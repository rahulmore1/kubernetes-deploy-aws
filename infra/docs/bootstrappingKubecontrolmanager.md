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
