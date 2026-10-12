# Set up the workshop

Finish this guide before starting Module 1. Setup builds the foundation a platform team would normally own, so the modules can focus on the platform itself. When you finish, you will have two accessible clusters, personalized private repositories, the worksheet and exercises, healthy platform packages and Gateway, and working Backstage and Argo CD UIs.

Choose one preparation path, then complete the shared [Module 1 handoff](#finish-setup-and-open-module-1):

- **Assigned Skillable VM:** use [Skillable lab setup](#skillable-lab-setup). Azure is already provisioned; run `make machine-setup`, not `make setup`.
- **New Azure environment, automated:** use [fast-track setup](#fast-track-setup).
- **Step-by-step control:** use [manual setup](#manual-setup). It covers the same preparation as `setup/fast-track.sh`, with a separate branch for an already provisioned Skillable foundation.
- **Environment already prepared:** use [resume a prepared environment](#resume-a-prepared-environment).

All `make` commands run from the source checkout, normally `$HOME/repos/ignite26-PREL37`. Your generated learner workspace is a different directory, `$HOME/prel37`. Do not clone the source into the learner workspace or run both preparation paths on the same instance.

## Application artifact prerequisite

**Why it matters:** pinning the application to a released image digest and source revision is what makes later checks meaningful. The Module 5 recovery restores this exact image, and telemetry evidence depends on its export support.

The lab pins Fourth Coffee release `0.1.0-12.1.ge412f12` from [the application repository](https://github.com/pauldotyu/fourth-coffee/tree/969ca1acae851d0ef3cb60619d5e0d6e90523fda). Its image is `ghcr.io/pauldotyu/fourth-coffee:0.1.0-12.1.ge412f12`; the corresponding upstream chart is `oci://ghcr.io/pauldotyu/charts/fourth-coffee` at the same version. Both registry digests and the source revision are recorded in `setup/artifact-lock.json`. The source and [successful release CI run](https://github.com/pauldotyu/fourth-coffee/actions/runs/40125873202) include renewable native OTLP authentication.

The deployed chart is the lab's Git-pinned adapter at `src/platform/charts/fourth-coffee`, not a direct installation of the upstream OCI chart. It preserves digest-pinned images, the `latest` rejection fixture, ClusterIP services and the shared Gateway, and platform-owned ServiceAccounts. Unlike the upstream Azure profile, this lab does not give `fourth-coffee-mcp` an Azure identity: its SDK telemetry is disabled and its stdout remains available. Agent spans still show calls to its tools.

The release supports `OTEL_EXPORTER_OTLP_AUTH_MODE=workload_identity`, direct HTTPS signal URLs, the Application Insights routing attribute, and the required metrics settings supplied by the baseline. It does not require AKS `appMonitoring`, `Instrumentation`, or a collector pod. Attendees do not build an image or supply bearer tokens.

`application.nativeOtlpWorkloadIdentity=true` records the pinned release's capability, not a successful deployment in an assigned subscription. **Live rehearsal remains pending.** Before a delivery, organizers must verify the actual identity and DCR grants, a fresh correlated chat/model call in `OTelSpans`, and continued export after token renewal. Keep `rehearsal.status` pending until the live lab evidence exists.

For later releases, update the image tag/digest, source revision, upstream chart metadata, adapter defaults and schema, and `src/exercises/application/values.yaml` together. For an initialized VM, use [the Fourth Coffee migration](../docs/appendix-a-troubleshooting.md#switch-an-existing-lab-to-fourth-coffee) rather than recopying templates over learner work.

## Skillable lab setup

**Use `make machine-setup`, not `make setup`, in the assigned lab VM.** Organizers have already run the Terraform in `infra/` from `C:\terraform`. You prepare the Linux workspace, GitHub repositories, platform packages, and local tools without provisioning Azure infrastructure again.

### Organizer preparation

Before learners arrive:

- Run the current `infra/main.tf` as the authorized bootstrap identity against the assigned resource group and learner identity, including the constrained telemetry-publisher delegation. Finish a successful apply in the default local Terraform workspace at `C:\terraform`, leaving `C:\terraform\terraform.tfstate` with the current `lab` output. Learners do not need the bootstrap identity or its permissions.
- Prepare Ubuntu on WSL with Linux versions of `make`, `git`, `gh`, `az`, `terraform` (>=1.10, <2.0), `kubectl`, `kubelogin`, `node` (v24), `jq`, and `envsubst`. Install the Azure CLI `log-analytics` extension in WSL for Module 3. Prepare VS Code with WSL support. Windows executables alone do not satisfy this tool setup.
- Ensure WSL can reach Azure sign-in, both cluster APIs, GitHub, the package registries, and the Backstage dependency registry. Terraform installs Crossplane and the Argo CD extension; `make machine-setup` installs the supplied Crossplane provider/functions and shared Gateway, not another copy of those Terraform-owned controllers.
- Supply the assigned Azure and GitHub accounts. The GitHub account needs permission to create the two private repositories and fine-grained tokens described below. Decide whether this source repository is pre-cloned in WSL or learners clone it at the start.

The Windows directory must contain the **bootstrap** state, not the controller-owned managed-namespace state. Keep state and credentials out of Git. Skillable owns the Azure lifecycle and teardown; learners should not run `make teardown`.

### Open WSL and the source repository

Open the Ubuntu profile in Windows Terminal, or run this from PowerShell:

```powershell
wsl
```

Run all remaining commands in the WSL shell. If the source repository is not pre-staged, clone it once:

```bash
mkdir -p "$HOME/repos"
git clone https://github.com/pauldotyu/ignite26-PREL37.git "$HOME/repos/ignite26-PREL37"
```

Then enter the existing clone and choose the workspace:

```bash
cd "$HOME/repos/ignite26-PREL37"
export LAB_SOURCE="$PWD"
export LAB_ROOT="$HOME/prel37"
```

### Check the assigned accounts in WSL

Windows sign-in does not automatically sign in the Linux Azure CLI or GitHub CLI. Check both:

```bash
az account show --query '{subscription:id,tenant:tenantId}' -o table
gh auth status
```

If needed, sign in inside WSL using the assigned lab accounts and select the assigned subscription:

```bash
az login --use-device-code
az account list --output table
read -r -p "Assigned subscription name or ID: " assigned_subscription
az account set --subscription "$assigned_subscription"
gh auth login --hostname github.com --git-protocol https
```

Do not use personal Azure credentials. `make machine-setup` checks that the active tenant and subscription match the provisioned outputs and stops if they do not.

### Prepare the learner workspace

```bash
make machine-setup
source "$LAB_ROOT/config/lab.env"
```

On the first run, answer the GitHub username/organization and Git author prompts. The script takes the lab ID, resource group, cluster names, and Azure configuration from the saved Terraform outputs. It does not ask you to choose them again.

The script:

1. Reads `/mnt/c/terraform/terraform.tfstate` through a private temporary snapshot and exports `lab` to `config/lab.json`. It leaves `C:\terraform` untouched and removes the snapshot. It does **not** run `terraform init`, `apply`, or `refresh`, copy Windows provider binaries, create a resource group, or change Azure role assignments.
2. Refreshes both cluster contexts with `setup/bootstrap.sh`, creates or reuses the private `prel37-<lab-id>-platform` and `prel37-<lab-id>-app-deploy` repositories, and prepares the worksheet, exercises, queries, evidence, and VS Code workspace.
3. Renders `config/environment.yaml` and installs the supplied provider/functions and shared Gateway, waiting for their ready conditions. It does **not** apply provider configuration, delivery permissions, EnvironmentConfig, or root Applications. Those are Module 2 work.
4. Prepares the pinned local Backstage runtime. GitHub setup choices are saved in `config/setup.env` under `LAB_ROOT`, not in the source clone.

There is no need to copy the entire Windows Terraform directory into `$HOME` or run `terraform init` in WSL. Reading saved outputs needs neither provider installation nor the bootstrap Azure identity. For a rehearsal with state in another location, use `LAB_TERRAFORM_SOURCE=/absolute/path/to/terraform make machine-setup`.

Rerunning `make machine-setup` preserves initialized repositories, worksheet answers, and existing workshop files. It stops rather than replacing a non-Git directory, using a clone for another lab, or hiding a failed push. Once setup has completed, use `make connect` and source `lab.env` to refresh access in later sessions without repeating preparation.

The application name comes from the saved `config/lab.env`, or defaults to `fourth-coffee` for a new lab. Setup ignores an inherited `APP_NAME` from other tools. For an intentional override, use `LAB_APP_NAME=<existing-application-name> make connect`; this updates the saved setting, not the application itself.

### Apply GitHub tokens

After `make machine-setup` succeeds and you source `lab.env`, run **`make auth` next**.

Create two fine-grained PATs scoped to your two private lab repositories: a read token with **Contents: Read-only**, and a Backstage token with **Contents: Read and write**, **Pull requests: Read and write**, and **Commit statuses: Read-only**. See [GitHub tokens](#github-tokens) for the resource-owner settings. In your current source-repository terminal, run:

```bash
make auth
```

Enter both tokens when prompted. Wait for the helper to finish applying the controller credentials and workload-cluster registration before continuing.

### Start Backstage and Argo CD

In a **second WSL terminal**, start Backstage and leave it running:

```bash
cd "$HOME/repos/ignite26-PREL37"
source "$HOME/prel37/config/lab.env"
make backstage
```

In a **third WSL terminal**, start the Argo CD tunnel and leave it running:

```bash
cd "$HOME/repos/ignite26-PREL37"
source "$HOME/prel37/config/lab.env"
make argocd
```

Confirm `http://localhost:3000` displays Backstage and select **Enter** as the guest user. Open `https://localhost:8443`, accept the local certificate warning, and sign in as `admin` with the password printed by `make argocd`.

### Open Module 1

With both services running, return to your original terminal and open the prepared workspace:

```bash
code "$LAB_ROOT/prel37.code-workspace"
```

Confirm VS Code is connected to WSL. Open `answers/product-brief.md` in **Lab Root** and start [Module 1: define the developer promise](../docs/1-developer-promise.md). Do not run `make app` until Module 3, and leave the platform wiring to Module 2.

---

## Fast-track setup

This path creates billable Azure resources. Use an authorized bootstrap identity and meet the [prerequisites](#prerequisites), including the preview registrations in [new Azure foundation](#new-azure-foundation). If the source is not cloned yet, first complete the source checkout in [manual step 1](#1-prepare-the-source-and-inputs).

```bash
cd "$HOME/repos/ignite26-PREL37"
az login
gh auth login --hostname github.com --git-protocol https
make setup
```

The script saves your inputs in `setup/setup.env`, provisions the foundation, refreshes cluster access, prepares the repositories and workspace, installs provider/functions and the Gateway, and installs the pinned Backstage runtime. Keep the saved configuration and bootstrap Terraform state for teardown.

Then complete [finish setup and open Module 1](#finish-setup-and-open-module-1). A successful `make setup` is not the final checkpoint: tokens and both local services are still required.

---

## Resume a prepared environment

Use this after preparation has completed. Do not rerun Terraform, copy templates over learner changes, or reset the workspace just to refresh access.

```bash
cd "$HOME/repos/ignite26-PREL37"
make connect
source "$HOME/prel37/config/lab.env"
```

1. If `make connect` reports an account mismatch, sign in to the lab's Azure tenant/subscription, then retry it.
2. If GitHub tokens expired, replace the affected file in `$LAB_ROOT/.credentials/`, then run `make auth`. Existing credential files are reused, so re-running `make auth` alone does not replace an expired token.
3. [Start the local services](#start-the-local-services) in separate terminals. Restart Backstage after changing its token. Start `make app` only after the application has been deployed in Module 3.

---

## Manual setup

Follow steps 1 through 6 in order, in the **same Bash terminal**, then complete the shared Module 1 handoff. Use Bash in WSL, Linux, or macOS, not PowerShell or `sh`. The commands keep you in the source checkout; Terraform uses `-chdir`, Git uses `-C`, and Backstage dependency installation runs in a subshell.

These are initialization steps for a fresh local workspace. If a destination already contains authored work, stop and inspect it rather than replacing it. Use the resume path for an already prepared lab. Do not continue past a failed command.

### Prerequisites

- **Tools:** `make`, `git`, `gh`, `az`, `terraform` (>=1.10, <2.0), `kubectl`, `kubelogin`, `node` (v24), `jq`, `envsubst`, `curl`, and VS Code. On Windows, prepare Linux CLI tools inside WSL and VS Code's WSL support. Keep shell scripts in LF format.
- **GitHub:** an authenticated account that can create the two private repositories and generate fine-grained PATs for them. No GitHub organization administration is required.
- **Azure, only when provisioning:** an authorized bootstrap identity with resource creation and role-assignment rights on the lab resource group, plus permission to create the OTLP custom role and its constrained telemetry-publisher delegation at subscription scope. Teardown also needs the model account's subscription-scoped [purge permission](../infra/README.md). These are operator prerequisites, not permissions learners must acquire.
- **Capacity, only when provisioning:** a region supporting the configured `Standard_D4s_v6` control node, AKS Automatic, and `gpt-5.4-mini` at capacity 10. Confirm availability and quota before starting.
- **Network access:** Azure sign-in and both cluster APIs, GitHub, Crossplane package registries, and Backstage dependencies. The Skillable image must include the Azure CLI `log-analytics` extension for Module 3; the new-foundation branch installs it below.

### 1. Prepare the source and inputs

If the source is not already cloned, run:

```bash
mkdir -p "$HOME/repos"
git clone https://github.com/pauldotyu/ignite26-PREL37.git "$HOME/repos/ignite26-PREL37"
```

Enter that checkout, choose the learner workspace, and restrict permissions on generated files:

```bash
cd "$HOME/repos/ignite26-PREL37"
export LAB_SOURCE="$PWD"
export LAB_ROOT="$HOME/prel37"
umask 077
mkdir -p "$LAB_ROOT/config" "$LAB_ROOT/runtime" "$LAB_ROOT/.state"
```

Check the accounts available in this shell. If needed, run `az login` and `gh auth login --hostname github.com --git-protocol https` first. In Skillable, use the assigned accounts. For provisioning, use the authorized bootstrap Azure identity.

```bash
az account show --query '{subscription:id,tenant:tenantId}' -o table
gh auth status
```

Collect the GitHub owner and Git commit identity once. Leave the organization blank to use your authenticated username:

```bash
GITHUB_USER="$(gh api user --jq .login)"
read -r -p "GitHub organization (blank for your username): " GITHUB_ORG
OWNER="${GITHUB_ORG:-$GITHUB_USER}"
if [ -n "$GITHUB_ORG" ]; then
  gh api "orgs/$GITHUB_ORG" >/dev/null
fi
read -r -p "Git author name: " GIT_NAME
read -r -p "Git author email: " GIT_EMAIL
export GITHUB_USER GITHUB_ORG OWNER GIT_NAME GIT_EMAIL
if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
  printf 'Git author name and email must both be nonempty.\n' >&2
  false
fi
```

**Expected result:** you know which account owns the repositories and have nonempty Git author values. The next step saves these choices where `make auth`, `make backstage`, and, for a newly provisioned lab, `make teardown` expect them.

### 2. Obtain the Azure foundation

The foundation is the bootstrap layer: two AKS clusters, Crossplane, the Argo CD extension, the model deployment, and the identities and role assignments the platform runs with. It is applied once by an authorized operator, separate from the per-team resources the platform vends later.

Complete **one** branch below, then continue to step 3. Never apply the managed-namespace module locally; only provider-opentofu runs that separate root.

#### New Azure foundation

Skip this branch in Skillable. This is the provisioning performed by `make setup`.

Register the Application Insights OTLP preview feature as the bootstrap operator. The AKS application-monitoring feature is not required:

```bash
az extension add --name log-analytics --upgrade --only-show-errors
az feature register --namespace Microsoft.Insights --name OtlpApplicationInsights
```

Registration is asynchronous. Check until its state is `Registered`; do not continue while it is pending:

```bash
az feature show --namespace Microsoft.Insights --name OtlpApplicationInsights --query properties.state -o tsv
```

Then re-register the resource providers:

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Insights
```

Choose a lab ID with **4-12 lowercase letters or digits, without hyphens**, the region, and the existing learner's identity. For your own user, `az ad signed-in-user show --query id -o tsv` gives the object ID. Prefer an object ID to avoid a directory lookup; a UPN requires the bootstrap identity to have directory-read access.

```bash
ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
read -r -p "Lab ID (4-12 lowercase letters or digits): " LAB_ID
read -r -p "Azure region: " AZURE_LOCATION
read -r -p "Learner Azure object ID or UPN: " LEARNER_ID
export ARM_SUBSCRIPTION_ID LAB_ID AZURE_LOCATION LEARNER_ID

unset TF_VAR_learner_object_id TF_VAR_learner_upn
if [[ ! "$LAB_ID" =~ ^[a-z0-9]{4,12}$ ]]; then
  printf 'Lab ID must contain 4-12 lowercase letters or digits, without hyphens.\n' >&2
  false
elif [ -z "$AZURE_LOCATION" ] || [ -z "$LEARNER_ID" ]; then
  printf 'Azure region and learner identity must both be nonempty.\n' >&2
  false
elif [[ "$LEARNER_ID" == *"@"* ]]; then
  export TF_VAR_learner_upn="$LEARNER_ID"
else
  export TF_VAR_learner_object_id="$LEARNER_ID"
fi
```

Save the same configuration file used by fast-track setup. Keep it with the matching bootstrap state; do not overwrite another lab's existing `setup/setup.env`:

```bash
if [ -e "$LAB_SOURCE/setup/setup.env" ]; then
  printf 'setup/setup.env already exists. Stop and restore or resume its matching lab.\n' >&2
  false
else
  jq -nr 'env | {ARM_SUBSCRIPTION_ID,AZURE_LOCATION,LAB_ID,GITHUB_USER,
    GITHUB_ORG,OWNER,GIT_NAME,GIT_EMAIL,LEARNER_ID} |
    to_entries[] | "export " + .key + "=" + (.value | @sh)' \
    > "$LAB_SOURCE/setup/setup.env"
fi
```

Create the resource group **outside Terraform**, then run only the bootstrap root from a dedicated directory. Terraform reads the group but does not own or delete it. Keep the default directory and group names so `make teardown` can find them:

```bash
az group create --name "rg-prel37-$LAB_ID" --location "$AZURE_LOCATION"
export BOOTSTRAP_DIR="$HOME/.prel37-tf-bootstrap-$LAB_ID"
mkdir -p "$BOOTSTRAP_DIR"
cp "$LAB_SOURCE/infra/main.tf" "$BOOTSTRAP_DIR/main.tf"

terraform -chdir="$BOOTSTRAP_DIR" init
terraform -chdir="$BOOTSTRAP_DIR" apply \
  -var="resource_group_name=rg-prel37-$LAB_ID" \
  -var="lab_id=$LAB_ID" \
  -auto-approve
terraform -chdir="$BOOTSTRAP_DIR" output -json lab > "$LAB_ROOT/config/lab.json"
```

**Expected result:** Terraform completes and `config/lab.json` contains the saved lab output. Terraform has installed Crossplane and the Argo CD extension, but provider/functions, the shared Gateway, repositories, and Backstage still need the following steps. Do not run `terraform init` or `apply` in this repository's `infra/` directory, which may contain older experimental state.

#### Already provisioned Skillable foundation

Skip the new-foundation branch entirely. Use the same output-only import as `make machine-setup`. Only the local default-workspace bootstrap state is copied, not Windows provider binaries or variable files:

```bash
(
  set -euo pipefail
  snapshot="$(mktemp -d "$LAB_ROOT/.state/terraform-output.XXXXXX")"
  trap 'rm -f -- "$snapshot/terraform.tfstate"; rmdir -- "$snapshot"' EXIT
  cp -- /mnt/c/terraform/terraform.tfstate "$snapshot/terraform.tfstate"
  TF_WORKSPACE=default TF_DATA_DIR="$snapshot/.terraform" \
    terraform -chdir="$snapshot" output -json lab > "$LAB_ROOT/config/lab.json"
)

jq -nr 'env | {GITHUB_USER,GITHUB_ORG,OWNER,GIT_NAME,GIT_EMAIL} |
  to_entries[] | "export " + .key + "=" + (.value | @sh)' \
  > "$LAB_ROOT/config/setup.env"
```

**Expected result:** `config/lab.json` comes from `C:\terraform\terraform.tfstate`, and GitHub choices are saved in the learner workspace. No Terraform `init`, `apply`, Azure resource-group creation, or role assignment is performed. The temporary state snapshot is removed and the Windows state remains unchanged.

### 3. Refresh cluster access and load the outputs

Both foundation branches continue here. Run the existing access helper, then source its generated environment into **this terminal**:

```bash
bash "$LAB_SOURCE/setup/bootstrap.sh"
source "$LAB_ROOT/config/lab.env"
kubectl config get-contexts -o name
kubectl --context "$CONTROL_CONTEXT" get nodes
kubectl --context "$AKS_CONTEXT" get nodes
```

**Expected result:** both clusters respond, with contexts `prel37-control` and `prel37-workload`. The helper validates the active Azure tenant/subscription and exports the known Terraform output fields with shell-safe quoting. It does not install controllers. Do not use `eval` on raw JSON or maintain a second set of `TF_VAR_lab_id` values for the later steps.

### 4. Prepare the repositories and platform

These two repositories are the platform's sources of truth. Platform holds the API, module, charts, and templates the platform team owns; App-Deploy holds what the application team changes. Argo CD and Backstage both act on them, so every later change is a reviewable commit.

This is `setup_repos` in the automation: seed both private repositories, render the personalized platform files, push `main`, copy the learner materials, and render the trusted mapping.

Set the repository URLs and Backstage selectors from the **exported** `LAB_ID` and saved GitHub owner:

```bash
gh auth setup-git --hostname github.com
export PLATFORM_REPO_URL="https://github.com/${OWNER}/prel37-${LAB_ID}-platform"
export APP_DEPLOY_REPO_URL="https://github.com/${OWNER}/prel37-${LAB_ID}-app-deploy"
export PLATFORM_BROWSER_URL="$PLATFORM_REPO_URL"
export APP_BROWSER_URL="$APP_DEPLOY_REPO_URL"
export APP_REPO_SELECTOR="github.com?owner=${OWNER}&repo=prel37-${LAB_ID}-app-deploy"
export PLATFORM_REPO_SELECTOR="github.com?owner=${OWNER}&repo=prel37-${LAB_ID}-platform"
```

Create or reuse the private repositories. **Copy the complete source assets before rendering**, including hidden files such as the managed-namespace module's `.terraform.lock.hcl`. This block stops on an unsafe destination or failed push; existing commits and working files are not overwritten:

```bash
(
  set -euo pipefail
  for repo in platform app-deploy; do
    name="prel37-$LAB_ID-$repo"
    path="$LAB_ROOT/$repo"
    if ! gh repo view "$OWNER/$name" >/dev/null 2>&1; then
      gh repo create "$OWNER/$name" --private
    fi
    if [ ! -e "$path" ]; then
      gh repo clone "$OWNER/$name" "$path"
    fi
    test -e "$path/.git"
    remote="$(git -C "$path" config --get remote.origin.url)"
    case "${remote%.git}" in
      "https://github.com/$OWNER/$name"|"git@github.com:$OWNER/$name"|"ssh://git@github.com/$OWNER/$name") ;;
      *) printf 'Wrong repository at %s. Stop and inspect it.\n' "$path" >&2; exit 1 ;;
    esac
    git -C "$path" config user.name "$GIT_NAME"
    git -C "$path" config user.email "$GIT_EMAIL"
    if ! git -C "$path" rev-parse --verify HEAD >/dev/null 2>&1; then
      test -z "$(git -C "$path" status --porcelain)"
      cp -R "$LAB_SOURCE/src/$repo/." "$path/"
      if [ "$repo" = platform ]; then
        for file in bootstrap/packages.yaml bootstrap/provider-config.yaml \
          bootstrap/control.yaml bootstrap/roots.yaml catalog/catalog.yaml \
          backstage/templates/ai-app/template.yaml \
          backstage/templates/app-environment/template.yaml; do
          envsubst < "$LAB_SOURCE/src/platform/$file" > "$path/$file"
        done
      fi
      git -C "$path" symbolic-ref HEAD refs/heads/main
      git -C "$path" add .
      git -C "$path" commit -m "Initial platform setup"
    fi
    if ! git -C "$path" rev-parse --verify refs/remotes/origin/main >/dev/null 2>&1; then
      git -C "$path" push -u origin main
    fi
  done
)
```

Copy the worksheet, evidence, queries, and exercise scaffolds outside the GitOps repositories. Copy only missing files so an interrupted setup can resume without replacing answers:

```bash
for dir in answers evidence queries exercises; do
  mkdir -p "$LAB_ROOT/$dir"
  find "$LAB_SOURCE/src/$dir" -type f -print0 |
    while IFS= read -r -d '' file; do
      relative="${file#"$LAB_SOURCE/src/"}"
      if [ ! -e "$LAB_ROOT/$relative" ]; then
        mkdir -p "$(dirname "$LAB_ROOT/$relative")"
        cp -- "$file" "$LAB_ROOT/$relative"
      fi
    done
done
```

Render the workspace and trusted EnvironmentConfig **after the platform's initial commit exists**, so `MODULE_REVISION` can pin that commit. Keep the approved artifact lock for Module 5 recovery:

```bash
MODULE_REVISION="$(git -C "$LAB_ROOT/platform" rev-list --max-parents=0 HEAD)"
test -n "$MODULE_REVISION"
export MODULE_REVISION
if [ ! -f "$LAB_ROOT/prel37.code-workspace" ]; then
  envsubst < "$LAB_SOURCE/src/platform/prel37.code-workspace.template" \
    > "$LAB_ROOT/prel37.code-workspace"
fi
if [ ! -f "$LAB_ROOT/config/environment.yaml" ]; then
  envsubst < "$LAB_SOURCE/src/platform/bootstrap/environment.yaml" \
    > "$LAB_ROOT/config/environment.yaml"
fi
if [ ! -f "$LAB_ROOT/config/artifact-lock.json" ]; then
  cp "$LAB_SOURCE/setup/artifact-lock.json" "$LAB_ROOT/config/artifact-lock.json"
fi
```

**Expected result:** both repositories have a published `main`; Platform contains the supplied API, module, charts, profiles, catalog, and templates; App-Deploy is intentionally empty of application manifests until Module 3. The learner workspace contains `answers/product-brief.md`, `exercises/`, `queries/`, `evidence/`, `prel37.code-workspace`, `config/environment.yaml`, and `config/artifact-lock.json`.

Do **not** apply `environment.yaml`, `bootstrap/provider-config.yaml`, `bootstrap/control.yaml`, or `bootstrap/roots.yaml` yet. They are rendered and committed where appropriate, but Module 2 owns the wiring.

### 5. Install provider/functions and the shared Gateway

Terraform installs Crossplane and Argo CD. The Crossplane provider and functions let the control cluster run OpenTofu modules and compose resources; the shared Gateway gives every team a common, platform-managed entry point on the workload cluster. Install the supplied Crossplane packages on the **control** cluster and the Gateway on the **workload** cluster, then wait for the same conditions as `make setup`:

```bash
kubectl --context "$CONTROL_CONTEXT" apply -f "$LAB_ROOT/platform/bootstrap/packages.yaml"
kubectl --context "$AKS_CONTEXT" apply -f "$LAB_ROOT/platform/bootstrap/workload.yaml"
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Healthy \
  providers.pkg.crossplane.io/provider-opentofu --timeout=600s
kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Healthy \
  functions.pkg.crossplane.io -l app.kubernetes.io/part-of=prel37 --timeout=600s
kubectl --context "$AKS_CONTEXT" -n platform-gateway wait --for=condition=Programmed \
  gateway/tenants --timeout=600s
```

**Expected result:** the provider and three functions are healthy, and Gateway `tenants` is programmed in namespace **`platform-gateway`**, not `platform-system`. No root Applications, `AppEnvironment` API, or `beans` namespace are created by these commands.

The complete source copy in step 4 includes the OpenTofu module and its lock file. Updating this source checkout alone does not upgrade an existing private platform repository or its installed package; preserve its personalized values when reviewing upgrades.

### 6. Prepare the pinned Backstage runtime

Clone the existing Backstage app, check out the approved revision, apply the two workshop overlays, and install dependencies with the repository's pinned Yarn. The subshell returns you to the source directory when installation finishes:

```bash
BACKSTAGE_REVISION="$(jq -er .backstage.sourceRevision "$LAB_ROOT/config/artifact-lock.json")"
if [ ! -d "$LAB_ROOT/runtime/backstage" ]; then
  git clone https://github.com/pauldotyu/backstage.git "$LAB_ROOT/runtime/backstage"
  git -C "$LAB_ROOT/runtime/backstage" checkout --detach "$BACKSTAGE_REVISION"
  cp "$LAB_SOURCE/src/backstage/App.tsx" "$LAB_ROOT/runtime/backstage/packages/app/src/App.tsx"
  cp "$LAB_SOURCE/src/backstage/index.ts" "$LAB_ROOT/runtime/backstage/packages/backend/src/index.ts"
fi
test "$(git -C "$LAB_ROOT/runtime/backstage" rev-parse HEAD)" = "$BACKSTAGE_REVISION"
if [ ! -f "$LAB_ROOT/runtime/backstage/node_modules/.yarn-state.yml" ]; then
  (
    cd "$LAB_ROOT/runtime/backstage"
    node .yarn/releases/yarn-4.13.0.cjs install --immutable
  )
fi
envsubst '${LAB_ROOT} ${PLATFORM_BROWSER_URL}' \
  < "$LAB_SOURCE/src/backstage/app-config.lab.yaml" \
  > "$LAB_ROOT/runtime/backstage/app-config.local.yaml"
```

**Expected result:** dependencies are installed and `app-config.local.yaml` points at your lab's platform repository. `${GITHUB_TOKEN}` remains literal in that file; the launcher supplies it at runtime. Do not paste a PAT into the config.

At this point, manual preparation matches the end of `make setup`. Continue below; you still need GitHub tokens and the two local services before Module 1.

## Finish setup and open Module 1

Every preparation path ends here. Keep your preparation terminal available for the checks, and use two additional terminals for the foreground services.

### GitHub tokens

Each consumer gets its own least-privilege, repository-scoped token. Argo CD and Crossplane only read; Backstage writes branches and opens PRs on the developer's behalf.

Create two [fine-grained PATs](https://github.com/settings/personal-access-tokens/new). For both, set **Resource owner** to the account that owns your repositories and **Repository access** to the two private `prel37-<lab-id>-platform` and `prel37-<lab-id>-app-deploy` repositories:

- **Read token:** `Contents: Read-only`, for Argo CD and Crossplane.
- **Backstage token:** `Contents: Read and write`, `Pull requests: Read and write`, and `Commit statuses: Read-only`. Contents and commit-status access let Backstage read the catalog and populate the Module 4 Application picker. Pull-request write access lets the template open its PR after pushing a branch.

From the source checkout, load the environment and apply the tokens:

```bash
cd "$HOME/repos/ignite26-PREL37"
export LAB_ROOT="${LAB_ROOT:-$HOME/prel37}"
source "$LAB_ROOT/config/lab.env"
make auth
```

Use the prompts rather than putting tokens in command history. The helper stores private credential files in `$LAB_ROOT/.credentials/`, checks the read side of the required GitHub permissions, and configures controller repository credentials plus Argo CD's workload-cluster registration. Write permissions must still be granted in GitHub.

Check the Secret names without printing their contents:

```bash
kubectl --context "$CONTROL_CONTEXT" -n platform-system get secret github-token
kubectl --context "$CONTROL_CONTEXT" -n crossplane-system get secret module-git-credentials
kubectl --context "$CONTROL_CONTEXT" -n argocd get secret repo-platform repo-app-deploy cluster-workload
```

**Expected result:** all five Secrets are listed. Keep `setup.env`, Terraform state, `config/`, `.state/`, and `.credentials/` out of Git.

### Start the local services

In **terminal A**, start Backstage and leave it running:

```bash
cd "$HOME/repos/ignite26-PREL37"
source "$HOME/prel37/config/lab.env"
make backstage
```

In **terminal B**, start the Argo CD tunnel and leave it running:

```bash
cd "$HOME/repos/ignite26-PREL37"
source "$HOME/prel37/config/lab.env"
make argocd
```

The commands above use the default source and workspace paths. If you chose a different path, use it in each new terminal. Do not put both launchers in one sequential command block: each stays in the foreground until you press Ctrl+C.

### Module 1 readiness

In the preparation terminal, check the files Module 1 and the later modules need:

```bash
test -s "$LAB_ROOT/answers/product-brief.md"
test -s "$LAB_ROOT/config/environment.yaml"
test -s "$LAB_ROOT/config/artifact-lock.json"
test -s "$LAB_ROOT/prel37.code-workspace"
kubectl config get-contexts -o name
kubectl --context "$CONTROL_CONTEXT" get nodes
kubectl --context "$AKS_CONTEXT" get nodes
```

- Both `prel37-control` and `prel37-workload` contexts exist, and both clusters respond.
- The provider/functions and Gateway waits succeeded; all five GitHub/cluster Secrets are present.
- `http://localhost:3000` displays Backstage. Select **Enter** as the guest user.
- `https://localhost:8443` displays Argo CD sign-in. Accept the local certificate warning and use `admin` with the password printed in terminal B.
- On a fresh instance, Argo CD has no workshop Applications, and there is no `AppEnvironment` API or `beans` namespace. That is expected. Leave provider configuration, delivery permissions, applying EnvironmentConfig, and root Applications to Module 2. Preserve later progress if resuming.

Open the prepared workspace from the preparation terminal:

```bash
code "$LAB_ROOT/prel37.code-workspace"
```

In WSL, confirm VS Code is connected to WSL. The Explorer contains **Lab Root**, **Platform**, and **App-Deploy**. Open `answers/product-brief.md` in **Lab Root**, read the [workshop overview](../docs/README.md), and start [Module 1: define the developer promise](../docs/1-developer-promise.md).

Do not run `make app` yet. The application and its tunnel come in Module 3. Passing these checks is the installation checkpoint, not proof that the later application delivery or telemetry exercises have passed.

## Resource teardown

**Skillable:** the lab host owns Azure cleanup. Do not run `make teardown` in the assigned learner VM.

**Self-paced:** Azure resources remain billable after you close the browser or stop local services:

- `make reset` removes the local `~/prel37` workspace, including answers and tokens, but leaves Azure resources running. It is not a normal resume or troubleshooting step.
- `make teardown` destroys bootstrap resources, deletes the two private GitHub repositories, removes the default local workspace and matching bootstrap directory, and removes `setup/setup.env`. Back up exercise evidence before confirming it.

Teardown needs `setup/setup.env` from the new-foundation branch, the matching `~/.prel37-tf-bootstrap-<lab-id>/terraform.tfstate`, and the authorized Azure identity. It derives `rg-prel37-<lab-id>` from that saved configuration and stops if required configuration or state is missing. A Terraform failure preserves the local setup and GitHub repositories so deletion can be retried.

The resource group itself is retained because bootstrap Terraform does not own it. Per-team resources vended by provider-opentofu are in separate state. After destroying the foundation, the teardown helper removes lab-tagged vended resources and their `Failure Anomalies` alert rules, including the optional next environment's resources.
