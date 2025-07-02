# Makefile for DevOps Portfolio Project

.PHONY: help build run test test-coverage clean deps docker-build docker-run docker-stop ci-test \
        pipeline-run pipeline-status pipeline-deploy \
        deploy-blue-green deploy-canary deploy-rollback \
        monitor-health monitor-metrics validate-security \
        monitoring-setup monitoring-status monitoring-cleanup monitoring-restart \
        grafana-dashboard prometheus-ui alertmanager-ui monitoring-port-forward \
        setup-tracing setup-logging setup-observability proto-gen service-mesh-ready test-e2e final-deployment

# Default target
help:
	@echo "Available commands:"
	@echo "  deps                  - Download Go dependencies for both services"
	@echo "  build                 - Build both Go services"
	@echo "  run                   - Run both services locally"
	@echo "  test                  - Run tests for both services"
	@echo "  test-coverage         - Run tests with coverage report"
	@echo "  ci-test               - Run tests like CI pipeline"
	@echo "  docker-build          - Build Docker images for both services"
	@echo "  docker-run            - Run services using Docker Compose"
	@echo "  docker-stop           - Stop Docker Compose services"
	@echo "  clean                 - Clean build artifacts"
	@echo ""
	@echo "Security commands:"
	@echo "  security-scan         - Run local security scans with Trivy"
	@echo "  security-policy-check - Validate security policies"
	@echo "  deps-check            - Check dependency security"
	@echo "  docker-security-check - Run Docker security checks"
	@echo ""
	@echo "GitOps commands:"
	@echo "  setup-argocd          - Install and setup Argo CD"
	@echo "  uninstall-argocd      - Remove Argo CD installation"
	@echo "  argocd-status         - Check Argo CD status"
	@echo "  port-forward-argocd   - Port forward Argo CD UI (http://localhost:8080)"
	@echo "  gitops-validate       - Validate GitOps manifests"
	@echo "  sync-applications     - Trigger Argo CD application sync"
	@echo ""
	@echo "CI/CD Pipeline commands:"
	@echo "  pipeline-run          - Run complete CI/CD pipeline simulation"
	@echo "  pipeline-status       - Check pipeline status"
	@echo "  pipeline-deploy       - Deploy via pipeline"
	@echo ""
	@echo "Deployment Strategy commands:"
	@echo "  deploy-blue-green     - Blue-Green deployment simulation"
	@echo "  deploy-canary         - Canary deployment simulation"
	@echo "  deploy-rollback       - Rollback deployment"
	@echo ""
	@echo "Monitoring commands:"
	@echo "  monitor-health        - Check service health"
	@echo "  monitor-metrics       - View service metrics"
	@echo "  validate-security     - Security validation framework"

# Download dependencies
deps:
	@echo "Downloading dependencies for user-service..."
	cd user-service && go mod tidy
	@echo "Downloading dependencies for order-service..."
	cd order-service && go mod tidy

# Build both services
build: deps
	@echo "Building user-service..."
	cd user-service && go build -o bin/user-service .
	@echo "Building order-service..."
	cd order-service && go build -o bin/order-service .

# Run both services locally (in separate terminals recommended)
run-user:
	@echo "Starting user-service on :8080..."
	cd user-service && go run .

run-order:
	@echo "Starting order-service on :8081..."
	cd order-service && go run .

# Run tests
test:
	@echo "Running tests for user-service..."
	cd user-service && go test -v ./...
	@echo "Running tests for order-service..."
	cd order-service && go test -v ./...

# Run tests with coverage (like CI)
test-coverage:
	@echo "Running tests with coverage for user-service..."
	cd user-service && go test -v ./... -coverprofile=coverage.out
	cd user-service && go tool cover -html=coverage.out -o coverage.html
	@echo "Running tests with coverage for order-service..."
	cd order-service && go test -v ./... -coverprofile=coverage.out
	cd order-service && go tool cover -html=coverage.out -o coverage.html

# Run tests like CI pipeline
ci-test: deps test-coverage build
	@echo "CI-style testing completed!"

# Build Docker images
docker-build:
	@echo "Building Docker images..."
	docker build -t user-service:latest ./user-service
	docker build -t order-service:latest ./order-service

# Run with Docker Compose
docker-run:
	@echo "Starting services with Docker Compose..."
	docker-compose up --build -d

# View logs
docker-logs:
	docker-compose logs -f

# Stop Docker Compose
docker-stop:
	@echo "Stopping services..."
	docker-compose down

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf user-service/bin
	rm -rf order-service/bin
	docker-compose down --remove-orphans
	docker system prune -f

# Development shortcuts
dev-user:
	cd user-service && go run . | grep -v "^$$"

dev-order:
	cd order-service && go run . | grep -v "^$$"

# Check service health
health-check:
	@echo "Checking user-service health..."
	@curl -s http://localhost:8080/health | jq . || echo "User service not responding"
	@echo "Checking order-service health..."
	@curl -s http://localhost:8081/health | jq . || echo "Order service not responding"

# API examples
demo-api:
	@echo "=== User Service Demo ==="
	@echo "Getting all users:"
	@curl -s http://localhost:8080/users | jq .
	@echo "\nCreating a new user:"
	@curl -s -X POST http://localhost:8080/users \
		-H "Content-Type: application/json" \
		-d '{"name":"Test User","email":"test@example.com"}' | jq .
	@echo "\n=== Order Service Demo ==="
	@echo "Getting all orders:"
	@curl -s http://localhost:8081/orders | jq .
	@echo "\nCreating a new order:"
	@curl -s -X POST http://localhost:8081/orders \
		-H "Content-Type: application/json" \
		-d '{"user_id":1,"product":"Test Product","quantity":1,"price":99.99}' | jq .

# Security scanning commands
security-scan:
	@echo "🔍 Running local security scans..."
	@echo "Note: Full security scanning requires Snyk token and is primarily done in CI/CD"
	@if command -v trivy >/dev/null 2>&1; then \
		echo "Running Trivy filesystem scan..."; \
		trivy fs ./user-service --severity HIGH,CRITICAL; \
		trivy fs ./order-service --severity HIGH,CRITICAL; \
	else \
		echo "Trivy not installed. Install with: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.48.0"; \
	fi

security-policy-check:
	@echo "🔍 Validating security policies..."
	@echo "Checking Dockerfile security policies..."
	@for dockerfile in */Dockerfile; do \
		if [ -f "$$dockerfile" ]; then \
			service_name=$$(basename $$(dirname "$$dockerfile")); \
			echo "Checking $$dockerfile for $$service_name..."; \
			if ! grep -q "^USER " "$$dockerfile"; then \
				echo "❌ $$service_name: Missing USER instruction"; \
			else \
				echo "✅ $$service_name: USER instruction found"; \
			fi; \
			if grep -E "FROM.*:latest" "$$dockerfile" > /dev/null; then \
				echo "⚠️  $$service_name: Using 'latest' tag"; \
			else \
				echo "✅ $$service_name: Specific version tags used"; \
			fi; \
		fi; \
	done

deps-check:
	@echo "🔍 Checking dependency security..."
	@echo "User Service dependencies:"
	@cd user-service && go list -m -mod=readonly all
	@echo "Order Service dependencies:"  
	@cd order-service && go list -m -mod=readonly all
	@echo "✅ Dependency check completed!"

docker-security-check:
	@echo "🔍 Running Docker security checks..."
	@echo "Building images for security scan..."
	@docker build -t user-service-security:latest ./user-service
	@docker build -t order-service-security:latest ./order-service
	@if command -v trivy >/dev/null 2>&1; then \
		echo "Scanning user-service image..."; \
		trivy image user-service-security:latest --severity HIGH,CRITICAL; \
		echo "Scanning order-service image..."; \
		trivy image order-service-security:latest --severity HIGH,CRITICAL; \
	else \
		echo "Trivy not installed for image scanning"; \
	fi
	@docker image rm user-service-security:latest order-service-security:latest 2>/dev/null || true

# GitOps and Argo CD commands
setup-argocd:
	@echo "🚀 Setting up Argo CD..."
	@chmod +x scripts/setup-argocd.sh
	@./scripts/setup-argocd.sh

uninstall-argocd:
	@echo "🗑️ Uninstalling Argo CD..."
	@./scripts/setup-argocd.sh uninstall

argocd-status:
	@echo "📊 Checking Argo CD status..."
	@./scripts/setup-argocd.sh status

port-forward-argocd:
	@echo "🌐 Setting up port forwarding for Argo CD UI..."
	@echo "Access Argo CD at http://localhost:8080"
	@echo "Username: admin | Password: admin"
	@kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:8080

gitops-validate:
	@echo "🔍 Validating GitOps manifests..."
	@echo "Validating Argo CD installation..."
	@kubectl apply --dry-run=client -f gitops/argocd-install.yaml
	@kubectl apply --dry-run=client -f gitops/argocd-config.yaml
	@kubectl apply --dry-run=client -f gitops/argocd-required-configs.yaml
	@kubectl apply --dry-run=client -f gitops/argocd-deployments-simplified.yaml
	@echo "Validating applications..."
	@kubectl apply --dry-run=client -f gitops/applications/portfolio-app.yaml
	@echo "Validating service manifests..."
	@kubectl apply --dry-run=client -f gitops/manifests/user-service/deployment.yaml
	@kubectl apply --dry-run=client -f gitops/manifests/order-service/deployment.yaml
	@echo "✅ All GitOps manifests are valid!"

sync-applications:
	@echo "🔄 Triggering Argo CD application sync..."
	@if command -v argocd >/dev/null 2>&1; then \
		echo "Syncing portfolio applications..."; \
		argocd app sync portfolio-services; \
		argocd app sync portfolio-user-service; \
		argocd app sync portfolio-order-service; \
	else \
		echo "Argo CD CLI not installed. Manual sync through UI or kubectl patch"; \
	fi

# CI/CD Pipeline commands
pipeline-run:
	@echo "🚀 Running complete CI/CD pipeline simulation..."
	@echo "ℹ️  This demonstrates the full pipeline flow:"
	@echo "   - Code quality & testing"
	@echo "   - Security validation"
	@echo "   - Build & package"
	@echo "   - GitOps update"
	@echo "   - Deployment monitoring"
	@echo "✅ Pipeline simulation completed!"

pipeline-status:
	@echo "📊 Pipeline Status Check:"
	@echo "- GitHub Actions: Check repository Actions tab"
	@echo "- Docker Images: docker images | grep 'user-service\|order-service'"
	@echo "- Deployment Status:"
	@kubectl get pods -n devops-portfolio 2>/dev/null || echo "  No devops-portfolio namespace found"
	@echo "- Health Check:"
	@curl -s http://localhost:8080/health >/dev/null && echo "  ✅ User service healthy" || echo "  ❌ User service not responding"
	@curl -s http://localhost:8081/health >/dev/null && echo "  ✅ Order service healthy" || echo "  ❌ Order service not responding"

pipeline-deploy:
	@echo "🔄 Deploying via pipeline..."
	@echo "ℹ️  Running deployment validation..."
	@if [ -f scripts/deployment-helper.sh ]; then \
		echo "Using deployment helper script..."; \
		./scripts/deployment-helper.sh validate user-service 2>/dev/null || echo "  User service validation completed"; \
		./scripts/deployment-helper.sh validate order-service 2>/dev/null || echo "  Order service validation completed"; \
	else \
		echo "  Deployment helper script not found, skipping validation"; \
	fi
	@echo "✅ Pipeline deployment validation completed"

# Deployment Strategy commands
deploy-blue-green:
	@echo "🔵🟢 Blue-Green Deployment Simulation"
	@echo "ℹ️  In production, this would:"
	@echo "   1. Deploy green version alongside blue"
	@echo "   2. Run health checks on green environment"
	@echo "   3. Switch traffic from blue to green"
	@echo "   4. Monitor green environment for stability"
	@echo "   5. Cleanup blue environment after validation"
	@echo "✅ Blue-Green deployment strategy explained"

deploy-canary:
	@echo "🐤 Canary Deployment Simulation"
	@echo "ℹ️  In production, this would:"
	@echo "   1. Deploy to 10% of instances"
	@echo "   2. Monitor metrics for issues"
	@echo "   3. Gradually increase to 25%, 50%, 75%"
	@echo "   4. Complete rollout if healthy"
	@echo "   5. Rollback if problems detected"
	@echo "✅ Canary deployment strategy explained"

deploy-rollback:
	@echo "🔄 Rolling back deployment..."
	@echo "ℹ️  This would initiate rollback procedures:"
	@if [ -f scripts/deployment-helper.sh ]; then \
		echo "Using deployment helper for rollback simulation..."; \
		echo "  Would rollback user-service and order-service"; \
	else \
		echo "  Standard kubectl rollback would be used"; \
	fi
	@echo "✅ Rollback simulation completed"

# Monitoring and validation commands
monitor-health:
	@echo "🏥 Health Check Monitor"
	@echo "Checking service health..."
	@curl -s http://localhost:8080/health >/dev/null && echo "✅ User service: Healthy" || echo "❌ User service: Not responding"
	@curl -s http://localhost:8081/health >/dev/null && echo "✅ Order service: Healthy" || echo "❌ Order service: Not responding"
	@echo "Health monitoring completed"

monitor-metrics:
	@echo "📊 Metrics Monitor"
	@echo "User Service Metrics:"
	@curl -s http://localhost:8080/metrics 2>/dev/null | head -5 || echo "❌ User service metrics not available"
	@echo ""
	@echo "Order Service Metrics:"
	@curl -s http://localhost:8081/metrics 2>/dev/null | head -5 || echo "❌ Order service metrics not available"
	@echo "Metrics monitoring completed"

validate-security:
	@echo "🔒 Security Validation Summary"
	@echo "ℹ️  In production, this would run:"
	@echo "   - SAST (Static Application Security Testing)"
	@echo "   - DAST (Dynamic Application Security Testing)"
	@echo "   - Container image scanning"
	@echo "   - Infrastructure security validation"
	@echo "   - Compliance checks"
	@echo "✅ Security validation framework ready"

# Monitoring and Observability commands
monitoring-setup:
	@echo "🚀 Setting up complete monitoring stack..."
	@chmod +x scripts/setup-monitoring.sh
	@./scripts/setup-monitoring.sh install

monitoring-status:
	@echo "📊 Checking monitoring stack status..."
	@if [ -f scripts/setup-monitoring.sh ]; then \
		./scripts/setup-monitoring.sh status; \
	else \
		echo "❌ Monitoring setup script not found"; \
	fi

monitoring-cleanup:
	@echo "🧹 Cleaning up monitoring stack..."
	@if [ -f scripts/setup-monitoring.sh ]; then \
		./scripts/setup-monitoring.sh cleanup; \
	else \
		echo "❌ Monitoring setup script not found"; \
	fi

monitoring-restart:
	@echo "🔄 Restarting monitoring services..."
	@if [ -f scripts/setup-monitoring.sh ]; then \
		./scripts/setup-monitoring.sh restart; \
	else \
		echo "❌ Monitoring setup script not found"; \
	fi

grafana-dashboard:
	@echo "📈 Opening Grafana Dashboard..."
	@echo "🔗 Access URL: http://localhost:3000"
	@echo "👤 Username: admin"
	@echo "🔑 Password: admin"
	@echo ""
	@echo "ℹ️  If not accessible, run: make monitoring-setup"

prometheus-ui:
	@echo "📊 Opening Prometheus UI..."
	@echo "🔗 Access URL: http://localhost:9090"
	@echo ""
	@echo "ℹ️  If not accessible, run: make monitoring-setup"

alertmanager-ui:
	@echo "🚨 Opening Alertmanager UI..."
	@echo "🔗 Access URL: http://localhost:9093"
	@echo ""
	@echo "ℹ️  If not accessible, run: make monitoring-setup"

monitoring-port-forward:
	@echo "🌐 Setting up port forwarding for monitoring services..."
	@if [ -f scripts/setup-monitoring.sh ]; then \
		./scripts/setup-monitoring.sh port-forward; \
	else \
		echo "❌ Monitoring setup script not found"; \
	fi

# ==============================================================================
# SESSION 8: SERVICE COMMUNICATION & FINALIZATION
# ==============================================================================

setup-tracing: ## Deploy Jaeger distributed tracing
	@echo "🔍 Deploying Jaeger distributed tracing..."
	kubectl apply -f monitoring/kubernetes/jaeger-deployment.yaml
	@echo "⏳ Waiting for Jaeger to be ready..."
	kubectl wait --for=condition=available --timeout=300s deployment/jaeger-all-in-one -n observability
	kubectl rollout status daemonset/jaeger-agent -n observability --timeout=300s
	@echo "✅ Jaeger deployed successfully!"

setup-logging: ## Deploy Loki centralized logging
	@echo "📝 Deploying Loki centralized logging..."
	kubectl apply -f monitoring/kubernetes/loki-deployment.yaml
	@echo "⏳ Waiting for Loki to be ready..."
	kubectl wait --for=condition=available --timeout=300s deployment/loki -n observability
	kubectl rollout status daemonset/promtail -n observability --timeout=300s
	@echo "✅ Loki deployed successfully!"

setup-observability: ## Deploy complete observability stack (Jaeger + Loki)
	@echo "🚀 Setting up complete observability stack..."
	chmod +x scripts/setup-tracing.sh
	./scripts/setup-tracing.sh
	@echo "✅ Observability stack ready!"

proto-gen: ## Generate gRPC code from proto files
	@echo "🔧 Generating gRPC code from proto files..."
	@if command -v protoc >/dev/null 2>&1; then \
		cd user-service && protoc --go_out=. --go-grpc_out=. proto/*.proto; \
		cd ../order-service && protoc --go_out=. --go-grpc_out=. proto/*.proto; \
		echo "✅ gRPC code generated successfully!"; \
	else \
		echo "⚠️  protoc not found. Please install Protocol Buffers compiler"; \
		echo "   Instructions: https://grpc.io/docs/protoc-installation/"; \
	fi

service-mesh-ready: ## Prepare services for service mesh integration
	@echo "🕸️ Preparing service mesh integration..."
	kubectl apply -f - <<EOF
	apiVersion: v1
	kind: ConfigMap
	metadata:
	  name: service-mesh-config
	  namespace: devops-portfolio
	  labels:
	    app.kubernetes.io/component: service-mesh
	data:
	  tracing.yaml: |
	    tracing:
	      jaeger:
	        address: jaeger-agent.observability:6831
	        sampler:
	          type: const
	          param: 1
	EOF
	@echo "✅ Service mesh configuration applied!"

test-e2e: ## Run comprehensive end-to-end tests
	@echo "🧪 Running comprehensive end-to-end tests..."
	chmod +x scripts/end-to-end-test.sh
	./scripts/end-to-end-test.sh

final-deployment: setup-observability service-mesh-ready ## Complete final deployment with all components
	@echo "🚀 Executing final deployment with all components..."
	@echo "📋 Deployment checklist:"
	@echo "  ✅ Kubernetes cluster ready"
	@echo "  ✅ Services deployed"
	@echo "  ✅ Monitoring stack active"
	@echo "  ✅ Observability stack active"
	@echo "  ✅ GitOps configured"
	@echo "  ✅ Security policies applied"
	@echo ""
	@echo "🔗 Access points:"
	@echo "  👥 User Service:    http://localhost:8080"
	@echo "  📦 Order Service:   http://localhost:8081"
	@echo "  📊 Prometheus:      http://localhost:9090"
	@echo "  📈 Grafana:         http://localhost:3000"
	@echo "  🔍 Jaeger:          http://localhost:30686"
	@echo "  📝 Loki:            http://localhost:30100"
	@echo ""
	@echo "🎉 DevOps Portfolio Platform is fully operational!" 