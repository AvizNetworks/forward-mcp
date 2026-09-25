# Build stage
FROM golang:1.26-alpine3.24 AS builder

WORKDIR /app

RUN apk add --no-cache gcc musl-dev

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application (CGO required for go-sqlite3)
RUN CGO_ENABLED=1 GOOS=linux go build -o /app/forward-mcp cmd/server/main.go

# Final stage - latest Alpine 3.x
FROM alpine:3.24

# Upgrade all packages to pick up security patches, keep CA certs (HTTPS to
# Forward Networks), then drop the package manager: apk-tools is what pulls in
# zlib (CVE-2026-85091, no fixed Alpine package yet) and libcrypto3/libssl3,
# none of which the binary (musl-only, Go TLS) uses.
RUN apk upgrade --no-cache && \
    apk add --no-cache ca-certificates-bundle && \
    apk del --no-cache apk-tools

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/forward-mcp .

# Expose port
EXPOSE 8080

# Run the application
CMD ["./forward-mcp"] 