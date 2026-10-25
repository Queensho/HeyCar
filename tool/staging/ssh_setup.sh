#!/usr/bin/env bash
set -euo pipefail
for name in SSH_KEY SSH_HOST SSH_PORT SSH_USER FINGERPRINT; do
  if [ -z "${!name}" ]; then echo "Missing staging binding: $name" >&2; exit 1; fi
done
test "$SSH_USER" = cepqontag-deploy
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
printf '%s\n' "$SSH_KEY" > "$HOME/.ssh/staging_key"
chmod 600 "$HOME/.ssh/staging_key"
ssh-keyscan -T 10 -t ed25519 -p "$SSH_PORT" -H "$SSH_HOST" > "$HOME/.ssh/known_hosts"
actual=$(ssh-keygen -lf "$HOME/.ssh/known_hosts" -E sha256 | awk 'NR==1 {print $2}')
test "$actual" = "$FINGERPRINT"
