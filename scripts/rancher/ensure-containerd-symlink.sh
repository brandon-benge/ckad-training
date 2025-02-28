#!/bin/bash
set -e

echo "🔍 Checking if Kubernetes is running..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed."
    exit 1
fi

if ! kubectl get nodes &> /dev/null; then
    echo "❌ Error: Kubernetes cluster is not accessible. Ensure Rancher Desktop is running."
    exit 1
fi

echo "🔗 Applying DaemonSet to ensure containerd.sock symlink..."

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ensure-containerd-symlink
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: ensure-containerd-symlink
  template:
    metadata:
      labels:
        app: ensure-containerd-symlink
    spec:
      hostPID: true
      containers:
      - name: ensure-containerd-symlink
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          if [ ! -S /run/containerd/containerd.sock ]; then
            echo "Creating containerd.sock symlink..."
            ln -s /run/k3s/containerd/containerd.sock /run/containerd/containerd.sock
          else
            echo "Symlink already exists. No action needed."
          fi
          sleep 10
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-run
          mountPath: /run
      terminationGracePeriodSeconds: 5
      restartPolicy: Always
      volumes:
      - name: host-run
        hostPath:
          path: /run
EOF

echo "✅ Symlink validation DaemonSet applied successfully!"

# Wait for DaemonSet to complete execution
echo "⏳ Waiting for DaemonSet to finish execution..."
sleep 5

# Verify the DaemonSet is running
kubectl get pods -n kube-system | grep ensure-containerd-symlink || true

echo "✅ DaemonSet applied. Symlink should now be in place."