# Module 2: implement the environment contract

[Workshop overview](README.md) | [Previous: developer promise](1-developer-promise.md) | [Next: application delivery](3-application-delivery.md)

**Duration:** 40 minutes, 00:35-01:15. 10 minutes explanation and guided wiring, 5 demonstration, 15 practice, 5 debrief, 5 catch-up.

## Objectives

By the end of this module, you will be able to:

- Explain the difference between what a developer asks for and the trusted configuration the platform supplies.
- Wire an installed platform so it can fetch private code, use its own identity, store state, and deliver within boundaries.
- Tighten a platform API by making an existing field required, and prove the API enforces it.
- Submit an environment request through Git and trace it to a usable AKS managed namespace.

> **Platform concept: self-service through a contract.** A platform API is a promise. Developers describe intent with a few fields; the platform owns how that intent becomes infrastructure. In the BACK stack, **Crossplane** serves the API, **Argo CD** delivers it from Git, and **Kubernetes** runs both.

> **AKS in action: managed namespaces, Azure RBAC, and the Argo CD extension.** The `beans` namespace you vend in this module is an AKS [managed namespace](https://learn.microsoft.com/azure/aks/concepts-managed-namespaces): AKS applies its quota, network policy, and labels as one Azure resource. Access is [Azure RBAC](https://learn.microsoft.com/azure/aks/manage-azure-rbac) scoped to that namespace, so the requesting developer can work inside it without cluster-wide rights. Argo CD runs as the AKS [Argo CD extension](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-argocd), so Azure installs and updates it while the platform team owns what it delivers. See [why AKS is the foundation](1b-aks-foundation.md#what-aks-provides-and-what-the-platform-adds).

## Before you start

**Prerequisites:** [setup](../setup/README.md) is complete, local services are running, and you have read [Module 1](1-developer-promise.md). In your terminal, `source ~/prel37/config/lab.env` has been run.

**Starting state on a fresh lab:**

- Controllers (Crossplane, provider-opentofu, Argo CD) are installed and healthy, but not wired to anything.
- `config/environment.yaml` (Lab Root folder) is rendered for your lab but **not applied**.
- Argo CD shows no applications. The `AppEnvironment` API does not exist yet.
- The platform repository's `requests/` folder has no `beans-dev.yaml`, and there is no `beans` team namespace.

**Resuming?** The wiring commands are safe to rerun. If a PR from this module already merged, verify its checkpoint and continue rather than repeating it.

## Separate intent from implementation

A well-run platform draws a sharp line between _what_ a developer asks for (intent) and _how_ the platform fulfills it (implementation). That line is the product contract.

The `AppEnvironment` request is that contract. A developer describes their intent with a few high-level fields: the team, application, owner, cost center, and an approved namespace class. They do not specify a cluster ID, a subnet, or a specific managed identity. The platform owns the mapping of those inputs to the actual infrastructure.

This split is a security and operational guardrail. If a request accepted arbitrary role IDs or module URLs, the API would be a remote infrastructure console. Constraining the inputs means every environment starts in a known, supported state.

### The life of a request: from Git to a usable environment

Think of the tools as one pipeline that turns a small YAML file into a usable environment, not as a list of products.

| Stage               | Component          | Action                                                                                            | Outcome                                  |
| :------------------ | :----------------- | :------------------------------------------------------------------------------------------------ | :--------------------------------------- |
| **1. Intent**       | Git                | A developer merges a request into the platform repository.                                        | A versioned, reviewed record of intent.  |
| **2. Sync**         | Argo CD (Control)  | Argo CD detects the change and applies the request to the control cluster.                        | The request is now a Kubernetes object.  |
| **3. Composition**  | Crossplane         | Crossplane matches the request to a Composition, combining intent with trusted lab configuration. | A plan for the required Azure resources. |
| **4. Provisioning** | provider-opentofu  | OpenTofu executes the plan, creating the namespace, identities, and telemetry resources.          | The raw infrastructure exists in Azure.  |
| **5. Activation**   | Argo CD (Baseline) | Argo CD uses the outputs from provisioning to deliver the ServiceAccount and ConfigMap.           | The environment is usable for the app.   |

You are not just running commands; you are wiring this pipeline. You connect the supplied parts, complete one piece of the public contract, then follow a real request through the system.

### Control plane and workload plane

This lab separates the **control plane**, which runs the platform, from the **workload plane**, which runs applications. The [foundation interlude](1b-aks-foundation.md) explains why the control cluster uses AKS Standard and the workload cluster uses AKS Automatic.

- **Control plane (control cluster):** runs the API (Crossplane), the delivery engine (Argo CD), and the infrastructure provider. Its identities hold the privileges to create Azure resources and deliver to the workload cluster.
- **Workload plane (workload cluster):** runs the applications inside constrained namespaces. It does not run the platform controllers; it runs what is delivered to it.

Keeping the platform's privileged controllers out of the workload cluster means an application namespace never holds the credentials that create infrastructure or change the platform API.

### Keep ownership and state separate

Every resource has exactly one owner. Two controllers managing the same object undo each other's work.

| Owner                                        | Owns                                                                                                                                  |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Foundation Terraform, run once by setup      | Clusters, controller installs and identities, shared model, Log Analytics, and remote state storage.                                  |
| You, as platform engineer, in this module    | Provider configuration, delivery permissions, trusted mapping, and root Applications. Applied with `kubectl`, not watched by Argo CD. |
| Argo CD `platform-system` and Crossplane     | The `AppEnvironment` API (XRD) and its Composition, delivered from `api/`.                                                            |
| provider-opentofu, running the remote module | Per-team Azure resources and the managed namespace. Each request has its own OpenTofu state in Azure Blob Storage.                    |
| Argo CD baseline and application delivery    | In-namespace resources. The app chart never creates the Namespace or its quota.                                                       |

The remote module `opentofu/managed-namespace/main.tf` is one complete file that only the controller runs. Do not run Terraform or OpenTofu against it from your computer.

Each request vends one team environment. The request's `team` names the namespace and the team's Azure resources, such as `id-prel37-<lab>-beans` and `appi-prel37-<lab>-beans`. The request's `metadata.name` names its Workspace, Argo CD projects, and baseline Application. This workshop uses team `beans`, application `fourth-coffee`, and request `beans-dev`, which `lab.env` sets as `$TEAM`, `$APP_NAME`, and `$APP_ENV`.

### Why cost attribution belongs in the contract

A cost center ties an environment to an accountable owner. Requiring it at request time means no environment arrives without attribution, and the platform never has to chase it later.

It does not cap spending. The `ai-dev` namespace class sets a Kubernetes quota (CPU requests `2000m`, limits `6000m`; memory requests `3Gi`, limits `8Gi`), which bounds resources, not dollars. Module 5 looks at cost.

### Accepted, provisioned, and usable are different states

A merged PR means the request is **accepted**. Creating the namespace and Azure resources means it is **provisioned**. Delivering the ServiceAccount and configuration means it is **usable**. A good platform tells the developer which state they are in. Module 3 then proves access with a real model call rather than assuming a role assignment worked.

## Guided wiring: connect the installed components

Setup installed the controllers. In this section you connect them so the platform can run without your personal login.

### 1. Check that the controllers and credentials are ready

```bash
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Healthy provider/provider-opentofu --timeout=600s
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Healthy functions.pkg.crossplane.io -l app.kubernetes.io/part-of=prel37 --timeout=600s
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system get secret module-git-credentials
kubectl --context "$CONTROL_CONTEXT" -n argocd get secret repo-platform repo-app-deploy cluster-workload
```

**Expected result:** the provider and three functions report `condition met`, and all four Secrets are listed. These Secrets hold the scoped GitHub tokens from `make auth` and the workload-cluster registration. If a Secret is missing, see [workspace or local service is unavailable](appendix-a-troubleshooting.md#workspace-sign-in-or-local-service-is-unavailable).

### 2. Connect execution, identity, and delivery permissions

In VS Code, open these files in the **Platform** folder and read the comments:

- `bootstrap/provider-config.yaml`
- `bootstrap/control.yaml`

They create three connections:

| Connection            | File                   | What it does                                                                                                                                                |
| --------------------- | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GitHub to provider    | `provider-config.yaml` | Lets `provider-opentofu` fetch the private module using the `module-git-credentials` token, not your GitHub login.                                          |
| Provider to Azure     | `provider-config.yaml` | Uses the control cluster's workload identity to call Azure, and stores OpenTofu state in your lab's storage account. Not your `az login`.                   |
| Crossplane to Argo CD | `control.yaml`         | Lets Crossplane create Argo CD `Applications` and `AppProjects`, and defines the `platform-system` project that limits what the platform roots may deliver. |

Apply both:

```bash
kubectl --context "$CONTROL_CONTEXT" apply --server-side -f "$LAB_ROOT/platform/bootstrap/provider-config.yaml"
kubectl --context "$CONTROL_CONTEXT" apply --server-side -f "$LAB_ROOT/platform/bootstrap/control.yaml"
```

**Expected result:** each object reports `serverside-applied`. Nothing is provisioned yet.

### 3. Supply the trusted lab mapping

In VS Code, open `config/environment.yaml` in the **Lab Root** folder. This is the platform's private knowledge about your lab: the repository URLs, cluster ID, model endpoint, Log Analytics workspace, and `moduleRevision`, the exact platform commit the controller runs. A developer never types any of these. The Composition reads them by name and combines them with the request.

The `moduleRevision` pins execution: even after you change `main`, the OpenTofu module and charts run from this fixed commit. That is how a platform team can change the API without silently changing the code that runs behind it.

```bash
kubectl --context "$CONTROL_CONTEXT" apply --server-side -f "$LAB_ROOT/config/environment.yaml"
```

**Expected result:** `environmentconfig.apiextensions.crossplane.io/prel37 serverside-applied`. The Composition can read these values when it provisions resources.

### 4. Trace the cost-center field through the implementation

Before turning on delivery, follow one field from the API to Azure. In VS Code, open these files in the **Platform** folder:

| File                                 | Find                                                                | Why it matters                                                                                                                                |
| ------------------------------------ | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `api/xrd.yaml`                       | `costCenter` with pattern `^CC-[0-9]{4}$`, and the `required:` list | The field exists but is not required. That is the contract gap you close in Cycle 1.                                                          |
| `api/composition.yaml`               | `cost_center: {{ $xr.spec.costCenter }}` in the Workspace `varmap`  | The Composition passes the developer's value to OpenTofu alongside trusted values from `environment.yaml`.                                    |
| `opentofu/managed-namespace/main.tf` | `variable "cost_center"` and where `var.cost_center` is used        | It becomes the namespace label `platform.prel37.example/cost-center` and a `cost-center` tag on the team's agent identities and App Insights. |

The Composition also creates two Argo CD AppProjects per request, both limited to the team's namespace. `beans-dev` allows the app's Deployments, Services, ConfigMaps, Secrets, and HTTPRoutes. `beans-dev-baseline` allows only ServiceAccounts, ConfigMaps, and NetworkPolicies. Neither can create cluster-wide resources or Namespaces. The baseline supplies native OTLP cloud URLs and routing attributes in `platform-context`; it does not require an `Instrumentation` CRD or a collector in the cluster.

**Expected result:** you can explain how `spec.costCenter` becomes a namespace label and resource tags. Do not edit these files.

### 5. Turn on delivery and establish the API

In VS Code, open `bootstrap/roots.yaml` in the **Platform** folder. A root `Application` is a pointer that tells Argo CD which Git folder to watch and where to apply it:

| Root `Application`  | Watches on `main` | Delivers to the control cluster              |
| ------------------- | ----------------- | -------------------------------------------- |
| `platform-system`   | `api/`            | The `AppEnvironment` XRD and its Composition |
| `platform-requests` | `requests/*.yaml` | Environment requests                         |

There is no root for the `app-deploy` repository. When a request is ready, the Composition creates that team's application delivery itself, so developers do not author Argo CD wiring.

> Both roots sync automatically and self-heal, but do not prune: deleting a request file does not tear an environment down. Removing an environment is an explicit platform team decision and action, not a side effect of a deleted file.

```bash
kubectl --context "$CONTROL_CONTEXT" apply --server-side -f "$LAB_ROOT/platform/bootstrap/roots.yaml"

# Argo CD delivers the XRD; Crossplane then serves the new API
kubectl --context "$CONTROL_CONTEXT" -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/platform-system --timeout=600s
kubectl --context "$CONTROL_CONTEXT" wait --for=create crd/appenvironments.platform.prel37.example --timeout=300s
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Established crd/appenvironments.platform.prel37.example --timeout=300s
kubectl --context "$CONTROL_CONTEXT" -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/platform-requests --timeout=600s
```

**Expected result:** within about 30 seconds, each wait reports `condition met`. In Argo CD (`https://localhost:8443`), `platform-system` and `platform-requests` are Synced and Healthy.

**Wiring checkpoint:** the `AppEnvironment` API exists, but nothing has been requested. There is still no Workspace or `beans` namespace. If a wait fails, keep the error and see [platform wiring or request API is not ready](appendix-a-troubleshooting.md#platform-wiring-or-request-api-is-not-ready). Do not add sleeps, broaden access, or run the module locally.

## Demonstrate: trace one request

**5 minutes. Instructor-led.** In a completed environment, the instructor shows a request, its Workspace, the managed namespace in the Azure portal, and the baseline in the workload cluster. The point to watch: one small YAML file in Git becomes Azure resources and a usable namespace, and every hop is visible.

Self-paced learners: skip ahead. You see the same chain in your own environment at the end of this module.

## Guided practice: require attribution and vend the environment

**15 minutes.** You make two small PRs in order. The API must change before a request relies on it.

### Cycle 1: make cost attribution part of the contract

#### 1. See the gap

Try a request that omits `costCenter`. `--dry-run=server` asks the API server to validate it without creating anything, and the throwaway name `contract-check` keeps it separate from your real request:

```bash
cd "$LAB_ROOT/platform"
grep -v costCenter examples/request.yaml | sed 's/name: beans-dev/name: contract-check/' | kubectl --context "$CONTROL_CONTEXT" apply --dry-run=server -f -
```

**Expected result:** `appenvironment.platform.prel37.example/contract-check created (server dry run)`. The API accepts a request with no cost center. You close that gap next.

#### 2. Change the schema on a branch

```bash
git checkout main && git pull origin main
git checkout -b update-request-schema
sed -i.bak 's/required: \[team, application, owner\]/required: [team, application, owner, costCenter]/' api/xrd.yaml && rm api/xrd.yaml.bak
git diff
```

**Expected result:** the diff shows one changed line, from `required: [team, application, owner]` to `required: [team, application, owner, costCenter]`. If the diff is empty, the `sed` did not match; check that `api/xrd.yaml` is unchanged from `main` and ask for help rather than editing other lines.

#### 3. Commit, open, review, and merge the PR

```bash
git add api/xrd.yaml
git commit -m "feat: require costCenter in AppEnvironment request"
git push -u origin update-request-schema
gh pr create --fill
gh pr diff
```

Read the diff. It must change only the `required` list. Then merge:

```bash
gh pr merge --merge --delete-branch
```

**Expected result:** `gh` reports the PR merged and your clone is back on `main`.

#### 4. Deliver the change and prove the contract

Argo CD polls Git every few minutes. Ask it to check now instead of waiting, then wait for the new revision:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd annotate application platform-system argocd.argoproj.io/refresh=normal --overwrite
MERGED="$(git rev-parse HEAD)"
kubectl --context "$CONTROL_CONTEXT" -n argocd wait application/platform-system --for=jsonpath="{.status.sync.revision}=$MERGED" --timeout=300s
```

Now rerun the request from step 1:

```bash
grep -v costCenter examples/request.yaml | sed 's/name: beans-dev/name: contract-check/' | kubectl --context "$CONTROL_CONTEXT" apply --dry-run=server -f -
```

**Expected result:** `The AppEnvironment "contract-check" is invalid: spec.costCenter: Required value`. The same request that passed in step 1 is rejected by the Kubernetes API, before any controller or reviewer spends time on it. That is a guardrail, not a gate.

> If the request is still accepted, Argo CD has not delivered your merge yet. Rerun the `annotate` and `wait` commands, then check `platform-system` in the Argo CD UI.

### Cycle 2: request the environment

#### 5. Create the request on a branch

```bash
cd "$LAB_ROOT/platform"
git checkout main && git pull origin main
git checkout -b submit-env-request
test ! -e "requests/$APP_ENV.yaml" && cp examples/request.yaml "requests/$APP_ENV.yaml"
REQUESTER_ID="$(az ad signed-in-user show --query id -o tsv)"
sed -i.bak "s/00000000-0000-0000-0000-000000000000/$REQUESTER_ID/" "requests/$APP_ENV.yaml" && rm "requests/$APP_ENV.yaml.bak"
```

If `test` stops the command, `requests/beans-dev.yaml` already exists from an earlier attempt in this lab. Do not overwrite it; check whether its PR already merged.

In VS Code, open `requests/beans-dev.yaml` (**Platform** folder) and read it. Every field is intent:

| Field               | Value                 | Meaning                                                                                            |
| ------------------- | --------------------- | -------------------------------------------------------------------------------------------------- |
| `metadata.name`     | `beans-dev`           | The request's name. Requests are cluster-scoped, so there is no `metadata.namespace`.              |
| `team`              | `beans`               | Names the managed namespace and the team's Azure resources.                                        |
| `application`       | `fourth-coffee`       | The app this environment serves, and its folder in app-deploy.                                     |
| `owner`             | `group:default/beans` | The Backstage catalog owner.                                                                       |
| `costCenter`        | `CC-1042`             | The value your contract requires.                                                                  |
| `requesterObjectId` | your Entra object ID  | Gets namespace access in AKS desktop and Monitoring Reader on the team's own Application Insights. |
| `namespaceClass`    | `ai-dev`              | The approved size and policy for the namespace.                                                    |

Another team would change `metadata.name`, `team`, `application`, and `owner` together.

#### 6. Commit, open, review, and merge the PR

```bash
git diff --stat main
git add "requests/$APP_ENV.yaml"
git commit -m "feat: request $APP_ENV environment"
git push -u origin submit-env-request
gh pr create --fill
gh pr diff
```

Check that the diff adds only `requests/beans-dev.yaml` and that `requesterObjectId` is not all zeros. Then merge:

```bash
gh pr merge --merge --delete-branch
kubectl --context "$CONTROL_CONTEXT" -n argocd annotate application platform-requests argocd.argoproj.io/refresh=normal --overwrite
```

### Trace the fulfillment

One merge starts a chain across Git, two clusters, and Azure. Allow the 15-minute provisioning window below. The module creates Azure resources, discovers the native OTLP endpoints, and grants the agent identities access to the application's DCR before the baseline is delivered. This checkpoint proves the connection contract exists, not that the application has exported telemetry; Module 3 proves that separately.

#### 7. Watch the request move from accepted to ready

```bash
kubectl --context "$CONTROL_CONTEXT" get appenvironment "$APP_ENV"
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system get workspaces.opentofu.m.upbound.io
```

Rerun these every minute or so. What you will see:

| What you see                                               | What it means                                                                             |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `the server doesn't have a resource` or `NotFound`         | Argo CD has not applied the request yet. Check `platform-requests` in the Argo CD UI.     |
| `SYNCED True`, `READY False`                               | Crossplane accepted it and created the Workspace. Provisioning is in progress.            |
| Workspace with blank `SYNCED` and `READY` columns          | OpenTofu is running its first plan and apply. Status appears when the first run finishes. |
| Workspace `READY True`, then `AppEnvironment` `READY True` | Azure resources exist and the baseline is delivered.                                      |

When you are ready to wait for the end, run:

```bash
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Ready appenvironment "$APP_ENV" --timeout=15m
```

**Expected result:** `appenvironment.platform.prel37.example/beans-dev condition met`. If it times out, see [environment request is merged but not ready](appendix-a-troubleshooting.md#environment-request-is-merged-but-not-ready).

#### 8. Verify the Azure managed namespace

```bash
az aks namespace show \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --cluster-name "$AKS_CLUSTER_NAME" \
  --name "$TEAM" \
  --query "{name:name, state:properties.provisioningState, costCenter:properties.labels.\"platform.prel37.example/cost-center\", quota:properties.defaultResourceQuota}"
```

**Expected result:** `state` is `Succeeded`, `costCenter` is `CC-1042`, and the quota matches the `ai-dev` class. Your contract field is now a label on a real Azure resource.

#### 9. Verify the workload baseline and the binding

```bash
kubectl --context "$AKS_CONTEXT" -n "$TEAM" get serviceaccount/concierge serviceaccount/ops-agent configmap/platform-context networkpolicy/allow-platform-gateway
kubectl --context "$AKS_CONTEXT" -n "$TEAM" get configmap platform-context -o json |
  jq -e '[.data.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT,
          .data.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT,
          .data.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT] |
         all(.[]; type == "string" and startswith("https://"))'
kubectl --context "$CONTROL_CONTEXT" get appenvironment "$APP_ENV" -o jsonpath='{.status.binding}' | jq
```

**Expected result:** the ServiceAccounts `concierge` and `ops-agent`, ConfigMap `platform-context`, and NetworkPolicy `allow-platform-gateway` exist in `beans`, and the endpoint check prints `true`. Each ServiceAccount carries a different `azure.workload.identity/client-id` annotation, because each agent has its own Azure identity. The binding lists `namespace`, `serviceAccountNames`, `configMapName`, `configPath`, and `appUrl`. Module 3 uses these names to connect the application. There is no `Instrumentation` resource or cluster DCR association to wait for.

In Argo CD you now also see `beans-dev-baseline` (Synced, Healthy) and `fourth-coffee`. `fourth-coffee` shows sync status `Unknown` because its folder in app-deploy does not exist yet. You create it in Module 3.

## Debrief: accepted is not ready

**5 minutes.**

- Who owns the request, the managed namespace, the identity, the baseline, and the application?
- While the Workspace was provisioning, what did a developer need to know? Where could they see it without reading controller logs?
- Why does the schema rejection in step 4 save time for both developers and the platform team?

Making work asynchronous does not remove waiting. A platform's value includes making the wait visible and recoverable.

**Takeaway:** list the inputs your teams send in environment tickets today. Split them into intent the developer owns and trusted configuration the platform owns. The first list is your API; the second is your EnvironmentConfig.

## Checkpoint

| Checkpoint  | Done when                                                                                                             |
| ----------- | --------------------------------------------------------------------------------------------------------------------- |
| Wiring      | Provider config, delivery permissions, and mapping applied; both roots Synced; API Established.                       |
| Contract    | A request without `costCenter` is rejected with `spec.costCenter: Required value`.                                    |
| Fulfillment | `beans-dev` is Ready; the `beans` namespace has `concierge`, `ops-agent`, `platform-context`, and the network policy. |

Record each result in `answers/product-brief.md` with the PR numbers and any help you needed. Continue to Module 3 only when fulfillment is complete.

If blocked, keep the PR and request as they are and use [Appendix A](appendix-a-troubleshooting.md#environment-request-is-merged-but-not-ready). Do not create the namespace by hand or run the module locally; fix the request through Git.

**What you learned:** a small request expresses intent. Platform engineers connect credentials, state, trusted mapping, and delivery boundaries so that intent becomes a usable result without a ticket.

## Break

**10 minutes, 01:15-01:25.** Keep the environment running.

---

[Previous: developer promise](1-developer-promise.md) | [Next: connect and deploy the application](3-application-delivery.md)
