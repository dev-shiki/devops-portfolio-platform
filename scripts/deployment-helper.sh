#!/bin/bash

# deployment-helper.sh - Helper script for deployment operations
# Provides utilities for deployment validation, rollback, and monitoring

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Validate deployment
validate_deployment() {
    local service=$1
    local namespace=${2:-devops-portfolio}
    
    log_info "Validating deployment for $service in $namespace..."
    
    # Check if deployment exists
    if ! kubectl get deployment "$service" -n "$namespace" &>/dev/null; then
        log_error "Deployment $service not found in namespace $namespace"
        return 1
    fi
    
    # Check deployment status
    local ready_replicas=$(kubectl get deployment "$service" -n "$namespace" -o jsonpath='{.status.readyReplicas}')
    local desired_replicas=$(kubectl get deployment "$service" -n "$namespace" -o jsonpath='{.spec.replicas}')
    
    if [ "$ready_replicas" = "$desired_replicas" ]; then
        log_success "Deployment $service is ready ($ready_replicas/$desired_replicas)"
        return 0
    else
        log_warning "Deployment $service not ready ($ready_replicas/$desired_replicas)"
        return 1
    fi
}

# Health check
health_check() {
    local service=$1
    local port=$2
    local namespace=${3:-devops-portfolio}
    
    log_info "Running health check for $service..."
    
    # Port forward and test
    kubectl port-forward "svc/$service" "$port:80" -n "$namespace" &
    local pf_pid=$!
    
    sleep 5
    
    if curl -s "http://localhost:$port/health" &>/dev/null; then
        log_success "Health check passed for $service"
        kill $pf_pid 2>/dev/null || true
        return 0
    else
        log_error "Health check failed for $service"
        kill $pf_pid 2>/dev/null || true
        return 1
    fi
}

# Update image tag
update_image_tag() {
    local service=$1
    local new_tag=$2
    local namespace=${3:-devops-portfolio}
    
    log_info "Updating $service to image tag: $new_tag"
    
    local image_path="ghcr.io/your-repo/devops-portfolio/$service:$new_tag"
    
    if kubectl set image "deployment/$service" "$service=$image_path" -n "$namespace"; then
        log_success "Image updated for $service"
        
        # Wait for rollout
        if kubectl rollout status "deployment/$service" -n "$namespace" --timeout=300s; then
            log_success "Rollout completed for $service"
            return 0
        else
            log_error "Rollout failed for $service"
            return 1
        fi
    else
        log_error "Failed to update image for $service"
        return 1
    fi
}

# Rollback deployment
rollback_deployment() {
    local service=$1
    local namespace=${2:-devops-portfolio}
    
    log_warning "Rolling back deployment for $service..."
    
    if kubectl rollout undo "deployment/$service" -n "$namespace"; then
        log_info "Waiting for rollback to complete..."
        
        if kubectl rollout status "deployment/$service" -n "$namespace" --timeout=300s; then
            log_success "Rollback completed for $service"
            return 0
        else
            log_error "Rollback failed for $service"
            return 1
        fi
    else
        log_error "Failed to initiate rollback for $service"
        return 1
    fi
}

# Get deployment info
get_deployment_info() {
    local service=$1
    local namespace=${2:-devops-portfolio}
    
    echo "=== Deployment Info: $service ==="
    kubectl get deployment "$service" -n "$namespace" -o wide
    echo ""
    echo "=== Pod Status ==="
    kubectl get pods -l "app=$service" -n "$namespace" -o wide
    echo ""
    echo "=== Service Info ==="
    kubectl get svc -l "app=$service" -n "$namespace" -o wide
    echo ""
}

# Monitor deployment
monitor_deployment() {
    local service=$1
    local duration=${2:-300}
    local namespace=${3:-devops-portfolio}
    
    log_info "Monitoring $service for $duration seconds..."
    
    local end_time=$((SECONDS + duration))
    
    while [ $SECONDS -lt $end_time ]; do
        if validate_deployment "$service" "$namespace"; then
            local remaining=$((end_time - SECONDS))
            echo "✅ $(date): $service healthy (${remaining}s remaining)"
        else
            log_warning "$(date): $service not ready"
        fi
        sleep 30
    done
    
    log_success "Monitoring completed for $service"
}

# Main script logic
case "${1:-help}" in
    "validate")
        validate_deployment "$2" "${3:-devops-portfolio}"
        ;;
    "health-check")
        health_check "$2" "$3" "${4:-devops-portfolio}"
        ;;
    "update-image")
        update_image_tag "$2" "$3" "${4:-devops-portfolio}"
        ;;
    "rollback")
        rollback_deployment "$2" "${3:-devops-portfolio}"
        ;;
    "info")
        get_deployment_info "$2" "${3:-devops-portfolio}"
        ;;
    "monitor")
        monitor_deployment "$2" "${3:-300}" "${4:-devops-portfolio}"
        ;;
    "help")
        echo "Usage: $0 [command] [args...]"
        echo ""
        echo "Commands:"
        echo "  validate <service> [namespace]           - Validate deployment"
        echo "  health-check <service> <port> [namespace] - Run health check"
        echo "  update-image <service> <tag> [namespace]  - Update image tag"
        echo "  rollback <service> [namespace]           - Rollback deployment"
        echo "  info <service> [namespace]               - Get deployment info"
        echo "  monitor <service> [duration] [namespace] - Monitor deployment"
        echo "  help                                     - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 validate user-service"
        echo "  $0 health-check user-service 8080"
        echo "  $0 update-image user-service v1.2.3"
        echo "  $0 rollback order-service"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information."
        exit 1
        ;;
esac 