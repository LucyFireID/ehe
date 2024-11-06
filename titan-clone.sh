#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# URLs
DOCKER_GPG_URL="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)"
DOCKER_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/winsnip/Tools/refs/heads/main/Docker.sh"

# Function to print logs
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "-----------------------------------------------------"
    case $level in
        "INFO") echo -e "${CYAN}[INFO] ${timestamp} - ${message}${NC}" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS] ${timestamp} - ${message}${NC}" ;;
        "ERROR") echo -e "${RED}[ERROR] ${timestamp} - ${message}${NC}" ;;
    esac
    echo -e "-----------------------------------------------------\n"
}

# Cleanup function to remove downloaded files
cleanup() {
    rm -f titan-edge-cli.tar.gz
}
trap cleanup EXIT

# Start Docker and Titan Edge setup
log "INFO" "Memulai proses pengaturan Docker dan Titan Edge..."
sleep 2

# Accept a unique identifier for each clone
clone_id=$1
if [ -z "$clone_id" ]; then
    echo -e "${RED}Error: No clone ID provided. Usage: $0 <clone_id>${NC}"
    exit 1
fi

# Create a unique directory for each clone based on the clone ID
config_dir="$HOME/.titanedge_$clone_id"
mkdir -p "$config_dir"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log "INFO" "Menginstal Docker..."
    curl -sSL $DOCKER_INSTALL_SCRIPT_URL | bash
    log "SUCCESS" "Docker berhasil diinstal."
else
    log "SUCCESS" "Docker sudah terinstal, melewati proses instalasi."
fi

# Install Docker Compose if not present
log "INFO" "Menginstal Docker Compose..."
curl -L $DOCKER_COMPOSE_URL -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
log "SUCCESS" "Instalasi Docker Compose selesai."

# Pull the Titan Edge Docker image
log "INFO" "Menarik image Docker untuk Titan Edge..."
docker pull nezha123/titan-edge
log "SUCCESS" "Image Docker Titan Edge berhasil diunduh."

# Run the Docker container with the unique configuration directory
log "INFO" "Menjalankan kontainer Titan Edge untuk clone ID: $clone_id..."
docker run --network=host -d --name "titan-edge-container_$clone_id" -v "$config_dir:/root/.titanedge" nezha123/titan-edge
log "SUCCESS" "Kontainer Titan Edge berhasil dijalankan untuk clone ID: $clone_id."

# Prompt for identity code
read -p "Masukkan identity code untuk clone ID $clone_id: " identity_code

# Bind identity with the specified code
log "INFO" "Bind identitas dengan kode $identity_code untuk clone ID: $clone_id..."
docker run --rm -it -v "$config_dir:/root/.titanedge" nezha123/titan-edge bind --hash="$identity_code" https://api-test1.container1.titannet.io/api/v2/device/binding
log "SUCCESS" "Identitas berhasil bind untuk clone ID: $clone_id."
