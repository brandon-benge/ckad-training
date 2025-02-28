#!/bin/bash
set -e

# Ensure Helm repositories are updated
./scripts/setup_helm_repos.sh

echo "🚀 Installing Thanos in the 'thanos' namespace..."

# Ensure the namespace exists
kubectl get ns thanos >/dev/null 2>&1 || kubectl create namespace thanos

# Copy the Thanos object storage secret from 'minio' to 'thanos'
if ! kubectl get secret thanos-objstore-secret -n thanos >/dev/null 2>&1; then
    echo "🔄 Copying Thanos object storage secret to thanos namespace..."
    kubectl get secret thanos-objstore-secret -n minio -o yaml | \
        sed 's/namespace: minio/namespace: thanos/' | kubectl apply -f -
    echo "✅ Thanos object storage secret copied successfully."
else
    echo "✅ Thanos object storage secret already exists in thanos namespace."
fi

# Install Thanos only if it's not already installed
if ! helm list -n thanos | grep -q "thanos"; then
    echo "📦 Installing Thanos with Helm..."
    helm install thanos bitnami/thanos -n thanos  \
        -f helm/thanos/values.yaml || { echo "❌ Helm installation failed"; exit 1; }
    echo "✅ Thanos installed successfully!"
else
    echo "✅ Thanos is already installed. Skipping Helm installation."
fi

# Wait for Thanos Store Gateway to be ready
echo "⏳ Waiting for Thanos Store Gateway to be ready..."
kubectl wait --for=condition=ready pod -n thanos -l app.kubernetes.io/component=storegateway --timeout=120s || { echo "❌ Thanos Store Gateway is not ready"; exit 1; }

# Restart Thanos Store Gateway to ensure it picks up the correct config
echo "🔄 Restarting Thanos Store Gateway..."
kubectl delete pod -n thanos -l app.kubernetes.io/component=storegateway --ignore-not-found=true

# Wait for Thanos Query service to be available
echo "⏳ Waiting for Thanos Query service to become available..."
max_attempts=30
attempt=0
while true; do
  if kubectl get svc -n thanos thanos-query >/dev/null 2>&1; then
    echo "✅ Thanos Query service is available."
    break
  fi
  attempt=$((attempt + 1))
  if [[ $attempt -ge $max_attempts ]]; then
    echo "❌ Thanos Query service did not become available within the expected time. Exiting."
    exit 1
  fi
  echo "🔄 Still waiting for Thanos Query service... ($attempt/$max_attempts)"
  sleep 5
done

# Start Thanos Query port forwarding
echo "🚀 Starting Thanos Query port forwarding..."
kubectl --namespace thanos port-forward svc/thanos-query 10902:9090 >/dev/null 2>&1 &
echo $! > .thanos_port_forward_pid

echo "🔗 Thanos Query is now accessible at http://localhost:10902"