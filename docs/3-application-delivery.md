# Module 3: connect and deploy the application

[Workshop overview](README.md) | [Previous: environment contract](2-environment-contract.md) | [Next: self-service interface](4-self-service.md)

**Duration:** 40 minutes, 01:25-02:05.
**Rhythm:** 10 minutes explanation, 5 demonstration, 15 guided practice, 5 debrief, 5 catch-up/questions.

## Objectives

By the end of this module, you will be able to:

- Bind an application to a platform-provided `ServiceAccount` and `ConfigMap`.
- Trace a Git change to the deployed application and its approved resource profile.
- Distinguish a healthy interface or fallback response from a verified model interaction.

> **Platform concept: the golden path.** The supported way should be the easiest way. The platform hands the team a ready identity, configuration, and delivery pipeline; the team supplies one name and its app settings. In the BACK stack, **Argo CD** delivers the app from Git onto **Kubernetes**, using the binding that **Crossplane** published.

> **AKS in action: workload identity and the managed Gateway.** The model call in this module needs no key because AKS Automatic turns on [workload identity](https://learn.microsoft.com/azure/aks/workload-identity-overview) and an OIDC issuer by default; the platform only federates each agent's ServiceAccount. Traffic reaches the app through the [App Routing Gateway API implementation](https://learn.microsoft.com/azure/aks/app-routing-gateway-api), which AKS runs and upgrades, so each team adds one route instead of operating an ingress controller. See [why AKS is the foundation](1b-aks-foundation.md#from-promise-to-foundation).

**Starting state:** Module 2 produced the `beans` namespace and baseline, including the `concierge` and `ops-agent` ServiceAccounts and the `platform-context` ConfigMap. The platform also created the Argo CD Application `fourth-coffee`, which is waiting for your configuration. If the baseline is blocked, follow [environment troubleshooting](appendix-a-troubleshooting.md#environment-request-is-merged-but-not-ready) before submitting the application. Guided attendees can also ask a proctor for help.
**Working in a lab prepared for a different application?** Follow [the Fourth Coffee migration](appendix-a-troubleshooting.md#switch-an-existing-lab-to-fourth-coffee) first. Keep that lab's application identifier and use the names in `status.binding`; the literal `fourth-coffee` paths below describe a fresh lab.

## The golden path: consuming the platform contract

Without a platform, every team rediscovers the same things: which identity to use, where the model key lives, which namespace and resource IDs belong to which environment. That assembly work is toil, and it is where copy-paste mistakes creep in. A platform replaces it with a **connection contract**: a small set of names the platform publishes and the application references.

The `AppEnvironment` request you merged in Module 2 is the source of this contract. When the environment is ready, the platform publishes a `status.binding` object. The binding is the bridge between the platform's infrastructure and the application's runtime, and in step 1 you read it directly.

| Field                 | Value                         | Question it answers                 |
| --------------------- | ----------------------------- | ----------------------------------- |
| `namespace`           | `beans`                       | "Where does my app live?"           |
| `serviceAccountNames` | `["concierge","ops-agent"]`   | "Who am I in the eyes of Azure?"    |
| `configMapName`       | `platform-context`            | "Where are my connection settings?" |
| `argoProject`         | `beans-dev`                   | "What are my delivery boundaries?"  |
| `argoApplication`     | `fourth-coffee`               | "Which delivery pipeline is mine?"  |
| `configPath`          | `apps/fourth-coffee`          | "Where do I put my configuration?"  |
| `appUrl`              | `http://beans.localhost:8080` | "How do I actually reach my app?"   |

Every value is derived from the request, so the process repeats the same way for every team. The `beans` team gets its own identifiers, entirely separate from the `coffee-ops` team, with no manual coordination between them.

In this lab, `concierge` and `ops-agent` are Kubernetes ServiceAccounts in the `beans` namespace on the **workload cluster**. Each is connected to its own Azure identity created by your environment request. `platform-context` contains the model endpoint, native OTLP cloud URLs, and the Application Insights routing attribute. It contains no ingestion token or application-owned credential.

### Workload identity and the trust chain

**Why this matters:** a static secret, such as an API key in a YAML file, can leak, must be rotated, and is hard to trace to one component. Cloud-native platforms replace it with **workload identity**.

Instead of handing the application a secret, the platform establishes trust between the Kubernetes cluster and Azure. The trust chain has four links:

1. **The platform** creates an Azure managed identity.
2. **The platform** federates that identity to a specific Kubernetes ServiceAccount in a specific namespace.
3. **The application pod** runs as that ServiceAccount.
4. **Azure** recognizes the pod's identity and grants it access to the model or telemetry resource.

The application never holds a password; it _is_ the identity. Nothing leaks, and nothing needs rotating by hand. This lab uses one identity per agent, `concierge` and `ops-agent`, so the platform team can audit or revoke one agent's access without affecting the rest of the application. `fourth-coffee-mcp` serves tools and calls no model, so it gets no ServiceAccount token and no Azure identity. Its SDK telemetry is explicitly disabled; use its stdout for process diagnostics. Agent-side spans still show calls to its tools. Access follows what each component does, not what the application as a whole needs.

You will see this in step 3: you fill in one ConfigMap name and never touch a client ID or key.

### Separating wiring from configuration

Platform engineering draws a clear line between **wiring** and **configuration**.

- **Wiring (platform owned):** the plumbing. The Argo CD Application manifest, target namespace, ServiceAccount assignments, and delivery project. Developers should never have to author this; if they do, the platform is leaking its implementation details.
- **Configuration (developer owned):** the tuning. The image tag, resource settings (CPU and memory), and application-specific settings. Developers control this through Git.

In this lab, the wiring already exists. The environment request created the Argo CD Application `fourth-coffee` in AppProject `beans-dev`. It pins the chart, targets the workload cluster's `beans` namespace, sets the route host to `beans.localhost` and each agent's ServiceAccount, and reads two files from your app-deploy repository: base `values.yaml`, then `profile.yaml`. Later values win, so the profile supplies the approved resource settings without replacing independent image or identity configuration.

Until you commit those files, Argo CD reports that `values.yaml` is missing. That is expected: the platform has done its part and is waiting for yours. You never write the Application manifest, so you cannot accidentally change its destination, project, or chart source.

Each source has its own job. The chart source is pinned to the approved platform commit in `moduleRevision`, and the image is a published release artifact; configuration on `main` changes as you complete the exercises. Canonical profiles live in `platform/profiles/workload-small.yaml` and `workload-standard.yaml`. The staged `profile.yaml` is an exact copy of the approved `small` profile. Module 4 replaces **that file**, not the Application's value-file reference.

> The pinned tag `0.1.0-12.1.ge412f12`, from [source revision `969ca1acae851d0ef3cb60619d5e0d6e90523fda`](https://github.com/pauldotyu/fourth-coffee/tree/969ca1acae851d0ef3cb60619d5e0d6e90523fda), includes renewable native OTLP authentication. Its verified image-index digest is `sha256:ece6b82e6411d47a17c48e6b550eac0571e19818ecf5b1fe1d4ef0b2113fa043`. The upstream OCI chart is recorded at the same release in the artifact lock; this lab's chart adapter keeps ServiceAccounts, the route, and digest pinning platform-owned. Attendees use the published image, not a local build. The [operator prerequisites](../setup/README.md#application-artifact-prerequisite) and this module's fresh interaction still need to prove that the assigned lab exports successfully.

Normal deployments render the locked image digest in the Pod specification, rather than the tag, to prevent upstream tag drift. The chart deliberately renders `:latest` for the explicit `image.tag=latest` teaching fixture in Module 5; restoring the locked tag restores the digest-pinned image.

The app chart creates neither Namespace nor quota. Those stay with the environment established in Module 2.

### Verifying the outcome with telemetry

A common trap is treating a green `Synced` status in Argo CD or a `Running` pod as proof the application works. AI applications make this trap worse: a pod can run while failing to reach the model, and the app can still return a plausible fallback reply.

A verified outcome requires three things, which steps 5 to 7 check in order:

1. **Reachability:** the application is accessible through the shared Gateway. `http://beans.localhost:8080` tunnels to the shared Gateway's ClusterIP service, not an application pod. Each team's HTTPRoute matches its own `<team>.localhost` host, so teams share the Gateway without colliding.
2. **Interaction:** a fresh user request is processed.
3. **Correlation:** telemetry proves a successful dependency call to the approved model, for this interaction rather than a historical example.

> **Tip:** The value is not hiding YAML. It is making a supported deployment and connection path usable without repeated assembly work.

## Demonstrate: follow the binding

**5 minutes. Instructor-led.**

Show `status.binding` on the AppEnvironment, then the `concierge` and `ops-agent` ServiceAccounts, each annotated with a different client ID, and the `platform-context` ConfigMap it names. Open `fourth-coffee` in Argo CD while it waits for configuration, then compare desired and observed revisions after a commit.

Compare a successful model dependency with a fallback-only interaction in the instructor environment. Notice the three details that tell them apart: the time, the operation (correlation) ID, and the dependency result.

The prepared query in `queries/application-model-call.kql` joins each chat request to its model call by trace ID. It reads the `OTelSpans` table in the lab's Log Analytics workspace, filtered to the application's own [Application Insights resource](README.md#application-telemetry). Use it rather than inventing a query from assumed event names.

## Guided practice: bind and deploy

**15 minutes.**

### 1. Read the binding from your environment

First, confirm the operator approved this image for authenticated telemetry. The artifact lock records which application build the lab uses:

```bash
jq -er '.application |
  if .nativeOtlpWorkloadIdentity == true then .imageTag
  else error("The pinned image is not approved for authenticated direct OTLP.")
  end' "$LAB_ROOT/config/artifact-lock.json"
```

**Expected result:** `0.1.0-12.1.ge412f12`. If this fails, stop before deploying. Do not flip the flag yourself or substitute classic ingestion; the operator must supply the verified artifact lock and matching chart/schema pins.

Next, read the contract the platform published for you. In your VS Code terminal, run:

```bash
kubectl --context "$CONTROL_CONTEXT" get appenvironment "$APP_ENV" -o jsonpath='{.status.binding}' | jq
```

**Expected result:** the seven binding fields from the table above. If `binding` is empty, the environment is not ready yet. Return to the Module 2 checkpoint.

Set the application name from the existing request:

```bash
APP_NAME="$(kubectl --context "$CONTROL_CONTEXT" get appenvironment "$APP_ENV" \
  -o json | jq -er '.spec.application | select(type == "string" and length > 0)')" &&
  export APP_NAME
```

**Expected result:** `echo "$APP_NAME"` prints `fourth-coffee`. If the command fails or prints something else, stop and ask a proctor.

Then confirm Argo CD already has your Application and is waiting for configuration. This is the platform-owned wiring in action:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd get application "$APP_NAME" -o jsonpath='{.status.conditions[*].message}{"\n"}'
```

**Expected result:** a long `helm template` error that ends with `apps/fourth-coffee/values.yaml: no such file or directory`. Sync status is `Unknown` and nothing is deployed yet. The error is good news: the delivery pipeline exists and is looking in the right place.

### 2. Add your application configuration on a branch

Start from current `main` in the app-deploy repository and copy the two prepared files into the folder your Argo CD Application watches:

```bash
cd "$LAB_ROOT/app-deploy"
git checkout main && git pull origin main
git status --short
git checkout -b "deploy-$APP_NAME"
mkdir -p "apps/$APP_NAME"
cp "$LAB_ROOT/exercises/application/values.yaml" "$LAB_ROOT/exercises/application/profile.yaml" "apps/$APP_NAME/"
```

**Expected result:** `git status --short` printed nothing before you branched, and you are on `deploy-fourth-coffee`.

In the VS Code Explorer, expand 🚀 **App-Deploy** > **apps** > **fourth-coffee** and open **values.yaml** and **profile.yaml**. Read them:

- `values.yaml` is the team's configuration: the image tag, and one blank `name: ""` field. The comment above it names the binding field that fills it.
- `profile.yaml` is an exact copy of the platform's approved `small` profile: CPU and memory for each of the three components. Leave it alone. Keeping it in its own file is what lets Backstage change it in Module 4 without touching anything else.

### 3. Fill the blank from the binding

Read the ConfigMap name from the binding and write it into `values.yaml`:

```bash
CM=$(kubectl --context "$CONTROL_CONTEXT" get appenvironment "$APP_ENV" -o jsonpath='{.status.binding.configMapName}')
echo "ConfigMap: $CM"
sed -i.bak \
  -e "/configMapRef:/,/name:/ s/name: \"\"/name: $CM/" \
  "apps/$APP_NAME/values.yaml" && rm "apps/$APP_NAME/values.yaml.bak"
```

**Expected result:** the echo prints `ConfigMap: platform-context`. Look at `values.yaml` in VS Code again; it ends with:

```yaml
extraEnvFrom:
  - configMapRef:
      name: platform-context
```

**What this means:** you did not name a ServiceAccount, create one, add a client ID, or paste a model key. The platform assigns each agent its ServiceAccount, and you referenced the configuration it already made. That one line is the entire connection between your app and the platform. If the name is blank, the environment is not ready; return to the Module 2 checkpoint.

### 4. Commit, open, review, and merge the PR

New files do not show in plain `git diff`, so stage the two files first, then review what is staged before you commit:

```bash
git add "apps/$APP_NAME/values.yaml" "apps/$APP_NAME/profile.yaml"
git status --short
git --no-pager diff --staged
```

**Expected result:** `git status --short` lists exactly two files, `A  apps/fourth-coffee/profile.yaml` and `A  apps/fourth-coffee/values.yaml`, and the diff ends with `name: platform-context` in `values.yaml`. `--no-pager` prints the whole diff and returns you to the prompt. Without it, Git shows a long diff in a pager and waits at a `:` or `(END)` prompt; press **q** to get the prompt back. If any other file is listed, or `values.yaml` still has `name: ""`, stop and ask for help before you commit.

Commit the two files, publish the branch, and open the PR:

```bash
git commit -m "feat: deploy $APP_NAME to $TEAM"
git push -u origin "deploy-$APP_NAME"
gh pr create --fill
```

Wait for `gh` to finish, then list the files in the PR:

```bash
gh pr diff --name-only
```

**Expected result:** the PR adds exactly two files, `apps/fourth-coffee/profile.yaml` and `apps/fourth-coffee/values.yaml`. The pull request is the review and audit point for every change; there is no side channel. Then merge:

```bash
gh pr merge --merge --delete-branch
```

### 5. Confirm Argo CD deployed your commit

A merged PR is not a deployed change. Argo CD has to notice the merge and render that exact commit. Ask it to check Git immediately instead of waiting for its next poll, then wait for your revision:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd annotate application "$APP_NAME" argocd.argoproj.io/refresh=normal --overwrite
MERGED="$(git rev-parse HEAD)"
kubectl --context "$CONTROL_CONTEXT" -n argocd wait application/"$APP_NAME" --for=jsonpath="{.status.sync.revisions[1]}=$MERGED" --timeout=300s
```

`fourth-coffee` has two sources. `revisions[0]` is the platform's chart, pinned to `moduleRevision`, so it does not track your app-deploy merge. `revisions[1]` is your app-deploy repository, and that is the one that must match. In the Argo CD UI, the same commit appears as the app-deploy source revision.

**Expected result:** `condition met`, usually within seconds of the refresh. The earlier `values.yaml: no such file or directory` message disappears.

Next, wait for the application to become healthy. The first rollout takes about two minutes because AKS Automatic may add a node for the new pods:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd wait application/"$APP_NAME" --for=jsonpath='{.status.health.status}'=Healthy --timeout=600s
for d in concierge ops-agent fourth-coffee-mcp; do
  kubectl --context "$AKS_CONTEXT" -n "$TEAM" rollout status deployment/"$d" --timeout=600s
done
kubectl --context "$AKS_CONTEXT" -n "$TEAM" get deployments,pods,services,httproutes
```

**Expected result:** Deployments `concierge`, `ops-agent`, and `fourth-coffee-mcp` each show `1/1` ready, and HTTPRoute `concierge` lists host `beans.localhost`. A running pod alone is not enough; Argo CD must also report the revision and health above.

### 6. Open the application through the gateway

With the application and route in place, open a **new terminal** and start the tunnel. These commands load your lab settings, look up the shared Gateway's service, and forward local port 8080 to it, so your request still goes through the Gateway and your HTTPRoute. They work from any directory.

```bash
source "${LAB_ROOT:-$HOME/prel37}/config/lab.env"
GATEWAY_SVC=$(kubectl --context "$AKS_CONTEXT" -n platform-gateway get service -l gateway.networking.k8s.io/gateway-name=tenants -o jsonpath='{.items[0].metadata.name}')
echo "Gateway service: $GATEWAY_SVC"
kubectl --context "$AKS_CONTEXT" -n platform-gateway port-forward "service/$GATEWAY_SVC" 8080:80 --address 127.0.0.1
```

**Expected result:** the terminal prints the Gateway service name, then `Forwarding from 127.0.0.1:8080 -> 80`.

**Keep this terminal running.** Open a browser and enter **`http://beans.localhost:8080`**, the `appUrl` from your binding.

**Do not open `http://127.0.0.1:8080` or `http://localhost:8080`**, even though the terminal prints the forwarding address. That address is where the tunnel listens, not the hostname your application route expects. The Gateway routes requests by hostname, and your application's HTTPRoute matches `beans.localhost`. Using the IP address or plain `localhost` returns **404**.

Browsers resolve `*.localhost` names to your own machine, so no DNS or hosts-file change is needed. Press Ctrl+C to stop the tunnel. If the service name is blank, the Gateway is not ready yet; return to step 5's checks.

### 7. Verify a fresh model interaction

A reply in the chat is not proof the model answered. The app can return a plausible fallback when the model call fails. This step finds the telemetry record showing your message reached the approved model and succeeded. It is the correlation check from [verifying the outcome with telemetry](#verifying-the-outcome-with-telemetry).

**1. Note the time.** In your VS Code terminal, run:

```bash
date -u +%FT%TZ
```

Telemetry timestamps are in UTC, so this gives you a time to compare against.

**2. Use the app.** At `http://beans.localhost:8080`, type a message such as `Suggest two coffee options for someone who likes oat milk` and select **Send**. The barista replies with a suggestion, but a suggestion doesn't add anything to the **Order ticket**, which still says **Nothing on the ticket yet**. Then place an order:

- Select **Surprise me**, the last item in the **On the board** panel. The barista builds a drink from what's in stock and replies _Your coffee is ready: ..._, and the order ticket shows the drink and its price.
- Enter a made-up name under **Name on the cup** and select **Confirm and brew**. The barista replies with an order number and a pickup time.

Selecting another drink on the board, or typing an order, can get a clarifying reply such as _Double includes 2 shots._ instead of a draft, and the ticket stays empty. If that happens, select **Surprise me**. In a narrow browser window, such as the lab VM's, the order ticket sits below the chat; scroll down to find it, or zoom out with **Ctrl+minus** until the three columns sit side by side. Use synthetic information only.

**3. Find your model call.** The agents send authenticated OTLP requests directly to Azure Monitor's cloud ingestion endpoints. The Application Insights DCR routes spans to `OTelSpans` in the lab's Log Analytics workspace, attributed to your Application Insights resource. Allow a few minutes for ingestion, then run:

```bash
APPI_ID=$(kubectl --context "$CONTROL_CONTEXT" get appenvironment "$APP_ENV" -o jsonpath='{.status.appInsightsResourceId}')
LAW_CUSTOMER_ID=$(az resource show --ids "$LOG_ANALYTICS_WORKSPACE_ID" --query properties.customerId -o tsv)
az monitor log-analytics query --workspace "$LAW_CUSTOMER_ID" \
  --analytics-query "let app = '$APPI_ID'; $(cat "$LAB_ROOT/queries/application-model-call.kql")" \
  -o table
```

The query returns one row per model call made while answering a chat message in the last 30 minutes, filtered to your application's resource. One chat message can make more than one model call.

**Expected result:** at least one row with a `RequestTime` later than the time you noted, `ModelTarget` set to your lab's `openai.azure.com` endpoint, `ModelSuccess` of `True`, and `ModelResult` of `200`. The `TraceId` ties your chat request to that model call.

- **No rows yet:** wait a minute and rerun. If a fresh interaction still produces no rows, check endpoint configuration and exporter authentication errors in [Appendix A](appendix-a-troubleshooting.md#current-application-telemetry-is-missing-or-denied). There is no node receiver or cluster DCR association to warm up.
- **Only older rows:** your new message has not arrived yet, or it was answered without the model. Send another free-text message and rerun.
- **`ModelSuccess` is `False`:** the app answered with a fallback. Check the binding from step 1 and [Appendix A](appendix-a-troubleshooting.md).

To see the same interaction in Azure Portal, open the [Application Insights resource](README.md#application-telemetry), select **Investigate** > **Search** (or the **Tracing** view), and open a request from after the time you noted whose URL ends in `/api/chat`. The list shows these as `POST /`, so check the URL. Skip `/api/confirm` requests: confirming an order calls the MCP tools, not the model. In the end-to-end view, expand **CoffeeConcierge** > **ConciergeRouter** > **lab-model**. Under it, the `aoai-...openai.azure.com:443` dependency should show result `200`. That is the model call, in the same trace as your chat request. Your account can read this telemetry because you are the builder. That does not prove that other users are blocked from it.

## Debrief: what toil disappeared?

**5 minutes. Pause editing.**

Trace the environment request, current Git revision, workload identity, and model interaction. Identify which responsibilities stayed with the application team and which the platform fulfilled.

Discuss whether the supplied connection names are understandable and whether a developer could find the right correction when a binding fails. Trading repeated assembly for an unexplained failure does not reduce toil; it only moves it.

**Takeaway:** pick one app your teams deploy often. Count the values a developer copies by hand today (client IDs, endpoints, keys, namespaces). Each one is a candidate for a platform-published binding the app references by name.

## Catch-up and checkpoint

**5 minutes.**

The checkpoint requires:

- The application is synced to the intended app-repository revision and its Deployments are healthy.
- The supported gateway route serves the application.
- A fresh interaction has correlated evidence of a successful model call.

Record the PR/revision and outcome in the worksheet. If telemetry is pending, the model-evidence checkpoint remains pending even when the application loads.

Compare the application files with the staged scaffolds, the AppEnvironment `status.binding`, and the approved profiles when investigating a mismatch. Guided attendees can ask a proctor to help submit a correction. Record assistance or demonstration-only results honestly. Do not bypass the Gateway by forwarding an application pod's port.

Use [application troubleshooting](appendix-a-troubleshooting.md#application-is-synced-but-not-usable) or [model evidence troubleshooting](appendix-a-troubleshooting.md#model-evidence-is-missing-or-fallback-only) if needed.

**What you learned:** a supported platform connection includes identity, configuration, delivery, and evidence of the application's actual behavior.

---

[Previous: environment contract](2-environment-contract.md) | [Next: complete the self-service interface](4-self-service.md)
