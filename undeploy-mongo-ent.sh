#!/bin/bash

set -e

RELEASE_NAME="mongo-ent"
NAMESPACE="mongodb-ent"
KEYFILE_SECRET_NAME="mongodb-keyfile"

echo "❌ Deleting Helm release: $RELEASE_NAME in namespace $NAMESPACE"
if helm status "$RELEASE_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
  helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
else
  echo "⚠️ Helm release not found: $RELEASE_NAME"
fi

echo "🧽 Deleting keyfile secret..."
oc delete secret "$KEYFILE_SECRET_NAME" -n "$NAMESPACE" --ignore-not-found

echo "🧼 Deleting PVCs..."
PVC_LIST=$(oc get pvc -n "$NAMESPACE" -o name)
if [[ -n "$PVC_LIST" ]]; then
  oc delete $PVC_LIST -n "$NAMESPACE"
else
  echo "ℹ️ No PVCs found."
fi

echo "🧼 Deleting namespace: $NAMESPACE"
oc delete namespace "$NAMESPACE" --ignore-not-found

