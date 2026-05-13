# syntax=docker/dockerfile:1
FROM rust:1.95-bookworm AS builder
WORKDIR /build

# Cache dependencies separately from source
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs \
  && cargo build --release \
  && rm -f target/release/catalog-gen

COPY src ./src
RUN touch src/main.rs && cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends git \
  && git config --system --add safe.directory '*' \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /build/target/release/catalog-gen /usr/local/bin/catalog-gen
ENTRYPOINT ["catalog-gen"]
