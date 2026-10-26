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

# --- Configuration ---
export LAB_ROOT="${LAB_ROOT:-$HOME/prel37}"
CONFIG_FILE="$LAB_ROOT/config/setup.env"
if [ ! -f "$CONFIG_FILE" ]; then
  CONFIG_FILE="setup/setup.env"
fi
CRED_DIR="$LAB_ROOT/.credentials"
NAMESPACE="platform-system"
SECRET_NAME="github-token"

# Load existing config
if [ -f "$LAB_ROOT/config/lab.env" ]; then
  source "$LAB_ROOT/config/lab.env"
fi
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

# --- Token Collection ---
collect_token() {
  local var_name=$1
  local file_name=$2
  local prompt_text=$3
  local current_val="${!var_name:-}"

  # 1. Check credential file (The single source of truth)
  if [ -f "$CRED_DIR/$file_name" ]; then
    local file_val=$(cat "$CRED_DIR/$file_name")
    if [[ -n "$file_val" ]]; then
      echo "$file_val"
      return
    fi
  fi

  # 2. Prompt user
  # Use /dev/tty to ensure the prompt goes to the user's terminal even when run via make
  local input_val
  printf "%s: " "$prompt_text" >&2
  read -r input_val < /dev/tty
  echo "$input_val"
}

log "Collecting GitHub tokens..."

# Collect tokens
READ_TOKEN=$(collect_token "GITHUB_READ_TOKEN" "read-token" "GitHub read PAT (Contents: Read-only)")
BACKSTAGE_TOKEN=$(collect_token "GITHUB_BACKSTAGE_TOKEN" "backstage-token" "GitHub Backstage PAT (Contents + Pull requests: Read and write, Commit statuses: Read-only)")

if [[ -z "$READ_TOKEN" || -z "$BACKSTAGE_TOKEN" ]]; then
  error "Both tokens are required."
  exit 1
fi

# --- Permission Check ---
# Fine-grained PATs return 403 for an API whose permission was not granted.
# Write access can't be probed without side effects, so this checks the read side of each grant.
gh_status() {
  curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $1" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$2"
}

if [[ -n "${OWNER:-}" && -n "${LAB_ID:-}" ]]; then
  log "Checking token permissions on ${OWNER}/prel37-${LAB_ID}-*..."
  TOKEN_ERRORS=0
  for repo in platform app-deploy; do
    full="${OWNER}/prel37-${LAB_ID}-${repo}"
    if [[ "$(gh_status "$READ_TOKEN" "$full/contents/")" != "200" ]]; then
      error "Read PAT can't read contents of $full. Grant 'Contents: Read-only' with resource owner '$OWNER'."
      TOKEN_ERRORS=1
    fi
    if [[ "$(gh_status "$BACKSTAGE_TOKEN" "$full/contents/")" != "200" ]]; then
      error "Backstage PAT can't read contents of $full. Grant 'Contents: Read and write' with resource owner '$OWNER'."
      TOKEN_ERRORS=1
    fi
    if [[ "$(gh_status "$BACKSTAGE_TOKEN" "$full/pulls")" != "200" ]]; then
      error "Backstage PAT can't access pull requests on $full. Grant 'Pull requests: Read and write'."
      TOKEN_ERRORS=1
    fi
    if [[ "$(gh_status "$BACKSTAGE_TOKEN" "$full/commits/main/status?per_page=0")" != "200" ]]; then
      error "Backstage PAT can't read commit statuses on $full. Grant 'Commit statuses: Read-only'; the Backstage catalog needs it to read catalog/*.yaml."
      TOKEN_ERRORS=1
    fi
  done
  if [[ "$TOKEN_ERRORS" -ne 0 ]]; then
    error "Fix the token permissions in GitHub, then update $CRED_DIR and re-run this script."
    exit 1
  fi
  success "Token permissions look correct."
else
  warn "OWNER or LAB_ID not set in $CONFIG_FILE. Skipping token permission check."
fi

# --- Persistence ---
# Save to ~/prel37/.credentials/ only
mkdir -p "$CRED_DIR"
chmod 700 "$CRED_DIR"
(umask 077 && echo "$READ_TOKEN" > "$CRED_DIR/read-token" && echo "$BACKSTAGE_TOKEN" > "$CRED_DIR/backstage-token")
chmod 600 "$CRED_DIR/read-token" "$CRED_DIR/backstage-token"

success "Tokens saved to $CRED_DIR."

# --- K8s Application ---
log "Applying tokens to Control Cluster..."

# Ensure we have a context and environment
if [[ -z "${CONTROL_CONTEXT:-}" ]]; then
  if [ -f "$LAB_ROOT/config/lab.env" ]; then
    source "$LAB_ROOT/config/lab.env"
  else
    error "CONTROL_CONTEXT not found. Please run 'make connect' (bootstrap) and source your lab.env first."
    exit 1
  fi
fi

# 1. Base GitHub Secret (used by platform controllers)
kubectl --context "$CONTROL_CONTEXT" create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl --context "$CONTROL_CONTEXT" apply -f -
kubectl --context "$CONTROL_CONTEXT" create secret generic "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --from-literal=read-token="$READ_TOKEN" \
  --from-literal=backstage-token="$BACKSTAGE_TOKEN" \
  --dry-run=client -o yaml | kubectl --context "$CONTROL_CONTEXT" apply -f -

# 2. Crossplane Module Credentials
log "Configuring Crossplane credentials..."
CREDS_VAL="https://x-access-token:${READ_TOKEN}@github.com"
kubectl --context "$CONTROL_CONTEXT" create secret generic module-git-credentials \
  --namespace crossplane-system \
  --from-literal=credentials="$CREDS_VAL" \
  --dry-run=client -o yaml | kubectl --context "$CONTROL_CONTEXT" apply -f -

# 3. Argo CD Repository Secrets
log "Configuring Argo CD repository access..."
for repo in platform app-deploy; do
  URL="https://github.com/${OWNER}/prel37-${LAB_ID}-${repo}"
  cat <<EOF | kubectl --context "$CONTROL_CONTEXT" apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: repo-${repo}
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: ${URL}
  password: ${READ_TOKEN}
EOF
done

# 4. Argo CD Workload Cluster Secret
log "Configuring Argo CD workload cluster access..."
if [ -f "setup/workload-cluster.yaml" ]; then
  envsubst < "setup/workload-cluster.yaml" | kubectl --context "$CONTROL_CONTEXT" apply -f -
else
  warn "setup/workload-cluster.yaml not found. Skipping cluster secret."
fi

success "All platform secrets applied to Control Cluster."
