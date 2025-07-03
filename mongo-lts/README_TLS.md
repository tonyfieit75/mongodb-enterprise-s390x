
# MongoDB 8.0.10 TLS + mTLS Setup on OpenShift

This guide describes how to **enable TLS and mutual TLS (mTLS)** for a **MongoDB 8.0.10 replica set** deployed as a **StatefulSet on OpenShift** using three helper scripts:

- `generate_mongo_tls_secret.sh`
- `patch_mongo_statefulset_tls.sh`
- `enable_mongo_tls_patch_configmap.sh`

---

## ✅ Quick Summary

### What was done:
1.  Generated a custom **Certificate Authority (CA)** and signed:
   - A **server certificate** with SANs for all replica set members.
   - A **client certificate** for mTLS testing.
      Created a **Kubernetes TLS secret** with those certs.
      Patched the **StatefulSet** to mount the secret at `/var/lib/mongo/certs`.
      Patched the **mongod.conf** (via ConfigMap) to enable TLS and mTLS.
      Restarted MongoDB pods to apply changes.
      Validated secure connection using `mongosh`.

---

## 📁 Script Overview

### 1. `generate_mongo_tls_secret.sh`

Generates TLS certificates and creates a Kubernetes TLS secret.

- CA: `ca.crt`
- Server: `server_mongo.pem` (with SANs)
- Client: `client.pem`
- Secret: `mongo-tls` in namespace `mongodb-ent`

> 📂 Outputs certs to the `./mongo-lts` directory.

### 2. `patch_mongo_statefulset_tls.sh`

Patches your MongoDB **StatefulSet** (`mongo-ent`) to mount the TLS secret:

```yaml
volumes:
  - name: tls-volume
    secret:
      secretName: mongo-tls

volumeMounts:
  - name: tls-volume
    mountPath: /var/lib/mongo/certs
    readOnly: true
```

Also restarts the pods.

### 3. `enable_mongo_tls_patch_configmap.sh`

Fetches and backs up `mongod.conf` from ConfigMap `mongo-ent-conf`, adds TLS config:

```yaml
net:
  tls:
    mode: requireTLS
    certificateKeyFile: /var/lib/mongo/certs/server_mongo.pem
    CAFile: /var/lib/mongo/certs/ca.crt
    allowConnectionsWithoutCertificates: false
```

Applies it directly and triggers a pod restart.

---

##  Deployment Steps

### Prerequisites:
- OpenShift cluster
- Logged in as a user with access to `mongodb-ent` namespace
- `oc`, `openssl`, `jq`, and `mongosh` (optional for testing) installed

### 1. Clone your script directory and make scripts executable:
```bash
chmod +x generate_mongo_tls_secret.sh
chmod +x patch_mongo_statefulset_tls.sh
chmod +x enable_mongo_tls_patch_configmap.sh
```

### 2. Generate TLS certs and secret
```bash
./generate_mongo_tls_secret.sh
```

### 3. Patch the MongoDB StatefulSet
```bash
./patch_mongo_statefulset_tls.sh
```

### 4. Update the ConfigMap to enable TLS in `mongod.conf`
```bash
./enable_mongo_tls_patch_configmap.sh
```

---

##  Verify

### Connect using `mongosh`:
```bash
mongosh "mongodb://mongo-ent-0:27017" \
  --tls \
  --tlsCAFile=./mongo-lts/ca.crt \
  --tlsCertificateKeyFile=./mongo-lts/client.pem
```

---

## 📎 Notes

- You must include **SANs and replica IPs/hostnames** in the server cert for TLS to work.
- Mount path for certs must match what’s in `mongod.conf`.
- Default MongoDB path to TLS certs is `/var/lib/mongo/certs`.
- Make sure the MongoDB container has permission to read the mounted secrets.

---

## 📁 Files Generated

```text
mongo-lts/
├── ca.crt
├── ca.key
├── client.pem
├── server.key
├── server_mongo.pem
└── client.csr
```

---

##  To Clean Up

To delete the secret and roll back ConfigMap:

```bash
oc delete secret mongo-tls -n mongodb-ent
oc edit configmap mongo-ent-conf -n mongodb-ent  # Manually revert TLS block
```

---

## 🛠 Authors
Created by [Antoine Fievre] for secure MongoDB 8.0.10 deployment on OpenShift s390x.

