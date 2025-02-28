#!/bin/bash
set -e

# Check if Rancher Desktop is installed
echo "🔍 Checking if Rancher Desktop is installed..."
if ! command -v rdctl &> /dev/null; then
    echo "🚀 Installing Rancher Desktop..."
    brew install --cask rancher
else
    echo "✅ Rancher Desktop is already installed. Skipping installation."
fi

# Check if Rancher Desktop is already running
echo "🔍 Checking if Rancher Desktop is running..."
if ! pgrep -f "Rancher Desktop" > /dev/null; then
    echo "🔄 Starting Rancher Desktop..."
    open -a "Rancher Desktop"
else
    echo "✅ Rancher Desktop is already running. Skipping start."
fi

# Wait for kubectl to return success responses
echo "⏳ Waiting for Rancher Desktop to become ready..."
for i in {1..30}; do
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ Rancher Desktop is now running!"
        break
    fi
    echo "🔄 Waiting for Kubernetes API to respond... ($i/30)"
    sleep 5
done

# If still not ready after the loop, print an error message
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Rancher Desktop did not become ready within the expected time."
    exit 1
fi

# Apply the ensure-containerd-symlink DaemonSet
echo "🔗 Ensuring containerd.sock symlink..."
SCRIPT_DIR=$(dirname "$(realpath "$0")")
"$SCRIPT_DIR/ensure-containerd-symlink.sh"

# Restart port forwarding for all services
echo "🔗 Restart port forwarding for all services..."
"$SCRIPT_DIR/restart_port_forwarding.sh"

echo "✅ Rancher Desktop setup complete!"