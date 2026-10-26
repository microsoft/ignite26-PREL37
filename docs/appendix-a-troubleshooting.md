# Appendix A: troubleshooting and safe recovery

[Workshop overview](README.md) | [Summary](7-summary.md)

Use this reference when a module checkpoint does not match. Each section names the symptom, explains why it usually happens, and gives the smallest safe fix. The pattern mirrors real platform operations: find the last stage that worked, observe the next one, and repair through the owning path (Git, the controller, or the setup operator) instead of patching around it. It is not an additional exercise or permission to broaden platform access. Module 2's documented wiring is platform-author work; installation and credential repair remain setup responsibilities.

**Guided session:** ask a proctor for help with setup, credentials, or an unresolved checkpoint. Organizers manage the assigned VM, accounts, and local services.

**Self-paced:** you are also the setup operator unless someone provisioned the foundation for you. Use the [setup recovery instructions](../setup/README.md#resume-a-prepared-environment) for local services, credentials, and interrupted preparation. References below to an organizer or proctor mean that authorized helper when you have one; otherwise follow the inspection steps yourself and involve your subscription or repository administrator only when their access is needed. Keep the original files and state while investigating.

## Start with context and the last successful stage

**Why it matters:** a GitOps platform is a chain of handoffs (Git, Argo CD, Crossplane, OpenTofu, Azure, the workload cluster). A symptom usually shows up downstream of its cause, so context and the last good stage save more time than guessing.

Record the module, intended result, actual result, relevant PR and merged commit, Argo CD source revision, and time of the failure. Include the smallest useful error message, not credentials or a full private log dump.

Check that you are using your lab's workspace, repository, and browser account. In your VS Code terminal, run:

```bash
pwd
git status --short
git branch --show-current
kubectl config view -o jsonpath='{.contexts[*].name}{"\n"}'
```

Run Git commands inside the intended repository. The Kubernetes command lists context names from the local kubeconfig without printing credentials. After [workspace initialization](README.md#open-the-prepared-workspace), expect `prel37-control` and `prel37-workload` in `~/prel37/.state/kubeconfig`.

Use `--context "$CONTROL_CONTEXT"` for Argo CD, Crossplane, and `AppEnvironment` observations. Use `--context "$AKS_CONTEXT"` for `beans`, the application, and its route. Argo CD Application objects live on the control cluster even when they deliver workload-cluster resources. If configuration is wrong, compare it with your saved setup inputs or ask the proctor; do not switch subscriptions or elevate permissions by guesswork.

Follow the chain from the last successful stage: installation, provider/delivery wiring, instance mapping, root sync and API establishment, then manual PR review (and any external branch checks), merge, delivery of the new source revision, provisioning or admission, workload health, route, and model evidence.

In a guided session, join the debrief when the practice window ends and use catch-up time for the remaining issue. For self-paced learning, pause at an unresolved checkpoint rather than carrying the failure into the next module. Follow [cleanup](../setup/README.md#resource-teardown) if you decide not to continue the lab.

## Workspace, sign-in, or local service is unavailable

**Symptoms:** `LAB_ROOT` is unset, prepared files are missing, a browser link fails, or Backstage/Argo CD cannot be opened.

**Why it happens:** every new terminal starts without the lab environment variables, and Backstage and the Argo CD tunnel are foreground processes that stop when their terminal closes or the session ends.

Initialize the new terminal using the [overview commands](README.md#open-the-prepared-workspace). On Windows, use Ubuntu WSL rather than PowerShell. Guided attendees should use the assigned VM; self-paced learners use the computer and workspace prepared during setup.

**Guided session:** contact the proctor for missing configuration or services. Organizers own startup, local tunnels, authentication renewal, and VM personalization.

**Self-paced:** use [resume a prepared environment](../setup/README.md#resume-a-prepared-environment) to refresh Azure access and its step 3 to restart Backstage and the Argo CD tunnel. For a missing tool or failed install, return to that setup step without overwriting your workspace.

Expected endpoints are Backstage's guest UI at `http://localhost:3000` with backend `http://localhost:7007`, and Argo CD's local-account UI at `https://localhost:8443`. GitHub browser login is not a login to either service.

Keep the supplied runtime and service names and bind only to loopback. For a certificate warning, use the setup guide's [local service check](../setup/README.md#module-1-readiness); do not bypass an unexpected TLS error. Guided attendees should not substitute personal credentials for their assigned accounts.

The application URL `http://beans.localhost:8080` is expected not to work before Module 3. That is different from an unavailable Backstage or Argo CD link at arrival. Its tunnel goes to the shared Gateway's ClusterIP service so that the HTTPRoute is still tested; do not substitute direct forwarding to an application pod or add custom DNS/public ingress.

## Git has unexpected changes or a check fails

**Symptoms:** the working tree is dirty before an exercise, a merge conflicts, an externally configured branch check fails, or the PR does not merge. No custom validation workflow ships with the lab.

**Why it happens:** most Git surprises come from a branch created on a stale `main`, edits outside the exercise's allowed files, or a token that lacks a permission the controller needs.

Inspect the diff and check output before editing more files. Confirm that the PR contains only the exercise's allowed changes. A failed check is feedback to understand, not an invitation to disable protection.

Ask the proctor before replacing content or resolving a conflict you do not understand. Preserve learner edits. Do not use broad staging, force-push, hard reset, or an administrator merge bypass.

Before every new branch, pull current `main`. In particular, Module 5 must include the Backstage profile change from Module 4. An image-only PR built from a stale branch would revert the `standard` profile.

There is no automatic merge or approval to wait for. Review the allowed diff and manually merge, honoring any externally configured branch checks. If the normal learner account cannot merge an allowed PR, report the repository policy or credential gap. Do not switch to an administrator, create a GitHub App, or add Azure credentials to CI.

Argo CD, Backstage, and provider-opentofu have separately prepared repository credentials. A successful Git push from your terminal does not prove any of them can fetch a private repository. Use the dedicated, repository-scoped tokens from setup rather than substituting your general GitHub login credential.

For expired or missing credentials, guided attendees should ask organizers for repair. Self-paced learners can follow the setup guide's [token renewal and connection steps](../setup/README.md#resume-a-prepared-environment). Preserve exercise edits, update only the affected credentials and Secrets, and restart Backstage so it reloads the token. Repository creation and initial file copying are not part of renewal.

## Platform wiring or request API is not ready

**Module:** [2, guided wiring](2-environment-contract.md#guided-wiring-connect-the-installed-components).

**Why it happens:** each wiring step depends on the one before it. Provider configuration needs healthy packages, the roots need delivery permissions and the EnvironmentConfig, and the `AppEnvironment` API exists only after Argo CD delivers the XRD and Crossplane establishes its CRD.

Before Module 2, no workshop roots or `AppEnvironment` API is the expected fresh state. After applying the roots, their absence or failure to sync identifies a delivery issue. Do not query an `AppEnvironment` until its CRD exists and is Established.

Use the failed checkpoint to choose the next observation:
| Last successful stage | Inspect next | Do not substitute |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Foundation installed | Provider/functions health and configuration CRDs from setup | Reinstalling controllers or applying provider configuration before its API exists |
| Packages healthy | Pinned `ClusterProviderConfig/prel37`, Secret reference, backend account/container/key, and provider runtime identity | Local GitHub login, a storage account key, or a manual OpenTofu run |
| Provider configured | Delivery ClusterRole aggregation and the `platform-system` AppProject from `bootstrap/control.yaml` | Broadening Azure roles to repair Kubernetes RBAC or Argo project restrictions |
| Delivery permissions applied | Local `EnvironmentConfig/prel37`, repository URLs, initial `moduleRevision`, and workload issuer | Regenerating mapping over existing instance data or putting identity IDs into the request |
| Roots applied | `platform-system` source, sync error, XRD and generated CRD | Waiting for a request API before its definition is delivered |

After the roots are applied, these observations inspect delivery and the generated definition without assuming the request API is already available:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd \
  get applications.argoproj.io platform-system platform-requests
kubectl --context "$CONTROL_CONTEXT" -n argocd \
  describe application platform-system
kubectl --context "$CONTROL_CONTEXT" get crd \
  appenvironments.platform.prel37.example --ignore-not-found -o name
```

**Expected result at the wiring checkpoint:** three Synced roots and an Established request CRD, using the waits in Module 2. An empty last result means the CRD has not been created, not that there are zero requests. Authorization or connection errors are not absence. If Argo has not delivered the XRD, inspect its repository/project/sync error first; if the XRD is delivered but the CRD is not established, inspect Crossplane's definition status with a proctor.

Repeat only the failed wiring step for the same instance once its cause is resolved. The pinned apply commands do not overwrite local exercise edits, and existing roots may resume published work immediately. Do not delete a namespace or reset state to reproduce a fresh checkpoint. If credentials are expired, use the setup renewal procedure rather than copying a learner PAT into a controller. Successful wiring alone does not test module retrieval or state authorization; those occur when the Workspace runs.

If stopping before or during wiring, follow [partial-setup cleanup](../setup/README.md#resource-teardown). Do not install the missing API merely to tear down an unused environment.

## Environment request is merged but not ready

**Module:** [2](2-environment-contract.md).

**Why it happens:** a merged request starts a pipeline, not a finished environment. Argo CD delivers the request, Crossplane composes a Workspace, provider-opentofu runs the module against Azure, and only then can Argo CD deliver the baseline. Any stage can stall while earlier stages look green.

First confirm the Module 2 wiring checkpoint passed and `platform-system` delivered the schema-edit revision before the request was submitted. If the API is missing, use [wiring troubleshooting](#platform-wiring-or-request-api-is-not-ready) before running request queries. Then follow `platform-requests`, the `AppEnvironment` and Workspace status on the control cluster, and `beans-dev-baseline` delivering to the workload cluster.

Observe the control-cluster delivery objects, ARM namespace, and workload baseline separately. This identifies the stalled stage rather than assuming a merged request is a usable environment:

```bash
kubectl --context "$CONTROL_CONTEXT" \
  get applications.argoproj.io --all-namespaces
kubectl --context "$CONTROL_CONTEXT" \
  get appenvironments.platform.prel37.example "$APP_ENV"

az aks namespace show \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --cluster-name "$AKS_CLUSTER_NAME" \
  --name "$TEAM"

kubectl --context "$AKS_CONTEXT" \
  get resourcequota,networkpolicy,serviceaccount,configmap -n "$TEAM"
```

Distinguish a rejected request, pending Azure provisioning, failed provider execution, and missing baseline. The correction depends on which stage failed.

If the Workspace is ready but the baseline reports a missing `monitor.azure.com/Instrumentation` API, the delivered baseline chart expects in-cluster collection. The direct-export baseline does not create that resource. Follow [the existing-lab migration](#migrate-an-existing-lab-to-direct-otlp), not an installation of AKS application monitoring or a stand-alone CRD. If the Workspace has no `otlp` output, the Composition waits rather than publishing an incomplete native-export binding.

If the provider cannot retrieve its module, local files and GitHub login are not a substitute. Provider pods on the control cluster use their own authenticated remote source, pinned to `EnvironmentConfig/prel37`'s `data.moduleRevision`, and their own state backend. Setup initially pins the first platform commit. The remote module's configuration is `opentofu/managed-namespace/main.tf`, with provider selections in the adjacent `.terraform.lock.hcl`, separate from `infra/main.tf` and its state. Do not create companion variable/output files or run a local plan/apply to repair a controller problem.

If `beans` already exists unexpectedly on a fresh first pass, stop. Do not adopt it or delete it manually. When resuming an already completed request on the same instance, that namespace is expected: inspect the existing request, Workspace, and state instead of trying to vend a second environment. The approved path owns its lifecycle.

The controller owns the managed namespace, per-agent identities and federation, model and DCR-publisher assignments, and Application Insights resource; Argo CD delivers the baseline from their outputs. A provisioning error can prevent baseline creation even when the namespace exists. Inspect the Workspace error rather than inserting an identity, endpoint, or token manually. A denied `telemetry_access` assignment needs the setup operator to check the bootstrap's constrained telemetry-publisher delegation on the generated DCR's subscription. Learners do not add IAM permissions. Authorization-isolation testing remains outside this lab.

### Migrate an existing lab to direct OTLP

**Setup-operator work.** Use this when an initialized lab's platform repository or execution pin lacks the direct OTLP export path in this source. Updating this source checkout does not update an initialized private platform repository or its saved execution pin. Keep the current request, namespace, Workspace, state backend, and learner changes.

1. Have the bootstrap operator review and apply the current `infra/main.tf` using the existing bootstrap state. The provisioner needs the constrained `Monitoring Metrics Publisher` delegation because the DCR lives in an Azure-managed resource group. Do not grant subscription Owner or ask learners to create role assignments. This application path does not require AKS `appMonitoring`; omission from an update payload alone does not prove that an enabled feature is disabled.
2. Merge the reviewed changes to `api/composition.yaml`, `opentofu/managed-namespace/main.tf`, and both charts into the lab's private platform repository. Preserve exercise edits, including the required cost-center field. The module removes only the cluster DCR association used by in-cluster collection, retains the Application Insights resource and managed ingestion resources, and adds agent publisher grants. Do not delete the Workspace or edit state.
3. Update `data.moduleRevision` in the saved `$LAB_ROOT/config/environment.yaml` to that full merged commit SHA, then apply that file with the same control context used in Module 2. Both the module and charts use this pin. The Composition arrives from `main` first and tolerates outputs without `otlp`, but the native-export contract stays unready until the updated module produces `otlp`.
4. Inspect Workspace conditions and the baseline's sync error. The module rejects a DCR without direct OTLP data sources or a single metrics stream rather than guessing a URL. Compare the vended URLs with the resource's **OTLP Connection Info** before the first live rehearsal. Repeat Module 2's baseline, HTTPS-endpoint, and binding checks. No `Instrumentation` resource or node-receiver wait is expected.
5. Before deploying or resuming the app, check the [pinned Fourth Coffee artifacts](../setup/README.md#application-artifact-prerequisite). Release `0.1.0-12.1.ge412f12` includes token renewal; an exporter-selection-only image or a static token does not. Apply the reviewed adapter, image schema, staged values, and artifact lock together. Update existing app-deploy values through a PR so Module 5's recovery restores that same image.
6. If existing pods still hold stale environment variables after the approved image and baseline are delivered, perform a controlled restart of `concierge` and `ops-agent` to reload the ConfigMap. Then send a fresh chat and prove the model dependency in `OTelSpans`. Do not treat a green AppEnvironment or historical trace as proof that native export works.

### Switch an existing lab to Fourth Coffee

**Setup-operator work.** The source defaults use team `beans`, request `beans-dev`, and application `fourth-coffee`, but an initialized environment must not be reset merely to rename the demo. An initialized lab may use other names, such as `scoops` and `scoops-dev`. Keep its existing team, namespace, request, Azure resources, and state in place; Kubernetes namespaces are not renamed by editing a lab example.

First read the existing application identifier:

```bash
source "$LAB_ROOT/config/lab.env"
APP_NAME="$(kubectl --context "$CONTROL_CONTEXT" get appenvironment "$APP_ENV" \
  -o jsonpath='{.spec.application}')"
export APP_NAME
```

Keep that request's `metadata.name`, `spec.team`, and `spec.application`. The application identifier also names the composed Argo CD Application and `apps/$APP_NAME/`; renaming it can replace controller-owned delivery objects. `make connect` preserves the saved team, application, and request names unless you explicitly override them. A fresh lab uses the default names, while an existing identifier can continue delivering the Fourth Coffee image. Do not change an existing `spec.team` or request name merely to match the examples.

1. Merge the reviewed `charts/fourth-coffee` adapter, API changes, and approved profiles into the private platform repository, preserving the learner's schema edits. Set the existing request's `spec.chart` to `fourth-coffee` through Git.
2. Keep the catalog component's identifier, owning group, delivery link, and the local Backstage guest ownership reference aligned with the existing environment. Update the application description to Fourth Coffee without replacing the team or introducing a second delivery Application. Fresh catalogs and guest configuration use `group:default/beans`; an initialized catalog can retain its existing owner.
3. Advance `data.moduleRevision` in the saved `$LAB_ROOT/config/environment.yaml` to the full merged platform commit and apply that mapping as in Module 2. The Composition arrives from `main`; the chart and module remain pinned. Finish the pin update before treating an intermediate missing-chart error as a new provisioning problem. If the lab also lacks direct OTLP export, complete [that migration](#migrate-an-existing-lab-to-direct-otlp), including the bootstrap's publisher delegation.
4. In `apps/$APP_NAME/values.yaml`, update the approved image tag to `0.1.0-12.1.ge412f12`. Rename the profile's MCP key to `fourthCoffeeMcp` while preserving its selected `small` or `standard` resources. Replace any explicit MCP endpoint override with `FOURTH_COFFEE_MCP_URL` pointing to `http://fourth-coffee-mcp:8101/mcp/`. Submit and merge these changes through the existing app-deploy repository.
5. Update the prepared `config/artifact-lock.json` application's metadata from the verified source lock, keeping unrelated artifact selections intact. Refresh the staged exercise values and profile deliberately; re-running setup does not overwrite initialized files.
6. Verify `fourth-coffee-mcp`, `ops-agent`, and `concierge` are ready and use the pinned digest. Argo CD's normal pruning removes superseded application-owned resources; do not manually remove the namespace, Workspace, identities, or state. The shared Gateway and `http://beans.localhost:8080` route stay unchanged. Send a fresh coffee request and prove its successful model call before continuing.

### Provider initialization fails

**Why it happens:** `Synced=True` on the composite only means Crossplane rendered its resources. The OpenTofu run inside the Workspace can still fail on provider selection, module retrieval, or Azure authorization, and that error lives in the Workspace conditions.

Read the Workspace rather than treating the composite's `Synced=True` as proof of successful Azure provisioning:

```bash
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system \
  describe workspaces.opentofu.m.upbound.io "$APP_ENV"
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system \
  get workspaces.opentofu.m.upbound.io "$APP_ENV" \
  -o jsonpath='{.spec.forProvider.module}{"\n"}'
kubectl --context "$CONTROL_CONTEXT" get environmentconfigs.apiextensions.crossplane.io prel37 \
  -o jsonpath='{.data.moduleRevision}{"\n"}'
```

The provider may compress the full OpenTofu error into the condition message. Decode its Base64/gzip payload as data to read the diagnostic; do not execute arbitrary commands copied from error text or share credentials from logs.

Distinguish these failures:

- **`locked provider ... 5.9.0 does not match configured version constraint ~> 4.0`:**
  the module and lock file disagree. This lab pins AzureRM `= 5.9.0` and AzAPI `= 2.13.0`. Restore matching constraints and lock selections; a controller restart cannot fix a mismatch committed in Git.
- **`Required plugins are not installed ... no package ... cached in .terraform/providers`:**
  the selected plugin is missing from the initialized workspace. This is not proof of provider-version incompatibility. Compare the full registry source address in the error, module, and lock file. The controller module explicitly uses `registry.opentofu.org/hashicorp/azurerm` and `registry.terraform.io/Azure/azapi`; the lock file normalizes the AzAPI namespace to lowercase. OpenTofu's lock-file migration can add an OpenTofu registry entry for a HashiCorp provider installed from the Terraform registry, leaving workspace selection looking for an uninstalled provider address. Use the OpenTofu registry for AzureRM in this module and regenerate the lock file from that registry. Do not copy checksums between registries. The bootstrap Terraform root is separate and unchanged. If the addresses already match, investigate download/init errors and cache paths before considering a controlled restart.
  **Platform-author recovery:** publish matching `main.tf` and `.terraform.lock.hcl` changes together in the private platform repository. If deliberately changing a provider version, regenerate its lock file in a clean maintenance copy with `tofu init -backend=false -upgrade` and review the selections. This is dependency maintenance, not permission to run a local plan/apply against controller-owned state. Do not downgrade solely because a plugin is missing.
  After the change is merged, update `data.moduleRevision` in the lab's saved `$LAB_ROOT/config/environment.yaml` to the full merged commit SHA and apply that file to the control cluster. Review the pinned module and baseline chart at that revision, since both use the same setting. Verify that the Workspace's module URL contains the merged SHA. Local edits or a push to `main` alone do not advance this pin; `remotePullPolicy: IfNotPresent` reuses the module until its URL changes. Preserve the Workspace and its state.
  provider-opentofu is separately pinned to `v1.1.10` in `bootstrap/packages.yaml`. Updating that package does not change the module's provider constraints, lock file, or revision. Use the setup installation step for a reviewed package update, then inspect Workspace conditions again. An upgrade is not evidence that the original initialization failure is resolved.

## Application is synced but not usable

**Module:** [3](3-application-delivery.md).

**Why it happens:** Argo CD reports `Synced` when the cluster matches Git, not when the app works. Admission denials, quota, scheduling, a misplaced values file, or a broken route can all leave a synced Application unusable.

Check the **app-repository** source revision as well as sync/health. Multi-source Applications have more than one revision; a chart commit is not your merged configuration commit.

Inspect the supplied resources:

```bash
kubectl --context "$AKS_CONTEXT" \
  get deployments,pods,services,httproutes -n "$TEAM"
kubectl --context "$AKS_CONTEXT" describe deployment concierge -n "$TEAM"
kubectl --context "$AKS_CONTEXT" \
  get events -n "$TEAM" --sort-by=.metadata.creationTimestamp
```

Look for unavailable replicas, admission denials, scheduling/quota issues, or route conditions. When the failed component is `ops-agent` or `fourth-coffee-mcp`, inspect that named Deployment rather than assuming the concierge is responsible.

Verify that both staged files were copied: `values.yaml` and `profile.yaml`. If Argo CD still reports `values.yaml` not found, check the path against `status.binding.configPath` on the AppEnvironment. In base values, `extraEnvFrom[0].configMapRef.name` must match `status.binding.configMapName` (`platform-context`). Do not add a ServiceAccount name; the platform's Argo CD Application assigns `concierge` and `ops-agent` and the chart schema rejects any other mapping. Preserve the image, component flags, and values order: base `values.yaml` followed by app-local `profile.yaml`. Do not add a `$profiles` value-file reference or enable Namespace/quota creation.

If the route fails, preserve its condition and ask the proctor to inspect the shared Gateway, HTTPRoute, ClusterIP service, loopback tunnel, and baseline ingress network exception. Do not expose another LoadBalancer or bypass the route with application-pod forwarding.

Unexpected injected resources or extra pods can invalidate the prepared capacity assumptions. Do not increase quota or remove limits to finish the exercise.

## Model evidence is missing or fallback-only

**Module:** [3](3-application-delivery.md).

**Why it happens:** telemetry arrives after a 2-5 minute ingestion delay, and the agent falls back to a canned answer when the model call fails. A plausible reply is not proof that the model was called.

Run the query from [Module 3, step 7](3-application-delivery.md#7-verify-a-fresh-model-interaction). It reads the last 30 minutes of `OTelSpans` for the `beans` Application Insights resource. If it fails with an extension prompt, run `az extension add --name log-analytics` and retry. If it returns nothing, wait 2-5 minutes for ingestion and send a new free-text chat message.

A page load, health probe, attempted call, plausible response, or historical trace is insufficient. Find the successful model dependency belonging to your fresh interaction.

If ingestion is delayed, record evidence pending and return during catch-up. Do not substitute an old trace.

If the model returns an authorization error, the proctor should inspect the binding, the **workload-cluster** issuer for `beans/concierge` or `beans/ops-agent` (whichever agent failed), and existing model authorization. Learners do not add a model API key or grant a broader role.

Verify the [direct-export artifact prerequisite](../setup/README.md#application-artifact-prerequisite) and the prepared ConfigMap with a proctor. The pinned Fourth Coffee image supports authenticated export; other images may only select an exporter. Confirm the actual running digest and `OTEL_EXPORTER_OTLP_AUTH_MODE=workload_identity` before investigating token or DCR errors. Do not substitute a classic exporter, local-auth key, or static bearer token.

## Backstage shows an old template or no usable result

**Module:** [4](4-self-service.md).

**Why it happens:** Backstage reads templates and catalog files from platform `main` on GitHub, not from your clone, refreshes them on a schedule, and acts with its own token. A missing token permission or an unmerged PR looks like stale or empty UI.

If the **Application** picker is empty, or the catalog has no `beans` group or `fourth-coffee` component, the Backstage token can't read commit statuses, which the catalog needs to read `catalog/*.yaml`. Add **Commit statuses: Read-only** to the Backstage token in GitHub (the token value doesn't change), then stop and rerun `make backstage`. See the [setup guide's token permissions](../setup/README.md#github-tokens).

For an old form, first confirm the change is on platform `main` in GitHub, since Backstage reads the template from there, not from your clone:

```bash
cd "$LAB_ROOT/platform"
git fetch origin
git show origin/main:backstage/templates/ai-app/template.yaml | grep -E 'description: Choose|enum:'
```

If the output still shows `enum: [small]`, the template PR has not merged; finish [Module 4, step 2](4-self-service.md#2-add-the-standard-profile-to-the-selector). If it shows `enum: [small, standard]`, open `http://localhost:3000/catalog/default/template/app-profile`, select **Refresh** on the **About** card, wait about 10 seconds, and reload the form. To see what Backstage actually published, open the template entity, select the three-dot menu, choose **Inspect entity**, and open **Raw YAML**. Compare `spec.parameters` with the merged file on platform `main`. Do not create a duplicate template or assume a local edit is published.

For a failed task, preserve the task reference and inspect whether a PR was created. Avoid repeatedly submitting the same task before checking its result.

If **Propose the profile change** fails with `Resource not accessible by personal access token`, the Backstage token can push branches but not open PRs. It needs **Pull requests: Read and write** in addition to **Contents: Read and write**; see the [setup guide's token permissions](../setup/README.md#github-tokens). After fixing the token, restart Backstage and delete the orphaned branch before you run the template again:

```bash
cd "$LAB_ROOT/app-deploy"
gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/backstage/$APP_NAME-profile-standard"
```

Before resubmitting, compare the current `profile.yaml` on app-repository `main` with the requested canonical profile. A repeated request for identical content can legitimately yield no new PR. Record that no-change result rather than expecting a rollout.

For a generated PR, manually inspect the diff. It must change only `apps/fourth-coffee/profile.yaml` to the exact approved `platform/profiles/workload-small.yaml` or `workload-standard.yaml` content. The native `fetch:plain:file` and `publish:github:pull-request` steps must preserve `values.yaml`, including identity and image. The Application's destination and access are platform-owned and not in the app repository. Do not implement a custom action to repair a preparation mismatch.

Manually merge an allowed PR after review, honoring any externally configured branch checks. A task waiting on a merge is not evidence that an automatic merger is broken; no such merger is part of the lab.

For a completed task with no rollout, follow the generated PR's merged revision in Argo CD. Task completion records submission, not application readiness.

If an update is stale or unauthorized, do not weaken validation. A proctor can help compare the current source and intended change while preserving unrelated work.

## The seeded failure does not match or recovery is stuck

**Module:** [5](5-operate-and-recover.md).

**Why it happens:** the safeguard under test is AKS Deployment Safeguards admission rejecting a mutable `:latest` image. If something else fails first (a branch check, the chart, an image pull), you see a different error. During recovery, Argo CD finishes retrying the rejected revision before it applies the fix.

The required fixture changes only `image.tag` to `latest`. Normal deployments render the locked digest; this explicit teaching fixture instead renders `:latest`. The expected failure is an admission-policy rejection.

The chart schema supports the locked tag or `latest`; there is no custom CI permissive exception. If an external branch check rejects the change first, record that enforcement point and ask the proctor to inspect the repository policy. If the rendered desired image remains digest-pinned for this fixture, ask organizers to inspect the chart/configuration rather than removing digest pinning yourself. Existing running Pods may remain on the locked digest while the update is denied. If an image-pull error occurs, it is not evidence of the intended safeguard.

Do not disable checks or policy to force the demonstration. Missing resource requests are not a substitute fixture because AKS Automatic may inject defaults.

For recovery, use native `jq` as shown in [Module 5](5-operate-and-recover.md#4-restore-the-approved-tag-through-git) to read `.application.imageTag` from `config/artifact-lock.json`. If the lookup fails or the value is empty or `latest`, stop; do not guess a tag. Restoring the locked tag restores the digest-pinned desired image. Check that the recovery PR preserves `profile.yaml` at `standard` and changes only the expected base value.

After merge, compare the app-repository revision, successful sync, workload health, and route. Existing healthy pods may remain throughout the rejection and recovery. A restart is not required evidence.

**Recovery stays `OutOfSync` for several minutes after the fix merged:** Argo CD is still retrying the rejected commit. Each Application retries a failed sync five times with a backoff that starts at 10 seconds and doubles up to 2 minutes. Check the attempt count:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd get application "$APP_NAME" \
  -o jsonpath='{.status.operationState.phase}{"\n"}{.status.operationState.message}{"\n"}' | grep -oE '^Running|^Succeeded|^Failed|Retrying attempt #[0-9]+'
```

If the phase is `Running` and the message says `Retrying attempt #N`, wait. After the fifth attempt Argo CD moves on to your fix, usually within about five minutes of it merging. Do not delete the Application or patch the Deployments to hurry it.

## Current application telemetry is missing or denied

**Module:** [5](5-operate-and-recover.md), instructor/organizer follow-up.

**Why it happens:** each agent exports OTLP directly to Azure Monitor with its own workload identity. Missing spans usually trace to the image, the token, the DCR grant, or the endpoint URL, and the HTTP status code tells you which.

Check the prepared account, time window, and current interaction's trace ID using the [application telemetry resource](README.md#application-telemetry) and the query in [Module 3, step 7](3-application-delivery.md#7-verify-a-fresh-model-interaction). Read `beans` container output with the `kubectl logs` command in [Module 5](5-operate-and-recover.md#demonstrate-inspect-current-application-telemetry). Cluster-level Container Insights collection is separate; a container log record does not prove native OTLP spans arrived.

If no spans arrive, check the export path in your VS Code terminal:

```bash
kubectl --context "$AKS_CONTEXT" -n "$TEAM" logs deploy/concierge --since=10m
kubectl --context "$AKS_CONTEXT" -n "$TEAM" logs deploy/ops-agent --since=10m
kubectl --context "$AKS_CONTEXT" -n "$TEAM" get configmap platform-context -o json |
  jq '.data | {OTEL_EXPORTER_OTLP_TRACES_ENDPOINT,
               OTEL_EXPORTER_OTLP_LOGS_ENDPOINT,
               OTEL_EXPORTER_OTLP_METRICS_ENDPOINT,
               OTEL_RESOURCE_ATTRIBUTES}'
```

- **HTTP 401 or token acquisition failures:** verify the approved image, workload-identity environment and token-file mount, the workload-cluster issuer, and the `https://monitor.azure.com/.default` audience. A connection string does not authenticate native OTLP.
- **HTTP 403:** the setup operator checks the exporting agent's `Monitoring Metrics Publisher` assignment on the DCR named by that endpoint, including propagation of a newly created assignment. `Monitoring Reader` on Application Insights is not an ingestion grant.
- **HTTP 404 or an invalid-stream error:** compare each complete URL with **OTLP Connection Info**. The metrics stream is discovered from the DCR and is case-sensitive. Do not use the classic connection string's ingestion URL as an OTLP URL.
- **Node-IP, localhost, or port 28331/28333 endpoints:** the pod has stale in-cluster collector configuration. Follow [the migration steps](#migrate-an-existing-lab-to-direct-otlp); there is no node collector to wait for on this path.
- **Export works initially, then fails:** verify application token renewal. A static bearer header is not a durable fix.
- **Export succeeds but the resource-filtered query is empty:** verify the generated DCR's workspace destination and the `microsoft.applicationId` resource attribute. For this contract it contains the connection string's `InstrumentationKey` GUID, not the ARM resource ID used by the query's `_ResourceId` filter.

`fourth-coffee-mcp` has SDK telemetry disabled because it has no Azure identity. Its stdout remains available. Do not grant it model access to enable telemetry.

If records are still missing, check ingestion and the current application interaction with the organizer. Record pending or blocked evidence rather than substituting historical records. For denied queries, preserve the error and ask the organizer to inspect the prepared access; do not broaden permissions.

Telemetry access control and authorization-isolation testing are outside this lab's scope. There are no viewer grants or foreign-data fixtures to repair. Neither an empty result nor a successful builder query proves isolation. Use the [setup guide](../setup/README.md) for preparation issues.

## Billing or usage evidence is incomplete

**Module:** [5](5-operate-and-recover.md).

**Why it happens:** Azure cost data lags, and a namespace created today has no billing history yet.

Use the prepared historical or explicitly illustrative evidence and its assumptions. Newly created namespaces do not have historical billing data, and current cost reporting may lag.

Do not label a sample's costs as your deployment's costs. If the evidence does not justify a profile recommendation, record that uncertainty and the measurement needed.

Do not install a billing tool, invent a rate, or compute guaranteed savings from a requests-only comparison to fill the gap.

## Recover without hiding the result

Proctors use staged exercise scaffolds and approved source files for comparison, not as a reset operation. Preserve learner work and submit the smallest correction through the owning Git path.

Ask before replacing learner content. Keep the same request, namespace, controller, and state. A preparation failure stays blocked until repaired; watching a demonstration can support learning but does not turn it into independent completion.

Record the intervention in `answers/product-brief.md`. Do not export private state or credentials with the worksheet.

---

[Back to workshop overview](README.md) | [Summary and take-home material](7-summary.md)
