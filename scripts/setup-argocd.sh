#!/bin/bash

# setup-argocd.sh - Setup Argo CD for DevOps Portfolio Project
# This script installs and configures Argo CD in a local Kubernetes cluster

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster. Please ensure your cluster is running."
        exit 1
    fi
    
    # Check if running locally (Kind/Minikube)
    cluster_context=$(kubectl config current-context 2>/dev/null || echo "unknown")
    log_info "Current cluster context: $cluster_context"
    
    log_success "Prerequisites check completed!"
}

# Install Argo CD
install_argocd() {
    log_info "Installing Argo CD..."
    
    # Apply Argo CD installation manifests
    log_info "Applying Argo CD namespace and RBAC..."
    kubectl apply -f gitops/argocd-install.yaml
    
    log_info "Applying Argo CD configuration..."
    kubectl apply -f gitops/argocd-config.yaml
    
    log_info "Applying Argo CD required configurations..."
    kubectl apply -f gitops/argocd-required-configs.yaml
    
    log_info "Applying Argo CD deployments..."
    kubectl apply -f gitops/argocd-deployments-simplified.yaml
    
    log_success "Argo CD installation manifests applied!"
}

# Wait for Argo CD to be ready
wait_for_argocd() {
    log_info "Waiting for Argo CD components to be ready..."
    
    # Wait for namespace
    kubectl wait --for=condition=Ready namespace/argocd --timeout=60s
    
    # Wait for deployments
    local deployments=("argocd-redis" "argocd-repo-server" "argocd-server" "argocd-application-controller")
    
    for deployment in "${deployments[@]}"; do
        log_info "Waiting for $deployment to be ready..."
        kubectl wait --for=condition=Available deployment/$deployment -n argocd --timeout=300s
    done
    
    log_success "All Argo CD components are ready!"
}

# Setup port forwarding
setup_port_forwarding() {
    log_info "Setting up port forwarding for Argo CD UI..."
    
    # Check if port 8080 is already in use
    if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null ; then
        log_warning "Port 8080 is already in use. Argo CD UI might not be accessible."
        log_info "You can manually forward the port with:"
        log_info "kubectl port-forward svc/argocd-server -n argocd 8080:8080"
    else
        log_info "Starting port forwarding in background..."
        kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:8080 &
        PORT_FORWARD_PID=$!
        echo $PORT_FORWARD_PID > /tmp/argocd-port-forward.pid
        sleep 5  # Give it time to start
        log_success "Port forwarding started (PID: $PORT_FORWARD_PID)"
    fi
}

# Get Argo CD admin password
get_admin_password() {
    log_info "Retrieving Argo CD admin password..."
    
    # Wait for secret to be available
    kubectl wait --for=condition=Ready secret/argocd-secret -n argocd --timeout=60s
    
    # Default password is 'admin' for our setup
    log_success "Argo CD admin credentials:"
    echo "Username: admin"
    echo "Password: admin"
    
    log_info "You can change the password after first login using:"
    echo "argocd account update-password"
}

# Install Argo CD CLI (optional)
install_argocd_cli() {
    if command -v argocd &> /dev/null; then
        log_info "Argo CD CLI already installed: $(argocd version --client --short 2>/dev/null || echo 'version unknown')"
        return
    fi
    
    log_info "Installing Argo CD CLI..."
    
    # Detect OS
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        arm64) ARCH="arm64" ;;
    esac
    
    # Download and install
    ARGOCD_VERSION="v2.9.3"
    curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-${OS}-${ARCH}"
    chmod +x argocd
    
    # Move to PATH
    if [[ ":$PATH:" == *":/usr/local/bin:"* ]]; then
        sudo mv argocd /usr/local/bin/
    else
        mkdir -p ~/bin
        mv argocd ~/bin/
        echo "export PATH=\$PATH:~/bin" >> ~/.bashrc
        log_info "Added ~/bin to PATH. Please run 'source ~/.bashrc' or start a new terminal."
    fi
    
    log_success "Argo CD CLI installed successfully!"
}

# Deploy portfolio applications
deploy_applications() {
    log_info "Deploying portfolio applications to Argo CD..."
    
    # Apply application definitions
    kubectl apply -f gitops/applications/portfolio-app.yaml
    
    log_success "Portfolio applications deployed to Argo CD!"
    log_info "Applications will be automatically synced based on their sync policies."
}

# Display access information
display_access_info() {
    echo ""
    echo "🎉 Argo CD Setup Complete!"
    echo "=========================="
    echo ""
    echo "📊 Argo CD Dashboard:"
    echo "   URL: http://localhost:8080"
    echo "   Username: admin"
    echo "   Password: admin"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   Check status: kubectl get pods -n argocd"
    echo "   View applications: kubectl get applications -n argocd"
    echo "   Port forward: kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:8080"
    echo ""
    echo "📱 Application Status:"
    echo "   Portfolio Services: http://localhost:8080/applications/portfolio-services"
    echo "   User Service: http://localhost:8080/applications/portfolio-user-service"
    echo "   Order Service: http://localhost:8080/applications/portfolio-order-service"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Access the Argo CD dashboard at http://localhost:8080"
    echo "   2. Login with admin/admin credentials"
    echo "   3. Sync the applications manually or wait for auto-sync"
    echo "   4. Monitor deployment status and application health"
    echo ""
}

# Cleanup function
cleanup() {
    if [ -f /tmp/argocd-port-forward.pid ]; then
        PID=$(cat /tmp/argocd-port-forward.pid)
        if kill -0 $PID 2>/dev/null; then
            log_info "Stopping port forwarding..."
            kill $PID
            rm -f /tmp/argocd-port-forward.pid
        fi
    fi
}

# Main execution
main() {
    echo "🚀 DevOps Portfolio - Argo CD Setup"
    echo "===================================="
    echo ""
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Run setup steps
    check_prerequisites
    install_argocd
    wait_for_argocd
    setup_port_forwarding
    get_admin_password
    install_argocd_cli
    deploy_applications
    display_access_info
    
    log_success "Argo CD setup completed successfully!"
}

# Script options
case "${1:-install}" in
    "install")
        main
        ;;
    "uninstall")
        log_info "Uninstalling Argo CD..."
        kubectl delete -f gitops/applications/portfolio-app.yaml --ignore-not-found=true
        kubectl delete -f gitops/argocd-deployments-simplified.yaml --ignore-not-found=true
        kubectl delete -f gitops/argocd-required-configs.yaml --ignore-not-found=true
        kubectl delete -f gitops/argocd-config.yaml --ignore-not-found=true
        kubectl delete -f gitops/argocd-install.yaml --ignore-not-found=true
        log_success "Argo CD uninstalled!"
        ;;
    "status")
        log_info "Checking Argo CD status..."
        kubectl get pods -n argocd
        kubectl get applications -n argocd
        ;;
    "help")
        echo "Usage: $0 [install|uninstall|status|help]"
        echo ""
        echo "Commands:"
        echo "  install    - Install and setup Argo CD (default)"
        echo "  uninstall  - Remove Argo CD installation"
        echo "  status     - Check Argo CD status"
        echo "  help       - Show this help message"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information."
        exit 1
        ;;
esac 