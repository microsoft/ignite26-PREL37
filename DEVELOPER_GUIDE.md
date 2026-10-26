# Technical implementation guide: self-service agent environment vending

This guide is the condensed, practitioner view of the workshop's paved road for AI agent environments on AKS. It covers the architecture and the execution steps without the teaching notes. If you are new to platform engineering, start with the [workshop guide](docs/README.md) and use this page as a reference map.

## 1. Architecture overview

The platform splits management from execution. One cluster runs the platform's controllers; another runs the team's application. This keeps platform credentials and reconcilers away from workloads, and gives each side a clear owner.

### The control plane (control cluster)

- **Role**: orchestration, provisioning, and policy.
- **Key components**: Argo CD (GitOps), Crossplane (control plane), `provider-opentofu` (Azure infrastructure).
- **Responsibilities**: serves the environment API, runs OpenTofu modules to provision Azure resources, and delivers baseline resources.

### The workload plane (workload cluster)

- **Role**: application execution.
- **Key components**: AKS Automatic, AI Gateway.
- **Responsibilities**: hosts the vended namespaces, the workloads that use the managed identities, and the AI application.

### The flow

Every change starts as a Git commit and ends as reconciled state:

`Platform Git` → `Control Cluster (Argo/Crossplane)` → `Azure Resource Manager` → `Workload Cluster (Namespace/Identity)` → `GitOps Baseline Delivery`.

---

## 2. Quick reference: environment and directories

### Environment variables

| Variable          | Purpose                                                      |
| ----------------- | ------------------------------------------------------------ |
| `LAB_ROOT`        | Base directory for the workshop workspace.                   |
| `CONTROL_CONTEXT` | Kubeconfig context for the control cluster (management).     |
| `AKS_CONTEXT`     | Kubeconfig context for the workload cluster (execution).     |
| `MODULE_REVISION` | The pinned Git commit ID used for platform system assets.    |
| `TEAM`            | Team that owns the vended namespace (`beans`).               |
| `APP_NAME`        | Application name and `apps/<name>` folder (`fourth-coffee`). |
| `APP_ENV`         | AppEnvironment request name (`beans-dev`).                   |

### Directory structure

| Directory     | Role                                                                                 |
| ------------- | ------------------------------------------------------------------------------------ |
| `/platform`   | **Platform repo**: the XRD, Compositions, OpenTofu modules, and Backstage templates. |
| `/app-deploy` | **App repo**: each application's `values.yaml` and `profile.yaml`.                   |
| `/config`     | **Local state**: instance-specific configuration (`lab.env`, `environment.yaml`).    |
| `/exercises`  | **Scaffolds**: starter files for the application deployment.                         |

---

## 3. Step-by-step implementation

### Phase 1: platform wiring (paving the road)

Before anyone can request an environment, the control plane needs credentials to reach Azure, rules for what Argo CD may deploy, and a trusted mapping from requests to real resources. Each step below applies one of those pieces from the platform repo.

1. **Initialize**: load your environment.

   `bash export LAB_ROOT="$HOME/prel37" source "$LAB_ROOT/config/lab.env" export KUBECONFIG="$LAB_ROOT/.state/kubeconfig" `

2. **Connect the provider**: apply the `ClusterProviderConfig` to connect OpenTofu to Azure and the remote state backend.

   `bash git -C "$LAB_ROOT/platform" show HEAD:bootstrap/provider-config.yaml | kubectl --context "$CONTROL_CONTEXT" apply -f - `

3. **Set up delivery RBAC**: apply the `ClusterRole` and `AppProject`s that define who can deploy what, and where.

   `bash git -C "$LAB_ROOT/platform" show HEAD:bootstrap/control.yaml | kubectl --context "$CONTROL_CONTEXT" apply -f - `

4. **Supply the trusted mapping**: apply the `EnvironmentConfig`, which maps logical environment requests to physical Azure resources (cluster ID, model endpoint, and so on). Developers never type these values, so they cannot point a request at the wrong cluster.

   `bash kubectl --context "$CONTROL_CONTEXT" apply -f "$LAB_ROOT/config/environment.yaml" `

5. **Enable GitOps roots**: apply the root Argo CD Applications to start watching the `api/` and `requests/` directories in the platform repo.

   `bash git -C "$LAB_ROOT/platform" show HEAD:bootstrap/roots.yaml | kubectl --context "$CONTROL_CONTEXT" apply -f - `

### Phase 2: the vending process (creating the environment)

With the platform wired, define the contract (what a request must contain) and submit the first request. The XRD is the platform's API: tightening it is how the platform team enforces a convention without a manual review step.

1. **Update the API contract**: modify the XRD (`api/xrd.yaml`) to make `costCenter` a required field.
   - _Action_: edit `api/xrd.yaml` → create PR → merge.
2. **Submit the request**: create an `AppEnvironment` custom resource in `platform/requests/$APP_ENV.yaml`. `spec.team` names the namespace and Azure resources; `metadata.name` names the Workspace and AppProjects; `spec.application` names the Argo CD Application and config folder.
   - _Action_: create file → create PR → merge.
3. **Automatic fulfillment**: after the merge, Crossplane and the OpenTofu provider provision:
   - A **Managed Namespace** on the workload cluster.
   - A **Managed Identity** with OIDC federation.
   - An **Application Insights** resource.
   - **Baseline Resources** (ServiceAccounts `concierge` and `ops-agent`, ConfigMap `platform-context`) via Argo CD.
   - Two request-owned **AppProjects** (`<request>` and `<request>-baseline`) confined to the team namespace.
   - The **Argo CD Application** `fourth-coffee`, which waits for configuration in `app-deploy/apps/fourth-coffee/` and routes at `beans.localhost`.
   - A **binding** in the AppEnvironment `status.binding` that tells the developer what to reference.

### Phase 3: application deployment

Bind the application to the vended environment. The developer references what the platform created instead of copying IDs or secrets.

1. **Bind to platform identity**: read `status.binding` on the AppEnvironment, then reference the vended resources in `app-deploy/apps/fourth-coffee/values.yaml`:
   - `extraEnvFrom[0].configMapRef.name: platform-context`
   - ServiceAccounts are assigned by the platform; do not add identity overrides to app-deploy.
2. **Deploy**: merge the application config PR.
3. **Verify**: confirm the supported Gateway route answers and a fresh chat has a correlated successful model dependency in `OTelSpans`.

### Phase 4: self-service scaling (the IDP experience)

Give developers a way to change their environment without filing a ticket. The platform team decides the approved options; the developer picks one through Backstage, and Git records the change.

1. **Expand profile options**: add the `standard` profile to the Backstage template enum in `platform/backstage/templates/ai-app/template.yaml`.
   - _Action_: edit → create PR → merge.
2. **User request through Backstage**:
   - Open the Backstage UI → select "Resize an application" → pick the application → choose `standard` → submit.
3. **GitOps fulfillment**:
   - Backstage creates a PR in the `app-deploy` repo updating only `apps/fourth-coffee/profile.yaml`.
   - The user merges the PR → Argo CD triggers a rolling update of the pods with the new resource limits.

### Phase 5: vend a second team (proving generalization)

A platform capability is only a platform capability if it works for the next team. Nothing in the platform is specific to `beans`. After completing phases 1 to 4, vend a second team on the same clusters to prove isolation. This example uses team `sprinkles` and application `sprinkles-app`, which reuses the supplied chart.
The **AI application environment** Backstage template (`platform/backstage/templates/app-environment/`) does steps 1 to 3 from one form and opens the two PRs for you. The learner version is [docs/8-optional-next-environment.md](docs/8-optional-next-environment.md). The manual steps below show what the template generates.

1. **Submit a second request** in the platform repo. Change `metadata.name`, `team`, `application`, and `owner` together:

   `yaml apiVersion: platform.prel37.example/v1alpha1 kind: AppEnvironment metadata: name: sprinkles-dev spec: team: sprinkles application: sprinkles-app owner: group:default/sprinkles costCenter: CC-2001 requesterObjectId: "<entra-object-id>" namespaceClass: ai-dev `
   Save it as `requests/sprinkles-dev.yaml`, then PR and merge. Watch `kubectl --context "$CONTROL_CONTEXT" get appenvironment sprinkles-dev -w` until `Ready=True`.

2. **Add the application configuration** in the app-deploy repo. Copy `apps/fourth-coffee/values.yaml` and `profile.yaml` to `apps/sprinkles-app/`, then PR and merge. The binding (`concierge`, `ops-agent`, `platform-context`) is the same shape, so no edits are required.

3. **Register the team in Backstage** (optional). Add a `sprinkles` Group and a `sprinkles-app` Component owned by `group:default/sprinkles` to `catalog/catalog.yaml`. To launch the profile template as that team, add `group:default/sprinkles` to the guest `ownershipEntityRefs` in the local Backstage config.

4. **Verify isolation**:

   | Check                     | Command or location                                                                                | Expected result                                                                                                                |
   | ------------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
   | Separate namespaces       | `kubectl --context "$AKS_CONTEXT" get ns beans sprinkles`                                          | Both exist, each with its own quota and baseline                                                                               |
   | Separate Azure resources  | `az resource list -g "$AKS_RESOURCE_GROUP" --tag team=sprinkles -o table`                          | Team identities and `appi-…-sprinkles`; Azure creates its cloud DCR/DCE in a separate managed resource group. No cluster DCRA. |
   | Separate OpenTofu state   | `az storage blob list` on the state container                                                      | A separate `env:sprinkles-dev` state blob next to `env:beans-dev`                                                              |
   | Separate delivery bounds  | `kubectl --context "$CONTROL_CONTEXT" -n argocd get appprojects`                                   | `sprinkles-dev` and `sprinkles-dev-baseline`, each limited to `sprinkles`                                                      |
   | Separate routes           | `curl -s -o /dev/null -w '%{http_code}\n' http://sprinkles.localhost:8080` with `make app` running | `200`, while `http://beans.localhost:8080` still serves Grinds                                                                 |
   | Separate telemetry        | Run `queries/application-model-call.kql` with each team's `status.appInsightsResourceId`           | Each query returns only that team's spans                                                                                      |
   | Duplicate team is refused | Submit a third request reusing `team: beans`                                                       | The Workspace fails with "already exists" on the identity, App Insights, and namespace; Grinds is untouched                    |

**Known limits:** one request per team per cluster. Application names must be unique across teams because they name the Argo CD Application and config folder. Telemetry routing trusts the application's own Application Insights attribute, so it separates teams for reading but is not a hard ingestion boundary. Only the supplied `fourth-coffee` chart is approved (`spec.chart`).
