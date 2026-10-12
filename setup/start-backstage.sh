#!/usr/bin/env bash
# Starts the local Backstage runtime (frontend :3000, backend :7007) in the foreground.
set -euo pipefail

LAB_ROOT="${LAB_ROOT:-$HOME/prel37}"
RUNTIME="$LAB_ROOT/runtime/backstage"
TOKEN_FILE="$LAB_ROOT/.credentials/backstage-token"
LAB_JSON="$LAB_ROOT/config/lab.json"

die() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$1" >&2; exit 1; }

[ -d "$RUNTIME" ] || die "Backstage is not installed at $RUNTIME. Run 'make machine-setup' in Skillable, or 'make setup' for a new Azure environment."
[ -s "$TOKEN_FILE" ] || die "Backstage token not found at $TOKEN_FILE. Run 'make auth' first."
[ -f "$LAB_JSON" ] || die "$LAB_JSON not found. Run 'make machine-setup' in Skillable, or 'make setup' for a new Azure environment."
if [ -f "$LAB_ROOT/config/setup.env" ]; then
  source "$LAB_ROOT/config/setup.env"
elif [ -f setup/setup.env ]; then
  source setup/setup.env
fi
[ -n "${OWNER:-}" ] || die "GitHub OWNER is not configured. Run 'make machine-setup' in Skillable, or 'make setup' for a new Azure environment."

LAB_ID="$(jq -r .LAB_ID "$LAB_JSON")"
export LAB_ROOT
export PLATFORM_BROWSER_URL="https://github.com/${OWNER}/prel37-${LAB_ID}-platform"

# Only substitute setup-time values. ${GITHUB_TOKEN} stays literal so Backstage reads it at runtime.
envsubst '${LAB_ROOT} ${PLATFORM_BROWSER_URL}' < src/backstage/app-config.lab.yaml > "$RUNTIME/app-config.local.yaml"
mkdir -p "$LAB_ROOT/.state/backstage"

GITHUB_TOKEN="$(cat "$TOKEN_FILE")"
export GITHUB_TOKEN

printf 'Starting Backstage at http://localhost:3000 (Ctrl+C to stop)...\n'
cd "$RUNTIME"
exec node .yarn/releases/yarn-4.13.0.cjs start
