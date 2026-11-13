# Optional: vend the next environment from Backstage

[Workshop overview](README.md) | [Previous: summary](7-summary.md)
**Duration:** about 25 minutes, most of it waiting for Azure. This exercise is optional. Do it after you finish Modules 1 to 7, never in place of a module or a break.

## Objectives

By the end of this exercise, you will be able to:

- Request a complete application environment from one Backstage form.
- Explain why the platform's real test is the second environment, not the first.
- Compare two environments and confirm they share the pattern but not the resources.

> **Platform concept: a golden path is the path you can repeat.** In Modules 2 and 3 you built the first environment by hand: a contract change, a request file, a binding, and a configuration PR. A platform earns its keep when the next team, or the next environment for the same team, needs none of that knowledge. In the BACK stack, **Backstage** collects the intent, **Argo CD** applies the request and delivers the app, **Crossplane** composes the environment, and **Kubernetes** runs it. The form is new. Nothing behind it is.

**Starting state:** you finished Module 5, so `fourth-coffee` runs healthy in `beans`. Backstage (`http://localhost:3000`), the Argo CD tunnel (`https://localhost:8443`), and the application tunnel are running. If any stopped, restart it with the [setup guide's resume path](../setup/README.md#resume-a-prepared-environment).

You create a second environment, `beans-prod`, for a second copy of the same application, `fourth-coffee-prod`. In this lab it uses the same `ai-dev` namespace class and the same approved image. A real production class would usually add stricter policy, approvals, or a separate cluster, and a real golden path would often scaffold source code and CI as well. This exercise skips both to stay within the approved, prebuilt workload.

## Repeat the golden path

A platform proves its value when it can repeat a success. The first environment, built in Modules 2 and 3, took manual wiring and specific knowledge. A golden path replaces that with a supported route that is also the easiest one. Requesting a second environment tests whether the platform really hides the complexity of the first.

The **AI application environment** template in Backstage implements this path. It turns intent into implementation in five steps:

| Stage          | Backstage action              | Result                                                                    |
| :------------- | :---------------------------- | :------------------------------------------------------------------------ |
| **1. Intent**  | `fetch:template`              | Authors `requests/<namespace>.yaml` and the catalog entry.                |
| **2. Tuning**  | `fetch:template`              | Authors `apps/<application>/values.yaml` with the correct contract names. |
| **3. Sizing**  | `fetch:plain:file`            | Copies the approved `profile.yaml` for the chosen resource class.         |
| **4. Request** | `publish:github:pull-request` | Opens a PR in **platform** to trigger the environment provisioning.       |
| **5. Config**  | `publish:github:pull-request` | Opens a PR in **app-deploy** to provide the app's configuration.          |

Because the golden path is a series of Git operations, every environment has an audit trail, and the developer never needs to know where the files live or how they are named.

### Identity comes from the platform

The form never asks for a client ID or a model endpoint. The platform creates a managed identity for each model-calling agent and federates it to the namespace _before_ the application deploys, so each agent runs as its identity from the first pod. The developer manages no secrets and never touches the OIDC trust chain. The form only supplies intent, such as the namespace and team.

### Check that the pattern holds

In step 8 you compare `beans-dev` and `beans-prod`. Two environments on the same `standard` profile should match in resource requests, identity pattern, and telemetry routing, and differ only in names and cost attribution. If they behave differently, the platform is leaking implementation details and the golden path is not consistent.

## Guided practice: request, approve, and use the next environment

### 1. Read the template

In the VS Code Explorer, expand 🏗️ **Platform** > **backstage** > **templates** > **app-environment** and open **template.yaml**. Read the `parameters`, then the five `steps`. Then expand **skeleton** in the same folder and open its three files.

Compare `skeleton/platform/requests/${{values.team}}.yaml` with your own `requests/beans-dev.yaml`. They have the same fields. The only difference is that Backstage fills them in. Compare `skeleton/app-deploy/apps/${{values.application}}/values.yaml` with 🚀 **App-Deploy** > **apps** > **fourth-coffee** > **values.yaml**. The `platform-context` name you copied from the binding in Module 3 is the same in every environment, so the template can write it for you. The platform assigns the agent ServiceAccounts in every environment, so the template does not mention them.

### 2. Find your Entra object ID

The form asks for it so that you get AKS desktop access to the new namespace and read access to its telemetry. In your VS Code terminal, run:

```bash
az ad signed-in-user show --query id -o tsv
```

**Expected result:** one GUID. Copy it.

### 3. Request the environment

Open `http://localhost:3000/create/templates/default/app-environment`. You can also find **AI application environment** on the **Create** page. If it is missing, open `http://localhost:3000/catalog/default/template/app-environment` and select **Refresh** on the **About** card.

Fill in the form:

| Field                 | Value                | Why                                                                                  |
| --------------------- | -------------------- | ------------------------------------------------------------------------------------ |
| Environment namespace | `beans-prod`         | Names the managed namespace, its Azure resources, and `beans-prod.localhost`         |
| Application name      | `fourth-coffee-prod` | Names the Argo CD Application and the `apps/` folder. Must not reuse `fourth-coffee` |
| Owning team           | `beans`              | The catalog owner                                                                    |
| Cost center           | `CC-1043`            | A different cost center, so you can see attribution separate the two                 |
| Your Entra object ID  | the GUID from step 2 | AKS desktop and telemetry access                                                     |
| Resource profile      | `standard`           | The approved profile, chosen up front this time                                      |

Select **Review**, check the values, then select **Create**.

**Expected result:** within a minute all five steps complete and four buttons appear: the two PRs (numbered in merge order), **Follow application delivery in Argo CD**, and **Open the application**. Backstage opened both PRs. It merged neither.

### 4. Review and merge the configuration PR first

Merge order matters. The configuration is inert until the platform creates the environment's Argo CD Application, so merging it first means the app deploys the moment the environment is ready.

```bash
cd "$LAB_ROOT/app-deploy"
git checkout main && git pull origin main
gh pr diff backstage/fourth-coffee-prod-config --name-only
gh pr diff backstage/fourth-coffee-prod-config
```

**Expected result:** exactly two new files, `apps/fourth-coffee-prod/profile.yaml` and `apps/fourth-coffee-prod/values.yaml`. `values.yaml` references `platform-context`, names no ServiceAccount, and sets no image tag, so the platform chart's digest-pinned image is used. Merge it:

```bash
gh pr merge backstage/fourth-coffee-prod-config --merge --delete-branch
kubectl --context "$CONTROL_CONTEXT" -n argocd get application fourth-coffee-prod
```

**Expected result:** the merge succeeds, and `kubectl` returns `NotFound`. Nothing deployed, because no environment exists yet.

### 5. Approve the environment request

Now act as the platform reviewer. This PR is the approval gate: merging it starts real Azure provisioning.

```bash
cd "$LAB_ROOT/platform"
git checkout main && git pull origin main
gh pr diff backstage/beans-prod-environment --name-only
gh pr diff backstage/beans-prod-environment
```

**Expected result:** two new files, `catalog/fourth-coffee-prod.yaml` and `requests/beans-prod.yaml`. In the request, `team` is `beans-prod`, `costCenter` is `CC-1043`, and `requesterObjectId` is your GUID. If anything else changed, do not merge. Then merge it and ask Argo CD to check for the request now:

```bash
gh pr merge backstage/beans-prod-environment --merge --delete-branch
kubectl --context "$CONTROL_CONTEXT" -n argocd annotate application platform-requests argocd.argoproj.io/refresh=normal --overwrite
```

### 6. Wait for fulfillment

This is the same chain you traced in Module 2. Expect about 6 to 7 minutes for the environment, then a few minutes for the first rollout.

```bash
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Ready appenvironment beans-prod --timeout=15m
kubectl --context "$CONTROL_CONTEXT" -n argocd wait application/fourth-coffee-prod --for=jsonpath='{.status.health.status}'=Healthy --timeout=600s
for d in concierge ops-agent fourth-coffee-mcp; do
  kubectl --context "$AKS_CONTEXT" -n beans-prod rollout status deployment/"$d" --timeout=300s
done
```

**Expected result:** `condition met` twice, then `successfully rolled out` for all three Deployments. If the first wait times out, use [environment request is merged but not ready](appendix-a-troubleshooting.md#environment-request-is-merged-but-not-ready). If `fourth-coffee-prod` is missing or reports `values.yaml: no such file or directory`, check that the configuration PR from step 4 merged.

You did not read a binding, fill a blank, or open a third PR.

### 7. Use the new environment

Open `http://beans-prod.localhost:8080` in your browser. The same application tunnel serves both environments, because each HTTPRoute matches its own host. Start a chat to confirm the model call works with the new environment's identity.

In Backstage, open **Catalog**. Within a few minutes `fourth-coffee-prod` appears next to `fourth-coffee`, owned by `beans`, with links to the app, its Argo CD Application, and its configuration folder.

### 8. Compare the two environments

Same pattern, separate resources. Run each check and compare the two rows:

```bash
kubectl --context "$AKS_CONTEXT" get namespace beans beans-prod -L platform.prel37.example/cost-center
az resource list -g "$AKS_RESOURCE_GROUP" \
  --query "[?tags.team=='beans' || tags.team=='beans-prod'].{name:name, team:tags.team, costCenter:tags.\"cost-center\"}" -o table
kubectl --context "$CONTROL_CONTEXT" -n argocd get appprojects beans-dev beans-prod
```

**Expected result:**

| Check                 | `beans-dev`                                                                | `beans-prod`                                                                         |
| --------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Namespace cost center | `CC-1042`                                                                  | `CC-1043`                                                                            |
| Agent identities      | `id-prel37-<lab-id>-beans-concierge`, `id-prel37-<lab-id>-beans-ops-agent` | `id-prel37-<lab-id>-beans-prod-concierge`, `id-prel37-<lab-id>-beans-prod-ops-agent` |
| Telemetry             | `appi-prel37-<lab-id>-beans`                                               | `appi-prel37-<lab-id>-beans-prod`                                                    |
| Delivery boundary     | AppProject `beans-dev`, limited to `beans`                                 | AppProject `beans-prod`, limited to `beans-prod`                                     |
| Address               | `http://beans.localhost:8080`                                              | `http://beans-prod.localhost:8080`                                                   |

Each environment has its own identity, telemetry, quota, cost attribution, and delivery boundary, all from one contract. A model call from `beans-prod` lands in its own Application Insights resource, not in the one you queried in Module 3.

## Debrief: what did the second environment cost?

Count what you did for `beans-dev` in Modules 2 and 3 against what you did here. The first time took a contract change, a request file, a binding lookup, a blank, and two PRs written by hand. This time took one form and two reviews. The difference is the developer toil the platform removed.

Then look at what stayed the same: the request is still a reviewed PR, the platform still approves by merging, and the controllers still enforce the contract. The form made the path faster without creating a second, less-governed one.

**Takeaway:** after your platform vends its first environment by hand, write down every value you had to look up or copy. Each one is either intent the form should ask for, or wiring the platform should supply. When the list is empty of wiring, you have a golden path, and the next team, and the one after it, follow the same route.

## Clean up

`beans-prod` runs three more Deployments and keeps its own Azure resources, so it adds cost while it exists. The [setup teardown](../setup/README.md#resource-teardown) removes it together with the rest of the lab. Do not delete the namespace, identity, or Application Insights resource by hand.

---

[Workshop overview](README.md) | [Previous: summary](7-summary.md)
