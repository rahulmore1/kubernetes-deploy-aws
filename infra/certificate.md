### Certificats on the Nodes and the cluster
We use cfssl for creating certificats 
You have to first crete config for the ca.

How the CA signs
```
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
```
Who the CA is 

```
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

```
Generate CA + Cert
```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

```
Admin Client Certificate
- admin identity for kubectl
- In Kubernetes RBAC, any cert with O: system:masters is treated as cluster-admin by default.

```
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

```
Certificates for Nodes [0,1]
Each kubelet must authenticate to the API server using a cert whose:
```
CN = system:node:<nodeName>

O = system:nodes
```
This is how the Node Authorizer recognizes nodes.

Capture internal IPS of each node. 
```
# internal IP of node-0
NODE0_INTERNAL_IP=$(ssh -i ~/.ssh/id_ed25519_kthw root@node-0 "hostname -I | awk '{print \$1}'")

# internal IP of node-1
NODE1_INTERNAL_IP=$(ssh -i ~/.ssh/id_ed25519_kthw root@node-1 "hostname -I | awk '{print \$1}'")
```
Set External IPS
```
NODE0_EXTERNAL_IP=54.71.141.98 // what ever they are 
NODE1_EXTERNAL_IP=35.87.243.113
```
node-0 CSR + cert
```
cat > node-0-csr.json <<EOF
{
  "CN": "system:node:node-0",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=node-0,${NODE0_INTERNAL_IP},${NODE0_EXTERNAL_IP} \
  -profile=kubernetes \
  node-0-csr.json | cfssljson -bare node-0

```
node-1 CSR + cert

```
cat > node-1-csr.json <<EOF
{
  "CN": "system:node:node-1",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=node-1,${NODE1_INTERNAL_IP},${NODE1_EXTERNAL_IP} \
  -profile=kubernetes \
  node-1-csr.json | cfssljson -bare node-1

```
kube-controller-manager client cert

The controller-manager talks to the API server as a specific user: system:kube-controller-manager. RBAC rules can apply to that user.

```
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
```
kube-proxy client cert
The kube-proxy process also talks to the API server and needs its own identity (system:kube-proxy).
```
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

```
kube-scheduler client cert
The scheduler has its own identity system:kube-scheduler.
```
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
```
```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
```
Server Certificates
API server certificate. 
Every component talks to the server
It should be valid for, 
    1. Service IP 
    2. Servers Private IP / Public IP
    3. Localhost 
    4. All internal DNS names. 
On Mac
 ```
 KUBERNETES_PUBLIC_ADDRESS=54.245.180.115

SERVER_INTERNAL_IP=$(ssh -i ~/.ssh/id_ed25519_kthw root@server "hostname -I | awk '{print \$1}'")

KUBERNETES_HOSTNAMES="kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local"

```
CSR+Cert

```
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,${SERVER_INTERNAL_IP},127.0.0.1,${KUBERNETES_PUBLIC_ADDRESS},${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

```
Kubernetes gets the first ip available , in our case the subnet is 10.32.0.0/24,  so the first house - ip is 10.32.0.1

Service Account Key Pair. 
Controll Manager uses this key air to sign service accounts. This is the used by the PODS to tlak to the API server. 

```
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

```

Distribute Certificates to Servers. 







