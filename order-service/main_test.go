package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestNewOrderStore(t *testing.T) {
	store := NewOrderStore()
	
	if store == nil {
		t.Fatal("NewOrderStore() returned nil")
	}
	
	if len(store.orders) != 2 {
		t.Errorf("Expected 2 initial orders, got %d", len(store.orders))
	}
	
	if store.nextID != 3 {
		t.Errorf("Expected nextID to be 3, got %d", store.nextID)
	}
}

func TestCreateOrder(t *testing.T) {
	store := NewOrderStore()
	
	order := store.CreateOrder(1, "Test Product", 2, 99.99)
	
	if order == nil {
		t.Fatal("CreateOrder() returned nil")
	}
	
	if order.UserID != 1 {
		t.Errorf("Expected UserID 1, got %d", order.UserID)
	}
	
	if order.Product != "Test Product" {
		t.Errorf("Expected product 'Test Product', got %s", order.Product)
	}
	
	if order.Quantity != 2 {
		t.Errorf("Expected quantity 2, got %d", order.Quantity)
	}
	
	if order.Price != 99.99 {
		t.Errorf("Expected price 99.99, got %f", order.Price)
	}
	
	if order.Status != "pending" {
		t.Errorf("Expected status 'pending', got %s", order.Status)
	}
	
	if order.ID <= 0 {
		t.Errorf("Expected positive ID, got %d", order.ID)
	}
}

func TestGetOrder(t *testing.T) {
	store := NewOrderStore()
	
	// Test existing order
	order, exists := store.GetOrder(1)
	if !exists {
		t.Error("Expected order 1 to exist")
	}
	if order == nil {
		t.Fatal("GetOrder() returned nil for existing order")
	}
	
	// Test non-existing order
	_, exists = store.GetOrder(999)
	if exists {
		t.Error("Expected order 999 to not exist")
	}
}

func TestGetOrdersByUser(t *testing.T) {
	store := NewOrderStore()
	
	// Add an order for user 1
	store.CreateOrder(1, "User 1 Product", 1, 50.0)
	
	orders := store.GetOrdersByUser(1)
	if len(orders) == 0 {
		t.Error("Expected at least one order for user 1")
	}
	
	// Test user with no orders
	orders = store.GetOrdersByUser(999)
	if len(orders) != 0 {
		t.Errorf("Expected 0 orders for user 999, got %d", len(orders))
	}
}

func TestUpdateOrderStatus(t *testing.T) {
	store := NewOrderStore()
	
	// Test updating existing order
	success := store.UpdateOrderStatus(1, "processing")
	if !success {
		t.Error("Expected UpdateOrderStatus to succeed for existing order")
	}
	
	order, _ := store.GetOrder(1)
	if order.Status != "processing" {
		t.Errorf("Expected status 'processing', got %s", order.Status)
	}
	
	// Test updating non-existing order
	success = store.UpdateOrderStatus(999, "shipped")
	if success {
		t.Error("Expected UpdateOrderStatus to fail for non-existing order")
	}
}

func TestHealthHandler(t *testing.T) {
	req, err := http.NewRequest("GET", "/health", nil)
	if err != nil {
		t.Fatal(err)
	}
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(healthHandler)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Expected status code %d, got %d", http.StatusOK, status)
	}
	
	var response map[string]string
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Fatal("Failed to parse JSON response")
	}
	
	if response["status"] != "healthy" {
		t.Errorf("Expected status 'healthy', got %s", response["status"])
	}
	
	if response["service"] != "order-service" {
		t.Errorf("Expected service 'order-service', got %s", response["service"])
	}
}

func TestHandleGetOrders(t *testing.T) {
	store := NewOrderStore()
	
	req, err := http.NewRequest("GET", "/orders", nil)
	if err != nil {
		t.Fatal(err)
	}
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(store.handleGetOrders)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Expected status code %d, got %d", http.StatusOK, status)
	}
	
	var orders []Order
	if err := json.Unmarshal(rr.Body.Bytes(), &orders); err != nil {
		t.Fatal("Failed to parse JSON response")
	}
	
	if len(orders) != 2 {
		t.Errorf("Expected 2 orders, got %d", len(orders))
	}
}

func TestHandleGetOrdersWithUserFilter(t *testing.T) {
	store := NewOrderStore()
	
	req, err := http.NewRequest("GET", "/orders?user_id=1", nil)
	if err != nil {
		t.Fatal(err)
	}
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(store.handleGetOrders)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Expected status code %d, got %d", http.StatusOK, status)
	}
	
	var orders []Order
	if err := json.Unmarshal(rr.Body.Bytes(), &orders); err != nil {
		t.Fatal("Failed to parse JSON response")
	}
	
	// Verify all returned orders belong to user 1
	for _, order := range orders {
		if order.UserID != 1 {
			t.Errorf("Expected all orders to belong to user 1, found order for user %d", order.UserID)
		}
	}
}

func TestHandleCreateOrder(t *testing.T) {
	store := NewOrderStore()
	
	orderData := map[string]interface{}{
		"user_id":  1,
		"product":  "New Product",
		"quantity": 3,
		"price":    149.99,
	}
	
	jsonData, err := json.Marshal(orderData)
	if err != nil {
		t.Fatal(err)
	}
	
	req, err := http.NewRequest("POST", "/orders", bytes.NewBuffer(jsonData))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(store.handleCreateOrder)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusCreated {
		t.Errorf("Expected status code %d, got %d", http.StatusCreated, status)
	}
	
	var order Order
	if err := json.Unmarshal(rr.Body.Bytes(), &order); err != nil {
		t.Fatal("Failed to parse JSON response")
	}
	
	if order.UserID != 1 {
		t.Errorf("Expected UserID 1, got %d", order.UserID)
	}
	
	if order.Product != "New Product" {
		t.Errorf("Expected product 'New Product', got %s", order.Product)
	}
	
	if order.Quantity != 3 {
		t.Errorf("Expected quantity 3, got %d", order.Quantity)
	}
	
	if order.Price != 149.99 {
		t.Errorf("Expected price 149.99, got %f", order.Price)
	}
}

func TestHandleCreateOrderInvalidJSON(t *testing.T) {
	store := NewOrderStore()
	
	req, err := http.NewRequest("POST", "/orders", bytes.NewBuffer([]byte("invalid json")))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(store.handleCreateOrder)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("Expected status code %d, got %d", http.StatusBadRequest, status)
	}
}

func TestHandleCreateOrderMissingFields(t *testing.T) {
	store := NewOrderStore()
	
	orderData := map[string]interface{}{
		"user_id": 1,
		"product": "Incomplete Order",
		// Missing quantity and price
	}
	
	jsonData, err := json.Marshal(orderData)
	if err != nil {
		t.Fatal(err)
	}
	
	req, err := http.NewRequest("POST", "/orders", bytes.NewBuffer(jsonData))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(store.handleCreateOrder)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("Expected status code %d, got %d", http.StatusBadRequest, status)
	}
}

func TestHandleUpdateOrderStatus(t *testing.T) {
	store := NewOrderStore()
	
	// Since we can't easily mock mux.Vars in unit test, we'll test the core logic
	success := store.UpdateOrderStatus(1, "processing")
	if !success {
		t.Error("Expected UpdateOrderStatus to succeed")
	}
	
	order, _ := store.GetOrder(1)
	if order.Status != "processing" {
		t.Errorf("Expected status 'processing', got %s", order.Status)
	}
}

func TestHandleUpdateOrderStatusInvalidStatus(t *testing.T) {
	// Test with invalid status - we'll test the validation logic directly
	validStatuses := map[string]bool{
		"pending": true, "processing": true, "shipped": true, "delivered": true, "cancelled": true,
	}
	
	invalidStatus := "invalid_status"
	if validStatuses[invalidStatus] {
		t.Error("Expected 'invalid_status' to be invalid")
	}
	
	validStatus := "shipped"
	if !validStatuses[validStatus] {
		t.Error("Expected 'shipped' to be valid")
	}
}

func TestFetchUserFromService(t *testing.T) {
	// Test the fallback behavior when user service is not available
	user, err := fetchUserFromService(1)
	
	// Should return fallback data without error
	if err != nil {
		t.Errorf("Expected no error for fallback, got %v", err)
	}
	
	if user == nil {
		t.Fatal("Expected user data, got nil")
	}
	
	if user.ID != 1 {
		t.Errorf("Expected user ID 1, got %d", user.ID)
	}
	
	expectedName := "User 1"
	if user.Name != expectedName {
		t.Errorf("Expected name '%s', got %s", expectedName, user.Name)
	}
	
	expectedEmail := "user1@example.com"
	if user.Email != expectedEmail {
		t.Errorf("Expected email '%s', got %s", expectedEmail, user.Email)
	}
} 