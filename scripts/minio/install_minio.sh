#!/bin/bash
set -e

# Ensure Helm repositories are updated
./scripts/setup_helm_repos.sh

echo "🚀 Installing MinIO in the 'minio' namespace..."

helm install minio bitnami/minio -n minio --create-namespace \
    -f helm/minio/values.yaml >/dev/null 2>&1

echo "✅ MinIO installed successfully!"

# Wait for MinIO pod to be ready
echo "⏳ Waiting for MinIO pod to be ready..."
kubectl wait --for=condition=ready pod -n minio -l app.kubernetes.io/name=minio --timeout=120s

# Get MinIO pod name
MINIO_POD=$(kubectl get pod -n minio -l app.kubernetes.io/name=minio -o jsonpath="{.items[0].metadata.name}")

# Ensure MinIO storage is writable before proceeding (max 12 attempts = 60s)
echo "⏳ Waiting for MinIO storage to be writable..."
attempt=0
max_attempts=12
while true; do
  sleep 5  # Sleep before checking the condition
  if kubectl exec -n minio "$MINIO_POD" -- sh -c "touch /bitnami/minio/data/testfile && rm -f /bitnami/minio/data/testfile" >/dev/null 2>&1; then
    break
  fi
  attempt=$((attempt + 1))
  if [[ $attempt -ge $max_attempts ]]; then
    echo "❌ MinIO storage did not become writable within 60s. Exiting."
    exit 1
  fi
  echo "🔄 MinIO storage not writable yet. Retrying..."
done
echo "✅ MinIO storage is writable."

# Ensure MinIO service is accessible
echo "⏳ Waiting for MinIO service to be available..."
attempt=0
while true; do
  sleep 5  # Sleep before checking the condition
  if kubectl get svc -n minio minio >/dev/null 2>&1; then
    break
  fi
  attempt=$((attempt + 1))
  if [[ $attempt -ge $max_attempts ]]; then
    echo "❌ MinIO service did not become available within 60s. Exiting."
    exit 1
  fi
  echo "🔄 MinIO service not available yet. Retrying..."
done
echo "✅ MinIO service is available."

# Ensure MinIO pod is running and all containers are ready
echo "⏳ Ensuring MinIO pod and all containers are ready..."
attempt=0
while true; do
  sleep 5  # Sleep before checking the condition
  pod_status=$(kubectl get pod "$MINIO_POD" -n minio -o jsonpath='{.status.phase}')
  container_status=$(kubectl get pod "$MINIO_POD" -n minio -o jsonpath='{.status.containerStatuses[*].ready}')

  if [[ "$pod_status" == "Running" && "$container_status" != *"false"* ]]; then
    break
  fi

  attempt=$((attempt + 1))
  if [[ $attempt -ge $max_attempts ]]; then
    echo "❌ MinIO pod did not become ready within 60s. Exiting."
    exit 1
  fi
  echo "🔄 MinIO pod is not fully ready yet. Retrying..."
done
echo "✅ MinIO pod is running and all containers are ready."

# Configure MinIO for Thanos
echo "🔧 Configuring MinIO for Thanos..."
kubectl exec -n minio "$MINIO_POD" -- mc alias set myminio http://localhost:9000 minio minio123

# Ensure bucket creation only happens when storage is ready
echo "⏳ Creating MinIO bucket..."
kubectl exec -n minio "$MINIO_POD" -- mc mb myminio/thanos-bucket || echo "⚠️ MinIO bucket already exists."

# Create object storage secret for Thanos before installation
echo "🔧 Creating object storage secret for Thanos..."
kubectl create secret generic thanos-objstore-secret -n minio \
  --from-literal=objstore.yml="$(cat <<EOF
type: S3
config:
  bucket: "thanos-bucket"
  endpoint: "minio.minio.svc.cluster.local:9000"
  access_key: "minio"
  secret_key: "minio123"
  insecure: true
EOF
)" --dry-run=client -o yaml | kubectl apply -f - || { echo "❌ Failed to create Thanos object storage secret"; exit 1; }

echo "✅ Thanos object storage secret configured."

# 🆕 Start MinIO Port Forwarding only after confirming service and pod readiness
echo "🚀 Starting MinIO port forwarding..."
kubectl --namespace minio port-forward svc/minio 9001:9001 >/dev/null 2>&1 &
echo $! > .minio_port_forward_pid
echo "🔗 MinIO is now accessible at http://localhost:9001"

echo "✅ MinIO setup completed."