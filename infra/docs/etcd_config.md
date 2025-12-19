### Configuring ETCD
What is ETCD and why do I care
The main rason , all the components of Kubernetes, 
kube-scheduler , kube-controller-manager, kube-apiserver, all are stateless. 
This means that they need a place to save the actual cluster states. 
This is where ETCD is comes in picture. 
K8 uses etcd like , 
-   All components talk to the API server.
-   The API server reads and writes cluster state in etcd

Basically this is DATABASE for Kubernetes. 

We will install etcd on the server node. 

Note : Once we have etcd installed and the excercise over we can practice two scenarios , one of backing up and restoring etcd and the other of using external encryption 

##### SSH into server
We will need the following 
-   etcd server binary , this is the actual KV store
-   client cli called etcdctl

On Server

```
cd /root
# still on server
cd /root

# choose an etcd version compatible with KTHW (3.6.x)
ETCD_VER=v3.6.0

# download Linux ARM64 build (your server is arm64)
curl -LO https://storage.googleapis.com/etcd/${ETCD_VER}/etcd-${ETCD_VER}-linux-arm64.tar.gz

# extract
tar -xvf etcd-${ETCD_VER}-linux-arm64.tar.gz

# move binaries into PATH
mv etcd-${ETCD_VER}-linux-arm64/etcd* /usr/local/bin/

# sanity check
etcd --version
etcdctl version
```

etcd directories 
/etc/etcd ->  has all the configuration and certificates
/var/lib/etcd -->. data directory for th persistant state

```
mkdir -p /etc/etcd /var/lib/etcd
chmod 700 /var/lib/etcd
```

Create a etcd systemd unit 
etcd runs as a daemon
li listens the clients on 
-   http://<INTERNAL_IP>:2379 for other machines (if needed) 
-   http://127.0.0.1:2379 so the API server (running on the same node) can talk to it
-   
listen to peers on http://<INTERNAN_IP>:2380
use the /var/lib/etcd as persistance store , or data directory 
Identifies in the  cluster as server. 

Get internal IPS 

```
INTERNAL_IP=$(hostname -I | awk '{print $1}')
ETCD_NAME=$(hostname -s)

echo "INTERNAL_IP=${INTERNAL_IP}"
echo "ETCD_NAME=${ETCD_NAME}"

```

##### Create /etc/systemd/system/etcd.service 
```
cat <<EOF >/etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --data-dir=/var/lib/etcd \\
  --listen-client-urls=http://${INTERNAL_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls=http://${INTERNAL_IP}:2379 \\
  --listen-peer-urls=http://${INTERNAL_IP}:2380 \\
  --initial-advertise-peer-urls=http://${INTERNAL_IP}:2380 \\
  --initial-cluster=${ETCD_NAME}=http://${INTERNAL_IP}:2380 \\
  --initial-cluster-state=new
Restart=always
RestartSec=5
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF

```
```
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd

```
```
#Check status 
systemctl status etcd
journalctl -u etcd -xe

```
##### Use etcdctl to inspect the member list
```
# ensure API v3 (default on modern etcd, but good habit)
export ETCDCTL_API=3

# by default etcdctl talks to http://127.0.0.1:2379
etcdctl member list

```
