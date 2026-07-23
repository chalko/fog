resource "pihole_local_dns" "misty" {
  hostname = "misty.fog.chalko.com"
  ip       = "10.7.82.10"
}

resource "pihole_local_dns" "ollama" {
  hostname = "ollama.fog.chalko.com"
  ip       = "10.7.82.100"
}

