#!/bin/bash
set -e

echo "🔄 Checking and restarting port forwarding for necessary services..."

# Function to check if a Kubernetes service exists
service_exists() {
  local namespace=$1
  local service=$2
  kubectl get svc -n "$namespace" "$service" >/dev/null 2>&1
}

# Function to wait for a service to be available
wait_for_service() {
  local namespace=$1
  local service_name=$2
  local port=$3
  echo "⏳ Waiting for service '$service_name' in namespace '$namespace' to become available on port $port..."

  for i in {1..30}; do
    if kubectl get svc -n "$namespace" "$service_name" >/dev/null 2>&1; then
      echo "✅ Service '$service_name' is available."
      return 0
    fi
    sleep 5
  done

  echo "❌ Timed out waiting for service '$service_name'."
  exit 1
}

# Function to start port forwarding
start_port_forward() {
  local namespace=$1
  local service=$2
  local local_port=$3
  local remote_port=$4
  local pid_file=$5

  # Kill existing port-forward process if running
  if [[ -f "$pid_file" ]]; then
    echo "🛑 Stopping existing port forwarding for $service..."
    kill $(cat "$pid_file") >/dev/null 2>&1 || true
    rm -f "$pid_file"
  fi

  # Wait for the service to be available before starting port forwarding
  wait_for_service "$namespace" "$service" "$remote_port"

  # Start port forwarding in background
  echo "🚀 Starting port forwarding for $service..."
  kubectl --namespace "$namespace" port-forward svc/"$service" "$local_port":"$remote_port" >/dev/null 2>&1 &
  echo $! > "$pid_file"
}

# Ensure Kubernetes is accessible
if ! kubectl get nodes >/dev/null 2>&1; then
  echo "❌ Kubernetes cluster is not accessible. Make sure Rancher is running."
  exit 1
fi

# Restart port forwarding for MinIO
if service_exists "minio" "minio"; then
  start_port_forward "minio" "minio" 9000 9000 ".minio_port_forward_pid"
  start_port_forward "minio" "minio" 9001 9001 ".minio_console_port_forward_pid"
else
  echo "⚠️ MinIO service is not running, skipping port forwarding."
fi

# Restart port forwarding for Prometheus
if service_exists "monitoring" "prometheus-kube-prometheus-prometheus"; then
  start_port_forward "monitoring" "prometheus-kube-prometheus-prometheus" 9090 9090 ".prometheus_port_forward_pid"
else
  echo "⚠️ Prometheus service is not running, skipping port forwarding."
fi

# Restart port forwarding for Grafana
if service_exists "monitoring" "prometheus-grafana"; then
  start_port_forward "monitoring" "prometheus-grafana" 3000 80 ".grafana_port_forward_pid"
else
  echo "⚠️ Grafana service is not running, skipping port forwarding."
fi

# Restart port forwarding for Thanos Query
if service_exists "thanos" "thanos-query"; then
  start_port_forward "thanos" "thanos-query" 10902 9090 ".thanos_port_forward_pid"
else
  echo "⚠️ Thanos Query service is not running, skipping port forwarding."
fi

echo "✅ Port forwarding restarted successfully."