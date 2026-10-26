#!/usr/bin/env bash
# Load exported Terraform outputs and refresh access to the two prepared clusters.
set -euo pipefail
umask 077
trap 'printf "Bootstrap failed at line %s. Fix the reported error and rerun.\n" "$LINENO" >&2' ERR
export LAB_ROOT="${LAB_ROOT:-$HOME/prel37}"
[[ "$LAB_ROOT" == /* && "$LAB_ROOT" != / && "$LAB_ROOT" != "$HOME" ]] ||
  { printf 'Use a dedicated absolute LAB_ROOT directory.\n' >&2; exit 1; }
mkdir -p "$LAB_ROOT/config" "$LAB_ROOT/.state"
environment="$(mktemp "$LAB_ROOT/config/lab.env.XXXXXX")"
trap 'rm -f -- "$environment"' EXIT

# Select known fields and quote values, never evaluate raw JSON as shell code.
jq -er '{LAB_ID,AZURE_SUBSCRIPTION_ID,AZURE_TENANT_ID,AZURE_LOCATION,AKS_RESOURCE_GROUP,
  CONTROL_CLUSTER_NAME,AKS_CLUSTER_NAME,WORKLOAD_CLUSTER_ID,WORKLOAD_SERVER,WORKLOAD_CA,
  PROVISIONER_CLIENT_ID,ARGO_CLIENT_ID,MODEL_RESOURCE_ID,MODEL_ENDPOINT,MODEL_DEPLOYMENT,
  WORKLOAD_OIDC_ISSUER,LOG_ANALYTICS_WORKSPACE_ID,AZURE_MONITOR_WORKSPACE_ID,
  CLUSTER_OPERATOR_OBJECT_IDS,STATE_ACCOUNT,STATE_CONTAINER,STATE_KEY} |
  if all(.[]; type == "string" and length > 0)
  then to_entries[] | "export " + .key + "=" + (.value | @sh)
  else error("lab.json must contain the nonempty string outputs from terraform output -json lab") end' \
  "${1:-$LAB_ROOT/config/lab.json}" > "$environment"
source "$environment"
[[ "$(az account show --query id -o tsv)" == "$AZURE_SUBSCRIPTION_ID" ]] ||
  { printf 'Select the assigned Azure subscription before running bootstrap.\n' >&2; exit 1; }
[[ "$(az account show --query tenantId -o tsv)" == "$AZURE_TENANT_ID" ]] ||
  { printf 'Sign in to the assigned Azure tenant before running bootstrap.\n' >&2; exit 1; }

export KUBECONFIG="$LAB_ROOT/.state/kubeconfig"
export CONTROL_CONTEXT=prel37-control AKS_CONTEXT=prel37-workload
# The worked example team and application. Docs commands use these so the same steps fit any vended team.
team="${TEAM:-}"
# APP_NAME can be inherited from unrelated tools; only accept an explicit lab override.
app_name="${LAB_APP_NAME:-}"
app_env="${APP_ENV:-}"
if [[ -f "$LAB_ROOT/config/lab.env" ]]; then
  if [[ -z "$team" ]]; then
    team="$(source "$LAB_ROOT/config/lab.env" && printf '%s' "${TEAM:-}")"
  fi
  if [[ -z "$app_name" ]]; then
    app_name="$(unset APP_NAME; source "$LAB_ROOT/config/lab.env" && printf '%s' "${APP_NAME:-}")"
  fi
  if [[ -z "$app_env" ]]; then
    app_env="$(source "$LAB_ROOT/config/lab.env" && printf '%s' "${APP_ENV:-}")"
  fi
fi
export TEAM="${team:-beans}" APP_NAME="${app_name:-fourth-coffee}"
export APP_ENV="${app_env:-$TEAM-dev}"
jq -nr 'env | {LAB_ROOT,KUBECONFIG,CONTROL_CONTEXT,AKS_CONTEXT,TEAM,APP_NAME,APP_ENV} |
  to_entries[] | "export " + .key + "=" + (.value | @sh)' >> "$environment"
az aks get-credentials --subscription "$AZURE_SUBSCRIPTION_ID" \
  -g "$AKS_RESOURCE_GROUP" -n "$CONTROL_CLUSTER_NAME" \
  --file "$KUBECONFIG" --context "$CONTROL_CONTEXT" --overwrite-existing
az aks get-credentials --subscription "$AZURE_SUBSCRIPTION_ID" \
  -g "$AKS_RESOURCE_GROUP" -n "$AKS_CLUSTER_NAME" \
  --file "$KUBECONFIG" --context "$AKS_CONTEXT" --overwrite-existing
kubelogin convert-kubeconfig --login azurecli --kubeconfig "$KUBECONFIG"
mv "$environment" "$LAB_ROOT/config/lab.env"
printf 'Environment ready. Run in this terminal:\nsource %q\n' "$LAB_ROOT/config/lab.env"
