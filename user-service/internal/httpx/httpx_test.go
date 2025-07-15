package httpx

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestWriteError(t *testing.T) {
	rr := httptest.NewRecorder()
	WriteError(rr, http.StatusBadRequest, "error msg")
	if rr.Code != http.StatusBadRequest {
		t.Errorf("Expected status %d, got %d", http.StatusBadRequest, rr.Code)
	}
	var resp map[string]string
	json.NewDecoder(rr.Body).Decode(&resp)
	if resp["error"] != "error msg" {
		t.Errorf("Expected error msg, got %v", resp["error"])
	}
}

func TestHealthHandler(t *testing.T) {
	rr := httptest.NewRecorder()
	h := NewHealthHandler("user-service")
	h(rr, httptest.NewRequest("GET", "/health", nil))
	if rr.Code != http.StatusOK {
		t.Errorf("Expected 200, got %d", rr.Code)
	}
	var resp map[string]string
	json.NewDecoder(rr.Body).Decode(&resp)
	if resp["status"] != "healthy" || resp["service"] != "user-service" {
		t.Errorf("Unexpected body: %v", resp)
	}
}

func TestAuthorHandler(t *testing.T) {
	rr := httptest.NewRecorder()
	AuthorHandler(rr, httptest.NewRequest("GET", "/author", nil))
	if ct := rr.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
		t.Errorf("Expected Content-Type application/json, got %s", ct)
	}
	var resp map[string]string
	json.NewDecoder(rr.Body).Decode(&resp)
	if resp["author"] == "" || resp["github"] == "" {
		t.Errorf("Unexpected body: %v", resp)
	}
}

func TestCORSMiddleware_OPTIONS(t *testing.T) {
	r := http.NewServeMux()
	r.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})
	cors := CORSMiddleware(r)
	rr := httptest.NewRecorder()
	req := httptest.NewRequest("OPTIONS", "/", nil)
	cors.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Errorf("Expected 200, got %d", rr.Code)
	}
	if rr.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Errorf("CORS header missing")
	}
} 