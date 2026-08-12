# Multi-stage Dockerfile for proxmox-dns-sync
# Stage 1: Build binary using official Go alpine image
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy module files and download dependencies
COPY go.mod ./
RUN go mod download || true

# Copy source tree
COPY . .

# Build statically linked binary without CGO
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/proxmox-dns-sync ./cmd/sync

# Stage 2: Minimal runtime image
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app
COPY --from=builder /app/proxmox-dns-sync /app/proxmox-dns-sync

USER 65534:65534

ENTRYPOINT ["/app/proxmox-dns-sync"]
