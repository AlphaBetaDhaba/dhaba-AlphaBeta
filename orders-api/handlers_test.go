package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealthHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rr := httptest.NewRecorder()

	healthHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rr.Code)
	}
	if !strings.Contains(rr.Body.String(), "ok") {
		t.Errorf("expected body to contain 'ok', got: %s", rr.Body.String())
	}
}

func TestCreateOrderHandler_EmptyItems(t *testing.T) {
	tests := []struct {
		name string
		body string
	}{
		{"empty items array", `{"items":[]}`},
		{"missing items field", `{}`},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/orders", strings.NewReader(tc.body))
			req.Header.Set("Content-Type", "application/json")
			rr := httptest.NewRecorder()

			// nil db/redis: validation should fail before any DB/redis call
			createOrderHandler(nil, nil, rr, req)

			if rr.Code != http.StatusBadRequest {
				t.Errorf("expected status 400, got %d (body: %s)", rr.Code, rr.Body.String())
			}
		})
	}
}
