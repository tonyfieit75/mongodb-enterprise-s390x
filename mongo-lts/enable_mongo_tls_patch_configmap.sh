#!/bin/bash

set -e

NAMESPACE="mongodb-ent"
CONFIGMAP="mongo-ent-conf"
STATEFULSET="mongo-ent"
TLS_CONF_TMP="./mongod.tls.conf"

echo "📥 Backing up current mongod.conf from ConfigMap..."
oc get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.mongod\.conf}' > ./mongod.conf.bak
echo "✅ Backup saved to ./mongod.conf.bak"

echo "📄 Generating patched mongod.conf with TLS..."
cat > "$TLS_CONF_TMP" <<EOF
storage:
  dbPath: /data/db
net:
  bindIp: 0.0.0.0
  port: 27017
  tls:
    mode: requireTLS
    certificateKeyFile: /var/lib/mongo/certs/server_mongo.pem
    CAFile: /var/lib/mongo/certs/ca.crt
    allowConnectionsWithoutCertificates: false
security:
  authorization: enabled
  keyFile: /etc/secrets/keyfile
replication:
  replSetName: rs0
EOF

echo "📦 Overwriting ConfigMap $CONFIGMAP in namespace $NAMESPACE with TLS config..."
oc create configmap "$CONFIGMAP" \
  --from-file=mongod.conf="$TLS_CONF_TMP" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | oc apply -f -

echo "✅ ConfigMap $CONFIGMAP updated in-place."

echo "🔁 Restarting StatefulSet $STATEFULSET..."
oc rollout restart statefulset "$STATEFULSET" -n "$NAMESPACE"

echo "⏳ Waiting for rollout to complete..."
oc rollout status statefulset "$STATEFULSET" -n "$NAMESPACE"

echo "🎉 TLS patch complete. MongoDB config now enforces TLS + mTLS."
echo "📎 Test TLS connection using:"
echo "mongosh \"mongodb://mongo-ent-0.$NAMESPACE.svc:27017\" \\"
echo "  --tls --tlsCAFile=./mongo-lts/ca.crt --tlsCertificateKeyFile=./mongo-lts/client.pem"

