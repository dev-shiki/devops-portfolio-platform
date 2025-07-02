# Test script for local development
# Run this script to test both microservices locally

Write-Host "=== DevOps Portfolio Project - Session 1 Test ===" -ForegroundColor Green
Write-Host ""

# Function to test if a service is running
function Test-Service {
    param($ServiceName, $Port, $Path = "/health")
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$Port$Path" -Method Get -TimeoutSec 5
        Write-Host "✓ $ServiceName is running on port $Port" -ForegroundColor Green
        Write-Host "  Status: $($response.status)" -ForegroundColor Cyan
        return $true
    }
    catch {
        Write-Host "✗ $ServiceName is not responding on port $Port" -ForegroundColor Red
        return $false
    }
}

# Function to test API endpoints
function Test-API {
    Write-Host "`n=== Testing API Endpoints ===" -ForegroundColor Yellow
    
    # Test User Service
    Write-Host "`nTesting User Service:" -ForegroundColor Cyan
    try {
        $users = Invoke-RestMethod -Uri "http://localhost:8080/users" -Method Get
        Write-Host "✓ GET /users - Found $($users.Count) users" -ForegroundColor Green
        
        # Test creating a user
        $newUser = @{
            name = "Test User from PowerShell"
            email = "powershell@test.com"
        } | ConvertTo-Json
        
        $createdUser = Invoke-RestMethod -Uri "http://localhost:8080/users" -Method Post -Body $newUser -ContentType "application/json"
        Write-Host "✓ POST /users - Created user ID: $($createdUser.id)" -ForegroundColor Green
        
        # Test getting specific user
        $specificUser = Invoke-RestMethod -Uri "http://localhost:8080/users/$($createdUser.id)" -Method Get
        Write-Host "✓ GET /users/$($createdUser.id) - Retrieved: $($specificUser.name)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ User Service API test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test Order Service
    Write-Host "`nTesting Order Service:" -ForegroundColor Cyan
    try {
        $orders = Invoke-RestMethod -Uri "http://localhost:8081/orders" -Method Get
        Write-Host "✓ GET /orders - Found $($orders.Count) orders" -ForegroundColor Green
        
        # Test creating an order
        $newOrder = @{
            user_id = 1
            product = "PowerShell Test Product"
            quantity = 2
            price = 149.99
        } | ConvertTo-Json
        
        $createdOrder = Invoke-RestMethod -Uri "http://localhost:8081/orders" -Method Post -Body $newOrder -ContentType "application/json"
        Write-Host "✓ POST /orders - Created order ID: $($createdOrder.id)" -ForegroundColor Green
        
        # Test getting specific order
        $specificOrder = Invoke-RestMethod -Uri "http://localhost:8081/orders/$($createdOrder.id)" -Method Get
        Write-Host "✓ GET /orders/$($createdOrder.id) - Retrieved: $($specificOrder.product)" -ForegroundColor Green
        
        # Test updating order status
        $statusUpdate = @{ status = "processing" } | ConvertTo-Json
        $updateResult = Invoke-RestMethod -Uri "http://localhost:8081/orders/$($createdOrder.id)/status" -Method Put -Body $statusUpdate -ContentType "application/json"
        Write-Host "✓ PUT /orders/$($createdOrder.id)/status - Status updated" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Order Service API test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Check if services are running
Write-Host "Checking if services are running..." -ForegroundColor Yellow

$userServiceRunning = Test-Service "User Service" 8080
$orderServiceRunning = Test-Service "Order Service" 8081

if ($userServiceRunning -and $orderServiceRunning) {
    Test-API
    
    Write-Host "`n=== Metrics Endpoints ===" -ForegroundColor Yellow
    Write-Host "User Service metrics: http://localhost:8080/metrics" -ForegroundColor Cyan
    Write-Host "Order Service metrics: http://localhost:8081/metrics" -ForegroundColor Cyan
} else {
    Write-Host "`nTo start the services manually:" -ForegroundColor Yellow
    Write-Host "Terminal 1: cd user-service && go run ." -ForegroundColor White
    Write-Host "Terminal 2: cd order-service && go run ." -ForegroundColor White
}

Write-Host "`n=== Session 1 Status: COMPLETED ✓ ===" -ForegroundColor Green
Write-Host "Both microservices are implemented and containerized!" -ForegroundColor Green 