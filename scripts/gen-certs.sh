#!/bin/bash
set -e

CERTS_DIR="./certs"
mkdir -p $CERTS_DIR

# Generate CA
openssl genrsa -out $CERTS_DIR/ca-key.pem 4096
openssl req -new -x509 -days 365 -key $CERTS_DIR/ca-key.pem -out $CERTS_DIR/ca-cert.pem \
    -subj "/C=US/ST=State/L=City/O=MyOrg/CN=MyCA"

# Function to generate service certificates
generate_cert() {
    local service=$1
    local san=$2
    
    # Generate private key
    openssl genrsa -out $CERTS_DIR/${service}-key.pem 4096
    
    # Generate CSR
    openssl req -new -key $CERTS_DIR/${service}-key.pem -out $CERTS_DIR/${service}.csr \
        -subj "/C=US/ST=State/L=City/O=MyOrg/CN=${service}"
    
    # Create extensions file with SAN
    cat > $CERTS_DIR/${service}-ext.cnf <<EOF
subjectAltName = ${san}
extendedKeyUsage = serverAuth,clientAuth
EOF
    
    # Sign certificate
    openssl x509 -req -days 365 -in $CERTS_DIR/${service}.csr \
        -CA $CERTS_DIR/ca-cert.pem -CAkey $CERTS_DIR/ca-key.pem -CAcreateserial \
        -out $CERTS_DIR/${service}-cert.pem -extfile $CERTS_DIR/${service}-ext.cnf
    
    # Cleanup
    rm $CERTS_DIR/${service}.csr $CERTS_DIR/${service}-ext.cnf
}

# Generate certificates for each service
generate_cert "trino" "DNS:trino,DNS:localhost,IP:127.0.0.1"
generate_cert "clickhouse" "DNS:clickhouse,DNS:localhost,IP:127.0.0.1"
generate_cert "postgres" "DNS:postgres,DNS:localhost,IP:127.0.0.1"
generate_cert "minio" "DNS:minio,DNS:localhost,IP:127.0.0.1"

# Generate client certificate for Trino to connect to other services
generate_cert "trino-client" "DNS:trino,DNS:localhost"


# === Build Trino keystore & truststore ===
KEYSTORE_PASS="changeit"

# Keystore (contains Trino's cert + key + CA)
openssl pkcs12 -export \
  -in "$CERTS_DIR/trino-cert.pem" \
  -inkey "$CERTS_DIR/trino-key.pem" \
  -certfile "$CERTS_DIR/ca-cert.pem" \
  -name "trino" \
  -out "$CERTS_DIR/trino-keystore.p12" \
  -password pass:$KEYSTORE_PASS

# Truststore (contains only CA)
(
  cd "$CERTS_DIR"
  keytool -importcert -noprompt \
    -alias myca \
    -file ca-cert.pem \
    -keystore trino-truststore.p12 \
    -storetype PKCS12 \
    -storepass $KEYSTORE_PASS
)

chmod 644 "$CERTS_DIR"/*.pem "$CERTS_DIR"/*.p12
chmod 600 "$CERTS_DIR"/*-key.pem

echo "Certificates and PKCS12 stores generated in $CERTS_DIR/"