@lab.Title

## Welcome to your lab environment

To begin, log into the virtual machine using the following credentials: +++@lab.VirtualMachine(Win11-Pro-Base).Password+++

**Note:** Text formatted as an +++example+++ represents type text. Clicking on this text will automatically insert it to prevent any typing errors.

## Overview

An application team needs a supported place to run an applications, a safe way to change it, and operating procedures it can use, without assembling the platform itself. In this workshop you build one thin slice of an internal developer platform that serves that need, then use it the way a developer would.

In this workshop you will:

- wire the platform's provisioning and delivery paths
- tighten an environment contract
- connect a supplied agent application to platform-provided identity and configuration
- publish a constrained self-service option within an internal developer platform (IDP)
- recover from a rejected deployment

You finish by using operating evidence to choose the next platform improvement.

> [!knowledge] Before we dive in, it's worth noting that the tools used in this workshop are intended to demonstrate one way of implementing these concepts, rather than the only way. The real goal here is to master the fundamentals: understanding what a platform team builds, the reasoning behind those choices, and how to determine if the platform is actually working. Each module is designed around a specific fundamental and concludes with a practical takeaway you can bring back to your own team.

## Platform engineering fundamentals you will practice

This workshop is designed to be more than just a technical walkthrough of tools; it is an exploration of the core principles that make a platform successful. The following table outlines the key fundamentals we will cover and maps them to the specific modules where you will put these concepts into practice.

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

To do this, we'll be using the "BACK stack," which is a combination of Backstage, Argo CD, Crossplane, and Kyverno. However, for this specific lab, we've swapped out Kyverno for the Azure Policy add-on for Kubernetes. You'll also notice that Crossplane is running an OpenTofu module (via the provider-opentofu) to handle the Azure resources. We've done this so that the infrastructure code stays in a readable, Terraform-compatible HCL format, which is much easier to manage than writing complex Kubernetes YAML.

| Letter | Component  | Role in this platform                                                                                            | First hands-on use |
| ------ | ---------- | ---------------------------------------------------------------------------------------------------------------- | ------------------ |
| B      | Backstage  | Developer portal. A software template offers one constrained choice and opens a pull request for review.         | Module 4           |
| A      | Argo CD    | GitOps delivery. Watches the platform and application repositories and applies what is merged to `main`.         | Module 2           |
| C      | Crossplane | Platform API. Defines the `AppEnvironment` request and composes it into Azure resources and Kubernetes delivery. | Module 2           |
| K      | Kyverno    | Policy enforcement. The Azure Policy add-on uses OPA Gatekeeper to enforce cluster policy.                       | Module 5           |

## What you will build

The platform is designed to support the `beans` application team and their [Fourth Coffee application](https://github.com/pauldotyu/fourth-coffee). To provide some architectural context, the application consists of a concierge service, an operations agent, and a Model Context Protocol (MCP) service, all of which interact with a pre-hosted AI model.

> [!hint] As you move through the exercises, please keep an eye on your identifiers. This lab is configured to use the team and namespace `beans`, the request `beans-dev`, and the application `fourth-coffee`. If you see different names in your environment, please stop where you are and let a proctor know.

A single environment request, `beans-dev`, provisions everything the team needs to get started:

- A managed AKS namespace named `beans`, configured with the necessary quotas and default policies.
- A dedicated managed identity for each agent, each federated to its own ServiceAccount and granted access to the shared AI model.
- An Application Insights resource to handle the team's telemetry.
- The necessary permissions for the requester, including namespace access via AKS desktop and the Monitoring Reader role for the team's Application Insights resource.
- An Argo CD Application that handles the deployment of the team's application directly from Git.

Throughout this workshop, you will be acting as a platform engineer, though you'll be evaluating the experience from the perspective of an application developer. Please keep in mind that your workshop account possesses broader Azure and cluster permissions than a standard developer would; therefore, the ability to inspect logs using this account should not be taken as proof of authorization isolation.

### One subscription, two clusters

To maintain a clean separation between the tools that manage the platform and the applications that run on it, the workshop architecture utilizes two distinct clusters. This separation of concerns ensures that the management plane—where your orchestration and infrastructure tools reside—remains isolated from the workload plane, where the actual application namespaces and gateways are deployed.

| Cluster                      | Role                                                                                                                                                                                       | Kubeconfig context |
| :--------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------- |
| **AKS Standard (Control)**   | This cluster hosts the management plane, including Argo CD, Crossplane, the OpenTofu provider, and composition functions. It is also where the Argo CD Application objects reside.         | `$CONTROL_CONTEXT` |
| **AKS Automatic (Workload)** | This cluster serves as the workload plane, hosting the Shared Gateway, admission policies (such as Deployment Safeguards), and the application namespaces created by environment requests. | `$AKS_CONTEXT`     |

> [!hint] To ensure there is no confusion between the two environments, every `kubectl` command in this guide explicitly includes the `--context` flag. This way, you always know exactly which cluster you are interacting with. Please note that every participant is provided with their own dedicated pair of clusters.

### Prepared for you versus built by you

To ensure we can focus on the architectural fundamentals rather than spending hours on boilerplate infrastructure, some components are pre-provisioned while others are designed for you to configure yourself.

**Pre-provisioned environment**

Before you begin Module 1, both clusters, the platform controllers and their identities, the shared model, the Log Analytics workspace, and remote state storage are already in place. Following the [setup steps](#set-up-your-lab-environment) will finalize your environment by creating the shared Gateway, your two private GitHub repositories (including controller credentials), your VS Code workspace, and a local instance of Backstage.

> [!note] Please note that the `AppEnvironment` API, root Argo CD Applications, and the `beans` namespace do not exist yet; this is intentional, as you will be creating them as part of the curriculum.

**Your contributions in Module 2**

In Module 2, you will handle the "wiring" of the platform. This includes configuring the provider, setting up delivery permissions, establishing trusted environment mapping, and deploying the root Applications that define the `AppEnvironment` API.

**Iterative changes via Pull Requests**

As you progress, you will use GitOps workflows to implement several key changes through pull requests. These include adding a required `costCenter` field, submitting an environment request, binding the application to platform-provided identity and configuration, selecting a Backstage profile, and managing a rejected image change to practice recovery.

> [!alert] What's out of scope
>
> To keep the workshop focused, you will not be required to install controllers, build images, write a full Composition from scratch, or create identities by hand. Additionally, please be aware that this lab does not include certain production-grade components such as Prometheus, Grafana, Azure Container Registry, an AI gateway, a production environment, cert-manager, external-dns, or Key Vault.

## Workshop Roadmap

To get the most out of this session, please follow the modules in the order presented. Because each module builds upon the environment created in the previous one, skipping a step may lead to configuration errors in later exercises.

| Time        | Module                                                                                                    | Objective                                                                                                            |
| :---------- | :-------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------- |
| 00:00-00:35 | [1. Define the developer promise](#module-1-define-the-developer-promise)                                 | Identify the core developer tasks, supported choices, and ownership models, and determine how to measure success.    |
| 00:35-01:15 | [2. Implement the environment contract](#module-2-implement-the-environment-contract)                     | Wire the platform components, implement cost attribution within the API, and provision the `beans` environment.      |
| 01:15-01:25 | **Break**                                                                                                 | —                                                                                                                    |
| 01:25-02:05 | [3. Connect and deploy the application](#module-3-connect-and-deploy-the-application)                     | Bind the application to platform identity and configuration, deploy via GitOps, and trace a model call.              |
| 02:05-02:45 | [4. Complete the self-service interface](#module-4-complete-the-self-service-interface)                   | Enhance Backstage with constrained profile choices and use them to update the running application.                   |
| 02:45-02:55 | **Break**                                                                                                 | —                                                                                                                    |
| 02:55-03:40 | [5. Recover, inspect telemetry, and evaluate cost](#module-5-recover-inspect-telemetry-and-evaluate-cost) | Experience a guardrail rejecting an unsafe change, perform a recovery via Git, and make a data-driven cost decision. |
| 03:40-04:00 | [6. Plan the next platform milestone](#module-6-plan-the-next-platform-milestone)                         | Select the next platform improvement and define the evidence required to prove its success.                          |

### Additional Resources and Optional Exercises

If you have a few minutes between Modules 1 and 2, or during a break, we highly recommend reading the [foundation interlude](#interlude-choose-the-foundation-for-the-promise). It provides a deeper dive into why the platform is split between AKS Standard and AKS Automatic.

For those who finish Module 6 with at least 35 minutes remaining on their lab timer, there is an [optional next-environment exercise](#optional-vend-the-next-environment-from-backstage) that demonstrates how to provision a second environment using a single Backstage form.

Finally, the [summary](#summary-and-take-home-material) serves as your primary take-home reference, and [Appendix A: troubleshooting](#appendix-a-troubleshooting-and-safe-recovery) is available if your results differ from the expected outcomes.

## Before you begin

To get the most out of this workshop, you should have a basic familiarity with Kubernetes—specifically namespaces, Deployments, Services, and YAML—as well as a general understanding of how Git commits are used to track changes. You do not need any prior experience with Crossplane, OpenTofu, Argo CD, or Backstage; we will explain the core concepts of each tool before you are asked to use them.

For the duration of the session, please use the assigned lab VM, subscription, and accounts rather than your own personal credentials. The Azure foundation has been pre-provisioned for you by the organizers. Before opening your workspace, ensure you have completed the [Set up your lab environment](#set-up-your-lab-environment) section (which we'll walkthrough next). If you find that any components are missing or a checkpoint is blocked, please reach out to a proctor for assistance.

Regarding access, you will not need administrator permissions for either Microsoft Entra or your GitHub organization. If you encounter a step that requires permissions you do not have, please stop and consult your setup operator or administrator. To avoid disrupting your environment or the lab's configuration, do not attempt to broaden your own access or reset your work independently.

### Your terminals at a glance

> [!alert] To ensure a smooth experience, it is important to use the correct terminal for each task. Running commands in the wrong context is one of the most common causes of confusion in this lab. To help you stay on track, every critical step in the guide begins with a **Run in:** line that specifies exactly which terminal—and, where necessary, which folder—you should be using.

| Name                       | Location                                        | Primary Purpose                                                         | Status                                              |
| :------------------------- | :---------------------------------------------- | :---------------------------------------------------------------------- | :-------------------------------------------------- |
| **Terminal 1 (Setup)**     | Ubuntu (WSL) tab in Windows Terminal            | Initial sign-ins, `make setup`, `make auth`, and launching VS Code.     | Keep open, though you will rarely return to it.     |
| **Terminal 2 (Backstage)** | Second Ubuntu tab                               | Running `make backstage` to host the portal at `http://localhost:3000`. | Keep open; no further input is required here.       |
| **Terminal 3 (Argo CD)**   | Third Ubuntu tab                                | Running `make argocd` to host the UI at `https://localhost:8443`.       | Keep open; no further input is required here.       |
| **VS Code Terminal**       | Integrated terminal in VS Code (📁 Lab Root)    | The primary workspace for nearly every command from Module 2 onward.    | Keep open; this is your main area of operation.     |
| **App Tunnel**             | Second VS Code terminal (from Module 3, Step 6) | Establishing the Gateway port-forward to `http://beans.localhost:8080`. | Keep open; this is required for subsequent modules. |

> [!TIP]
> To avoid confusion, we highly recommend renaming your terminals. In Windows Terminal, you can right-click a tab and select **Rename tab**. In VS Code, you can open the command palette (**Ctrl+Shift+P**) and run **Terminal: Rename**.

!IMAGE[Windows Terminal with three renamed Ubuntu tabs](instructions359547/sn4cz1g1.png)

===

## Set up your lab environment

Azure resources have been pre-provisioned and bootstrapped as much as possible. There are a few things you will need to configure manually. Follow the steps below.

Inside the virtual machine:

### Setup 1: Sign in to Azure

Open Microsoft Edge and sign in to Azure at +++https://portal.azure.com+++. Use the **Username** and the **TAP** (Temporary Access Pass) shown on the **Resources** tab above. If Edge asks **Stay signed in?**, select **Yes**.

### Setup 2: Sign in to GitHub

In the same browser, sign in to your provided GitHub account through SSO at +++https://github.com/enterprises/skillable-events/sso+++. Do this after signing in to Azure: SSO uses your Azure sign-in, so GitHub signs you in without asking for anything else. Your account is named `User1-@lab.LabInstance.Id_events`, and your lab ID is `@lab.LabInstance.Id`.

### Setup 3: Open Terminal 1

Open the Ubuntu profile in Windows Terminal.

> [!hint] Windows terminal should default to Ubuntu on Windows Subsystem for Linux (WSL). If not you can run the following command from PowerShell:
>
> ```powershell
> wsl
> ```

Rename this tab to **Terminal 1 (setup)**.

### Setup 4: Set the workspace paths

Run all remaining setup commands in Terminal 1 (setup) unless a step says otherwise. The workshop files and Backstage dependencies are already staged in the VM. Change into the setup folder and set two paths the later commands use: `LAB_SOURCE` (the setup bundle) and `LAB_ROOT` (your workspace):

```bash
cd "$HOME/prel37/setup"
export LAB_SOURCE="$PWD"
export LAB_ROOT="$HOME/prel37"
```

> [!alert] If this directory is missing, ask a proctor. You do not need to clone the upstream workshop repository.

<a id="check-the-assigned-accounts-in-wsl"></a>

### Setup 5: Check the assigned accounts in WSL

**Run in:** Terminal 1 (setup)

Windows sign-in does not automatically sign in the Linux Azure CLI or GitHub CLI. Sign in to each inside WSL using the assigned lab accounts. Run the two sign-ins one at a time, not together.

First, sign in to Azure:

```bash
az login --use-device-code
```

Copy the code then open the sign-in page that `az` prints in Edge, enter the code, and sign in with the same account as before. When `az` asks you to **Select a subscription and tenant**, press **Enter** to keep the default, which is the lab subscription.

Next, sign in to GitHub CLI:

```bash
gh auth login --hostname github.com --git-protocol https --web
```

If `gh` asks whether to authenticate Git with your GitHub credentials, answer **Y**. When it prints a one-time code, press **Enter**. `gh` can't open a browser from WSL, so it reports that it failed to open one and then waits. That is expected. Open +++https://github.com/login/device+++ in Edge, type the code from the terminal, and approve the sign-in. `gh` then finishes on its own.

Check both:

```bash
az account show --query '{subscription:id,tenant:tenantId}' -o table
gh auth status
```

<a id="prepare-the-learner-workspace"></a>

### Setup 6: Prepare the learner workspace

**Run in:** Terminal 1 (setup)

This one command reads the provisioned Terraform outputs, connects to both clusters, creates your platform and app-deploy repositories, installs the platform controllers, and prepares Backstage. It takes a few minutes:

```bash
make setup
```

> [!alert] If setup reports that no Terraform state exists and prepares only the VM, stop and ask a proctor to check `C:\terraform\terraform.tfstate`. Do not proceed until the learner environment has been configured.

Setup asks four questions, in this order:

1. **GitHub Username:** press **Enter** to accept the detected account, `User1-@lab.LabInstance.Id_events`.
2. **Is your GitHub org different from your username? (y/N):** type `n`, so the repositories are created under your user account.
3. **Git Author Name:** enter your GitHub account name, `User1-@lab.LabInstance.Id_events`.
4. **Git Author Email:** enter the email you used to sign in to Azure and GitHub, which is the **Username** on the **Resources** tab.

> [!hint] Setup is done when you see **WORKSHOP FILES AND PLATFORM PACKAGES READY**.
>
> The summary on screen lists the next steps, which follow in this guide. If setup stops with an error, fix the cause and rerun `make setup`; it picks up where it stopped.
>
> Setup saves your answers in `$LAB_ROOT/config/setup.env`, so to enter them again, delete that file first with `rm "$LAB_ROOT/config/setup.env"`.
>
> If you gave the wrong GitHub username or answered `y` to the organization question, ask a proctor before you rerun setup.

Now load your environment variables:

```bash
source "$LAB_ROOT/config/lab.env"
```

<a id="set-up-github-tokens"></a>

### Setup 7: Set up GitHub tokens

In Edge, go to +++https://github.com/settings/personal-access-tokens/new+++ and create two fine-grained personal access tokens, one after the other. For both, set **Resource owner** to your own account (`User1-@lab.LabInstance.Id_events`) and **Repository access** to **Only select repositories**. In **Select repositories**, type +++prel37-@lab.LabInstance.Id+++ and tick both private repositories, +++prel37-@lab.LabInstance.Id-platform+++ and +++prel37-@lab.LabInstance.Id-app-deploy+++. GitHub adds **Metadata: Read-only** on its own.

!IMAGE[GitHub fine-grained token page with Resource owner set, Only select repositories chosen, and both lab repositories ticked](instructions359547/3mdutgk2.png)

> [!alert] GitHub shows each token **only once**. As you create each token, paste it into its text box below. The saved values are repeated below so you can copy them when `make auth` prompts.

**Read token**, for Argo CD and Crossplane:

1. **Token name:** +++prel37-read+++
2. **Permissions:** add **Contents** and leave it at **Read-only**.
3. Copy and paste the token here: @lab.TextBox(prel37-read-token)

**Backstage token:**

1. **Token name:** +++prel37-backstage+++
2. **Permissions:** add **Contents** and **Pull requests**, and change both to **Read and write**. Add **Commit statuses** and leave it at **Read-only**.

!IMAGE[GitHub token permissions panel with Contents and Pull requests set to Read and write, and Commit statuses set to Read-only](instructions359547/qhar49p4.png)

4. Copy and paste the token here: @lab.TextBox(prel37-write-token)

Contents and commit-status access let Backstage read the catalog and populate the Module 4 Application picker. Pull-request write access lets the template open its PR after pushing a branch.

**Run in:** Terminal 1 (setup)

Apply the tokens to the cluster. Start with the `cd` so this also works in a new terminal.

```bash
cd "$HOME/prel37/setup"
make auth
```

Paste each token when prompted, the read token first. In WSL, paste with **Ctrl+Shift+V**. Wait for the helper to finish applying the controller credentials and workload-cluster registration. It is done when you see **All platform secrets applied to Control Cluster**.

If you need to copy a token again, use the values saved in the text boxes:

- GitHub read PAT (Contents: Read-only): `@lab.Variable(prel37-read-token)`
- GitHub Backstage PAT (Contents + Pull requests: Read and write, Commit statuses: Read-only): `@lab.Variable(prel37-write-token)`

<a id="start-backstage-and-argo-cd"></a>

### Setup 8: Start Backstage and Argo CD

**Run in:** Terminal 2 (Backstage)

In Windows Terminal, create a new a new Ubuntu tab and rename it to `Terminal 2 (Backstage)`:

Start Backstage:

```bash
cd "$HOME/prel37/setup"
source "$HOME/prel37/config/lab.env"
make backstage
```

> [!alert] **Keep this terminal running.** Don't press Ctrl+C or type in this terminal again. Later modules need it. If it stops, restart it with the same commands.

**Run in:** Terminal 3 (Argo CD), a new Ubuntu tab in Windows Terminal.

In Windows Terminal, create a new a new Ubuntu tab and rename it to `Terminal 3 (Argo CD)`:

Start the Argo CD tunnel:

```bash
cd "$HOME/prel37/setup"
source "$HOME/prel37/config/lab.env"
make argocd
```

> [!alert] **Keep this terminal running.** Don't press Ctrl+C or type in this terminal again. Later modules need it. If it stops, restart it with the same commands; `make argocd` prints the `admin` password again.

Confirm +++http://localhost:3000+++ displays Backstage and select **Enter** as the guest user. The first start compiles Backstage and can take a few minutes, so wait for the page to load.

Open +++https://localhost:8443+++, accept the local certificate warning, and sign in as `admin` with the password printed by `make argocd`.

<a id="configure-the-vs-code-workspace"></a>

### Setup 9: Configure the VS Code workspace

**Run in:** Terminal 1 (setup)

With both services running, open the prepared workspace:

```bash
cd "$HOME/prel37/setup"
source "$HOME/prel37/config/lab.env"
code "$LAB_ROOT/prel37.code-workspace"
```

Confirm VS Code is connected to WSL: the bottom-left corner of the window shows **WSL** and the name of your Linux distribution.

!IMAGE[VS Code with the WSL: Ubuntu indicator in the bottom-left corner and the three workspace folders in the Explorer](instructions359547/6xpcxz93.png)

<a id="open-the-prepared-workspace"></a>

## Getting familiar with the prepared workspace

Use this section to confirm the workspace.

### 1. Open the workspace in VS Code

> [+alert] If it is not already open
>
> Run this in Terminal 1 (setup), or any WSL terminal:
>
> ```bash
> code "$HOME/prel37/prel37.code-workspace"
> ```
>
> Open the workspace this way rather than with **File** > **Open Workspace from File**, because a VS Code window that isn't connected to WSL can't see `~/prel37`.

The Explorer shows three folders:

| Workspace folder | Path on disk          | What it holds                                                                               |
| ---------------- | --------------------- | ------------------------------------------------------------------------------------------- |
| 📁 Lab Root      | `~/prel37`            | Your lab configuration, exercise scaffolds, telemetry queries, evidence, and worksheet      |
| 🏗️ Platform      | `~/prel37/platform`   | Your private platform repository: API, composition, OpenTofu module, profiles, and template |
| 🚀 App-Deploy    | `~/prel37/app-deploy` | Your private application delivery repository, watched by Argo CD                            |

> [!alert] If VS Code or the workspace file is missing, ask a proctor.

For what each file in Lab Root is for, see [Find the working files](#find-the-working-files).

### 2. Load your environment in the terminal

Open the command palette (**View** > **Command Palette** or **Ctrl+Shift+P**) and type `Terminal: Create New Terminal in Editor Area`.

!IMAGE[Create new terminal in editor area](instructions359547/o77rydlo.png)

> [!hint] If VS Code asks which folder to use, choose 📁 **Lab Root**. This is your **VS Code terminal**, where you run every module command from Module 2 onward.

You'll be using VS Code terminal for the rest of the lab. Run the following commands to ensure you have all the necesary environment variables loaded and Kubernetes clusters are available.

```bash
source ~/prel37/config/lab.env
echo "$LAB_ROOT $TEAM $APP_NAME $APP_ENV"
kubectl config get-contexts -o name
```

**Expected result:** the echo prints `/home/labuser/prel37 beans fourth-coffee beans-dev` (your home path varies), and the contexts list includes `prel37-control` and `prel37-workload`.

> [!hint] The `~/prel37/config/lab.env` file helps you set `LAB_ROOT`, `KUBECONFIG`, both cluster contexts, the application team names, and your Azure resource IDs. Every later command depends on it, so rerun the `source` line in any new terminal if you loose environment variables.

### 3. Check the local services

Here is the list of local services you will be working with throughout the workshop.

| Endpoint                      | What you should see                                                                      |
| ----------------------------- | ---------------------------------------------------------------------------------------- |
| `http://localhost:3000`       | Backstage. Select **Enter** as the guest user.                                           |
| `https://localhost:8443`      | Argo CD sign-in. Accept the local certificate warning and sign in as `admin`.            |
| `http://beans.localhost:8080` | The application, through the shared Gateway. Not running until Module 3; that is normal. |

If Backstage or Argo CD does not load, the local service is not running or its tunnel dropped. Rerun `make backstage` or `make argocd` as shown in [Start Backstage and Argo CD](#start-backstage-and-argo-cd); `make argocd` prints the `admin` password again. Ask a proctor if restarting does not resolve it.

> [!note] At this point Argo CD shows no applications and `beans` does not exist. You create both in Module 2.

**Setup checklist:** tick each item before Module 1.

- [] Terminal 1 shows **WORKSHOP FILES AND PLATFORM PACKAGES READY** from `make setup`.
- [] Terminal 1 shows **All platform secrets applied to Control Cluster** from `make auth`.
- [] Terminal 2 is running Backstage, and +++http://localhost:3000+++ loads.
- [] Terminal 3 is running the Argo CD tunnel, and +++https://localhost:8443+++ loads.
- [] VS Code shows **WSL** in the bottom-left corner, with three folders in the Explorer.
- [] The VS Code terminal echo prints `/home/labuser/prel37 beans fourth-coffee beans-dev`.

**Coming back to a saved lab later?** Don't repeat setup. Follow [Resume a saved lab](#resume-a-saved-lab).

## How each module works

Each module is designed to lead you from theory to practice. The flow is always the same:
**Objectives & Concepts** --> **Demonstration** --> **Numbered Steps** --> **Debrief & Checkpoint**.

Every step includes an **Expected result**. If your output doesn't match, please pause and investigate the discrepancy before moving forward.

### A note on "Reconciliation"

You will notice occasional pauses between steps. This is "reconciliation"—the time it takes for a controller to detect a change and act upon it. We have included estimated wait times in the guide, along with instructions on how to prompt Argo CD to sync with Git immediately if you prefer not to wait.

### Three workflow conventions

To keep the lab predictable, we follow these three rules:

- **Read files in VS Code.** When a step asks you to review a file (e.g., _In the VS Code Explorer, expand 🏗️ **Platform** > **api** and open **xrd.yaml**_), start at the top-level workspace folder named first (📁 **Lab Root**, 🏗️ **Platform**, or 🚀 **App-Deploy**), expand each folder in order, and open the file. We encourage you to explore the directory structure to better understand the project.
- **Make changes in the terminal.** To ensure all changes are identical and reviewable, all edits and Git operations are performed via terminal commands. Avoid editing these files directly in the editor. If you do, use `git --no-pager diff` to find and fix the discrepancy.
- **Verify the "Run in" line.** Every terminal step starts with a **Run in:** line specifying the correct terminal and repository folder. Always verify this before pasting a command.

### Git habits

All changes are managed via pull requests (PRs) using the VS Code terminal. To avoid common pitfalls, please adopt these four habits:

- **Use `git --no-pager`** for `git diff` and `git log`. This prevents Git from opening a "pager" (like `less`) that can trap your input. If you see a `:` prompt or an `(END)` marker, press **q** to return to the shell.
- **Treat `gh` commands as final.** Run `gh pr create` and `gh pr merge` as the last command in a block. Wait for the command to finish before moving to the next block to avoid dropped keystrokes.
- **Stage only specified files.** Only stage the files explicitly mentioned. Avoid `git add .` or force-pushing. If `git status --short` shows unexpected changes, stop and ask for help.
- **Merged $\neq$ Delivered.** A merged PR is not a deployed change. After every merge, confirm that Argo CD has successfully synced the commit and that the resources are correctly configured.

For a detailed walkthrough of this pattern, see [Appendix B](#git-workflow-used-throughout).

### Recording your results

Please use 📁 **Lab Root** > **answers** > **product-brief.md** in the VS Code Explorer as your sole worksheet. **Important:** VS Code does not autosave in this environment, so remember to press **Ctrl+S** after each entry.

For every checkpoint, record:

1. The PR or request ID and the merged revision.
2. Your observations.
3. Your completion status (**independently**, **assisted**, **demonstration-only**, or **blocked**).

If evidence has not yet appeared, mark the item as "pending" rather than "passed." Please use synthetic data only; do not paste actual credentials or raw telemetry into the document.

===

<a id="module-1-define-the-developer-promise"></a>

# Module 1: define the developer promise

**Duration:** 35 minutes, 00:00-00:35.
**Rhythm:** 15 minutes explanation, 5 demonstration, 10 product exercise, 5 discussion.

## Objectives

By the end of this module, you will be able to:

- Describe a recurring developer task and the friction a platform capability should remove.
- Separate supported developer choices from platform defaults, mandatory controls, and exceptions.
- Define the capability's owner, first non-goals, and observable success criteria.

> [!knowledge] **Platform concept: platform as a product.** A platform team has customers: the developers who use it. Start from a task they repeat and a promise you can keep, then pick tools. In this module you write that promise. The BACK stack shows up from Module 2 onward as the way to keep it.

No infrastructure changes happen in this module. Start with the developer's task before looking at the implementation.

## Start with the developer's task

The scenario for this workshop is deliberately narrow:

> The Fourth Coffee "beans" team needs a governed development environment for its workloads, a supported deployment path, and access to its own operating information.

In platform engineering, the developer outcome is never just "a resource exists." The real goal is to let a team deploy, make supported changes, understand failures, and find help without needing a platform engineer to manually wire every connection. If a namespace is created but lacks a usable identity, a delivery path, or operating information, the developer is still stuck assembling the missing pieces. This last-mile assembly is where most developer friction lives, and it is the work a platform should take off the developer's plate.

### The capability is not the portal

A common mistake in platform design is confusing the _portal_ (the UI) with the _capability_ (the end-to-end service). Backstage is the interface through which a developer discovers and requests a change, but the capability itself includes the contract, authorization, fulfillment, status, recovery information, and the team that operates it.

A form that simply opens a ticket has improved the intake process, but it has not removed the fulfillment handoff. A truly useful self-service path allows an authorized developer to complete a supported task from start to finish without routine manual intervention from the platform team.

The same distinction applies even without a portal. A well-defined request in Git can be a powerful self-service interface if the validation, fulfillment, status, and recovery paths are all automated and transparent. In Module 4, you add a discoverable interface to a delivery path that already works, rather than treating the portal as the product itself.

### Define clear responsibilities

A successful platform relies on a clean separation of concerns:

- **Application developers** are responsible for their application's behavior and for choosing among supported options based on their specific needs.
- **Platform engineers** supply the "paved road": the infrastructure, access guardrails, operational boundaries, and the maintained path through them.

The goal is not to hide every implementation detail or to make the platform team the sole troubleshooters for everything. Instead, the goal is to remove repetitive assembly work while making responsibilities and exceptions transparent.

For this lab, the platform provides identity, configuration, namespace defaults, approved profiles, and application telemetry. The developer consumes these capabilities without needing to know a specific identity ID, a module URL, or an arbitrary Azure resource name. Ownership is declared in a static Backstage catalog YAML manifest. That is a platform-managed binding, not a manual access grant.

### Keep the first promise small

It is tempting to solve every infrastructure request at once. Start instead with a thin slice: one bounded, supported task that works end to end.

> [!note] This workshop covers one application in one development environment. Production promotion and arbitrary infrastructure requests are out of scope. A thin capability that works beats an all-in-one fulfillment path that does not.

> [!hint] Describe success from the developer's perspective (for example, "I can deploy my app and see the logs") before you name a tool.

## Demonstrate: watch the finished outcome

**5 minutes. Instructor-led, using a separate prepared environment.**

Watch the instructor submit an approved application change, follow the generated Git revision, open the application, and find its owner and recovery information.

Notice four points:

- What the developer actually chooses.
- What the platform derives or supplies.
- How the developer knows the change is running rather than merely submitted.
- What the developer can do when the path rejects a change.

Do not reproduce the demonstration yet. Your environment has installed controllers but no workshop root Applications, request API, or application namespace. Module 2 wires those controllers and establishes the API before the first request. The instructor's completed environment is not evidence that yours is ready. If you are learning independently, read these observation prompts as a preview and continue to the worksheet; no separate demonstration environment is needed.

## Product exercise: define one useful capability

**10 minutes.**

In the VS Code Explorer, expand 📁 **Lab Root** > **answers** and open **product-brief.md**. You use this one worksheet for the whole workshop, with a section per module, so the promise you write now can be checked against what you observe later. Fill in the **Module 1** section as you go, and press **Ctrl+S** after each entry. If VS Code is not open yet, follow [Open the prepared workspace](#open-the-prepared-workspace).

### 1. Name the task and friction

Describe the developer, the recurring task, and one handoff, repeated action, or unclear convention the capability should remove.

> [!hint] Stay with the supplied scenario for the build. You can relate it to your organization during discussion, but do not expand the implementation to another application or environment.


### 2. State the promise and boundary

Write a short capability statement. For example:

> A developer on the app team can request the approved development environment, deploy their app with platform-provided connections, and change its workload profile without routine manual fulfillment.

This is an illustrative statement to refine, not a measured customer finding.

> [!hint] Add the platform owner, support route, exception route, and first non-goals. Describe an accountable team or role rather than an individual.


### 3. Make the outcome observable

Write acceptance criteria in terms of things you can observe. Useful examples for this scenario are:

- The request produces the assigned namespace and usable baseline, not just an accepted API object.
- The application reaches the approved model without copying a model key.
- An approved profile change reaches the running application after the learner reviews and manually merges a PR, without another team fulfilling it.
- A rejected change points to a supported correction through Git.

> [!hint] You are defining what to evaluate, not asserting these outcomes already passed.


### 4. Ask a baseline question

Record one question about the current task: how much time is active work, how much is waiting, and where does the developer need help?

> [!hint] Do not invent a starting duration or improvement percentage. If a baseline is unavailable, record how you would collect it. Any supplied organizational figures are illustrative unless explicitly labeled with a measured source.


## Discuss: which inputs belong in the request?

**5 minutes. Pause writing for the group discussion.**

Classify the following as a developer choice, platform default, mandatory control, or exception:

- An approved workload profile.
- The assigned owner and cost center.
- A raw managed-identity client ID.
- Cluster and namespace placement.
- A pinned application image.
- A request for production access or a larger quota.

The useful distinction is not simply whether a field appears in YAML. An owner or cost center can be visible while still needing review against the assigned binding. A dropdown can improve usability without enforcing authorization.

For this workshop, the developer chooses an approved workload profile. The platform resolves placement and identity from trusted configuration. Cost attribution and image policy are controls. A larger namespace quota or production access requires a separate exception or capability, not an arbitrary form value. Guest access to a local catalog is not proof that someone is authorized to make arbitrary infrastructure changes.

You will see each answer again in the build: `costCenter` becomes a required contract field in Module 2, identity and placement come from the platform's binding in Module 3, the profile is the only Backstage choice in Module 4, and image policy rejects `latest` in Module 5.

> [!knowledge] **Takeaway:** list the last ten requests your platform team handled by hand. Group them by developer task. The largest group with a short list of safe answers is a good first capability; write its promise in one sentence before choosing any tool.

## Checkpoint

You have a capability statement, owner and boundaries, observable acceptance criteria, and one baseline question in the worksheet.

You have not wired provider access, applied any manifests, or created the namespace or application. That is the expected fresh state. Continue to Module 2 to connect the prepared installation; do not wait for an API that has not been delivered. If resuming an existing instance, preserve its later progress rather than removing resources to match this checkpoint.

> [!knowledge] **What you learned:** an internal developer platform is valuable when it completes a developer task, not because it exposes a large number of tools.

===

<a id="interlude-choose-the-foundation-for-the-promise"></a>

# Interlude: choose the foundation for the promise

**Duration:** about 10 minutes of optional reading. Read it before Module 2, during a break, or after the session. It is not part of the timed schedule.

## Objectives

After reading, you will be able to:

- Explain why a platform team builds on a managed Kubernetes service instead of assembling every cluster capability itself.
- Describe the lab's two-cluster layout and why each cluster uses a different AKS tier.
- Separate what AKS provides, what the platform adds, and what developers own.

> [!knowledge] **Platform concept: build the product, not the plumbing.** In Module 1 you wrote a promise. Every hour spent patching nodes, wiring ingress, or rotating credentials is an hour not spent keeping it. Choose a foundation that already handles the undifferentiated work, then spend your effort on the contract and the golden path.

> [!note] No infrastructure changes happen here. This page explains choices that are already made in `infra/main.tf`, which you can read in the VS Code Explorer under 📁 **Lab Root** > **setup** > **infra**.


<a id="from-promise-to-foundation"></a>

## From promise to foundation

Look at the acceptance criteria you wrote in Module 1. Each one depends on a capability that someone has to build, run, and upgrade:

| Your promise needs                              | Foundation capability                           | Where you see it in the lab                        |
| ----------------------------------------------- | ----------------------------------------------- | -------------------------------------------------- |
| The app reaches the model without copying a key | Workload identity and an OIDC issuer            | Module 3, agent ServiceAccounts                    |
| A rejected change points to a supported fix     | Admission policy with clear messages            | Module 5, Deployment Safeguards rejects `latest`   |
| Each team gets its own boundary                 | Namespaces with quota, network policy, and RBAC | Module 2, the vended `beans` namespace             |
| The app is reachable without per-team plumbing  | A shared Gateway with one route per team        | Module 3, `beans.localhost`                        |
| You can prove the outcome, not just the status  | Managed metrics, logs, and an OTLP destination  | Modules 3 and 5, telemetry queries                 |
| The environment stays patched without a ticket  | Automatic cluster and node OS upgrades          | Runs in the background                             |
| Capacity follows demand                         | Node autoprovisioning                           | Module 4, a larger profile requests more resources |

A platform team can build every row itself. Most should not. Each row you assemble by hand is another component to patch, debug, and staff. A managed foundation turns those rows into defaults, so the platform team owns the contract instead of the plumbing.

<a id="aks-standard-and-aks-automatic"></a>

## AKS Standard and AKS Automatic

AKS offers two ways to run a cluster. Think of them as two points on a spectrum of responsibility, not as good and better.

- **AKS Standard** gives you full control. You choose node pools, networking, add-ons, upgrade channels, and policy. Most capabilities are optional, so you decide what to turn on and you own keeping it consistent.
- **AKS Automatic** starts from a production-ready configuration. Many capabilities are preconfigured (always on) or default (on, but changeable). You still get the full Kubernetes API and its ecosystem.

[AKS Automatic](https://learn.microsoft.com/azure/aks/intro-aks-automatic) includes, among other things:

- **Node autoprovisioning** to create right-sized nodes from pending pod requests, with managed system node pools, plus HPA, KEDA, and VPA enabled.
- **Deployment Safeguards** and baseline Pod Security Standards enforced through Azure Policy.
- **Azure RBAC for Kubernetes authorization** instead of local accounts.
- **Workload identity** with Microsoft Entra Workload ID and an OIDC issuer.
- **Automatic upgrades** for the cluster (stable channel) and node OS images, with upgrades stopped when deprecated API usage is detected.
- **Secure-by-default settings**, such as API server virtual network integration, image cleaner, and a locked node resource group.
- **Azure CNI Overlay powered by Cilium** for networking and network policy.
- **Managed Prometheus and Container Insights** for monitoring.
- A **pod readiness SLA** and an API server uptime SLA.

The same overview has a feature-by-feature comparison table. Use it when you decide which tier fits a given cluster.

**When Standard is the better call:** you need control over when minor-version upgrades happen, specific node configuration, a fixed footprint, or networking and add-ons that Automatic manages for you. Choosing Standard is a decision to own those settings, and that is a fair trade when you have a reason to.

## The choice this lab makes: two clusters, two tiers

The lab runs two clusters. Module 2 calls them the control plane and the workload plane.

**Control cluster: AKS Standard.** This cluster runs the platform's own controllers: Crossplane, which serves the request API, and Argo CD, which delivers from Git. Its workload is small, predictable, and owned by the platform team, so control matters more than elasticity. In `infra/main.tf` it is a single fixed node with manual node provisioning, a `patch` upgrade channel, `NodeImage` OS upgrades, local accounts disabled, Azure RBAC, workload identity, and Cilium networking. Those are Standard options turned on deliberately. The single node is sized for a lab, not for production. A production control cluster would also use a private API server and scope its identity to the resource groups it manages.

**Workload cluster: AKS Automatic.** This is where developers' applications run. Here, best practices enforced by default matter most: every team's namespace starts from a hardened baseline, nodes appear when workloads need them, and patching happens without a platform ticket. The lab adds monitoring and the App Routing Gateway API implementation (Istio) on top of the Automatic defaults.

> [!knowledge] The pattern to take home: **run the platform where you want control, and run tenant workloads where you want guardrails by default.** It also keeps privileges apart. The credentials that create infrastructure live on the control cluster, never in an application namespace.


<a id="what-aks-provides-and-what-the-platform-adds"></a>

## What AKS provides, and what the platform adds

The BACK stack (Backstage, Argo CD, Crossplane, Kyverno) does not replace AKS features. In this lab, the Azure Policy add-on for Kubernetes uses OPA Gatekeeper to fill Kyverno's policy-enforcement role. The platform packages AKS capabilities into a contract a developer can request.

| Layer                               | Owns                                                                                                  | In this lab                                                      |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **AKS**                             | Identity federation, admission safeguards, managed namespaces, Gateway, upgrades, scaling, monitoring | Control cluster (Standard) and workload cluster (Automatic)      |
| **Platform (BACK stack, OpenTofu)** | The `AppEnvironment` contract, composition, GitOps delivery, the catalog and form, approved profiles  | Crossplane and Argo CD on the control cluster, Backstage locally |
| **Developer**                       | Application configuration, profile choice, image                                                      | The app-deploy repository                                        |

Two examples make the split concrete:

- **Managed namespaces** are an AKS capability available on both tiers. AKS does not decide which team gets which namespace. The platform's OpenTofu module creates one per environment request, with the quota and labels the contract requires.
- **Argo CD** runs as the AKS [Argo CD cluster extension](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-argocd) (`Microsoft.ArgoCD`), so Azure handles its installation and release train. The platform team still owns the Applications, projects, and repositories it delivers.

> [!knowledge] AKS also stays open where you need it. Crossplane is installed from its upstream Helm chart, Backstage is the open source developer portal, and the Gateway API is the upstream Kubernetes API. You choose where a managed option saves effort and where an open source component fits better, on the same cluster.


## Trade-offs to keep in mind

- **Less control on Automatic.** Preconfigured settings cannot be disabled or changed. Check the comparison table before you depend on a setting you need to tune.
- **Two clusters means two of everything.** Two sets of credentials, two upgrade cadences, and two places to look when something fails. When a result looks wrong, first ask which cluster should hold it.
- **Managed defaults move.** Automatic upgrades and managed components change over time. Pin what your contract depends on. Module 2 shows this with `moduleRevision`.
- **Cost follows the tier.** Automatic includes the Standard pricing tier and its SLAs. The control cluster here uses the Free tier. Compare with the [pricing page](https://azure.microsoft.com/pricing/details/kubernetes-service/) for your own case.

## Discuss

- Which rows in the [promise-to-foundation table](#from-promise-to-foundation) does your organization still assemble by hand?
- Where would your platform's controllers run: on a Standard cluster, an Automatic cluster, or somewhere else? What would decide it?

## Learn more

| Capability                           | Microsoft Learn                                                                                                                                                                           |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AKS Automatic overview               | [What is AKS Automatic?](https://learn.microsoft.com/azure/aks/intro-aks-automatic)                                                                                                       |
| Deployment Safeguards (policy)       | [Deployment Safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards)                                                                                                      |
| Node autoprovisioning                | [Node autoprovisioning](https://learn.microsoft.com/azure/aks/node-auto-provisioning)                                                                                                     |
| Azure RBAC                           | [Azure RBAC for Kubernetes authorization](https://learn.microsoft.com/azure/aks/manage-azure-rbac)                                                                                        |
| Automatic upgrades                   | [Cluster auto-upgrade](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster) and [node OS auto-upgrade](https://learn.microsoft.com/azure/aks/auto-upgrade-node-os-image)           |
| App Routing                          | [Application routing add-on](https://learn.microsoft.com/azure/aks/app-routing)                                                                                                           |
| Gateway API with App Routing (Istio) | [App Routing Gateway API](https://learn.microsoft.com/azure/aks/app-routing-gateway-api) and [managed Gateway API](https://learn.microsoft.com/azure/aks/managed-gateway-api)             |
| Workload identity                    | [Microsoft Entra Workload ID on AKS](https://learn.microsoft.com/azure/aks/workload-identity-overview)                                                                                    |
| Secure by default                    | [AKS security concepts](https://learn.microsoft.com/azure/aks/concepts-security)                                                                                                          |
| Managed namespaces                   | [Managed namespaces](https://learn.microsoft.com/azure/aks/concepts-managed-namespaces)                                                                                                   |
| Networking                           | [Azure CNI powered by Cilium](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium)                                                                                          |
| Monitoring                           | [Monitor AKS](https://learn.microsoft.com/azure/aks/monitor-aks)                                                                                                                          |
| Extensions, including Argo CD        | [Cluster extensions](https://learn.microsoft.com/azure/aks/cluster-extensions) and [Argo CD extension](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-argocd) |
| Open source integrations             | [Add-ons, extensions, and integrations](https://learn.microsoft.com/azure/aks/integrations) and [support policies](https://learn.microsoft.com/azure/aks/support-policies)                |

## What you learned

> [!knowledge] A platform is only as calm as its foundation. Choose the AKS tier per cluster based on who should own each decision, let AKS carry the undifferentiated work, and build the developer contract on top.


===

<a id="module-2-implement-the-environment-contract"></a>

# Module 2: implement the environment contract

**Duration:** 40 minutes, 00:35-01:15.
**Rhythm:** 10 minutes explanation and guided wiring, 5 demonstration, 15 guided practice, 5 debrief, 5 catch-up/questions.

## Objectives

By the end of this module, you will be able to:

- Explain the difference between what a developer asks for and the trusted configuration the platform supplies.
- Wire an installed platform so it can fetch private code, use its own identity, store state, and deliver within boundaries.
- Tighten a platform API by making an existing field required, and prove the API enforces it.
- Submit an environment request through Git and trace it to a usable AKS managed namespace.

> [!knowledge] **Platform concept: self-service through a contract.** A platform API is a promise. Developers describe intent with a few fields; the platform owns how that intent becomes infrastructure. In the BACK stack, **Crossplane** serves the API, **Argo CD** delivers it from Git, and **Kubernetes** runs both.

> [!knowledge] **AKS in action: managed namespaces, Azure RBAC, and the Argo CD extension.** The `beans` namespace you vend in this module is an AKS [managed namespace](https://learn.microsoft.com/azure/aks/concepts-managed-namespaces): AKS applies its quota, network policy, and labels as one Azure resource. Access is [Azure RBAC](https://learn.microsoft.com/azure/aks/manage-azure-rbac) scoped to that namespace, so the requesting developer can work inside it without cluster-wide rights. Argo CD runs as the AKS [Argo CD extension](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-argocd), so Azure installs and updates it while the platform team owns what it delivers. See [why AKS is the foundation](#what-aks-provides-and-what-the-platform-adds).

## Prerequisites and starting state

**Prerequisites:** [lab setup](#set-up-your-lab-environment) is complete, local services are running, and you have read [Module 1](#module-1-define-the-developer-promise). In your terminal, `source ~/prel37/config/lab.env` has been run.

**Starting state on a fresh lab:**

- Controllers (Crossplane, provider-opentofu, Argo CD) are installed and healthy, but not wired to anything.
- 📁 **Lab Root** > **config** > **environment.yaml** is rendered for your lab but **not applied**.
- Argo CD shows no applications. The `AppEnvironment` API does not exist yet.
- The platform repository's `requests/` folder has no `beans-dev.yaml`, and there is no `beans` team namespace.

**Resuming?** The wiring commands are safe to rerun. If a PR from this module already merged, verify its checkpoint and continue rather than repeating it.

**Before you start:**

- [] Backstage (Terminal 2) and Argo CD (Terminal 3) are still running.
- [] You're in the VS Code terminal, and `echo $APP_ENV` prints `beans-dev`.
- [] You have time for a wait of about 7 minutes, up to 15, at step 7.

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

In this module you wire this pipeline: connect the supplied parts, complete one piece of the public contract, then follow a real request through the system.

### Control plane and workload plane

This lab separates the **control plane**, which runs the platform, from the **workload plane**, which runs applications. The [foundation interlude](#interlude-choose-the-foundation-for-the-promise) explains why the control cluster uses AKS Standard and the workload cluster uses AKS Automatic.

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

Each request vends one team environment. The request's `team` names the namespace and the team's Azure resources, such as the per-agent identities `id-prel37-<lab>-beans-concierge` and `id-prel37-<lab>-beans-ops-agent`, and `appi-prel37-<lab>-beans`. The request's `metadata.name` names its Workspace, Argo CD projects, and baseline Application. This workshop uses team `beans`, application `fourth-coffee`, and request `beans-dev`, which `lab.env` sets as `$TEAM`, `$APP_NAME`, and `$APP_ENV`.

### Why cost attribution belongs in the contract

A cost center ties an environment to an accountable owner. Requiring it at request time means no environment arrives without attribution, and the platform never has to chase it later.

It does not cap spending. The `ai-dev` namespace class sets a Kubernetes quota (CPU requests `2000m`, limits `6000m`; memory requests `3Gi`, limits `8Gi`), which bounds resources, not dollars. Module 5 looks at cost.

### Accepted, provisioned, and usable are different states

A merged PR means the request is **accepted**. Creating the namespace and Azure resources means it is **provisioned**. Delivering the ServiceAccount and configuration means it is **usable**. A good platform tells the developer which state they are in. Module 3 then proves access with a real model call rather than assuming a role assignment worked.

<a id="guided-wiring-connect-the-installed-components"></a>

## Guided practice: connect the installed components

Setup installed the controllers. In this section you connect them so the platform can run without your personal login.

**New terminal? Load your environment first.** Every command depends on `lab.env`. If you opened a new terminal, or you see an empty value or an `unbound variable` error, run +++source ~/prel37/config/lab.env+++. Then +++echo "$LAB_ROOT $TEAM $APP_NAME $APP_ENV"+++ should print `/home/labuser/prel37 beans fourth-coffee beans-dev`.

### 1. Check that the controllers and credentials are ready

**Run in:** VS Code terminal. These commands use full paths, so any folder works.

```bash
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Healthy provider/provider-opentofu --timeout=600s
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Healthy functions.pkg.crossplane.io -l app.kubernetes.io/part-of=prel37 --timeout=600s
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system get secret module-git-credentials
kubectl --context "$CONTROL_CONTEXT" -n argocd get secret repo-platform repo-app-deploy cluster-workload
```

**Expected result:** the provider and three functions report `condition met`, and all four Secrets are listed. These Secrets hold the scoped GitHub tokens from `make auth` and the workload-cluster registration. If a Secret is missing, run `cd ~/prel37/setup && make auth`, then repeat this step. If that doesn't fix it, see [workspace or local service is unavailable](#workspace-sign-in-or-local-service-is-unavailable).

### 2. Connect execution, identity, and delivery permissions

In the VS Code Explorer, expand 🏗️ **Platform** > **bootstrap** and open these files. Read the comments:

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

In the VS Code Explorer, expand 📁 **Lab Root** > **config** and open **environment.yaml**. This is the platform's private knowledge about your lab: the repository URLs, cluster ID, model endpoint, Log Analytics workspace, and `moduleRevision`, the exact platform commit the controller runs. A developer never types any of these. The Composition reads them by name and combines them with the request.

The `moduleRevision` pins execution: even after you change `main`, the OpenTofu module and charts run from this fixed commit. That is how a platform team can change the API without silently changing the code that runs behind it.

```bash
kubectl --context "$CONTROL_CONTEXT" apply --server-side -f "$LAB_ROOT/config/environment.yaml"
```

**Expected result:** `environmentconfig.apiextensions.crossplane.io/prel37 serverside-applied`. The Composition can read these values when it provisions resources.

### 4. Trace the cost-center field through the implementation

Before turning on delivery, follow one field from the API to Azure. In the VS Code Explorer, expand 🏗️ **Platform** and open these files. Each path starts under 🏗️ **Platform**:

| File                                 | Find                                                                | Why it matters                                                                                                                                |
| ------------------------------------ | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `api/xrd.yaml`                       | `costCenter` with pattern `^CC-[0-9]{4}$`, and the `required:` list | The field exists but is not required. That is the contract gap you close in Cycle 1.                                                          |
| `api/composition.yaml`               | The `cost_center:` line in the Workspace `varmap`                   | The Composition passes the developer's value to OpenTofu alongside trusted values from `environment.yaml`.                                    |
| `opentofu/managed-namespace/main.tf` | `variable "cost_center"` and where `var.cost_center` is used        | It becomes the namespace label `platform.prel37.example/cost-center` and a `cost-center` tag on the team's agent identities and App Insights. |

The Composition also creates two Argo CD AppProjects per request, both limited to the team's namespace. `beans-dev` allows the app's Deployments, Services, ConfigMaps, Secrets, and HTTPRoutes. `beans-dev-baseline` allows only ServiceAccounts, ConfigMaps, and NetworkPolicies. Neither can create cluster-wide resources or Namespaces. The baseline supplies native OTLP cloud URLs and routing attributes in `platform-context`; it does not require an `Instrumentation` CRD or a collector in the cluster.

**Expected result:** you can explain how `spec.costCenter` becomes a namespace label and resource tags. Do not edit these files.

### 5. Turn on delivery and establish the API

In the VS Code Explorer, expand 🏗️ **Platform** > **bootstrap** and open **roots.yaml**. A root `Application` is a pointer that tells Argo CD which Git folder to watch and where to apply it:

| Root `Application`  | Watches on `main` | Delivers to the control cluster              |
| ------------------- | ----------------- | -------------------------------------------- |
| `platform-system`   | `api/`            | The `AppEnvironment` XRD and its Composition |
| `platform-requests` | `requests/*.yaml` | Environment requests                         |

There is no root for the `app-deploy` repository. When a request is ready, the Composition creates that team's application delivery itself, so developers do not author Argo CD wiring.

> [!note] Both roots sync automatically and self-heal, but do not prune: deleting a request file does not tear an environment down. Removing an environment is an explicit platform team decision and action, not a side effect of a deleted file.

```bash
kubectl --context "$CONTROL_CONTEXT" apply --server-side -f "$LAB_ROOT/platform/bootstrap/roots.yaml"

# Argo CD delivers the XRD; Crossplane then serves the new API
kubectl --context "$CONTROL_CONTEXT" -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/platform-system --timeout=600s
kubectl --context "$CONTROL_CONTEXT" wait --for=create crd/appenvironments.platform.prel37.example --timeout=300s
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Established crd/appenvironments.platform.prel37.example --timeout=300s
kubectl --context "$CONTROL_CONTEXT" -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/platform-requests --timeout=600s
```

**Expected result:** within about 30 seconds, each wait reports `condition met`. In Argo CD (`https://localhost:8443`), `platform-system` and `platform-requests` are Synced and Healthy.

**Wiring checkpoint:** the `AppEnvironment` API exists, but nothing has been requested. There is still no Workspace or `beans` namespace. If a wait fails, keep the error and see [platform wiring or request API is not ready](#platform-wiring-or-request-api-is-not-ready). Do not add sleeps, broaden access, or run the module locally.

## Demonstrate: trace one request

**5 minutes. Instructor-led.** In a completed environment, the instructor shows a request, its Workspace, the managed namespace in the Azure portal, and the baseline in the workload cluster. The point to watch: one small YAML file in Git becomes Azure resources and a usable namespace, and every hop is visible.

## Guided practice: require attribution and vend the environment

**15 minutes.** You make two small PRs in order. The API must change before a request relies on it.

### Cycle 1: make cost attribution part of the contract

#### 1. See the gap

**Run in:** VS Code terminal · Platform repo

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
git --no-pager diff
```

**Expected result:** the diff shows one changed line, from `required: [team, application, owner]` to `required: [team, application, owner, costCenter]`. If the diff is empty, the `sed` did not match; check that `api/xrd.yaml` is unchanged from `main` and ask for help rather than editing other lines.

#### 3. Commit, open, review, and merge the PR

```bash
git add api/xrd.yaml
git commit -m "feat: require costCenter in AppEnvironment request"
git push -u origin update-request-schema
gh pr create --fill
```

Wait for `gh` to finish, then review the diff:

```bash
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

> [!note] If the request is still accepted, Argo CD has not delivered your merge yet. Rerun the `annotate` and `wait` commands, then check `platform-system` in the Argo CD UI.

### Cycle 2: request the environment

#### 5. Create the request on a branch

**Run in:** VS Code terminal · Platform repo

```bash
cd "$LAB_ROOT/platform"
git checkout main && git pull origin main
git checkout -b submit-env-request
if [ -e "requests/$APP_ENV.yaml" ]; then echo "STOP: requests/$APP_ENV.yaml already exists"; else cp examples/request.yaml "requests/$APP_ENV.yaml"; fi
REQUESTER_ID="$(az ad signed-in-user show --query id -o tsv)"
echo "Requester object ID: $REQUESTER_ID"
sed -i.bak "s/00000000-0000-0000-0000-000000000000/$REQUESTER_ID/" "requests/$APP_ENV.yaml" && rm "requests/$APP_ENV.yaml.bak"
git status --short
```

**Expected result:** the requester object ID line shows a GUID, and `git status --short` prints `?? requests/beans-dev.yaml`. If you see `STOP`, `requests/beans-dev.yaml` already exists from an earlier attempt in this lab. Do not overwrite it; check whether its PR already merged.

In the VS Code Explorer, expand 🏗️ **Platform** > **requests** and open **beans-dev.yaml**. Read it. Every field is intent:

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
git add "requests/$APP_ENV.yaml"
git --no-pager diff --staged --stat
git commit -m "feat: request $APP_ENV environment"
git push -u origin submit-env-request
gh pr create --fill
```

Wait for `gh` to finish, then review the diff:

```bash
gh pr diff
```

Check that the diff adds only `requests/beans-dev.yaml` and that `requesterObjectId` is not all zeros. Then merge:

```bash
gh pr merge --merge --delete-branch
```

Note the time, then ask Argo CD to check Git now. You record how long the request takes to become `Ready` in the worksheet.

```bash
date
kubectl --context "$CONTROL_CONTEXT" -n argocd annotate application platform-requests argocd.argoproj.io/refresh=normal --overwrite
```

### Trace the fulfillment

One merge starts a chain across Git, two clusters, and Azure. Allow up to 15 minutes. In rehearsal the environment became `Ready` about 7 minutes after the merge, so the 15-minute limit is a ceiling, not the usual wait. Use the wait to start on the debrief questions below. The module creates Azure resources, discovers the native OTLP endpoints, and grants the agent identities access to the application's DCR before the baseline is delivered. This checkpoint proves the connection contract exists, not that the application has exported telemetry; Module 3 proves that separately.

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

> [!knowledge] **See it in the UI while you wait.** In Argo CD (+++https://localhost:8443+++), select **Applications**. `platform-system` and `platform-requests` show **Synced** and **Healthy**. Select `platform-requests` to see the `beans-dev` AppEnvironment it applied. When the environment is ready, `beans-dev-baseline` and `fourth-coffee` tiles appear.
>
> ![Argo CD Applications list with platform-system and platform-requests Synced and Healthy, and the beans-dev AppEnvironment in the platform-requests tree](https://placehold.co/600x400){600}

When you are ready to wait for the end, run:

```bash
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Ready appenvironment "$APP_ENV" --timeout=15m
date
```

**Expected result:** `appenvironment.platform.prel37.example/beans-dev condition met`, then the current time. Record the time from the merge in step 6 to now in the worksheet. If it times out, see [environment request is merged but not ready](#environment-request-is-merged-but-not-ready).

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

**Expected result:** the ServiceAccounts `concierge` and `ops-agent`, ConfigMap `platform-context`, and NetworkPolicy `allow-platform-gateway` exist in `beans`, and the endpoint check prints `true`. Each ServiceAccount carries a different `azure.workload.identity/client-id` annotation, because each agent has its own Azure identity. The binding lists `namespace`, `serviceAccountNames`, `configMapName`, `argoProject`, `argoApplication`, `configPath`, and `appUrl`. Module 3 uses these names to connect the application. There is no `Instrumentation` resource or cluster DCR association to wait for.

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

If blocked, keep the PR and request as they are and use [Appendix A](#environment-request-is-merged-but-not-ready). Do not create the namespace by hand or run the module locally; fix the request through Git.

**What you learned:** a small request expresses intent. Platform engineers connect credentials, state, trusted mapping, and delivery boundaries so that intent becomes a usable result without a ticket.

## Break

**10 minutes, 01:15-01:25.** Keep the environment running.

===

<a id="module-3-connect-and-deploy-the-application"></a>

# Module 3: connect and deploy the application

**Duration:** 40 minutes, 01:25-02:05.
**Rhythm:** 10 minutes explanation, 5 demonstration, 15 guided practice, 5 debrief, 5 catch-up/questions.

## Objectives

By the end of this module, you will be able to:

- Bind an application to a platform-provided `ServiceAccount` and `ConfigMap`.
- Trace a Git change to the deployed application and its approved resource profile.
- Distinguish a healthy interface or fallback response from a verified model interaction.

> [!knowledge] **Platform concept: the golden path.** The supported way should be the easiest way. The platform hands the team a ready identity, configuration, and delivery pipeline; the team supplies one name and its app settings. In the BACK stack, **Argo CD** delivers the app from Git onto **Kubernetes**, using the binding that **Crossplane** published.

> [!knowledge] **AKS in action: workload identity and the managed Gateway.** The model call in this module needs no key because AKS Automatic turns on [workload identity](https://learn.microsoft.com/azure/aks/workload-identity-overview) and an OIDC issuer by default; the platform only federates each agent's ServiceAccount. Traffic reaches the app through the [App Routing Gateway API implementation](https://learn.microsoft.com/azure/aks/app-routing-gateway-api), which AKS runs and upgrades, so each team adds one route instead of operating an ingress controller. See [why AKS is the foundation](#from-promise-to-foundation).

**Starting state:** Module 2 produced the `beans` namespace and baseline, including the `concierge` and `ops-agent` ServiceAccounts and the `platform-context` ConfigMap. The platform also created the Argo CD Application `fourth-coffee`, which is waiting for your configuration. If the baseline is blocked, follow [environment troubleshooting](#environment-request-is-merged-but-not-ready) before submitting the application. You can also ask a proctor for help.

The paths below use `fourth-coffee`, the application in every fresh lab. If your lab was prepared for a different application, stop and ask a proctor; the lab image is out of date.

**Before you start:**

- [] Backstage (Terminal 2) and Argo CD (Terminal 3) are still running.
- [] You're in the VS Code terminal, and `echo $APP_ENV` prints `beans-dev`.

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

> [!note] The pinned tag `0.1.0-12.1.ge412f12`, from [source revision `969ca1acae851d0ef3cb60619d5e0d6e90523fda`](https://github.com/pauldotyu/fourth-coffee/tree/969ca1acae851d0ef3cb60619d5e0d6e90523fda), includes renewable native OTLP authentication. Its verified image-index digest is `sha256:ece6b82e6411d47a17c48e6b550eac0571e19818ecf5b1fe1d4ef0b2113fa043`. The upstream OCI chart is recorded at the same release in the artifact lock; this lab's chart adapter keeps ServiceAccounts, the route, and digest pinning platform-owned. Attendees use the published image, not a local build.

Normal deployments render the locked image digest in the Pod specification, rather than the tag, to prevent upstream tag drift. The chart deliberately renders `:latest` for the explicit `image.tag=latest` teaching fixture in Module 5; restoring the locked tag restores the digest-pinned image.

The app chart creates neither Namespace nor quota. Those stay with the environment established in Module 2.

<a id="verifying-the-outcome-with-telemetry"></a>

### Verifying the outcome with telemetry

A common trap is treating a green `Synced` status in Argo CD or a `Running` pod as proof the application works. AI applications make this trap worse: a pod can run while failing to reach the model, and the app can still return a plausible fallback reply.

A verified outcome requires three things, which steps 5 to 7 check in order:

1. **Reachability:** the application is accessible through the shared Gateway. `http://beans.localhost:8080` tunnels to the shared Gateway's ClusterIP service, not an application pod. Each team's HTTPRoute matches its own `<team>.localhost` host, so teams share the Gateway without colliding.
2. **Interaction:** a fresh user request is processed.
3. **Correlation:** telemetry proves a successful dependency call to the approved model, for this interaction rather than a historical example.

> [!hint] The value is not hiding YAML. It is making a supported deployment and connection path usable without repeated assembly work.

## Demonstrate: follow the binding

**5 minutes. Instructor-led.**

Show `status.binding` on the AppEnvironment, then the `concierge` and `ops-agent` ServiceAccounts, each annotated with a different client ID, and the `platform-context` ConfigMap it names. Open `fourth-coffee` in Argo CD while it waits for configuration, then compare desired and observed revisions after a commit.

Compare a successful model dependency with a fallback-only interaction in the instructor environment. Notice the three details that tell them apart: the time, the operation (correlation) ID, and the dependency result.

The prepared query in `queries/application-model-call.kql` joins each chat request to its model call by trace ID. It reads the `OTelSpans` table in the lab's Log Analytics workspace, filtered to the application's own [Application Insights resource](#application-telemetry). Use it rather than inventing a query from assumed event names.

## Guided practice: bind and deploy

**15 minutes.**

**New terminal? Load your environment first.** Every command depends on `lab.env`. If you opened a new terminal, or you see an empty value or an `unbound variable` error, run +++source ~/prel37/config/lab.env+++. Then +++echo "$LAB_ROOT $TEAM $APP_NAME $APP_ENV"+++ should print `/home/labuser/prel37 beans fourth-coffee beans-dev`.

### 1. Read the binding from your environment

**Run in:** VS Code terminal

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

**Run in:** VS Code terminal · App-Deploy repo (the block below changes into it, and steps 3 to 5 stay there)

Start from current `main` in the app-deploy repository and copy the two prepared files into the folder your Argo CD Application watches:

```bash
cd "$LAB_ROOT/app-deploy"
git checkout main && git pull origin main
git status --short
git checkout -b "deploy-$APP_NAME"
mkdir -p "apps/$APP_NAME"
cp "$LAB_ROOT/exercises/application/values.yaml" "$LAB_ROOT/exercises/application/profile.yaml" "apps/$APP_NAME/"
```

**Expected result:** `git status --short` prints nothing, because it runs before you copy the files. After the copy, `apps/fourth-coffee/` holds the two new files, untracked until you stage them in step 4.

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

**Expected result:** the echo prints `ConfigMap: platform-context`. Look at `values.yaml` in VS Code again; it ends with the following.

**Expected output (don't run):**

```yaml-nocopy
extraEnvFrom:
  - configMapRef:
      # status.binding.configMapName on your AppEnvironment
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

> [!knowledge] **See it in the UI.** In Argo CD (+++https://localhost:8443+++), select the `fourth-coffee` tile. It moves from **Progressing** to **Healthy** as the three Deployments roll out, and the resource tree shows each Deployment, ReplicaSet, and pod.
>
> ![Argo CD fourth-coffee application tree with three Deployments Healthy](https://placehold.co/600x400){600}

<a id="6-open-the-application-through-the-gateway"></a>

### 6. Open the application through the gateway

**Run in:** App tunnel (a new VS Code terminal). Leave it running.

With the application and route in place, open a second VS Code terminal the same way you opened the first (**Ctrl+Shift+P**, then `Terminal: Create New Terminal in Editor Area`) and rename it `app tunnel` (**Terminal: Rename**). Start the tunnel there. These commands load your lab settings, look up the shared Gateway's service, and forward local port 8080 to it, so your request still goes through the Gateway and your HTTPRoute. They work from any directory.

```bash
source "${LAB_ROOT:-$HOME/prel37}/config/lab.env"
GATEWAY_SVC=$(kubectl --context "$AKS_CONTEXT" -n platform-gateway get service -l gateway.networking.k8s.io/gateway-name=tenants -o jsonpath='{.items[0].metadata.name}')
echo "Gateway service: $GATEWAY_SVC"
kubectl --context "$AKS_CONTEXT" -n platform-gateway port-forward "service/$GATEWAY_SVC" 8080:80 --address 127.0.0.1
```

> [!hint]
> **Do not open `http://127.0.0.1:8080` or `http://localhost:8080`**, even though the terminal prints the forwarding address. That address is where the tunnel listens, not the hostname your application route expects. The Gateway routes requests by hostname, and your application's HTTPRoute matches `beans.localhost`. Using the IP address or plain `localhost` returns **404**.

**Expected result:** the terminal prints the Gateway service name, then `Forwarding from 127.0.0.1:8080 -> 80`.

> [!alert] **Keep this terminal running.** Don't press Ctrl+C or type in this terminal again. Modules 4 and 5 and the optional exercise need it. If it stops, rerun the commands above in this terminal, or run `make app` from `~/prel37/setup`.

Open a browser and enter **`http://beans.localhost:8080`**, the `appUrl` from your binding.

Browsers resolve `*.localhost` names to your own machine, so no DNS or hosts-file change is needed. If the service name is blank, the Gateway is not ready yet; return to step 5's checks.

<a id="7-verify-a-fresh-model-interaction"></a>

### 7. Verify a fresh model interaction

**Run in:** VS Code terminal (not the app tunnel)

A reply in the chat is not proof the model answered. The app can return a plausible fallback when the model call fails. This step finds the telemetry record showing your message reached the approved model and succeeded. It is the correlation check from [verifying the outcome with telemetry](#verifying-the-outcome-with-telemetry).

**1. Note the time.** In your **main VS Code terminal** (not the app tunnel), run:

```bash
date -u +%FT%TZ
```

Telemetry timestamps are in UTC, so this gives you a time to compare against.

**2. Use the app.** At `http://beans.localhost:8080`, type a message such as `Suggest two coffee options for someone who likes oat milk` and select **Send**. The barista replies with a suggestion, but a suggestion doesn't add anything to the **Order ticket**, which still says **Nothing on the ticket yet**. Then place an order:

- Select **Surprise me**, the last item in the **On the board** panel. The barista builds a drink from what's in stock and replies _Your coffee is ready: ..._, and the order ticket shows the drink and its price.
- Enter a made-up name under **Name on the cup** and select **Confirm and brew**. The barista replies with an order number and a pickup time.

Selecting another drink on the board, or typing an order, can get a clarifying reply such as _Double includes 2 shots._ instead of a draft, and the ticket stays empty. If that happens, select **Surprise me**. In a narrow browser window, such as the lab VM's, the order ticket sits below the chat; scroll down to find it, or zoom out with **Ctrl+minus** until the three columns sit side by side. Use synthetic information only.

![Fourth Coffee chat with a barista reply, a drink on the Order ticket, and the Confirm and brew button](https://placehold.co/600x400){600}

**3. Find your model call.** The agents send authenticated OTLP requests directly to Azure Monitor's cloud ingestion endpoints. The Application Insights DCR routes spans to `OTelSpans` in the lab's Log Analytics workspace, attributed to your Application Insights resource. Allow a few minutes for ingestion, then stay in your **main VS Code terminal** and leave the tunnel running. Run the following:

```bash
APPI_ID=$(kubectl --context "$CONTROL_CONTEXT" get appenvironment "$APP_ENV" -o jsonpath='{.status.appInsightsResourceId}')
LAW_CUSTOMER_ID=$(az resource show --ids "$LOG_ANALYTICS_WORKSPACE_ID" --query properties.customerId -o tsv)
echo "APPI_ID=$APPI_ID LAW_CUSTOMER_ID=$LAW_CUSTOMER_ID"
az monitor log-analytics query --workspace "$LAW_CUSTOMER_ID" \
  --analytics-query "let app = '$APPI_ID'; $(cat "$LAB_ROOT/queries/application-model-call.kql")" \
  -o table
```

The `echo` line shows both values. If either is blank, the query returns no rows, which looks like slow ingestion. Check that you ran `source ~/prel37/config/lab.env` in this terminal and that the Module 2 checkpoint passed. The first `az monitor log-analytics` command may stop to ask whether to install the `log-analytics` extension. If it does, answer **Y**; it is a preview extension, so `az` also prints a warning, which is expected.

The query returns one row per model call made while answering a chat message in the last 30 minutes, filtered to your application's resource. One chat message can make more than one model call.

**Expected result:** at least one row with a `RequestTime` later than the time you noted, `ModelTarget` set to your lab's `openai.azure.com` endpoint, `ModelSuccess` of `True`, and `ModelResult` of `200`. The `TraceId` ties your chat request to that model call.

- **No rows yet:** wait a minute and rerun. If a fresh interaction still produces no rows, check endpoint configuration and exporter authentication errors in [Appendix A](#current-application-telemetry-is-missing-or-denied). There is no node receiver or cluster DCR association to warm up.
- **Only older rows:** your new message has not arrived yet, or it was answered without the model. Send another free-text message and rerun.
- **`ModelSuccess` is `False`:** the app answered with a fallback. Check the binding from step 1 and [Appendix A](#appendix-a-troubleshooting-and-safe-recovery).

<a id="application-telemetry"></a>

To see the same interaction in the Azure portal, print the link to your Application Insights resource:

```bash
kubectl --context "$CONTROL_CONTEXT" get appenvironment "$APP_ENV" -o json |
  jq -er '.status.appInsightsResourceId |
    if type == "string" and length > 0 then "https://portal.azure.com/#resource\(.)"
    else error("Application Insights has not been vended yet") end'
```

Open the link, select **Investigate** > **Search** (or the **Tracing** view), and open a request from after the time you noted whose URL ends in `/api/chat`. The list shows these as `POST /`, so check the URL. Skip `/api/confirm` requests: confirming an order calls the MCP tools, not the model. In the end-to-end view, expand **CoffeeConcierge** > **ConciergeRouter** > **lab-model**. Under it, the `aoai-...openai.azure.com:443` dependency should show result `200`. That is the model call, in the same trace as your chat request. Your account can read this telemetry because you are the builder. That does not prove that other users are blocked from it.

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

Compare the application files with the staged scaffolds, the AppEnvironment `status.binding`, and the approved profiles when investigating a mismatch. Ask a proctor to help submit a correction. Record assistance or demonstration-only results honestly. Do not bypass the Gateway by forwarding an application pod's port.

Use [application troubleshooting](#application-is-synced-but-not-usable) or [model evidence troubleshooting](#model-evidence-is-missing-or-fallback-only) if needed.

**What you learned:** a supported platform connection includes identity, configuration, delivery, and evidence of the application's actual behavior.

===

<a id="module-4-complete-the-self-service-interface"></a>

# Module 4: complete the self-service interface

**Duration:** 40 minutes, 02:05-02:45.
**Rhythm:** 10 minutes explanation, 5 demonstration, 15 guided practice, 5 debrief, 5 catch-up/questions.

## Objectives

By the end of this module, you will be able to:

- Explain the difference between a supported interface and an authorization boundary.
- Offer a developer a decision (a named profile) instead of implementation details (CPU and memory numbers).
- Use Backstage to change the running application through the same GitOps path you used in Module 3.

> [!knowledge] **Platform concept: the self-service portal is a front door, not a second pipeline.** A developer portal makes a supported change easy to find and request. It does not get its own permissions or its own way to deploy. In the BACK stack, **Backstage** turns a form into a pull request, and **Argo CD** delivers the merged result exactly as it did in Module 3.

> [!knowledge] **AKS in action: node autoprovisioning.** The standard profile doubles the agents' CPU and memory requests. Nobody files a ticket for bigger nodes: on the AKS Automatic workload cluster, [node autoprovisioning](https://learn.microsoft.com/azure/aks/node-auto-provisioning) adds right-sized capacity when existing nodes cannot fit the new requests. The developer chooses a profile; the platform's quota bounds it; AKS supplies the nodes. See [why AKS is the foundation](#aks-standard-and-aks-automatic).

**Starting state:** Fourth Coffee runs in `beans` with the `small` profile. Backstage is running at `http://localhost:3000` and the Argo CD tunnel at `https://localhost:8443`. If either stopped, restart it as shown in [Start Backstage and Argo CD](#start-backstage-and-argo-cd). This module does not create another repository, application, or namespace.

**Before you start:**

- [] Backstage (Terminal 2) and Argo CD (Terminal 3) are still running.
- [] You're in the VS Code terminal, and `echo $APP_ENV` prints `beans-dev`.
- [] The app tunnel is running, and +++http://beans.localhost:8080+++ loads.

## The pattern: self-service as a fulfillment path

A common misconception is that a developer portal such as Backstage replaces the deployment pipeline. It does not. The portal is a front door: a way to make a supported change easy to find and request.

In a mature platform, the portal has no separate permissions and no hidden way to deploy. It uses the same GitOps path you used in Module 3. When a developer completes a form in Backstage, the portal is not deploying the app; it is authoring a pull request.

The template in this module shows the pattern in two steps:

1. **Fetch the approved profile:** downloads a specific, versioned YAML file from the platform repository.
2. **Propose the profile change:** opens a PR in the application repository that replaces only the `profile.yaml` file.

Because every change goes through Git, there is one source of truth and one audit trail, whether the change came from a portal form or an engineer's editor.

### Offer a decision, not an implementation

**Why this matters:** every low-level setting a developer must choose is cognitive load, and a chance to get it wrong. A platform reduces that load by offering a decision instead of the details behind it.

Instead of asking for CPU and memory numbers ("I need 400m CPU and 512Mi RAM"), the platform offers named choices: `small` or `standard`.

| Profile    | What the developer asks for          | What the platform sets          |
| :--------- | :----------------------------------- | :------------------------------ |
| `small`    | "I need a basic dev environment"     | 200m CPU, 256Mi RAM (per agent) |
| `standard` | "I need more headroom for my agents" | 400m CPU, 512Mi RAM (per agent) |

The platform team defines what these names mean in the platform repository (`profiles/workload-small.yaml` and `profiles/workload-standard.yaml`). Backstage copies one of those approved files, so a request made through the form stays aligned with the approved sizes. The namespace quota is the only bound the platform enforces on size: the chart schema does not check CPU or memory values, so a hand-edited `profile.yaml` is stopped only when its total exceeds the quota.

### The front door and the pipeline

The portal is the _interface_, not the _implementation_.

- **The front door (Backstage):** handles discovery, intake, and user experience.
- **The pipeline (Git, Argo CD, AKS):** handles authorization, validation, and fulfillment.

Because the portal only writes to Git, the platform can layer its governance:

1. **Interface:** the dropdown (`enum`) limits the choices a developer sees.
2. **Review:** the pull request lets a person or a bot check the change.
3. **Admission:** Kubernetes admission policy, the namespace quota, and the chart's Helm schema (which checks the image, the identity mapping, and the configuration reference) validate the final YAML before it is applied.

> [+Hint] Why the dropdown alone isn't a control
>
> A dropdown alone is not a control. Anyone with write access can skip the UI and commit an invalid value directly to Git. Placing the real controls in the pipeline keeps the platform safe even when the front door is bypassed. This is the difference between a supported interface and an authorization boundary.

### The full loop: from request to runtime

In a ticket-driven process, a closed ticket is the end of the story. In platform engineering, a change is not done until you observe it in the running environment.

A finished Backstage task means only that a PR was opened. A merged PR means only that the desired state changed. The loop closes when Argo CD reconciles the change and the pods restart with the new resources. Steps 5 to 7 walk each of those stages.

> [!hint] Link the portal's success page to the delivery pipeline, as this template does with an Argo CD link. It shifts the developer's focus from "I submitted the form" to "my application is running with the new resources."

## Demonstrate: follow the template-to-Git path

**5 minutes. Instructor-led.**

The instructor opens `backstage/templates/ai-app/template.yaml` and shows the profile parameter, the two steps, and the two output links. Then they show that a template change is just another platform PR, and that Backstage reads the merged file from GitHub, not your local copy.

You do not write a Backstage action, register the catalog, or wire output links.

## Guided practice: complete one choice and use it

**15 minutes.**

**New terminal? Load your environment first.** Every command depends on `lab.env`. If you opened a new terminal, or you see an empty value or an `unbound variable` error, run +++source ~/prel37/config/lab.env+++. Then +++echo "$LAB_ROOT $TEAM $APP_NAME $APP_ENV"+++ should print `/home/labuser/prel37 beans fourth-coffee beans-dev`.

### 1. Read the template you will change

In the VS Code Explorer, expand 🏗️ **Platform** > **backstage** > **templates** > **ai-app** and open **template.yaml**. Find the `profile` property under `parameters`, marked with a `Module 4` comment.

**File excerpt (don't run):**

```yaml-nocopy
profile:
  title: Resource profile
  type: string
  # Module 4: add standard and explain the supported choice.
  description: Choose the small profile.
  enum: [small]
  default: small
```

`enum` is the list the dropdown offers. `description` is the help text under the field. Further down, the `profile` step builds the file URL from the selected value, so adding a name to `enum` works only because `profiles/workload-standard.yaml` already exists. The platform defines the profile first; the template just exposes it. Read the file here, and make the change in the terminal in the next step.

<a id="2-add-the-standard-profile-to-the-selector"></a>

### 2. Add the standard profile to the selector

**Run in:** VS Code terminal · Platform repo (the block below changes into it)

In your VS Code terminal, run:

```bash
cd "$LAB_ROOT/platform"
git checkout main && git pull origin main
git status --short
git checkout -b add-standard-profile
sed -i.bak \
  -e 's/enum: \[small\]/enum: [small, standard]/' \
  -e 's/description: Choose the small profile\./description: Choose using demand evidence. Standard has higher app requests and memory limits; namespace quota is unchanged./' \
  backstage/templates/ai-app/template.yaml && rm backstage/templates/ai-app/template.yaml.bak
git --no-pager diff
```

**Expected result:** `git status --short` prints nothing, and the diff shows exactly two changed lines: `description` and `enum`. If the diff is empty, the file did not match what step 1 showed; ask for help rather than editing other lines.

A template change is a platform change, so it goes through a PR like any other. Commit only the template, then open the PR:

```bash
git add backstage/templates/ai-app/template.yaml
git commit -m "feat: offer the standard profile in Backstage"
git push -u origin add-standard-profile
gh pr create --fill
```

Wait for `gh` to finish, then review the diff:

```bash
gh pr diff
```

The diff shows the same two lines. Then merge:

```bash
gh pr merge --merge --delete-branch
```

**Expected result:** `gh` reports the PR merged with your clone back on `main`.

### 3. Refresh the published template in Backstage

Backstage reads the template from GitHub and re-checks it every few minutes. Refreshing makes it check now.

1. Open `http://localhost:3000/catalog/default/template/app-profile`. This is the **Resize an application** template. You can also reach it from **Catalog** by setting the **Kind** filter to **Template**.
2. On the **About** card, select **Refresh** (the circular arrow). Wait about 10 seconds.
3. On the same card, select **Launch Template**.
4. Open the **Resource profile** dropdown. Do not submit yet.

**Expected result:** the dropdown offers `small` and `standard`, with `small` selected, and the help text reads "Choose using demand evidence. Standard has higher app requests and memory limits; namespace quota is unchanged."

![Backstage Resize an application form with the Resource profile dropdown open, showing small and standard](https://placehold.co/600x400){600}

If you still see "Choose the small profile.", wait a minute, reload the page, and select **Refresh** again. If it persists, use [Backstage troubleshooting](#backstage-shows-an-old-template-or-no-usable-result).

### 4. Request the standard profile

**Run in:** VS Code terminal · App-Deploy repo (the block below changes into it, and steps 5 to 7 stay there)

First, confirm which profile the app runs today. `profile.yaml` is an exact copy of one approved file and has no name field, so compare it with each. In your VS Code terminal, run:

```bash
cd "$LAB_ROOT/app-deploy"
git checkout main && git pull origin main
for p in small standard; do
  diff -q "apps/$APP_NAME/profile.yaml" "$LAB_ROOT/platform/profiles/workload-$p.yaml" >/dev/null && echo "current profile: $p"
done
```

**Expected result:** `current profile: small`. If it already says `standard`, a new request has nothing to change. Backstage usually fails the task, for example with a `null response from GitHub` error, instead of opening a PR. Record that as a verified no-change result.

Back in the Backstage form:

1. **Application:** select `fourth-coffee`. After you pick it, the field shows the catalog reference `component:default/fourth-coffee`. The picker lists only Components your team owns.
2. **Resource profile:** select `standard`.
3. Select **Review**, check the two values, then select **Create**.

**Expected result:** within about 10 seconds, both steps (**Fetch the approved profile** and **Propose the profile change**) show as complete, and two buttons appear: **Review the pull request** and **Follow application delivery in Argo CD**. Backstage opened the PR from branch `backstage/fourth-coffee-profile-standard`. It did not merge it; that is your job as reviewer. This is the interface handing off to the pipeline.

### 5. Review and merge the generated PR

Review the PR from your terminal, the same way you review your own. A portal-generated change gets no special trust:

```bash
cd "$LAB_ROOT/app-deploy"
gh pr view "backstage/$APP_NAME-profile-standard" --json title --jq .title
gh pr diff "backstage/$APP_NAME-profile-standard" --name-only
gh pr diff "backstage/$APP_NAME-profile-standard"
```

**Expected result:** the first command prints **Use the standard profile for fourth-coffee**. The only changed file is `apps/fourth-coffee/profile.yaml`. In it, `opsAgent` and `concierge` move from `200m, 256Mi` requests and a `768Mi` memory limit to `400m, 512Mi` requests and a `1536Mi` limit. `fourthCoffeeMcp` and `values.yaml` are untouched. If the PR changes any other file, do not merge it; ask for help.

Merge it:

```bash
gh pr merge "backstage/$APP_NAME-profile-standard" --merge --delete-branch
```

When `gh` finishes, confirm `main` matches the standard profile:

```bash
git checkout main && git pull origin main
for p in small standard; do
  diff -q "apps/$APP_NAME/profile.yaml" "$LAB_ROOT/platform/profiles/workload-$p.yaml" >/dev/null && echo "current profile: $p"
done
```

**Expected result:** `current profile: standard`.

<a id="6-confirm-argo-cd-delivered-the-change"></a>

### 6. Confirm Argo CD delivered the change

Merging the PR was the whole request. No platform engineer touches it from here. Use the same check as Module 3: refresh, then wait for your commit.

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd annotate application "$APP_NAME" argocd.argoproj.io/refresh=normal --overwrite
MERGED="$(git rev-parse HEAD)"
kubectl --context "$CONTROL_CONTEXT" -n argocd wait application/"$APP_NAME" --for=jsonpath="{.status.sync.revisions[1]}=$MERGED" --timeout=300s
```

**Expected result:** `condition met`, usually within seconds. You can watch the same rollout in the Argo CD UI from the task's **Follow application delivery in Argo CD** button.

Argo CD can report `Healthy` before Kubernetes finishes replacing the old pods, so wait on the Deployments themselves:

```bash
for d in concierge ops-agent fourth-coffee-mcp; do
  kubectl --context "$AKS_CONTEXT" -n "$TEAM" rollout status deployment/"$d" --timeout=300s
done
```

**Expected result:** `successfully rolled out` for all three, usually within two minutes.

### 7. Check what is actually running

Ask the workload cluster what each Deployment runs, rather than trusting the PR:

```bash
kubectl --context "$AKS_CONTEXT" -n "$TEAM" get deployments \
  -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,CPU_REQ:.spec.template.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.template.spec.containers[0].resources.requests.memory,CPU_LIM:.spec.template.spec.containers[0].resources.limits.cpu,MEM_LIM:.spec.template.spec.containers[0].resources.limits.memory'
```

**Expected result (output, don't run):**

```text-nocopy
NAME                READY   CPU_REQ   MEM_REQ   CPU_LIM   MEM_LIM
concierge           1       400m      512Mi     1         1536Mi
fourth-coffee-mcp   1       100m      128Mi     500m      256Mi
ops-agent           1       400m      512Mi     1         1536Mi
```

Kubernetes shows a `1000m` CPU limit as `1`. **What this means:** `concierge` and `ops-agent` run the standard values, `fourth-coffee-mcp` keeps its own settings, and the namespace quota is unchanged. The request made it all the way from a form to the running pods. If the larger requests did not fit on the existing nodes, node autoprovisioning added capacity during the rollout, with no node pool for anyone to resize.

The pods restarted, so start a new chat at `http://beans.localhost:8080` before you continue. If the page doesn't load, restart the gateway tunnel from [Module 3, step 6](#6-open-the-application-through-the-gateway).

## Debrief: did this remove a handoff?

**5 minutes. Pause editing.**

Walk the path you just used: form, PR, review, merge, Argo CD, running Deployments. Where would a ticket and a platform engineer have sat in a traditional process?

Then separate a supported change from an exception. A larger namespace quota, production access, or a different model is outside this template's promise and needs a different route.

Finally, discuss what evidence would justify `standard`. The exercise shows the change path; it does not prove the larger profile is right for every workload.

**Takeaway:** find the most common ticket your platform team fulfills by hand, such as a resize, a new environment variable, or a scaling change. If the safe answers fit in a short list, that list is a template with an `enum`, and the fulfillment is a PR into a repository you already deliver with GitOps.

## Catch-up and checkpoint

**5 minutes.**

| Check                                                                   | Evidence                                  |
| ----------------------------------------------------------------------- | ----------------------------------------- |
| The template offers `small` and `standard` with the new description     | Step 3 dropdown                           |
| Backstage opened a PR changing only `apps/fourth-coffee/profile.yaml`   | Step 5 `gh pr diff --name-only`           |
| Argo CD deployed the merged commit and all three Deployments rolled out | Step 6 `condition met` and rollout status |
| `concierge` and `ops-agent` run `400m`/`512Mi` requests                 | Step 7 table                              |

A successful Backstage task alone does not pass the checkpoint. If fulfillment is blocked, keep the task link and the PR and use [template troubleshooting](#backstage-shows-an-old-template-or-no-usable-result) rather than recreating anything.

**What you learned:** a self-service interface offers understandable choices and connects them to enforced, observable fulfillment.

## Break

**10 minutes, 02:45-02:55.** Reconciliation may continue. Do not use the break as mandatory lab time.

===

<a id="module-5-recover-inspect-telemetry-and-evaluate-cost"></a>

# Module 5: recover, inspect telemetry, and evaluate cost

**Duration:** 45 minutes, 02:55-03:40.
**Rhythm:** 10 minutes explanation, 5 monitoring demonstration, 15 guided recovery practice, 10 cost/debrief discussion, 5 catch-up/questions.

## Objectives

By the end of this module, you will be able to:

- Find the reason for a rejected deployment and correct the desired state through Git.
- Explain what current container logs and application traces show, and why they do not prove authorization isolation.
- Make one resource-profile decision without confusing quota, allocated costs, and monetary budgets.

> [!knowledge] **Platform concept: guardrails with a recovery path.** A guardrail is only useful if the developer it stops can see why and fix it without filing a ticket. In the BACK stack, **Kubernetes** admission (AKS Deployment Safeguards) blocks the unsafe change, **Argo CD** shows the reason, and Git is the only way back.

> [!knowledge] **AKS in action: secure by default.** You do not install the policy that rejects `latest`. AKS Automatic enforces [Deployment Safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards) and baseline Pod Security Standards through Azure Policy from the moment the cluster exists, and [automatic upgrades](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster) keep the cluster and node images patched without a platform ticket. The platform team builds its recovery path on guardrails it does not have to operate. Cluster telemetry comes the same way: Container Insights and managed Prometheus are on, alongside the application traces you query here. See [why AKS is the foundation](#aks-standard-and-aks-automatic).

**Starting state:** Module 4's `standard` profile is delivered and all three Deployments are ready. Confirm with:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd get application "$APP_NAME" -o custom-columns=SYNC:.status.sync.status,HEALTH:.status.health.status
```

**Expected result:** `Synced` and `Healthy`. If not, finish [Module 4, step 6](#6-confirm-argo-cd-delivered-the-change) first.

**Before you start:**

- [] Backstage (Terminal 2) and Argo CD (Terminal 3) are still running.
- [] You're in the VS Code terminal, and `echo $APP_ENV` prints `beans-dev`.
- [] The app tunnel is running, and +++http://beans.localhost:8080+++ loads.
- [] You have time for step 5, which can take up to 10 minutes.

## Why guardrails need a recovery path

An opaque "Access Denied" or a generic "Internal Server Error" does not remove work. It moves the troubleshooting from the developer to the platform team and creates the very tickets the platform was meant to eliminate.

A useful guardrail tells the developer three things:

1. **What was blocked?** For example, "The update to the `concierge` deployment was rejected."
2. **Which field caused it?** For example, "The `image.tag` field was set to `latest`."
3. **What is the supported value?** For example, "Use a specific, immutable image digest or version tag."

In this exercise, you will set `image.tag` to `latest`. The Helm chart's schema allows it, but the AKS admission policy (Deployment Safeguards) rejects mutable tags. You will watch the platform reject it, then recover the supported way: correct the source in Git and let Argo CD converge.

### Sync and health answer different questions

Argo CD reports two separate statuses. Knowing which one changed tells you whether you have a blocked change or an outage.

| Status     | Question it answers                                   | Meaning in this exercise                                                              |
| ---------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Sync**   | Does the cluster match what Git asks for?             | `OutOfSync`. The cluster does not match Git because the platform rejected the change. |
| **Health** | Are the resources that are currently running working? | `Healthy`. The last accepted version of the app keeps running and serving traffic.    |

Admission policy rejects the change _before_ any pod is replaced. The update fails, but the application stays up. That safe failure is what you will confirm in step 3.

### Telemetry is not an access boundary

Application teams need logs, traces, and metrics to debug their apps, but they should not get workspace-wide visibility into every team's data. Handing every team one broad "Monitoring" role is a common design mistake; a platform should aim for **scoped telemetry access**.

In this lab, the binding from Module 3 identifies the telemetry destination. The approved image uses workload identity to get ingestion tokens, and read access is a separate grant. The OTLP URLs and Application Insights routing attribute say _where_ data goes; they do not grant permission to _read_ it. Keeping `beans` data out of view of other teams, such as `coffee-ops`, needs its own verified read permissions, which this lab does not test.

### Resource limits are not budgets

Resource quotas and monetary budgets are easy to confuse. They are related, but they answer different questions.

| Control                 | What it governs               | Why it matters                                                   |
| :---------------------- | :---------------------------- | :--------------------------------------------------------------- |
| **Requests and Limits** | CPU/Memory per container      | Governs scheduling and stability (preventing "noisy neighbors"). |
| **Namespace Quota**     | Total CPU/Memory for the team | Governs the overall footprint of the team's environment.         |
| **Cost Allocation**     | Who pays for the consumption  | Governs accountability and chargebacks (TCO).                    |
| **Budget**              | Spending thresholds           | Governs financial risk and alerting.                             |

None of these substitutes for another. A strict CPU limit does not stop overspending on an expensive high-memory node. Model tokens are billed separately from Kubernetes resources, so quota does not cap them either.

> [!hint] When a developer asks for "more resources," first ask whether they are hitting a container limit (performance) or the namespace quota (capacity). The fixes are different.

<a id="demonstrate-inspect-current-application-telemetry"></a>

## Demonstrate: inspect current application telemetry

**5 minutes. Instructor-led.**

The instructor makes a fresh synthetic chat in the app and shows two views.

**Container logs** show what each process printed:

```bash
kubectl --context "$AKS_CONTEXT" -n "$TEAM" logs -l app.kubernetes.io/part-of="$APP_NAME" --all-containers=true --prefix --tail=20
```

`--prefix` labels each line with its pod and container. Most lines are `/healthz` probes; a `POST /api/chat` line shows the request arrived, not that the model answered.

**Traces** show what the request did. Rerun the model-call query from [Module 3, step 7](#7-verify-a-fresh-model-interaction) and find a row newer than the chat with `ModelSuccess` of `True`.

**Expected result:** a current log line for the chat and a correlated model-call row. If the row is missing, record it as pending; ingestion takes a few minutes. This shows operating information, not an access boundary.

## Guided practice: reject and recover one change

**15 minutes.**

**New terminal? Load your environment first.** Every command depends on `lab.env`. If you opened a new terminal, or you see an empty value or an `unbound variable` error, run +++source ~/prel37/config/lab.env+++. Then +++echo "$LAB_ROOT $TEAM $APP_NAME $APP_ENV"+++ should print `/home/labuser/prel37 beans fourth-coffee beans-dev`.

### 1. Make the unsafe change

**Run in:** VS Code terminal · App-Deploy repo (the block below changes into it, and steps 2 to 5 stay there)

Start from current `main`, which includes Module 4's profile change. In your VS Code terminal, run:

```bash
cd "$LAB_ROOT/app-deploy"
git checkout main && git pull origin main
git status --short
git checkout -b try-latest-tag
sed -i.bak 's/^  tag: ".*"/  tag: "latest"/' "apps/$APP_NAME/values.yaml" && rm "apps/$APP_NAME/values.yaml.bak"
git --no-pager diff
```

**Expected result:** `git status --short` prints nothing, and the diff shows one line, from the organizer-approved image tag to `tag: "latest"`. `profile.yaml` stays at `standard`. Backstage never offers a mutable tag; you are making this change by hand only to watch the guardrail work. If the diff is empty, the `sed` did not match; check that `apps/fourth-coffee/values.yaml` is unchanged from `main` and ask for help rather than editing the file by hand.

In the VS Code Explorer, expand 🚀 **App-Deploy** > **apps** > **fourth-coffee** and open **values.yaml** to see the change in context. `image.tag` is the only line you touched.

### 2. Merge it and let Argo CD try

```bash
git add "apps/$APP_NAME/values.yaml"
git commit -m "test: use the latest image tag"
git push -u origin try-latest-tag
gh pr create --fill
```

Wait for `gh` to finish, then list the files in the PR:

```bash
gh pr diff --name-only
```

Then merge:

```bash
gh pr merge --merge --delete-branch
```

**Expected result:** `gh pr diff --name-only` lists only `apps/fourth-coffee/values.yaml`, and the PR merges. If a branch check blocks the merge, don't disable it. That check is another enforcement point; note it and see [failure/recovery troubleshooting](#the-seeded-failure-does-not-match-or-recovery-is-stuck).

Now have Argo CD pick up the merge, using the same commands as Module 4:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd annotate application "$APP_NAME" argocd.argoproj.io/refresh=normal --overwrite
MERGED="$(git rev-parse HEAD)"
kubectl --context "$CONTROL_CONTEXT" -n argocd wait application/"$APP_NAME" --for=jsonpath="{.status.sync.revisions[1]}=$MERGED" --timeout=300s
```

**Expected result:** `condition met`. Argo CD has fetched your commit. Next you see what it could do with it.

### 3. Read the failure

Wait about 20 seconds for the first sync attempt, then look in three places.

**Is the app in sync?**

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd get application "$APP_NAME" \
  -o custom-columns=SYNC:.status.sync.status,HEALTH:.status.health.status,OPERATION:.status.operationState.phase
```

**Expected result:** `OutOfSync`, `Healthy`, and `Running`. `Running` means Argo CD is retrying the sync.

**Why was it rejected?**

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd get application "$APP_NAME" -o json |
  jq -r '.status.operationState.syncResult.resources[]? | select(.status=="SyncFailed") | "\(.name): \(.message)"'
```

If this prints nothing, Argo CD is mid-retry and hasn't recorded the results yet. Wait 15 seconds and rerun it.

**Expected result:** one line each for `concierge`, `ops-agent`, and `fourth-coffee-mcp`, each containing `admission webhook "validation.gatekeeper.sh" denied the request`, a rule named `azurepolicy-k8sazurev2containernolatestima-...`, and `Avoiding the latest tag for container`. The message also says `[Implied by gatekeeper-expand-workloads]`: Gatekeeper checks the pods that each Deployment would create, so the Deployment is rejected before any pod is replaced. That is the AKS Deployment Safeguards rule against `latest` images. An image-pull error or a different rule name means something else went wrong; see [failure/recovery troubleshooting](#the-seeded-failure-does-not-match-or-recovery-is-stuck).

The same message appears in the Argo CD UI at `https://localhost:8443`: open `fourth-coffee` and select the sync status.

![Argo CD fourth-coffee sync status panel showing the Gatekeeper denial for the latest image tag](https://placehold.co/600x400){600}

**Is the app still up?**

```bash
kubectl --context "$AKS_CONTEXT" -n "$TEAM" get deployments \
  -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'
```

**Expected result:** all three are ready and still run `ghcr.io/pauldotyu/fourth-coffee@sha256:...`, the digest-pinned image. `http://beans.localhost:8080` still works. A bad change was blocked, and nothing went down.

Admission works per object, not per sync. Only the three Deployments violate the policy, so the rest of the chart can still be applied: the ConfigMap `app-config`, for example, can now carry `APP_VERSION: "latest"`. The recovery PR sets it back along with the image tag.

In the worksheet, record the rule name, the field that caused it (`image.tag` in `values.yaml`), and the fix: restore the locked tag through Git.

<a id="4-restore-the-approved-tag-through-git"></a>

### 4. Restore the approved tag through Git

The approved tag lives in the lab's artifact lock. Create a recovery branch and put it back:

```bash
cd "$LAB_ROOT/app-deploy"
git checkout main && git pull origin main
git checkout -b restore-image-tag
TAG="$(jq -er '.application.imageTag' "$LAB_ROOT/config/artifact-lock.json")" &&
  echo "Approved tag: $TAG" &&
  sed -i.bak "s/^  tag: \"latest\"/  tag: \"$TAG\"/" "apps/$APP_NAME/values.yaml" && rm "apps/$APP_NAME/values.yaml.bak"
git --no-pager diff
```

**Expected result:** `Approved tag:` followed by the verified tag in `config/artifact-lock.json`, and the diff changes one line from `tag: "latest"` back to that tag. If the lookup fails, the `sed` does not run and the diff is empty. Stop and ask a proctor; do not guess a tag.

Commit the fix and open the PR:

```bash
git add "apps/$APP_NAME/values.yaml"
git commit -m "fix: restore the approved image tag"
git push -u origin restore-image-tag
gh pr create --fill
```

Wait for `gh` to finish, then list the files in the PR:

```bash
gh pr diff --name-only
```

Then merge:

```bash
gh pr merge --merge --delete-branch
```

### 5. Confirm the recovery converged

Refresh Argo CD and wait for it to sync. Allow up to 10 minutes: Argo CD first finishes retrying the bad commit (about five minutes), then applies your fix.

> [!note] While you wait, keep `fourth-coffee` open in Argo CD. The sync status counts retry attempts on the bad commit, then switches to your fix and returns to **Synced**.

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd annotate application "$APP_NAME" argocd.argoproj.io/refresh=normal --overwrite
MERGED="$(git rev-parse HEAD)"
kubectl --context "$CONTROL_CONTEXT" -n argocd wait application/"$APP_NAME" --for=jsonpath="{.status.sync.revisions[1]}=$MERGED" --timeout=300s
kubectl --context "$CONTROL_CONTEXT" -n argocd wait application/"$APP_NAME" --for=jsonpath='{.status.sync.status}'=Synced --timeout=600s
kubectl --context "$CONTROL_CONTEXT" -n argocd get application "$APP_NAME" \
  -o custom-columns=SYNC:.status.sync.status,HEALTH:.status.health.status,OPERATION:.status.operationState.phase
```

**Expected result:** two `condition met` lines, then `Synced`, `Healthy`, and `Succeeded`. While you wait, the operation phase stays `Running` and its message counts retry attempts; that is expected.

The pods probably don't restart. The locked tag resolves to the same digest that was already running, so the desired state matches what is there. Recovery means convergence to the approved configuration, not a forced restart. Start a fresh chat at `http://beans.localhost:8080` to confirm the app still answers.

Do not patch the live Deployment, exclude the namespace from policy, or disable safeguards.

### 6. Evaluate the recovery runbook

In the VS Code Explorer, expand 🏗️ **Platform** > **docs** and open **recovery.md**. This is the runbook a developer finds when a change is blocked. Compare it with what you just did and note one improvement in the worksheet. For example: does it mention the retry wait you just sat through? Publishing a documentation PR is optional take-home work.

## Discuss: make one cost decision

**10 minutes. Instructor-facilitated. No calculator or billing setup is required.**

In the VS Code Explorer, expand 📁 **Lab Root** > **evidence** and open **profile-comparison.md**. Start with provenance: this file is calculated from the profile files, not measured usage or a billing export.

### Compare configuration with the quota

Check what the namespace quota counts:

```bash
kubectl --context "$AKS_CONTEXT" -n "$TEAM" get resourcequota
```

**Expected result:** `requests.cpu: 900m/2`, `requests.memory: 1152Mi/3Gi`, `limits.cpu: 2500m/6`, and `limits.memory: 3328Mi/8Gi`. The used values are exactly the `standard` totals from the evidence file, and the quota itself did not change in Module 4.

Discuss with the evidence file:

- During a rolling update every Deployment briefly runs two pods. Standard requests would then total `1800m` and `2304Mi`, close to the `2000m` CPU quota. Arithmetic alone does not prove the rollout fits; observed rollouts do.
- These numbers describe configuration, not demand. Without a sourced usage window, memory peaks, and service needs, the honest answer may be "evidence is insufficient."
- Do not cut requests just because a quiet interval showed low usage.

### Explain what might change on the bill

A smaller request changes scheduling and cost allocation. It does not guarantee fewer nodes or a lower Azure bill; cluster capacity, shared services, and idle overhead still count. Model tokens are priced separately, namespace quota does not cap them, and a Cost Management budget alerts an owner but does not stop the app.

### Record one decision

In the worksheet, record:

- Your profile recommendation, or "evidence is insufficient."
- One measurement you would need before claiming savings.
- Who should respond to a cost alert for this app.

Do not submit another profile change. Do not present illustrative numbers as observed savings.

## Debrief and checkpoint

**5 minutes.**

**Takeaway:** pick one policy your clusters enforce today. Walk through what a developer sees when it blocks them: is the rule name readable, does the message name the field, and does a runbook point to the supported value? If any answer is no, that gap creates tickets, and it is the platform team's to close.

| Check                                                             | Evidence                                       |
| ----------------------------------------------------------------- | ---------------------------------------------- |
| The `latest` tag was rejected at admission, and the app stayed up | Step 3 rejection message and ready Deployments |
| The fix went through Git and Argo CD converged                    | Step 5 `Synced`, `Healthy`, `Succeeded`        |
| One cost decision with its evidence, or "insufficient"            | Worksheet                                      |

Record both PR numbers and the actual rejection reason. If recovery is stuck past 10 minutes, use [failure/recovery troubleshooting](#the-seeded-failure-does-not-match-or-recovery-is-stuck).

**What you learned:** operating a capability means making failures, access boundaries, and cost trade-offs understandable without bypassing its controls.

===

<a id="module-6-plan-the-next-platform-milestone"></a>

# Module 6: plan the next platform milestone

**Duration:** 20 minutes, 03:40-04:00.
**Rhythm:** 5 minutes explanation, 10 product exercise, 5 sharing/questions.

## Objectives

By the end of this module, you will be able to:

- Use observed friction to choose one next improvement or experiment.
- Define a developer outcome measure without inventing a baseline.
- Keep ownership, non-goals, and a feedback checkpoint explicit.

> [!knowledge] **Platform concept: evidence and feedback.** A platform is never done. The next investment should follow observed developer friction and a measure you can collect, not the next tool on a list. The BACK stack gave you the evidence: Git history, Argo CD status, admission messages, and telemetry.

No further cloud or application changes are required.

## Evolve the platform from evidence

Successful platforms do not grow by adding the next tool on a list. They grow by responding to observed developer friction.

The goal is to move from "I think we need this tool" to "I have evidence that this specific task causes friction for these developers." Your own run produced that kind of evidence: PR history, Argo CD sync status, the admission rejection message, and model-call telemetry.

### Separate observations from hypotheses

Keep what you _saw_ apart from what you _think_ will fix it. The examples below are illustrative, not data from this lab.

- **Observation:** "Three developers spent 20 minutes finding why their deployment was rejected." This records friction.
- **Hypothesis:** "If the Backstage task output includes the rejection reason, time to resolve a rejected change drops from 20 minutes to 2." This is a testable proposal.

Shipping a change without a clear hypothesis tends to produce feature bloat: capabilities developers do not value. If you only watched a demonstration during this workshop, record that limitation. A successful demonstration is a proof of concept, not evidence of customer demand.

### Measure tasks, not users

Raw user counts mislead when the platform is mandatory. Measure adoption as the share of teams on the supported path versus working around it. Task-based measures tell you whether developer work actually got easier.

| Metric                  | What it measures                                           | Why it matters                                         |
| :---------------------- | :--------------------------------------------------------- | :----------------------------------------------------- |
| **TTR (Time to Ready)** | Interval from request to a usable environment.             | Measures the efficiency of the fulfillment pipeline.   |
| **Handoff Count**       | Number of times a developer must wait for another team.    | Measures the "self-service" nature of the capability.  |
| **Recovery Time**       | Time from a rejected change to a corrected commit.         | Measures the effectiveness of guardrails and runbooks. |
| **TTV (Time to Value)** | Time from first commit to the first successful model call. | Measures the total "onboarding" friction.              |

Define the start, finish, and evidence source for a measure before the experiment begins. Include blocked and assisted attempts, not only the happy path, for an honest view of the developer experience.

### Avoid the tooling trap

A new plugin, dashboard, or infrastructure product is not progress by itself. Progress is measured by the developer outcome, not the component count. A clearer rejection message, like the one you read in Module 5, can be worth more than a new UI. A simple, reliable fulfillment path beats a feature-rich one that often fails.

> [!hint] Before adding a tool to the roadmap, ask: "What specific developer friction does this remove, and how will I measure the improvement?" If there is no answer, the tool is a guess, not a priority.

## Product exercise: choose one next milestone

**10 minutes.**

In the VS Code Explorer, return to 📁 **Lab Root** > **answers** > **product-brief.md** and fill in the **Module 6** section.

### 1. Select one observed friction point

Use the PR numbers, timings, and results you recorded in the Module 2 to 5 sections. Choose one problem, not a backlog of every possible extension.

If your own run was blocked, describe the blocker honestly and state whether your proposal comes from direct experience, the demonstration, or supplied evidence.

### 2. Propose a bounded improvement or experiment

Describe what would change for the developer. Reuse the owner and non-goals from Module 1, and name the pilot team (in this lab, the `beans` team), rather than creating another planning document.

Keep the first milestone small enough to evaluate. For example, test whether clearer fulfillment status helps a pilot team resolve a waiting request without asking the platform team to inspect controller logs. This is an illustrative hypothesis, not a claim about your run.

Include who maintains the change and the support path after the pilot. A capability that depends on unplanned manual maintenance has not necessarily removed toil.

### 3. Define one outcome measure

Choose a measure connected to the selected friction:

- Task completion time, including work and waiting.
- Manual fulfillment or troubleshooting handoffs.
- Independent completion of the supported task.
- Time to identify and correct a rejected change.

Select one, not all four. State how you will collect a baseline and what population it applies to. Do not invent a target percentage or substitute this workshop's duration for production performance.

### 4. Define the feedback checkpoint

Record when or after what pilot activity you will review the result, what evidence you need, and what result would lead you to change or stop the investment.

Your short milestone statement should identify the observed friction, proposed change, pilot team, owner/non-goal, outcome measure and baseline method, and feedback checkpoint.

Production promotion, an AI gateway, and full tenant onboarding remain possible extensions. None is automatically the next milestone. This lab already creates a separate identity for each model-calling agent, federation, model access, and telemetry resource at vending time. It deliberately uses guest Backstage access, static catalog owners, a single development environment, and basic application telemetry with live monitoring ABAC deferred; do not describe those as a complete production identity or onboarding system.

## Share and ask questions

**5 minutes.**

Share selected milestone statements and the evidence that would change them. Explain whether the proposal removes developer work, reduces waiting, or clarifies an unavoidable responsibility.

**Takeaway:** before your next platform roadmap review, write each proposed item in the same shape as your milestone statement: observed friction, change, pilot team, one measure with a baseline method, and a feedback checkpoint. Items that can't fill in the first field are guesses, not priorities.

Save the worksheet with relevant PR/revision references and **independent**, **assisted**, **demonstration-only**, or **blocked** results. Record technical evidence that is still pending rather than silently counting it as complete. Preserve the distinction between a profile-file PR and a no-change repeat request, a builder's model evidence and proof of authorization isolation, and configured resources and measured usage.

The worksheet is your take-home artifact. To keep a copy of its non-sensitive contents, open 📁 **Lab Root** > **answers** > **product-brief.md** in the VS Code Explorer and press **Ctrl+S**. Then select all (**Ctrl+A**), copy (**Ctrl+C**), and paste the text into a note or message on your own computer; the lab's clipboard carries text out of the lab. Check that the paste worked before you end the lab. Do not export credentials, token caches, kubeconfigs, Terraform state, shell history, or raw telemetry.

## Checkpoint

You have one next milestone connected to observed or explicitly qualified evidence, with a way to evaluate the developer outcome.

Use the [summary](#summary-and-take-home-material) to review completion and end the session. That page does not add another timed exercise.

**What you learned:** platform engineering continues after the first working request, through ownership, feedback, and measured improvement.

===

<a id="summary-and-take-home-material"></a>

# Summary and take-home material

This is the completion reference for Module 6, not an additional timed module.

## The capability you worked on

- The workshop connects a developer promise to one practical implementation: request an approved environment, deploy an AI application with platform-provided connections, make a supported change, and recover through the same controlled delivery path.
- The platform includes more than the Backstage form. It includes the request contract, trusted resource mappings, identity and access, fulfillment, operating information, and an accountable owner.
- The provided infrastructure keeps foundation and controller installation outside learner time. Module 2 makes the wiring explicit: provider access, delivery permissions, trusted instance mapping, and root watches are platform-engineer responsibilities, not developer request fields. Your bounded edits then make parts of that capability usable without installing every component during class.

## The fundamentals, in practice

| Fundamental                         | From                                                   | To                                                                                        | First step on your platform                                                            |
| :---------------------------------- | :----------------------------------------------------- | :---------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------- |
| **Platform as a product**           | A list of tools you think the team needs               | A clear promise based on a developer task and an observable outcome                       | Write the promise for your most-requested manual task before choosing a tool           |
| **Self-service through a contract** | Manual tickets and "hope-based" fulfillment            | A versioned API where developers describe intent and the platform owns the implementation | Define the few fields a developer must supply; let the platform derive the rest        |
| **Golden paths**                    | Documented "how-to" guides that developers must follow | The supported way is also the easiest way: prepared templates and constrained choices     | Publish the binding your apps copy by hand today as a named, platform-owned contract   |
| **GitOps as the change path**       | Manual `kubectl apply` and untracked changes           | Every change is a reviewed pull request, and controllers reconcile the state              | Check revision and health after merge, not just "PR merged"                            |
| **Guardrails, not gates**           | Approval queues and "ticket-based" security            | Automated schema validation and admission policy that stop unsafe changes instantly       | Make sure each enforced policy names the field and points to a supported fix           |
| **Clear ownership**                 | Overlapping responsibilities and "shared" secrets      | A clean split between platform, application, and controller state                         | Give each resource exactly one owner and one way to change it                          |
| **Evidence and feedback**           | Gut-feeling and "it feels slower"                      | Telemetry and cost data that tell you whether the promise holds                           | Pick one developer outcome measure and collect its baseline before the next investment |

## How AKS carried the promise

Each part of the promise from Module 1 rested on an AKS capability the platform did not have to build or operate. The BACK stack turned those capabilities into a contract; AKS kept them running.

| Promise you kept                               | AKS capability                                                    | Where you saw it  |
| :--------------------------------------------- | :---------------------------------------------------------------- | :---------------- |
| Each team gets its own bounded environment     | Managed namespaces with namespace-scoped Azure RBAC               | Module 2          |
| The platform's delivery engine stays current   | Argo CD as an AKS cluster extension                               | Module 2          |
| The app reaches the model without a key        | Workload identity and OIDC issuer (default on AKS Automatic)      | Module 3          |
| Teams share one entry point without colliding  | App Routing Gateway API implementation (Istio)                    | Module 3          |
| A bigger profile runs without a node ticket    | Node autoprovisioning                                             | Module 4          |
| Unsafe changes stop at admission with a reason | Deployment Safeguards and Pod Security Standards via Azure Policy | Module 5          |
| The foundation stays patched                   | Automatic cluster and node OS upgrades                            | In the background |

For the reasoning behind the two-cluster, two-tier design and links to each capability, see [why AKS is the foundation](#interlude-choose-the-foundation-for-the-promise).

## Check your outcome

Use the worksheet to record what actually happened. Core completion means:

| Module | Completed when                                                                                                            |
| ------ | ------------------------------------------------------------------------------------------------------------------------- |
| 1      | The worksheet has a capability statement, owner, non-goals, acceptance criteria, and a baseline question                  |
| 2      | The `beans-dev` request is `Ready`, the managed namespace carries the cost-center label, and the baseline resources exist |
| 3      | Argo CD deployed your app-deploy commit, and telemetry shows a successful model call after a fresh chat                   |
| 4      | Backstage proposed only `profile.yaml`, you merged it, and `concierge` runs the `standard` requests                       |
| 5      | Admission rejected `latest`, the app stayed up, the Git fix converged, and you recorded one qualified cost decision       |
| 6      | The worksheet has one next milestone tied to observed or explicitly qualified evidence                                    |

Independent, assisted, demonstration-only, and blocked results should stay distinct. Pending telemetry or an unresolved recovery is not a pass. A repeated already-selected profile can be a verified no-change result, not a new PR or rollout. Live monitoring ABAC and authorization-isolation testing are deferred, not completion requirements.

## What this does not establish

- This is a development capability in an isolated lab, not a production-ready multi-tenant platform. It does not establish application production sizing, adversarial tenant isolation, production delivery improvements, or measured cost savings.
- The shared model, workspace, and controllers were prepared. Your request created a separate identity, federation, and model-access assignment per agent, and the Application Insights resource alongside its namespace. This does not implement the full joiner/mover/leaver lifecycle of a real application team.
- A production monitoring access boundary needs its own verified permission tests. A builder's successful query or a filtered dashboard cannot substitute for them. This lab has no restricted-viewer identity or foreign-data fixtures. The telemetry-publisher grants enable ingestion, and the requester's Monitoring Reader grant does not by itself prove isolation.
- The pinned Fourth Coffee artifact authenticates model calls and cloud OTLP ingestion through workload identity, with separate role assignments. Its release capability is not proof that your environment exported successfully: retain the fresh model-call evidence from Module 3. Endpoint URLs and routing attributes do not authorize reading telemetry. Backstage's guest session and static catalog owners likewise do not implement production user authorization.
- These boundaries do not make the capability less useful. They make its supported promise clear and identify what a production adoption would need to evaluate.

## End the session

Save the non-sensitive worksheet at `$LAB_ROOT/answers/product-brief.md` (press **Ctrl+S**).

If you want a copy, follow the take-home steps near the end of [Module 6](#module-6-plan-the-next-platform-milestone). Organizers manage local-service shutdown and Azure cleanup; use their session-end instructions.

Cleanup follows resource ownership: remove the application environment through its controller before destroying the shared foundation. Do not manually delete the namespace, Workspace, identity, role assignments, or OpenTofu state backend out of order. Removing controller state too early can leave resources or permissions behind.

## Optional follow-ups

These are optional, not unfinished core lab requirements:

- If at least 35 minutes remain on the lab timer after Module 6, vend a second environment, `beans-prod`, from one Backstage form in the [optional next-environment exercise](#optional-vend-the-next-environment-from-backstage). It is the clearest way to see the golden path repeat, and it needs your live lab, so it can't be done after the lab ends.
- Refine the recovery guide improvement you recorded. Evaluate whether it makes the source and correction clearer to a developer.
- Revisit the next milestone with a pilot team and collect the baseline you defined.
- If organizers supplied `evidence/production-events.csv`, practice distinguishing production delivery measures from environment-provisioning and workshop events. Respect its synthetic or sanitized provenance.
- Review the setup guide to understand what must be maintained outside the developer-facing path.
- Explore the pinned [Fourth Coffee source](https://github.com/pauldotyu/fourth-coffee/tree/969ca1acae851d0ef3cb60619d5e0d6e90523fda) to relate the supplied workload to its local and Kubernetes layouts. This is optional source study, not a required image build.

Do not use the protected breaks for these. The `beans-prod` exercise is the only item here that opens PRs, and only while time remains on the lab timer.

## Reference material

- [Troubleshooting and safe recovery](#appendix-a-troubleshooting-and-safe-recovery).
- [AKS managed namespaces](https://learn.microsoft.com/azure/aks/concepts-managed-namespaces).
- [Deployment Safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards).
- [Granular RBAC for Azure Monitor Logs](https://learn.microsoft.com/azure/azure-monitor/logs/granular-rbac-log-analytics).
- [AKS cost analysis](https://learn.microsoft.com/azure/aks/cost-analysis).
- [DORA delivery performance metrics](https://dora.dev/guides/dora-metrics/).
- [Build the platform, not the plumbing](https://blog.aks.azure.com/2026/11/09/build-the-platform-not-the-plumbing) on the AKS blog.

## Closing thought: from tooling to product

Moving from a tooling team to a platform product team is a shift in mindset. Tooling focuses on the _capability_ ("We have Argo CD"). Product thinking focuses on the _outcome_ ("Developers can ship a change without a ticket").

Backstage, Argo CD, Crossplane, and AKS are the vehicle. The real value is in the **contracts** you define and the **friction** you remove. This lab builds the API and the portal up front so you can see every layer. In your own platform, start small: add an API when pull requests become the bottleneck and a portal when discovery does. Base your roadmap on observed evidence, and always measure success by the developer's ability to complete their task.

===

<a id="optional-vend-the-next-environment-from-backstage"></a>

# Optional: vend the next environment from Backstage

**Duration:** about 25 minutes, most of it waiting for Azure. This exercise is optional. Do it after you finish Modules 1 to 6, only if at least 35 minutes remain on the lab timer, and never in place of a module or a break.

## Objectives

By the end of this exercise, you will be able to:

- Request a complete application environment from one Backstage form.
- Explain why the platform's real test is the second environment, not the first.
- Compare two environments and confirm they share the pattern but not the resources.

> [!knowledge] **Platform concept: a golden path is the path you can repeat.** In Modules 2 and 3 you built the first environment by hand: a contract change, a request file, a binding, and a configuration PR. A platform earns its keep when the next team, or the next environment for the same team, needs none of that knowledge. In the BACK stack, **Backstage** collects the intent, **Argo CD** applies the request and delivers the app, **Crossplane** composes the environment, and **Kubernetes** runs it. The form is new. Nothing behind it is.

**Starting state:** you finished Modules 1 to 6, so `fourth-coffee` runs healthy in `beans`. Backstage (`http://localhost:3000`), the Argo CD tunnel (`https://localhost:8443`), and the application tunnel are running. If any stopped, restart it as shown in [Start Backstage and Argo CD](#start-backstage-and-argo-cd) or, for the application tunnel, [Module 3, step 6](#6-open-the-application-through-the-gateway). `make app` runs the same commands as step 6.

**Before you start:**

- [] Backstage (Terminal 2), Argo CD (Terminal 3), and the app tunnel are still running.
- [] You're in the VS Code terminal, and `echo $APP_ENV` prints `beans-dev`.
- [] You will **not** `export APP_ENV` or `export TEAM` in this exercise. `make connect` saves exports and would break later commands.

You create a second environment, `beans-prod`, for a second copy of the same application, `fourth-coffee-prod`. In this lab it uses the same `ai-dev` namespace class and the same approved image. A real production class would usually add stricter policy, approvals, or a separate cluster, and a real golden path would often scaffold source code and CI as well. This exercise skips both to stay within the approved, prebuilt workload.

## Repeat the golden path

A platform proves its value when it can repeat a success. The first environment, built in Modules 2 and 3, took manual wiring and specific knowledge. A golden path replaces that with a supported route that is also the easiest one. Requesting a second environment tests whether the platform really hides the complexity of the first.

The **AI application environment** template in Backstage implements this path. It turns intent into implementation in five steps:

| Stage          | Backstage action              | Result                                                                    |
| :------------- | :---------------------------- | :------------------------------------------------------------------------ |
| **1. Intent**  | `fetch:template`              | Authors `requests/<namespace>.yaml` and the catalog entry.                |
| **2. Tuning**  | `fetch:template`              | Authors `apps/<application>/values.yaml` with the correct contract names. |
| **3. Sizing**  | `fetch:plain:file`            | Copies the approved `profile.yaml` for the chosen resource class.         |
| **4. Config**  | `publish:github:pull-request` | Opens a PR in **app-deploy** to provide the app's configuration.          |
| **5. Request** | `publish:github:pull-request` | Opens a PR in **platform** to trigger the environment provisioning.       |

Because the golden path is a series of Git operations, every environment has an audit trail, and the developer never needs to know where the files live or how they are named.

### Identity comes from the platform

The form never asks for a client ID or a model endpoint. The platform creates a managed identity for each model-calling agent and federates it to the namespace _before_ the application deploys, so each agent runs as its identity from the first pod. The developer manages no secrets and never touches the OIDC trust chain. The form only supplies intent, such as the namespace and team.

### Check that the pattern holds

In step 8 you compare `beans-dev` and `beans-prod`. Two environments on the same `standard` profile should match in resource requests, identity pattern, and telemetry routing, and differ only in names and cost attribution. If they behave differently, the platform is leaking implementation details and the golden path is not consistent.

## Guided practice: request, approve, and use the next environment

**New terminal? Load your environment first.** Every command depends on `lab.env`. If you opened a new terminal, or you see an empty value or an `unbound variable` error, run +++source ~/prel37/config/lab.env+++. Then +++echo "$LAB_ROOT $TEAM $APP_NAME $APP_ENV"+++ should print `/home/labuser/prel37 beans fourth-coffee beans-dev`.

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

Open +++http://localhost:3000/create/templates/default/app-environment+++. You can also find **AI application environment** on the **Create** page. If it is missing, open +++http://localhost:3000/catalog/default/template/app-environment+++ and select **Refresh** on the **About** card.

The form has three pages: **Environment**, **Access and resources**, and **Review**. Fill in the **Environment** page, then select **Next**:

| Field                 | Value                    | Why                                                                                  |
| --------------------- | ------------------------ | ------------------------------------------------------------------------------------ |
| Environment namespace | +++beans-prod+++         | Names the managed namespace, its Azure resources, and `beans-prod.localhost`         |
| Application name      | +++fourth-coffee-prod+++ | Names the Argo CD Application and the `apps/` folder. Must not reuse `fourth-coffee` |
| Owning team           | `beans`                  | The catalog owner. Pick it from the list.                                            |
| Cost center           | +++CC-1043+++            | A different cost center, so you can see attribution separate the two                 |

On the **Access and resources** page, fill in the following, then select **Review**:

| Field                | Value                | Why                                             |
| -------------------- | -------------------- | ----------------------------------------------- |
| Your Entra object ID | the GUID from step 2 | AKS desktop and telemetry access                |
| Resource profile     | `standard`           | The approved profile, chosen up front this time |

On the **Review** page, check the values, then select **Create**. If you mistype a value, see [If you need to start over](#if-you-need-to-start-over).

**Expected result:** within a minute all five steps complete and four buttons appear: the two PRs (numbered in merge order), **Follow application delivery in Argo CD**, and **Open the application**. Backstage opened both PRs. It merged neither.

### 4. Review and merge the configuration PR first

**Run in:** VS Code terminal · App-Deploy repo (the block below changes into it)

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
```

When `gh` finishes, check for the environment's Argo CD Application:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd get application fourth-coffee-prod
```

**Expected result:** the merge succeeds, and `kubectl` returns `NotFound`. Nothing deployed, because no environment exists yet.

### 5. Approve the environment request

**Run in:** VS Code terminal · Platform repo (the block below changes into it)

Now act as the platform reviewer. This PR is the approval gate: merging it starts real Azure provisioning.

```bash
cd "$LAB_ROOT/platform"
git checkout main && git pull origin main
gh pr diff backstage/beans-prod-environment --name-only
gh pr diff backstage/beans-prod-environment
```

**Expected result:** two new files, `catalog/fourth-coffee-prod.yaml` and `requests/beans-prod.yaml`. In the request, `team` is `beans-prod`, `costCenter` is `CC-1043`, and `requesterObjectId` is your GUID. If anything else changed, do not merge. Then merge it:

```bash
gh pr merge backstage/beans-prod-environment --merge --delete-branch
```

When `gh` finishes, ask Argo CD to check for the request now:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd annotate application platform-requests argocd.argoproj.io/refresh=normal --overwrite
```

### 6. Wait for fulfillment

This is the same chain you traced in Module 2. Expect about 2 to 7 minutes for the environment, then a few minutes for the first rollout. The first command waits for Argo CD to apply the request, so the later waits don't fail with `NotFound`.

> [!note] While you wait, open Argo CD and watch `platform-requests` pick up `beans-prod`, then `beans-prod-baseline` and `fourth-coffee-prod` appear next to the `beans-dev` tiles.

```bash
kubectl --context "$CONTROL_CONTEXT" wait --for=create appenvironment/beans-prod --timeout=300s
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Ready appenvironment beans-prod --timeout=15m
kubectl --context "$CONTROL_CONTEXT" -n argocd wait --for=create application/fourth-coffee-prod --timeout=300s
kubectl --context "$CONTROL_CONTEXT" -n argocd wait application/fourth-coffee-prod --for=jsonpath='{.status.health.status}'=Healthy --timeout=600s
for d in concierge ops-agent fourth-coffee-mcp; do
  kubectl --context "$AKS_CONTEXT" -n beans-prod rollout status deployment/"$d" --timeout=300s
done
```

**Expected result:** `condition met` four times, then `successfully rolled out` for all three Deployments. The platform creates the `fourth-coffee-prod` Application only after the environment's baseline is ready, so it is not there at first.

If a wait times out, check `beans-prod` itself. The commands in [environment request is merged but not ready](#environment-request-is-merged-but-not-ready) use `$APP_ENV` and `$TEAM`, which name `beans-dev`, so run these instead:

```bash
kubectl --context "$CONTROL_CONTEXT" get appenvironment beans-prod
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system get workspaces.opentofu.m.upbound.io beans-prod
kubectl --context "$AKS_CONTEXT" -n beans-prod get resourcequota,networkpolicy,serviceaccount,configmap
```

Do not `export APP_ENV=beans-prod` or `export TEAM=beans-prod` to reuse those commands: `make connect` saves exported overrides into `lab.env`, and every later command in this guide would then point at `beans-prod`. If `fourth-coffee-prod` reports `values.yaml: no such file or directory`, check that the configuration PR from step 4 merged.

You did not read a binding, fill a blank, or open a third PR.

### 7. Use the new environment

Open +++http://beans-prod.localhost:8080+++ in your browser. The same application tunnel serves both environments, because each HTTPRoute matches its own host. Start a chat to confirm the model call works with the new environment's identity.

In Backstage, open **Catalog**. Within a few minutes `fourth-coffee-prod` appears next to `fourth-coffee`, owned by `beans`, with links to the app, its Argo CD Application, and its configuration folder.

### 8. Compare the two environments

Same pattern, separate resources. Run each check and compare the two rows:

```bash
kubectl --context "$AKS_CONTEXT" get namespace beans beans-prod -L platform.prel37.example/cost-center
az resource list -g "$AKS_RESOURCE_GROUP" \
  --query "[?tags.team=='beans' || tags.team=='beans-prod'].{name:name, team:tags.team, costCenter:tags.\"cost-center\"}" -o table
kubectl --context "$CONTROL_CONTEXT" -n argocd get appprojects beans-dev beans-prod \
  -o custom-columns='NAME:.metadata.name,NAMESPACE:.spec.destinations[*].namespace'
```

**Expected result:** the last command shows the one namespace each AppProject can deploy to. Compare the rest of the checks in this table:

| Check                 | `beans-dev`                                                                | `beans-prod`                                                                         |
| --------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Namespace cost center | `CC-1042`                                                                  | `CC-1043`                                                                            |
| Agent identities      | `id-prel37-<lab-id>-beans-concierge`, `id-prel37-<lab-id>-beans-ops-agent` | `id-prel37-<lab-id>-beans-prod-concierge`, `id-prel37-<lab-id>-beans-prod-ops-agent` |
| Telemetry             | `appi-prel37-<lab-id>-beans`                                               | `appi-prel37-<lab-id>-beans-prod`                                                    |
| Delivery boundary     | AppProject `beans-dev`, limited to `beans`                                 | AppProject `beans-prod`, limited to `beans-prod`                                     |
| Address               | `http://beans.localhost:8080`                                              | `http://beans-prod.localhost:8080`                                                   |

Each environment has its own identity, telemetry, quota, cost attribution, and delivery boundary, all from one contract. A model call from `beans-prod` lands in its own Application Insights resource, not in the one you queried in Module 3.

<a id="if-you-need-to-start-over"></a>

### If you need to start over

If you mistype a value in the form, or the task stops partway, don't submit the form again yet: the task stops on the branches it already created. If you have **not** merged either PR, close both PRs and delete their branches, then submit the form again. Start with the app-deploy PR:

```bash
cd "$LAB_ROOT/app-deploy"
gh pr close backstage/fourth-coffee-prod-config --delete-branch
```

Then the platform PR:

```bash
cd "$LAB_ROOT/platform"
gh pr close backstage/beans-prod-environment --delete-branch
```

If `gh` says there is no pull request for a branch, the task stopped before it opened that PR. Delete the leftover branch with `git push origin --delete <branch>`, using the branch name from the command above. If you already merged either PR, ask a proctor before you continue.

## Debrief: what did the second environment cost?

Count what you did for `beans-dev` in Modules 2 and 3 against what you did here. The first time took a contract change, a request file, a binding lookup, a blank, and two PRs written by hand. This time took one form and two reviews. The difference is the developer toil the platform removed.

Then look at what stayed the same: the request is still a reviewed PR, the platform still approves by merging, and the controllers still enforce the contract. The form made the path faster without creating a second, less-governed one.

**Takeaway:** after your platform vends its first environment by hand, write down every value you had to look up or copy. Each one is either intent the form should ask for, or wiring the platform should supply. When the list is empty of wiring, you have a golden path, and the next team, and the one after it, follow the same route.

## Clean up

`beans-prod` runs three more Deployments and keeps its own Azure resources, so it adds cost while it exists. Organizers remove it together with the rest of the lab. Do not delete the namespace, identity, or Application Insights resource by hand. Deleting `requests/beans-prod.yaml` from Git does not remove the environment either, because the root Applications don't prune. If you stop before you merge both PRs, close them as shown in [If you need to start over](#if-you-need-to-start-over).

===

<a id="appendix-a-troubleshooting-and-safe-recovery"></a>

# Appendix A: troubleshooting and safe recovery

Use this appendix when a checkpoint doesn't match. Find what you see in the table, jump to that section, and work through it from the top.

Every section follows the same rule: find the last stage that worked, look at the next one, and fix it through the path that owns it (Git, the controller, or a proctor). Don't patch around a problem, and don't broaden access to get unstuck.

Ask a proctor for help with setup, credentials, or a checkpoint you can't resolve. Organizers manage the VM and accounts. You start and restart the local services yourself.

| What you see                                                                                    | Go to                                                                                                             |
| ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| You don't know which stage failed                                                               | [Start with context and the last successful stage](#start-with-context-and-the-last-successful-stage)             |
| You reconnected to a saved lab                                                                  | [Resume a saved lab](#resume-a-saved-lab)                                                                         |
| `LAB_ROOT` is empty, a file is missing, or Backstage, Argo CD, or the app URL won't open        | [Workspace, sign-in, or local service is unavailable](#workspace-sign-in-or-local-service-is-unavailable)         |
| A dirty working tree, a merge conflict, a failed check, or an expired token                     | [Git has unexpected changes or a check fails](#git-has-unexpected-changes-or-a-check-fails)                       |
| Module 2: the roots don't sync, or the `AppEnvironment` API doesn't exist                       | [Platform wiring or request API is not ready](#platform-wiring-or-request-api-is-not-ready)                       |
| Module 2: the request merged, but `beans` isn't ready                                           | [Environment request is merged but not ready](#environment-request-is-merged-but-not-ready)                       |
| Module 2: the Workspace reports an OpenTofu, provider, or module error                          | [Provider initialization fails](#provider-initialization-fails)                                                   |
| Module 3: Argo CD says `Synced`, but the app doesn't work                                       | [Application is synced but not usable](#application-is-synced-but-not-usable)                                     |
| Any module: `SyncError: Failed sync attempt` won't clear                                        | [An Argo CD sync error does not clear](#an-argo-cd-sync-error-does-not-clear)                                     |
| Module 3: no model span, or the agent gives a canned answer                                     | [Model evidence is missing or fallback-only](#model-evidence-is-missing-or-fallback-only)                         |
| Module 4: Backstage shows an old form, an empty picker, or a failed task                        | [Backstage shows an old template or no usable result](#backstage-shows-an-old-template-or-no-usable-result)       |
| Module 5: you get a different error than the admission rejection, or recovery stays `OutOfSync` | [The seeded failure does not match or recovery is stuck](#the-seeded-failure-does-not-match-or-recovery-is-stuck) |
| Module 5: telemetry is missing or a query is denied                                             | [Current application telemetry is missing or denied](#current-application-telemetry-is-missing-or-denied)         |
| Module 5: cost data is missing or thin                                                          | [Billing or usage evidence is incomplete](#billing-or-usage-evidence-is-incomplete)                               |

<a id="start-with-context-and-the-last-successful-stage"></a>

## Start with context and the last successful stage

**Why it matters:** a GitOps platform is a chain of handoffs (Git, Argo CD, Crossplane, OpenTofu, Azure, the workload cluster). A symptom usually shows up downstream of its cause, so context and the last good stage save more time than guessing.

**Write down what happened:** the module, what you expected, what you got, the PR and merged commit, the Argo CD source revision, and the time. Keep the smallest useful error message. Leave out credentials and full logs.

**Confirm you're in the right place.** In your VS Code terminal, inside the repository you meant to use, run:

```bash
pwd
git status --short
git branch --show-current
kubectl config view -o jsonpath='{.contexts[*].name}{"\n"}'
```

The last command lists context names from your kubeconfig without printing credentials. After [workspace initialization](#open-the-prepared-workspace), expect `prel37-control` and `prel37-workload` in `~/prel37/.state/kubeconfig`.

**Point each command at the right cluster:**

- `--context "$CONTROL_CONTEXT"`: Argo CD, Crossplane, and `AppEnvironment`. Argo CD Applications live here even when they deliver to the workload cluster.
- `--context "$AKS_CONTEXT"`: the `beans` namespace, the application, and its route.

If a setting looks wrong, compare it with your saved setup inputs or ask a proctor. Don't switch subscriptions or elevate permissions to test a guess.

**Walk the chain from the last stage that worked:**

1. Installation
2. Provider and delivery wiring
3. Instance mapping
4. Root sync and API establishment
5. PR review and any external branch checks
6. Merge
7. Argo CD delivers the new source revision
8. Provisioning or admission
9. Workload health
10. Route
11. Model evidence

If time runs out, join the debrief and come back to the issue during catch-up time.

<a id="resume-a-saved-lab"></a>

## Resume a saved lab

You don't repeat setup when you come back to a saved lab.

**Refresh access.** In Terminal 1 (setup), reconnect to the clusters and load your environment:

```bash
cd "$HOME/prel37/setup"
make connect
source "$HOME/prel37/config/lab.env"
```

If `make connect` reports an account mismatch, run `az login --use-device-code` with the assigned lab account and rerun it.

**Restart what stopped**, each in its own terminal, as in [Start Backstage and Argo CD](#start-backstage-and-argo-cd):

- Terminal 2 (Backstage): `make backstage`
- Terminal 3 (Argo CD): `make argocd`
- From Module 3 on, the app tunnel: rerun [Module 3, step 6](#6-open-the-application-through-the-gateway). `make app` runs the same commands.

**Reload your VS Code terminal** with `source ~/prel37/config/lab.env`.

<a id="workspace-sign-in-or-local-service-is-unavailable"></a>

## Workspace, sign-in, or local service is unavailable

**Symptoms:** `LAB_ROOT` is unset, prepared files are missing, a browser link fails, or Backstage or Argo CD won't open.

**Why it happens:** every new terminal starts without the lab environment variables. Backstage and the tunnels are foreground processes. They stop when their terminal closes, when the VM or WSL restarts, or when a tunnel drops (for example, `port-forward` reports `lost connection to pod`).

**New terminal:** initialize it with the [workspace commands](#open-the-prepared-workspace). On Windows, use Ubuntu WSL, not PowerShell.

**A service stopped:** in a WSL terminal, load your environment first:

```bash
cd "$HOME/prel37/setup"
source "$HOME/prel37/config/lab.env"
```

Then run only the command for the service that stopped. Each one stays in the foreground, so leave its terminal open.

Backstage, at `http://localhost:3000` (backend at `http://localhost:7007`):

```bash
make backstage
```

The Argo CD tunnel, at `https://localhost:8443`. It prints the `admin` password again:

```bash
make argocd
```

The application tunnel, at `http://beans.localhost:8080` (from Module 3 on):

```bash
make app
```

**`address already in use`:** a stale process still holds the port. Find its process ID, stop it with `kill <PID>`, and run the command again:

```bash
ss -ltnp | grep -E ':(3000|7007|8443|8080) '
```

**Expected behavior, not a fault:**

- The certificate warning at `https://localhost:8443`. Accept it, as in setup. For any other TLS error, ask a proctor.
- `http://beans.localhost:8080` not loading before Module 3.
- Signing in to GitHub in the browser doesn't sign you in to Backstage or Argo CD.

**Don't:** use personal credentials in place of the assigned accounts, rename the supplied runtime or services, or bind anything to an address other than loopback. Don't forward directly to an application pod or add custom DNS or public ingress. The app tunnel goes through the shared Gateway's ClusterIP service so the HTTPRoute is still tested.

Ask a proctor for missing configuration, or if a restart doesn't fix it.

<a id="git-has-unexpected-changes-or-a-check-fails"></a>

## Git has unexpected changes or a check fails

**Symptoms:** the working tree is dirty before an exercise, a merge conflicts, an external branch check fails, a PR won't merge, or a token stops working. The lab ships no custom validation workflow.

**Why it happens:** most Git surprises come from a branch created on a stale `main`, edits outside the exercise's allowed files, or a token that lacks a permission the controller needs.

**Fix it:**

- Read the diff and the check output before you edit more files. Confirm the PR has only the exercise's allowed changes. A failed check is feedback to understand, not something to disable.
- Pull current `main` before every new branch. This matters most in Module 5: an image-only PR from a stale branch drops Module 4's Backstage change and reverts the `standard` profile.
- Merge your own PRs after review, honoring any external branch checks. Nothing merges or approves automatically. If your learner account can't merge an allowed PR, report it to a proctor as a repository policy or credential gap.

**Don't:** use broad staging, force-push, hard reset, or an administrator merge bypass. Don't switch to an administrator account, create a GitHub App, or add Azure credentials to CI. Ask a proctor before replacing content or resolving a conflict you don't understand, and keep your edits.

<a id="replace-an-expired-or-missing-github-token"></a>

### Replace an expired or missing GitHub token

Argo CD, Backstage, and provider-opentofu each use their own repository-scoped token from setup. A successful `git push` from your terminal doesn't prove any of them can read a private repository, and your general GitHub login isn't a substitute.

Create a replacement the same way as in [Set up GitHub tokens](#set-up-github-tokens), with the same repositories and permissions. `make auth` reuses the saved token files, so running it alone doesn't replace a token. This example replaces the Backstage token. For the read token, use `read-token` in the file name instead:

```bash
source "$HOME/prel37/config/lab.env"
read -rsp "New Backstage token: " NEW_TOKEN; echo
```

Paste the new token and press **Enter**. Then save it and apply it:

```bash
printf '%s\n' "$NEW_TOKEN" > "$LAB_ROOT/.credentials/backstage-token"
unset NEW_TOKEN
cd "$HOME/prel37/setup" && make auth
```

After a Backstage token change, stop `make backstage` with **Ctrl+C** in its terminal and run it again so it reloads the token. Renewal doesn't recreate repositories or recopy files, and your exercise edits stay as they are.

<a id="platform-wiring-or-request-api-is-not-ready"></a>

## Platform wiring or request API is not ready

**Module:** [2, guided wiring](#guided-wiring-connect-the-installed-components).

**Symptoms:** `platform-system` or `platform-requests` doesn't sync, or the `AppEnvironment` API doesn't exist.

**Why it happens:** each wiring step depends on the one before it. Provider configuration needs healthy packages, the roots need delivery permissions and the EnvironmentConfig, and the `AppEnvironment` API exists only after Argo CD delivers the XRD and Crossplane establishes its CRD.

Before you apply the roots, having no workshop roots and no `AppEnvironment` API is the expected fresh state. Don't query an `AppEnvironment` until its CRD exists and is Established.

**Find the stage.** Use the last checkpoint that passed to choose what to inspect next:

| Last successful stage        | Inspect next                                                                                                          | Do not substitute                                                                         |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Foundation installed         | Provider/functions health and configuration CRDs from setup                                                           | Reinstalling controllers or applying provider configuration before its API exists         |
| Packages healthy             | Pinned `ClusterProviderConfig/prel37`, Secret reference, backend account/container/key, and provider runtime identity | Local GitHub login, a storage account key, or a manual OpenTofu run                       |
| Provider configured          | Delivery ClusterRole aggregation and the `platform-system` AppProject from `bootstrap/control.yaml`                   | Broadening Azure roles to repair Kubernetes RBAC or Argo project restrictions             |
| Delivery permissions applied | Local `EnvironmentConfig/prel37`, repository URLs, initial `moduleRevision`, and workload issuer                      | Regenerating mapping over existing instance data or putting identity IDs into the request |
| Roots applied                | `platform-system` source, sync error, XRD and generated CRD                                                           | Waiting for a request API before its definition is delivered                              |

**Check delivery and the CRD.** After the roots are applied, these commands inspect delivery and the generated definition without assuming the request API exists yet:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd \
  get applications.argoproj.io platform-system platform-requests
kubectl --context "$CONTROL_CONTEXT" -n argocd \
  describe application platform-system
kubectl --context "$CONTROL_CONTEXT" get crd \
  appenvironments.platform.prel37.example --ignore-not-found -o name
```

**Expected result:** both roots (`platform-system` and `platform-requests`) are Synced and the request CRD is Established, using the waits in Module 2.

- An empty last result means the CRD hasn't been created yet, not that there are zero requests.
- An authorization or connection error is not the same as "not found".
- If Argo CD hasn't delivered the XRD, read its repository, project, or sync error first.
- If the XRD is delivered but the CRD isn't Established, ask a proctor to check Crossplane's definition status.

**Fix it:** once the cause is resolved, repeat only the failed wiring step on the same instance. The pinned apply commands don't overwrite your exercise edits, and existing roots may resume published work right away. For expired credentials, [replace the token](#replace-an-expired-or-missing-github-token) rather than copying a learner token into a controller.

Successful wiring doesn't test module retrieval or state access. Those happen when the Workspace runs.

**Don't:** delete a namespace or reset state to get back to a fresh checkpoint. If you stop before or during wiring, tell a proctor; organizers handle cleanup. Don't install the missing API just to tear down an unused environment.

<a id="environment-request-is-merged-but-not-ready"></a>

## Environment request is merged but not ready

**Module:** [2](#module-2-implement-the-environment-contract).

**Symptoms:** the request PR merged, but the `AppEnvironment`, the `beans` namespace, or its baseline isn't ready.

**Why it happens:** a merged request starts a pipeline, not a finished environment. Argo CD delivers the request, Crossplane composes a Workspace, provider-opentofu runs the module against Azure, and only then can Argo CD deliver the baseline. Any stage can stall while earlier stages look green.

**Check the wiring first.** Confirm the Module 2 wiring checkpoint passed and `platform-system` delivered the schema-edit revision before you submitted the request. If the API is missing, go to [Platform wiring or request API is not ready](#platform-wiring-or-request-api-is-not-ready).

**Find the stalled stage.** Check each stage on its own: the delivery objects and request on the control cluster, the managed namespace in Azure, and the baseline on the workload cluster:

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

Then decide which case you have, because each has a different fix: a rejected request, Azure provisioning still pending, a failed provider run (see [Provider initialization fails](#provider-initialization-fails)), or a missing baseline.

**Known cases:**

- **The baseline reports a missing `monitor.azure.com/Instrumentation` API:** the delivered baseline chart expects in-cluster collection, which the direct-export baseline doesn't use, so your lab image is out of date. Stop and ask a proctor. Don't install AKS application monitoring or a stand-alone CRD.
- **The Workspace has no `otlp` output:** the Composition waits rather than publishing an incomplete binding. Read the Workspace error.
- **The namespace exists, but the baseline doesn't:** a provisioning error can block the baseline. Read the Workspace error. Don't insert an identity, endpoint, or token by hand.
- **A `telemetry_access` assignment is denied:** a proctor checks the bootstrap's constrained telemetry-publisher delegation on the generated DCR's subscription. Learners don't add IAM permissions.
- **`beans` already exists on a fresh first pass:** stop and ask a proctor. Don't adopt it or delete it. If you're resuming a request that already finished on this instance, the namespace is expected. Inspect the existing request, Workspace, and state instead of vending a second environment.

> [+Hint] For proctors: what the controller owns
>
> The controller owns the managed namespace, per-agent identities and federation, model and DCR-publisher assignments, and the Application Insights resource. Argo CD delivers the baseline from their outputs.
>
> Provider pods on the control cluster use their own authenticated remote module source, pinned to `EnvironmentConfig/prel37`'s `data.moduleRevision`, and their own state backend. Setup initially pins the first platform commit. The module is `opentofu/managed-namespace/main.tf`, with provider selections in the adjacent `.terraform.lock.hcl`, separate from `infra/main.tf` and its state. Local files and GitHub login are not a substitute. Don't create companion variable or output files, or run a local plan or apply, to repair a controller problem.
>
> Authorization-isolation testing is outside this lab.

<a id="provider-initialization-fails"></a>

### Provider initialization fails

**Symptoms:** the composite reports `Synced=True`, but the environment never becomes ready, and the Workspace conditions show a provider, module, or authorization error.

**Why it happens:** `Synced=True` on the composite only means Crossplane rendered its resources. The OpenTofu run inside the Workspace can still fail on provider selection, module retrieval, or Azure authorization, and that error lives in the Workspace conditions.

**Read the Workspace**, its module URL, and the pinned revision:

```bash
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system \
  describe workspaces.opentofu.m.upbound.io "$APP_ENV"
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system \
  get workspaces.opentofu.m.upbound.io "$APP_ENV" \
  -o jsonpath='{.spec.forProvider.module}{"\n"}'
kubectl --context "$CONTROL_CONTEXT" get environmentconfigs.apiextensions.crossplane.io prel37 \
  -o jsonpath='{.data.moduleRevision}{"\n"}'
```

Print each condition's message. This is read-only:

```bash
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system \
  get workspaces.opentofu.m.upbound.io "$APP_ENV" \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}: {.message}{"\n"}{end}'
```

If a message is a long, unreadable string, the provider compressed the OpenTofu error. Decode it:

```bash
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system \
  get workspaces.opentofu.m.upbound.io "$APP_ENV" \
  -o jsonpath='{.status.conditions[?(@.type=="Synced")].message}' | base64 -d | gunzip
```

Treat the output as data. Don't run commands copied from error text, and don't share credentials from logs.

**Then ask a proctor.** The fixes change the shared platform repository and the `EnvironmentConfig` every environment uses, and one of them needs `tofu`, which isn't installed in your lab. Note which message you see:

- `locked provider ... 5.9.0 does not match configured version constraint ~> 4.0`: the module and lock file disagree.
- `Required plugins are not installed ... no package ... cached in .terraform/providers`: the selected plugin is missing from the initialized workspace.

> [+Hint] For proctors: fix provider initialization
>
> **Version mismatch.** This lab pins AzureRM `= 5.9.0` and AzAPI `= 2.13.0`. Restore matching constraints and lock selections. A controller restart can't fix a mismatch committed in Git.
>
> **Missing plugin.** This is not proof of a provider-version incompatibility. Compare the full registry source address in the error, the module, and the lock file. The module explicitly uses `registry.opentofu.org/hashicorp/azurerm` and `registry.terraform.io/Azure/azapi`; the lock file normalizes the AzAPI namespace to lowercase. OpenTofu's lock-file migration can add an OpenTofu registry entry for a HashiCorp provider installed from the Terraform registry, so workspace selection looks for a provider address that was never installed. Use the OpenTofu registry for AzureRM in this module and regenerate the lock file from that registry. Don't copy checksums between registries. The bootstrap Terraform root is separate and unchanged. If the addresses already match, investigate download, init, and cache-path errors before considering a controlled restart.
>
> **Publish the fix.** Commit matching `main.tf` and `.terraform.lock.hcl` changes together in the private platform repository. If you're deliberately changing a provider version, regenerate its lock file in a clean maintenance copy with `tofu init -backend=false -upgrade` and review the selections. This is dependency maintenance, not permission to run a local plan or apply against controller-owned state. Don't downgrade only because a plugin is missing.
>
> **Advance the pin.** After merge, set `data.moduleRevision` in the lab's saved `$LAB_ROOT/config/environment.yaml` to the full merged commit SHA and apply that file to the control cluster. The pinned module and the baseline chart both use this setting, so review both at that revision. Confirm the Workspace's module URL contains the merged SHA. A local edit or a push to `main` doesn't move the pin, and `remotePullPolicy: IfNotPresent` reuses the module until its URL changes. Keep the Workspace and its state.
>
> **Package version.** provider-opentofu is pinned separately to `v1.1.10` in `bootstrap/packages.yaml`. Updating that package doesn't change the module's provider constraints, lock file, or revision. Use the setup installation step for a reviewed package update, then read the Workspace conditions again. An upgrade alone doesn't prove the original failure is resolved.

<a id="application-is-synced-but-not-usable"></a>

## Application is synced but not usable

**Module:** [3](#module-3-connect-and-deploy-the-application).

**Symptoms:** Argo CD shows `Synced`, but pods aren't ready, the route fails, or the app returns errors.

**Why it happens:** Argo CD reports `Synced` when the cluster matches Git, not when the app works. Admission denials, quota, scheduling, a misplaced values file, or a broken route can all leave a synced Application unusable.

**Check the right revision.** Multi-source Applications have more than one revision. Along with sync and health, confirm the **app-repository** revision is your merged configuration commit, not a chart commit.

**Inspect the resources:**

```bash
kubectl --context "$AKS_CONTEXT" \
  get deployments,pods,services,httproutes -n "$TEAM"
kubectl --context "$AKS_CONTEXT" describe deployment concierge -n "$TEAM"
kubectl --context "$AKS_CONTEXT" \
  get events -n "$TEAM" --sort-by=.metadata.creationTimestamp
```

Look for unavailable replicas, admission denials, scheduling or quota problems, and route conditions. If `ops-agent` or `fourth-coffee-mcp` is the failing component, inspect that Deployment rather than `concierge`.

**Check your configuration files:**

- Both staged files were copied: `values.yaml` and `profile.yaml`.
- If Argo CD reports `values.yaml` not found, compare the path with `status.binding.configPath` on the AppEnvironment.
- In base values, `extraEnvFrom[0].configMapRef.name` matches `status.binding.configMapName` (`platform-context`).
- The image, component flags, and value-file order (base `values.yaml`, then app-local `profile.yaml`) are unchanged.

**The route fails:** keep its condition and ask a proctor to inspect the shared Gateway, HTTPRoute, ClusterIP service, loopback tunnel, and the baseline's ingress network exception.

**Don't:**

- Add a ServiceAccount name. The platform's Argo CD Application assigns `concierge` and `ops-agent`, and the chart schema rejects any other mapping.
- Add a `$profiles` value-file reference, or enable Namespace or quota creation.
- Expose another LoadBalancer or forward to an application pod to bypass the route.
- Raise quota or remove limits. Unexpected injected resources or extra pods can break the prepared capacity assumptions, so report them instead.

<a id="an-argo-cd-sync-error-does-not-clear"></a>

## An Argo CD sync error does not clear

**Module:** any module that waits on Argo CD.

**Symptoms:** an Application shows `SyncError: Failed sync attempt to <commit>` and it doesn't go away.

**Why it happens:** automatic sync retries a failed sync a few times (five for your application, ten for the environment baseline) and then stops. It doesn't try the same commit again, so a transient failure, such as an Azure permission that hadn't propagated yet, stays until something changes.

**Read the error** in the Argo CD UI at `https://localhost:8443`, or with the command below. For the baseline, use `"$APP_ENV-baseline"` instead of `"$APP_NAME"`:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd get application "$APP_NAME" \
  -o jsonpath='{.status.conditions[*].message}{"\n"}'
```

- **The operation phase is `Running` and the message says `Retrying attempt #N`:** Argo CD is still retrying. Wait, as described in [the seeded failure](#the-seeded-failure-does-not-match-or-recovery-is-stuck).
- **Retries have stopped:** fix the cause, then open the Application in Argo CD and select **Sync**, then **Synchronize**. A new merged commit also starts a fresh attempt.

**Don't:** delete the Application or patch resources to hurry it.

<a id="model-evidence-is-missing-or-fallback-only"></a>

## Model evidence is missing or fallback-only

**Module:** [3](#module-3-connect-and-deploy-the-application).

**Symptoms:** the step 7 query returns nothing, or the agent replies but you can't find a model call for that reply.

**Why it happens:** telemetry arrives after a 2-5 minute ingestion delay, and the agent falls back to a canned answer when the model call fails. A plausible reply is not proof that the model was called.

**Rerun the query** from [Module 3, step 7](#7-verify-a-fresh-model-interaction). It reads the last 30 minutes of `OTelSpans` for the `beans` Application Insights resource.

- **It fails with an extension prompt:** run `az extension add --name log-analytics` and retry.
- **It returns nothing:** wait 2-5 minutes, send a new free-text chat message, and query again.
- **Ingestion is still delayed:** record the evidence as pending and come back during catch-up. Don't substitute an old trace.

**What counts as evidence:** a successful model dependency from your fresh interaction. A page load, health probe, attempted call, plausible reply, or historical trace doesn't count.

**The model returns an authorization error:** ask a proctor. Don't add a model API key or grant a broader role.

> [+Hint] For proctors: model authorization and export checks
>
> Inspect the binding, the **workload-cluster** issuer for `beans/concierge` or `beans/ops-agent` (whichever agent failed), and the existing model authorization.
>
> Verify the pinned image in `config/artifact-lock.json` and the prepared ConfigMap. The pinned Fourth Coffee image supports authenticated export; other images may only select an exporter. Confirm the actual running digest and `OTEL_EXPORTER_OTLP_AUTH_MODE=workload_identity` before investigating token or DCR errors. Don't substitute a classic exporter, local-auth key, or static bearer token.

<a id="backstage-shows-an-old-template-or-no-usable-result"></a>

## Backstage shows an old template or no usable result

**Module:** [4](#module-4-complete-the-self-service-interface).

**Symptoms:** the form is out of date, the **Application** picker is empty, the catalog is missing entries, a task fails, or a task completes but nothing rolls out.

**Why it happens:** Backstage reads templates and catalog files from platform `main` on GitHub, not from your clone, refreshes them on a schedule, and acts with its own token. A missing token permission or an unmerged PR looks like stale or empty UI.

**Empty picker, or no `beans` group or `fourth-coffee` component in the catalog.** Try these in order:

1. Backstage may have started before `make auth` finished. Stop it with **Ctrl+C** and run `make backstage` again.
2. The catalog may not have refreshed yet. Wait a few minutes and reload.
3. The Backstage token may be missing **Commit statuses: Read-only**, which the catalog needs to read `catalog/*.yaml`. Add it to the Backstage token in GitHub (the token value doesn't change), then stop and rerun `make backstage`. See [Set up GitHub tokens](#set-up-github-tokens).

**Old form.** Backstage reads the template from platform `main` on GitHub, so first confirm your change is there:

```bash
cd "$LAB_ROOT/platform"
git fetch origin
git show origin/main:backstage/templates/ai-app/template.yaml | grep -E 'description: Choose|enum:'
```

- **The output shows `enum: [small]`:** the template PR hasn't merged. Finish [Module 4, step 2](#2-add-the-standard-profile-to-the-selector).
- **The output shows `enum: [small, standard]`:** open `http://localhost:3000/catalog/default/template/app-profile`, select **Refresh** on the **About** card, wait about 10 seconds, and reload the form.

To see what Backstage actually published, open the template entity, select the three-dot menu, choose **Inspect entity**, and open **Raw YAML**. Compare `spec.parameters` with the merged file on platform `main`. Don't create a duplicate template or assume a local edit is published.

**`Resource not accessible by personal access token`.** The Backstage token can push branches but can't open PRs. Add **Pull requests: Read and write** alongside **Contents: Read and write**, as in [Set up GitHub tokens](#set-up-github-tokens), then restart Backstage.

Before you run the template again, delete the orphaned branch. Deleting a branch also closes any PR open on it, so first check that none is open:

```bash
cd "$LAB_ROOT/app-deploy"
: "${APP_NAME:?Run source ~/prel37/config/lab.env first}" &&
  gh pr list --head "backstage/$APP_NAME-profile-standard"
```

If this lists nothing, delete the branch:

```bash
: "${APP_NAME:?Run source ~/prel37/config/lab.env first}" &&
  gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/backstage/$APP_NAME-profile-standard"
```

**A task fails with `null response from GitHub`.** You may be requesting the profile that's already on `main`. Compare `profile.yaml` on app-repository `main` with the profile you asked for. Identical content has nothing to change, so record the no-change result rather than expecting a rollout.

**Any other failed task.** Keep the task reference and check whether a PR was created before you submit again.

**Review the generated PR.** It must change only `apps/fourth-coffee/profile.yaml`, to the exact content of the approved `platform/profiles/workload-small.yaml` or `workload-standard.yaml`. The template's `fetch:plain:file` and `publish:github:pull-request` steps leave `values.yaml`, including identity and image, unchanged. The Application's destination and access are platform-owned and aren't in the app repository.

Merge it yourself after review, honoring any external branch checks. No automatic merger is part of the lab, so a task waiting on a merge isn't a bug.

**A task completed, but nothing rolled out.** Task completion records the submission, not application readiness. Follow the generated PR's merged revision in Argo CD.

**Don't:** write a custom action to work around a preparation mismatch, or weaken validation to get a stale or unauthorized update through. A proctor can help compare the current source with the intended change while keeping unrelated work.

<a id="the-seeded-failure-does-not-match-or-recovery-is-stuck"></a>

## The seeded failure does not match or recovery is stuck

**Module:** [5](#module-5-recover-inspect-telemetry-and-evaluate-cost).

**Symptoms:** the bad tag produces a different error than an admission rejection, or recovery stays `OutOfSync` after the fix merges.

**Why it happens:** the safeguard under test is AKS Deployment Safeguards admission rejecting a mutable `:latest` image. If something else fails first (a branch check, the chart, an image pull), you see a different error. During recovery, Argo CD finishes retrying the rejected revision before it applies the fix.

**What should happen.** The fixture changes only `image.tag` to `latest`. Normal deployments render the locked digest; this teaching fixture renders `:latest` instead, and admission policy rejects it. Existing running pods may stay on the locked digest while the update is denied.

**You got a different result:**

- **An external branch check rejected the change first:** record that enforcement point and ask a proctor to inspect the repository policy. The chart schema accepts the locked tag or `latest`; there's no custom CI exception.
- **The rendered image is still digest-pinned:** ask a proctor to inspect the chart and configuration. Don't remove digest pinning yourself.
- **An image-pull error:** that isn't the safeguard under test. Ask a proctor.
- **Argo CD shows `Synced` and `Progressing`, not a sync failure:** admission denied the Pods, not the Deployments. Find the same rule in the ReplicaSet events and record it as your rejection reason:

```bash
kubectl --context "$AKS_CONTEXT" -n "$TEAM" get events --field-selector reason=FailedCreate
```

**Don't:** disable checks or policy to force the demonstration. Missing resource requests aren't a substitute fixture, because AKS Automatic may inject defaults.

**Restoring the tag.** Use native `jq`, as in [Module 5](#4-restore-the-approved-tag-through-git), to read `.application.imageTag` from `config/artifact-lock.json`. If the lookup fails, or the value is empty or `latest`, stop; don't guess a tag. Check that the recovery PR keeps `profile.yaml` at `standard` and changes only the expected base value.

After merge, check the app-repository revision, a successful sync, workload health, and the route. Healthy pods may stay up through the rejection and the recovery, so a restart isn't required evidence.

**Recovery stays `OutOfSync` for several minutes after the fix merged:** Argo CD is still retrying the rejected commit. Each Application retries a failed sync five times with a backoff that starts at 10 seconds and doubles up to 2 minutes. Check the attempt count:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd get application "$APP_NAME" \
  -o jsonpath='{.status.operationState.phase}{"\n"}{.status.operationState.message}{"\n"}' | grep -oE '^Running|^Succeeded|^Failed|Retrying attempt #[0-9]+'
```

If the phase is `Running` and the message says `Retrying attempt #N`, wait. After the fifth attempt Argo CD moves on to your fix, usually within about five minutes of it merging. Don't delete the Application or patch the Deployments to hurry it.

<a id="current-application-telemetry-is-missing-or-denied"></a>

## Current application telemetry is missing or denied

**Module:** [5](#module-5-recover-inspect-telemetry-and-evaluate-cost), with proctor follow-up.

**Symptoms:** no spans arrive for your current interaction, or a telemetry query is denied.

**Why it happens:** each agent exports OTLP directly to Azure Monitor with its own workload identity. Missing spans usually trace to the image, the token, the DCR grant, or the endpoint URL, and the HTTP status code tells you which.

**Check the basics.** Confirm the account, time window, and the current interaction's trace ID, using the [application telemetry link](#application-telemetry) and the query in [Module 3, step 7](#7-verify-a-fresh-model-interaction). Read `beans` container output with the `kubectl logs` command in [Module 5](#demonstrate-inspect-current-application-telemetry). Container Insights collection is a separate path, so a container log record doesn't prove native OTLP spans arrived.

**Check the export path** in your VS Code terminal:

```bash
kubectl --context "$AKS_CONTEXT" -n "$TEAM" logs deploy/concierge --since=10m
kubectl --context "$AKS_CONTEXT" -n "$TEAM" logs deploy/ops-agent --since=10m
kubectl --context "$AKS_CONTEXT" -n "$TEAM" get configmap platform-context -o json |
  jq '.data | {OTEL_EXPORTER_OTLP_TRACES_ENDPOINT,
               OTEL_EXPORTER_OTLP_LOGS_ENDPOINT,
               OTEL_EXPORTER_OTLP_METRICS_ENDPOINT,
               OTEL_RESOURCE_ATTRIBUTES}'
```

Then match what you see to the cause:

- **HTTP 401 or token acquisition failures:** verify the approved image, workload-identity environment and token-file mount, the workload-cluster issuer, and the `https://monitor.azure.com/.default` audience. A connection string does not authenticate native OTLP.
- **HTTP 403:** the setup operator checks the exporting agent's `Monitoring Metrics Publisher` assignment on the DCR named by that endpoint, including propagation of a newly created assignment. `Monitoring Reader` on Application Insights is not an ingestion grant.
- **HTTP 404 or an invalid-stream error:** compare each complete URL with **OTLP Connection Info**. The metrics stream is discovered from the DCR and is case-sensitive. Don't use the classic connection string's ingestion URL as an OTLP URL.
- **Node-IP, localhost, or port 28331/28333 endpoints:** the pod has stale in-cluster collector configuration, so your lab image is out of date. Stop and ask a proctor; there is no node collector to wait for on this path.
- **Export works at first, then fails:** verify application token renewal. A static bearer header is not a durable fix.
- **Export succeeds but the resource-filtered query is empty:** verify the generated DCR's workspace destination and the `microsoft.applicationId` resource attribute. For this contract it contains the connection string's `InstrumentationKey` GUID, not the ARM resource ID used by the query's `_ResourceId` filter.

`fourth-coffee-mcp` has SDK telemetry disabled because it has no Azure identity. Its stdout is still available. Don't grant it model access to enable telemetry.

**Still missing or denied:** record the evidence as pending or blocked, keep the error, and ask a proctor to check ingestion and the prepared access. Don't substitute historical records or broaden permissions.

Telemetry access control and authorization-isolation testing are outside this lab's scope. There are no viewer grants or foreign-data fixtures to repair, and neither an empty result nor a successful builder query proves isolation.

<a id="billing-or-usage-evidence-is-incomplete"></a>

## Billing or usage evidence is incomplete

**Module:** [5](#module-5-recover-inspect-telemetry-and-evaluate-cost).

**Symptoms:** there's no cost data for `beans`, or the numbers don't support a profile recommendation.

**Why it happens:** Azure cost data lags, and a namespace created today has no billing history yet.

**Fix it:** use the prepared historical or explicitly illustrative evidence and its assumptions. Don't label a sample's costs as your deployment's costs. If the evidence doesn't justify a profile recommendation, record that uncertainty and the measurement you'd need.

**Don't:** install a billing tool, invent a rate, or compute guaranteed savings from a requests-only comparison to fill the gap.

<a id="recover-without-hiding-the-result"></a>

## Recover without hiding the result

When a proctor steps in, the fix still goes through the owning path:

- Proctors compare your work with staged exercise scaffolds and approved source files. They don't use them to reset your work.
- The correction is the smallest change, submitted through Git, on the same request, namespace, controller, and state. Proctors ask before replacing your content.
- A preparation failure stays blocked until it's repaired. Watching a demonstration helps you learn, but it doesn't count as completing the step yourself.

Record the intervention in `answers/product-brief.md`. Don't export private state or credentials with the worksheet.

===

<a id="appendix-b-lab-reference"></a>

# Appendix B: lab reference

Background reference. You don't need to read it to finish the modules; they link here where it helps.

<a id="git-workflow-used-throughout"></a>

## Git workflow used throughout

Every platform and application change goes through a PR to `main`. The PR is where a person reviews intent before a controller makes it real. Each module gives you the exact commands; this is the shape they all follow:

```bash-nocopy
# 1. Start from current main in the right repository
cd "$LAB_ROOT/platform"            # or "$LAB_ROOT/app-deploy"
git checkout main && git pull origin main
git status --short                 # expect no output

# 2. Branch, change, and review your own diff
git checkout -b <branch-name>
# ... the module's change command ...
git --no-pager diff                # confirm only the intended lines changed

# 3. Commit only the named file and publish the branch
git add <file>
git commit -m "<message>"
git push -u origin <branch-name>

# 4. Open, review, and merge the PR (run each gh command on its own, and wait for it to finish)
gh pr create --fill
gh pr diff
gh pr merge --merge --delete-branch
```

`gh pr merge --delete-branch` also switches your clone back to `main` and pulls the merge, so you are ready for the next change.

You merge your own PRs in this lab because you are both the platform engineer and the reviewer. In production, a second person or required check would review platform changes.

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

<a id="how-application-telemetry-flows"></a>

## How application telemetry flows

The model-calling agents export OpenTelemetry from their own code, authenticating with their vended identity, straight to Azure Monitor's cloud OTLP endpoints. Because the app does the exporting, nothing extra runs in the cluster: no AKS application monitoring add-on, no `Instrumentation` resource, and no collector pod. Each agent's Application Insights data collection rule (DCR) then routes its spans to the lab's Log Analytics workspace, tagged with the team's resource. This path requires the pinned Fourth Coffee release recorded in `config/artifact-lock.json`.

Cluster-level Container Insights is separate from this application export path; its presence is not proof that native application spans arrived.

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

The source for these files is bundled in the VS Code Explorer under 📁 **Lab Root** > **setup** > **src**. The prepared copies are personalized for your lab, so do not copy them from another attendee.

## Notes for facilitators

Announce each practice stop time and hold the debrief even if a reconciliation is still pending. Return to status during catch-up. Do not recover time by cutting explanations or breaks.
