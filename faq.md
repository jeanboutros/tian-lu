# FAQ

## How to generate ssh keys for the user

```
ssh-keygen -t ed25519 -C "your_email@example.com" -N "" -f ./keys/user__at_tianlu
```

## To search for machines on the network that have ssh port 22 enabled

```
nmap -p 22 --open -sV 10.0.0.0/24
```

## To connect

```
ssh -i ~/projects/tianlu/keys/huyang__at_tianlu \
  -o IdentitiesOnly=yes \
  -o AddKeysToAgent=no \
  -o PreferredAuthentications=publickey \
  huyang@10.0.0.5
```

## To shutdown

```
sudo shutdown -P now
```

## To deploy / re-deploy Floci

```
sudo ./setup-floci.sh
```

The script is idempotent — safe to re-run at any time to reconcile state.

## To check if Floci is running

```bash
# As the floci user
sudo -u floci systemctl --user status floci.service

# Quick health check (from the server itself)
curl -k --resolve tianlu-floci:4566:127.0.0.1 https://tianlu-floci:4566/_floci/init
```

## To restart Floci

```bash
sudo -u floci systemctl --user restart floci.service
```

## To view Floci logs

```bash
sudo -u floci journalctl --user -u floci.service -f
```

## To check the firewall

```bash
sudo ufw status numbered
```

## To run a quick smoke test against Floci

```bash
# From the server (AWS CLI, disable TLS verification for self-signed cert)
aws --endpoint-url https://tianlu-floci:4566 --no-verify-ssl s3 ls

# From a LAN client (once tianlu-floci resolves — see dnsmasq design)
aws --endpoint-url https://tianlu-floci:4566 --no-verify-ssl s3 mb s3://test-bucket
```

## To run the test suite

```bash
make check          # lint + unit tests (seconds)
make twin-test      # full Lima digital-twin end-to-end run (~15–30 min, Apple Silicon only)
```

See `docs/testing-guide.md` for the full guide.
