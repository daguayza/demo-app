#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Prevents errors in a pipeline from being masked

# Define variables
NAMESPACE="observability"
HELM_REPO_ELASTIC="elastic"
HELM_REPO_GRAFANA="grafana"
HELM_REPO_JAEGER="jaegertracing"

# Values file paths (all under observability folder)
VALUES_ELASTIC="observability/elk-values.yaml"
VALUES_GRAFANA="observability/grafana-values.yaml"
VALUES_JAEGER="observability/jaeger-values.yaml"

# Dash0 monitoring configuration file
DASH0_MONITORING_FILE="dash0/dash0-monitoring.yaml"

echo "🚀 Starting Observability Stack installation..."

# Ensure Helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Please install Helm and try again."
    exit 1
fi

# Ensure namespace exists and apply Dash0 monitoring immediately
echo "📌 Ensuring namespace '$NAMESPACE' exists..."
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    kubectl create namespace "$NAMESPACE"
    echo "✅ Namespace '$NAMESPACE' created!"

    # Apply Dash0 monitoring configuration immediately after namespace creation
    if [[ -f "$DASH0_MONITORING_FILE" ]]; then
        echo "📊 Applying Dash0 monitoring configuration..."
        kubectl apply -f "$DASH0_MONITORING_FILE" -n "$NAMESPACE"
        echo "✅ Dash0 monitoring applied successfully!"
    else
        echo "⚠️ Dash0 monitoring file '$DASH0_MONITORING_FILE' not found. Skipping..."
    fi
else
    echo "✅ Namespace '$NAMESPACE' already exists."
fi

# Add Helm repositories
echo "🔹 Adding Helm repositories..."
helm repo add "$HELM_REPO_ELASTIC" https://helm.elastic.co
helm repo add "$HELM_REPO_GRAFANA" https://grafana.github.io/helm-charts
helm repo add "$HELM_REPO_JAEGER" https://jaegertracing.github.io/helm-charts
helm repo update

# Function to delete Helm releases if they exist
delete_if_exists() {
    local release=$1
    if helm list -n "$NAMESPACE" | grep -q "$release"; then
        echo "🗑️  Deleting existing Helm release: $release..."
        helm uninstall "$release" --namespace "$NAMESPACE"
        sleep 5  # Give Kubernetes time to clean up resources
    fi
}

# Install Grafana and Jaeger first
delete_if_exists "grafana"
echo "📊 Deploying Grafana..."
helm upgrade --install grafana "$HELM_REPO_GRAFANA/grafana" \
    --namespace "$NAMESPACE" --values "$VALUES_GRAFANA"

delete_if_exists "jaeger"
echo "🔍 Deploying Jaeger..."
helm upgrade --install jaeger "$HELM_REPO_JAEGER/jaeger" \
    --namespace "$NAMESPACE" --values "$VALUES_JAEGER"

# Deploy Elasticsearch, Logstash, and Kibana (ELK)
delete_if_exists "elasticsearch"
echo "📦 Deploying Elasticsearch..."
helm upgrade --install elasticsearch "$HELM_REPO_ELASTIC/elasticsearch" \
    --namespace "$NAMESPACE" --values "$VALUES_ELASTIC"

# delete_if_exists "logstash"
# echo "📦 Deploying Logstash..."
# helm upgrade --install logstash "$HELM_REPO_ELASTIC/logstash" \
#     --namespace "$NAMESPACE"

# delete_if_exists "kibana"
# echo "📦 Deploying Kibana..."
# helm upgrade --install kibana "$HELM_REPO_ELASTIC/kibana" \
#     --namespace "$NAMESPACE"

echo "✅ Observability Stack installation complete with Dash0 monitoring!"
