### Configuring kubectl for Remote Access
Create an admin.config on your jumpbox

```aiexclude
KUBERNETES_PUBLIC_ADDRESS=54.245.180.115 # public ip of the server
```
 Define a cluster 
 
```aiexclude
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kthw-admin-remote.kubeconfig

```
This will define a cluster called kubernetes-the-hard-way.
This tells the Kubectl the following 
-   trust ca
- api server address is https://${KUBERNETES_PUBLIC_ADDRESS}:6443
- embed-certs=true , stores the ca inside the kubeconfig file

Define admin user
```
kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --embed-certs=true \
  --kubeconfig=kthw-admin-remote.kubeconfig

```
This will define a user called admin, use existing tls client certificates
and embed them in the kubeconfig file

Create a context tying them together
```aiexclude
kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=kthw-admin-remote.kubeconfig

```
Context named kubernetes-the-hard-way = “use user admin against cluster kubernetes-the-hard-way”.

Make that context the default in the file
```aiexclude
kubectl config use-context kubernetes-the-hard-way \
  --kubeconfig=kthw-admin-remote.kubeconfig

```
Test remote kubectl from your Mac
``kubectl --kubeconfig=kthw-admin-remote.kubeconfig get nodes
``

