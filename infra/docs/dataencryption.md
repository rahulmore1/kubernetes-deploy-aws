### Generating the Data Encryption Config and Key
All the information is stored in the etdc [ data store for Kubernetes]
By default this information is stored as plain text on disc. 
The secrets are only base 64 encoded.

To solve the secrets issue we have to encrypt the data at rest. 
What it does is,
-   it makes the api server encrypt the resource like secret before commiting them to ETcd
-   We will create a encryption provider config (encryption-config.yaml) here

Here is the flow. 
-   Generate a strong random key 
-   Encryption config file references the key 
-   this file is placed on the control plane server
-   Later, when we start the API server, we point it at this file via the --encryption-provider-config flag.
-   Every time a Secret is created/updated, the API server:

    -   encrypts it using this key  and stores the ciphertext in etcd

##### Generate a Strong Encryption Key 
```
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo $ENCRYPTION_KEY
```
```
ssh -i ~/.ssh/id_ed25519_kthw root@server
mkdir -p /var/lib/kubernetes
```
```
cat > /var/lib/kubernetes/encryption-config.yaml <<EOF
kind: EncryptionConfiguration
apiVersion: apiserver.config.k8s.io/v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

```

#### How will we use this later
When we configure the kube-apiserver systemd unit (in the “Bootstrapping the Kubernetes Control Plane” lab), we will add a flag:
```
--encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml
```

