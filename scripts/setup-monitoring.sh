#!/bin/bash

# setup-monitoring.sh - Setup complete monitoring stack with Prometheus, Grafana, and Alertmanager
# For DevOps Portfolio Project

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    log_success "kubectl is available"
}

# Function to check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    log_success "Kubernetes cluster is accessible"
}

# Function to create monitoring namespace
create_namespace() {
    log_info "Creating monitoring namespace..."
    
    if kubectl get namespace monitoring &> /dev/null; then
        log_warning "Monitoring namespace already exists"
    else
        kubectl create namespace monitoring
        log_success "Monitoring namespace created"
    fi
}

# Function to deploy Prometheus
deploy_prometheus() {
    log_info "Deploying Prometheus..."
    
    if kubectl apply -f monitoring/kubernetes/prometheus-deployment.yaml; then
        log_success "Prometheus deployment applied"
    else
        log_error "Failed to deploy Prometheus"
        return 1
    fi
    
    # Wait for Prometheus to be ready
    log_info "Waiting for Prometheus to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring
    log_success "Prometheus is ready"
}

# Function to deploy Grafana
deploy_grafana() {
    log_info "Deploying Grafana..."
    
    if kubectl apply -f monitoring/kubernetes/grafana-deployment.yaml; then
        log_success "Grafana deployment applied"
    else
        log_error "Failed to deploy Grafana"
        return 1
    fi
    
    # Wait for Grafana to be ready
    log_info "Waiting for Grafana to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring
    log_success "Grafana is ready"
}

# Function to deploy Alertmanager
deploy_alertmanager() {
    log_info "Deploying Alertmanager..."
    
    if kubectl apply -f monitoring/kubernetes/alertmanager-deployment.yaml; then
        log_success "Alertmanager deployment applied"
    else
        log_error "Failed to deploy Alertmanager"
        return 1
    fi
    
    # Wait for Alertmanager to be ready
    log_info "Waiting for Alertmanager to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/alertmanager -n monitoring
    log_success "Alertmanager is ready"
}

# Function to setup port forwarding
setup_port_forwarding() {
    log_info "Setting up port forwarding for monitoring services..."
    
    # Check if port forwarding processes are already running
    if pgrep -f "kubectl port-forward.*prometheus" > /dev/null; then
        log_warning "Prometheus port forwarding already running"
    else
        log_info "Starting Prometheus port forwarding (localhost:9090)..."
        kubectl port-forward svc/prometheus-external -n monitoring 9090:9090 &
    fi
    
    if pgrep -f "kubectl port-forward.*grafana" > /dev/null; then
        log_warning "Grafana port forwarding already running"
    else
        log_info "Starting Grafana port forwarding (localhost:3000)..."
        kubectl port-forward svc/grafana-external -n monitoring 3000:3000 &
    fi
    
    if pgrep -f "kubectl port-forward.*alertmanager" > /dev/null; then
        log_warning "Alertmanager port forwarding already running"
    else
        log_info "Starting Alertmanager port forwarding (localhost:9093)..."
        kubectl port-forward svc/alertmanager-external -n monitoring 9093:9093 &
    fi
    
    sleep 5
    log_success "Port forwarding setup completed"
}

# Function to verify deployment
verify_deployment() {
    log_info "Verifying monitoring stack deployment..."
    
    # Check pods status
    log_info "Checking pod status..."
    kubectl get pods -n monitoring
    
    # Check services
    log_info "Checking services..."
    kubectl get services -n monitoring
    
    # Verify external access
    log_info "Verifying external access..."
    echo "📊 Monitoring Services:"
    echo "- Prometheus: http://localhost:9090"
    echo "- Grafana: http://localhost:3000 (admin/admin)"
    echo "- Alertmanager: http://localhost:9093"
    echo ""
    echo "🔍 Default Credentials:"
    echo "- Grafana: admin / admin"
    echo ""
    echo "📈 Default Dashboards:"
    echo "- Application Overview: Available in Grafana"
    echo "- Service Metrics: Real-time monitoring"
    echo "- Alert Rules: Configured for SLA monitoring"
}

# Function to show monitoring status
show_status() {
    log_info "Monitoring Stack Status"
    echo "========================"
    
    # Check if monitoring namespace exists
    if kubectl get namespace monitoring &> /dev/null; then
        echo "✅ Namespace: monitoring (exists)"
    else
        echo "❌ Namespace: monitoring (missing)"
        return 1
    fi
    
    # Check deployments
    echo ""
    echo "📦 Deployments:"
    kubectl get deployments -n monitoring -o custom-columns="NAME:.metadata.name,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas,AGE:.metadata.creationTimestamp" 2>/dev/null || echo "❌ No deployments found"
    
    # Check services
    echo ""
    echo "🌐 Services:"
    kubectl get services -n monitoring -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[*].ip,PORT:.spec.ports[*].port" 2>/dev/null || echo "❌ No services found"
    
    # Check pods
    echo ""
    echo "🚀 Pods:"
    kubectl get pods -n monitoring -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,AGE:.metadata.creationTimestamp" 2>/dev/null || echo "❌ No pods found"
}

# Function to cleanup monitoring stack
cleanup() {
    log_warning "Cleaning up monitoring stack..."
    
    # Stop port forwarding
    log_info "Stopping port forwarding processes..."
    pkill -f "kubectl port-forward.*prometheus" || true
    pkill -f "kubectl port-forward.*grafana" || true
    pkill -f "kubectl port-forward.*alertmanager" || true
    
    # Delete monitoring resources
    log_info "Deleting monitoring resources..."
    kubectl delete -f monitoring/kubernetes/prometheus-deployment.yaml --ignore-not-found=true
    kubectl delete -f monitoring/kubernetes/grafana-deployment.yaml --ignore-not-found=true
    kubectl delete -f monitoring/kubernetes/alertmanager-deployment.yaml --ignore-not-found=true
    
    # Delete namespace
    log_info "Deleting monitoring namespace..."
    kubectl delete namespace monitoring --ignore-not-found=true
    
    log_success "Monitoring stack cleanup completed"
}

# Function to restart monitoring services
restart() {
    log_info "Restarting monitoring services..."
    
    kubectl rollout restart deployment/prometheus -n monitoring
    kubectl rollout restart deployment/grafana -n monitoring
    kubectl rollout restart deployment/alertmanager -n monitoring
    
    log_info "Waiting for services to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring
    kubectl wait --for=condition=available --timeout=300s deployment/alertmanager -n monitoring
    
    log_success "Monitoring services restarted successfully"
}

# Main installation function
install() {
    log_info "🚀 Setting up complete monitoring stack..."
    echo "========================================"
    
    # Prerequisites check
    check_kubectl
    check_cluster
    
    # Create namespace
    create_namespace
    
    # Deploy services
    deploy_prometheus
    deploy_grafana
    deploy_alertmanager
    
    # Setup access
    setup_port_forwarding
    
    # Verify deployment
    verify_deployment
    
    echo ""
    echo "🎉 Monitoring Stack Setup Complete!"
    echo "==================================="
    echo ""
    echo "📊 Access URLs:"
    echo "- Prometheus: http://localhost:9090"
    echo "- Grafana: http://localhost:3000 (admin/admin)"
    echo "- Alertmanager: http://localhost:9093"
    echo ""
    echo "📈 Next Steps:"
    echo "1. Access Grafana to view dashboards"
    echo "2. Configure alert notification channels"
    echo "3. Set up custom dashboards for your metrics"
    echo "4. Test alerting rules with sample alerts"
    echo ""
    echo "🔧 Management Commands:"
    echo "- Status: ./setup-monitoring.sh status"
    echo "- Restart: ./setup-monitoring.sh restart"
    echo "- Cleanup: ./setup-monitoring.sh cleanup"
}

# Main script logic
case "${1:-install}" in
    "install")
        install
        ;;
    "status")
        show_status
        ;;
    "restart")
        restart
        ;;
    "cleanup")
        cleanup
        ;;
    "port-forward")
        setup_port_forwarding
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  install      - Install complete monitoring stack (default)"
        echo "  status       - Show monitoring stack status"
        echo "  restart      - Restart all monitoring services"
        echo "  cleanup      - Remove monitoring stack"
        echo "  port-forward - Setup port forwarding for services"
        echo "  help         - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                    # Install monitoring stack"
        echo "  $0 status             # Check status"
        echo "  $0 restart            # Restart services"
        echo "  $0 cleanup            # Remove everything"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information."
        exit 1
        ;;
esac 