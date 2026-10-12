#!/usr/bin/env bash
# Opens the application at http://<team>.localhost:8080 through the shared Gateway's ClusterIP service, in the foreground.
# Each team's HTTPRoute matches its own <team>.localhost host, so one tunnel serves every vended team.
set -euo pipefail

LAB_ROOT="${LAB_ROOT:-$HOME/prel37}"
LAB_ENV="$LAB_ROOT/config/lab.env"

if [ -z "${AKS_CONTEXT:-}" ]; then
  [ -f "$LAB_ENV" ] || { echo "AKS_CONTEXT not set. Run 'make connect' first." >&2; exit 1; }
  source "$LAB_ENV"
fi

SERVICE="$(kubectl --context "$AKS_CONTEXT" -n platform-gateway get service \
  -l gateway.networking.k8s.io/gateway-name=tenants -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
[ -n "$SERVICE" ] || { echo "Gateway service for 'tenants' not found in platform-gateway yet. Check the HTTPRoute and try again." >&2; exit 1; }

printf 'Application: http://%s.localhost:8080 via service/%s (Ctrl+C to stop)\n' "${TEAM:-beans}" "$SERVICE"
exec kubectl --context "$AKS_CONTEXT" -n platform-gateway port-forward "service/$SERVICE" 8080:80 --address 127.0.0.1
