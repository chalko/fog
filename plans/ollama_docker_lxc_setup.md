# Plan: Run Ollama via Docker inside Proxmox LXC

This plan details how to securely run Ollama using its official Docker image inside the newly provisioned LXC container (`ollama`, VMID `9100`). This avoids piping unverified installation scripts from the web directly to the host shell.

---

## 1. Prerequisites & Sandbox Configuration
*   **LXC Nesting**: The LXC container is configured in Terraform with `nesting = true` which enables Docker-in-LXC containerization.
*   **Storage**: A 40 GB storage volume on the fast ZFS pool is mounted to the container to accommodate model downloads and Docker image layers.

---

## 2. Setup Workflow

### Phase 1: Install Docker on LXC Host
We will log into the container and install Docker using the standard Debian stable package manager (no curl-piped scripts).

1.  Access the LXC shell via the Proxmox host:
    ```bash
    ssh root@10.7.82.10 "pct enter 9100"
    ```
2.  Update repositories and install the stable Docker engine:
    ```bash
    apt-get update
    apt-get install -y docker.io
    ```
3.  Enable and start the Docker service:
    ```bash
    systemctl enable --now docker
    ```

### Phase 2: Run the Official Ollama Container
We run the verified official Docker Hub image (`ollama/ollama`) with persistence.

1.  Launch the container:
    ```bash
    docker run -d \
      --name ollama \
      --restart always \
      -v ollama_data:/root/.ollama \
      -p 11434:11434 \
      ollama/ollama:latest
    ```
    *   **`-v ollama_data:/root/.ollama`**: Mounts a Docker volume to persist downloaded models.
    *   **`-p 11434:11434`**: Binds Ollama to the LXC container's port `11434`.
    *   **`--restart always`**: Ensures Ollama restarts automatically if it crashes or if the LXC container reboots.

### Phase 3: Verification
1.  Verify the container is running:
    ```bash
    docker ps
    ```
2.  Test the API endpoint from another machine on the local subnet (`10.7.82.0/24`):
    ```bash
    curl http://10.7.82.100:11434/api/tags
    ```
    It should return a `200 OK` JSON response indicating no models are downloaded yet: `{"models":[]}`.

---

## 3. Pulling Models
To download a model (e.g. `llama3` or `qwen2.5:7b`), run:
```bash
docker exec -it ollama ollama run llama3
```
This downloads and runs the model inside the isolated Docker container.
