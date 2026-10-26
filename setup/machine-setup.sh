#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fast-track.sh"
trap 'printf "Skillable setup failed at line %s. Fix the reported error and rerun make machine-setup.\n" "$LINENO" >&2' ERR

LAB_TERRAFORM_SOURCE="${LAB_TERRAFORM_SOURCE:-/mnt/c/terraform}"
TF_OUTPUT_DIR=""
LAB_JSON_TMP=""

cleanup() {
  if [[ -n "$LAB_JSON_TMP" ]]; then
    rm -f -- "$LAB_JSON_TMP"
  fi
  if [[ -n "$TF_OUTPUT_DIR" ]]; then
    rm -f -- "$TF_OUTPUT_DIR/terraform.tfstate"
    rmdir -- "$TF_OUTPUT_DIR"
  fi
}
trap cleanup EXIT

load_preprovisioned_outputs() {
  local state_file="$LAB_TERRAFORM_SOURCE/terraform.tfstate"
  [ -s "$state_file" ] ||
    { error "No saved Terraform state at $state_file. Ask the lab organizer to complete provisioning in C:\\terraform."; exit 1; }

  log "Reading the pre-provisioned lab outputs. Azure infrastructure will not be changed."
  TF_OUTPUT_DIR="$(mktemp -d "$LAB_ROOT/.state/terraform-output.XXXXXX")"
  LAB_JSON_TMP="$(mktemp "$LAB_ROOT/config/lab.json.XXXXXX")"
  # Only the state is needed. Windows provider binaries and backend metadata stay on C:.
  cp -- "$state_file" "$TF_OUTPUT_DIR/terraform.tfstate"
  TF_WORKSPACE=default TF_DATA_DIR="$TF_OUTPUT_DIR/.terraform" \
    terraform -chdir="$TF_OUTPUT_DIR" output -json lab > "$LAB_JSON_TMP"
  rm -- "$TF_OUTPUT_DIR/terraform.tfstate"
  rmdir -- "$TF_OUTPUT_DIR"
  TF_OUTPUT_DIR=""

  jq -e '.LAB_ID | type == "string" and test("^[a-z0-9]{4,12}$")' "$LAB_JSON_TMP" >/dev/null
  if [ -f "$LAB_ROOT/config/lab.json" ]; then
    [ "$(jq -c '[.LAB_ID,.AZURE_SUBSCRIPTION_ID,.AZURE_TENANT_ID]' "$LAB_ROOT/config/lab.json")" = \
      "$(jq -c '[.LAB_ID,.AZURE_SUBSCRIPTION_ID,.AZURE_TENANT_ID]' "$LAB_JSON_TMP")" ] ||
      { error "$LAB_ROOT already contains another lab. Use a separate LAB_ROOT."; exit 1; }
  fi
  # Bootstrap validates every required output and the WSL Azure tenant/subscription.
  bash setup/bootstrap.sh "$LAB_JSON_TMP"
  mv -- "$LAB_JSON_TMP" "$LAB_ROOT/config/lab.json"
  LAB_JSON_TMP=""
  source "$LAB_ROOT/config/lab.env"
}

collect_lab_inputs() {
  local config_file="$LAB_ROOT/config/setup.env"
  if [ -f "$config_file" ]; then
    log "Loading the saved GitHub setup from $config_file."
    source "$config_file"
    [[ -n "${OWNER:-}" && -n "${GIT_NAME:-}" && -n "${GIT_EMAIL:-}" ]] ||
      { error "$config_file must contain OWNER, GIT_NAME, and GIT_EMAIL."; exit 1; }
    gh auth status --hostname github.com
  else
    collect_github_inputs
    jq -nr 'env | {GITHUB_USER,GITHUB_ORG,OWNER,GIT_NAME,GIT_EMAIL} |
      to_entries[] | "export " + .key + "=" + (.value | @sh)' > "$config_file"
  fi
  export OWNER GIT_NAME GIT_EMAIL
}

main() {
  validate_lab_paths
  cd "$LAB_SOURCE"
  check_tools
  mkdir -p "$LAB_ROOT/config" "$LAB_ROOT/runtime" "$LAB_ROOT/.state"
  load_preprovisioned_outputs
  collect_lab_inputs
  setup_repos
  install_platform_software
  setup_backstage
  print_next_steps
}

main "$@"
