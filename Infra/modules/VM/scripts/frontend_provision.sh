#!/bin/bash
# Frontend provisioning script

set -euxo pipefail

LOG_FILE="/var/log/frontend_provision.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== Starting frontend provisioning at $$(date) ====="

# Ensure root
if [ "$(id -u)" -ne 0 ]; then
  echo "Running with sudo..."
  exec sudo "$0" "$@"
fi

# -----------------------------
# Template variables (FROM TERRAFORM)
# -----------------------------
application_port="${application_port}"
full_image_name="${full_image_name}"
dockerhub_username="${dockerhub_username}"
dockerhub_password="${dockerhub_password}"
backend_lb_ip="${backend_lb_ip}"
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

# -----------------------------
# Docker login 
# -----------------------------

sleep 20
if [ -n "$${dockerhub_username:-}" ] && [ -n "$${dockerhub_password:-}" ]; then
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
# Backend LB IP
# -----------------------------
echo "Initial backend IP from Terraform: $backend_lb_ip"

# Discover backend if not provided
if [ -z "$backend_lb_ip" ]; then
  echo "Discovering backend load balancer..."

  for subnet in "10.0.3" "10.0.4"; do
    for i in $(seq 1 10); do
      ip="$${subnet}.$${i}"
      if nc -z -w 1 "$ip" 8080 >/dev/null 2>&1; then
        backend_lb_ip="$ip"
        echo "Found backend at $backend_lb_ip"
        break 2
      fi
    done
  done

  # fallback
  backend_lb_ip=$${backend_lb_ip:-10.0.3.4}
fi

echo "Using backend URL: http://${backend_lb_ip}:8080"

# -----------------------------
# Remove old container if exists
# -----------------------------
if docker ps -a --format '{{.Names}}' | grep -q "^frontend-app$"; then
  echo "Removing existing container..."
  docker rm -f frontend-app || true
fi
# -----------------------------
# Azure Login (Managed Identity)
# -----------------------------
echo "Logging into Azure using Managed Identity..."
az login --identity --allow-no-subscriptions >/dev/null 2>&1 || {
  echo "❌ Managed Identity login failed"
  
}
# -----------------------------
# Key Vault Name
# -----------------------------
KEY_VAULT_NAME=$(basename "$key_vault_id")
echo "Using Key Vault: $KEY_VAULT_NAME"

sleep 10
echo "Checking Key Vault access..."
echo "Checking Key Vault access..."
echo "Checking Managed Identity login..."
if ! az keyvault secret show \
  --vault-name "$KEY_VAULT_NAME" \
  --name "db-username" >/dev/null 2>&1; then
  echo "ERROR: Cannot access Key Vault secrets (RBAC issue)"
  
fi


echo "Starting agent container..."
echo "Fetching DB secrets..."

# -----------------------------
# Login using Managed Identity
# -----------------------------
az login --identity > /dev/null 2>&1

# -----------------------------
# Wait for RBAC propagation
# -----------------------------
echo "Waiting for RBAC..."
sleep 60

# -----------------------------
# Retry function
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

# -----------------------------
# Fetch secrets safely
# -----------------------------
db_username=$(get_secret "db-username")
db_password=$(get_secret "db-password")
db_host=$(get_secret "db-host")
db_name=$(get_secret "db-name")
db_port=$(get_secret "db-port")

# -----------------------------
# Validation (NO silent failure)
# -----------------------------
if [ -z "$db_password" ]; then
  echo "❌ DB password missing"
  
fi

sleep 10

# -----------------------------
# Run container
# -----------------------------
echo "Starting frontend container..."

docker run -d \
  --name frontend-app \
  -p "$application_port:8501" \
  -e DB_USERNAME="$db_username" \
  -e DB_USER="$db_username" \
  -e DB_PASSWORD="$db_password" \
  -e DB_PASS="$db_password" \
  -e DB_HOST="$db_host" \
  -e DB_NAME="$db_name" \
  -e DB_PORT="$db_port" \
  -e DB_SSLMODE="require" \
  -e BACKEND_URL="http://${backend_lb_ip}:8080" \
  --restart always \
  "$full_image_name"


# -----------------------------
# Verify container
# -----------------------------
sleep 5
# -----------------------------
# Run Agent Container
# -----------------------------
echo "Starting agent container..."
echo "Fetching DB secrets..."


# Remove old agent if exists
if docker ps -a --format '{{.Names}}' | grep -q "^agent$"; then
  docker rm -f agent || true
fi

docker pull srujandaddy/siem-agent:latest

sleep 20

docker run -d \
  --name agent \
  --network host \
  -v /var/log:/var/log \
  -e BACKEND_URL="http://${backend_lb_ip}:8080/logs" \
  --restart always \
  srujandaddy/siem-agent:latest \
  

echo "Running containers:"
docker ps

echo "Testing frontend locally..."
curl -f "http://localhost:$application_port/health" || echo "WARNING: Frontend not responding yet"

echo "===== Frontend provisioning completed at $$(date) ====="