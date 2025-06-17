# 📘 MongoDB Enterprise 8.0.10 Deployment on OpenShift (s390x Architecture)

### 📌 Overview

![image](https://github.com/user-attachments/assets/f29ca681-4b6c-49a9-a4c7-396b8fa9799d)

Automatic Failover
When a primary does not communicate with the other members of the set for more than the configured electionTimeoutMillis period (10 seconds by default), an eligible secondary calls for an election to nominate itself as the new primary. The cluster attempts to complete the election of a new primary and resume normal operations.

![image](https://github.com/user-attachments/assets/6b747275-1e7c-4f46-a82d-7d3457949f03)



This guide outlines the steps required to deploy **MongoDB Enterprise v8.0.10** as a **3-member replica set** on **OpenShift** on **s390x Architecture**, including:

- Custom `StatefulSet`, `Service`, and `Secret`
- Helm chart-based deployment
- Secure keyfile-based authentication
- Automated replica set initiation and admin user creation

---

## 🛠️ Prerequisites

1. OpenShift cluster access (`oc` CLI configured)
2. Helm 3.x installed
3. MongoDB Enterprise 8.0.10 binaries and license
4. Admin privileges on OpenShift to create namespaces and secrets
5. A Linux host or VM to run the deployment script

---

## 📁 Directory Structure

```bash
mongodb-enterprise-s390x/
├── deploy-mongo-ent.sh
├── mongo-ent-0.1.0
│   ├── Chart.yaml
│   ├── mongodb-keyfile
│   ├── readme.txt
│   ├── templates
│   │   ├── configmap.yaml
│   │   ├── _helpers.tpl
│   │   ├── secret.yaml
│   │   ├── service.yaml
│   │   └── statefulset.yaml
│   └── values.yaml
├── README.md
└── undeploy-mongo-ent.sh
```

---

## 🚀 Deployment Steps

### 1. Clone This Repo (after GitHub creation below)

```bash
git clone https://github.com/tonyfieit75/mongodb-enterprise-s390x.git
cd mongodb-enterprise-s390x
```

### 2. Deploy MongoDB Enterprise

Run the script:

```bash
chmod +x deploy-mongo-ent.sh
./deploy-mongo-ent.sh
```

This will:
- Create a namespace `mongodb-ent`
- Generate a base64 keyfile
- Deploy the Helm chart
- Initialize the replica set
- Wait for PRIMARY election
- Create admin user

### 3. Connect to MongoDB

```bash
mongosh -u admin -p Snowball2025! --authenticationDatabase admin
```

---

## 🧹 Cleanup

To delete all resources:

```bash
chmod +x undeploy-mongo-ent.sh
./undeploy-mongo-ent.sh
```

---

## 🧾 Components Explained

### ➤ Key Helm Values

```yaml
auth:
  keyfile: <base64-generated-keyfile>
```

### ➤ StatefulSet Highlights

- 3 replicas (`mongo-ent-0`, `mongo-ent-1`, `mongo-ent-2`)
- Custom volume for persistent data
- Mount `/etc/secrets/keyfile` with `0600` permissions
- Container runAs UID/GID compatible with OpenShift SCCs

### ➤ Script Logic

`deploy-mongo-ent.sh`:
- Waits for all pods to be ready
- Initializes `rs.initiate()`
- Polls for a PRIMARY election
- Creates the `admin` user securely

---

### 2. Push Local Directory

```bash
cd /path/to/mongodb-enterprise-s390x
git init
git remote add origin https://github.com/tonyfieit75/mongodb-enterprise-s390x.git
git add .
git commit -m "Initial commit: MongoDB Enterprise 8.0.10 OpenShift deployment"
git push -u origin master
```


