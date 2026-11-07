# Module 5: recover, inspect telemetry, and evaluate cost

[Workshop overview](README.md) | [Previous: self-service interface](4-self-service.md) | [Next: next milestone](6-next-milestone.md)

**Duration:** 45 minutes, 02:55-03:40.
**Rhythm:** 10 minutes explanation, 5 monitoring demonstration, 15 guided recovery practice, 10 cost/debrief discussion, 5 catch-up/questions.

## Objectives

By the end of this module, you will be able to:

- Find the reason for a rejected deployment and correct the desired state through Git.
- Explain what current container logs and application traces show, and why they do not prove authorization isolation.
- Make one resource-profile decision without confusing quota, allocated costs, and monetary budgets.

> **Platform concept: guardrails with a recovery path.** A guardrail is only useful if the developer it stops can see why and fix it without filing a ticket. In the BACK stack, **Kubernetes** admission (AKS Deployment Safeguards) blocks the unsafe change, **Argo CD** shows the reason, and Git is the only way back.

> **AKS in action: secure by default.** You do not install the policy that rejects `latest`. AKS Automatic enforces [Deployment Safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards) and baseline Pod Security Standards through Azure Policy from the moment the cluster exists, and [automatic upgrades](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster) keep the cluster and node images patched without a platform ticket. The platform team builds its recovery path on guardrails it does not have to operate. Cluster telemetry comes the same way: Container Insights and managed Prometheus are on, alongside the application traces you query here. See [why AKS is the foundation](1b-aks-foundation.md#aks-standard-and-aks-automatic).

**Starting state:** Module 4's `standard` profile is delivered and all three Deployments are ready. Confirm with:

```bash
kubectl --context "$CONTROL_CONTEXT" -n argocd get application "$APP_NAME" -o custom-columns=SYNC:.status.sync.status,HEALTH:.status.health.status
```

**Expected result:** `Synced` and `Healthy`. If not, finish [Module 4, step 6](4-self-service.md#6-confirm-argo-cd-delivered-the-change) first.

## Why guardrails need a recovery path

An opaque "Access Denied" or a generic "Internal Server Error" does not remove work. It moves the troubleshooting from the developer to the platform team and creates the very tickets the platform was meant to eliminate.

A useful guardrail tells the developer three things:

1. **What was blocked?** (e.g., "The update to the `concierge` deployment was rejected.")
2. **Which specific field caused the failure?** (e.g., "The `image.tag` field was set to `latest`.")
3. **What is the supported value?** (e.g., "Please use a specific, immutable image digest or version tag.")

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

> **Tip:** when a developer asks for "more resources," first ask whether they are hitting a container limit (performance) or the namespace quota (capacity). The fixes are different.

## Demonstrate: inspect current application telemetry

**5 minutes. Instructor-led.**

The instructor makes a fresh synthetic chat in the app and shows two views. Self-paced learners can run both against their own app.

**Container logs** show what each process printed:

```bash
kubectl --context "$AKS_CONTEXT" -n "$TEAM" logs -l app.kubernetes.io/part-of="$APP_NAME" --all-containers=true --prefix --tail=20
```

`--prefix` labels each line with its pod and container. Most lines are `/healthz` probes; a `POST /api/chat` line shows the request arrived, not that the model answered.

**Traces** show what the request did. Rerun the model-call query from [Module 3, step 7](3-application-delivery.md#7-verify-a-fresh-model-interaction) and find a row newer than the chat with `ModelSuccess` of `True`.

**Expected result:** a current log line for the chat and a correlated model-call row. If the row is missing, record it as pending; ingestion takes a few minutes. This shows operating information, not an access boundary.

## Guided practice: reject and recover one change

**15 minutes.**

### 1. Make the unsafe change

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

In VS Code, open `apps/fourth-coffee/values.yaml` (**App-Deploy** folder) to see the change in context. `image.tag` is the only line you touched.

### 2. Merge it and let Argo CD try

```bash
git add "apps/$APP_NAME/values.yaml"
git commit -m "test: use the latest image tag"
git push -u origin try-latest-tag
gh pr create --fill
gh pr diff --name-only
gh pr merge --merge --delete-branch
```

**Expected result:** `gh pr diff --name-only` lists only `apps/fourth-coffee/values.yaml`, and the PR merges. If a branch check blocks the merge, don't disable it. That check is another enforcement point; note it and see [failure/recovery troubleshooting](appendix-a-troubleshooting.md#the-seeded-failure-does-not-match-or-recovery-is-stuck).
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

**Expected result:** one line each for `concierge`, `ops-agent`, and `fourth-coffee-mcp`, each containing `admission webhook "validation.gatekeeper.sh" denied the request`, a rule named `azurepolicy-k8sazurev2containernolatestima-...`, and `Avoiding the latest tag for container`. That is the AKS Deployment Safeguards rule against `latest` images. An image-pull error or a different rule name means something else went wrong; see [failure/recovery troubleshooting](appendix-a-troubleshooting.md#the-seeded-failure-does-not-match-or-recovery-is-stuck).

The same message appears in the Argo CD UI at `https://localhost:8443`: open `fourth-coffee` and select the sync status.

**Is the app still up?**

```bash
kubectl --context "$AKS_CONTEXT" -n "$TEAM" get deployments \
  -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'
```

**Expected result:** all three are ready and still run `ghcr.io/pauldotyu/fourth-coffee@sha256:...`, the digest-pinned image. `http://beans.localhost:8080` still works. A bad change was blocked, and nothing went down.

In the worksheet, record the rule name, the field that caused it (`image.tag` in `values.yaml`), and the fix: restore the locked tag through Git.

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

**Expected result:** `Approved tag:` followed by the verified tag in `config/artifact-lock.json`, and the diff changes one line from `tag: "latest"` back to that tag. If the lookup fails, the `sed` does not run and the diff is empty. Stop and ask for help; do not guess a tag.

Commit, review, and merge the fix:

```bash
git add "apps/$APP_NAME/values.yaml"
git commit -m "fix: restore the approved image tag"
git push -u origin restore-image-tag
gh pr create --fill
gh pr diff --name-only
gh pr merge --merge --delete-branch
```

### 5. Confirm the recovery converged

Refresh Argo CD and wait for it to sync. Allow up to 10 minutes: Argo CD first finishes retrying the bad commit (about five minutes), then applies your fix.

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

In VS Code, open `docs/recovery.md` (**Platform** folder). This is the runbook a developer finds when a change is blocked. Compare it with what you just did and note one improvement in the worksheet. For example: does it mention the retry wait you just sat through? Publishing a documentation PR is optional take-home work.

## Discuss: make one cost decision

**10 minutes. Instructor-facilitated. No calculator or billing setup is required.**

In VS Code, open `evidence/profile-comparison.md` (**Lab Root** folder). Start with provenance: this file is calculated from the profile files, not measured usage or a billing export.

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

Record both PR numbers and the actual rejection reason. If recovery is stuck past 10 minutes, use [failure/recovery troubleshooting](appendix-a-troubleshooting.md#the-seeded-failure-does-not-match-or-recovery-is-stuck).

**What you learned:** operating a capability means making failures, access boundaries, and cost trade-offs understandable without bypassing its controls.

---

[Previous: self-service interface](4-self-service.md) | [Next: plan the next platform milestone](6-next-milestone.md)
