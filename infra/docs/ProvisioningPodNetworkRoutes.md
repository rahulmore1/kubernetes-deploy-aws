### Provisioning Pod Network Routes
What are we trying to solve here 
- We need to provision routes for pods to communicate with each other across nodes
- We need to provision routes for pods to communicate with services
- We need to provision routes for pods to communicate with external networks

Each Nodes has a Pod CIDR
node-0 → 10.200.0.0/24
node-1 → 10.200.1.0/24

When a pod is scheduled on node-0 it gets a IP like 10.200.0.X
When a pod is scheduled on node-1 it gets a IP like 10.200.1.X

Locally on each node the CNI Bridge , cnio0 and host-local IPAM each know how to reach thei pod subnets 
But 
Other machines , the server , other node , will not know how to reach
“To reach 10.200.0.0/24, go via node-0’s internal IP”
“To reach 10.200.1.0/24, go via node-1’s internal IP”

So:
Pod on node-0 → Pod on node-1 will fail (no route).
Server → Pod, Node-0 → Pod on Node-1, etc., will fail.

Here we will use Linux Static routes
For each Pod CIDR, add a route that says “send this traffic to the node’s internal IP”.
From earlier in your setup:

-   Server private IP: 10.240.0.209

-   node-0 private IP: 10.240.0.141

-   node-1 private IP: 10.240.0.94

Pod CIDRs:

-   node-0 Pods: 10.200.0.0/24

-   node-1 Pods: 10.200.1.0/24

We’re going to teach:

Server how to reach both Pod subnets

-   node-0 how to reach 10.200.1.0/24 via node-1

-   node-1 how to reach 10.200.0.0/24 via node-0

That’s enough for:

-   Pod ↔ Pod cross-node

-   Server ↔ Pod (handy for debugging)

SSH into server 

```aiexclude
# Pods on node-0
ip route add 10.200.0.0/24 via 10.240.0.141

# Pods on node-1
ip route add 10.200.1.0/24 via 10.240.0.94

# check 
ip route
```
On Node-0,

``` ip route add 10.200.1.0/24 via 10.240.0.94 ```

Check 

``
ip route | grep 10.200
``

Add routes on node-1

``
ip route add 10.200.0.0/24 via 10.240.0.141
``
hese ip route add changes:

Are in-memory only – they’ll disappear on reboot.

For KTHW (a learning lab) that’s fine.

In a more “prod-like” setup, you’d:

either use VPC route tables with ENIs as targets, or

bake static routes into your network config (netplan/systemd-networkd), or

use a real CNI like Calico/Flannel, which programs routes automatically.

For now, ephemeral routes are perfect for understanding what’s happening.

The cluster now is capable of end to end connectivity
