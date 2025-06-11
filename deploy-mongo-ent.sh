#!/bin/bash

set -e

NAMESPACE="mongodb-ent"
RELEASE_NAME="mongo-ent"
CHART_PATH="./mongo-ent-0.1.0"  # Can be a .tgz chart or folder
KEYFILE_B64=$(openssl rand -base64 756 | tr -d '\n')
ADMIN_USER="admin"
ADMIN_PASS="Snowball2025!"  # Change as needed

echo "🚀 Creating namespace: $NAMESPACE"
oc create namespace "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -

echo "🔑 Generating base64 keyfile and deploying Helm chart..."
helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
  --namespace "$NAMESPACE" \
  --set auth.keyfile="$KEYFILE_B64"

echo "⏳ Waiting for pods to start creating..."
sleep 10

echo "📦 Waiting for all 3 pods in the StatefulSet to be Ready..."
for i in {1..60}; do
  READY_COUNT=$(oc get pods -n "$NAMESPACE" -l app=$RELEASE_NAME -o jsonpath="{.items[*].status.containerStatuses[0].ready}" | grep -o "true" | wc -l)
  if [[ "$READY_COUNT" -ge 3 ]]; then
    echo "✅ All 3 MongoDB pods are running and ready."
    break
  fi
  echo "⌛ $READY_COUNT/3 pods are ready. Retrying in 10s..."
  sleep 10
  if [[ "$i" -eq 60 ]]; then
    echo "❌ Timeout waiting for pods to be ready."
    exit 1
  fi
done

echo "🧠 Initializing the replica set..."
POD="$RELEASE_NAME-0"
oc exec -n "$NAMESPACE" "$POD" -c mongod -- env HOME=/tmp mongosh --quiet --norc --eval "
try {
  rs.initiate({
    _id: 'rs0',
    members: [
      { _id: 0, host: '$RELEASE_NAME-0.$RELEASE_NAME.$NAMESPACE.svc.cluster.local:27017' },
      { _id: 1, host: '$RELEASE_NAME-1.$RELEASE_NAME.$NAMESPACE.svc.cluster.local:27017' },
      { _id: 2, host: '$RELEASE_NAME-2.$RELEASE_NAME.$NAMESPACE.svc.cluster.local:27017' }
    ]
  });
} catch (e) { print('Warning: ' + e); }
" || true

echo "🕓 Waiting for PRIMARY to be elected..."
PRIMARY_POD=""
for i in {1..60}; do
  PRIMARY_POD=$(oc exec -n "$NAMESPACE" "$POD" -c mongod -- env HOME=/tmp mongosh --quiet --norc --eval \
    'var status = rs.status(); for (var i=0; i < status.members.length; i++) { if (status.members[i].stateStr === "PRIMARY") { print(status.members[i].name.split(".")[0]); break; } }' 2>/dev/null)
  if [[ -n "$PRIMARY_POD" ]]; then
    echo "✅ PRIMARY elected: $PRIMARY_POD"
    break
  fi
  echo "⌛ No PRIMARY yet. Retrying in 5s..."
  sleep 5
done


if [[ -z "$PRIMARY_POD" ]]; then
  echo "❌ Failed to detect PRIMARY pod for user creation."
  echo "ℹ️ Dumping rs.status() for diagnostics:"
  oc exec -n "$NAMESPACE" "$POD" -c mongod -- env HOME=/tmp mongosh --quiet --norc --eval 'rs.status()'
  exit 1
fi

echo "👤 Creating admin user..."
oc exec -n "$NAMESPACE" "$PRIMARY_POD" -c mongod -- env HOME=/tmp mongosh --quiet --norc --eval "
db.getSiblingDB('admin').createUser({
  user: '$ADMIN_USER',
  pwd: '$ADMIN_PASS',
  roles: [ { role: 'root', db: 'admin' } ]
})
"

echo "✅ MongoDB Enterprise Replica Set deployed, initialized, and secured with admin user!"
echo "➡️ Connect using: mongosh -u $ADMIN_USER -p $ADMIN_PASS --authenticationDatabase admin"

