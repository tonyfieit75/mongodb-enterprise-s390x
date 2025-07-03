#!/bin/bash

# CONFIG
NAMESPACE="mongodb-ent"
STATEFULSET="mongo-ent"
SECRET_NAME="mongo-tls"
VOLUME_NAME="tls-volume"
MOUNT_PATH="/var/lib/mongo/certs"

echo "📦 Patching StatefulSet: $STATEFULSET in namespace: $NAMESPACE"

# Patch volumeMounts
oc patch statefulset "$STATEFULSET" -n "$NAMESPACE" --type='json' -p="[
  {
    \"op\": \"add\",
    \"path\": \"/spec/template/spec/containers/0/volumeMounts/-\",
    \"value\": {
      \"name\": \"$VOLUME_NAME\",
      \"mountPath\": \"$MOUNT_PATH\",
      \"readOnly\": true
    }
  }
]"

# Patch volumes
oc patch statefulset "$STATEFULSET" -n "$NAMESPACE" --type='json' -p="[
  {
    \"op\": \"add\",
    \"path\": \"/spec/template/spec/volumes/-\",
    \"value\": {
      \"name\": \"$VOLUME_NAME\",
      \"secret\": {
        \"secretName\": \"$SECRET_NAME\"
      }
    }
  }
]"

echo "✅ StatefulSet patched successfully."
echo "🔁 Restarting pods to apply changes..."
oc rollout restart statefulset "$STATEFULSET" -n "$NAMESPACE"

echo "⏳ Waiting for pods to restart..."
oc rollout status statefulset "$STATEFULSET" -n "$NAMESPACE"

