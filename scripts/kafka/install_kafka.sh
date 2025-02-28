#!/bin/bash
set -e

# Ensure Helm repositories are updated
./scripts/setup_helm_repos.sh

NAMESPACE="kafka"
TIMEOUT=180  # Max wait time in seconds

# Ensure the Kafka namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "🔧 Creating namespace '$NAMESPACE'..."
    kubectl create namespace "$NAMESPACE"
fi

# Deploy Kafka Controller using Helm and controller.yaml
echo "📦 Deploying Kafka Controller..."
helm upgrade --install kafka-controller bitnami/kafka -n "$NAMESPACE" -f helm/kafka/controller.yaml

# Wait for Kafka Controller pod to be ready
echo "⏳ Waiting for Kafka Controller pod to be ready (timeout: ${TIMEOUT}s)..."
if ! kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l app.kubernetes.io/instance=kafka-controller --timeout=${TIMEOUT}s; then
    echo "❌ Kafka Controller pod did not become ready in time. Exiting."
    exit 1
fi
echo "✅ Kafka Controller is running!"

# Deploy Kafka Brokers using Helm and broker.yaml
echo "📦 Deploying Kafka Brokers..."
helm upgrade --install kafka-broker bitnami/kafka -n "$NAMESPACE" -f helm/kafka/broker.yaml

# Wait for Kafka Broker(s) to be ready
echo "⏳ Waiting for Kafka Brokers to be ready (timeout: ${TIMEOUT}s)..."
if ! kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l app.kubernetes.io/instance=kafka-broker --timeout=${TIMEOUT}s; then
    echo "❌ Kafka Brokers did not become ready in time. Exiting."
    exit 1
fi
echo "✅ Kafka Brokers are running!"

# Ensure the Kafka client pod is available for running commands
echo "⏳ Checking for Kafka client pod..."
KAFKA_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=kafka -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
if [[ -z "$KAFKA_POD" ]]; then
    echo "❌ Kafka client pod not found. Exiting."
    exit 1
fi

# Create SASL authentication file for Kafka client
echo "🔑 Configuring SASL authentication..."
cat <<EOF > /tmp/client.properties
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="user1" \
    password="$(kubectl get secret kafka-user-passwords --namespace kafka -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)";
EOF

# Copy SASL authentication file to the Kafka pod
kubectl cp --namespace "$NAMESPACE" /tmp/client.properties "$KAFKA_POD":/tmp/client.properties

# Ensure Kafka brokers are correctly registered with the controller
echo "🔄 Checking Kafka brokers registration..."
kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- \
    kafka-broker-api-versions.sh --bootstrap-server kafka.kafka.svc.cluster.local:9092 \
    --command-config /tmp/client.properties | grep 'Broker'

if [ $? -ne 0 ]; then
    echo "❌ No brokers are registered with the controller. Exiting."
    exit 1
fi
echo "✅ Kafka Brokers are registered with the Controller."

# Create a default topic "prometheus-data"
echo "📌 Creating Kafka topic: prometheus-data..."
kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- \
    kafka-topics.sh --create --topic prometheus-data \
    --bootstrap-server kafka.kafka.svc.cluster.local:9092 \
    --command-config /tmp/client.properties \
    --partitions 1 --replication-factor 1 || \
    echo "⚠️ Topic may already exist."

# Validate that the Kafka service is available before starting port forwarding
echo "⏳ Waiting for Kafka service to be accessible (timeout: ${TIMEOUT}s)..."
for ((i=0; i<TIMEOUT; i+=5)); do
    if kubectl get svc -n "$NAMESPACE" kafka >/dev/null 2>&1; then
        echo "✅ Kafka service is available."
        break
    fi
    echo "🔄 Waiting for Kafka service..."
    sleep 5
done

if ! kubectl get svc -n "$NAMESPACE" kafka >/dev/null 2>&1; then
    echo "❌ Kafka service did not become available in time. Exiting."
    exit 1
fi

# Start port forwarding
echo "🚀 Starting Kafka port forwarding..."
kubectl --namespace "$NAMESPACE" port-forward svc/kafka 9092:9092 >/dev/null 2>&1 &
echo $! > ".kafka_port_forward_pid"
echo "🔗 Kafka is accessible at localhost:9092"

echo "🎉 Kafka installation complete!"