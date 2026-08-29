// Package aiclient is the Go API's client for the internal Python AI service.
// The Flutter apps never call the AI service directly — they go through the Go
// API, which credits/authorizes the request and then calls here.
package aiclient

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type Client struct {
	baseURL string
	http    *http.Client
}

func New(baseURL string) *Client {
	return &Client{baseURL: baseURL, http: &http.Client{Timeout: 180 * time.Second}}
}

// GeneratePrompt calls the AI service's prompt composer.
func (c *Client) GeneratePrompt(ctx context.Context, body any) (json.RawMessage, error) {
	return c.post(ctx, "/prompts/generate", body)
}

// GenerateImage calls the AI service's image generator.
func (c *Client) GenerateImage(ctx context.Context, body any) (json.RawMessage, error) {
	return c.post(ctx, "/images/generate", body)
}

func (c *Client) post(ctx context.Context, path string, body any) (json.RawMessage, error) {
	buf, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+path, bytes.NewReader(buf))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("ai service %d: %s", resp.StatusCode, string(data))
	}
	return json.RawMessage(data), nil
}
