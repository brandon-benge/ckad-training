#!/bin/bash
set -e

echo "🚀 Uninstalling MinIO from the 'minio' namespace..."

# Stop MinIO Port Forwarding if it's running
if [[ -f .minio_port_forward_pid ]]; then
  echo "🛑 Stopping MinIO port forwarding..."
  kill $(cat .minio_port_forward_pid) >/dev/null 2>&1 || true
  rm -f .minio_port_forward_pid
  echo "✅ MinIO port forwarding stopped."
fi

# Uninstall MinIO Helm release
echo "🗑 Removing MinIO Helm release..."
helm uninstall minio -n minio >/dev/null 2>&1 || echo "⚠️ MinIO Helm release not found."

# Wait for pods to be deleted
echo "⏳ Waiting for MinIO pods to terminate..."
attempt=0
max_attempts=20
while kubectl get pods -n minio --no-headers 2>/dev/null | grep -q 'minio'; do
  sleep 5
  attempt=$((attempt + 1))
  if [[ $attempt -ge $max_attempts ]]; then
    echo "❌ MinIO pods did not terminate within 100s. Exiting."
    exit 1
  fi
  echo "🔄 Waiting for MinIO pods to terminate... ($attempt/20)"
done
echo "✅ MinIO pods terminated."

# Wait for MinIO service to be deleted
echo "⏳ Waiting for MinIO service to be removed..."
attempt=0
while kubectl get svc -n minio --no-headers 2>/dev/null | grep -q 'minio'; do
  sleep 5
  attempt=$((attempt + 1))
  if [[ $attempt -ge $max_attempts ]]; then
    echo "❌ MinIO service did not terminate within 100s. Exiting."
    exit 1
  fi
  echo "🔄 Waiting for MinIO service to terminate... ($attempt/20)"
done
echo "✅ MinIO service removed."

# Delete the MinIO namespace if it's empty
if [[ $(kubectl get all -n minio --no-headers 2>/dev/null | wc -l) -eq 0 ]]; then
  echo "🗑 Deleting 'minio' namespace..."
  kubectl delete namespace minio >/dev/null 2>&1 || echo "⚠️ 'minio' namespace already deleted."
  echo "✅ 'minio' namespace deleted."
else
  echo "⚠️ 'minio' namespace is not empty, skipping deletion."
fi

echo "✅ MinIO uninstall completed."