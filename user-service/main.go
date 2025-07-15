/*
 * DevOps Portfolio Platform - User Service
 * 
 * Author: dev-shiki (Your Personal Portfolio)
 * Created: 2025-01-27 (Portfolio Development Session)
 * Project: PORTFOLIO-DEVOPS-2025-V1
 * License: MIT
 * 
 * Personal Signature: DSK-PORTFOLIO-2025-USER-SVC-ORIG
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
	"log"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"user-service/internal/httpx"
)

// User represents a user in the system
type User struct {
	ID       int    `json:"id"`
	Name     string `json:"name"`
	Email    string `json:"email"`
	Created  string `json:"created"`
}

// UserStore provides in-memory storage for users
type UserStore struct {
	users map[int]*User
	mutex sync.RWMutex
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
)

func init() {
	prometheus.MustRegister(httpRequests)
	prometheus.MustRegister(httpDuration)
}

// NewUserStore creates a new user store
func NewUserStore() *UserStore {
	store := &UserStore{
		users:  make(map[int]*User),
		nextID: 1,
	}
	
	// Add some sample data
	store.CreateUser("John Doe", "john@example.com")
	store.CreateUser("Jane Smith", "jane@example.com")
	
	return store
}

// CreateUser creates a new user
func (s *UserStore) CreateUser(name, email string) *User {
	s.mutex.Lock()
	defer s.mutex.Unlock()
	
	user := &User{
		ID:      s.nextID,
		Name:    name,
		Email:   email,
		Created: time.Now().Format(time.RFC3339),
	}
	
	s.users[user.ID] = user
	s.nextID++
	
	return user
}

// GetUser retrieves a user by ID
func (s *UserStore) GetUser(id int) (*User, bool) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	
	user, exists := s.users[id]
	return user, exists
}

// GetAllUsers retrieves all users
func (s *UserStore) GetAllUsers() []*User {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	
	users := make([]*User, 0, len(s.users))
	for _, user := range s.users {
		users = append(users, user)
	}
	
	return users
}

// HTTP Handlers
func (s *UserStore) handleGetUsers(w http.ResponseWriter, r *http.Request) {
	timer := prometheus.NewTimer(httpDuration.WithLabelValues(r.Method, "/users"))
	defer timer.ObserveDuration()
	
	users := s.GetAllUsers()
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
	
	httpRequests.WithLabelValues(r.Method, "/users", "200").Inc()
}

func (s *UserStore) handleGetUser(w http.ResponseWriter, r *http.Request) {
	timer := prometheus.NewTimer(httpDuration.WithLabelValues(r.Method, "/users/{id}"))
	defer timer.ObserveDuration()
	
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "Invalid user ID")
		httpRequests.WithLabelValues(r.Method, "/users/{id}", "400").Inc()
		return
	}
	
	user, exists := s.GetUser(id)
	if !exists {
		httpx.WriteError(w, http.StatusNotFound, "User not found")
		httpRequests.WithLabelValues(r.Method, "/users/{id}", "404").Inc()
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
	
	httpRequests.WithLabelValues(r.Method, "/users/{id}", "200").Inc()
}

func (s *UserStore) handleCreateUser(w http.ResponseWriter, r *http.Request) {
	timer := prometheus.NewTimer(httpDuration.WithLabelValues(r.Method, "/users"))
	defer timer.ObserveDuration()
	
	var req struct {
		Name  string `json:"name"`
		Email string `json:"email"`
	}
	
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "Invalid JSON")
		httpRequests.WithLabelValues(r.Method, "/users", "400").Inc()
		return
	}
	
	if req.Name == "" || req.Email == "" {
		httpx.WriteError(w, http.StatusBadRequest, "Name and email are required")
		httpRequests.WithLabelValues(r.Method, "/users", "400").Inc()
		return
	}
	
	user := s.CreateUser(req.Name, req.Email)
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(user)
	
	httpRequests.WithLabelValues(r.Method, "/users", "201").Inc()
}

func main() {
	store := NewUserStore()
	
	r := mux.NewRouter()
	r.Use(httpx.CORSMiddleware)
	r.HandleFunc("/health", httpx.NewHealthHandler("user-service")).Methods("GET")
	r.HandleFunc("/author", httpx.AuthorHandler).Methods("GET")
	r.HandleFunc("/users", store.handleGetUsers).Methods("GET")
	r.HandleFunc("/users/{id:[0-9]+}", store.handleGetUser).Methods("GET")
	r.HandleFunc("/users", store.handleCreateUser).Methods("POST")
	
	// Metrics endpoint
	r.Handle("/metrics", promhttp.Handler())
	
	port := ":8080"
	log.Printf("User Service starting on port %s", port)
	log.Printf("Health check: http://localhost%s/health", port)
	log.Printf("API endpoint: http://localhost%s/users", port)
	log.Printf("Metrics: http://localhost%s/metrics", port)
	
	if err := http.ListenAndServe(port, r); err != nil {
		log.Fatal("Server failed to start:", err)
	}
} 