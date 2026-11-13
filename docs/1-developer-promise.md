# Module 1: define the developer promise

[Workshop overview](README.md) | [Next: choose the foundation](1b-aks-foundation.md)

**Duration:** 35 minutes, 00:00-00:35.
**Rhythm:** 15 minutes explanation, 5 demonstration, 10 product exercise, 5 discussion.

## Objectives

By the end of this module, you will be able to:

- Describe a recurring developer task and the friction a platform capability should remove.
- Separate supported developer choices from platform defaults, mandatory controls, and exceptions.
- Define the capability's owner, first non-goals, and observable success criteria.

> **Platform concept: platform as a product.** A platform team has customers: the developers who use it. Start from a task they repeat and a promise you can keep, then pick tools. In this module you write that promise. The BACK stack shows up from Module 2 onward as the way to keep it.

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

> This workshop covers one application in one development environment. Production promotion and arbitrary infrastructure requests are out of scope. A thin capability that works beats an all-in-one fulfillment path that does not.

**Tip:** describe success from the developer's perspective (for example, "I can deploy my app and see the logs") before you name a tool.

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

In the VS Code Explorer, expand 📁 **Lab Root** > **answers** and open **product-brief.md**. You use this one worksheet for the whole workshop, with a section per module, so the promise you write now can be checked against what you observe later. Fill in the **Module 1** section as you go. If VS Code is not open yet, follow [Open the prepared workspace](README.md#open-the-prepared-workspace).

### 1. Name the task and friction

Describe the developer, the recurring task, and one handoff, repeated action, or unclear convention the capability should remove.

Stay with the supplied scenario for the build. You can relate it to your organization during discussion, but do not expand the implementation to another application or environment.

### 2. State the promise and boundary

Write a short capability statement. For example:

> A developer on the app team can request the approved development environment, deploy their app with platform-provided connections, and change its workload profile without routine manual fulfillment.

This is an illustrative statement to refine, not a measured customer finding.

Add the platform owner, support route, exception route, and first non-goals. Describe an accountable team or role rather than an individual.

### 3. Make the outcome observable

Write acceptance criteria in terms of things you can observe. Useful examples for this scenario are:

- The request produces the assigned namespace and usable baseline, not just an accepted API object.
- The application reaches the approved model without copying a model key.
- An approved profile change reaches the running application after the learner reviews and manually merges a PR, without another team fulfilling it.
- A rejected change points to a supported correction through Git.

You are defining what to evaluate, not asserting these outcomes already passed.

### 4. Ask a baseline question

Record one question about the current task: how much time is active work, how much is waiting, and where does the developer need help?

Do not invent a starting duration or improvement percentage. If a baseline is unavailable, record how you would collect it. Any supplied organizational figures are illustrative unless explicitly labeled with a measured source.

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

**Takeaway:** list the last ten requests your platform team handled by hand. Group them by developer task. The largest group with a short list of safe answers is a good first capability; write its promise in one sentence before choosing any tool.

## Checkpoint

You have a capability statement, owner and boundaries, observable acceptance criteria, and one baseline question in the worksheet.

You have not wired provider access, applied any manifests, or created the namespace or application. That is the expected fresh state. Continue to Module 2 to connect the prepared installation; do not wait for an API that has not been delivered. If resuming an existing instance, preserve its later progress rather than removing resources to match this checkpoint.

**What you learned:** an internal developer platform is valuable when it completes a developer task, not because it exposes a large number of tools.

---

[Previous: overview](README.md) | [Next: choose the foundation (optional reading)](1b-aks-foundation.md) | [Skip to Module 2: implement the environment contract](2-environment-contract.md)
