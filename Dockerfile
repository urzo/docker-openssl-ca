FROM alpine:3.10.3
LABEL maintainer="urzo [urzo.mx@gmail.com]"

ARG C="US"
ARG ST="CA"
ARG L="San Francisco"
ARG O="urzo"
ARG OCSP_FQDN="ocsp.urzo.dev"

ENV ROOT_DIR=/root/ca
ENV INT_DIR=$ROOT_DIR/intermediate

RUN apk update && apk upgrade && \
    apk --update add --no-cache openssl bash curl perl openrc && \
    rm -rf /var/cache/apk/* && \
    rm -rf /var/tmp/* && \
    rm -rf /usr/share/man && \
    rm -rf /usr/share/doc && \
    rm -rf /usr/share/doc-base

RUN mkdir -p $ROOT_DIR && \
    mkdir -p $ROOT_DIR/certs $ROOT_DIR/crl $ROOT_DIR/newcerts $ROOT_DIR/private $ROOT_DIR/intermediate $ROOT_DIR/scripts && \
    mkdir -p $INT_DIR/certs $INT_DIR/crl $INT_DIR/csr $INT_DIR/newcerts $INT_DIR/private && \
    mkdir -p $ROOT_DIR/commands

ENV PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin:/root/ca/commands
RUN echo "export PATH=$PATH" >> /root/.bashrc

RUN openssl rand -hex -writerand $ROOT_DIR/private/.rand &>/dev/null && \
    chmod 700 $ROOT_DIR/private $INT_DIR/private && \
    touch $ROOT_DIR/index.txt $INT_DIR/index.txt && \
    echo "1000" | tee -a $ROOT_DIR/serial $INT_DIR/serial $INT_DIR/crlnumber &>/dev/null

WORKDIR $ROOT_DIR

COPY configs/root.cnf $ROOT_DIR/openssl.cnf
COPY configs/intermediate.cnf $INT_DIR/openssl.cnf

RUN echo "creating CA key" && \
    openssl genrsa -out private/ca.key.pem 4096 && \
    chmod 400 private/ca.key.pem && \
    echo "creating CA cert" && \
    openssl req -config openssl.cnf \
        -key private/ca.key.pem \
        -new -x509 -days 7300 -sha256 -extensions v3_ca \
        -out certs/ca.cert.pem \
        -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${O} Certificate Authority lda/CN=${O} CA" && \
    chmod 444 certs/ca.cert.pem && \
    echo "creating intermediate key" && \
    openssl genrsa -out intermediate/private/intermediate.key.pem 4096 && \
    chmod 400 intermediate/private/intermediate.key.pem && \
    echo "creating intermediate csr" && \
    openssl req -config intermediate/openssl.cnf \
        -new -sha256 \
        -key intermediate/private/intermediate.key.pem \
        -out intermediate/csr/intermediate.csr.pem \
        -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${O} Certificate Authority lda/CN=${O} Intermediate CA" && \
    echo "creating intermediate cert" && \
    openssl ca -config openssl.cnf -extensions v3_intermediate_ca \
        -days 3650 -notext -md sha256 -batch \
        -in intermediate/csr/intermediate.csr.pem \
        -out intermediate/certs/intermediate.cert.pem && \
    chmod 444 intermediate/certs/intermediate.cert.pem && \
    echo "creating certificate chain" && \
    cat intermediate/certs/intermediate.cert.pem certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem && \
    chmod 444 intermediate/certs/ca-chain.cert.pem && \
    echo "creating intermediate crl" && \
    openssl ca -config intermediate/openssl.cnf -gencrl -out intermediate/crl/intermediate.crl.pem  && \
    echo "creating ocsp key" && \
    openssl genrsa -out intermediate/private/ocsp.key.pem 4096 && \
    chmod 400 intermediate/private/ocsp.key.pem && \
    echo "creating ocsp csr" && \
    openssl req -config intermediate/openssl.cnf -new -sha256 \
        -key intermediate/private/ocsp.key.pem \
        -out intermediate/csr/ocsp.csr.pem \
        -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${O} Certificate Authority lda/CN=${OCSP_FQDN}" && \
    echo "creating ocsp cert" && \
    openssl ca -config intermediate/openssl.cnf -extensions ocsp \
        -days 365 -notext -md sha256 -batch \
        -in intermediate/csr/ocsp.csr.pem \
        -out intermediate/certs/ocsp.cert.pem && \
    chmod 444 intermediate/certs/ocsp.cert.pem

# entrypoint.bash is the openRC script
COPY system/entrypoint.bash /etc/init.d/openssl_ca
# ocsp.bash is the openRC service definition script
COPY system/service /usr/sbin/openssl_ca
COPY commands/* commands/

RUN chmod a+x commands/* /etc/init.d/openssl_ca /usr/sbin/openssl_ca && /sbin/rc-update add openssl_ca

VOLUME $ROOT_DIR

EXPOSE 2560
ENTRYPOINT ["/sbin/rc-service", "openssl_ca", "start"]
