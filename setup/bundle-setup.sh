#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fast-track.sh"
trap 'printf "Bundle setup failed at line %s. Fix the reported error and rerun make setup.\n" "$LINENO" >&2' ERR

[ -f "$LAB_SOURCE/.lab-bundle" ] ||
  { error "This setup path is only for an extracted lab bundle."; exit 1; }
validate_lab_paths
cd "$LAB_SOURCE"
state_file="${LAB_TERRAFORM_SOURCE:-/mnt/c/terraform}/terraform.tfstate"
if [[ -e "$state_file" || -L "$state_file" ]]; then
  # Existing but invalid state must fail in machine-setup, not become image preparation.
  exec bash setup/machine-setup.sh
fi

log "No Terraform state at $state_file. Preparing the VM only; Azure will not be provisioned."
for path in config/lab.json config/lab.env config/setup.env .credentials .state/kubeconfig \
  .state/backstage platform app-deploy runtime/backstage/app-config.local.yaml; do
  if [[ -e "$LAB_ROOT/$path" || -L "$LAB_ROOT/$path" ]]; then
    error "$LAB_ROOT/$path already contains lab-specific configuration or work. Use a fresh VM for a reusable snapshot; use make connect to resume a configured lab."
    exit 1
  fi
done
check_tools
prepare_backstage
success "Backstage source and dependencies are prepared. No Terraform state was copied or loaded, and no learner accounts were configured."
printf 'Before snapshotting, remove any preparation sign-ins or credentials from the VM.\n'
printf 'After Skillable provisions C:\\terraform\\terraform.tfstate, sign in with the assigned accounts and rerun make setup here.\n'
