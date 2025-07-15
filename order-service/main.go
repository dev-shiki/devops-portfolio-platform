/*
 * DevOps Portfolio Platform - Order Service
 * 
 * Author: dev-shiki (Your Personal Portfolio)
 * Created: 2025-01-27 (Portfolio Development Session)
 * Project: PORTFOLIO-DEVOPS-2025-V1
 * License: MIT
 * 
 * Personal Signature: DSK-PORTFOLIO-2025-ORDER-SVC-ORIG
 * Build Timestamp: 2025-01-27T12:00:00Z
 * 
 * This is an original work created for professional portfolio demonstration.
 * Implementation showcases enterprise-grade microservices architecture
 * with comprehensive monitoring, observability, and DevOps best practices.
 * 
 * Contact: github.com/dev-shiki
 * Portfolio: DevOps Engineering & Cloud Architecture
 */

package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"order-service/internal/httpx"
)

// Order represents an order in the system
type Order struct {
	ID       int     `json:"id"`
	UserID   int     `json:"user_id"`
	Product  string  `json:"product"`
	Quantity int     `json:"quantity"`
	Price    float64 `json:"price"`
	Status   string  `json:"status"`
	Created  string  `json:"created"`
}

// User represents user data from user-service
type User struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

// OrderWithUser represents an order with user information
type OrderWithUser struct {
	Order
	UserName  string `json:"user_name,omitempty"`
	UserEmail string `json:"user_email,omitempty"`
}

// OrderStore provides in-memory storage for orders
type OrderStore struct {
	orders map[int]*Order
	mutex  sync.RWMutex
	nextID int
}

// Prometheus metrics
var (
	httpRequests = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)
	
	httpDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "http_request_duration_seconds",
			Help: "Duration of HTTP requests",
		},
		[]string{"method", "endpoint"},
	)
	
	orderCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "orders_total",
			Help: "Total number of orders created",
		},
		[]string{"status"},
	)
)

func init() {
	prometheus.MustRegister(httpRequests)
	prometheus.MustRegister(httpDuration)
	prometheus.MustRegister(orderCounter)
}

// NewOrderStore creates a new order store
func NewOrderStore() *OrderStore {
	store := &OrderStore{
		orders: make(map[int]*Order),
		nextID: 1,
	}
	
	// Add some sample data
	store.CreateOrder(1, "Laptop", 1, 999.99)
	store.CreateOrder(2, "Mouse", 2, 25.00)
	
	return store
}

// CreateOrder creates a new order
func (s *OrderStore) CreateOrder(userID int, product string, quantity int, price float64) *Order {
	s.mutex.Lock()
	defer s.mutex.Unlock()
	
	order := &Order{
		ID:       s.nextID,
		UserID:   userID,
		Product:  product,
		Quantity: quantity,
		Price:    price,
		Status:   "pending",
		Created:  time.Now().Format(time.RFC3339),
	}
	
	s.orders[order.ID] = order
	s.nextID++
	
	orderCounter.WithLabelValues(order.Status).Inc()
	
	return order
}

// GetOrder retrieves an order by ID
func (s *OrderStore) GetOrder(id int) (*Order, bool) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	
	order, exists := s.orders[id]
	return order, exists
}

// GetAllOrders retrieves all orders
func (s *OrderStore) GetAllOrders() []*Order {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	
	orders := make([]*Order, 0, len(s.orders))
	for _, order := range s.orders {
		orders = append(orders, order)
	}
	
	return orders
}

// GetOrdersByUser retrieves orders for a specific user
func (s *OrderStore) GetOrdersByUser(userID int) []*Order {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	
	var userOrders []*Order
	for _, order := range s.orders {
		if order.UserID == userID {
			userOrders = append(userOrders, order)
		}
	}
	
	return userOrders
}

// UpdateOrderStatus updates the status of an order
func (s *OrderStore) UpdateOrderStatus(id int, status string) bool {
	s.mutex.Lock()
	defer s.mutex.Unlock()
	
	order, exists := s.orders[id]
	if !exists {
		return false
	}
	
	order.Status = status
	orderCounter.WithLabelValues(status).Inc()
	
	return true
}

// fetchUserFromService fetches user data from user-service
func fetchUserFromService(userID int) (*User, error) {
	// In a real implementation, this would call the user-service
	// For demo purposes, we'll simulate the response
	url := fmt.Sprintf("http://user-service:8080/users/%d", userID)
	
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		// Fallback for local development
		return &User{
			ID:    userID,
			Name:  fmt.Sprintf("User %d", userID),
			Email: fmt.Sprintf("user%d@example.com", userID),
		}, nil
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("user service returned status %d", resp.StatusCode)
	}
	
	var user User
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		return nil, err
	}
	
	return &user, nil
}

// HTTP Handlers
func (s *OrderStore) handleGetOrders(w http.ResponseWriter, r *http.Request) {
	timer := prometheus.NewTimer(httpDuration.WithLabelValues(r.Method, "/orders"))
	defer timer.ObserveDuration()
	
	userIDStr := r.URL.Query().Get("user_id")
	var orders []*Order
	
	if userIDStr != "" {
		userID, err := strconv.Atoi(userIDStr)
		if err != nil {
			httpx.WriteError(w, http.StatusBadRequest, "Invalid user ID")
			httpRequests.WithLabelValues(r.Method, "/orders", "400").Inc()
			return
		}
		orders = s.GetOrdersByUser(userID)
	} else {
		orders = s.GetAllOrders()
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(orders)
	
	httpRequests.WithLabelValues(r.Method, "/orders", "200").Inc()
}

func (s *OrderStore) handleGetOrder(w http.ResponseWriter, r *http.Request) {
	timer := prometheus.NewTimer(httpDuration.WithLabelValues(r.Method, "/orders/{id}"))
	defer timer.ObserveDuration()
	
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "Invalid order ID")
		httpRequests.WithLabelValues(r.Method, "/orders/{id}", "400").Inc()
		return
	}
	
	order, exists := s.GetOrder(id)
	if !exists {
		httpx.WriteError(w, http.StatusNotFound, "Order not found")
		httpRequests.WithLabelValues(r.Method, "/orders/{id}", "404").Inc()
		return
	}
	
	// Try to fetch user information
	orderWithUser := OrderWithUser{Order: *order}
	if user, err := fetchUserFromService(order.UserID); err == nil {
		orderWithUser.UserName = user.Name
		orderWithUser.UserEmail = user.Email
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(orderWithUser)
	
	httpRequests.WithLabelValues(r.Method, "/orders/{id}", "200").Inc()
}

func (s *OrderStore) handleCreateOrder(w http.ResponseWriter, r *http.Request) {
	timer := prometheus.NewTimer(httpDuration.WithLabelValues(r.Method, "/orders"))
	defer timer.ObserveDuration()
	
	var req struct {
		UserID   int     `json:"user_id"`
		Product  string  `json:"product"`
		Quantity int     `json:"quantity"`
		Price    float64 `json:"price"`
	}
	
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "Invalid JSON")
		httpRequests.WithLabelValues(r.Method, "/orders", "400").Inc()
		return
	}
	
	if req.UserID <= 0 || req.Product == "" || req.Quantity <= 0 || req.Price <= 0 {
		httpx.WriteError(w, http.StatusBadRequest, "All fields are required and must be valid")
		httpRequests.WithLabelValues(r.Method, "/orders", "400").Inc()
		return
	}
	
	order := s.CreateOrder(req.UserID, req.Product, req.Quantity, req.Price)
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(order)
	
	httpRequests.WithLabelValues(r.Method, "/orders", "201").Inc()
}

func (s *OrderStore) handleUpdateOrderStatus(w http.ResponseWriter, r *http.Request) {
	timer := prometheus.NewTimer(httpDuration.WithLabelValues(r.Method, "/orders/{id}/status"))
	defer timer.ObserveDuration()
	
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "Invalid order ID")
		httpRequests.WithLabelValues(r.Method, "/orders/{id}/status", "400").Inc()
		return
	}
	
	var req struct {
		Status string `json:"status"`
	}
	
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "Invalid JSON")
		httpRequests.WithLabelValues(r.Method, "/orders/{id}/status", "400").Inc()
		return
	}
	
	validStatuses := map[string]bool{
		"pending": true, "processing": true, "shipped": true, "delivered": true, "cancelled": true,
	}
	
	if !validStatuses[req.Status] {
		httpx.WriteError(w, http.StatusBadRequest, "Invalid status")
		httpRequests.WithLabelValues(r.Method, "/orders/{id}/status", "400").Inc()
		return
	}
	
	if !s.UpdateOrderStatus(id, req.Status) {
		httpx.WriteError(w, http.StatusNotFound, "Order not found")
		httpRequests.WithLabelValues(r.Method, "/orders/{id}/status", "404").Inc()
		return
	}
	
	response := map[string]string{"status": "updated"}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
	
	httpRequests.WithLabelValues(r.Method, "/orders/{id}/status", "200").Inc()
}

func main() {
	store := NewOrderStore()
	
	r := mux.NewRouter()
	r.Use(httpx.CORSMiddleware)
	r.HandleFunc("/health", httpx.NewHealthHandler("order-service")).Methods("GET")
	r.HandleFunc("/author", httpx.AuthorHandler).Methods("GET")
	r.HandleFunc("/orders", store.handleGetOrders).Methods("GET")
	r.HandleFunc("/orders/{id:[0-9]+}", store.handleGetOrder).Methods("GET")
	r.HandleFunc("/orders", store.handleCreateOrder).Methods("POST")
	r.HandleFunc("/orders/{id:[0-9]+}/status", store.handleUpdateOrderStatus).Methods("PUT")
	
	// Metrics endpoint
	r.Handle("/metrics", promhttp.Handler())
	
	port := ":8081"
	log.Printf("Order Service starting on port %s", port)
	log.Printf("Health check: http://localhost%s/health", port)
	log.Printf("API endpoint: http://localhost%s/orders", port)
	log.Printf("Metrics: http://localhost%s/metrics", port)
	
	if err := http.ListenAndServe(port, r); err != nil {
		log.Fatal("Server failed to start:", err)
	}
} 