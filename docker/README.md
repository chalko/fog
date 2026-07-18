# Docker Containers

This directory contains configuration files and Docker Compose stacks for local services running on docker hosts in the home lab.

## Structure

Each sub-directory houses a specific stack or related group of services (all currently planned):

- `portainer/` (*Planned*): Portainer CE for container management.
- `monitoring/` (*Planned*): Prometheus, Grafana, and Node Exporter stack.
- `homelab-apps/` (*Planned*): Dashboard, wiki, or local media servers.

## Running Stacks

To run a stack, source the environment variables first:

```bash
source ../bin/load-env.sh
cd <stack-directory>/
docker compose up -d
```


