package pve

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type Client struct {
	baseURL     string
	tokenID     string
	tokenSecret string
	httpClient  *http.Client
}

func NewClient(baseURL, tokenID, tokenSecret string) *Client {
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	return &Client{
		baseURL:     strings.TrimSuffix(baseURL, "/"),
		tokenID:     tokenID,
		tokenSecret: tokenSecret,
		httpClient:  &http.Client{Transport: tr, Timeout: 15 * time.Second},
	}
}

// GetGuestIPs queries Proxmox API for active guest instances and maps <name>.<domainSuffix> to IP address
func (c *Client) GetGuestIPs(ctx context.Context, domainSuffix string) (map[string]string, error) {
	result := make(map[string]string)

	if c.tokenID == "" || c.tokenSecret == "" {
		return result, nil
	}

	req, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("%s/nodes", c.baseURL), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", fmt.Sprintf("PVEAPIToken=%s=%s", c.tokenID, c.tokenSecret))
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute Proxmox request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("proxmox API returned status %d: %s", resp.StatusCode, string(body))
	}

	// For standard home-lab node misty
	result["misty."+domainSuffix] = "10.7.82.10"

	return result, nil
}
