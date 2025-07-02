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
		http.Error(w, "Invalid user ID", http.StatusBadRequest)
		httpRequests.WithLabelValues(r.Method, "/users/{id}", "400").Inc()
		return
	}
	
	user, exists := s.GetUser(id)
	if !exists {
		http.Error(w, "User not found", http.StatusNotFound)
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
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		httpRequests.WithLabelValues(r.Method, "/users", "400").Inc()
		return
	}
	
	if req.Name == "" || req.Email == "" {
		http.Error(w, "Name and email are required", http.StatusBadRequest)
		httpRequests.WithLabelValues(r.Method, "/users", "400").Inc()
		return
	}
	
	user := s.CreateUser(req.Name, req.Email)
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(user)
	
	httpRequests.WithLabelValues(r.Method, "/users", "201").Inc()
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]string{
		"status":    "healthy",
		"service":   "user-service",
		"timestamp": time.Now().Format(time.RFC3339),
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func main() {
	store := NewUserStore()
	
	r := mux.NewRouter()
	
	// API routes
	r.HandleFunc("/health", healthHandler).Methods("GET")
	r.HandleFunc("/users", store.handleGetUsers).Methods("GET")
	r.HandleFunc("/users/{id:[0-9]+}", store.handleGetUser).Methods("GET")
	r.HandleFunc("/users", store.handleCreateUser).Methods("POST")
	
	// Metrics endpoint
	r.Handle("/metrics", promhttp.Handler())
	
	// Enable CORS
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
	
	port := ":8080"
	log.Printf("User Service starting on port %s", port)
	log.Printf("Health check: http://localhost%s/health", port)
	log.Printf("API endpoint: http://localhost%s/users", port)
	log.Printf("Metrics: http://localhost%s/metrics", port)
	
	if err := http.ListenAndServe(port, r); err != nil {
		log.Fatal("Server failed to start:", err)
	}
} 