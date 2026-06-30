# Multi-stage build — compiles ai-memory from source (supports amd64 and arm64)
FROM rust:1.80-slim AS builder

RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

RUN cargo install ai-memory --locked 2>/dev/null || \
    cargo install --git https://github.com/alphaonedev/ai-memory-mcp.git

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates libssl3 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/cargo/bin/ai-memory /usr/local/bin/ai-memory

RUN mkdir -p /data
VOLUME /data

ENV AI_MEMORY_DB=/data/ai-memory.db

EXPOSE 9077

CMD ["ai-memory", "serve"]
