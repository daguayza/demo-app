#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Prevents errors in a pipeline from being masked

# Define variables
NAMESPACE="demo"
MICROSERVICES_PATH="microservices-demo"
DASH0_MONITORING_FILE="dash0/dash0-monitoring.yaml"

echo "🚀 Starting Okteto Microservices installation..."

# Ensure Minikube is running
if ! minikube status | grep -q "Running"; then
    echo "❌ Minikube is not running. Please start Minikube first."
    exit 1
fi

# Set up Minikube Docker environment
echo "🐳 Using Minikube's Docker daemon..."
eval $(minikube -p minikube docker-env)

# Ensure the namespace exists and apply Dash0 monitoring immediately
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

# Build Docker images inside Minikube's Docker daemon
echo "🛠️ Building Docker images..."
docker build -t demo/vote-image:latest "$MICROSERVICES_PATH/vote"
docker build -t demo/result-image:latest "$MICROSERVICES_PATH/result"
docker build -t demo/worker-image:latest "$MICROSERVICES_PATH/worker"

# Deploy PostgreSQL using Helm
echo "📦 Deploying PostgreSQL..."
helm upgrade --install postgresql oci://registry-1.docker.io/bitnamicharts/postgresql \
    -f "$MICROSERVICES_PATH/postgresql/values.yml" --version 13.4.4 --namespace "$NAMESPACE"

# Deploy Kafka using Helm
echo "📦 Deploying Kafka..."
helm upgrade --install kafka oci://registry-1.docker.io/bitnamicharts/kafka \
    -f "$MICROSERVICES_PATH/kafka/values.yml" --version 26.8.3 --namespace "$NAMESPACE"

# Deploy the Vote service
echo "📦 Deploying Vote service..."
helm upgrade --install vote "$MICROSERVICES_PATH/vote/chart" --namespace "$NAMESPACE"

# Deploy the Result service
echo "📦 Deploying Result service..."
helm upgrade --install result "$MICROSERVICES_PATH/result/chart" --namespace "$NAMESPACE"

# Deploy the Worker service
echo "📦 Deploying Worker service..."
helm upgrade --install worker "$MICROSERVICES_PATH/worker/chart" --namespace "$NAMESPACE"

echo "✅ Okteto Microservices installation complete with Dash0 monitoring!"
