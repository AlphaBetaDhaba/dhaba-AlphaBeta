FROM golang:1.22-alpine as builder
wORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o orders-api .

FROM alpine:3.20
WORKDIR /app
RUN apk add --no-cache ca-certificates\
    && addgroup -S appuser \
    && adduser -S appuser -G appuser
COPY --from=builder --chown=appuser:appgroup /app/orders-api .
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3s \
    CMD wget -q0- http://127.0.0.1:8002/health || exit 1
CMD ["./orders-api"]
