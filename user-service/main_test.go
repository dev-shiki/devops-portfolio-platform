package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gorilla/mux"
	"user-service/internal/httpx"
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
	handler := httpx.NewHealthHandler("user-service")
	handler(rr, req)
	
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
	
	handler(rr, req)
	
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
	
	handler(rr, req)
	
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
	
	handler(rr, req)
	
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
	
	handler(rr, req)
	
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("Expected status code %d, got %d", http.StatusBadRequest, status)
	}
} 

func TestHandleGetUser_InvalidID(t *testing.T) {
	store := NewUserStore()
	req, err := http.NewRequest("GET", "/users/abc", nil)
	if err != nil {
		t.Fatal(err)
	}
	// Simulasi mux vars
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		vars := map[string]string{"id": "abc"}
		r = mux.SetURLVars(r, vars)
		store.handleGetUser(w, r)
	})
	handler(rr, req)
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("Expected status code %d, got %d", http.StatusBadRequest, status)
	}
}

func TestHandleGetUser_NotFound(t *testing.T) {
	store := NewUserStore()
	req, err := http.NewRequest("GET", "/users/999", nil)
	if err != nil {
		t.Fatal(err)
	}
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		vars := map[string]string{"id": "999"}
		r = mux.SetURLVars(r, vars)
		store.handleGetUser(w, r)
	})
	handler(rr, req)
	if status := rr.Code; status != http.StatusNotFound {
		t.Errorf("Expected status code %d, got %d", http.StatusNotFound, status)
	}
}

func TestAuthorHandler(t *testing.T) {
	req, err := http.NewRequest("GET", "/author", nil)
	if err != nil {
		t.Fatal(err)
	}
	rr := httptest.NewRecorder()
	handler := httpx.AuthorHandler
	handler(rr, req)
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Expected status code %d, got %d", http.StatusOK, status)
	}
	if ct := rr.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("Expected Content-Type application/json, got %s", ct)
	}
}

func TestCORSPreflight(t *testing.T) {
	store := NewUserStore()
	r := mux.NewRouter()
	r.HandleFunc("/users", store.handleGetUsers).Methods("GET", "OPTIONS") // tambahkan OPTIONS agar middleware dijalankan
	// Tambahkan CORS middleware
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
			if r.Method == "OPTIONS" {
				w.WriteHeader(http.StatusOK)
				return
			}
			next.ServeHTTP(w, r)
		})
	})

	req, err := http.NewRequest("OPTIONS", "/users", nil)
	if err != nil {
		t.Fatal(err)
	}
	rr := httptest.NewRecorder()
	r.ServeHTTP(rr, req)
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Expected status code %d, got %d", http.StatusOK, status)
	}
	if rr.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Errorf("CORS header missing")
	}
} 