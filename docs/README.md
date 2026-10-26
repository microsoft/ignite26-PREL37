# Platform engineering on AKS: a paved road to AI apps

## Overview

An application team needs a supported place to run an AI application, a safe way to change it, and operating information it can use, without assembling the platform itself. In this workshop you build one thin slice of an internal developer platform that serves that need, then use it the way a developer would.

You wire the platform's provisioning and delivery paths, tighten an environment contract, connect a supplied AI application to platform-provided identity and configuration, publish a constrained self-service choice in Backstage, and recover from a rejected deployment. You finish by using operating evidence to choose the next platform improvement.

The tools are the hands-on vehicle; the fundamentals are the point: what a platform team builds, why, and how to tell whether it is working. Each module calls out the fundamental it teaches and ends with a takeaway you can use with your own platform team.

## Platform engineering fundamentals you will practice

| Fundamental                     | What it means                                                                                                | Where you practice it |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------ | --------------------- |
| Platform as a product           | Start from a developer task and a promise you can keep, not from a tool list.                                | Module 1, Module 6    |
| Self-service through a contract | Developers ask for an outcome through a small, versioned API. The platform decides how to fulfill it.        | Module 2              |
| Golden paths                    | The supported way is also the easiest way: prepared templates, defaults, and a few constrained choices.      | Modules 3 and 4       |
| GitOps as the change path       | Git holds desired state. Every change is a reviewed pull request, and controllers reconcile it.              | Modules 2 to 5        |
| Guardrails, not gates           | Schema validation and admission policy stop unsafe changes automatically, so nobody waits on a ticket queue. | Modules 2 and 5       |
| Clear ownership                 | Platform, application, and controller responsibilities stay separate. Each resource has exactly one owner.   | Every module          |
| Evidence and feedback           | Telemetry, status, and cost data tell you whether the promise holds and what to improve next.                | Modules 3, 5, and 6   |

## The BACK stack

This workshop uses a common open source combination sometimes called the BACK stack. You will touch each part:

| Letter | Component        | Role in this platform                                                                                            | First hands-on use |
| ------ | ---------------- | ---------------------------------------------------------------------------------------------------------------- | ------------------ |
| B      | Backstage        | Developer portal. A software template offers one constrained choice and opens a pull request for review.         | Module 4           |
| A      | Argo CD          | GitOps delivery. Watches the platform and application repositories and applies what is merged to `main`.         | Module 2           |
| C      | Crossplane       | Platform API. Defines the `AppEnvironment` request and composes it into Azure resources and Kubernetes delivery. | Module 2           |
| K      | Kubernetes (AKS) | Runtime. A control cluster runs the platform controllers; an AKS Automatic workload cluster runs applications.   | Module 2           |

Crossplane runs an OpenTofu module (through provider-opentofu) to create the Azure resources, so the infrastructure code stays readable Terraform-compatible HCL rather than a custom controller.

## What you will build

The platform serves the `beans` application team and its supplied [Fourth Coffee application](https://github.com/pauldotyu/fourth-coffee): a concierge, an operations agent, and a Model Context Protocol (MCP) service that call an already hosted model. You do not write agents or provision GPUs.

The lab uses team and namespace `beans`, request `beans-dev`, and application `fourth-coffee`. If your lab instance uses different identifiers, see [switch an existing lab to Fourth Coffee](appendix-a-troubleshooting.md#switch-an-existing-lab-to-fourth-coffee). Renaming the example does not rename a live namespace or recreate its Azure resources.

One environment request, `beans-dev`, vends everything the team needs to run:

- an AKS managed namespace, `beans`, with quota and default policy
- one managed identity per agent, each federated to its own ServiceAccount, with access to the shared model
- an Application Insights resource for the team's telemetry
- namespace access for the requester in AKS desktop, plus Monitoring Reader on the team's own Application Insights
- an Argo CD Application that delivers the team's app from Git

You work as a platform engineer while evaluating the experience of an application developer. Your workshop account has broader Azure and cluster permissions than a developer would get, so inspecting logs with it is not proof of authorization isolation.

### One subscription, two clusters

| Cluster                | Role                                                                                                           | Kubeconfig context |
| ---------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------ |
| AKS Standard control   | Argo CD, Crossplane, provider-opentofu, and composition functions. Argo CD Application objects live here.      | `$CONTROL_CONTEXT` |
| AKS Automatic workload | Shared Gateway, admission policy (Deployment Safeguards), and the application namespaces that requests create. | `$AKS_CONTEXT`     |

Every `kubectl` command in this guide passes `--context` explicitly so you always know which cluster you are talking to. Each learner has their own two clusters.

### Prepared for you versus built by you

**Prepared before Module 1:** both clusters, the platform controllers and their identities, the shared model and Log Analytics workspace, remote state storage, the shared Gateway, your two private GitHub repositories with controller credentials, the VS Code workspace, and local Backstage. The `AppEnvironment` API, root Argo CD Applications, and the `beans` namespace do not exist yet. That is expected.

**Wired by you in Module 2:** the provider configuration, delivery permissions, trusted environment mapping, and root Applications that establish the `AppEnvironment` API.

**Changed by you through pull requests:** a required `costCenter` field, the environment request, the application's binding to platform-provided identity and configuration, a Backstage profile choice, and a rejected and recovered image change.

You do not install controllers, build images, write a full Composition, or create identities by hand. The lab does not include Prometheus, Grafana, Azure Container Registry, an AI gateway, a production environment, cert-manager, external-dns, or Key Vault.

## Before you begin

You should recognize Kubernetes namespaces, Deployments, Services, and YAML files, and know that a Git commit records a change. No prior Crossplane, OpenTofu, Argo CD, or Backstage experience is needed. Each module explains the platform concept before you use it.

### Choose your learning path

**Guided session:** use the assigned lab VM, subscription, and accounts, not personal credentials. Organizers provision the Azure foundation before you arrive. Open WSL and follow the [Skillable lab setup](../setup/README.md#skillable-lab-setup), including `make machine-setup`, GitHub tokens, and the two local services, before opening the workspace below. The source repository may be pre-cloned or supplied as a clone step. Ask a proctor if something is missing or a checkpoint is blocked.

**Self-paced:** first complete the [setup guide](../setup/README.md) with your own Azure subscription and GitHub account, including starting Backstage and the Argo CD tunnel. Use Bash on Ubuntu, macOS, or Ubuntu on WSL. Wherever a module mentions an instructor demonstration, read it, then repeat the observation in your own environment.

Neither Microsoft Entra tenant administrator nor GitHub organization administrator permissions are required. If a step needs permissions you do not have, stop and ask your setup operator or administrator rather than broadening access or resetting work.

## Open the prepared workspace

Do this once at the start of the workshop, and again whenever you open a new terminal.

### 1. Open the workspace in VS Code

Open `~/prel37/prel37.code-workspace` in VS Code (**File** > **Open Workspace from File**). The Explorer shows three folders:

| Workspace folder | Path on disk          | What it holds                                                                               |
| ---------------- | --------------------- | ------------------------------------------------------------------------------------------- |
| 📁 Lab Root      | `~/prel37`            | Your lab configuration, exercise scaffolds, telemetry queries, evidence, and worksheet      |
| 🏗️ Platform      | `~/prel37/platform`   | Your private platform repository: API, composition, OpenTofu module, profiles, and template |
| 🚀 App-Deploy    | `~/prel37/app-deploy` | Your private application delivery repository, watched by Argo CD                            |

If VS Code or the workspace file is missing, guided attendees ask a proctor; self-paced learners complete the [editor prerequisites](../setup/README.md#prerequisites).

### 2. Load your environment in the terminal

Open the integrated terminal (**Terminal** > **New Terminal**) and run:

```bash
source ~/prel37/config/lab.env
echo "$LAB_ROOT $TEAM $APP_NAME $APP_ENV"
kubectl config get-contexts -o name
```

**Expected result:** the echo prints `/home/<you>/prel37 beans fourth-coffee beans-dev` (your home path varies), and the contexts list includes `prel37-control` and `prel37-workload`.

`lab.env` sets `LAB_ROOT`, `KUBECONFIG`, both cluster contexts, the application team names, and your Azure resource IDs. Every later command depends on it, so rerun the `source` line in any new terminal.

### 3. Check the local services

| Endpoint                      | What you should see                                                                      |
| ----------------------------- | ---------------------------------------------------------------------------------------- |
| `http://localhost:3000`       | Backstage. Select **Enter** as the guest user.                                           |
| `https://localhost:8443`      | Argo CD sign-in. Accept the local certificate warning and sign in as `admin`.            |
| `http://beans.localhost:8080` | The application, through the shared Gateway. Not running until Module 3; that is normal. |

If Backstage or Argo CD does not load, the local service is not running or its tunnel dropped. Restart it with the setup guide's [resume path](../setup/README.md#resume-a-prepared-environment), which also prints the Argo CD `admin` password. Guided attendees ask a proctor if restarting does not resolve it.

At this point Argo CD shows no applications and `beans` does not exist. You create both in Module 2.

## How to use this guide

Every module follows the same rhythm:

1. **Objectives and platform concept.** What you will be able to do, and the fundamental behind it.
2. **Explain and demonstrate.** The idea, then what it looks like in a working platform.
3. **Guided practice.** Numbered steps. Each step says why it matters, what to do, and the **Expected result**. Stop and check when the result does not match.
4. **Debrief and checkpoint.** What you proved, plus one takeaway for your own platform.

Two conventions keep the steps predictable:

- **Read files in VS Code.** When a step says _In VS Code, open `api/xrd.yaml` (Platform folder)_, use the Explorer to open the file and read it. You can click around and explore.
- **Make changes in the terminal.** Edits, Git, and GitHub actions are terminal commands you copy and run. This keeps every learner's change identical and reviewable. Do not also edit the same file in VS Code; if you do, `git diff` shows exactly what changed so you can fix it.

Most waits are reconciliation: a controller noticing a change and acting on it. Each module tells you how long to expect and how to ask Argo CD to check Git immediately instead of waiting for its next poll.

## Git workflow used throughout

Every platform and application change goes through a pull request (PR) to `main`. The PR is where a person reviews intent before a controller makes it real. You use the same terminal rhythm every time:

```bash
# 1. Start from current main in the right repository
cd "$LAB_ROOT/platform"            # or "$LAB_ROOT/app-deploy"
git checkout main && git pull origin main
git status --short                 # expect no output

# 2. Branch, change, and review your own diff
git checkout -b <branch-name>
# ... the module's change command ...
git diff                           # confirm only the intended lines changed

# 3. Commit only the named file and publish the branch
git add <file>
git commit -m "<message>"
git push -u origin <branch-name>

# 4. Open, review, and merge the PR
gh pr create --fill
gh pr diff
gh pr merge --merge --delete-branch
```

`gh pr merge --delete-branch` also switches your clone back to `main` and pulls the merge, so you are ready for the next change.

Rules that keep the lab safe:

- Stop if `git status --short` shows unexpected changes before you branch. Ask for help rather than discarding them.
- Stage only the files the step names. Do not run `git add .`, force-push, or bypass branch checks.
- You merge your own PRs in this lab because you are both the platform engineer and the reviewer. In production, a second person or required check would review platform changes.

**Merged is not the same as delivered.** After every merge, confirm that Argo CD synced the merged commit and that the resulting resources look right. A healthy app at an old revision does not prove your change worked.

## Workshop map

Follow the modules in order. Each one builds on the environment the previous module created.

| Time        | Module                                                                       | You will                                                                                            |
| ----------- | ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| 00:00-00:35 | [1. Define the developer promise](1-developer-promise.md)                    | Identify the developer task, the supported choices, ownership, and how to measure success.          |
| 00:35-01:15 | [2. Implement the environment contract](2-environment-contract.md)           | Wire the platform, require cost attribution in the API, and vend the `beans` environment.           |
| 01:15-01:25 | Break                                                                        |                                                                                                     |
| 01:25-02:05 | [3. Connect and deploy the application](3-application-delivery.md)           | Bind the app to platform identity and configuration, deploy through GitOps, and trace a model call. |
| 02:05-02:45 | [4. Complete the self-service interface](4-self-service.md)                  | Add a constrained profile choice to Backstage and use it to change the running app.                 |
| 02:45-02:55 | Break                                                                        |                                                                                                     |
| 02:55-03:40 | [5. Recover, inspect telemetry, and evaluate cost](5-operate-and-recover.md) | See a guardrail reject an unsafe change, recover through Git, and make a cost decision.             |
| 03:40-04:00 | [6. Plan the next platform milestone](6-next-milestone.md)                   | Choose the next improvement and the evidence that would prove it worked.                            |

Between Modules 1 and 2, the optional [foundation interlude](1b-aks-foundation.md) explains why the platform runs on AKS Standard and AKS Automatic. Read it before Module 2, during a break, or after the session. The [summary](7-summary.md) is the take-home reference. To continue after the session, the [optional next-environment exercise](8-optional-next-environment.md) vends a second environment from a single Backstage form. Use [Appendix A: troubleshooting](appendix-a-troubleshooting.md) when a result does not match.

**Facilitators:** announce each practice stop time and hold the debrief even if a reconciliation is still pending. Return to status during catch-up. Do not recover time by cutting explanations or breaks.

## How the capability fits together

Every module follows the same pattern: you change something in Git, a controller reconciles it, and you observe the result with `kubectl`, Argo CD, or the Azure portal.

| Module | You change                                                                                          | What reacts                                                                                                            | What you get                                                                                                                                                                                                       |
| ------ | --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2      | Platform wiring: provider config, delivery RBAC, trusted `EnvironmentConfig`, and root Applications | Argo CD delivers `api/` (XRD and Composition)                                                                          | Crossplane serves the `AppEnvironment` API                                                                                                                                                                         |
| 2      | Environment request: a PR to the platform repo adding `requests/beans-dev.yaml`                     | Argo CD applies the request to the control cluster, then Crossplane runs the OpenTofu module                           | A managed namespace, per-agent identities, model grants, Application Insights, and a namespace baseline (agent ServiceAccounts, ConfigMap, network exception). `status.binding` publishes the names the app needs. |
| 3      | Application: a PR to the app-deploy repo under `apps/fourth-coffee/`                                | Argo CD renders the pinned chart with `values.yaml`, then `profile.yaml`. AKS Automatic admission checks the workload. | Running agents, each using its vended identity and sending telemetry to its Application Insights                                                                                                                   |
| 4      | Profile choice in Backstage                                                                         | The template opens a PR that copies the approved platform profile into `profile.yaml`. You review and merge.           | The same application delivery path as Module 3, with the new profile                                                                                                                                               |
| 5      | An unsafe image change                                                                              | Admission rejects it                                                                                                   | You recover with a revert PR                                                                                                                                                                                       |

Ownership stays separate. OpenTofu owns the Azure resources and the managed namespace. Argo CD owns the baseline and the application. The application chart creates neither the Namespace nor its quota. The `AppEnvironment` API (`platform.prel37.example/v1alpha1`) is defined by this workshop; it is not a built-in AKS API.

## Application telemetry

The model-calling agents export OpenTelemetry from their own code, authenticating with their vended identity, straight to Azure Monitor's cloud OTLP endpoints. Because the app does the exporting, nothing extra runs in the cluster: no AKS application monitoring add-on, no `Instrumentation` resource, and no collector pod. Each agent's Application Insights data collection rule (DCR) then routes its spans to the lab's Log Analytics workspace, tagged with the team's resource. This path requires the [approved direct-export application artifact](../setup/README.md#application-artifact-prerequisite). After the environment is vended, print the Azure portal link:

```bash
kubectl --context "$CONTROL_CONTEXT" get appenvironment "$APP_ENV" -o json |
  jq -er '.status.appInsightsResourceId |
    if type == "string" and length > 0 then "https://portal.azure.com/#resource\(.)"
    else error("Application Insights has not been vended yet") end'
```

In the resource, use **Investigate** > **Search** to follow a chat request to its model call. [Module 3, step 7](3-application-delivery.md#7-verify-a-fresh-model-interaction) runs `queries/application-model-call.kql` from the terminal to show the same correlation. Read container stdout with `kubectl logs`, as shown in [Module 5](5-operate-and-recover.md#demonstrate-inspect-current-application-telemetry). Cluster-level Container Insights is separate from this application export path; its presence is not proof that native application spans arrived.

## Find the working files

| Lab Root path              | What it is                                                                          |
| -------------------------- | ----------------------------------------------------------------------------------- |
| `config/lab.env`           | Environment variables for your terminal                                             |
| `config/environment.yaml`  | Trusted platform mapping you apply in Module 2. Developers never type these values. |
| `exercises/`               | Scaffolds you copy into the repositories, kept outside the folders Argo CD watches  |
| `queries/`                 | Prepared telemetry queries                                                          |
| `evidence/`                | Usage and cost data for Module 5                                                    |
| `answers/product-brief.md` | Your single worksheet for the whole session                                         |
| `.state/`, `.credentials/` | Private state and tokens. Never copy these into Git or your notes.                  |

The source for these files lives in this repository under `src/`. The prepared copies are personalized for your lab, so do not copy them from another attendee.

## Recording your results

Use `answers/product-brief.md` (Lab Root folder) as your only worksheet. For each checkpoint, record the PR or request, the merged revision, what you observed, and whether you completed it **independently**, **assisted**, **demonstration-only**, or **blocked**. Mark evidence that has not arrived as pending rather than passed. Use synthetic inputs only; do not paste credentials or raw telemetry.
