#!/bin/bash

# Backend provisioning script

set -euxo pipefail

LOG_FILE="/var/log/backend_provision.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== Starting backend provisioning at $(date) ====="

# Ensure root

if [ "$(id -u)" -ne 0 ]; then
echo "Running with sudo..."
exec sudo "$0" "$@"
fi

# -----------------------------

# Template variables

# -----------------------------

application_port=8080
full_image_name="${full_image_name}"
dockerhub_username="${dockerhub_username}"
dockerhub_password="${dockerhub_password}"
key_vault_id="${key_vault_id}"

# -----------------------------

# Install dependencies

# -----------------------------
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  apt-transport-https ca-certificates curl software-properties-common dnsutils gnupg netcat-openbsd
# -----------------------------

# Install Docker

# -----------------------------

echo "Setting up Docker..."
install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null


apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker

# Add user to docker group

usermod -aG docker adminuser || true

# -----------------------------

# Install Azure CLI

# -----------------------------

if ! command -v az >/dev/null 2>&1; then
echo "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
fi



echo "Checking Key Vault access..."


  if ! az keyvault secret show \
  --vault-name "$KEY_VAULT_NAME" \
  --name "db-username" >/dev/null 2>&1; then
  echo "❌ Cannot access Key Vault (RBAC issue)"
  
fi
  echo "Proceeding anyway, but DB may fail..."



# -----------------------------

# Docker login (optional)

# -----------------------------

if [ -n "$dockerhub_username" ] && [ -n "$dockerhub_password" ]; then
echo "Logging into Docker Hub..."
echo "$dockerhub_password" | docker login -u "$dockerhub_username" --password-stdin
else
echo "Skipping Docker login (public image assumed)"
fi

# -----------------------------

# Pull image

# -----------------------------

echo "Pulling image: $full_image_name"
docker pull "$full_image_name"

# -----------------------------

# Key Vault setup

# -----------------------------

KEY_VAULT_NAME=$(basename "$key_vault_id")
echo "Using Key Vault: $KEY_VAULT_NAME"

# -----------------------------

# Azure login (Managed Identity)

# -----------------------------

az login --identity --allow-no-subscriptions >/dev/null 2>&1 || {
  echo "❌ Managed Identity login failed"
  
}


# -----------------------------

# Fetch secrets

# -----------------------------
get_secret () {
  for i in {1..6}; do
    value=$(az keyvault secret show \
      --vault-name "$KEY_VAULT_NAME" \
      --name "$1" \
      --query value -o tsv 2>/dev/null)

    if [ ! -z "$value" ]; then
      echo $value
      return
    fi

    echo "Retry $i for $1..."
    sleep 10
  done

  echo "❌ Failed to fetch secret: $1"
  
}

DB_USERNAME=$(get_secret "db-username")
DB_PASSWORD=$(get_secret "db-password")
DB_HOST=$(get_secret "db-host")
DB_NAME=$(get_secret "db-name")
DB_PORT=$(get_secret "db-port")
DB_SSLMODE=$(get_secret "db-sslmode")
# -----------------------------

# Validate secrets

# -----------------------------
echo "Checking DB connectivity..."

if [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_HOST" ]; then
  echo "❌ Critical DB secrets missing"
fi

if nc -z -w 3 "$DB_HOST" "$DB_PORT" >/dev/null 2>&1; then
  echo "DB connectivity OK"
else
  echo "WARNING: Cannot reach DB at $DB_HOST:$DB_PORT"
  echo "Proceeding anyway, but application may fail..."
fi



echo "All DB secrets retrieved successfully."

# -----------------------------

# Wait for DNS resolution

# -----------------------------

echo "Checking DNS for DB host: $DB_HOST"

for i in {1..20}; do
if nslookup "$DB_HOST" >/dev/null 2>&1; then
echo "DNS resolved"
break
fi
echo "Retry $i/20..."
sleep 10
done

# -----------------------------

# Remove old backend container

# -----------------------------

if docker ps -a --format '{{.Names}}' | grep -q "^backend-app$"; then
echo "Removing existing backend container..."
docker rm -f backend-app || true
fi

# -----------------------------

# Run backend container

# -----------------------------

echo "Starting backend container..."
docker run -d --name backend-app -p "$application_port:8000" -e DB_USERNAME="$DB_USERNAME" -e DB_PASSWORD="$DB_PASSWORD" -e DB_HOST="$DB_HOST" -e DB_NAME="$DB_NAME" -e DB_PORT="$DB_PORT" -e DB_SSLMODE="$DB_SSLMODE" --restart always "$full_image_name"


# -----------------------------

# WAIT FOR BACKEND HEALTH (CRITICAL)

# -----------------------------

echo "Waiting for backend to become healthy..."

for i in {1..30}; do
if curl -f "http://localhost:$application_port/health" >/dev/null 2>&1; then
echo "Backend is healthy"
break
fi
echo "Waiting... ($i)"
sleep 5
done

# -----------------------------

# Remove old agent container

# -----------------------------

if docker ps -a --format '{{.Names}}' | grep -q "^agent$"; then
docker rm -f agent || true
fi

# -----------------------------

# Run agent container (FIXED NETWORK)

# -----------------------------

echo "Starting agent container..."

docker pull srujandaddy/siem-agent:latest

docker run -d \
  --name agent \
  --network host \
  -e BACKEND_URL="http://localhost:8000/logs" \
  --restart always \
  srujandaddy/siem-agent:latest

# -----------------------------

# Verify

# -----------------------------

echo "Running containers:"
docker ps

echo "Testing backend locally..."
curl -f "http://localhost:$application_port/health" || echo "WARNING: Backend not responding yet"

echo "===== Backend provisioning completed at $$(date) ====="
