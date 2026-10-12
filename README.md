## Before you're done

This repo has been created for your Microsoft Ignite 2026 session. Here's how to get it ready.
**Easiest path: use the agent (recommended):**

- Open GitHub Copilot Chat and say `help me initialize repo`. The agent will walk you through getting the README populated.
- When you're ready to publish, say `help me finalize repo`. The agent will clean up unused folders, validate everything, and remove this "Before you're done" section and other extra stuff that attendees don't need to see.
- Curious how it works? Read the [agent workflow](.github/AGENT-WORKFLOW.md).

**Doing it manually?**
Fill in the sections below yourself, then:

- Delete any placeholder folders you don't need (`data/`, `infra/`, etc.)
- Delete this "Before you're done" section
- Delete `.github/agents/`, `.github/tests/`, `.github/copilot-instructions.md`, and `.github/AGENT-WORKFLOW.md`. These are template tooling, not part of your published repo.

**Folder conventions:**

- Attendee step-by-step guidance goes in `instructions/`. If you use MkDocs or a docs site instead, put it in `docs/` and link to it from this README.
- Reference material and background reading go in `docs/`.
- You can add a `.devcontainer/` folder if needed.

---

<a name="start-building"></a>

<p align="center"> <img src="img/banner-ignite-26.png" alt="Microsoft Ignite 2026" width="100%"/> </p> 
# [Microsoft Ignite 2026](https://ignite.microsoft.com)

## 🔥 PREL37: Platform engineering on AKS: a paved road to AI apps

### Session description

Platform engineering on AKS is about more than any single tool. This session covers the practices that make application teams productive on Kubernetes and building internal developer platforms (IDPs). Learn how to create golden paths and templates, policy guardrails, workload identity, GitOps self-service, and the observability and cost controls platform teams rely on. See how these come together into a paved road for AI-ready workloads built on Kubernetes.

#### Workshop focus

Build a thin self-service platform capability on Azure Kubernetes Service (AKS) around a recurring developer task. Connect the installed platform's provisioning and delivery paths, complete a supported environment request, deploy the supplied Fourth Coffee AI application through GitOps, and expose approved changes through Backstage using platform-provided identity and configuration. Recover from a policy rejection and use telemetry, cost evidence, and observed friction to decide what the platform should improve next.
Each step maps to a practice platform teams use every day: a written developer promise, a versioned environment API, GitOps delivery, a self-service portal, policy guardrails, and evidence-based iteration. You build a small version of each, so the pattern is concrete before you scale it.

**Current status:** The attendee guide matches the implementation assets and preparation contract. Live end-to-end rehearsal is pending, including real startup, reconciliation, application telemetry, and four-hour timing. Telemetry authorization isolation is outside this lab's scope. Source files and setup scripts do not mean a VM image, personalized repositories, or live Azure resources have already been created or validated.

### How the materials fit together

There is one learner path. `docs/` and `instructions/` lead to the same guide.

- **Attendees:** Start with the [workshop guide](docs/README.md), then follow its six modules, summary, and troubleshooting reference. These pages are the source of truth for learner steps. The [instructions entry point](instructions/README.md) links to this same guide.
- **Environment organizers:** Use the [setup guide](setup/README.md) for cloud resources, identity, access, workspace preparation, controller/provider/function installation, shared gateway, native UI startup, and teardown. For Skillable, provision Terraform from `C:\terraform` before class, then use the [WSL learner setup](setup/README.md#skillable-lab-setup) to prepare the workspace with `make machine-setup`. Source assets live in `src/`. Stop at the installation checkpoint: render `environment.yaml`, but leave provider configuration, delivery permissions, applying EnvironmentConfig, and root watches to Module 2.
- **Speakers:** The [deck specification](instructor/PREL37-speaker-deck.md) describes slide content and delivery cues; the [design system](instructor/PREL37-design-system.md) describes visual rules. The presentation file is built on the official Ignite template from the deck specification and is maintained outside this repository.

### 🚀 Getting started

#### In a guided session

If you're following along during a live session:

1. Use the assigned Skillable Windows/WSL environment and lab accounts once organizers have prepared them. Do not use a personal subscription or credentials.
2. Open WSL and complete the [Skillable lab setup](setup/README.md#skillable-lab-setup) with `make machine-setup`, GitHub tokens, and the local services. Then open Backstage at `http://localhost:3000`, Argo CD at `https://localhost:8443`, and the two private repositories. Start the application tunnel in Module 3, after deployment.
3. Follow the [workshop guide](docs/README.md) with the instructor, starting with [Module 1: define the developer promise](docs/1-developer-promise.md). The proposed four-hour schedule includes explanations, Module 2 wiring, demonstrations, discussion, catch-up time, and two breaks. Its timing remains pending rehearsal.

#### On your own

If you're learning at your own pace:

1. Clone this repository and read the [workshop overview](docs/README.md).
2. Follow the [setup guide](setup/README.md) with the authorized Azure identity and permissions described there, including `setup/bootstrap.sh` before starting the modules. Cloning this repository alone does not provision or personalize the lab.
3. After the installation checkpoint passes, follow the same [numbered modules](docs/README.md#workshop-map) at your own pace, including the teaching notes and reflection prompts. Root Applications and the request API are intentionally absent on a fresh instance until Module 2 wires the platform. Keep unverified results marked pending.

Each learner uses one isolated lab subscription, one pre-created lab resource group, an AKS Standard control cluster, and an AKS Automatic workload cluster. AKS owns its separate node resource groups. The control cluster runs Argo CD, Crossplane, and provider-opentofu; the workload cluster receives the vended `beans` namespace and application.
The environment request also creates a managed identity, federation, and model and telemetry-publisher assignments per agent, and an OTLP-enabled Application Insights resource. The shared model and Log Analytics workspace remain part of bootstrap.
Application telemetry goes directly to cloud OTLP ingestion, without AKS `appMonitoring` or a collector pod. Fourth Coffee release `0.1.0-12.1.ge412f12` includes native authentication and token renewal; the image and upstream chart digests are pinned in `setup/artifact-lock.json`. The [lab delivery adapter and live-verification requirements](setup/README.md#application-artifact-prerequisite) preserve the workshop's identity and Gateway boundaries. A successful live rehearsal is not implied by the artifact pins.
The learner keeps the Lab on Demand (LOD) Contributor role plus bootstrap-provided cluster access. No Microsoft Entra tenant administration or GitHub organization administration is required. Learners review and manually merge allowed pull requests, honoring any externally configured organization branch checks. No custom validation workflow ships with the lab. The lab needs no GitHub App, automated approvals, or Azure credentials in GitHub Actions.
Backstage runs locally with guest access. The application uses `http://beans.localhost:8080` through a tunnel to the shared Gateway's ClusterIP service, so its real Gateway and HTTPRoute are exercised without custom DNS or public UI ingress. Real model access remains keyless through workload identity. The instructor inspects current application logs and telemetry; this does not demonstrate authorization isolation, which is outside this lab's scope.

### 🎯 Learning outcomes

By the end of this session, you will be able to:

- Define a thin platform capability around a recurring developer task, with clear ownership, supported choices, and success measures.
- Connect the installed platform's access, state, and delivery boundaries, then complete a self-service path that vends an AKS managed namespace and deploys an AI application through Backstage and GitOps using platform-provided identity and configuration.
- Recover from a policy rejection through Git and use application telemetry, cost evidence, and observed friction to choose the next platform improvement.

### 💻 Technologies used

- Azure Kubernetes Service (AKS) Standard for platform control, AKS Automatic for workloads, and managed namespaces
- Crossplane and the OpenTofu provider
- Argo CD and GitOps
- Backstage
- Git, GitHub, and GitHub Copilot as optional assistance
- Microsoft Entra ID and Azure workload identity
- Azure Policy and AKS Deployment Safeguards
- Azure OpenAI for the prepared hosted model
- Azure Monitor, Log Analytics, and Application Insights
- Visual Studio Code and Windows Subsystem for Linux (WSL)

### 📚 Continue your learning

Pick your next step based on your learning style:

| Resource                                                                           | What you'll get                                                      |
| :--------------------------------------------------------------------------------- | :------------------------------------------------------------------- |
| **[Ignite 2026 Next Steps](https://aka.ms/ignite26-next-steps)**                   | Additional session repos and materials from Microsoft Ignite 2026    |
| **[Microsoft AI Skills Navigator](https://aka.ms/ignite26-asn)**                   | Discover AI skills, learning paths, and resources for your next step |
| **[Microsoft Learn](https://aka.ms/ignite26-learn)**                               | Official documentation and guided learning paths on these topics     |
| **[Microsoft Foundry Community](https://aka.ms/MicrosoftFoundryDiscord-Ignite26)** | Connect with other learners and experts in our Discord community     |

### 🌟 Microsoft Learn MCP server

<!-- Remove this section if the Microsoft Learn MCP Server is not relevant to the session. -->

The Microsoft Learn Model Context Protocol (MCP) server gives your AI agent access to Microsoft's official documentation for grounded answers about the topics in this session. It is an optional learning aid, not a required lab dependency or an in-session installation task.

**VS Code:** One-click install for optional follow-up:

[![Install in VS Code](https://img.shields.io/badge/VS_Code-Install_Microsoft_Learn_MCP-0098FF?style=flat-square&logo=visualstudiocode&logoColor=white)](https://vscode.dev/redirect/mcp/install?name=microsoft-learn&config=%7B%22type%22%3A%22http%22%2C%22url%22%3A%22https%3A%2F%2Flearn.microsoft.com%2Fapi%2Fmcp%22%7D)
For more information, visit the [Learn MCP Server repo](https://aka.ms/learnmcp).

### 👥 Content owners

<!-- TODO: Add yourself as a content owner
1. Change the src in the image tag to {your github url}.png
2. Change INSERT NAME HERE to your name
3. Change the github url in the final href to your url. -->

<table> <tr> <td align="center"><a href="http://github.com/pauldotyu"> <img src="https://github.com/pauldotyu.png" width="100px;" alt="Paul Yu"/><br /> <sub><b>Paul Yu</b></sub></a><br /> <a href="https://github.com/pauldotyu" title="talk">📢</a> </td> <td align="center"><a href="http://github.com/bbenz"> <img src="https://github.com/bbenz.png" width="100px;" alt="Brian Benz"/><br /> <sub><b>Brian Benz</b></sub></a><br /> <a href="https://github.com/bbenz" title="talk">📢</a> </td> <td align="center"><a href="http://github.com/sjwaight"> <img src="https://github.com/sjwaight.png" width="100px;" alt="Simon Waight"/><br /> <sub><b>Simon Waight</b></sub></a><br /> <a href="https://github.com/sjwaight" title="talk">📢</a> </td> </tr></table> 
### ⚖️ Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
