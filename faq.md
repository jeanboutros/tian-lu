# FAQ

## How to generate ssh keys for the user

```
ssh-keygen -t ed25519 -C "your_email@example.com" -N "" -f ./keys/user__at_tianlu
```

## To search for machines on the network that have ssh port 22 enabled

```
nmap -p 22 --open -sV 192.168.2.0/24
```

