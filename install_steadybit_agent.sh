#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Prevents errors in a pipeline from being masked

# Define variables
NAMESPACE="steadybit"
CHART_NAME="steadybit-agent"
HELM_REPO_NAME="steadybit"
HELM_REPO_URL="https://steadybit.github.io/helm-charts"
VALUES_FILE="steadybit/values.yaml"
DASH0_MONITORING_FILE="dash0/dash0-monitoring.yaml"

echo "🚀 Starting Steadybit Agent installation..."

# Ensure Helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Please install Helm and try again."
    exit 1
fi

# Add Steadybit Helm repo
echo "🔹 Adding Steadybit Helm repository..."
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL"

# Update Helm repositories
echo "🔄 Updating Helm repositories..."
helm repo update

# Ensure namespace exists
echo "📌 Ensuring namespace '$NAMESPACE' exists..."
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

# Install Steadybit Agent with values.yaml
echo "🚀 Installing/upgrading Steadybit Agent..."
helm upgrade --install "$CHART_NAME" "$HELM_REPO_NAME/$CHART_NAME" \
    --namespace "$NAMESPACE" \
    --values "$VALUES_FILE"

# Wait for Steadybit Agent to be fully deployed before applying monitoring
echo "⏳ Waiting for Steadybit Agent to be ready..."
while [[ $(kubectl get pods -n "$NAMESPACE" -l app=steadybit-agent -o jsonpath='{.items[*].status.phase}') != "Running" ]]; do
    echo "⏳ Steadybit Agent is not ready yet. Retrying in 5 seconds..."
    sleep 5
done
echo "✅ Steadybit Agent is now running!"

# Apply Dash0 monitoring configuration AFTER the Steadybit Agent is running
if [[ -f "$DASH0_MONITORING_FILE" ]]; then
    echo "📊 Applying Dash0 monitoring configuration..."
    kubectl apply -f "$DASH0_MONITORING_FILE" -n "$NAMESPACE"
    echo "✅ Dash0 monitoring applied successfully!"
else
    echo "⚠️ Dash0 monitoring file '$DASH0_MONITORING_FILE' not found. Skipping..."
fi

echo "✅ Steadybit Agent installation complete with Dash0 monitoring!"
