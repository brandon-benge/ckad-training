#!/bin/bash
set -e

echo "🚀 Uninstalling Thanos..."

helm uninstall thanos -n thanos >/dev/null 2>&1
kubectl delete namespace thanos --ignore-not-found >/dev/null 2>&1

# Stop port forwarding
if [[ -f .thanos_port_forward_pid ]]; then
  echo "🛑 Stopping Thanos Query port forwarding..."
  kill $(cat .thanos_port_forward_pid) || true
  rm -f .thanos_port_forward_pid
fi

echo "✅ Thanos removed successfully."
