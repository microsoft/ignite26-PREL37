# Interlude: choose the foundation for the promise

[Workshop overview](README.md) | [Previous: developer promise](1-developer-promise.md) | [Next: environment contract](2-environment-contract.md)

**Duration:** about 10 minutes of optional reading. Read it before Module 2, during a break, or after the session. It is not part of the timed schedule.

## Objectives

After reading, you will be able to:

- Explain why a platform team builds on a managed Kubernetes service instead of assembling every cluster capability itself.
- Describe the lab's two-cluster layout and why each cluster uses a different AKS tier.
- Separate what AKS provides, what the platform adds, and what developers own.

> **Platform concept: build the product, not the plumbing.** In Module 1 you wrote a promise. Every hour spent patching nodes, wiring ingress, or rotating credentials is an hour not spent keeping it. Choose a foundation that already handles the undifferentiated work, then spend your effort on the contract and the golden path.

No infrastructure changes happen here. This page explains choices that are already made in `infra/main.tf`.

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

**When Standard is the better call:** you need a pinned Kubernetes version, specific node configuration, a fixed footprint, or networking and add-ons that Automatic manages for you. Choosing Standard is a decision to own those settings, and that is a fair trade when you have a reason to.

## The choice this lab makes: two clusters, two tiers

The lab runs two clusters. Module 2 calls them the control plane and the workload plane.

**Control cluster: AKS Standard.** This cluster runs the platform's own controllers: Crossplane, which serves the request API, and Argo CD, which delivers from Git. Its workload is small, predictable, and owned by the platform team, so control matters more than elasticity. In `infra/main.tf` it is a single fixed node with manual node provisioning, a `patch` upgrade channel, `NodeImage` OS upgrades, local accounts disabled, Azure RBAC, workload identity, and Cilium networking. Those are Standard options turned on deliberately. The single node is sized for a lab, not for production.

**Workload cluster: AKS Automatic.** This is where developers' applications run. Here, best practices enforced by default matter most: every team's namespace starts from a hardened baseline, nodes appear when workloads need them, and patching happens without a platform ticket. The lab adds monitoring and the App Routing Gateway API implementation (Istio) on top of the Automatic defaults.

The pattern to take home: **run the platform where you want control, and run tenant workloads where you want guardrails by default.** It also keeps privileges apart. The credentials that create infrastructure live on the control cluster, never in an application namespace.

## What AKS provides, and what the platform adds

The BACK stack (Backstage, Argo CD, Crossplane, Kubernetes) does not replace AKS features. It packages them into a contract a developer can request.

| Layer                               | Owns                                                                                                  | In this lab                                                      |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **AKS**                             | Identity federation, admission safeguards, managed namespaces, Gateway, upgrades, scaling, monitoring | Control cluster (Standard) and workload cluster (Automatic)      |
| **Platform (BACK stack, OpenTofu)** | The `AppEnvironment` contract, composition, GitOps delivery, the catalog and form, approved profiles  | Crossplane and Argo CD on the control cluster, Backstage locally |
| **Developer**                       | Application configuration, profile choice, image                                                      | The app-deploy repository                                        |

Two examples make the split concrete:

- **Managed namespaces** are an AKS capability available on both tiers. AKS does not decide which team gets which namespace. The platform's OpenTofu module creates one per environment request, with the quota and labels the contract requires.
- **Argo CD** runs as the AKS [Argo CD cluster extension](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-argocd) (`Microsoft.ArgoCD`), so Azure handles its installation and release train. The platform team still owns the Applications, projects, and repositories it delivers.

AKS also stays open where you need it. Crossplane is installed from its upstream Helm chart, Backstage is the open source developer portal, and the Gateway API is the upstream Kubernetes API. You choose where a managed option saves effort and where an open source component fits better, on the same cluster.

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

A platform is only as calm as its foundation. Choose the AKS tier per cluster based on who should own each decision, let AKS carry the undifferentiated work, and build the developer contract on top.

---

[Previous: developer promise](1-developer-promise.md) | [Next: implement the environment contract](2-environment-contract.md)
