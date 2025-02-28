#!/bin/bash
set -e

echo "🚀 Setting up Helm repositories..."

helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1
helm repo add trino https://trinodb.github.io/charts >/dev/null 2>&1

helm repo update >/dev/null 2>&1

echo "✅ Helm repositories updated!"
