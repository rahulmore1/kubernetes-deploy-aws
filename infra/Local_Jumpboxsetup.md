## SSH setup and Local Hostname
Things to Do 
1. Create a SSH key
   1. Add the key to the SSH agent Once 
   `ssh-add --apple-use-keychain ~/.ssh/id_ed25519_kthw
` Verify that the key iosn added 
`ssh-add -l`
Note this is per reboot
Can be made automatic by adding to the [optional]
`vim ~/.ssh/config
`
```
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519_kthw
```

2. Copy the key to all EC2 instances 
3. Changes to the Local Hosts. 


### Key Generation 
`ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_kthw`
`eval "$(ssh-agent -s)"`
`ssh-add ~/.ssh/id_ed25519_kthw`


### Copy The Key to the instances. 

Note this is for a Debian based instance and this and usually is admin as default user
`ssh-copy-id -i ~/.ssh/id_ed25519_kthw.pub admin@<server-public-ip>`
`ssh-copy-id -i ~/.ssh/id_ed25519_kthw.pub admin@<node-0-public-ip>`
`ssh-copy-id -i ~/.ssh/id_ed25519_kthw.pub admin@<node-1-public-ip>`

#### Enable root over SSH via key (simplifies KTHW flows):

```
ssh -i ~/.ssh/id_ed25519_kthw admin@<server-public-ip>
sudo -i
mkdir -p /root/.ssh
cat /home/admin/.ssh/authorized_keys >> /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
exit
exit
```
Do this on all nodes , once done you can SSH via root access. 



