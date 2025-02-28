#!/bin/bash
set -e

# Uninstall Prometheus and all components

echo "🚀 Uninstalling Prometheus and all components..."
helm uninstall prometheus -n monitoring || true
kubectl delete namespace monitoring || true

echo "✅ Uninstallation complete."

# Stop Grafana Port Forwarding if running
if [ -f .port_forward_pid ]; then
    PID=$(cat .port_forward_pid)
    if ps -p $PID > /dev/null 2>&1; then
        echo "🛑 Stopping Grafana port forwarding..."
        kill $PID || true
    fi
    rm .port_forward_pid
fi

# Stop Prometheus Port Forwarding if running
if [ -f .prometheus_port_forward_pid ]; then
    PID=$(cat .prometheus_port_forward_pid)
    if ps -p $PID > /dev/null 2>&1; then
        echo "🛑 Stopping Prometheus port forwarding..."
        kill $PID || true
    fi
    rm .prometheus_port_forward_pid
fi

echo "✅ Cleanup complete."
