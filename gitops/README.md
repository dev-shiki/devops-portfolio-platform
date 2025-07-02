# 🚀 GitOps Implementation with Argo CD

This directory contains the GitOps implementation for the DevOps Portfolio Project using Argo CD. GitOps provides declarative, automated deployments with git as the single source of truth.

## 📁 Directory Structure

```
gitops/
├── README.md                           # This documentation
├── argocd-install.yaml                 # Argo CD namespace and RBAC
├── argocd-config.yaml                  # Argo CD configuration
├── argocd-required-configs.yaml        # Required ConfigMaps and Secrets
├── argocd-deployments-simplified.yaml  # Argo CD core deployments
├── applications/                       # Argo CD Application definitions
│   └── portfolio-app.yaml             # Portfolio services applications
└── manifests/                         # Kubernetes manifests for services
    ├── user-service/
    │   └── deployment.yaml            # User service K8s resources
    └── order-service/
        └── deployment.yaml            # Order service K8s resources
```

## 🎯 GitOps Principles

Our implementation follows core GitOps principles:

### 1. **Declarative Configuration**
- All Kubernetes resources defined declaratively in YAML
- Application state described in Git repository
- Infrastructure as Code approach

### 2. **Version Control as Source of Truth**
- Git repository contains desired system state
- All changes tracked and auditable
- Rollback capabilities through Git history

### 3. **Automated Deployment**
- Argo CD automatically syncs Git state to cluster
- Continuous reconciliation of desired vs actual state
- Self-healing capabilities

### 4. **Monitoring and Alerting**
- Real-time visibility into application state
- Drift detection and correction
- Deployment status tracking

## 🛠️ Argo CD Components

### Core Components

| Component | Purpose | Port |
|-----------|---------|------|
| **argocd-server** | Web UI and API server | 8080 |
| **argocd-application-controller** | Manages applications and syncing | 8082 |
| **argocd-repo-server** | Git repository interaction | 8081 |
| **argocd-redis** | Caching and session storage | 6379 |

### Security Features

- **RBAC Integration**: Role-based access control
- **Non-root Execution**: All containers run as non-root users
- **Security Contexts**: Proper security contexts defined
- **Resource Limits**: CPU and memory limits enforced
- **Read-only Root Filesystem**: Enhanced container security

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (Kind, Minikube, or cloud cluster)
- kubectl configured and accessible
- Git repository with portfolio project

### Installation

1. **Run Setup Script:**
```bash
chmod +x scripts/setup-argocd.sh
./scripts/setup-argocd.sh
```

2. **Manual Installation (Alternative):**
```bash
# Install Argo CD
kubectl apply -f gitops/argocd-install.yaml
kubectl apply -f gitops/argocd-config.yaml
kubectl apply -f gitops/argocd-required-configs.yaml
kubectl apply -f gitops/argocd-deployments-simplified.yaml

# Wait for components to be ready
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

# Deploy applications
kubectl apply -f gitops/applications/portfolio-app.yaml
```

3. **Access Argo CD UI:**
```bash
# Port forward to access UI
kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:8080

# Access at http://localhost:8080
# Username: admin
# Password: admin
```

## 📱 Application Management

### Application Definitions

Our portfolio uses three main Argo CD applications:

#### 1. Portfolio Services (Main)
- **Name**: `portfolio-services`
- **Source**: `k8s-manifests/`
- **Sync Wave**: 0 (first)
- **Purpose**: Core Kubernetes resources

#### 2. User Service
- **Name**: `portfolio-user-service`
- **Source**: `gitops/manifests/user-service/`
- **Sync Wave**: 1 (second)
- **Purpose**: User management microservice

#### 3. Order Service
- **Name**: `portfolio-order-service`
- **Source**: `gitops/manifests/order-service/`
- **Sync Wave**: 2 (third)
- **Purpose**: Order management microservice

### Sync Policies

All applications are configured with:
- **Automated Sync**: Automatic deployment on Git changes
- **Self-Healing**: Automatic correction of configuration drift
- **Pruning**: Automatic removal of deleted resources
- **Retry Logic**: Automatic retry on deployment failures

## 🔧 Configuration Management

### Environment Variables

Services are configured with appropriate environment variables:

```yaml
env:
- name: PORT
  value: "8080"
- name: LOG_LEVEL
  value: "info"
- name: ENVIRONMENT
  value: "production"
- name: SERVICE_NAME
  value: "user-service"
```

### Resource Management

All deployments include:
- **Resource Requests**: CPU and memory requests
- **Resource Limits**: CPU and memory limits
- **Health Checks**: Liveness and readiness probes
- **Security Contexts**: Non-root execution

## 📊 Monitoring and Observability

### Health Checks

Each service includes comprehensive health checks:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Metrics Collection

Services are configured for Prometheus scraping:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

## 🔄 CI/CD Integration

### GitOps Workflow

The `.github/workflows/gitops.yml` workflow:

1. **Validates** all GitOps manifests
2. **Security scans** GitOps configurations
3. **Triggers** Argo CD sync on main branch changes
4. **Monitors** deployment status

### Automated Updates

The CI/CD pipeline updates GitOps manifests:
1. New container images built and pushed
2. GitOps manifests updated with new image tags
3. Argo CD detects changes and syncs automatically
4. Applications updated with zero downtime

## 🛡️ Security Features

### Container Security

- **Non-root Users**: All containers run as UID 10001
- **Read-only Filesystem**: Root filesystem is read-only
- **Security Contexts**: Proper security contexts defined
- **Capability Dropping**: All Linux capabilities dropped

### Network Security

- **Service Isolation**: Services communicate via Kubernetes services
- **Network Policies**: Planned for enhanced network security
- **TLS Encryption**: Planned for service-to-service communication

### Access Control

- **RBAC**: Role-based access control for Argo CD
- **Authentication**: Admin authentication required
- **Authorization**: Fine-grained permissions

## 🔧 Troubleshooting

### Common Issues

#### 1. Argo CD Pods Not Starting
```bash
# Check pod status
kubectl get pods -n argocd

# Check pod logs
kubectl logs -n argocd deployment/argocd-server

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

#### 2. Applications Not Syncing
```bash
# Check application status
kubectl get applications -n argocd

# Describe application
kubectl describe application portfolio-services -n argocd

# Manual sync
kubectl patch application portfolio-services -n argocd --type merge -p='{"operation":{"sync":{"syncStrategy":{"hook":{},"apply":{"force":true}}}}}'
```

#### 3. Image Pull Errors
```bash
# Check image exists
docker pull ghcr.io/your-username/devops-portfolio/user-service:latest

# Check service account
kubectl get serviceaccount default -n devops-portfolio

# Check image pull secrets
kubectl get secrets -n devops-portfolio
```

### Useful Commands

```bash
# Check Argo CD status
kubectl get pods -n argocd
kubectl get applications -n argocd

# Port forward to UI
kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:8080

# Manual application sync
argocd app sync portfolio-services
argocd app sync portfolio-user-service
argocd app sync portfolio-order-service

# Check application health
argocd app wait portfolio-services --health
argocd app get portfolio-services

# View application logs
argocd app logs portfolio-services
```

## 📚 Additional Resources

### Argo CD Documentation
- [Official Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/)

### Security Best Practices
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [Container Security](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

---

## 🎯 Next Steps

After setting up GitOps:

1. **Monitor Applications**: Use Argo CD dashboard to monitor application health
2. **Implement Observability**: Add Prometheus and Grafana (Sesi 7)
3. **Enhance Security**: Implement network policies and service mesh
4. **Scale Applications**: Configure horizontal pod autoscaling
5. **Disaster Recovery**: Implement backup and restore procedures

---

*This GitOps implementation provides a solid foundation for declarative, automated deployments with git as the single source of truth.* 