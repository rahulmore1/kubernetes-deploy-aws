### Bootstraping the Worker Nodes
We are now going to bootstrap , the worker nodes 
For each node we need the following 
-   Container Runtime 
    -   We will use containerd , this is what will actually run your container.
-   CNI networking 
    -   This is something that will give IPs to your pods on a node so that they can talk to other nodes. 
-   Kubelet 
    -   Agent that runs on each pod and communicates with the api server
-   kube-proxy
    -   Kubernetes service implementation on the Node
  
What we alreay have on each node 
-   TLS certificates 
-   Kubeconfigs 
-   Working control plane on the server 

#### Preparation on your JumpBox
Make sure on your jumpbox you have the required certificates
Check by 
```aiexclude
ls node-0* node-1* ca*
```
Copy the certificats and the kubeconfigs to both the nodes
```
for host in node-0 node-1; do
  echo ">>> Copying certs and kubeconfigs to $host"
  scp ca.pem \
      ${host}.pem ${host}-key.pem \
      ${host}.kubeconfig \
      kube-proxy.kubeconfig \
      root@${host}:~/
done
```
##### On each node do the following , OS prereq on each node

On Node-0

Helper packages
```aiexclude
apt-get update
apt-get install -y socat conntrack ipset tar
```
-   socat --  for kubectl port forward
-   conntrack -- used by kube-proxy for tracking connections 
-   ipset/iptables -- used for service routing 
-    tar -unpack packages

Important to disable swap 
Kubelet will refuse to run if swap is enabled , because swap breaks resource accounting 

```aiexclude
swapon --show      # if this is empty, you’re good
swapoff -a         # turn off swap for this boot

# Comment out any swap line in /etc/fstab so it stays off after reboot
sed -i '/ swap / s/^/#/' /etc/fstab

```
Kernal Network Setting [bridge and forwarding]
For kubernetes to function properly the 
-   The kernal to pass bridge traffic through iptables
- IP forwarding is turned on so traffic can be routed between pods and outside world

```aiexclude
cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF >/etc/sysctl.d/99-k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

```
#### Install Contained and CNI plugin on each node. 

```aiexclude
apt-get install -y containerd
```
Generate a default config for containerd , and switch to the systemd cgroup driver

```aiexclude
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml

# Set SystemdCgroup = true under the runc runtime options
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd
systemctl status containerd --no-pager

```
An active status means we are fine on the node with regards to containerd

Create all runtime directories 
```aiexclude
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

```
#### Install the CNI Plugin Bridge and Loop bacl 

```aiexclude
cd /tmp

CNI_VERSION=v1.8.0   # good recent version
curl -L -o cni-plugins.tgz \
  https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-arm64-${CNI_VERSION}.tgz

tar -C /opt/cni/bin -xzvf cni-plugins.tgz

```
#### Install kubelet , kube-proxy , and kubectl on each node

```aiexclude
cd /usr/local/bin
K8S_VERSION=v1.34.2

for bin in kubelet kube-proxy kubectl; do
  echo ">>> Downloading $bin"
  curl -L -o ${bin} "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/arm64/${bin}"
  chmod +x ${bin}
done

```
I like to keep kubectl handy on each node , not required 

#### Configure CNI Plugin

Working with POD CIDR on each node
This will be different on each node as we have the following for each node,
-   node‑0 → 10.200.0.0/24 
- node‑1 → 10.200.1.0/24

On node-0 with POD CIDR 10.200.0.0/24

```aiexclude
export POD_CIDR="10.200.0.0/24"

cat <<EOF >/etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

cat <<EOF >/etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF

```
On node‑1, same but with POD_CIDR="10.200.1.0/24".
Why do we need these configs , majorly 
-   For the nodes to handout ips from the given subnets
- to use a linux bridge - cn01, o connect pods and route traffic

#### Kubelet configuration per node 
A kubelet is a agent running on each nodes that connect with the api server. 
They will need the following 
-   Client certificate and keys 
- CA certifiacte
- Pods CIDR
- location for container runtime , containerd  and CNI

Move certs and configs 
```aiexclude
HOSTNAME=$(hostname)   # should be "node-0"

mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
mv ${HOSTNAME}.pem /var/lib/kubelet/${HOSTNAME}.pem
mv ${HOSTNAME}-key.pem /var/lib/kubelet/${HOSTNAME}-key.pem

mv ca.pem /var/lib/kubernetes/ca.pem
mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

```
#### Create kubelet config YAML
```aiexclude
export POD_CIDR="10.200.0.0/24"

cat <<EOF >/var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF
```
#### Kubelet systemd service
 
```
cat <<EOF >/etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \
  --config=/var/lib/kubelet/kubelet-config.yaml \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --register-node=true \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

 ```
#### Kube‑proxy configuration
Kube-proxy programs the iptables so that the clusterIP and NodePort Services can work 

##### Kube-proxy yaml config 
```aiexclude
cat <<EOF >/var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

```
-   clusterCIDR is the overall Pod network, not just one node’s /24. With your per-node /24s, 10.200.0.0/16 covers them all.
##### Kube‑proxy systemd service

```
cat <<EOF >/etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

```
Start the services on each nodes

```aiexclude
systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy

systemctl status kubelet kube-proxy --no-pager

```
#### Verify from the control plane
```aiexclude
ssh -i ~/.ssh/id_ed25519_kthw root@server
cd /var/lib/kubernetes   # where your admin.kubeconfig lives
kubectl get nodes --kubeconfig=admin.kubeconfig

```
You should see something like 
```aiexclude
NAME    STATUS   ROLES    AGE   VERSION
node-0  Ready    <none>   1m    v1.34.2
```
Repeat all on Node-1



