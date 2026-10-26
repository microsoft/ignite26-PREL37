#!/usr/bin/env bash
# Opens the Argo CD UI at https://localhost:8443 through a loopback tunnel, in the foreground.
set -euo pipefail

LAB_ROOT="${LAB_ROOT:-$HOME/prel37}"
LAB_ENV="$LAB_ROOT/config/lab.env"

if [ -z "${CONTROL_CONTEXT:-}" ]; then
  [ -f "$LAB_ENV" ] || { echo "CONTROL_CONTEXT not set. Run 'make connect' first." >&2; exit 1; }
  source "$LAB_ENV"
fi

PASSWORD="$(kubectl --context "$CONTROL_CONTEXT" -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"

printf 'Argo CD: https://localhost:8443 (Ctrl+C to stop)\n'
printf '  user: admin\n'
[ -n "$PASSWORD" ] && printf '  password: %s\n' "$PASSWORD"
exec kubectl --context "$CONTROL_CONTEXT" -n argocd port-forward svc/argocd-server 8443:443 --address 127.0.0.1
