# PREL37: speaker deck specification

**Session:** Platform engineering on AKS: A paved road to AI apps.
**Format:** Slide content and delivery specification for the PREL37 PowerPoint deck. The deck itself is maintained outside this repository.
**Template:** Microsoft Ignite 2026 PREL37 template, Infra visual variant. **Design system:** [PREL37-design-system.md](PREL37-design-system.md).
**Duration:** 240 minutes, including two ten-minute breaks. **Slides:** 66, in nine sections that match the workshop guide. **Instructor demos:** five.
**Starting state:** On delivery day, the Azure subscription, its resources, and the lab VM are ready before learners sit down. Learners start at Module 1. No slide asks them to set anything up. Module 2's guided wiring connects controllers that are already installed; it is part of the module, not setup.

## The speaker's through-line

**Platform engineering removes toil for developers.**
A team building an AI agent needs five things before it writes a line of business logic: a place to run, an identity, access to a model, a way to see what the agent is doing, and a way to ship changes safely. Without a platform, each one is a ticket, a wait, and a different team.
The deck states that promise concretely in Module 1, then each module delivers part of it and asks the same question: **did this remove work, or relocate it?**
Three devices carry the through-line:

1. **The module skeleton.** Every module uses the same slide order, so learners always know whether to listen, watch, act, or discuss.
2. **The promise tracker.** The "team gets" list from Module 1 returns on every module's "why" slide, with that module's items highlighted.
3. **Remove or relocate?** Every debrief asks it. Module 6 turns it into the test for the next milestone.

The source of truth for attendee actions is the [workshop guide](../docs/README.md). Slides introduce each module, say what learners will do and when they are done, and add the points the guide leaves to the speaker. Do not ask learners to transcribe commands from the projector.

## Deck structure

```markdown
| Section                                        | Slides | Elapsed     | Guide                                                       |
| ---------------------------------------------- | ------ | ----------- | ----------------------------------------------------------- |
| Opening                                        | 1-4    | 00:00-00:03 | [Overview](../docs/README.md)                               |
| Module 1: define the developer promise         | 5-15   | 00:03-00:35 | [Module 1](../docs/1-developer-promise.md)                  |
| Module 2: implement the environment contract   | 16-26  | 00:35-01:25 | [Module 2](../docs/2-environment-contract.md)               |
| Module 3: connect and deploy the application   | 27-36  | 01:25-02:05 | [Module 3](../docs/3-application-delivery.md)               |
| Module 4: complete the self-service interface  | 37-46  | 02:05-02:55 | [Module 4](../docs/4-self-service.md)                       |
| Module 5: recover, inspect telemetry, and cost | 47-56  | 02:55-03:40 | [Module 5](../docs/5-operate-and-recover.md)                |
| Module 6: plan the next platform milestone     | 57-61  | 03:40-03:58 | [Module 6](../docs/6-next-milestone.md)                     |
| Summary                                        | 62-65  | 03:58-04:00 | [Summary](../docs/7-summary.md)                             |
| Optional: vend the next environment            | 66-67  | Take-home   | [Optional exercise](../docs/8-optional-next-environment.md) |
```

Elapsed times for Modules 2 and 4 include the break that follows them.

### The module skeleton

Modules 2 to 5 use the full skeleton. Module 1 replaces the "what you'll do" technical steps with the worksheet, and Module 6 drops the demo.

```markdown
| Step           | Slide type                      | Speaker's job                                                           |
| -------------- | ------------------------------- | ----------------------------------------------------------------------- |
| Divider        | Module divider                  | Name the module and the platform fundamental it teaches                 |
| Why            | Promise tracker                 | Show which part of the promise this module delivers                     |
| What you'll do | Steps and "done when"           | Lay out the learner's work and checkpoint before explaining any concept |
| Points to make | Two or three explanation slides | Add what the guide leaves to the speaker                                |
| Demo           | Demo slide with "watch for"     | Show the finished path in the instructor environment                    |
| Your turn      | Activity hold screen            | Stop presenting; announce the stop time                                 |
| Debrief        | Discussion screen               | Ask "remove or relocate?" about this module's work                      |
| Checkpoint     | Catch-up screen                 | Separate ready, pending, and blocked; take questions                    |
```

### The promise tracker

These mappings are verified against the lab. Each module's "why" slide highlights the items it puts to use.

```markdown
| Team gets                                    | Highlighted in | What the lab does                                                |
| -------------------------------------------- | -------------- | ---------------------------------------------------------------- |
| Namespace                                    | Module 2       | The request vends an AKS managed namespace                       |
| Sized quota                                  | Module 2       | The `ai-dev` namespace class sets the quota                      |
| Network defaults                             | Module 2       | Managed namespace policy plus the baseline NetworkPolicy         |
| Access to the namespace                      | Module 2       | Requester namespace access in AKS desktop                        |
| Argo CD project scoped to the team namespace | Module 2       | Per-request AppProject: one destination, whitelisted kinds       |
| Workload identity                            | Module 3       | Vended in Module 2, one identity per agent; consumed in Module 3 |
| Model access                                 | Module 3       | Granted in Module 2; proven by a fresh model call in Module 3    |
| Platform settings delivered                  | Module 3       | `platform-context` ConfigMap, named in `status.binding`          |
| Deploy repo                                  | Module 3       | Prepared before the session; the request does not create it      |
| Catalog entry and a golden path              | Module 4       | Static catalog entry; the profile template is the golden path    |
| Application Insights on the shared workspace | Module 5       | Vended in Module 2; read for current telemetry in Module 5       |
```

```markdown
| Team does not get              | Where the deck shows it                                 |
| ------------------------------ | ------------------------------------------------------- |
| A cluster                      | Module 2: a namespace on a shared workload cluster      |
| A kubeconfig with admin rights | Module 2: namespace-scoped access on the developer path |
| A model deployment             | Module 3: agents call the shared model                  |
| A dashboard                    | Module 5: search on the team's Application Insights     |
| A client secret                | Module 3: workload identity, no model key               |
```

**Keep claims inside the lab.** The lab has no AI gateway, so nothing in it is rate-limited. The deploy repo is prepared, not vended. Learners act as platform engineers with broad permissions, so "no admin kubeconfig" describes the developer path, not the lab account. Say this when it comes up rather than claiming more than the lab builds.

## Design system summary

Use the full [design system](PREL37-design-system.md) for exact style tokens, layout dimensions, and the module divider, promise tracker, and demo patterns.

```markdown
| Role           | Specification                                                                   |
| -------------- | ------------------------------------------------------------------------------- |
| Template       | PREL37 Ignite template, Infra variant; dark navy master background              |
| Text           | #FFFFFF; secondary text #E8E6DF                                                 |
| Accents        | #8DE971 for key principles and "this module"; #49C5B1 for delivered or evidence |
| Type           | Segoe Sans Text (template theme); titles 36 pt, body 20 pt, activity 24 pt      |
| Code           | Consolas, 18 pt on #1E1E1E panel                                                |
| Caption safety | Bottom 15% empty of critical content                                            |
| Animation      | 0.5 s Fade transitions; 0.3 s click reveals; no autoplay                        |
```

Content tables contain the exact visible copy. A semicolon separates distinct on-slide items. Style tokens expand to the font, size, weight, and color in the design system.

## Delivery rules

- Say what the developer is trying to accomplish before naming a tool.
- Show "what you'll do" before explaining concepts. Learners listen better when they know what they are about to build.
- End practice at the announced time. Debriefs, checkpoints, and both breaks are protected.
- Use the separate instructor environment for demos. Do not accelerate a learner's environment by changing its ownership or permissions.
- Treat recorded fallbacks as labeled teaching aids, not live evidence. Do not spend a five-minute demo debugging infrastructure.
- Record blocked, assisted, and demonstration-only outcomes honestly.

## Opening

**Slides 1-4. 00:00-00:03.**

### Slide 1: title

**Layout:** Title Slide. **Duration:** 0:45.

```markdown
| Element  | Content                                              | Position | Style |
| -------- | ---------------------------------------------------- | -------- | ----- |
| Title    | Platform engineering on AKS: A paved road to AI apps | TITLE    | T     |
| Subtitle | Remove the toil between a team and a running agent.  | SUBTITLE | H     |
| Session  | PREL37                                               | LABEL    | P     |
```

**Animation:** Static.
**Speaker notes:** "Today you build one slice of an internal developer platform and use it the way a developer would. The test for everything we build is simple: did it remove work for the application team, or move that work somewhere else?" Make clear that the environment is ready and the first module is a product exercise, not setup.

### Slide 2: today's path

**Layout:** Title and Content. **Duration:** 0:45.

```markdown
| Element | Content                                                    | Position     | Style     |
| ------- | ---------------------------------------------------------- | ------------ | --------- |
| Title   | Six modules, one developer promise                         | TITLE        | T         |
| Cards   | Six module cards, left to right (see below)                | BODY y24-60% | See below |
| Breaks  | Two "BREAK" markers in the gaps after cards 2 and 4        | BODY y24-60% | L         |
| Rhythm  | Each module: why, what you'll do, demo, your turn, debrief | LABEL        | B         |
```

Module cards, one rounded rectangle each, equal width, in a single row from x5% to x95%:

```markdown
| Card | Label (S) | Name (H)                | Start (L) |
| ---- | --------- | ----------------------- | --------- |
| 1    | MODULE 1  | Define the promise      | 00:03     |
| 2    | MODULE 2  | Implement the contract  | 00:35     |
| 3    | MODULE 3  | Connect and deploy      | 01:25     |
| 4    | MODULE 4  | Complete self-service   | 02:05     |
| 5    | MODULE 5  | Operate and recover     | 02:55     |
| 6    | MODULE 6  | Plan the next milestone | 03:40     |
```

Cards use the neutral #E8E6DF outline, no fill, with text top-aligned so names that wrap stay level across the row. Break markers are a thin dashed vertical rule with "BREAK" in L, centered in the wider gap after cards 2 and 4. Summary and the optional take-home exercise are not cards; the speaker mentions them.
**Animation:** Static.
**Speaker notes:** Explain the rhythm once. Every module opens by saying what you will build and how you know you are done, then shows a short demo, then hands over. The guide has the exact steps. When the speaker calls time, stop editing for the debrief; reconciliation keeps running. Mention the summary and the optional take-home exercise at the end.

### Slide 3: the lab at a glance

**Layout:** Title Only plus a lab map. **Duration:** 0:45.

```markdown
| Element | Content                                                          | Position     | Style     |
| ------- | ---------------------------------------------------------------- | ------------ | --------- |
| Title   | One team, one app, two clusters                                  | TITLE        | T         |
| Map     | Lab map: four zones, ready pieces solid, you-build pieces dashed | BODY y20-68% | See below |
| Legend  | Solid: ready for you. Dashed: you build, badge shows the module. | LABEL left   | L         |
| Stack   | Backstage, Argo CD, Crossplane, Kubernetes (AKS)                 | LABEL right  | P         |
```

Lab map zones, left to right, with Azure as a strip underneath both clusters:

```markdown
| Zone                             | Position         | Ready for you (solid)                                        | You build (dashed, module badge)                        |
| -------------------------------- | ---------------- | ------------------------------------------------------------ | ------------------------------------------------------- |
| Your lab VM                      | x5-22%, y20-55%  | VS Code workspace; local Backstage; two private GitHub repos | Golden path choice in Backstage (M4)                    |
| Control cluster (AKS Standard)   | x26-58%, y20-55% | Argo CD; Crossplane; provider-opentofu                       | Platform wiring and the AppEnvironment API (M2)         |
| Workload cluster (AKS Automatic) | x62-95%, y20-55% | Shared Gateway; Deployment Safeguards                        | beans namespace (M2), with Fourth Coffee inside it (M3) |
| Azure                            | x26-95%, y58-68% | Shared model; Log Analytics; state storage                   | Agent identities, model grants, App Insights (M2)       |
```

Connectors, thin arrows in #E8E6DF: lab VM -> control cluster labeled "pull request"; control cluster -> workload cluster labeled "Argo CD delivers"; control cluster -> Azure strip labeled "OpenTofu creates". Zone outlines are solid #E8E6DF with the zone name in S at the top. Ready pieces are solid teal #49C5B1 outlined chips. You-build pieces are dashed green #8DE971 outlined chips with a small "M2", "M3", or "M4" badge, matching the module cards on slide 2. The beans namespace is a dashed box inside the workload cluster, empty except for a dashed Fourth Coffee chip, to show it does not exist yet.
**Animation:** Reveal in two clicks. Click 1: zones, ready chips, and connectors. Click 2: all dashed you-build chips together.
**Speaker notes:** Start on click 1: "Everything solid is already running in your lab. You don't install anything today." Name the two clusters: the control cluster runs the platform, Argo CD and Crossplane; the AKS Automatic workload cluster runs applications. Click 2: "Everything dashed, you build, and the badge tells you which module." Point at the empty beans namespace: it does not exist until your request in Module 2 creates it, and the app lands in it in Module 3. The beans team and their app are next. The BACK stack is the vehicle, not the lesson. Learners act as platform engineers while judging the experience of a developer.

### Slide 4: meet Fourth Coffee

**Layout:** Title Only plus an app diagram. **Duration:** 0:45.
Source: the pinned Fourth Coffee application's architecture, adapted to the PREL37 template.

```markdown
| Element   | Content                                                        | Position         | Style     |
| --------- | -------------------------------------------------------------- | ---------------- | --------- |
| Title     | AI handles the conversation. Deterministic tools run the shop. | TITLE            | T         |
| Agents    | "Model-driven agents" zone (below)                             | x5-64%, y20-40%  | See below |
| Tools     | "Deterministic tools and rules" zone (below)                   | x5-64%, y44-64%  | See below |
| Order     | "Reliable order submission" panel (below)                      | x68-95%, y20-64% | See below |
| Telemetry | Agent traces link the chat to model and tool calls.            | BODY y66-70%     | L         |
| Point     | The app is supplied. Today you build the platform it lands on. | LABEL            | P         |
```

Agents zone, a pale outlined container labeled "Model-driven agents" in S:

```markdown
| Piece      | Card text                                                    |
| ---------- | ------------------------------------------------------------ |
| Customer   | Small person chip, arrow into Concierge                      |
| Concierge  | LLM concierge. Conversation, routing, drafts                 |
| Brewmaster | Operations specialist. Inventory, availability, pricing, ETA |
```

A two-way connector between Concierge and Brewmaster labeled "A2A delegation". Under each agent card, in L, the name learners see in the cluster: `concierge`, `ops-agent`.
Tools zone, a teal outlined container labeled "Deterministic tools and rules" in S. Two tool cards, each joined to the agent above by a vertical connector labeled "MCP": Customer tools (menu, quote, submit) under Concierge, and Operations tools (menu, availability, quote) under Brewmaster. A wide card along the bottom of the zone, "Fourth Coffee MCP: shop truth", holds menu, inventory, pricing, ETA, drafts, and idempotency; both tool cards connect down into it. In L under it: `fourth-coffee-mcp`.
Order panel, a #1E1E1E rounded panel headed "Models converse and delegate. MCP tools decide." in H, then "An order is submitted only from a confirmed draft." in B. Four circles joined by arrows, top to bottom:

```markdown
| Circle | Caption                        |
| ------ | ------------------------------ |
| DRAFT  | MCP quote, pending draft       |
| OK     | Explicit customer confirmation |
| KEY    | Idempotency key                |
| ORDER  | MCP submit, one order          |
```

Under the circles in L: "1 confirmed draft, 1 idempotency key, 1 submitted order".
If the instructor environment is ready, the speaker may instead show a 30-second live view of the concierge with "Show me the menu." and "Surprise me." Module 1's demo shows the finished app in depth; do not extend this slide into a demo.
**Animation:** Reveal: agents zone, then tools zone, then the order panel.
**Speaker notes:** The beans team runs Fourth Coffee. A customer chats with the concierge, which delegates operations questions to Brewmaster over agent-to-agent (A2A). Neither agent is trusted to invent a price, inventory, or an ETA: both call the Fourth Coffee MCP tool service, which holds the shop's truth. An order is submitted only from a draft the customer confirmed, with one idempotency key, so a retry cannot place two orders. In this workshop the agents export traces; the identity-free MCP service uses stdout, with its calls still visible in agent-side spans. Nobody writes agents or provisions GPUs today; the agents call an already hosted model. Then set up the next module: "Two agents and a tool service. Each one needs a place to run, the access its job requires, and a safe way to ship changes. That's the next slide." In Module 3 you deploy this app onto the platform; in Module 5 you follow one chat request to its model call.

## Module 1: define the developer promise

**Slides 5-15. 00:03-00:35.** Source: [Module 1](../docs/1-developer-promise.md). Rhythm: 12 minutes explanation, 5 demo, 10 product exercise, 5 discussion.

### Slide 5: Module 1 divider

**Layout:** Section Title, module. **Duration:** 0:15.

```markdown
| Element     | Content                      | Position | Style |
| ----------- | ---------------------------- | -------- | ----- |
| Label       | MODULE 1                     | LABEL    | S     |
| Title       | Define the developer promise | CENTER   | TD    |
| Fundamental | Platform as a product        | BADGE    | P     |
```

**Animation:** Static.
**Speaker notes:** "A platform team has customers. Before we touch a tool, we write down what we promise them."

### Slide 6: five things before business logic

**Layout:** Title and Content. **Duration:** 1:30.

```markdown
| Element | Content                                                                                         | Position | Style |
| ------- | ----------------------------------------------------------------------------------------------- | -------- | ----- |
| Title   | Before an agent does anything useful, a team needs five things                                  | TITLE    | T     |
| Needs   | A place to run; an identity; access to a model; a way to see what it does; a way to ship safely | BODY     | H     |
```

**Layout zones:** BODY shows five equal cells in one row.
**Animation:** Reveal; one need per click.
**Speaker notes:** None of these is the agent's business logic. All of them are needed before the first useful request. The beans team is no different from any team building an AI app.

### Slide 7: without a platform

**Layout:** Title and Content. **Duration:** 1:30.

```markdown
| Element | Content                                                    | Position | Style |
| ------- | ---------------------------------------------------------- | -------- | ----- |
| Title   | Without a platform, each one is a ticket                   | TITLE    | T     |
| Grid    | Each of the five needs: a ticket; a wait; a different team | BODY     | B     |
| Key     | Five needs. Five queues.                                   | LABEL    | K     |
```

**Layout zones:** BODY repeats the five cells from slide 6, each with "ticket, wait, team" beneath it.
**Animation:** Static.
**Speaker notes:** This is backlog coupling: the team's delivery depends on several other teams' queues. Automating each queue separately still leaves the team chasing five handoffs. Ask the room how many of the five they would wait on today. Do not quote numbers; let the room supply them.

### Slide 8: the promise

**Layout:** Title and Content. **Duration:** 1:30.

```markdown
| Element | Content                                                                                                            | Position    | Style |
| ------- | ------------------------------------------------------------------------------------------------------------------ | ----------- | ----- |
| Title   | The promise                                                                                                        | TITLE       | T     |
| Promise | From "we need somewhere to run this agent" to a running, observable agent in an afternoon, through a pull request. | BODY top    | K     |
| Without | No tickets for a cluster, a model deployment, a dashboard, or a credential.                                        | BODY bottom | H     |
```

**Animation:** Reveal; promise on load, then the "no tickets" line.
**Speaker notes:** This is the developer outcome the rest of the workshop builds toward. It is a promise to design against, not a measured result. Notice it says nothing about which tools; that comes later.

### Slide 9: writing the promise keeps the design honest

**Layout:** Two Content. **Duration:** 2:30.

```markdown
| Element      | Content                                                                                                                                                                                                                        | Position | Style |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ----- |
| Title        | Writing the promise early keeps the design honest                                                                                                                                                                              | TITLE    | T     |
| Team gets    | Namespace; sized quota; network defaults; namespace access; workload identity; model access; Application Insights on a shared workspace; deploy repo; scoped Argo CD project; platform settings; catalog entry and golden path | LEFT     | B     |
| Does not get | A cluster; an admin kubeconfig; a model deployment; a dashboard; a client secret                                                                                                                                               | RIGHT    | H     |
```

**Layout zones:** LEFT is the promise tracker in its neutral state (11 chips). RIGHT is five larger items.
**Animation:** Compare.
**Speaker notes:** The left column is what the platform hands over. The right column is just as important: each item there is something the team would otherwise own, maintain, and secure. Tell learners this list returns at the start of every module, with that module's part highlighted. The Argo CD project can deploy only into the team's namespace and only a short list of resource kinds. Be precise: the lab prepares the deploy repo and catalog entry rather than creating them per request.

### Slide 10: toil shifts to platform teams

**Layout:** Two Content. **Duration:** 2:30.

```markdown
| Element    | Content                                                                                                                                              | Position | Style |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| Title      | Toil shifts to platform teams. Not all toil is equal.                                                                                                | TITLE    | T     |
| Essential  | Essential toil amortizes. One AI gateway, one observability backend, one control plane serve every team. The twentieth team costs almost nothing.    | LEFT     | B     |
| Incidental | Incidental toil does not. A second orchestrator for the same resources, a per-team Grafana, a 30-minute apply per request: it grows with every team. | RIGHT    | B     |
| Test       | Useful test: does it remove work, or relocate it?                                                                                                    | LABEL    | P     |
```

**Animation:** Compare; the test label appears with the right column.
**Speaker notes:** This is the lens for the whole session. Platform work is not free; the question is whether its cost is shared or multiplied. The lab has examples of both: one shared model and one Log Analytics workspace serve every team, while every request runs its own OpenTofu apply. The AI gateway is an example of essential toil, not something this lab builds. If someone asks whether Crossplane plus OpenTofu is "two orchestrators," answer directly: Crossplane owns the request and the Workspace, OpenTofu owns the Azure resources, and no resource has two owners.

### Slide 11: today's thin slice

**Layout:** Two Content. **Duration:** 1:00.

```markdown
| Element  | Content                                                                                            | Position | Style |
| -------- | -------------------------------------------------------------------------------------------------- | -------- | ----- |
| Title    | Thin, but complete end to end                                                                      | TITLE    | T     |
| In scope | One team; one application; one development environment; one supported change; one recovery path    | LEFT     | H     |
| Later    | Production promotion; AI gateway and rate limits; full team onboarding; telemetry access isolation | RIGHT    | B     |
```

**Animation:** Compare.
**Speaker notes:** "Thin" means a bounded task, not an incomplete fulfillment path. Everything on the left works end to end. Everything on the right is a possible next milestone, which is exactly what Module 6 asks you to choose between.

### Slide 12: what you'll do in Module 1

**Layout:** What you'll do. **Duration:** 1:15.

```markdown
| Element   | Content                                  | Position     | Style     |
| --------- | ---------------------------------------- | ------------ | --------- |
| Title     | What you'll do in Module 1               | TITLE        | T         |
| Steps     | Four step cards (below)                  | BODY y21-52% | See below |
| Done when | Checklist strip (below)                  | BODY y56-70% | B         |
| Point     | No infrastructure changes in this module | LABEL        | P         |
```

Step cards:

```markdown
| #   | Card text                      | Tag       |
| --- | ------------------------------ | --------- |
| 1   | Name the task and its friction | Worksheet |
| 2   | State the promise and boundary | Worksheet |
| 3   | Make the outcome observable    | Worksheet |
| 4   | Ask one baseline question      | Worksheet |
```

Done-when checklist, one box per item: Promise. Owner. Non-goals. Acceptance criteria. Baseline question.
**Animation:** Static.
**Speaker notes:** Everything in Module 1 goes in 📁 **Lab Root** > **answers** > **product-brief.md** in the VS Code Explorer. It is one worksheet for the whole session, so the promise written now is checked against what learners observe later. The checklist is the done-when: five boxes, all in the worksheet.

### Slide 13: demo 1, watch the finished outcome

**Layout:** Demo. **Duration:** 5:00.

```markdown
| Element   | Content                                                                                                        | Position | Style |
| --------- | -------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| Label     | DEMO 1                                                                                                         | LABEL    | S     |
| Title     | Watch the developer's task finish                                                                              | CENTER   | TD    |
| Watch for | What the developer chooses; what the platform supplies; how they know it is running; what happens on rejection | BADGE    | BD    |
```

**Animation:** Demo.
**Speaker notes:** In the instructor environment, submit an approved profile change in Backstage, follow the generated PR, show Argo CD at the merged revision, open the app, and find its owner and recovery information. Return to this slide and ask which of the five needs from slide 6 the developer never had to think about. Learners' environments do not have the request API yet; Module 2 builds it.

### Slide 14: your turn, define the promise

**Layout:** Activity. **Duration:** 10:00.

```markdown
| Element | Content                                                                        | Position | Style |
| ------- | ------------------------------------------------------------------------------ | -------- | ----- |
| Label   | YOUR TURN · 10 MINUTES                                                         | LABEL    | S     |
| Title   | Write the promise for the beans team                                           | TITLE    | T     |
| Steps   | Task and friction; promise and boundary; observable outcome; baseline question | BODY     | A     |
| Guide   | Module 1 · answers/product-brief.md                                            | FOOTER   | B     |
```

**Animation:** Static.
**Speaker notes:** Announce the stop time. Stay with the supplied scenario. Do not invent a baseline duration; if there is none, write how you would collect it.

### Slide 15: discuss, which inputs belong in the request?

**Layout:** Discussion. **Duration:** 5:00.

```markdown
| Element | Content                                                                                                                            | Position | Style |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| Label   | DISCUSS · 5 MINUTES                                                                                                                | LABEL    | S     |
| Title   | Choice, default, control, or exception?                                                                                            | TITLE    | T     |
| Items   | Workload profile; owner and cost center; raw identity client ID; cluster placement; image tag; production access                   | BODY     | A     |
| Reveal  | Profile: choice (M4); cost center: control (M2); identity and placement: platform (M3); image: control (M5); production: exception | LABEL    | B     |
```

**Animation:** Reveal; the answer line appears on the final click.
**Speaker notes:** Pause writing. Take two or three answers before revealing. The reveal is a map of the rest of the workshop: each answer becomes a build step. A dropdown is usability, not authorization; that returns in Module 4.

## Module 2: implement the environment contract

**Slides 16-26. 00:35-01:25 including the break.** Source: [Module 2](../docs/2-environment-contract.md). Rhythm: 10 minutes explanation and guided wiring, 5 demo, 15 practice, 5 debrief, 5 checkpoint, then the first break.
**Delivery cue:** The controllers are installed but not wired. Learners run the guide's wiring steps 1 to 5 while slides 19 to 21 are on screen. Rehearse this pairing; do not move wiring into setup or cut the break to hide a timing problem.

### Slide 16: Module 2 divider

**Layout:** Section Title, module. **Duration:** 0:15.

```markdown
| Element     | Content                            | Position | Style |
| ----------- | ---------------------------------- | -------- | ----- |
| Label       | MODULE 2                           | LABEL    | S     |
| Title       | Implement the environment contract | CENTER   | TD    |
| Fundamental | Self-service through a contract    | BADGE    | P     |
```

**Animation:** Static.
**Speaker notes:** "Now we build the first part of the promise: one request instead of five tickets."

### Slide 17: why, one request instead of five tickets

**Layout:** Promise tracker. **Duration:** 1:30.

```markdown
| Element   | Content                                         | Position     | Style     |
| --------- | ----------------------------------------------- | ------------ | --------- |
| Title     | One request instead of five tickets             | TITLE        | T         |
| Tracker   | Eleven chips; five marked "this module" (below) | BODY x5-68%  | See below |
| Not given | "Instead of" pairs (below)                      | BODY x72-95% | See below |
```

Tracker chips marked **this module**: Namespace. Sized quota. Network defaults. Access to the namespace. Argo CD project scoped to the team namespace. All other chips stay neutral.
Not-given column, one pair per row:

```markdown
| Not given (struck through) | Instead                         |
| -------------------------- | ------------------------------- |
| A cluster                  | A namespace on a shared cluster |
| An admin kubeconfig        | Access scoped to that namespace |
```

**Animation:** Static.
**Speaker notes:** One merged request vends the namespace and its guardrails, and it also creates the identities, model grants, and Application Insights resource that later modules put to use. Read the right column as trades: the team gets a namespace on a shared cluster instead of a cluster, and namespace-scoped access instead of admin. Learners hold broader permissions today because they are also the platform engineer.

### Slide 18: what you'll do in Module 2

**Layout:** What you'll do. **Duration:** 1:30.

```markdown
| Element   | Content                                       | Position     | Style     |
| --------- | --------------------------------------------- | ------------ | --------- |
| Title     | What you'll do in Module 2                    | TITLE        | T         |
| Steps     | Four step cards (below)                       | BODY y21-52% | See below |
| Done when | Checklist strip (below)                       | BODY y56-70% | B         |
| Point     | The API changes before a request relies on it | LABEL        | P         |
```

Step cards:

```markdown
| #   | Card text                      | Tag     |
| --- | ------------------------------ | ------- |
| 1   | Wire the installed controllers | kubectl |
| 2   | Make costCenter required       | PR 1    |
| 3   | Request beans-dev              | PR 2    |
| 4   | Trace it to Ready              | Verify  |
```

Done-when checklist: beans-dev is Ready. The namespace carries the cost-center label. The baseline exists.
**Animation:** Reveal, one card per click.
**Speaker notes:** Two PRs, in order: the API must change before a request relies on it. Learners merge their own PRs because they are both platform engineer and reviewer; in production, a second person or a required check would review. After every merge, confirm Argo CD synced that commit. Merged is not delivered.

### Slide 19: the request carries intent

**Layout:** Two Content with code. **Duration:** 2:15.

```markdown
| Element  | Content                                                      | Position            | Style     |
| -------- | ------------------------------------------------------------ | ------------------- | --------- |
| Title    | The developer asks for an outcome. The platform decides how. | TITLE               | T         |
| Code     | The request excerpt below, with four callouts                | LEFT, #1E1E1E panel | C         |
| Supplied | "The platform fills in" chips (below)                        | RIGHT               | See below |
| Wiring   | Three connector pills (below)                                | BODY y62-70%        | B         |
```

Visible code:

```yaml
spec:
  team: beans
  application: fourth-coffee
  owner: group:default/beans
  costCenter: CC-1042
  namespaceClass: ai-dev
```

Callouts, thin lines from the code to short labels in L:

```markdown
| Field          | Callout                  |
| -------------- | ------------------------ |
| team           | Names the namespace      |
| owner          | Who gets access          |
| costCenter     | Who pays                 |
| namespaceClass | How big, and what policy |
```

Right column heading: "The platform fills in". Four neutral chips stacked: Cluster. OpenTofu module. Identities and role grants. Model endpoint and telemetry. Caption under the chips in L: "from `config/environment.yaml`, never typed by a developer".
Wiring strip, heading "You connect now" in S, three pills with arrows inside them:

```markdown
| Pill                        | Meaning                                        |
| --------------------------- | ---------------------------------------------- |
| GitHub -> provider-opentofu | Fetch the module with a scoped token           |
| provider-opentofu -> Azure  | Platform identity, remote state                |
| Crossplane -> Argo CD       | Create the team's Applications and AppProjects |
```

**Animation:** Static for code; Reveal: callouts, then the right column, then the wiring strip.
**Speaker notes:** Learners start the guided wiring now. Point out what is missing from the request: no role IDs, no module URL, no cluster name. If the request accepted those, it would be a remote infrastructure console rather than a product. The trusted mapping in `config/environment.yaml` supplies them, and learners apply it with `kubectl` during wiring. The three pills are wiring step 2: after it, the platform fetches its module with a scoped token and calls Azure with its own workload identity, not anyone's `az login`. `AppEnvironment` is defined by this workshop; it is not a built-in AKS API.

### Slide 20: Crossplane owns the API, OpenTofu owns Azure

**Layout:** Two Content. **Duration:** 2:15.

```markdown
| Element   | Content                                                      | Position     | Style     |
| --------- | ------------------------------------------------------------ | ------------ | --------- |
| Title     | Crossplane owns the API. OpenTofu owns Azure.                | TITLE        | T         |
| Lanes     | Two ownership lanes joined by a Workspace arrow (below)      | BODY y21-54% | See below |
| Trace     | costCenter trace, four pills left to right (below)           | BODY y58-68% | B         |
| Ownership | Every resource has one owner. moduleRevision pins what runs. | LABEL        | P         |
```

Ownership lanes, each a tall rounded box with its owner in S at the top and chips stacked inside:

```markdown
| Lane                                | Chips                                                                     |
| ----------------------------------- | ------------------------------------------------------------------------- |
| Crossplane, control cluster         | AppEnvironment API. The request. The team's Argo CD AppProjects           |
| OpenTofu, through provider-opentofu | Managed namespace and quota. Agent identities. Model grants. App Insights |
```

Between the lanes, one arrow from Crossplane to OpenTofu labeled "OpenTofu Workspace". Under the OpenTofu lane, a small storage icon labeled "state in the lab storage account".
costCenter trace: `costCenter: CC-1042` -> Composition -> Workspace input -> namespace label and resource tags.
**Animation:** Compare the two lanes, then reveal the trace.
**Speaker notes:** This is the connection platform engineers came to see. Crossplane is the product surface: it serves the `AppEnvironment` API, validates the request, and turns it into an OpenTofu Workspace plus the team's AppProjects. OpenTofu does the Azure work through provider-opentofu, using the identity and state backend learners wired in step 2. Follow the trace along the bottom, which is wiring step 4: `costCenter` enters as a request field, the Composition passes it into the Workspace `varmap`, and OpenTofu writes it as a namespace label and resource tags. `moduleRevision` means a change on `main` does not change the code that runs until the platform team bumps the pin. If someone asks whether this is two orchestrators describing the same resources: no. Crossplane owns the Kubernetes objects, OpenTofu owns the Azure resources, and no resource has two owners. Keep the full chain for the demo: Git -> Argo CD -> Crossplane -> OpenTofu -> Azure -> baseline, about 6 to 9 minutes on a fresh lab. Learners connect these parts; they do not author the chain.

### Slide 21: two distinctions

**Layout:** Two Content. **Duration:** 2:15.

```markdown
| Element     | Content                                                                 | Position | Style |
| ----------- | ----------------------------------------------------------------------- | -------- | ----- |
| Title       | Two distinctions a developer needs                                      | TITLE    | T     |
| States      | Accepted (merged) -> provisioned (Azure) -> usable (baseline delivered) | LEFT     | H     |
| Attribution | Cost center says who pays. Quota bounds resources. Neither is a budget. | RIGHT    | H     |
```

**Animation:** Compare.
**Speaker notes:** A good platform tells the developer which state they are in; a green "merged" check is not "ready." Requiring `costCenter` at request time means no environment arrives without an owner, so nobody chases attribution later. The `ai-dev` quota caps CPU and memory, not dollars. Module 5 returns to cost.

### Slide 22: demo 2, trace one request

**Layout:** Demo. **Duration:** 5:00.

```markdown
| Element   | Content                                                                                              | Position | Style |
| --------- | ---------------------------------------------------------------------------------------------------- | -------- | ----- |
| Label     | DEMO 2                                                                                               | LABEL    | S     |
| Title     | One YAML file becomes a usable namespace                                                             | CENTER   | TD    |
| Watch for | The rejected request without costCenter; the Workspace; the managed namespace in Azure; the baseline | BADGE    | BD    |
```

**Animation:** Demo.
**Speaker notes:** In the completed instructor environment, show the schema requirement and the rejection, then the request, its Workspace, the managed namespace in the Azure portal, and the baseline on the workload cluster. Every hop is visible. Do not promise fresh Azure provisioning inside four minutes. The instructor's environment is not evidence that a learner's wiring worked.

### Slide 23: your turn, require attribution and vend the environment

**Layout:** Activity. **Duration:** 15:00.

```markdown
| Element  | Content                                     | Position     | Style     |
| -------- | ------------------------------------------- | ------------ | --------- |
| Label    | YOUR TURN · 15 MINUTES                      | LABEL        | S         |
| Title    | Require attribution, then request beans-dev | TITLE        | T         |
| PR cards | Two PR cards side by side (below)           | BODY y21-52% | See below |
| Progress | Three-stage status bar (below)              | BODY y56-66% | B         |
| Guide    | Module 2 · Guided practice                  | FOOTER       | B         |
```

PR cards:

```markdown
| Card                      | Lines inside the card                                           |
| ------------------------- | --------------------------------------------------------------- |
| PR 1: costCenter required | Edit the schema. Merge. Prove a request without it is rejected. |
| PR 2: request beans-dev   | Add the request file. Merge. Watch it reach Ready.              |
```

An arrow joins PR 1 to PR 2 labeled "API first".
Status bar, three segments: Accepted (merged) -> Provisioned (Azure) -> Usable (baseline delivered). Caption under it in L: "about 6 to 9 minutes".
**Animation:** Static.
**Speaker notes:** Announce the stop time. The chain takes 6 to 9 minutes, so learners who merge PR 2 late will still be waiting at the debrief. That is expected; status returns at the checkpoint. The status bar is the same three states from slide 21; ask learners which one they are in, not whether they are done.

### Slide 24: debrief, who owns the wait?

**Layout:** Discussion. **Duration:** 5:00.

```markdown
| Element | Content                                                                                     | Position | Style |
| ------- | ------------------------------------------------------------------------------------------- | -------- | ----- |
| Label   | DEBRIEF · 5 MINUTES                                                                         | LABEL    | S     |
| Title   | Remove or relocate?                                                                         | TITLE    | T     |
| Prompts | What did a waiting developer see? Which part of the wait is essential? Which is incidental? | BODY     | A     |
```

**Animation:** Static.
**Speaker notes:** Pause editing. A visible 6 to 9 minute wait with named stages beats a ticket queue, but a per-request OpenTofu apply is incidental toil that grows with every team. Name it honestly as a candidate for Module 6. Ask what the developer would need to see to act on a stuck request without asking the platform team to read controller logs.

### Slide 25: checkpoint, environment ready

**Layout:** Checkpoint. **Duration:** 5:00.

```markdown
| Element | Content                                                                           | Position | Style |
| ------- | --------------------------------------------------------------------------------- | -------- | ----- |
| Label   | CHECKPOINT · 5 MINUTES                                                            | LABEL    | S     |
| Title   | Environment ready, not application                                                | TITLE    | T     |
| Ready   | beans-dev Ready; namespace labeled with the cost center; baseline resources exist | BODY     | A     |
| Pending | Still pending or blocked? Record it and ask a proctor. Keep the lab running.      | LABEL    | B     |
```

**Animation:** Static.
**Speaker notes:** Learners record the PR numbers, merged revisions, and result in the worksheet. Proctors use [Appendix A](../docs/appendix-a-troubleshooting.md#environment-request-is-merged-but-not-ready).

### Slide 26: first break

**Layout:** Section Title, break. **Duration:** 10:00.

```markdown
| Element | Content                                  | Position | Style |
| ------- | ---------------------------------------- | -------- | ----- |
| Label   | BREAK                                    | LABEL    | S     |
| Title   | Take ten minutes                         | CENTER   | TD    |
| Badge   | Leave the lab running. Back at Module 3. | BADGE    | BD    |
```

**Animation:** Static.
**Speaker notes:** Announce the return time from the actual clock. Reconciliation continues during the break. Do not ask learners to work through it.

## Module 3: connect and deploy the application

**Slides 27-36. 01:25-02:05.** Source: [Module 3](../docs/3-application-delivery.md). Rhythm: 10 minutes explanation, 5 demo, 15 practice, 5 debrief, 5 checkpoint.

### Slide 27: Module 3 divider

**Layout:** Section Title, module. **Duration:** 0:15.

```markdown
| Element     | Content                            | Position | Style |
| ----------- | ---------------------------------- | -------- | ----- |
| Label       | MODULE 3                           | LABEL    | S     |
| Title       | Connect and deploy the application | CENTER   | TD    |
| Fundamental | Golden paths                       | BADGE    | P     |
```

**Animation:** Static.
**Speaker notes:** "The supported way should be the easiest way. Let's see how little the team has to supply."

### Slide 28: why, no client secret, no model key

**Layout:** Promise tracker. **Duration:** 1:45.

```markdown
| Element   | Content                                            | Position     | Style     |
| --------- | -------------------------------------------------- | ------------ | --------- |
| Title     | Run on the platform without assembling credentials | TITLE        | T         |
| Tracker   | Eleven chips; four marked "this module" (below)    | BODY x5-68%  | See below |
| Not given | "Instead of" pairs (below)                         | BODY x72-95% | See below |
```

Tracker chips marked **this module**: Workload identity. Model access. Platform settings delivered. Deploy repo, with a small "prepared" tag. Chips highlighted in Module 2 show as delivered; the rest stay neutral.
Not-given column, one pair per row:

```markdown
| Not given (struck through) | Instead                       |
| -------------------------- | ----------------------------- |
| A client secret            | A workload identity per agent |
| A model deployment         | A grant on the shared model   |
```

**Animation:** Static.
**Speaker notes:** Module 2 created the identities and model grants; this module proves they work. Without a platform, the team would look up identity IDs, copy a model key, and assemble resource identifiers. Here they supply one name. The deploy repo was prepared before the session; the request did not create it.

### Slide 29: what you'll do in Module 3

**Layout:** What you'll do. **Duration:** 1:30.

```markdown
| Element   | Content                                       | Position     | Style     |
| --------- | --------------------------------------------- | ------------ | --------- |
| Title     | What you'll do in Module 3                    | TITLE        | T         |
| Steps     | Five step cards (below)                       | BODY y21-52% | See below |
| Done when | Checklist strip (below)                       | BODY y56-70% | B         |
| Point     | The platform is already waiting for your part | LABEL        | P         |
```

Step cards:

```markdown
| #   | Card text                     | Tag    |
| --- | ----------------------------- | ------ |
| 1   | Read the binding              | Read   |
| 2   | Add values, one blank to fill | Edit   |
| 3   | Open and merge the PR         | PR     |
| 4   | Confirm your commit deployed  | Verify |
| 5   | Verify a fresh model call     | Verify |
```

Done-when checklist: Argo CD runs your commit. A fresh chat produces a successful model call in telemetry.
**Animation:** Reveal, one card per click.
**Speaker notes:** The platform already created the Argo CD Application `fourth-coffee`; it reports that `values.yaml` is missing until learners commit it. That is the platform waiting for the team's part. Two of five cards are verify steps on purpose: deployed and working are separate claims.

### Slide 30: the platform publishes the binding

**Layout:** Two Content with code. **Duration:** 2:15.

```markdown
| Element | Content                                                                | Position            | Style |
| ------- | ---------------------------------------------------------------------- | ------------------- | ----- |
| Title   | The platform publishes the contract. You fill one name.                | TITLE               | T     |
| Code    | The binding excerpt below                                              | LEFT, #1E1E1E panel | C     |
| Meaning | Platform assigns each agent its identity; you consume platform-context | RIGHT               | B     |
```

Visible code:

```yaml
# set by the platform's Argo CD Application
workloadIdentity.serviceAccounts.concierge: concierge
workloadIdentity.serviceAccounts.ops-agent: ops-agent
# filled by you from status.binding
extraEnvFrom:
  - configMapRef:
      name: platform-context
```

**Animation:** Static for code; Reveal for the meaning labels.
**Speaker notes:** `status.binding` publishes the namespace, ServiceAccounts, ConfigMap, Argo CD project and Application, config path, and app URL. Every value derives from the request, so another team gets its own set. Learners never write the Application manifest, so they cannot change its destination, project, or chart source by accident.

### Slide 31: identity is not configuration

**Layout:** Two Content. **Duration:** 2:15.

```markdown
| Element       | Content                                                                          | Position | Style |
| ------------- | -------------------------------------------------------------------------------- | -------- | ----- |
| Title         | Configuration says where. Identity says may.                                     | TITLE    | T     |
| Configuration | platform-context: model endpoint; native cloud OTLP URLs and routing attribute   | LEFT     | H     |
| Identity      | One identity per agent; federated ServiceAccount; model and DCR-publisher grants | RIGHT    | H     |
```

**Animation:** Compare.
**Speaker notes:** Separate identities let access be audited and revoked per agent. `fourth-coffee-mcp` calls no model, so it gets no Azure identity and its SDK telemetry is disabled; inspect its stdout instead. Naming a ServiceAccount in values does not create trust or grant access; vending did that. The agents use workload identity for model calls and cloud OTLP ingestion with different roles. OTLP URLs and routing attributes are not read credentials. The Fourth Coffee release supports authenticated export; organizers must still verify actual ingestion and token renewal in the assigned lab before this demonstration.

### Slide 32: a plausible answer is not evidence

**Layout:** Title and Content. **Duration:** 2:00.

```markdown
| Element  | Content                                                                                | Position | Style |
| -------- | -------------------------------------------------------------------------------------- | -------- | ----- |
| Title    | A working page is not a working model call                                             | TITLE    | T     |
| Evidence | Your commit deployed -> route answers -> fresh chat -> correlated model call succeeded | BODY     | H     |
| Trap     | The app can return a plausible fallback when the model call fails.                     | LABEL    | P     |
```

**Animation:** Trace.
**Speaker notes:** A green health probe or a convincing reply is incomplete evidence. Learners run `queries/application-model-call.kql` and look for a row newer than their chat with `ModelSuccess` true. A historical trace does not prove the fresh interaction.

### Slide 33: demo 3, follow the binding

**Layout:** Demo. **Duration:** 5:00.

```markdown
| Element   | Content                                                                         | Position | Style |
| --------- | ------------------------------------------------------------------------------- | -------- | ----- |
| Label     | DEMO 3                                                                          | LABEL    | S     |
| Title     | From binding to a real model call                                               | CENTER   | TD    |
| Watch for | The binding; the deployed revision; a fresh chat; the correlated model-call row | BADGE    | BD    |
```

**Animation:** Demo.
**Speaker notes:** Show `status.binding`, the Argo CD revision matching the merged commit, a fresh chat through the gateway, and the query result. If ingestion is slow, say so and mark it pending.

### Slide 34: your turn, bind and deploy

**Layout:** Activity. **Duration:** 15:00.

```markdown
| Element | Content                                                                                         | Position | Style |
| ------- | ----------------------------------------------------------------------------------------------- | -------- | ----- |
| Label   | YOUR TURN · 15 MINUTES                                                                          | LABEL    | S     |
| Title   | Bind and deploy Fourth Coffee                                                                   | TITLE    | T     |
| Steps   | Read the binding; fill the blank; PR and merge; confirm the revision; verify a fresh model call | BODY     | A     |
| Guide   | Module 3 · Guided practice                                                                      | FOOTER   | B     |
```

**Animation:** Static.
**Speaker notes:** Announce the stop time.

### Slide 35: debrief, what toil disappeared?

**Layout:** Discussion. **Duration:** 5:00.

```markdown
| Element | Content                                                                                                         | Position | Style |
| ------- | --------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| Label   | DEBRIEF · 5 MINUTES                                                                                             | LABEL    | S     |
| Title   | Remove or relocate?                                                                                             | TITLE    | T     |
| Prompts | What did you not have to do? What decisions stayed with the app team? Would a failure have been understandable? | BODY     | A     |
```

**Animation:** Static.
**Speaker notes:** Collect the "did not do" list: no identity IDs, no model key, no Application manifest, no namespace or quota in the chart. Then the honest part: the app team still owns its configuration and its behavior. The goal is not hiding YAML; it is removing repeated assembly.

### Slide 36: checkpoint, working app with model evidence

**Layout:** Checkpoint. **Duration:** 5:00.

```markdown
| Element | Content                                                        | Position | Style |
| ------- | -------------------------------------------------------------- | -------- | ----- |
| Label   | CHECKPOINT · 5 MINUTES                                         | LABEL    | S     |
| Title   | Working app, real model evidence                               | TITLE    | T     |
| Ready   | Argo CD at your commit; Healthy; a fresh correlated model call | BODY     | A     |
| Pending | Telemetry still arriving? Record it as pending, not passed.    | LABEL    | B     |
```

**Animation:** Static.
**Speaker notes:** Take questions. Proctors help blocked learners.

## Module 4: complete the self-service interface

**Slides 37-46. 02:05-02:55 including the break.** Source: [Module 4](../docs/4-self-service.md). Rhythm: 10 minutes explanation, 5 demo, 15 practice, 5 debrief, 5 checkpoint, then the second break.

### Slide 37: Module 4 divider

**Layout:** Section Title, module. **Duration:** 0:15.

```markdown
| Element     | Content                                           | Position | Style |
| ----------- | ------------------------------------------------- | -------- | ----- |
| Label       | MODULE 4                                          | LABEL    | S     |
| Title       | Complete the self-service interface               | CENTER   | TD    |
| Fundamental | The portal is a front door, not a second pipeline | BADGE    | P     |
```

**Animation:** Static.
**Speaker notes:** "The path works. Now make one supported change easy to find."

### Slide 38: why, a golden path people can find

**Layout:** Promise tracker. **Duration:** 2:00.

```markdown
| Element | Content                                            | Position | Style     |
| ------- | -------------------------------------------------- | -------- | --------- |
| Title   | A golden path is only useful if people can find it | TITLE    | T         |
| Tracker | Eleven chips; one marked "this module" (below)     | BODY     | See below |
| Point   | Same delivery path as Module 3. New front door.    | LABEL    | P         |
```

Tracker chip marked **this module**: Catalog entry and a golden path. Chips highlighted in Modules 2 and 3 show as delivered; the rest stay neutral.
**Animation:** Static.
**Speaker notes:** The team can already change the app through Git. Backstage makes one change, resizing the app, discoverable. It must not become a second deployment system with its own permissions, defaults, or recovery behavior.

### Slide 39: what you'll do in Module 4

**Layout:** What you'll do. **Duration:** 1:45.

```markdown
| Element   | Content                                   | Position     | Style     |
| --------- | ----------------------------------------- | ------------ | --------- |
| Title     | What you'll do in Module 4                | TITLE        | T         |
| Steps     | Five step cards in two groups (below)     | BODY y21-52% | See below |
| Done when | Checklist strip (below)                   | BODY y56-70% | B         |
| Point     | First change the menu, then order from it | LABEL        | P         |
```

Step cards, with a bracket over cards 1-2 labeled "As the platform engineer" and over cards 3-5 labeled "As the developer":

```markdown
| #   | Card text                    | Tag       |
| --- | ---------------------------- | --------- |
| 1   | Add standard to the selector | PR        |
| 2   | Refresh the template         | Backstage |
| 3   | Request standard             | Backstage |
| 4   | Review and merge             | PR        |
| 5   | Confirm the rollout          | Verify    |
```

Done-when checklist: The PR changed only `profile.yaml`. Concierge runs the standard requests.
**Animation:** Reveal by group.
**Speaker notes:** The template change is itself a platform PR. Backstage reads the merged template from GitHub, not the local copy, so it must be refreshed after merge. Then learners switch hats and use the choice they just published.

### Slide 40: offer a decision, not an implementation

**Layout:** Two Content. **Duration:** 3:00.

```markdown
| Element  | Content                                                     | Position | Style |
| -------- | ----------------------------------------------------------- | -------- | ----- |
| Title    | Offer a decision, not CPU and memory numbers                | TITLE    | T     |
| small    | small: agents 200m, 256Mi requests; 1000m, 768Mi limits     | LEFT     | B     |
| standard | standard: agents 400m, 512Mi requests; 1000m, 1536Mi limits | RIGHT    | B     |
| Caveat   | Same namespace quota. Bigger is not automatically faster.   | LABEL    | P     |
```

**Animation:** Compare.
**Speaker notes:** The platform team owns what each name means in `platform/profiles/`. The template has two built-in steps and no custom code: fetch the approved profile file unchanged, and open a PR that replaces only `profile.yaml`. Because the profile lives in its own file, it cannot disturb image, identity, or telemetry settings. A good field description says what the choice changes and what it does not.

### Slide 41: the form is not the guardrail

**Layout:** Two Content. **Duration:** 3:00.

```markdown
| Element | Content                                                      | Position | Style     |
| ------- | ------------------------------------------------------------ | -------- | --------- |
| Title   | The form guides. The checks protect.                         | TITLE    | T         |
| Left    | "What keeps the change safe" layer stack (below)             | LEFT     | See below |
| Right   | "When is it done?" three-stage tracker (below)               | RIGHT    | See below |
| Point   | Only a rollout in Argo CD means the developer got the change | LABEL    | P         |
```

Left, heading "What keeps the change safe", five stacked bars from top to bottom. The top bar is neutral and labeled "convenience"; the four below are teal and labeled "control":

```markdown
| Bar                                      | Label       |
| ---------------------------------------- | ----------- |
| The dropdown shows small and standard    | Convenience |
| Each name maps to one approved file      | Control     |
| A person reviews the PR                  | Control     |
| Helm schema validates the values         | Control     |
| Kubernetes admission checks the workload | Control     |
```

Right, heading "When is it done?", three steps top to bottom, each naming where you see it:

```markdown
| Stage               | Means             | Where you see it |
| ------------------- | ----------------- | ---------------- |
| Backstage task done | A PR was opened   | Backstage        |
| PR merged           | Desired state set | GitHub           |
| Rolled out          | Fulfilled         | Argo CD, pods    |
```

**Animation:** Reveal the left stack bottom-up, then the right column.
**Speaker notes:** Two ideas on this slide. First, the dropdown is not what keeps people safe. Anyone can call the template directly with a value the dropdown never showed, so the form is a convenience. The protection is in the layers under it: the profile name maps to exactly one approved file, a person reviews the PR, and Helm and admission check the result. Second, "done" in Backstage only means a PR exists. Merged means Git says what should run. Only Argo CD and running pods show the developer got the change, which is why the task page links to both the PR and Argo CD. Guest sign-in and static catalog owners are lab shortcuts, not production authorization.

### Slide 42: demo 4, template to Git

**Layout:** Demo. **Duration:** 5:00.

```markdown
| Element   | Content                                                                     | Position | Style |
| --------- | --------------------------------------------------------------------------- | -------- | ----- |
| Label     | DEMO 4                                                                      | LABEL    | S     |
| Title     | One choice becomes one reviewed change                                      | CENTER   | TD    |
| Watch for | The profile parameter; the two steps; the output links; a profile-only diff | BADGE    | BD    |
```

**Animation:** Demo.
**Speaker notes:** Open 🏗️ **Platform** > **backstage** > **templates** > **ai-app** > **template.yaml** in the VS Code Explorer, show the parameter, steps, and output links, then show that the template change is just another platform PR. Learners do not write a Backstage action or register the catalog.

### Slide 43: your turn, complete and use the interface

**Layout:** Activity. **Duration:** 15:00.

```markdown
| Element | Content                                                                                         | Position | Style |
| ------- | ----------------------------------------------------------------------------------------------- | -------- | ----- |
| Label   | YOUR TURN · 15 MINUTES                                                                          | LABEL    | S     |
| Title   | Offer standard, then use it                                                                     | TITLE    | T     |
| Steps   | Edit the selector; merge and refresh; request standard; review and merge; check what is running | BODY     | A     |
| Guide   | Module 4 · Guided practice                                                                      | FOOTER   | B     |
```

**Animation:** Static.
**Speaker notes:** Announce the stop time.

### Slide 44: debrief, self-service or better intake?

**Layout:** Discussion. **Duration:** 5:00.

```markdown
| Element | Content                                                                                                             | Position | Style |
| ------- | ------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| Label   | DEBRIEF · 5 MINUTES                                                                                                 | LABEL    | S     |
| Title   | Remove or relocate?                                                                                                 | TITLE    | T     |
| Prompts | Did anyone else have to fulfill the change? Where does an unsupported request go? What evidence justifies standard? | BODY     | A     |
```

**Animation:** Static.
**Speaker notes:** A form that opens a ticket improves intake but keeps the handoff. This one finishes without a platform engineer, while keeping review, admission, and an exception route for anything the template does not offer.

### Slide 45: checkpoint, approved profile running

**Layout:** Checkpoint. **Duration:** 5:00.

```markdown
| Element | Content                                                                    | Position | Style |
| ------- | -------------------------------------------------------------------------- | -------- | ----- |
| Label   | CHECKPOINT · 5 MINUTES                                                     | LABEL    | S     |
| Title   | Same app, approved profile, healthy revision                               | TITLE    | T     |
| Ready   | Selector published; profile-only PR merged; concierge on standard requests | BODY     | A     |
| Pending | Rollout still in progress? Record it and keep the lab running.             | LABEL    | B     |
```

**Animation:** Static.
**Speaker notes:** Take questions.

### Slide 46: second break

**Layout:** Section Title, break. **Duration:** 10:00.

```markdown
| Element | Content                                  | Position | Style |
| ------- | ---------------------------------------- | -------- | ----- |
| Label   | BREAK                                    | LABEL    | S     |
| Title   | Take ten minutes                         | CENTER   | TD    |
| Badge   | Leave the lab running. Back at Module 5. | BADGE    | BD    |
```

**Animation:** Static.
**Speaker notes:** Announce the return time from the actual clock.

## Module 5: recover, inspect telemetry, and evaluate cost

**Slides 47-56. 02:55-03:40.** Source: [Module 5](../docs/5-operate-and-recover.md). Rhythm: 10 minutes explanation, 5 demo, 15 practice, 10 cost discussion, 5 checkpoint.

### Slide 47: Module 5 divider

**Layout:** Section Title, module. **Duration:** 0:15.

```markdown
| Element     | Content                                       | Position | Style |
| ----------- | --------------------------------------------- | -------- | ----- |
| Label       | MODULE 5                                      | LABEL    | S     |
| Title       | Recover, inspect telemetry, and evaluate cost | CENTER   | TD    |
| Fundamental | Guardrails with a recovery path               | BADGE    | P     |
```

**Animation:** Static.
**Speaker notes:** "The first deployment is the easy part. Now the day-two promise: see what the agent is doing and ship changes safely."

### Slide 48: why, see it and ship it safely

**Layout:** Promise tracker. **Duration:** 2:00.

```markdown
| Element   | Content                                           | Position     | Style     |
| --------- | ------------------------------------------------- | ------------ | --------- |
| Title     | See what the agent is doing. Ship changes safely. | TITLE        | T         |
| Tracker   | Eleven chips; one marked "this module" (below)    | BODY x5-68%  | See below |
| Not given | "Instead of" pair (below)                         | BODY x72-95% | See below |
```

Tracker chip marked **this module**: Application Insights on the shared workspace. All other chips show as delivered or prepared.
Not-given column:

```markdown
| Not given (struck through) | Instead                                   |
| -------------------------- | ----------------------------------------- |
| A dashboard                | Search on the team's Application Insights |
```

**Animation:** Static.
**Speaker notes:** One shared observability backend serves every team: essential toil that amortizes. A per-team Grafana would be incidental toil. An opaque rejection just moves troubleshooting to another team, so a guardrail must name what was blocked and the supported fix.

### Slide 49: what you'll do in Module 5

**Layout:** What you'll do. **Duration:** 1:45.

```markdown
| Element   | Content                               | Position     | Style     |
| --------- | ------------------------------------- | ------------ | --------- |
| Title     | What you'll do in Module 5            | TITLE        | T         |
| Steps     | Five step cards in two groups (below) | BODY y21-52% | See below |
| Done when | Checklist strip (below)               | BODY y56-70% | B         |
| Point     | Git is the only way back              | LABEL        | P         |
```

Step cards, with a bracket over cards 1-4 labeled "Break it safely, recover through Git" and over card 5 labeled "Decide":

```markdown
| #   | Card text               | Tag       |
| --- | ----------------------- | --------- |
| 1   | Merge image.tag: latest | PR        |
| 2   | Read the rejection      | Verify    |
| 3   | Restore the locked tag  | PR        |
| 4   | Confirm it converged    | Verify    |
| 5   | Make one cost decision  | Worksheet |
```

Done-when checklist: The app stayed up. The Git fix converged. One qualified cost decision is recorded.
**Animation:** Reveal by group.
**Speaker notes:** Learners do not change the policy or patch a live Deployment. Git is the only way back. The first box matters most: a rejected update should leave the running app untouched.

### Slide 50: a rejected update is not an outage

**Layout:** Two Content. **Duration:** 2:00.

```markdown
| Element | Content                                                       | Position | Style |
| ------- | ------------------------------------------------------------- | -------- | ----- |
| Title   | A rejected update is not an outage                            | TITLE    | T     |
| Sync    | Sync: does the cluster match Git? OutOfSync                   | LEFT     | H     |
| Health  | Health: is what's running working? Healthy                    | RIGHT    | H     |
| Retries | Argo CD retries for about 5 minutes. Your fix waits for them. | LABEL    | P     |
```

**Animation:** Compare.
**Speaker notes:** AKS Deployment Safeguards rejects the mutable tag before anything is replaced, so the old pods keep serving. A Helm schema rejection, an admission denial, and an image-pull failure are different failures with different fixes; record which one happened. Retry limits are a platform decision: more retries ride out transient errors, fewer let a fix land sooner.

### Slide 51: logs and traces answer different questions

**Layout:** Two Content. **Duration:** 2:00.

```markdown
| Element | Content                                                                | Position | Style |
| ------- | ---------------------------------------------------------------------- | -------- | ----- |
| Title   | Logs and traces answer different questions                             | TITLE    | T     |
| Logs    | kubectl logs: what the process printed; the request arrived            | LEFT     | H     |
| Traces  | Application Insights: what the request did; whether the model answered | RIGHT    | H     |
| Caveat  | Your successful query does not prove who else can read it.             | LABEL    | P     |
```

**Animation:** Compare.
**Speaker notes:** This lab does not build a telemetry access boundary: no restricted viewer, no test that another team is blocked. Filtering a dashboard is not authorization. That is a named later milestone, not a gap to hide.

### Slide 52: four controls, four questions

**Layout:** Title and Content. **Duration:** 2:00.

```markdown
| Element | Content                                                 | Position     | Style     |
| ------- | ------------------------------------------------------- | ------------ | --------- |
| Title   | Four controls, four different questions                 | TITLE        | T         |
| Grid    | Four cells in a 2x2 grid (below)                        | BODY y21-66% | See below |
| Caveat  | Model tokens are billed separately from CPU and memory. | LABEL        | P         |
```

Each cell: the question in H as the cell's headline, the control in S above it, and the scope in L below it.

```markdown
| Control             | Question it answers                         | Scope           |
| ------------------- | ------------------------------------------- | --------------- |
| Requests and limits | How is each container scheduled and capped? | Per container   |
| Namespace quota     | How much can the whole team use?            | Per namespace   |
| Cost allocation     | Who is charged?                             | Cost Management |
| Budget              | Who is alerted? It does not stop the app.   | Cost Management |
```

**Animation:** Reveal, one cell per click.
**Speaker notes:** None substitutes for another. The top row is Kubernetes; the bottom row is money. Changing a profile changes scheduling assumptions; whether it changes the bill depends on capacity and billing behavior. Set up the cost discussion: the decision must name what evidence supports it.

### Slide 53: demo 5, current telemetry

**Layout:** Demo. **Duration:** 5:00.

```markdown
| Element   | Content                                                                     | Position | Style |
| --------- | --------------------------------------------------------------------------- | -------- | ----- |
| Label     | DEMO 5                                                                      | LABEL    | S     |
| Title     | Inspect current telemetry, not a stale trace                                | CENTER   | TD    |
| Watch for | A fresh chat; its log line; a correlated model-call row newer than the chat | BADGE    | BD    |
```

**Animation:** Demo.
**Speaker notes:** Run `kubectl logs` with `--prefix`, point out that most lines are `/healthz` probes, then find the `POST /api/chat` line. Rerun the Module 3 query for a newer row. If ingestion is slow, mark it pending.

### Slide 54: your turn, reject and recover

**Layout:** Activity. **Duration:** 15:00.

```markdown
| Element | Content                                                                      | Position | Style |
| ------- | ---------------------------------------------------------------------------- | -------- | ----- |
| Label   | YOUR TURN · 15 MINUTES                                                       | LABEL    | S     |
| Title   | Break it safely, then recover through Git                                    | TITLE    | T     |
| Steps   | Merge latest; read the failure; restore the locked tag; confirm it converged | BODY     | A     |
| Guide   | Module 5 · Guided practice                                                   | FOOTER   | B     |
```

**Animation:** Static.
**Speaker notes:** Announce the stop time. Remind learners that recovery includes the retry window.

### Slide 55: discuss, make one cost decision

**Layout:** Discussion. **Duration:** 10:00.

```markdown
| Element | Content                                                  | Position | Style     |
| ------- | -------------------------------------------------------- | -------- | --------- |
| Label   | DISCUSS · 10 MINUTES                                     | LABEL    | S         |
| Title   | Is standard worth it? Decide from evidence.              | TITLE    | T         |
| Left    | "What you have" and "What you don't have" (below)        | LEFT     | See below |
| Right   | "Record in your worksheet", three numbered boxes (below) | RIGHT    | A         |
| Guide   | Module 5 · evidence/profile-comparison.md                | FOOTER   | B         |
```

Left column, two short lists:

```markdown
| Heading             | Items                                                                           |
| ------------------- | ------------------------------------------------------------------------------- |
| What you have       | Configured profile totals. The namespace quota. A rollout briefly doubles pods. |
| What you don't have | Measured usage. A billing export.                                               |
```

Right column, three numbered boxes:

```markdown
| #   | Record                                             |
| --- | -------------------------------------------------- |
| 1   | Your profile pick, or "evidence is insufficient"   |
| 2   | One measurement you'd need before claiming savings |
| 3   | Who responds to a cost alert for this app          |
```

**Animation:** Static.
**Speaker notes:** Frame the question plainly: Module 4 moved concierge to the standard profile. Was that the right size, and would it change the bill? Open 📁 **Lab Root** > **evidence** > **profile-comparison.md** in the VS Code Explorer: it is calculated from the profile files, not measured, so it shows what was configured, not what the app needs. Run the quota check: usage now matches the standard totals. During a rollout every Deployment briefly runs two pods, which puts CPU requests near the quota, so arithmetic alone does not prove a rollout fits. On the bill: a smaller request changes scheduling and allocation, not necessarily the number of nodes, and model tokens are priced separately. "Evidence is insufficient" is a good answer if it names the measurement that would settle it. Do not submit another profile change.

### Slide 56: checkpoint, recovered and decided

**Layout:** Checkpoint. **Duration:** 5:00.

```markdown
| Element | Content                                                                        | Position | Style |
| ------- | ------------------------------------------------------------------------------ | -------- | ----- |
| Label   | CHECKPOINT · 5 MINUTES                                                         | LABEL    | S     |
| Title   | Corrected intent and a defensible decision                                     | TITLE    | T     |
| Ready   | Rejection recorded; locked tag restored; Synced and Healthy; one cost decision | BODY     | A     |
| Pending | Still retrying? Record it as pending recovery, not a pass.                     | LABEL    | B     |
```

**Animation:** Static.
**Speaker notes:** Take questions.

## Module 6: plan the next platform milestone

**Slides 57-61. 03:40-03:58.** Source: [Module 6](../docs/6-next-milestone.md). Rhythm: 5 minutes explanation, 10 product exercise, 3 sharing. The summary uses the last 2 minutes of the module's sharing time.

### Slide 57: Module 6 divider

**Layout:** Section Title, module. **Duration:** 0:15.

```markdown
| Element     | Content                          | Position | Style |
| ----------- | -------------------------------- | -------- | ----- |
| Label       | MODULE 6                         | LABEL    | S     |
| Title       | Plan the next platform milestone | CENTER   | TD    |
| Fundamental | Evidence and feedback            | BADGE    | P     |
```

**Animation:** Static.
**Speaker notes:** "A platform is never done. The next investment should follow friction you observed, not the next tool on a list."

### Slide 58: improve the outcome, not the tool count

**Layout:** Two Content. **Duration:** 2:30.

```markdown
| Element | Content                                                                        | Position | Style     |
| ------- | ------------------------------------------------------------------------------ | -------- | --------- |
| Title   | Improve the outcome, not the tool count                                        | TITLE    | T         |
| Left    | Observation and hypothesis as two speech cards (below)                         | LEFT     | See below |
| Right   | "Before you compare" checklist (below)                                         | RIGHT    | B         |
| Test    | Remove or relocate? A change that needs unplanned upkeep has not removed toil. | LABEL    | P         |
```

Left, two cards with an arrow between them:

```markdown
| Card        | Text                                                            |
| ----------- | --------------------------------------------------------------- |
| Observation | "I needed help finding the failed revision."                    |
| Hypothesis  | "Showing it in the template output would reduce help requests." |
```

Right, heading "Before you compare", four checkboxes: Start event. Finish event. Who is included. Where the data comes from. Under them in L: "Count blocked and assisted attempts too."
**Animation:** Compare.
**Speaker notes:** Use the worksheet evidence from Modules 2 to 5. A clearer rejection message or better fulfillment status may help more than another portal plugin. The arrow from observation to hypothesis is the step most proposals skip. Neither this workshop nor one participant proves production demand. Slide 11's "later" list is a menu, not a roadmap: production promotion, an AI gateway, and full onboarding are each only worth doing if evidence points there.

### Slide 59: where DORA fits

**Layout:** Two Content. **Duration:** 2:15.

```markdown
| Element | Content                                                                  | Position | Style     |
| ------- | ------------------------------------------------------------------------ | -------- | --------- |
| Title   | DORA tells you if delivery improved. Task measures tell you what to fix. | TITLE    | T         |
| Left    | DORA's five delivery metrics in two groups (below)                       | LEFT     | See below |
| Right   | Today's platform task measures (below)                                   | RIGHT    | See below |
| Point   | Track both. Neither replaces the other.                                  | LABEL    | P         |
```

Left, heading "DORA: per app, in production, over time", two stacked groups of chips:

```markdown
| Group       | Chips                                                                   |
| ----------- | ----------------------------------------------------------------------- |
| Throughput  | Change lead time. Deployment frequency. Failed deployment recovery time |
| Instability | Change fail rate. Deployment rework rate                                |
```

Right, heading "Platform task measures: per developer task", four chips, each with the module where learners saw it:

```markdown
| Chip                              | Seen in     |
| --------------------------------- | ----------- |
| Environment fulfillment time      | Module 2    |
| Self-service task time            | Module 4    |
| Manual handoffs                   | Modules 2-4 |
| Time to correct a rejected change | Module 5    |
```

Between the columns, a thin arrow from right to left labeled "can move", not "equals".
**Animation:** Compare.
**Speaker notes:** DORA's current guidance names five software delivery metrics: change lead time, deployment frequency, and failed deployment recovery time for throughput; change fail rate and deployment rework rate for instability. They describe one application or service in production over time, not a person and not a platform. Today's lab measures are not automatically DORA measures: an environment request is not necessarily a production deployment, and an admission rejection before production is not a production change failure. Platform task measures are what a platform team can change directly, and they may move DORA outcomes for the apps on the platform. DORA's 2024 research associated platform use with higher productivity but also lower throughput and stability; the 2025 report looked at platform quality instead. Both are observational, so measure your own baseline before and after rather than assuming the platform helps. Avoid turning any single metric into a target or ranking teams against each other. Source: dora.dev/guides/dora-metrics.

### Slide 60: your turn, choose one next milestone

**Layout:** Activity. **Duration:** 10:00.

```markdown
| Element | Content                                                                                                   | Position | Style |
| ------- | --------------------------------------------------------------------------------------------------------- | -------- | ----- |
| Label   | YOUR TURN · 10 MINUTES                                                                                    | LABEL    | S     |
| Title   | Choose one next investment                                                                                | TITLE    | T     |
| Steps   | One observed friction; a bounded change and owner; one measure and baseline method; a feedback checkpoint | BODY     | A     |
| Guide   | Module 6 · answers/product-brief.md                                                                       | FOOTER   | B     |
```

**Animation:** Static.
**Speaker notes:** One problem, not a backlog. No invented target percentages.

### Slide 61: share, what would change your mind?

**Layout:** Discussion. **Duration:** 3:00.

```markdown
| Element | Content                                                                     | Position | Style |
| ------- | --------------------------------------------------------------------------- | -------- | ----- |
| Label   | SHARE · 3 MINUTES                                                           | LABEL    | S     |
| Title   | What would you try, and what would change your mind?                        | TITLE    | T     |
| Prompt  | Does it remove developer work, reduce waiting, or clarify a responsibility? | BODY     | A     |
```

**Animation:** Static.
**Speaker notes:** Take two or three statements. Push each one through the remove-or-relocate test.

## Summary

**Slides 62-65. 03:58-04:00.** Source: [Summary](../docs/7-summary.md).

### Slide 62: summary divider

**Layout:** Section Title, module. **Duration:** 0:15.

```markdown
| Element | Content                | Position | Style |
| ------- | ---------------------- | -------- | ----- |
| Label   | SUMMARY                | LABEL    | S     |
| Title   | The promise, revisited | CENTER   | TD    |
```

**Animation:** Static.
**Speaker notes:** None.

### Slide 63: the promise, revisited

**Layout:** Promise tracker. **Duration:** 0:45.

```markdown
| Element   | Content                                       | Position     | Style     |
| --------- | --------------------------------------------- | ------------ | --------- |
| Title     | What the team got, through pull requests      | TITLE        | T         |
| Tracker   | All eleven chips marked delivered or prepared | BODY x5-68%  | See below |
| Not given | "Instead of" pairs, all five (below)          | BODY x72-95% | See below |
```

Tracker: every chip teal, with the deploy repo tagged "prepared".
Not-given column, one pair per row:

```markdown
| Not given (struck through) | Instead                         |
| -------------------------- | ------------------------------- |
| A cluster                  | A namespace on a shared cluster |
| An admin kubeconfig        | Namespace-scoped access         |
| A model deployment         | A grant on the shared model     |
| A dashboard                | Search on Application Insights  |
| A client secret            | Workload identity               |
```

**Animation:** Static.
**Speaker notes:** Every item came through a reviewed change. Then name the limits: one development environment, no AI gateway, guest Backstage access, no telemetry access boundary. Those are the boundaries of today's promise, not failures of it.

### Slide 64: take it to your platform

**Layout:** Title and Content. **Duration:** 0:45.

```markdown
| Element | Content                                                                                                                                                   | Position | Style |
| ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| Title   | Three things to try on Monday                                                                                                                             | TITLE    | T     |
| Actions | Write the promise for your most-requested manual task; define the few fields a developer must supply; ask "remove or relocate?" of your next roadmap item | BODY     | H     |
```

**Animation:** Static.
**Speaker notes:** The full fundamentals table is in the summary page of the guide.

### Slide 65: close

**Layout:** Title Slide, closing. **Duration:** 0:15.

```markdown
| Element  | Content                                                                   | Position | Style |
| -------- | ------------------------------------------------------------------------- | -------- | ----- |
| Title    | Remove the toil, not just move it.                                        | TITLE    | T     |
| Subtitle | Save answers/product-brief.md. Try the optional next environment at home. | SUBTITLE | H     |
```

**Animation:** Static.
**Speaker notes:** Organizers handle service shutdown and Azure cleanup; learners should not delete namespaces or state by hand. Use the prepared Skillable transfer to save the non-sensitive worksheet. Finish at 04:00.

## Optional: vend the next environment

**Slides 66-67. Take-home, not presented in the timed session.** Source: [Optional exercise](../docs/8-optional-next-environment.md). Use these slides in self-paced or recorded versions, or keep them after the close as reference.

### Slide 66: optional divider

**Layout:** Section Title, module. **Duration:** Untimed.

```markdown
| Element     | Content                                  | Position | Style |
| ----------- | ---------------------------------------- | -------- | ----- |
| Label       | OPTIONAL · ABOUT 25 MINUTES              | LABEL    | S     |
| Title       | Vend the next environment from Backstage | CENTER   | TD    |
| Fundamental | A golden path is the path you can repeat | BADGE    | P     |
```

**Animation:** Static.
**Speaker notes:** None.

### Slide 67: the second environment is the real test

**Layout:** Two Content. **Duration:** Untimed.

```markdown
| Element | Content                                                                          | Position | Style |
| ------- | -------------------------------------------------------------------------------- | -------- | ----- |
| Title   | The second environment is the real test                                          | TITLE    | T     |
| First   | beans-dev, by hand: a contract change; a request file; a binding lookup; two PRs | LEFT     | B     |
| Next    | beans-prod, from one form: two PRs opened for you; two reviews                   | RIGHT    | B     |
| Point   | The difference is the toil the platform removed.                                 | LABEL    | P     |
```

**Animation:** Compare.
**Speaker notes:** The form never asks for a client ID, model or OTLP endpoint, DCR ID, chart, or image. Backstage opens both PRs; it merges neither. In this lab `beans-prod` uses the same `ai-dev` class and image; a real production class would add stricter policy, approvals, or a separate cluster. This is the twentieth-team argument from slide 10 made concrete.

## Slide flow and timing summary

All times are proposed elapsed workshop time and remain pending rehearsal. The speaker's actual start time sets the return time announced at breaks.

```markdown
| Slides | Phase                               | Duration | Elapsed     |
| ------ | ----------------------------------- | -------- | ----------- |
| 1-4    | Opening                             | 3:00     | 00:00-00:03 |
| 5-12   | M1 divider, why, and what you'll do | 12:00    | 00:03-00:15 |
| 13     | M1 demo                             | 5:00     | 00:15-00:20 |
| 14     | M1 product exercise                 | 10:00    | 00:20-00:30 |
| 15     | M1 discussion                       | 5:00     | 00:30-00:35 |
| 16-21  | M2 explanation and guided wiring    | 10:00    | 00:35-00:45 |
| 22     | M2 demo                             | 5:00     | 00:45-00:50 |
| 23     | M2 practice                         | 15:00    | 00:50-01:05 |
| 24     | M2 debrief                          | 5:00     | 01:05-01:10 |
| 25     | M2 checkpoint                       | 5:00     | 01:10-01:15 |
| 26     | Break                               | 10:00    | 01:15-01:25 |
| 27-32  | M3 explanation                      | 10:00    | 01:25-01:35 |
| 33     | M3 demo                             | 5:00     | 01:35-01:40 |
| 34     | M3 practice                         | 15:00    | 01:40-01:55 |
| 35     | M3 debrief                          | 5:00     | 01:55-02:00 |
| 36     | M3 checkpoint                       | 5:00     | 02:00-02:05 |
| 37-41  | M4 explanation                      | 10:00    | 02:05-02:15 |
| 42     | M4 demo                             | 5:00     | 02:15-02:20 |
| 43     | M4 practice                         | 15:00    | 02:20-02:35 |
| 44     | M4 debrief                          | 5:00     | 02:35-02:40 |
| 45     | M4 checkpoint                       | 5:00     | 02:40-02:45 |
| 46     | Break                               | 10:00    | 02:45-02:55 |
| 47-52  | M5 explanation                      | 10:00    | 02:55-03:05 |
| 53     | M5 demo                             | 5:00     | 03:05-03:10 |
| 54     | M5 practice                         | 15:00    | 03:10-03:25 |
| 55     | M5 cost discussion                  | 10:00    | 03:25-03:35 |
| 56     | M5 checkpoint                       | 5:00     | 03:35-03:40 |
| 57-59  | M6 explanation                      | 5:00     | 03:40-03:45 |
| 60     | M6 product exercise                 | 10:00    | 03:45-03:55 |
| 61     | M6 sharing                          | 3:00     | 03:55-03:58 |
| 62-65  | Summary and close                   | 2:00     | 03:58-04:00 |
| 66-67  | Optional next environment           | Untimed  | Take-home   |
```

Module 1's 15 minutes of explanation includes the 3-minute opening, matching the guide's 00:00-00:35 allocation.

### Slide-by-slide cue sheet

```markdown
| #   | Cue                                          | Type            | Duration |
| --- | -------------------------------------------- | --------------- | -------- |
| 1   | Title                                        | Opening         | 0:45     |
| 2   | Today's path                                 | Opening         | 0:45     |
| 3   | The lab at a glance                          | Opening         | 0:45     |
| 4   | Meet Fourth Coffee                           | Opening         | 0:45     |
| 5   | Module 1 divider                             | Divider         | 0:15     |
| 6   | Five things before business logic            | Explanation     | 1:30     |
| 7   | Without a platform                           | Explanation     | 1:30     |
| 8   | The promise                                  | Explanation     | 1:30     |
| 9   | Team gets, team does not get                 | Explanation     | 2:30     |
| 10  | Toil shifts to platform teams                | Explanation     | 2:30     |
| 11  | Today's thin slice                           | Explanation     | 1:00     |
| 12  | What you'll do in Module 1                   | What you'll do  | 1:15     |
| 13  | Demo 1                                       | Demo            | 5:00     |
| 14  | Define the promise                           | Your turn       | 10:00    |
| 15  | Choice, default, control, exception          | Discussion      | 5:00     |
| 16  | Module 2 divider                             | Divider         | 0:15     |
| 17  | One request instead of five tickets          | Why             | 1:30     |
| 18  | What you'll do in Module 2                   | What you'll do  | 1:30     |
| 19  | The request carries intent                   | Explanation     | 2:15     |
| 20  | Crossplane owns the API, OpenTofu owns Azure | Explanation     | 2:15     |
| 21  | Two distinctions                             | Explanation     | 2:15     |
| 22  | Demo 2                                       | Demo            | 5:00     |
| 23  | Require attribution and vend                 | Your turn       | 15:00    |
| 24  | Remove or relocate? The wait                 | Debrief         | 5:00     |
| 25  | Environment ready                            | Checkpoint      | 5:00     |
| 26  | First break                                  | Break           | 10:00    |
| 27  | Module 3 divider                             | Divider         | 0:15     |
| 28  | No client secret, no model key               | Why             | 1:45     |
| 29  | What you'll do in Module 3                   | What you'll do  | 1:30     |
| 30  | The platform publishes the binding           | Explanation     | 2:15     |
| 31  | Identity is not configuration                | Explanation     | 2:15     |
| 32  | A plausible answer is not evidence           | Explanation     | 2:00     |
| 33  | Demo 3                                       | Demo            | 5:00     |
| 34  | Bind and deploy                              | Your turn       | 15:00    |
| 35  | Remove or relocate? Assembly                 | Debrief         | 5:00     |
| 36  | Working app, model evidence                  | Checkpoint      | 5:00     |
| 37  | Module 4 divider                             | Divider         | 0:15     |
| 38  | A golden path people can find                | Why             | 2:00     |
| 39  | What you'll do in Module 4                   | What you'll do  | 1:45     |
| 40  | A decision, not numbers                      | Explanation     | 3:00     |
| 41  | The form guides, the checks protect          | Explanation     | 3:00     |
| 42  | Demo 4                                       | Demo            | 5:00     |
| 43  | Offer standard, then use it                  | Your turn       | 15:00    |
| 44  | Remove or relocate? Intake                   | Debrief         | 5:00     |
| 45  | Approved profile running                     | Checkpoint      | 5:00     |
| 46  | Second break                                 | Break           | 10:00    |
| 47  | Module 5 divider                             | Divider         | 0:15     |
| 48  | See it and ship it safely                    | Why             | 2:00     |
| 49  | What you'll do in Module 5                   | What you'll do  | 1:45     |
| 50  | Rejected is not an outage                    | Explanation     | 2:00     |
| 51  | Logs versus traces                           | Explanation     | 2:00     |
| 52  | Four controls                                | Explanation     | 2:00     |
| 53  | Demo 5                                       | Demo            | 5:00     |
| 54  | Reject and recover                           | Your turn       | 15:00    |
| 55  | Is standard worth it?                        | Discussion      | 10:00    |
| 56  | Recovered and decided                        | Checkpoint      | 5:00     |
| 57  | Module 6 divider                             | Divider         | 0:15     |
| 58  | Improve the outcome                          | Explanation     | 2:30     |
| 59  | Where DORA fits                              | Explanation     | 2:15     |
| 60  | Choose one next investment                   | Your turn       | 10:00    |
| 61  | What would change your mind?                 | Discussion      | 3:00     |
| 62  | Summary divider                              | Divider         | 0:15     |
| 63  | The promise, revisited                       | Promise tracker | 0:45     |
| 64  | Three things to try on Monday                | Explanation     | 0:45     |
| 65  | Close                                        | Closing         | 0:15     |
| 66  | Optional divider                             | Divider         | Untimed  |
| 67  | The second environment                       | Explanation     | Untimed  |
```

## Speaker preparation and contingency

### Prepare before delivery

Rehearse Module 2's guided wiring alongside slides 19 to 21 in a fresh lab, and confirm the 10-minute allocation. Keep the separate instructor environment complete through Module 5 so each demo shows a finished path. Prepare the catalog refresh path, the model-call query, the profile comparison, and the worksheet transfer instructions.
Prepare one sanitized recorded fallback per demo:

```markdown
| Demo | Fallback shows                                                               | Do not imply                                    |
| ---- | ---------------------------------------------------------------------------- | ----------------------------------------------- |
| 1    | Supported choice, generated PR, completed revision, owner and recovery links | A pending live request already succeeded        |
| 2    | Schema requirement, rejected request, completed request trace and baseline   | New provisioning always fits the demo window    |
| 3    | Binding, deployed revision, correlated successful model call                 | A historical trace proves the fresh interaction |
| 5    | Refreshed selector, profile-only diff, completed rollout                     | Task submission alone completed deployment      |
| 6    | Fresh chat, prefixed log line, correlated model-call row                     | The builder's query proves access isolation     |
```

### When a demo or exercise is blocked

Name the failed or pending stage. Use a clearly labeled recorded fallback to teach the concept, then return to the planned phase. Do not broaden permissions, bypass checks, or manually create resources. Proctors use the guide's [troubleshooting appendix](../docs/appendix-a-troubleshooting.md).
If a rehearsal shows that the exercises cannot fit, bring the timing problem back for a scope decision. Do not silently cut an objective, a debrief, or a break.

### Audience assumptions

Learners recognize namespaces, Deployments, Services, YAML, and Git commits. They do not need Crossplane, OpenTofu, Argo CD, or Backstage experience. Keep full manifests and policy expressions in the guide; speaker notes explain decisions, not implementation line by line.

## Production notes

Build the deck on the official Ignite template following the [design system](PREL37-design-system.md), with editable PowerPoint text and shapes. Put speaker notes from this specification in the Notes pane. When slide content changes, update this specification and the deck together.
Use PowerPoint sections that match the nine section names in [Deck structure](#deck-structure), so the slide sorter shows the workshop modules.
Review every slide from projected-room distance. Keep essential content above the caption-safe bottom 15%. Use meaningful reading order and alt text. No slide requires a photo, customer quote, price, or QR code. Add the published guide URL to the closing slide once the repository is public.
