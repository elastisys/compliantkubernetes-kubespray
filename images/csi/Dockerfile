ARG SOURCE
FROM quay.io/jetstack/trust-pkg-debian-trixie:20250419-deb13u1.0@sha256:0591b21e1dd3e649660f80d89d44bbfa6a16e8b305612339f7d093857d852cf8 as blessed
FROM ghcr.io/elastisys/curl-jq:1.1.1@sha256:a89f688ae5834ade200f8c78f193c8f7f477d879b753a87cfc482657ff06fb3c as curljq
COPY --from=blessed /debian-package/cert-manager-package-debian.json /tmp/cert-manager-package-debian.json
RUN jq -er '.bundle' /tmp/cert-manager-package-debian.json > /tmp/ca-certificates.crt
FROM "${SOURCE}"
COPY --from=curljq /tmp/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
