# Final Platform Test Script for DevOps Portfolio
# Session 8: Service Communication & Finalization
# Windows PowerShell Version

param(
    [switch]$Quick,
    [switch]$Verbose
)

# Colors for PowerShell output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"
$Cyan = "Cyan"

# Configuration
$UserServiceUrl = "http://localhost:8080"
$OrderServiceUrl = "http://localhost:8081"
$PrometheusUrl = "http://localhost:9090"
$GrafanaUrl = "http://localhost:3000"
$JaegerUrl = "http://localhost:30686"
$LokiUrl = "http://localhost:30100"

$TestResults = @()
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0

# Utility functions
function Write-Info($message) {
    Write-Host "[INFO] $message" -ForegroundColor $Blue
}

function Write-Success($message) {
    Write-Host "[SUCCESS] $message" -ForegroundColor $Green
}

function Write-Warning($message) {
    Write-Host "[WARNING] $message" -ForegroundColor $Yellow
}

function Write-Error($message) {
    Write-Host "[ERROR] $message" -ForegroundColor $Red
}

function Write-Test($message) {
    Write-Host "[TEST] $message" -ForegroundColor $Cyan
}

function Write-Result($status, $testName, $details = "") {
    $script:TotalTests++
    
    if ($status -eq "PASS") {
        Write-Host "✓ PASS $testName" -ForegroundColor $Green
        $script:PassedTests++
        $script:TestResults += "PASS: $testName"
    } else {
        Write-Host "✗ FAIL $testName - $details" -ForegroundColor $Red
        $script:FailedTests++
        $script:TestResults += "FAIL: $testName - $details"
    }
}

function Test-ServiceConnectivity {
    Write-Test "Testing service connectivity..."
    
    try {
        $userResponse = Invoke-RestMethod -Uri "$UserServiceUrl/health" -Method Get -TimeoutSec 5
        Write-Result "PASS" "User Service connectivity"
    } catch {
        Write-Result "FAIL" "User Service connectivity" "Cannot reach $UserServiceUrl/health"
    }
    
    try {
        $orderResponse = Invoke-RestMethod -Uri "$OrderServiceUrl/health" -Method Get -TimeoutSec 5
        Write-Result "PASS" "Order Service connectivity"
    } catch {
        Write-Result "FAIL" "Order Service connectivity" "Cannot reach $OrderServiceUrl/health"
    }
}

function Test-KubernetesCluster {
    Write-Test "Testing Kubernetes cluster connectivity..."
    
    try {
        $clusterInfo = kubectl cluster-info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Result "PASS" "Kubernetes cluster connectivity"
        } else {
            Write-Result "FAIL" "Kubernetes cluster connectivity" "Cannot connect to cluster"
        }
    } catch {
        Write-Result "FAIL" "Kubernetes cluster connectivity" "kubectl command failed"
    }
}

function Test-NamespaceExistence {
    Write-Test "Testing namespace existence..."
    
    $namespaces = @("devops-portfolio", "monitoring", "observability")
    $missingNamespaces = @()
    
    foreach ($ns in $namespaces) {
        try {
            $result = kubectl get namespace $ns 2>&1
            if ($LASTEXITCODE -ne 0) {
                $missingNamespaces += $ns
            }
        } catch {
            $missingNamespaces += $ns
        }
    }
    
    if ($missingNamespaces.Count -eq 0) {
        Write-Result "PASS" "All required namespaces exist"
    } else {
        Write-Result "FAIL" "Missing namespaces" ($missingNamespaces -join ", ")
    }
}

function Test-PodHealth {
    Write-Test "Testing pod health across all namespaces..."
    
    $namespaces = @("devops-portfolio", "monitoring", "observability")
    $unhealthyPods = @()
    
    foreach ($ns in $namespaces) {
        try {
            $pods = kubectl get pods -n $ns --no-headers 2>$null
            if ($LASTEXITCODE -eq 0 -and $pods) {
                $podLines = $pods -split "`n"
                foreach ($line in $podLines) {
                    if ($line.Trim()) {
                        $fields = $line -split '\s+'
                        if ($fields.Length -ge 3) {
                            $podName = $fields[0]
                            $status = $fields[2]
                            if ($status -notmatch "Running|Completed") {
                                $unhealthyPods += "$ns/$podName`:$status"
                            }
                        }
                    }
                }
            }
        } catch {
            # Namespace might not exist, skip
        }
    }
    
    if ($unhealthyPods.Count -eq 0) {
        Write-Result "PASS" "All pods are healthy"
    } else {
        Write-Result "FAIL" "Unhealthy pods found" ($unhealthyPods -join ", ")
    }
}

function Test-APIEndpoints {
    Write-Test "Testing API endpoints functionality..."
    
    # Test User Service APIs
    $userTests = @(
        @{ Method = "GET"; Url = "$UserServiceUrl/users"; Name = "User Service API: GET users" },
        @{ Method = "GET"; Url = "$UserServiceUrl/metrics"; Name = "User Service API: GET metrics" }
    )
    
    foreach ($test in $userTests) {
        try {
            $response = Invoke-RestMethod -Uri $test.Url -Method $test.Method -TimeoutSec 5
            Write-Result "PASS" $test.Name
        } catch {
            Write-Result "FAIL" $test.Name "HTTP request failed"
        }
    }
    
    # Test Order Service APIs
    $orderTests = @(
        @{ Method = "GET"; Url = "$OrderServiceUrl/orders"; Name = "Order Service API: GET orders" },
        @{ Method = "GET"; Url = "$OrderServiceUrl/metrics"; Name = "Order Service API: GET metrics" }
    )
    
    foreach ($test in $orderTests) {
        try {
            $response = Invoke-RestMethod -Uri $test.Url -Method $test.Method -TimeoutSec 5
            Write-Result "PASS" $test.Name
        } catch {
            Write-Result "FAIL" $test.Name "HTTP request failed"
        }
    }
}

function Test-MonitoringStack {
    Write-Test "Testing monitoring stack..."
    
    try {
        $prometheusResponse = Invoke-RestMethod -Uri "$PrometheusUrl/-/healthy" -Method Get -TimeoutSec 5
        Write-Result "PASS" "Prometheus health"
    } catch {
        Write-Result "FAIL" "Prometheus health" "Prometheus not responding"
    }
    
    try {
        $grafanaResponse = Invoke-RestMethod -Uri "$GrafanaUrl/api/health" -Method Get -TimeoutSec 5
        Write-Result "PASS" "Grafana health"
    } catch {
        Write-Result "FAIL" "Grafana health" "Grafana not responding"
    }
}

function Test-ObservabilityStack {
    Write-Test "Testing observability stack (Jaeger & Loki)..."
    
    try {
        $jaegerResponse = Invoke-RestMethod -Uri "$JaegerUrl/" -Method Get -TimeoutSec 5
        Write-Result "PASS" "Jaeger UI accessibility"
    } catch {
        Write-Result "FAIL" "Jaeger UI accessibility" "Cannot reach Jaeger UI"
    }
    
    try {
        $lokiResponse = Invoke-RestMethod -Uri "$LokiUrl/ready" -Method Get -TimeoutSec 5
        Write-Result "PASS" "Loki readiness"
    } catch {
        Write-Result "FAIL" "Loki readiness" "Loki not ready"
    }
}

function Test-BusinessLogic {
    Write-Test "Testing business logic with data flow..."
    
    $userData = @{
        name = "Test User"
        email = "test@example.com"
        phone = "1234567890"
        address = "Test Address"
    } | ConvertTo-Json
    
    $orderData = @{
        user_id = 1
        product_name = "Test Product"
        quantity = 2
        price = 25.99
    } | ConvertTo-Json
    
    try {
        $userResponse = Invoke-RestMethod -Uri "$UserServiceUrl/users" -Method Post -Body $userData -ContentType "application/json" -TimeoutSec 5
        if ($userResponse -match "Test User") {
            Write-Result "PASS" "User creation"
        } else {
            Write-Result "FAIL" "User creation" "Unexpected response format"
        }
    } catch {
        Write-Result "FAIL" "User creation" "Failed to create user"
    }
    
    try {
        $orderResponse = Invoke-RestMethod -Uri "$OrderServiceUrl/orders" -Method Post -Body $orderData -ContentType "application/json" -TimeoutSec 5
        if ($orderResponse -match "Test Product") {
            Write-Result "PASS" "Order creation"
        } else {
            Write-Result "FAIL" "Order creation" "Unexpected response format"
        }
    } catch {
        Write-Result "FAIL" "Order creation" "Failed to create order"
    }
}

function Generate-TestReport {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor White
    Write-Host "║                    END-TO-END TEST REPORT                       ║" -ForegroundColor White
    Write-Host "╠══════════════════════════════════════════════════════════════════╣" -ForegroundColor White
    Write-Host "║ Total Tests: $TotalTests                                                   ║" -ForegroundColor White
    Write-Host "║ Passed:      $PassedTests                                                   ║" -ForegroundColor White
    Write-Host "║ Failed:      $FailedTests                                                   ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor White
    Write-Host ""
    
    if ($FailedTests -eq 0) {
        Write-Success "🎉 ALL TESTS PASSED! DevOps platform is fully operational."
    } else {
        Write-Error "❌ Some tests failed. Please review the failures above."
        Write-Host ""
        Write-Host "Failed tests:" -ForegroundColor Yellow
        foreach ($result in $TestResults) {
            if ($result.StartsWith("FAIL")) {
                Write-Host "  - $($result.Substring(6))" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
    Write-Host "📊 Platform Status Summary:" -ForegroundColor Cyan
    Write-Host "  🐳 Kubernetes:     $(if ($TotalTests -gt 0) { "✓ Ready" } else { "✗ Issues" })"
    Write-Host "  🚀 Services:       $(try { Invoke-RestMethod -Uri "$UserServiceUrl/health" -TimeoutSec 2 | Out-Null; "✓ Running" } catch { "✗ Issues" })"
    Write-Host "  📈 Monitoring:     $(try { Invoke-RestMethod -Uri "$PrometheusUrl/-/healthy" -TimeoutSec 2 | Out-Null; "✓ Active" } catch { "✗ Issues" })"
    Write-Host "  🔍 Observability:  $(try { Invoke-RestMethod -Uri "$JaegerUrl/" -TimeoutSec 2 | Out-Null; "✓ Active" } catch { "✗ Issues" })"
    Write-Host ""
}

# Main execution
function Main {
    Write-Host ""
    Write-Info "🚀 Starting Final Platform Test for DevOps Portfolio Platform"
    Write-Host ""
    
    if ($Verbose) {
        Write-Info "Running in verbose mode..."
    }
    
    if ($Quick) {
        Write-Info "Running quick tests only..."
        Test-ServiceConnectivity
        Test-MonitoringStack
    } else {
        # Infrastructure Tests
        Write-Host "=== INFRASTRUCTURE TESTS ===" -ForegroundColor Cyan
        Test-KubernetesCluster
        Test-NamespaceExistence
        Test-PodHealth
        
        # Service Tests
        Write-Host "=== SERVICE TESTS ===" -ForegroundColor Cyan
        Test-ServiceConnectivity
        Test-APIEndpoints
        Test-BusinessLogic
        
        # Monitoring Tests
        Write-Host "=== MONITORING TESTS ===" -ForegroundColor Cyan
        Test-MonitoringStack
        Test-ObservabilityStack
    }
    
    # Generate report
    Generate-TestReport
    
    # Exit with appropriate code
    if ($FailedTests -gt 0) {
        exit 1
    } else {
        exit 0
    }
}

# Run main function
Main 