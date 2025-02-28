#!/bin/bash
set -e

# Ensure Helm repositories are updated
./scripts/setup_helm_repos.sh

# Ensure the monitoring namespace exists
echo "🔧 Ensuring 'monitoring' namespace exists..."
kubectl get ns monitoring >/dev/null 2>&1 || kubectl create namespace monitoring

# Copy the Thanos object storage secret from 'minio' to 'monitoring'
if ! kubectl get secret thanos-objstore-secret -n monitoring >/dev/null 2>&1; then
    echo "🔄 Copying Thanos object storage secret to monitoring namespace..."
    kubectl get secret thanos-objstore-secret -n minio -o yaml | \
        sed 's/namespace: minio/namespace: monitoring/' | kubectl apply -f -
    echo "✅ Thanos object storage secret copied successfully."
else
    echo "✅ Thanos object storage secret already exists in monitoring namespace."
fi

# Deploy Prometheus using community helm
echo "🚀 Deploying the default Prometheus install..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack -n monitoring -f helm/prometheus/values.yaml >/dev/null 2>&1

echo "✅ Prometheus, Node Exporter, Kube-State-Metrics, Grafana, and Operator deployed successfully."

# Retrieve Grafana Admin Password
echo "🔑 Grafana admin password: $(kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d)"

# Function to wait for a service to be available
wait_for_service() {
  local namespace=$1
  local service=$2
  local port=$3

  echo "⏳ Waiting for service '$service' in namespace '$namespace' to become available on port $port..."

  for i in {1..30}; do
    if kubectl get svc -n "$namespace" "$service" >/dev/null 2>&1; then
      echo "✅ Service '$service' is available."
      return 0
    fi
    sleep 5
  done

  echo "❌ Timed out waiting for service '$service'."
  return 1
}

# Function to wait for all containers in a pod to be ready
wait_for_pod_ready() {
  local namespace=$1
  local pod_name_pattern=$2  # Using a pattern match instead of strict label filtering

  echo "⏳ Waiting for pod matching '$pod_name_pattern' in namespace '$namespace' to be fully ready..."

  for i in {1..30}; do
    # Find the actual Prometheus pod name dynamically
    local prometheus_pod
    prometheus_pod=$(kubectl get pods -n "$namespace" --no-headers | awk -v pattern="$pod_name_pattern" '$1 ~ pattern {print $1; exit}')

    if [[ -z "$prometheus_pod" ]]; then
      echo "⏳ No matching pod found yet... waiting. ($i/30)"
      sleep 5
      continue
    fi

    # Check if the pod has 3 containers and if all are ready
    local total_containers
    total_containers=$(kubectl get pod "$prometheus_pod" -n "$namespace" -o jsonpath='{.status.containerStatuses[*].ready}' 2>/dev/null | wc -w)

    local ready_containers
    ready_containers=$(kubectl get pod "$prometheus_pod" -n "$namespace" -o jsonpath='{.status.containerStatuses[?(@.ready==true)]}' 2>/dev/null | wc -w)

    if [[ "$total_containers" -lt 3 ]]; then
      echo "⏳ Waiting for all containers to be created in '$prometheus_pod'... ($i/30)"
      sleep 5
      continue
    fi

    if [[ "$ready_containers" -eq "$total_containers" && "$ready_containers" -eq 3 ]]; then
      echo "✅ All 3 containers in '$prometheus_pod' are fully ready!"
      return 0
    else
      echo "⏳ Containers starting in '$prometheus_pod' ($ready_containers/3 ready)... ($i/30)"
      sleep 5
    fi
  done

  echo "❌ Timed out waiting for all containers in '$pod_name_pattern' to be fully ready."
  return 1
}

# Start Grafana Port Forwarding after it's available
if wait_for_service "monitoring" "prometheus-grafana" 80; then
  echo "🚀 Starting Grafana port forwarding..."
  kubectl --namespace monitoring port-forward svc/prometheus-grafana 3000:80 >/dev/null 2>&1 &
  echo $! > .port_forward_pid
  echo "🔗 Grafana is now accessible at http://localhost:3000"
else
  echo "⚠️ Skipping Grafana port forwarding due to service unavailability."
fi

# Wait for all Prometheus containers to be ready before port forwarding
if wait_for_service "monitoring" "prometheus-kube-prometheus-prometheus" 9090 && \
   wait_for_pod_ready "monitoring" "prometheus-kube-prometheus-prometheus"; then
  echo "🚀 Starting Prometheus port forwarding..."
  kubectl --namespace monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 >/dev/null 2>&1 &
  echo $! > .prometheus_port_forward_pid
  echo "🔗 Prometheus is now accessible at http://localhost:9090"
else
  echo "⚠️ Skipping Prometheus port forwarding due to service unavailability or pod readiness issues."
fi