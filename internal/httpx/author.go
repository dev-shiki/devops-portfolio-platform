package httpx

import (
	"encoding/json"
	"net/http"
)

func AuthorHandler(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{
		"author": "dev-shiki",
		"github": "https://github.com/dev-shiki",
	})
} 