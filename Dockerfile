# syntax=docker/dockerfile:1.4

# ---------- Builder stage ----------
FROM rust:1.75-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy only the manifests first so the dependency-compile layer is cached
# independently of unrelated monorepo changes (frontend/, docs/, etc.).
COPY services/api/Cargo.toml ./services/api/Cargo.toml
COPY services/api/Cargo.lock* ./services/api/Cargo.lock

# Warm the dependency cache with a dummy build. This layer is only invalidated
# when the manifests change, not when unrelated repo files change.
RUN mkdir -p services/api/src \
    && echo 'fn main() {}' > services/api/src/main.rs \
    && cargo build --release --manifest-path services/api/Cargo.toml \
    && rm -rf services/api/src

# Now copy the actual source and build the real binary.
COPY services/api ./services/api

RUN cargo build --release --manifest-path services/api/Cargo.toml

# ---------- Runtime stage ----------
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/services/api/target/release/api /usr/local/bin/api

EXPOSE 8080

CMD ["api"]
