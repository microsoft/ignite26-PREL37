# Module 4: complete the self-service interface

[Workshop overview](README.md) | [Previous: application delivery](3-application-delivery.md) | [Next: operate and recover](5-operate-and-recover.md)

**Duration:** 40 minutes, 02:05-02:45.
**Rhythm:** 10 minutes explanation, 5 demonstration, 15 guided practice, 5 debrief, 5 catch-up/questions.

## Objectives

By the end of this module, you will be able to:

- Explain the difference between a supported interface and an authorization boundary.
- Offer a developer a decision (a named profile) instead of implementation details (CPU and memory numbers).
- Use Backstage to change the running application through the same GitOps path you used in Module 3.

> **Platform concept: the self-service portal is a front door, not a second pipeline.** A developer portal makes a supported change easy to find and request. It does not get its own permissions or its own way to deploy. In the BACK stack, **Backstage** turns a form into a pull request, and **Argo CD** delivers the merged result exactly as it did in Module 3.

> **AKS in action: node autoprovisioning.** The standard profile doubles the agents' CPU and memory requests. Nobody files a ticket for bigger nodes: on the AKS Automatic workload cluster, [node autoprovisioning](https://learn.microsoft.com/azure/aks/node-auto-provisioning) adds right-sized capacity when existing nodes cannot fit the new requests. The developer chooses a profile; the platform's quota bounds it; AKS supplies the nodes. See [why AKS is the foundation](1b-aks-foundation.md#aks-standard-and-aks-automatic).

**Starting state:** Fourth Coffee runs in `beans` with the `small` profile. Backstage is running at `http://localhost:3000` and the Argo CD tunnel at `https://localhost:8443`. If either stopped, restart it with the [setup guide's resume path](../setup/README.md#resume-a-prepared-environment). This module does not create another repository, application, or namespace.

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

The platform team defines what these names mean in the platform repository (`profiles/workload-small.yaml` and `profiles/workload-standard.yaml`). Resource requests stay aligned with approved sizes, and developers cannot accidentally request more than the namespace quota allows.

### The front door and the pipeline

The portal is the _interface_, not the _implementation_.

- **The front door (Backstage):** handles discovery, intake, and user experience.
- **The pipeline (Git, Argo CD, AKS):** handles authorization, validation, and fulfillment.

Because the portal only writes to Git, the platform can layer its governance:

1. **Interface:** the dropdown (`enum`) limits the choices a developer sees.
2. **Review:** the pull request lets a person or a bot check the change.
3. **Admission:** Kubernetes admission controllers and Helm schemas validate the final YAML before it is applied.

A dropdown alone is not a control. Anyone with write access can skip the UI and commit an invalid value directly to Git. Placing the real controls in the pipeline keeps the platform safe even when the front door is bypassed. This is the difference between a supported interface and an authorization boundary.

### The full loop: from request to runtime

In a ticket-driven process, a closed ticket is the end of the story. In platform engineering, a change is not done until you observe it in the running environment.

A finished Backstage task means only that a PR was opened. A merged PR means only that the desired state changed. The loop closes when Argo CD reconciles the change and the pods restart with the new resources. Steps 5 to 7 walk each of those stages.

> **Tip:** Link the portal's success page to the delivery pipeline, as this template does with an Argo CD link. It shifts the developer's focus from "I submitted the form" to "my application is running with the new resources."

## Demonstrate: follow the template-to-Git path

**5 minutes. Instructor-led.**

The instructor opens `backstage/templates/ai-app/template.yaml` and shows the profile parameter, the two steps, and the two output links. Then they show that a template change is just another platform PR, and that Backstage reads the merged file from GitHub, not your local copy.

You do not write a Backstage action, register the catalog, or wire output links.

## Guided practice: complete one choice and use it

**15 minutes.**

### 1. Read the template you will change

In VS Code, open `backstage/templates/ai-app/template.yaml` in the **Platform** folder. Find the `profile` property under `parameters`, marked with a `Module 4` comment:

```yaml
profile:
  title: Resource profile
  type: string
  # Module 4: add standard and explain the supported choice.
  description: Choose the small profile.
  enum: [small]
  default: small
```

`enum` is the list the dropdown offers. `description` is the help text under the field. Further down, the `profile` step builds the file URL from the selected value, so adding a name to `enum` works only because `profiles/workload-standard.yaml` already exists. The platform defines the profile first; the template just exposes it. Read the file here, and make the change in the terminal in the next step.

### 2. Add the standard profile to the selector

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

A template change is a platform change, so it goes through a PR like any other. Commit only the template, then open, review, and merge the PR:

```bash
git add backstage/templates/ai-app/template.yaml
git commit -m "feat: offer the standard profile in Backstage"
git push -u origin add-standard-profile
gh pr create --fill
gh pr diff
gh pr merge --merge --delete-branch
```

**Expected result:** the PR diff shows the same two lines, and `gh` reports the PR merged with your clone back on `main`.

### 3. Refresh the published template in Backstage

Backstage reads the template from GitHub and re-checks it every few minutes. Refreshing makes it check now.

1. Open `http://localhost:3000/catalog/default/template/app-profile`. This is the **Resize an application** template. You can also reach it from **Catalog** by setting the **Kind** filter to **Template**.
2. On the **About** card, select **Refresh** (the circular arrow). Wait about 10 seconds.
3. On the same card, select **Launch Template**.
4. Open the **Resource profile** dropdown. Do not submit yet.

**Expected result:** the dropdown offers `small` and `standard`, with `small` selected, and the help text reads "Choose using demand evidence. Standard has higher app requests and memory limits; namespace quota is unchanged." If you still see "Choose the small profile.", wait a minute, reload the page, and select **Refresh** again. If it persists, use [Backstage troubleshooting](appendix-a-troubleshooting.md#backstage-shows-an-old-template-or-no-usable-result).

### 4. Request the standard profile

First, confirm which profile the app runs today. `profile.yaml` is an exact copy of one approved file and has no name field, so compare it with each. In your VS Code terminal, run:

```bash
cd "$LAB_ROOT/app-deploy"
git checkout main && git pull origin main
for p in small standard; do
  diff -q "apps/$APP_NAME/profile.yaml" "$LAB_ROOT/platform/profiles/workload-$p.yaml" >/dev/null && echo "current profile: $p"
done
```

**Expected result:** `current profile: small`. If it already says `standard`, a new request has nothing to change and Backstage opens no PR. Record that as a verified no-change result.

Back in the Backstage form:

1. **Application:** select `fourth-coffee`. After you pick it, the field shows the catalog reference `component:default/fourth-coffee`. The picker lists only Components your team owns.
2. **Resource profile:** select `standard`.
3. Select **Review**, check the two values, then select **Create**.

**Expected result:** within about 10 seconds, both steps (**Fetch the approved profile** and **Propose the profile change**) show as complete, and two buttons appear: **Review the pull request** and **Follow application delivery in Argo CD**. Backstage opened the PR from branch `backstage/fourth-coffee-profile-standard`. It did not merge it; that is your job as reviewer. This is the interface handing off to the pipeline.

### 5. Review and merge the generated PR

Review the PR from your terminal, the same way you review your own. A portal-generated change gets no special trust:

```bash
cd "$LAB_ROOT/app-deploy"
gh pr list
gh pr diff "backstage/$APP_NAME-profile-standard" --name-only
gh pr diff "backstage/$APP_NAME-profile-standard"
```

**Expected result:** `gh pr list` shows **Use the standard profile for fourth-coffee**. The only changed file is `apps/fourth-coffee/profile.yaml`. In it, `opsAgent` and `concierge` move from `200m, 256Mi` requests and a `768Mi` memory limit to `400m, 512Mi` requests and a `1536Mi` limit. `fourthCoffeeMcp` and `values.yaml` are untouched. If the PR changes any other file, do not merge it; ask for help.

Merge it, then confirm `main` matches the standard profile:

```bash
gh pr merge "backstage/$APP_NAME-profile-standard" --merge --delete-branch
git checkout main && git pull origin main
for p in small standard; do
  diff -q "apps/$APP_NAME/profile.yaml" "$LAB_ROOT/platform/profiles/workload-$p.yaml" >/dev/null && echo "current profile: $p"
done
```

**Expected result:** `current profile: standard`.

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

**Expected result:**

```text
NAME                READY   CPU_REQ   MEM_REQ   CPU_LIM   MEM_LIM
concierge           1       400m      512Mi     1         1536Mi
fourth-coffee-mcp   1       100m      128Mi     500m      256Mi
ops-agent           1       400m      512Mi     1         1536Mi
```

Kubernetes shows a `1000m` CPU limit as `1`. **What this means:** `concierge` and `ops-agent` run the standard values, `fourth-coffee-mcp` keeps its own settings, and the namespace quota is unchanged. The request made it all the way from a form to the running pods. If the larger requests did not fit on the existing nodes, node autoprovisioning added capacity during the rollout, with no node pool for anyone to resize.

The pods restarted, so start a new chat at `http://beans.localhost:8080` before you continue. If the page doesn't load, restart the gateway tunnel from [Module 3, step 6](3-application-delivery.md#6-open-the-application-through-the-gateway).

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

A successful Backstage task alone does not pass the checkpoint. If fulfillment is blocked, keep the task link and the PR and use [template troubleshooting](appendix-a-troubleshooting.md#backstage-shows-an-old-template-or-no-usable-result) rather than recreating anything.

**What you learned:** a self-service interface offers understandable choices and connects them to enforced, observable fulfillment.

## Break

**10 minutes, 02:45-02:55.** Reconciliation may continue. Do not use the break as mandatory lab time.

---

[Previous: application delivery](3-application-delivery.md) | [Next: recover, inspect telemetry, and evaluate cost](5-operate-and-recover.md)
