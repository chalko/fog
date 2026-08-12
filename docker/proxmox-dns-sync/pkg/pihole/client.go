package pihole

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type Client struct {
	serverURL  string
	password   string
	httpClient *http.Client
}

func NewClient(serverURL, password string) *Client {
	return &Client{
		serverURL:  strings.TrimSuffix(serverURL, "/"),
		password:   password,
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}
}

// SyncRecords pushes DNS entries to Pi-hole custom DNS API
func (c *Client) SyncRecords(ctx context.Context, hosts map[string]string) error {
	if c.password == "" {
		return fmt.Errorf("no Pi-hole password provided")
	}

	for host, ip := range hosts {
		err := c.addCustomDNS(ctx, host, ip)
		if err != nil {
			return fmt.Errorf("failed to add DNS record %s -> %s: %w", host, ip, err)
		}
	}
	return nil
}

func (c *Client) addCustomDNS(ctx context.Context, domain, ip string) error {
	url := fmt.Sprintf("%s/api/customdns?action=add&ip=%s&domain=%s", c.serverURL, ip, domain)
	req, err := http.NewRequestWithContext(ctx, "POST", url, nil)
	if err != nil {
		return err
	}

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.password))
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 && resp.StatusCode != http.StatusConflict {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("pihole API returned status %d: %s", resp.StatusCode, string(body))
	}
	return nil
}
