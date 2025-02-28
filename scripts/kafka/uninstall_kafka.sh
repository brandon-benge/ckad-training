#!/bin/bash
set -e

NAMESPACE="kafka"

echo "🚀 Uninstalling Kafka..."
helm uninstall kafka -n "$NAMESPACE" >/dev/null 2>&1 || echo "⚠️ Kafka not found."
kubectl delete namespace "$NAMESPACE" --ignore-not-found >/dev/null 2>&1
echo "✅ Kafka removed successfully."

# Stop port forwarding if running
if [[ -f ".kafka_port_forward_pid" ]]; then
    echo "🛑 Stopping Kafka port forwarding..."
    kill $(cat ".kafka_port_forward_pid") >/dev/null 2>&1 || true
    rm -f ".kafka_port_forward_pid"
fi

echo "✅ Cleanup complete."
