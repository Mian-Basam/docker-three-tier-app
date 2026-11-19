#!/usr/bin/env bash
# First-time setup: create .env and a random DB password secret.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] || { cp .env.example .env; echo "created .env"; }
if [[ ! -s secrets/db_password.txt ]]; then
  umask 077
  head -c 24 /dev/urandom | base64 | tr -d '/+=' > secrets/db_password.txt
  echo "generated secrets/db_password.txt"
fi
# Docker Compose mounts file-based secrets with the host file's permissions, and the API
# container runs as a non-root user (UID 10001), so the file must be readable by it.
# It stays git-ignored; real deployments should use a secret store (Swarm/K8s secrets, Vault).
chmod 0644 secrets/db_password.txt
