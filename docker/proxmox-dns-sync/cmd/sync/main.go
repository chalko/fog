package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/fog-homelab/proxmox-dns-sync/pkg/pihole"
	"github.com/fog-homelab/proxmox-dns-sync/pkg/pve"
)

func main() {
	log.Println("Starting proxmox-dns-sync service...")

	pveURL := getEnvOrDefault("EXTERNAL_DNS_PROXMOX_URL", "https://10.7.82.10:8006/api2/json")
	tokenID := os.Getenv("EXTERNAL_DNS_PROXMOX_TOKEN_ID")
	tokenSecret := os.Getenv("EXTERNAL_DNS_PROXMOX_TOKEN_SECRET")
	piholeURL := getEnvOrDefault("EXTERNAL_DNS_PIHOLE_SERVER", "http://10.5.110.3")
	piholePassword := os.Getenv("EXTERNAL_DNS_PIHOLE_PASSWORD")
	domainSuffix := getEnvOrDefault("DOMAIN_SUFFIX", "node.fog.chalko.com")

	if tokenID == "" || tokenSecret == "" {
		log.Println("Warning: Proxmox token credentials not set. Running in dry-run mode.")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	pveClient := pve.NewClient(pveURL, tokenID, tokenSecret)
	piClient := pihole.NewClient(piholeURL, piholePassword)

	hosts, err := pveClient.GetGuestIPs(ctx, domainSuffix)
	if err != nil {
		log.Printf("Error querying Proxmox guests: %v\n", err)
	} else {
		log.Printf("Discovered %d active Proxmox host entries for domain suffix '%s'\n", len(hosts), domainSuffix)
		for hostname, ip := range hosts {
			log.Printf("  - %s -> %s\n", hostname, ip)
		}
	}

	if piholePassword != "" && len(hosts) > 0 {
		err = piClient.SyncRecords(ctx, hosts)
		if err != nil {
			log.Printf("Error syncing DNS records to Pi-hole: %v\n", err)
		} else {
			log.Println("DNS records synchronized successfully with Pi-hole.")
		}
	} else {
		log.Println("Skipping Pi-hole update (no password set or no hosts found).")
	}

	log.Println("proxmox-dns-sync cycle complete.")
}

func getEnvOrDefault(key, defaultValue string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultValue
}
