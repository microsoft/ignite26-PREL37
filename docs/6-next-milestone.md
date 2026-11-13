# Module 6: plan the next platform milestone

[Workshop overview](README.md) | [Previous: operate and recover](5-operate-and-recover.md) | [Next: summary](7-summary.md)

**Duration:** 20 minutes, 03:40-04:00.
**Rhythm:** 5 minutes explanation, 10 product exercise, 5 sharing/questions.

## Objectives

By the end of this module, you will be able to:

- Use observed friction to choose one next improvement or experiment.
- Define a developer outcome measure without inventing a baseline.
- Keep ownership, non-goals, and a feedback checkpoint explicit.

> **Platform concept: evidence and feedback.** A platform is never done. The next investment should follow observed developer friction and a measure you can collect, not the next tool on a list. The BACK stack gave you the evidence: Git history, Argo CD status, admission messages, and telemetry.

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

> **Tip:** before adding a tool to the roadmap, ask: "What specific developer friction does this remove, and how will I measure the improvement?" If there is no answer, the tool is a guess, not a priority.

## Product exercise: choose one next milestone

**10 minutes.**

In VS Code, return to `answers/product-brief.md` (**Lab Root** folder) and fill in the **Module 6** section.

### 1. Select one observed friction point

Use the PR numbers, timings, and results you recorded in the Module 2 to 5 sections. Choose one problem, not a backlog of every possible extension.

If your own run was blocked, describe the blocker honestly and state whether your proposal comes from direct experience, the demonstration, or supplied evidence.

### 2. Propose a bounded improvement or experiment

Describe what would change for the developer. Reuse the pilot team, owner, and non-goals from Module 1 rather than creating another planning document.

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

The worksheet is your take-home artifact. Guided attendees should use the prepared Skillable file-transfer instructions to save its non-sensitive contents. Self-paced learners already have it at `$LAB_ROOT/answers/product-brief.md` and can keep a separate non-sensitive copy before cleanup. Do not export credentials, token caches, kubeconfigs, Terraform state, shell history, or raw telemetry.

## Checkpoint

You have one next milestone connected to observed or explicitly qualified evidence, with a way to evaluate the developer outcome.

Use the [summary](7-summary.md) to review completion and end the session. That page does not add another timed exercise.

**What you learned:** platform engineering continues after the first working request, through ownership, feedback, and measured improvement.

---

[Previous: operate and recover](5-operate-and-recover.md) | [Next: summary and take-home material](7-summary.md)
