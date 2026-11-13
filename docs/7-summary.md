# Summary and take-home material

[Workshop overview](README.md) | [Previous: next milestone](6-next-milestone.md)

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

For the reasoning behind the two-cluster, two-tier design and links to each capability, see [why AKS is the foundation](1b-aks-foundation.md).

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
- The pinned Fourth Coffee artifact authenticates model calls and cloud OTLP ingestion through workload identity, with separate role assignments. Its release capability is not proof that the assigned environment exported successfully: retain the fresh model-call evidence and complete the setup guide's live checks. Endpoint URLs and routing attributes do not authorize reading telemetry. Backstage's guest session and static catalog owners likewise do not implement production user authorization.
- These boundaries do not make the capability less useful. They make its supported promise clear and identify what a production adoption would need to evaluate.

## End the session

Save the non-sensitive worksheet at `$LAB_ROOT/answers/product-brief.md`.

**Guided session:** follow the prepared Skillable transfer instructions if you want a copy. Organizers manage local-service shutdown and Azure cleanup; use their session-end instructions.

**Self-paced:** you or your authorized setup operator must complete [setup cleanup](../setup/README.md#resource-teardown). Keep the original Terraform state, controller credentials, and cluster access available until deletion finishes. Closing the browser or stopping a local tunnel does not stop Azure charges.

For both paths, cleanup follows resource ownership: remove the application environment through its controller before destroying the shared foundation. Do not manually delete the namespace, Workspace, identity, role assignments, or OpenTofu state backend out of order. Removing controller state too early can leave resources or permissions behind.

## Optional take-home exploration

These are optional follow-ups, not unfinished core lab requirements:

- Vend a second environment, `beans-prod`, from one Backstage form in the [optional next-environment exercise](8-optional-next-environment.md). It is the clearest way to see the golden path repeat.
- Refine the recovery guide improvement you recorded. Evaluate whether it makes the source and correction clearer to a developer.
- Revisit the next milestone with a pilot team and collect the baseline you defined.
- If organizers supplied `evidence/production-events.csv`, practice distinguishing production delivery measures from environment-provisioning and workshop events. Respect its synthetic or sanitized provenance.
- Review the setup guide to understand what must be maintained outside the developer-facing path.
- Explore the pinned [Fourth Coffee source](https://github.com/pauldotyu/fourth-coffee/tree/969ca1acae851d0ef3cb60619d5e0d6e90523fda) to relate the supplied workload to its local and Kubernetes layouts. This is optional source study, not a required image build.

Do not turn these into extra in-session PRs or consume the protected breaks to complete them.

## Reference material

- [Troubleshooting and safe recovery](appendix-a-troubleshooting.md).
- [Setup guide: bootstrap, native UI startup, and teardown](../setup/README.md).
- [Accepted abstract and scope](../README.md#session-description).
- [AKS managed namespaces](https://learn.microsoft.com/azure/aks/concepts-managed-namespaces).
- [Deployment Safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards).
- [Granular RBAC for Azure Monitor Logs](https://learn.microsoft.com/azure/azure-monitor/logs/granular-rbac-log-analytics).
- [AKS cost analysis](https://learn.microsoft.com/azure/aks/cost-analysis).
- [DORA delivery performance metrics](https://dora.dev/guides/dora-metrics/).
- [Build the platform, not the plumbing](https://blog.aks.azure.com/2026/11/09/build-the-platform-not-the-plumbing) on the AKS blog.

## Closing thought: from tooling to product

Moving from a tooling team to a platform product team is a shift in mindset. Tooling focuses on the _capability_ ("We have Argo CD"). Product thinking focuses on the _outcome_ ("Developers can ship a change without a ticket").

Backstage, Argo CD, Crossplane, and AKS are the vehicle. The real value is in the **contracts** you define and the **friction** you remove. This lab builds the API and the portal up front so you can see every layer. In your own platform, start small: add an API when pull requests become the bottleneck and a portal when discovery does. Base your roadmap on observed evidence, and always measure success by the developer's ability to complete their task.

---

[Previous: next milestone](6-next-milestone.md) | [Optional: vend the next environment](8-optional-next-environment.md) | [Back to workshop overview](README.md)
