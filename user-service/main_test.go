package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestNewUserStore(t *testing.T) {
	store := NewUserStore()
	
	if store == nil {
		t.Fatal("NewUserStore() returned nil")
	}
	
	if len(store.users) != 2 {
		t.Errorf("Expected 2 initial users, got %d", len(store.users))
	}
	
	if store.nextID != 3 {
		t.Errorf("Expected nextID to be 3, got %d", store.nextID)
	}
}

func TestCreateUser(t *testing.T) {
	store := NewUserStore()
	
	user := store.CreateUser("Test User", "test@example.com")
	
	if user == nil {
		t.Fatal("CreateUser() returned nil")
	}
	
	if user.Name != "Test User" {
		t.Errorf("Expected name 'Test User', got %s", user.Name)
	}
	
	if user.Email != "test@example.com" {
		t.Errorf("Expected email 'test@example.com', got %s", user.Email)
	}
	
	if user.ID <= 0 {
		t.Errorf("Expected positive ID, got %d", user.ID)
	}
}

func TestGetUser(t *testing.T) {
	store := NewUserStore()
	
	// Test existing user
	user, exists := store.GetUser(1)
	if !exists {
		t.Error("Expected user 1 to exist")
	}
	if user == nil {
		t.Fatal("GetUser() returned nil for existing user")
	}
	
	// Test non-existing user
	_, exists = store.GetUser(999)
	if exists {
		t.Error("Expected user 999 to not exist")
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
	
	if response["service"] != "user-service" {
		t.Errorf("Expected service 'user-service', got %s", response["service"])
	}
}

func TestHandleGetUsers(t *testing.T) {
	store := NewUserStore()
	
	req, err := http.NewRequest("GET", "/users", nil)
	if err != nil {
		t.Fatal(err)
	}
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(store.handleGetUsers)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Expected status code %d, got %d", http.StatusOK, status)
	}
	
	var users []User
	if err := json.Unmarshal(rr.Body.Bytes(), &users); err != nil {
		t.Fatal("Failed to parse JSON response")
	}
	
	if len(users) != 2 {
		t.Errorf("Expected 2 users, got %d", len(users))
	}
}

func TestHandleCreateUser(t *testing.T) {
	store := NewUserStore()
	
	userData := map[string]string{
		"name":  "New User",
		"email": "newuser@example.com",
	}
	
	jsonData, err := json.Marshal(userData)
	if err != nil {
		t.Fatal(err)
	}
	
	req, err := http.NewRequest("POST", "/users", bytes.NewBuffer(jsonData))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(store.handleCreateUser)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusCreated {
		t.Errorf("Expected status code %d, got %d", http.StatusCreated, status)
	}
	
	var user User
	if err := json.Unmarshal(rr.Body.Bytes(), &user); err != nil {
		t.Fatal("Failed to parse JSON response")
	}
	
	if user.Name != "New User" {
		t.Errorf("Expected name 'New User', got %s", user.Name)
	}
	
	if user.Email != "newuser@example.com" {
		t.Errorf("Expected email 'newuser@example.com', got %s", user.Email)
	}
}

func TestHandleCreateUserInvalidJSON(t *testing.T) {
	store := NewUserStore()
	
	req, err := http.NewRequest("POST", "/users", bytes.NewBuffer([]byte("invalid json")))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(store.handleCreateUser)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("Expected status code %d, got %d", http.StatusBadRequest, status)
	}
}

func TestHandleCreateUserMissingFields(t *testing.T) {
	store := NewUserStore()
	
	userData := map[string]string{
		"name": "Only Name",
		// Missing email
	}
	
	jsonData, err := json.Marshal(userData)
	if err != nil {
		t.Fatal(err)
	}
	
	req, err := http.NewRequest("POST", "/users", bytes.NewBuffer(jsonData))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(store.handleCreateUser)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("Expected status code %d, got %d", http.StatusBadRequest, status)
	}
} 