### Setting KubecONFIG 
Each Kubeconfig answers the following questions 
Who am I talking too - which cluster  :Cluster Section 
Who am I -- User Section
Which combination shoudl we use now - context section

Overall Kubeconfis are created for the followig

-   each kubelet (node-0, node-1)
-   kube-proxy
-   kube-controller-manager
-   kube-scheduler
-   the admin user
-   
Later:
-   the kubelet, kube-proxy, etc. will use their kubeconfig file to talk to the API server.

-   your kubectl will use the admin kubeconfig to act as a human cluster admin.

Make sure you are in the same directory where you have the certificates. 

So the basic anatomy remains the same , fo reach kubeconfig we are going to utilise the same set of commands. 
1.  set-cluster – define where the API server is and which CA to trust.
2.  set-credentials – define the client identity (which cert/key to use).
3.  set-context – tie 1 and 2 together.
4.  use-context – make that context the default in this kubeconfig file.

#### Kubelet kubeconfigs (node-0 and node-1)
These configs are used to know where the API server is and also to present it self. 

A concept called NodeAuthorizer will evaluate each node based on this. 

```
for host in node-0 node-1; do
  echo ">>> Building kubeconfig for ${host}"

  # 1) Which cluster? (where + CA)
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=${host}.kubeconfig

  # 2) Who am I? (client cert + key)
  kubectl config set-credentials system:node:${host} \
    --client-certificate=${host}.pem \
    --client-key=${host}-key.pem \
    --embed-certs=true \
    --kubeconfig=${host}.kubeconfig

  # 3) How to combine cluster + user?
  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${host} \
    --kubeconfig=${host}.kubeconfig

  # 4) Make that context the default in this file
  kubectl config use-context default \
    --kubeconfig=${host}.kubeconfig
done
```

#### kube-proxy kubeconfig
Kube-proxy talks to the api server
- It watches service endpoints , etc
- it has its own identity and also its own certificate

```
echo ">>> Building kube-proxy kubeconfig"
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-proxy.kubeconfig
```
#### kube-controller-manager kubeconfig
kube-controller-manager is a control plane component that talks to the API server
It needs where the api server is and also its own identty - system:kube-controller-manager

```
echo ">>> Building kube-controller-manager kubeconfig"

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-controller-manager.kubeconfig
```

#### kube-scheduler kubeconfig
Similar to to the kube-controller-manager

```
echo ">>> Building kube-scheduler kubeconfig"

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.pem\
  --client-key=kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-scheduler.kubeconfig

```

#### admin kubeconfig
This kubeconfig describes you, the admin, when you run kubectl on the server node.
-   CN = admin
-   O = system:masters → this group is treated as cluster-admin.

```
echo ">>> Building admin kubeconfig"

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default \
  --kubeconfig=admin.kubeconfig

```

 127.0.0.1 is the machine that runs the kubectl. 

#### Distribute kubeconfigs to the correct machines

##### To the workers: kubelet + kube-proxy
Each node should get the following 
-   its own kubelet kubeconfig → /var/lib/kubelet/kubeconfig
-   shared kube-proxy kubeconfig → /var/lib/kube-proxy/kubeconfig

```
for host in node-0 node-1; do
  echo ">>> Copying kubeconfigs to ${host}"

  # ensure config dirs exist
  ssh -i ~/.ssh/id_ed25519_kthw root@${host} "mkdir -p /var/lib/{kubelet,kube-proxy}"

  # kube-proxy
  scp -i ~/.ssh/id_ed25519_kthw kube-proxy.kubeconfig \
    root@${host}:/var/lib/kube-proxy/kubeconfig

  # kubelet (per-node)
  scp -i ~/.ssh/id_ed25519_kthw ${host}.kubeconfig \
    root@${host}:/var/lib/kubelet/kubeconfig
done
```
##### To the server: control-plane + admin

The control-plane node (server) needs:
-   kube-controller-manager.kubeconfig
-   kube-scheduler.kubeconfig
-   admin.kubeconfig

```
scp -i ~/.ssh/id_ed25519_kthw \
  admin.kubeconfig \
  kube-controller-manager.kubeconfig \
  kube-scheduler.kubeconfig \
  root@server:~/

```   

Quick Verification on Each Servers

```
# On Node-0
ssh -i ~/.ssh/id_ed25519_kthw root@node-0 "ls -R /var/lib/kubelet /var/lib/kube-proxy"
# On Node-1
Same as Above
# On Server
ssh -i ~/.ssh/id_ed25519_kthw root@server "ls *.kubeconfig"

```
