#!/usr/bin/env bash
set -euo pipefail

export LAB_SOURCE="${LAB_SOURCE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export LAB_ROOT="${LAB_ROOT:-$HOME/prel37}"

# ==============================================================================
# FAST-TRACK SETUP: The "Just Get Me Started" Script
# ==============================================================================
# This script automates the boring parts of the setup process.
# It will handle tool checks, Azure provisioning, and repo creation.
# It will pause for your interactive logins/tokens.
# ==============================================================================

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

# --- 1. Tool Check ---
check_tools() {
  log "Checking prerequisites..."
  local tools=(git gh az terraform kubectl kubelogin node jq envsubst)
  for tool in "${tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      error "Missing: $tool. Please install it before continuing."
      exit 1
    fi
  done
  success "Prerequisites found."
}

check_azure_features() {
  az extension add --name log-analytics --upgrade --only-show-errors >/dev/null 2>&1 \
    || warn "Could not install the log-analytics az extension; Module 3 telemetry checks need it."
  local flag state
  for flag in Microsoft.Insights/OtlpApplicationInsights; do
    state=$(az feature show --namespace "${flag%%/*}" --name "${flag##*/}" --query properties.state -o tsv 2>/dev/null)
    if [ "$state" != "Registered" ]; then
      error "Azure feature $flag is '${state:-NotRegistered}'. Register it, wait for 'Registered', then run: az provider register -n ${flag%%/*}"
      exit 1
    fi
  done
}

# --- 2. Input Gathering ---
collect_github_inputs() {
  local gh_user input_gh input_org_diff
  if ! gh_user=$(gh api user --jq .login); then
    error "Not logged into GitHub. Run 'gh auth login' in this shell first."
    exit 1
  fi
  printf "GitHub Username [%s]: " "$gh_user"
  read -r input_gh; GITHUB_USER="${input_gh:-$gh_user}"

  printf "Is your GitHub org different from your username? (y/N): "
  read -r input_org_diff
  GITHUB_ORG=""
  if [[ "$input_org_diff" =~ ^[Yy] ]]; then
    printf "GitHub Org Name: "
    read -r GITHUB_ORG
    if [[ -z "$GITHUB_ORG" ]]; then
      error "GitHub org name is required when it differs from your username."
      exit 1
    fi
    if ! gh api "orgs/$GITHUB_ORG" >/dev/null 2>&1; then
      error "GitHub org '$GITHUB_ORG' not found or not accessible. Check the name and your 'gh auth' scopes (read:org)."
      exit 1
    fi
  fi
  OWNER="${GITHUB_ORG:-$GITHUB_USER}"
  log "Repositories will be created under: $OWNER"

  printf "Git Author Name: "
  read -r GIT_NAME
  printf "Git Author Email: "
  read -r GIT_EMAIL
  if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]]; then
    error "A Git author name and email are required."
    exit 1
  fi
  export GITHUB_USER GITHUB_ORG OWNER GIT_NAME GIT_EMAIL
}

collect_inputs() {
  local config_file="setup/setup.env"
  
  if [ -f "$config_file" ]; then
    log "Loading existing setup configuration from $config_file..."
    source "$config_file"
    # Re-derive TF variables from the saved LEARNER_ID
    if [[ "$LEARNER_ID" == *"@"* ]]; then
      export TF_VAR_learner_upn="$LEARNER_ID"
      unset TF_VAR_learner_object_id
    else
      export TF_VAR_learner_object_id="$LEARNER_ID"
      unset TF_VAR_learner_upn
    fi
    export ARM_SUBSCRIPTION_ID AZURE_LOCATION LAB_ID OWNER GIT_NAME GIT_EMAIL
    return 0
  fi

  log "First-time setup: Gathering inputs..."
  
  # Subscription
  local sub_id=$(az account show --query id -o tsv 2>/dev/null || echo "")
  if [[ -z "$sub_id" ]]; then
     warn "Not logged into Azure. Please run 'az login' first."
     exit 1
  fi
  printf "Azure Subscription ID [%s]: " "$sub_id"
  read -r input_sub; ARM_SUBSCRIPTION_ID="${input_sub:-$sub_id}"
  
  # Region
  local region=$(az account show --query resources.location -o tsv | head -n 1 || echo "eastus")
  printf "Azure Region [%s]: " "$region"
  read -r input_region; AZURE_LOCATION="${input_region:-$region}"
  
  # Lab ID
  local default_id=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 6)
  printf "Unique Lab ID (4-12 lowercase/digits) [%s]: " "$default_id"
  read -r input_id; LAB_ID="${input_id:-$default_id}"
  
  collect_github_inputs
  
  # Learner Identity
  local learner_id=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
  printf "Azure Object ID or UPN [%s]: " "$learner_id"
  read -r input_lid; LEARNER_ID="${input_lid:-$learner_id}"

  # Save to config file for future runs
  cat <<EOF > "$config_file"
ARM_SUBSCRIPTION_ID="$ARM_SUBSCRIPTION_ID"
AZURE_LOCATION="$AZURE_LOCATION"
LAB_ID="$LAB_ID"
GITHUB_USER="$GITHUB_USER"
GITHUB_ORG="$GITHUB_ORG"
OWNER="$OWNER"
GIT_NAME="$GIT_NAME"
GIT_EMAIL="$GIT_EMAIL"
LEARNER_ID="$LEARNER_ID"
EOF
  success "Setup configuration saved to $config_file."

  # Determine if this is a UPN (contains @) or an Object ID
  if [[ "$LEARNER_ID" == *"@"* ]]; then
    export TF_VAR_learner_upn="$LEARNER_ID"
    unset TF_VAR_learner_object_id
  else
    export TF_VAR_learner_object_id="$LEARNER_ID"
    unset TF_VAR_learner_upn
  fi

  export ARM_SUBSCRIPTION_ID AZURE_LOCATION LAB_ID OWNER GIT_NAME GIT_EMAIL
}

# --- 3. Azure Provisioning ---
provision() {
  log "Provisioning Azure Foundation (this may take 10-15 mins)..."
  
  local rg="rg-prel37-$LAB_ID"
  az group create --name "$rg" --location "$AZURE_LOCATION"
  
  local tf_dir="$HOME/.prel37-tf-bootstrap-$LAB_ID"
  mkdir -p "$tf_dir"
  cp "infra/main.tf" "$tf_dir/main.tf"
  
  cd "$tf_dir"
  terraform init
  # Use the variable determined in collect_inputs
  terraform apply \
    -var="resource_group_name=$rg" \
    -var="lab_id=$LAB_ID" \
    ${TF_VAR_learner_object_id:+ -var="learner_object_id=$TF_VAR_learner_object_id"} \
    ${TF_VAR_learner_upn:+ -var="learner_upn=$TF_VAR_learner_upn"} \
    -auto-approve
  
  mkdir -p "$LAB_ROOT/config"
  terraform output -json lab > "$LAB_ROOT/config/lab.json"
  cd - > /dev/null
  success "Azure foundation ready."
}

# --- 4. GitHub Setup ---
setup_repos() {
  log "Setting up private GitHub repositories..."

  gh auth setup-git --hostname github.com
  export LAB_ID OWNER
  export PLATFORM_REPO_URL="https://github.com/${OWNER}/prel37-${LAB_ID}-platform"
  export APP_DEPLOY_REPO_URL="https://github.com/${OWNER}/prel37-${LAB_ID}-app-deploy"
  export PLATFORM_BROWSER_URL="$PLATFORM_REPO_URL"
  export APP_BROWSER_URL="$APP_DEPLOY_REPO_URL"
  export APP_REPO_SELECTOR="github.com?owner=${OWNER}&repo=prel37-${LAB_ID}-app-deploy"
  export PLATFORM_REPO_SELECTOR="github.com?owner=${OWNER}&repo=prel37-${LAB_ID}-platform"
  
  local plat_files=(
    "bootstrap/packages.yaml" "bootstrap/provider-config.yaml" "bootstrap/control.yaml"
    "bootstrap/roots.yaml" "catalog/catalog.yaml" "backstage/templates/ai-app/template.yaml"
    "backstage/templates/app-environment/template.yaml"
  )
  local repo_name repo_full_name repo_path remote f dir file relative
  for repo_name in platform app-deploy; do
    repo_full_name="prel37-$LAB_ID-$repo_name"
    repo_path="$LAB_ROOT/$repo_name"
    if gh repo view "$OWNER/$repo_full_name" >/dev/null 2>&1; then
      log "Repository $OWNER/$repo_full_name already exists."
    else
      gh repo create "$OWNER/$repo_full_name" --private
    fi
    if [ ! -e "$repo_path" ]; then
      gh repo clone "$OWNER/$repo_full_name" "$repo_path"
    fi
    [ -e "$repo_path/.git" ] ||
      { error "$repo_path is not a Git clone. Move it aside before retrying."; exit 1; }
    remote=$(git -C "$repo_path" config --get remote.origin.url)
    case "${remote%.git}" in
      "https://github.com/$OWNER/$repo_full_name"|"git@github.com:$OWNER/$repo_full_name"|"ssh://git@github.com/$OWNER/$repo_full_name") ;;
      *) error "$repo_path belongs to a different repository ($remote). Use a separate LAB_ROOT."; exit 1 ;;
    esac
    git -C "$repo_path" config user.name "$GIT_NAME"
    git -C "$repo_path" config user.email "$GIT_EMAIL"

    if ! git -C "$repo_path" rev-parse --verify HEAD >/dev/null 2>&1; then
      [ -z "$(git -C "$repo_path" status --porcelain)" ] ||
        { error "$repo_path has uncommitted files. Preserve them before retrying."; exit 1; }
      cp -R "src/$repo_name/." "$repo_path/"
      if [ "$repo_name" = platform ]; then
        for f in "${plat_files[@]}"; do
          envsubst < "src/platform/$f" > "$repo_path/$f"
        done
      fi
      git -C "$repo_path" symbolic-ref HEAD refs/heads/main
      git -C "$repo_path" add .
      git -C "$repo_path" commit -m "Initial platform setup"
    else
      log "Preserving existing commits and working files in $repo_path."
    fi
    # A failed first push can be retried without recopying or recommitting the assets.
    if ! git -C "$repo_path" rev-parse --verify refs/remotes/origin/main >/dev/null 2>&1; then
      git -C "$repo_path" push -u origin main
    fi
  done

  for dir in answers evidence queries exercises; do
    mkdir -p "$LAB_ROOT/$dir"
    find "src/$dir" -type f -print0 |
      while IFS= read -r -d '' file; do
        relative="${file#src/}"
        if [ ! -e "$LAB_ROOT/$relative" ]; then
          mkdir -p "$(dirname "$LAB_ROOT/$relative")"
          cp -- "$file" "$LAB_ROOT/$relative"
        fi
      done
  done
  if [ ! -f "$LAB_ROOT/prel37.code-workspace" ]; then
    envsubst < "src/platform/prel37.code-workspace.template" > "$LAB_ROOT/prel37.code-workspace"
  fi

  MODULE_REVISION="$(git -C "$LAB_ROOT/platform" rev-list --max-parents=0 HEAD)"
  export MODULE_REVISION
  [ -n "$MODULE_REVISION" ] || { error "Could not determine MODULE_REVISION from $LAB_ROOT/platform."; exit 1; }
  if [ ! -f "$LAB_ROOT/config/environment.yaml" ]; then
    envsubst < "src/platform/bootstrap/environment.yaml" > "$LAB_ROOT/config/environment.yaml"
  fi
  if [ ! -f "$LAB_ROOT/config/artifact-lock.json" ]; then
    cp "setup/artifact-lock.json" "$LAB_ROOT/config/artifact-lock.json"
  fi
  success "Personalized repositories and workshop files ready."
}

# --- 5. Cluster Access ---
configure_clusters() {
  log "Fetching cluster credentials..."
  bash setup/bootstrap.sh
  source "$LAB_ROOT/config/lab.env"
}

# --- 6. Platform Software Installation ---
install_platform_software() {
  log "Installing platform controllers and gateway..."
  
  # We must use the context from lab.env
  if [ -f "$LAB_ROOT/config/lab.env" ]; then
    source "$LAB_ROOT/config/lab.env"
  else
    error "lab.env not found. Cannot install software."
    exit 1
  fi
  
  # 1. Install Control Plane components
  log "Applying control plane packages..."
  kubectl --context "$CONTROL_CONTEXT" apply -f "$LAB_ROOT/platform/bootstrap/packages.yaml"
  
  # 2. Install Workload Gateway
  log "Applying workload gateway..."
  kubectl --context "$AKS_CONTEXT" apply -f "$LAB_ROOT/platform/bootstrap/workload.yaml"

  kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Healthy \
    providers.pkg.crossplane.io/provider-opentofu --timeout=600s
  kubectl --context "$CONTROL_CONTEXT" wait --for=condition=Healthy \
    functions.pkg.crossplane.io -l app.kubernetes.io/part-of=prel37 --timeout=600s
  kubectl --context "$AKS_CONTEXT" -n platform-gateway wait --for=condition=Programmed \
    gateway/tenants --timeout=600s
  success "Platform packages and shared gateway ready. Module 2 wiring is left to the workshop."
}

# --- 7. Backstage ---
setup_backstage() {
  log "Installing Backstage (this takes a few minutes)..."
  mkdir -p "$LAB_ROOT/runtime"
  local rev
  rev=$(jq -er .backstage.sourceRevision "$LAB_ROOT/config/artifact-lock.json")
  if [ ! -d "$LAB_ROOT/runtime/backstage" ]; then
    git clone https://github.com/pauldotyu/backstage.git "$LAB_ROOT/runtime/backstage"
    git -C "$LAB_ROOT/runtime/backstage" checkout --detach "$rev"
    cp "src/backstage/App.tsx" "$LAB_ROOT/runtime/backstage/packages/app/src/App.tsx"
    cp "src/backstage/index.ts" "$LAB_ROOT/runtime/backstage/packages/backend/src/index.ts"
  fi
  [ "$(git -C "$LAB_ROOT/runtime/backstage" rev-parse HEAD)" = "$rev" ] ||
    { error "Backstage at $LAB_ROOT/runtime/backstage is not at the pinned revision $rev."; exit 1; }
  # Yarn writes this file only after a complete install, so an interrupted setup reinstalls on rerun.
  if [ ! -f "$LAB_ROOT/runtime/backstage/node_modules/.yarn-state.yml" ]; then
    (cd "$LAB_ROOT/runtime/backstage" && node .yarn/releases/yarn-4.13.0.cjs install --immutable)
  fi
  
  # Config
  # ${GITHUB_TOKEN} stays literal; setup/start-backstage.sh supplies it at runtime
  envsubst '${LAB_ROOT} ${PLATFORM_BROWSER_URL}' < "src/backstage/app-config.lab.yaml" > "$LAB_ROOT/runtime/backstage/app-config.local.yaml"
  success "Backstage installed."
}

print_next_steps() {
  printf "\n${GREEN}==================================================================${NC}\n"
  printf "${GREEN}WORKSHOP FILES AND PLATFORM PACKAGES READY${NC}\n"
  printf "Load the environment in this terminal:\n"
  printf "   source %q\n\n" "$LAB_ROOT/config/lab.env"
  printf "Next, create two fine-grained GitHub PATs (resource owner: %s, repos: prel37-%s-*):\n" "$OWNER" "$LAB_ID"
  printf "   Read token:      Contents: Read-only\n"
  printf "   Backstage token: Contents + Pull requests: Read and write, Commit statuses: Read-only\n"
  printf "   https://github.com/settings/personal-access-tokens/new\n"
  printf "\nThen apply them to the control cluster:\n"
  printf "   make auth   (or: bash setup/apply-tokens.sh)\n"
  printf "\nThen start the local services, each in its own terminal:\n"
  printf "   source %q   (in each new terminal first)\n" "$LAB_ROOT/config/lab.env"
  printf "   make backstage   (http://localhost:3000)\n"
  printf "   make argocd      (https://localhost:8443)\n"
  printf "   make app         (http://beans.localhost:8080, after Module 3)\n"
  printf "\nOnce your tokens are applied and both services are running, open %s/prel37.code-workspace\n" "$LAB_ROOT"
  printf "and start docs/1-developer-promise.md (Module 1).\n"
  printf "\nReturning in a new session? Refresh cluster access first:\n"
  printf "   make connect\n"
  printf "   source %q\n" "$LAB_ROOT/config/lab.env"
  printf "${GREEN}==================================================================${NC}\n"
}

main() {
  cd "$LAB_SOURCE"
  check_tools
  check_azure_features
  collect_inputs
  provision
  configure_clusters
  setup_repos
  install_platform_software
  setup_backstage
  print_next_steps
}

# machine-setup.sh reuses preparation functions, but must never enter the provisioning path.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
