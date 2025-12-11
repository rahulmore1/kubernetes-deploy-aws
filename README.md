# Kubernetes the Hard Way on AWS (ARM / Debian / v1.34.x) — Deep Dive

This guide walks through setting up a **real** Kubernetes cluster on AWS **without** kubeadm or a managed service.

You will:

- Build **PKI (TLS)** for all components.
- Run **etcd**, **kube-apiserver**, **kube-controller-manager**, **kube-scheduler**.
- Configure **kubelet**, **kube-proxy**, **containerd**, **CNI**.
- Deploy **CoreDNS**, verify **DNS**, **Services**, **Pods**, and **encryption at rest**.
- Reproduce a lot of real-world troubleshooting you’ll actually face.

The cluster:

- 1 control plane node: `server`
- 2 worker nodes: `node-0`, `node-1`
- Debian 13 (trixie), arm64.
- Kubernetes v1.34.2.
- containerd v1.7.x.

---

## 0. Architecture Overview

### 0.1 Diagram

```text
                        ┌─────────────────────────────┐
                        │        Your Laptop          │
                        │  kubectl, cfssl, SSH        │
                        └────────────┬────────────────┘
                                     │ (SSH + kubectl)
                         Internet    │
─────────────────────────────────────┼────────────────────────────
                                     │
                 AWS Region          │
                                     ▼
                     (VPC, Subnet, Security Group)


          ┌──────────────────────────┴──────────────────────────┐
          │                                                     │
   ┌──────┴───────┐                                       ┌─────┴───────┐
   │  server      │                                       │  node-0     │
   │ (control     │                                       │ (worker)    │
   │  plane)      │                                       │             │
   │              │                                       │  kubelet    │
   │  etcd        │                                       │  kube-proxy │
   │  kube-apiserver                                    ┌─┴─┐ CNI        │
   │  kube-controller-manager                           │   │ containerd │
   │  kube-scheduler                                    │   └────────────┘
   │  CoreDNS (kube-dns Service)                        │   PodCIDR:    │
   └──────┬────────┘                                   10.200.0.0/24    │
          │                                                      └──────┬
          │                                                             │
          │                                                       ┌─────┴───────┐
          │                                                       │  node-1     │
          │                                                       │ (worker)    │
          │                                                       │             │
          │                                                       │  kubelet    │
          │                                                       │  kube-proxy │
          │                                                       │  CNI        │
          │                                                       │  containerd │
          │                                                       │ PodCIDR:    │
          │                                                       │ 10.200.1.0/24
          │                                                       └─────────────┘

