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

## To start the local Floci dev environment (Mac)

```bash
make dev-up
```

First run takes ~10–15 min (boots Ubuntu VM + installs Floci). Subsequent starts take ~30 seconds.

## To configure the AWS CLI for the dev environment

```bash
eval "$(make dev-env-export)"
```

This exports `AWS_PROFILE=ns-tianlu-floci-dev` plus `AWS_CONFIG_FILE` and `AWS_SHARED_CREDENTIALS_FILE` pointing at a project-local store under `~/.cache/tianlu-floci/aws` (your real `~/.aws` is left untouched). The profile carries the 12-digit account AKID, a generated secret (Floci ignores it today), region `eu-west-2`, and the Floci endpoint.

## To stop the dev environment (preserving all AWS data)

```bash
make dev-down
```

## To check dev environment status

```bash
make dev-status
```

## To rebuild the dev VM OS without losing AWS data

```bash
make dev-recreate
```

This deletes the Lima instance and creates a fresh one, but the standalone `floci-dev-data` disk (and all AWS state on it) is preserved.

## To permanently erase the dev environment

```bash
make dev-reset CONFIRM=reset
```

This deletes the VM **and** the data disk. All AWS state is lost. Confirmation is required.
