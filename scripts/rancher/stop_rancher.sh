#!/bin/bash
set -e

echo "🔄 Stopping Rancher Desktop..."

# Quit Rancher Desktop using AppleScript (for macOS)
osascript -e 'quit app "Rancher Desktop"'

# Ensure all background processes related to Rancher are stopped
echo "🛑 Stopping Rancher Desktop background processes..."
pgrep -f "rancher-desktop" | xargs kill -9 || true

echo "✅ Rancher Desktop has been stopped."
