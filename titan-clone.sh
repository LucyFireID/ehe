#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

curl -s https://file.winsnip.xyz/file/uploads/Logo-winsip.sh | bash
echo -e "${CYAN}Starting Docker and Titan Edge...${NC}"
sleep 2

DOCKER_GPG_URL="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)"
DOCKER_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/winsnip/Tools/refs/heads/main/Docker.sh"

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

cleanup() {
    rm -f titan-edge-cli.tar.gz
}
trap cleanup EXIT

log "INFO" "Memulai proses pengaturan Docker dan Titan Edge..."
sleep 2

if docker ps -a | grep -q "titan-edge-container"; then
    log "INFO" "Menghentikan dan menghapus kontainer Titan Edge lama..."
    docker stop titan-edge-container || true
    docker rm titan-edge-container || true
    log "SUCCESS" "Kontainer lama berhasil dihentikan dan dihapus."

    log "INFO" "Menghapus folder konfigurasi Titan Edge lama..."
    rm -rf ~/.titanedge
    log "SUCCESS" "Folder konfigurasi Titan Edge lama berhasil dihapus."
else
    log "INFO" "Tidak ada kontainer Titan Edge yang ditemukan."
fi

log "INFO" "Memperbarui daftar paket dan menginstal paket dasar..."
apt update && apt upgrade -y

if ! command -v docker &> /dev/null; then
    log "INFO" "Menginstal Docker..."
    curl -sSL $DOCKER_INSTALL_SCRIPT_URL | bash
    log "SUCCESS" "Docker berhasil diinstal."
else
    log "SUCCESS" "Docker sudah terinstal, melewati proses instalasi."
fi

log "INFO" "Menginstal Docker Compose..."
curl -L $DOCKER_COMPOSE_URL -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
log "SUCCESS" "Instalasi Docker Compose selesai."

log "INFO" "Menarik image Docker untuk Titan Edge..."
docker pull nezha123/titan-edge
log "SUCCESS" "Image Docker Titan Edge berhasil diunduh."

mkdir -p ~/.titanedge

# Prompt user for number of clones
read -p "Masukkan jumlah kontainer yang ingin dibuat: " clone_count

# Validate input
if ! [[ "$clone_count" =~ ^[0-9]+$ ]] || [ "$clone_count" -le 0 ]; then
    log "ERROR" "Jumlah kontainer harus berupa angka positif."
    exit 1
fi

# Create specified number of clones
for i in $(seq 1 "$clone_count"); do
    log "INFO" "Membuat kontainer Titan Edge clone ke-$i..."
    container_name="titan-edge-container-clone-$i-$(date +%s)"  # Unique container name for each clone

    docker run --network=host -d --name "$container_name" -v ~/.titanedge:/root/.titanedge --restart always nezha123/titan-edge
    log "SUCCESS" "Kontainer Titan Edge clone ke-$i berhasil dijalankan."

    read -p "Masukkan identity code untuk clone ke-$i: " identity_code
    log "INFO" "Bind identitas dengan kode $identity_code untuk clone ke-$i..."
    docker run --rm -it -v ~/.titanedge:/root/.titanedge nezha123/titan-edge bind --hash="$identity_code" https://api-test1.container1.titannet.io/api/v2/device/binding
    log "SUCCESS" "Identitas berhasil bind untuk clone ke-$i."
done

# Enabling Docker to start automatically after reboot
log "INFO" "Mengaktifkan Docker agar berjalan otomatis setelah restart..."
systemctl enable docker
log "SUCCESS" "Docker telah diaktifkan untuk berjalan otomatis setelah restart."

# Additional step: Verify if Docker is running after a reboot
log "INFO" "Verifikasi Docker dan kontainer setelah reboot..."
sleep 5
docker ps -a
