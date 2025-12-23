## Bootstrapping the Kubernetes Control Plane
Big Picture
So far we have the following
-   etcd --> the data store
-   TLS Certs + keys --> who is who , identity
-   kueconfigs --> profiles
-   encryption-config --> how to encrypt secrets at rest.

Now the control plane preocess do the following

#### kude-apiserver
-   front door for all the cluster
-   authn and authz
-   talks to etcd

#### kube-contoller-manager
This is the main controller that implements controllers for
    - Deployments --> ReplicaSets --> Pods
    - Node controller , service controller, etc
  - Watches api server , match desired state.

#### kube-scheduler
-   takes unscheduled pods
-   picks nodes , where the pods should land

We will work from the server

On the server , install Kubeernetes controller binaries
- kube-apiserver API endoint , validate request , talks to etcd
- kube-controller-manager controller that maintains state
- kube-scheduler decides where stated pods end up
- kubectl CLI

Here we have used ARM 64 as we selcted that architecture for our EC2 machines

```
# choose a Kubernetes version; this is an example, can be any one version
K8S_VERSION=v1.34.2

cd /usr/local/bin

for bin in kube-apiserver kube-controller-manager kube-scheduler kubectl; do
  curl -L -o ${bin} "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/arm64/${bin}"
  chmod +x ${bin}
done

# quick sanity check
kube-apiserver --version
kube-controller-manager --version
kube-scheduler --version
kubectl version --client

```

#### Certificates and Kubeconfigs
We have to place the certificactes in proper places so that the control plane components can
have a secure communication.
With the kubeconfig , the control plane know how to talk api server- except the api server
The encryption to encrypt the data at rest.

Here the standardized as follows
- /var/lib/kubernetes -->. control plane config + certs
- /etc/kubernetes/config --> extra components like scheduler YAML

On your server.
```
mkdir -p /etc/kubernetes/config /var/lib/kubernetes
```

Move certs and Kube config

```
cd /root

# move CA, API server cert, service-account certs
mv ca.pem ca-key.pem \
   kubernetes.pem kubernetes-key.pem \
   service-account.pem service-account-key.pem \
   /var/lib/kubernetes/

# if your encryption config is still in ~, move it too
[ -f encryption-config.yaml ] && mv encryption-config.yaml /var/lib/kubernetes/

# move the control-plane kubeconfigs
mv admin.kubeconfig \
   kube-controller-manager.kubeconfig \
   kube-scheduler.kubeconfig \
   /var/lib/kubernetes/

```
#### Kube-api server:  As a systemd service
Conceptually the kube-apiserver listens on the port 6443 for https.
terminates TLS using the kubernetes.pem [server cert]

- Get the internal IP of the server

```
INTERNAL_IP=$(hostname -I | awk '{print $1}')
echo "INTERNAL_IP=${INTERNAL_IP}"
```
Create a systemd Unit for Kube-apiserver

```
cat >/etc/systemd/system/kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota,NodeRestriction \\
  --enable-bootstrap-token-auth=true \\
  --etcd-servers=http://127.0.0.1:2379 \\
  --event-ttl=1h \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config=api/all=true \\
  --service-account-issuer=https://kubernetes.default.svc.cluster.local \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --secure-port=6443 \\
  --anonymous-auth=false \\
  --profiling=false \\
  --v=2
Restart=always
RestartSec=5
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF

```
#### kube-controller-manager: systemd service
This basically does the following
- Keeps a right quorum of pods on nodes
- Allocates PODs CIDRS to Nodes
- manages service accounts and tokens

```
cat >/etc/systemd/system/kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --allocate-node-cidrs=true \\
  --v=2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

```

#### kube-scheduler: config + systemd service
It looks fo Pods with no nodes attached and decides to place them to nodes.

Create a Scheduler config

```
  cat >/etc/kubernetes/config/kube-scheduler.yaml <<EOF
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

```

The above tells the scheduler which config to use and participate in leader selection.

Create a Service

```
cat >/etc/systemd/system/kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --bind-address=127.0.0.1 \\
  --v=2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

```

#### Start all control-plane services
Reload systemd and enable services

```
systemctl daemon-reload

systemctl enable kube-apiserver kube-controller-manager kube-scheduler

systemctl start kube-apiserver kube-controller-manager kube-scheduler

```

Basic health checks

```
systemctl status kube-apiserver
systemctl status kube-controller-manager
systemctl status kube-scheduler
```
Talk to your control plane with kubectl
```
cd /var/lib/kubernetes

kubectl cluster-info --kubeconfig=admin.kubeconfig

```

```
Kubernetes control plane is running at https://127.0.0.1:6443

```
From the Jumpbox or mac

```
curl --cacert ca.pem https://server.kubernetes.local:6443/version
```

#### RBAC so API server can talk to kubelet (kube-apiserver → kubelet)

Why do we need it , well when we call things like kubectl logs , kubectl exec , kubectl port-forward , the api server
needs to call the kubectl HTTP API on each of the worker node.
In these instances we want the API servers identiy to perform the action and use RBAC for that.

##### Create the rbac objects
On the server
 cd /var/lib/kubernetes

 ```
 cat > kube-apiserver-to-kubelet.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups: [""]
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - kind: User
    name: kubernetes
    apiGroup: rbac.authorization.k8s.io
EOF

 ```
 Apply it

```
kubectl apply -f kube-apiserver-to-kubelet.yaml \
  --kubeconfig=admin.kubeconfig

# You can verify by
kubectl get clusterroles \
  --kubeconfig=admin.kubeconfig \
  | grep kube-apiserver-to-kubelet

```




