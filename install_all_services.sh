#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Prevents errors in a pipeline from being masked

# Define script paths
DASH0_SCRIPT="./install_dash0_operator.sh"
STEADYBIT_SCRIPT="./install_steadybit_agent.sh"
OKTETO_SCRIPT="./install_okteto_microservices.sh"
OBSERVABILITY_SCRIPT="./install_observability_stack.sh"

# Function to check if Dash0 Operator is running
check_dash0_operator() {
    echo "⏳ Waiting for Dash0 Operator to be ready..."
    
    while true; do
        # Check if Dash0 Operator pods are in Running state
        if kubectl get pods -n dash0-system | grep "dash0-operator" | grep -q "Running"; then
            echo "✅ Dash0 Operator is running!"
            break
        else
            echo "⏳ Dash0 Operator is not ready yet. Retrying in 5 seconds..."
            sleep 5
        fi
    done
}

# Function to log installation steps
log_step() {
    echo "---------------------------------------------------"
    echo "🚀 $1"
    echo "---------------------------------------------------"
}

# Ensure all scripts are executable
chmod +x "$DASH0_SCRIPT" "$STEADYBIT_SCRIPT" "$OKTETO_SCRIPT" "$OBSERVABILITY_SCRIPT"

# # Install Dash0 Operator
# log_step "Installing Dash0 Operator..."
# "$DASH0_SCRIPT"

# # Ensure Dash0 Operator is running before proceeding
# check_dash0_operator

# # Install Steadybit Agent
# log_step "Installing Steadybit Agent..."
# "$STEADYBIT_SCRIPT"

# Install Okteto Microservices
log_step "Installing Okteto Microservices..."
"$OKTETO_SCRIPT"

# Install Observability Stack (Grafana, Jaeger, ELK)
log_step "Installing Observability Stack..."
"$OBSERVABILITY_SCRIPT"

log_step "✅ All services installed successfully!"
