## PKI + Authentication Map (KTHW / AWS)

This repo bootstraps a small Kubernetes cluster using a **private CA** and a mix of:
- **mTLS (x509 client certs)** for humans + cluster components
- **TLS server cert** for the API server
- **ServiceAccount JWT signing keys** for Pods

If you remember only one rule:
> **Certificates claim identity. Private keys prove identity (by signing TLS handshake data). CA cert verifies certs. CA private key only signs certs during setup.**

---

### 1) What’s in `*.pem` vs `*-key.pem`?

- `*.pem` (certificate) = **public identity document**
  - includes: Subject (CN/O), public key, CA signature
- `*-key.pem` (private key) = **secret proof**
  - used to sign **TLS handshake data** (never re-signs the certificate)

CA is special:
- `ca-key.pem` = **CA private key** (signing key; keep secret)
- `ca.pem` = **CA certificate** (public key; used everywhere to verify)

---

### 2) Inventory (your exact files)

#### A) Trust root (CA)
| File | Type | Used for |
|---|---|---|
| `ca-key.pem` | CA private key (SECRET) | **Signs** all certs during setup |
| `ca.pem` | CA cert (public) | **Verifies** cert signatures at runtime |

#### B) API server TLS identity (server authentication)
| File | Type | Used by | Purpose |
|---|---|---|---|
| `kubernetes.pem` | server cert | `kube-apiserver` | proves “I am the API server” |
| `kubernetes-key.pem` | server private key (SECRET) | `kube-apiserver` | proves ownership of `kubernetes.pem` during TLS |

> Clients (kubectl/kubelet/etc.) verify `kubernetes.pem` using `ca.pem`.

#### C) Human/admin identity (kubectl client authentication)
| File | Type | Used by | Purpose |
|---|---|---|---|
| `admin.pem` | client cert | `kubectl` | claims identity (CN/O => username/groups) |
| `admin-key.pem` | client private key (SECRET) | `kubectl` | signs TLS handshake data to prove it owns `admin.pem` |

#### D) Control-plane component identities (client certs to API server)
| File(s) | Used by | Why it exists |
|---|---|---|
| `kube-controller-manager.pem` + `kube-controller-manager-key.pem` | controller-manager | API server can authenticate **controller-manager** requests |
| `kube-scheduler.pem` + `kube-scheduler-key.pem` | scheduler | API server can authenticate **scheduler** requests |

#### E) Worker node identities (kubelet client certs)
| File(s) | Used by | Why it exists |
|---|---|---|
| `node-0.pem` + `node-0-key.pem` | kubelet on node-0 | kubelet authenticates as `system:node:node-0` |
| `node-1.pem` + `node-1-key.pem` | kubelet on node-1 | kubelet authenticates as `system:node:node-1` |

#### F) kube-proxy identity (client cert to API server)
| File(s) | Used by | Why it exists |
|---|---|---|
| `kube-proxy.pem` + `kube-proxy-key.pem` | kube-proxy on workers | API server can authenticate kube-proxy watching Services/Endpoints |

#### G) ServiceAccount token signing (Pods authenticate with JWTs, not x509)
| File | Type | Used by | Purpose |
|---|---|---|---|
| `service-account-key.pem` | JWT signing private key (SECRET) | controller-manager | **signs** ServiceAccount tokens |
| `service-account.pem` | JWT verify public key/cert | API server | **verifies** ServiceAccount tokens |

---

### 3) Trust graph (who signs what, who verifies what)

```mermaid
flowchart LR
  CAKEY["ca-key.pem<br/>(CA private key)"]
  CACERT["ca.pem<br/>(CA cert/public key)"]

  CAKEY -->|signs| ADMINCERT[admin.pem]
  CAKEY -->|signs| APICERT[kubernetes.pem]
  CAKEY -->|signs| N0[node-0.pem]
  CAKEY -->|signs| N1[node-1.pem]
  CAKEY -->|signs| CM[kube-controller-manager.pem]
  CAKEY -->|signs| SCH[kube-scheduler.pem]
  CAKEY -->|signs| KP[kube-proxy.pem]

  subgraph Clients
    KUBECTL[kubectl]
    KUBELET0[kubelet node-0]
    KUBELET1[kubelet node-1]
    CONTROLLER[kube-controller-manager]
    SCHED[kube-scheduler]
    PROXY[kube-proxy]
  end

  APISERVER[kube-apiserver]

  APISERVER -->|presents kubernetes.pem| Clients
  Clients -->|verify server cert using ca.pem| CACERT

  KUBECTL -->|presents admin.pem| APISERVER
  KUBECTL -->|"proves via admin-key.pem<br/>(signs TLS handshake data)"| APISERVER

  KUBELET0 -->|presents node-0.pem + proof via node-0-key.pem| APISERVER
  KUBELET1 -->|presents node-1.pem + proof via node-1-key.pem| APISERVER

  CONTROLLER -->|presents CM cert + proof| APISERVER
  SCHED -->|presents scheduler cert + proof| APISERVER
  PROXY -->|presents proxy cert + proof| APISERVER

  SAKEY["service-account-key.pem<br/>(sign JWT)"]
  SAPUB["service-account.pem<br/>(verify JWT)"]
  POD[Pod]

  CONTROLLER -->|sign SA JWTs| SAKEY
  POD -->|Authorization: Bearer <JWT>| APISERVER
  APISERVER -->|verify JWT signature| SAPUB
  ```
  ### Runtime mental model: a real kubectl request
  Example: kubectl get nodes

1. TCP connect to API server :6443

2. API server proves itself

    1. sends kubernetes.pem

    2. kubectl verifies signature using ca.pem

    3. kubectl checks SAN matches hostname/IP used

3. kubectl proves itself (mTLS client auth)

    1. sends admin.pem (identity claim)

    2.  signs TLS handshake data with admin-key.pem (proof)

    3.  API server verifies:

        1.  admin cert was signed by CA (using ca.pem)

        2.  handshake proof matches public key in admin.pem

4.  Kubernetes AuthN/AuthZ

    1.  AuthN: CN/O => username/groups

    2.  AuthZ: RBAC decides permissions

5.  API server serves response

### Runtime mental model: a Pod calling the API (ServiceAccount)
Pods typically do not use x509 client certs. They use a JWT Bearer token:
1. controller-manager signs ServiceAccount JWTs with service-account-key.pem

2. Pod sends: Authorization: Bearer <JWT>

3. API server verifies JWT signature using service-account.pem

4. RBAC applies to the ServiceAccount identity


 Note: Kubernetes Pods authenticate using Bearer tokens whose payloads are JWTs signed by the controller-manager and verified by the API server.
