# syntax=docker/dockerfile:1

# ---- build ----
FROM golang:1.26-alpine AS build

WORKDIR /src

# go.sum doesn't exist yet (no third-party deps); the glob keeps this
# layer cacheable now and still correct once deps are added.
COPY go.mod go.sum* ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

# Fully static binary -> final image needs no libc.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags="-s -w" -o /out/api ./cmd

# ---- runtime ----
FROM alpine:3.21

# ca-certificates for outbound TLS, tzdata so time.LoadLocation works.
RUN apk add --no-cache ca-certificates tzdata \
    && adduser -D -u 10001 app

COPY --from=build /out/api /usr/local/bin/api

USER app
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/api"]
