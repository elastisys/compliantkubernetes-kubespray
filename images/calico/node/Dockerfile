FROM alpine:latest AS certs
RUN apk add --no-cache ca-certificates

FROM quay.io/calico/node:v3.31.5

COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

