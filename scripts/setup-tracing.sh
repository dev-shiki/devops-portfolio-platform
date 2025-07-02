#!/bin/bash

# Setup Distributed Tracing and Logging Infrastructure
# DevOps Portfolio - Session 8: Service Communication & Finalization

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE_OBSERVABILITY="observability"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Utility functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if monitoring namespace exists
    if ! kubectl get namespace monitoring &> /dev/null; then
        log_warning "Monitoring namespace not found. Please run setup-monitoring.sh first"
        log_info "Creating basic monitoring namespace..."
        kubectl create namespace monitoring
    fi
    
    log_success "Prerequisites check completed"
}

create_observability_namespace() {
    log_info "Creating observability namespace..."
    
    if kubectl get namespace $NAMESPACE_OBSERVABILITY &> /dev/null; then
        log_warning "Namespace $NAMESPACE_OBSERVABILITY already exists"
    else
        kubectl create namespace $NAMESPACE_OBSERVABILITY
        kubectl label namespace $NAMESPACE_OBSERVABILITY name=observability
        log_success "Namespace $NAMESPACE_OBSERVABILITY created"
    fi
}

deploy_jaeger() {
    log_info "Deploying Jaeger distributed tracing..."
    
    if kubectl apply -f "$PROJECT_ROOT/monitoring/kubernetes/jaeger-deployment.yaml"; then
        log_success "Jaeger manifests applied successfully"
        
        # Wait for Jaeger to be ready
        log_info "Waiting for Jaeger deployment to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/jaeger-all-in-one -n $NAMESPACE_OBSERVABILITY
        
        # Wait for Jaeger agent daemonset to be ready
        log_info "Waiting for Jaeger agent daemonset to be ready..."
        kubectl rollout status daemonset/jaeger-agent -n $NAMESPACE_OBSERVABILITY --timeout=300s
        
        log_success "Jaeger is ready!"
    else
        log_error "Failed to deploy Jaeger"
        return 1
    fi
}

deploy_loki() {
    log_info "Deploying Loki centralized logging..."
    
    if kubectl apply -f "$PROJECT_ROOT/monitoring/kubernetes/loki-deployment.yaml"; then
        log_success "Loki manifests applied successfully"
        
        # Wait for Loki to be ready
        log_info "Waiting for Loki deployment to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/loki -n $NAMESPACE_OBSERVABILITY
        
        # Wait for Promtail daemonset to be ready
        log_info "Waiting for Promtail daemonset to be ready..."
        kubectl rollout status daemonset/promtail -n $NAMESPACE_OBSERVABILITY --timeout=300s
        
        log_success "Loki and Promtail are ready!"
    else
        log_error "Failed to deploy Loki"
        return 1
    fi
}

update_grafana_datasources() {
    log_info "Updating Grafana with new datasources..."
    
    # Create updated datasources configuration
    cat > /tmp/grafana-datasources.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
  labels:
    app: grafana
data:
  prometheus.yml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus-service:9090
        isDefault: true
        editable: true
        jsonData:
          timeInterval: "5s"
          queryTimeout: "300s"
          httpMethod: "POST"
      - name: Jaeger
        type: jaeger
        access: proxy
        url: http://jaeger-query.observability:16686
        editable: true
        jsonData:
          tracesToLogsV2:
            datasourceUid: 'loki'
            spanStartTimeShift: '-1h'
            spanEndTimeShift: '1h'
            tags: [{'key': 'service.name', 'value': 'service'}]
            filterByTraceID: false
            filterBySpanID: false
            customQuery: true
            query: '{service="${__data.fields.service}"} |= "${__data.fields.traceID}"'
      - name: Loki
        type: loki
        access: proxy
        url: http://loki-service.observability:3100
        editable: true
        jsonData:
          derivedFields:
            - datasourceUid: 'jaeger'
              matcherRegex: 'trace_id=(\w+)'
              name: 'TraceID'
              url: '$${__value.raw}'
              urlDisplayLabel: 'View Trace'
EOF
    
    if kubectl apply -f /tmp/grafana-datasources.yml; then
        log_success "Grafana datasources updated"
        
        # Restart Grafana to pick up new datasources
        log_info "Restarting Grafana to load new datasources..."
        kubectl rollout restart deployment/grafana -n monitoring
        kubectl rollout status deployment/grafana -n monitoring --timeout=300s
        
        log_success "Grafana restarted with new datasources"
    else
        log_error "Failed to update Grafana datasources"
    fi
    
    # Clean up temp file
    rm -f /tmp/grafana-datasources.yml
}

setup_service_mesh_ready() {
    log_info "Preparing service mesh integration..."
    
    # Create service mesh configuration
    cat > /tmp/service-mesh-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-mesh-config
  namespace: devops-portfolio
  labels:
    app.kubernetes.io/component: service-mesh
    app.kubernetes.io/part-of: devops-portfolio
data:
  tracing.yaml: |
    tracing:
      jaeger:
        address: jaeger-agent.observability:6831
        sampler:
          type: const
          param: 1
      opentelemetry:
        endpoint: jaeger-collector.observability:14250
        protocol: grpc
        sampler_ratio: 1.0
  logging.yaml: |
    logging:
      level: info
      format: json
      output: stdout
      fields:
        service: true
        trace_id: true
        span_id: true
        timestamp: true
        level: true
        message: true
EOF
    
    if kubectl apply -f /tmp/service-mesh-config.yaml; then
        log_success "Service mesh configuration created"
    else
        log_warning "Failed to create service mesh configuration"
    fi
    
    rm -f /tmp/service-mesh-config.yaml
}

verify_deployment() {
    log_info "Verifying tracing and logging deployment..."
    
    # Check Jaeger
    if kubectl get pods -n $NAMESPACE_OBSERVABILITY -l app=jaeger | grep -q Running; then
        log_success "✓ Jaeger is running"
    else
        log_error "✗ Jaeger is not running properly"
    fi
    
    # Check Loki
    if kubectl get pods -n $NAMESPACE_OBSERVABILITY -l app=loki | grep -q Running; then
        log_success "✓ Loki is running"
    else
        log_error "✗ Loki is not running properly"
    fi
    
    # Check Promtail
    if kubectl get pods -n $NAMESPACE_OBSERVABILITY -l app=promtail | grep -q Running; then
        log_success "✓ Promtail is running"
    else
        log_error "✗ Promtail is not running properly"
    fi
}

print_access_info() {
    log_info "Getting access information..."
    
    # Get NodePort for Jaeger
    JAEGER_PORT=$(kubectl get svc jaeger-external -n $NAMESPACE_OBSERVABILITY -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    
    # Get NodePort for Loki
    LOKI_PORT=$(kubectl get svc loki-external -n $NAMESPACE_OBSERVABILITY -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    
    echo
    log_success "🚀 Tracing and Logging Infrastructure Deployed Successfully!"
    echo
    echo "📊 Access Points:"
    echo "  🔍 Jaeger UI:    http://localhost:$JAEGER_PORT"
    echo "  📝 Loki API:     http://localhost:$LOKI_PORT"
    echo "  📈 Grafana:      http://localhost:3000 (updated with new datasources)"
    echo
    echo "🔧 Configuration:"
    echo "  📋 Namespace:    $NAMESPACE_OBSERVABILITY"
    echo "  🏷️  Sampling:     100% for dev services, 10% for others"
    echo "  📦 Retention:    14 days for logs"
    echo
    echo "🧪 Testing:"
    echo "  curl http://localhost:8080/users"
    echo "  curl http://localhost:8081/orders"
    echo "  Check traces in Jaeger UI"
    echo "  Check logs in Grafana -> Explore -> Loki"
    echo
}

main() {
    echo
    log_info "🚀 Setting up Distributed Tracing and Logging - DevOps Portfolio Session 8"
    echo
    
    check_prerequisites
    create_observability_namespace
    deploy_jaeger
    deploy_loki
    update_grafana_datasources
    setup_service_mesh_ready
    
    # Wait a bit for services to stabilize
    log_info "Waiting for services to stabilize..."
    sleep 30
    
    verify_deployment
    print_access_info
    
    log_success "🎉 Tracing and Logging setup completed successfully!"
}

# Run main function
main "$@" 