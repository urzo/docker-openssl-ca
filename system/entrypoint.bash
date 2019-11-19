#!/bin/bash

set -eou pipefail
IFS=$'\r\n'

source /root/.bashrc

main() {
  local ROOT_DIR="/root/ca/intermediate"
  openssl ocsp -ignore_err \
    -port 2560 -text -rmd sha256 \
    -index "$ROOT_DIR/index.txt" \
    -CA "$ROOT_DIR/certs/ca-chain.cert.pem" \
    -rkey "$ROOT_DIR/private/ocsp.key.pem" \
    -rsigner "$ROOT_DIR/certs/ocsp.cert.pem"
}
main
