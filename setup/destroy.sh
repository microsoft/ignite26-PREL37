#!/usr/bin/env bash
set -euo pipefail

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

log "Initiating total teardown of the Paved Road environment..."

# Load the same saved inputs used by fast-track setup.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/setup.env"
if [ ! -f "$CONFIG_FILE" ]; then
  error "Missing $CONFIG_FILE. Restore the saved setup configuration before teardown."
  exit 1
fi

LAB_ID=""
OWNER=""
ARM_SUBSCRIPTION_ID=""
LEARNER_ID=""
source "$CONFIG_FILE"

if [[ -z "$LAB_ID" || -z "$OWNER" || -z "$ARM_SUBSCRIPTION_ID" || -z "$LEARNER_ID" ]]; then
  error "setup.env must contain LAB_ID, OWNER, ARM_SUBSCRIPTION_ID, and LEARNER_ID. No resources were deleted."
  exit 1
fi
if [[ ! "$LAB_ID" =~ ^[a-z0-9]{4,12}$ ]]; then
  error "LAB_ID must contain four to twelve lowercase letters or digits. No resources were deleted."
  exit 1
fi

export ARM_SUBSCRIPTION_ID
unset TF_VAR_learner_object_id TF_VAR_learner_upn
if [[ "$LEARNER_ID" == *"@"* ]]; then
  export TF_VAR_learner_upn="$LEARNER_ID"
else
  export TF_VAR_learner_object_id="$LEARNER_ID"
fi

TF_DIR="$HOME/.prel37-tf-bootstrap-$LAB_ID"
if [ ! -d "$TF_DIR" ]; then
  error "Bootstrap directory $TF_DIR not found. Restore it and its Terraform state before teardown."
  exit 1
fi
if [ ! -s "$TF_DIR/terraform.tfstate" ]; then
  error "Terraform state is missing or empty in $TF_DIR. Restore it before teardown."
  exit 1
fi

log "Destroying bootstrap-managed Azure resources for lab $LAB_ID..."
terraform -chdir="$TF_DIR" destroy \
  -input=false \
  -var="resource_group_name=rg-prel37-$LAB_ID" \
  -var="lab_id=$LAB_ID" \
  -auto-approve
success "Bootstrap-managed Azure resources for $LAB_ID destroyed."

# Each AppEnvironment's identity and Application Insights live in OpenTofu state, not bootstrap state,
# so the bootstrap destroy above leaves them behind. Remove them, and the alert rule Azure adds to each
# Application Insights resource, by the tags the managed-namespace module sets.
RG="rg-prel37-$LAB_ID"
if [ "$(az group exists --name "$RG")" = "true" ]; then
  log "Deleting environment resources vended for $LAB_ID..."
  VENDED_IDS="$(az resource list -g "$RG" \
    --query "[?tags.\"managed-by\"=='provider-opentofu' && tags.\"lab-id\"=='$LAB_ID'].id" -o tsv)"
  ALERT_IDS="$(az resource list -g "$RG" --resource-type microsoft.alertsmanagement/smartDetectorAlertRules \
    --query "[?starts_with(name, 'Failure Anomalies - appi-prel37-$LAB_ID-')].id" -o tsv)"
  # Alert rule names contain spaces, so read one ID per line.
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    az resource delete --ids "${id// /%20}" --output none && success "Deleted ${id##*/}."
  done <<< "$(printf '%s\n%s\n' "$ALERT_IDS" "$VENDED_IDS")"
fi

log "Deleting GitHub repositories for $LAB_ID..."
for repo in platform app-deploy; do
  REPO_NAME="prel37-${LAB_ID}-${repo}"
  if gh repo view "$OWNER/$REPO_NAME" >/dev/null 2>&1; then
    gh repo delete "$OWNER/$REPO_NAME" --yes
    success "Deleted repository $OWNER/$REPO_NAME."
  else
    warn "Repository $OWNER/$REPO_NAME not found. Skipping."
  fi
done

log "Cleaning up local files..."
rm -rf "$TF_DIR"
rm -rf "$HOME/prel37"
rm -f "$CONFIG_FILE"

success "Teardown complete. Local lab files and bootstrap-managed Azure resources have been removed. The resource group is retained."
