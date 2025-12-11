
### Basic tools

Make sure the following tools are installed on the Jumpbox. 
1. kubectl
2. cfssl

### Dedicated SSH Kys

`ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_kthw -C "kthw" `

Add it to ssh-agent so we do not have to keep entering the passpharase multiple times

`eval "$(ssh-agent -s)"`
`ssh-add ~/.ssh/id_ed25519_kthw`


