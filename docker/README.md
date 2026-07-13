# Docker Containers

This directory contains configuration files and Docker Compose stacks for local services running on docker hosts in the home lab.

## Structure

Each sub-directory should house a specific stack or related group of services:

- `monitoring/`: Prometheus, Grafana, and Node Exporter stack.
- `portainer/`: Portainer CE for container management.
- `homelab-apps/`: Dashboard, wiki, or local media servers.

## Running Stacks

To run a stack, source the environment variables first:

```bash
source ../bin/load-env.sh
cd portainer/
docker compose up -d
```
