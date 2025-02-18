#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Prevents errors in a pipeline from being masked

# Define variables
NAMESPACE="dash0-system"
CHART_NAME="dash0-operator"
HELM_REPO_NAME="dash0-operator"
HELM_REPO_URL="https://dash0hq.github.io/dash0-operator"
VALUES_FILE="dash0/values.yaml"
SECRET_NAME="dash0-authorization-secret"
SECRET_TOKEN="auth_IpsjnhKJ72pLUXnqmcaWbHG49cQ4bAB6"  # Replace with your actual token

# Dash0 monitoring configuration file
DASH0_MONITORING_FILE="dash0/dash0-monitoring.yaml"

echo "🚀 Starting Dash0 Operator installation..."

# Ensure Helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Please install Helm and try again."
    exit 1
fi

# Add Dash0 Operator Helm repo
echo "🔹 Adding Dash0 Operator Helm repository..."
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL"

# Update Helm repositories
echo "🔄 Updating Helm repositories..."
helm repo update

# Ensure namespace exists
echo "📌 Ensuring namespace '$NAMESPACE' exists..."
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

# Create or update the Dash0 authorization secret
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "🔐 Secret '$SECRET_NAME' already exists, updating it..."
    kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
    sleep 2
fi
echo "🔐 Creating Dash0 authorization secret..."
kubectl create secret generic "$SECRET_NAME" --namespace "$NAMESPACE" --from-literal=token="$SECRET_TOKEN"

# Deploy Dash0 Operator with values.yaml
echo "🚀 Installing/upgrading Dash0 Operator..."
helm upgrade --install "$CHART_NAME" "$HELM_REPO_NAME/$CHART_NAME" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --values "$VALUES_FILE"

# Wait for Dash0 Operator to be fully deployed before applying monitoring
echo "⏳ Waiting for Dash0 Operator to be ready..."
while [[ $(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=dash0-operator -o jsonpath='{.items[*].status.phase}') != "Running" ]]; do
    echo "⏳ Dash0 Operator is not ready yet. Retrying in 5 seconds..."
    sleep 5
done
echo "✅ Dash0 Operator is now running!"

# Apply Dash0 monitoring configuration AFTER the operator is running
if [[ -f "$DASH0_MONITORING_FILE" ]]; then
    echo "📊 Applying Dash0 monitoring configuration..."
    kubectl apply -f "$DASH0_MONITORING_FILE" -n "$NAMESPACE"
    echo "✅ Dash0 monitoring applied successfully!"
else
    echo "⚠️ Dash0 monitoring file '$DASH0_MONITORING_FILE' not found. Skipping..."
fi

echo "✅ Dash0 Operator installation complete with monitoring!"
