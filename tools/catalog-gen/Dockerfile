# syntax=docker/dockerfile:1
FROM rust:1.95-alpine AS builder
RUN apk add --no-cache musl-dev
WORKDIR /build

# Cache dependencies separately from source
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs \
  && cargo build --release \
  && rm -f target/release/catalog-gen

COPY src ./src
RUN touch src/main.rs && cargo build --release

FROM alpine:3.21
RUN apk add --no-cache git \
  && git config --system --add safe.directory '*'
COPY --from=builder /build/target/release/catalog-gen /usr/local/bin/catalog-gen
ENTRYPOINT ["catalog-gen"]
