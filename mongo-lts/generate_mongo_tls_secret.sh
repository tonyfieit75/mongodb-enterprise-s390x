#!/bin/bash

set -e

# CONFIG
NAMESPACE="mongodb-ent"
SECRET_NAME="mongo-tls"
CERT_DIR="./mongo-lts"
COMMON_NAME="mongo-ent-0"
DNS_NAMES=(mongo-ent-0 mongo-ent-1 mongo-ent-2)
IP_ADDRS=(10.128.3.78 10.131.0.12 10.128.3.79)
# CLEANUP
rm -rf $CERT_DIR
mkdir -p $CERT_DIR

echo "🔐 Generating CA..."
openssl genrsa -out $CERT_DIR/ca.key 4096
openssl req -x509 -new -nodes -key $CERT_DIR/ca.key -sha256 -days 365 \
  -out $CERT_DIR/ca.crt -subj "/C=US/ST=State/L=City/O=Org/OU=IT/CN=MongoCA"

echo "🔐 Generating server key and CSR with SANs..."

cat > $CERT_DIR/server-openssl.cnf <<EOF
[ req ]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = req_ext

[ dn ]
CN = $COMMON_NAME

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
EOF

i=1
for dns in "${DNS_NAMES[@]}"; do echo "DNS.$i = $dns" >> $CERT_DIR/server-openssl.cnf; ((i++)); done
j=1
for ip in "${IP_ADDRS[@]}"; do echo "IP.$j = $ip" >> $CERT_DIR/server-openssl.cnf; ((j++)); done

openssl genrsa -out $CERT_DIR/server.key 4096
openssl req -new -key $CERT_DIR/server.key -out $CERT_DIR/server.csr \
  -config $CERT_DIR/server-openssl.cnf

openssl x509 -req -in $CERT_DIR/server.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key \
  -CAcreateserial -out $CERT_DIR/server.crt -days 365 \
  -extensions req_ext -extfile $CERT_DIR/server-openssl.cnf

cat $CERT_DIR/server.key $CERT_DIR/server.crt > $CERT_DIR/server_mongo.pem

echo "🔐 Generating client cert for mTLS..."
openssl genrsa -out $CERT_DIR/client.key 4096
openssl req -new -key $CERT_DIR/client.key -out $CERT_DIR/client.csr \
  -subj "/C=US/ST=State/L=City/O=Org/OU=Clients/CN=mongoclient"
openssl x509 -req -in $CERT_DIR/client.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key \
  -CAcreateserial -out $CERT_DIR/client.crt -days 365
cat $CERT_DIR/client.key $CERT_DIR/client.crt > $CERT_DIR/client.pem

echo "📦 Creating Kubernetes TLS secret: $SECRET_NAME..."
oc delete secret $SECRET_NAME -n $NAMESPACE --ignore-not-found
oc create secret generic $SECRET_NAME \
  --from-file=server_mongo.pem=$CERT_DIR/server_mongo.pem \
  --from-file=ca.crt=$CERT_DIR/ca.crt \
  --from-file=client.pem=$CERT_DIR/client.pem \
  -n $NAMESPACE

echo -e "\n✅ Secret created: $SECRET_NAME in namespace: $NAMESPACE"
echo -e "\n📁 TLS certs written to: $CERT_DIR"
echo -e "\n👉 Now update your Deployment or StatefulSet with:\n"
cat <<EOF
volumes:
  - name: tls-volume
    secret:
      secretName: mongo-tls

volumeMounts:
  - name: tls-volume
    mountPath: /var/lib/mongo/certs
    readOnly: true
EOF

echo -e "\n📝 Be sure your mongod.conf contains:\n"
cat <<EOF
net:
  port: 27017
  tls:
    mode: requireTLS
    certificateKeyFile: /var/lib/mongo/certs/server_mongo.pem
    CAFile: /var/lib/mongo/certs/ca.crt
    allowConnectionsWithoutCertificates: false
EOF

echo -e "\n🔑 Test connection with:\n"
echo "mongosh --tls --tlsCAFile=$CERT_DIR/ca.crt --tlsCertificateKeyFile=$CERT_DIR/client.pem --host mongo-ent-0:27017"

