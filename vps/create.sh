#!/usr/bin/env bash
#
# vps/create.sh
# Creates a new VPS instance using LXC/LXD where available, falling
# back to Docker otherwise. Each VPS receives root access, dedicated
# CPU/RAM/disk limits, a hostname, SSH access, automatic networking
# and automatic DNS. Metadata is persisted so start/stop/restart/
# delete/list/console/backup/restore can operate on it later.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.conf"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/utils.sh"

require_root
trap_errors

CREATED_RESOURCE=0
BACKEND=""
NAME=""

# ---------------------------------------------------------------------------
# Cleanup on failure
# ---------------------------------------------------------------------------

cleanup_on_failure() {
    if [[ "$CREATED_RESOURCE" -eq 1 ]]; then
        msg_warn "Rolling back partially created VPS '$NAME'..."

        if [[ "$BACKEND" == "lxc" ]]; then
            lxc delete --force "$NAME" >/dev/null 2>&1
        elif [[ "$BACKEND" == "docker" ]]; then
            docker rm -f "$NAME" >/dev/null 2>&1
        fi

        rm -f "$VPS_DATA_DIR/$NAME.conf"
        infinite_log "ERROR" "VPS creation for '$NAME' failed and was rolled back."
    fi
}

trap cleanup_on_failure EXIT

# ---------------------------------------------------------------------------
# Backend detection
# ---------------------------------------------------------------------------

detect_backend() {
    if command_exists lxc && lxc info >/dev/null 2>&1; then
        BACKEND="lxc"
        msg_success "LXC/LXD detected. Containers will be created with LXC."
    elif command_exists docker; then
        BACKEND="docker"
        msg_warn "LXC/LXD not available. Falling back to Docker."
    else
        msg_error "Neither LXC nor Docker is installed. Run Panel Setup > Dependencies first."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Input collection
# ---------------------------------------------------------------------------

gather_input() {
    mkdir -p "$VPS_DATA_DIR"

    while true; do
        read -r -p "VPS name (letters, numbers, hyphens): " NAME
        if ! validate_hostname "$NAME"; then
            continue
        fi
        if [[ -f "$VPS_DATA_DIR/$NAME.conf" ]]; then
            msg_error "A VPS named '$NAME' already exists."
            continue
        fi
        break
    done

    read -r -p "Hostname [$NAME]: " VPS_HOSTNAME
    VPS_HOSTNAME="${VPS_HOSTNAME:-$NAME}"

    echo -e "${C_WHITE}Available OS images:${C_RESET}"
    echo "  [1] Ubuntu 22.04"
    echo "  [2] Ubuntu 24.04"
    echo "  [3] Debian 12"
    read -r -p "Select OS [1]: " os_choice
    os_choice="${os_choice:-1}"

    case "$os_choice" in
        1)
            LXC_IMAGE="images:ubuntu/22.04"
            DOCKER_IMAGE="ubuntu:22.04"
            OS_LABEL="Ubuntu 22.04"
            ;;
        2)
            LXC_IMAGE="images:ubuntu/24.04"
            DOCKER_IMAGE="ubuntu:24.04"
            OS_LABEL="Ubuntu 24.04"
            ;;
        3)
            LXC_IMAGE="images:debian/12"
            DOCKER_IMAGE="debian:12"
            OS_LABEL="Debian 12"
            ;;
        *)
            msg_error "Invalid OS selection."
            exit 1
            ;;
    esac

    read -r -p "CPU cores [$DEFAULT_VPS_CPU]: " VPS_CPU
    VPS_CPU="${VPS_CPU:-$DEFAULT_VPS_CPU}"
    validate_number "$VPS_CPU" "CPU cores" || exit 1

    read -r -p "RAM in MB [$DEFAULT_VPS_RAM_MB]: " VPS_RAM_MB
    VPS_RAM_MB="${VPS_RAM_MB:-$DEFAULT_VPS_RAM_MB}"
    validate_number "$VPS_RAM_MB" "RAM" || exit 1

    read -r -p "Disk in GB [$DEFAULT_VPS_DISK_GB]: " VPS_DISK_GB
    VPS_DISK_GB="${VPS_DISK_GB:-$DEFAULT_VPS_DISK_GB}"
    validate_number "$VPS_DISK_GB" "Disk" || exit 1

    read -r -p "VPS username [root]: " VPS_USERNAME
    VPS_USERNAME="${VPS_USERNAME:-root}"

    read -r -s -p "VPS password (leave blank to auto-generate): " VPS_PASSWORD
    echo
    if [[ -z "$VPS_PASSWORD" ]]; then
        VPS_PASSWORD=$(generate_random_password 16)
        msg_warn "Generated password: $VPS_PASSWORD"
    fi

    read -r -p "SSH port [random]: " SSH_PORT
    if [[ -z "$SSH_PORT" ]]; then
        SSH_PORT=$(random_port 20000 40000)
    fi
    validate_number "$SSH_PORT" "SSH port" || exit 1

    read -r -p "Network (bridge name, or 'auto') [auto]: " NETWORK_MODE
    NETWORK_MODE="${NETWORK_MODE:-auto}"
}

# ---------------------------------------------------------------------------
# LXC creation path
# ---------------------------------------------------------------------------

create_with_lxc() {
    msg_info "Launching LXC container '$NAME' from $OS_LABEL..."

    local network_args=()
    if [[ "$NETWORK_MODE" != "auto" ]]; then
        network_args=(--network "$NETWORK_MODE")
    fi

    if ! lxc launch "$LXC_IMAGE" "$NAME" "${network_args[@]}"; then
        msg_error "Failed to launch LXC container."
        exit 1
    fi

    CREATED_RESOURCE=1

    msg_info "Applying resource limits (CPU: $VPS_CPU, RAM: ${VPS_RAM_MB}MB, Disk: ${VPS_DISK_GB}GB)..."

    lxc config set "$NAME" limits.cpu "$VPS_CPU"
    lxc config set "$NAME" limits.memory "${VPS_RAM_MB}MB"

    if ! lxc config device override "$NAME" root size="${VPS_DISK_GB}GB" >/dev/null 2>&1; then
        lxc config device add "$NAME" root disk path=/ pool=default size="${VPS_DISK_GB}GB" >/dev/null 2>&1 \
            || msg_warn "Could not enforce a hard disk quota on this storage backend."
    fi

    msg_info "Waiting for container network to come up..."

    local tries=0
    local container_ip=""
    while [[ "$tries" -lt 30 ]]; do
        container_ip=$(lxc list "$NAME" -c 4 --format csv 2>/dev/null | awk '{print $1}')
        [[ -n "$container_ip" ]] && break
        sleep 1
        ((tries++))
    done

    if [[ -z "$container_ip" ]]; then
        msg_warn "Network address not detected yet; the container may still be booting."
    else
        msg_success "Container network is up: $container_ip"
    fi

    msg_info "Configuring hostname, DNS, root access and SSH inside the container..."

    lxc exec "$NAME" -- bash -c "hostnamectl set-hostname '$VPS_HOSTNAME' 2>/dev/null || hostname '$VPS_HOSTNAME'"

    lxc exec "$NAME" -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf; echo 'nameserver 1.1.1.1' >> /etc/resolv.conf"

    lxc exec "$NAME" -- bash -c "apt-get update -y && apt-get install -y openssh-server sudo >/dev/null 2>&1"

    lxc exec "$NAME" -- bash -c "echo 'root:${VPS_PASSWORD}' | chpasswd"
    lxc exec "$NAME" -- bash -c "sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
    lxc exec "$NAME" -- bash -c "sed -i 's/^#\?Port .*/Port ${SSH_PORT}/' /etc/ssh/sshd_config"
    lxc exec "$NAME" -- bash -c "grep -q '^Port ${SSH_PORT}' /etc/ssh/sshd_config || echo 'Port ${SSH_PORT}' >> /etc/ssh/sshd_config"

    if [[ "$VPS_USERNAME" != "root" ]]; then
        lxc exec "$NAME" -- bash -c "id -u '$VPS_USERNAME' >/dev/null 2>&1 || useradd -m -s /bin/bash '$VPS_USERNAME'"
        lxc exec "$NAME" -- bash -c "echo '${VPS_USERNAME}:${VPS_PASSWORD}' | chpasswd"
        lxc exec "$NAME" -- bash -c "usermod -aG sudo '$VPS_USERNAME'"
    fi

    lxc exec "$NAME" -- bash -c "systemctl enable ssh >/dev/null 2>&1; systemctl restart ssh >/dev/null 2>&1 || service ssh restart"

    container_ip=$(lxc list "$NAME" -c 4 --format csv 2>/dev/null | awk '{print $1}')
    VPS_IP="${container_ip:-N/A}"
    CONTAINER_REF="$NAME"

    msg_success "LXC container '$NAME' is up and configured."
}

# ---------------------------------------------------------------------------
# Docker creation path
# ---------------------------------------------------------------------------

create_with_docker() {
    msg_info "Creating Docker container '$NAME' from $DOCKER_IMAGE..."

    local mem_mb="${VPS_RAM_MB}m"
    local storage_opt=()

    if docker info 2>/dev/null | grep -qi "overlay2" && [[ -n "${VPS_DISK_GB:-}" ]]; then
        storage_opt=(--storage-opt "size=${VPS_DISK_GB}G")
    fi

    local network_arg="bridge"
    if [[ "$NETWORK_MODE" != "auto" ]]; then
        network_arg="$NETWORK_MODE"
        docker network inspect "$network_arg" >/dev/null 2>&1 \
            || docker network create "$network_arg" >/dev/null 2>&1
    fi

    if ! docker run -d \
        --name "$NAME" \
        --hostname "$VPS_HOSTNAME" \
        --cpus "$VPS_CPU" \
        --memory "$mem_mb" \
        --network "$network_arg" \
        --dns 8.8.8.8 --dns 1.1.1.1 \
        -p "${SSH_PORT}:22" \
        "${storage_opt[@]}" \
        --restart unless-stopped \
        "$DOCKER_IMAGE" tail -f /dev/null; then

        if [[ "${#storage_opt[@]}" -gt 0 ]]; then
            msg_warn "Disk quota not supported by this storage driver. Retrying without it..."
            docker run -d \
                --name "$NAME" \
                --hostname "$VPS_HOSTNAME" \
                --cpus "$VPS_CPU" \
                --memory "$mem_mb" \
                --network "$network_arg" \
                --dns 8.8.8.8 --dns 1.1.1.1 \
                -p "${SSH_PORT}:22" \
                --restart unless-stopped \
                "$DOCKER_IMAGE" tail -f /dev/null || { msg_error "Failed to create Docker container."; exit 1; }
        else
            msg_error "Failed to create Docker container."
            exit 1
        fi
    fi

    CREATED_RESOURCE=1

    msg_info "Configuring root access, packages and SSH inside the container..."

    docker exec "$NAME" bash -c "apt-get update -y && apt-get install -y openssh-server sudo passwd >/dev/null 2>&1"
    docker exec "$NAME" bash -c "mkdir -p /var/run/sshd"
    docker exec "$NAME" bash -c "echo 'root:${VPS_PASSWORD}' | chpasswd"
    docker exec "$NAME" bash -c "sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
    docker exec "$NAME" bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf; echo 'nameserver 1.1.1.1' >> /etc/resolv.conf" || true

    if [[ "$VPS_USERNAME" != "root" ]]; then
        docker exec "$NAME" bash -c "id -u '$VPS_USERNAME' >/dev/null 2>&1 || useradd -m -s /bin/bash '$VPS_USERNAME'"
        docker exec "$NAME" bash -c "echo '${VPS_USERNAME}:${VPS_PASSWORD}' | chpasswd"
        docker exec "$NAME" bash -c "usermod -aG sudo '$VPS_USERNAME'"
    fi

    docker exec -d "$NAME" /usr/sbin/sshd

    VPS_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$NAME" 2>/dev/null)
    VPS_IP="${VPS_IP:-N/A}"
    CONTAINER_REF=$(docker inspect -f '{{.Id}}' "$NAME" 2>/dev/null | cut -c1-12)

    msg_success "Docker container '$NAME' is up and configured. SSH mapped to host port ${SSH_PORT}."
}

# ---------------------------------------------------------------------------
# Metadata persistence
# ---------------------------------------------------------------------------

save_metadata() {
    local conf_file="$VPS_DATA_DIR/$NAME.conf"

    cat > "$conf_file" <<EOF
# INFINITE VPS MANAGER - instance metadata
# Managed automatically. Do not edit while the VPS is running.

NAME="$NAME"
TYPE="$BACKEND"
CONTAINER_REF="$CONTAINER_REF"
HOSTNAME="$VPS_HOSTNAME"
OS_LABEL="$OS_LABEL"
LXC_IMAGE="$LXC_IMAGE"
DOCKER_IMAGE="$DOCKER_IMAGE"
CPU="$VPS_CPU"
RAM_MB="$VPS_RAM_MB"
DISK_GB="$VPS_DISK_GB"
USERNAME="$VPS_USERNAME"
PASSWORD="$VPS_PASSWORD"
SSH_PORT="$SSH_PORT"
NETWORK_MODE="$NETWORK_MODE"
IP_ADDRESS="$VPS_IP"
CREATED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
STATUS="running"
EOF

    chmod 600 "$conf_file"
    msg_success "VPS metadata saved to $conf_file"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    print_header "CREATE VPS"

    detect_backend
    gather_input

    if [[ "$BACKEND" == "lxc" ]]; then
        create_with_lxc
    else
        create_with_docker
    fi

    save_metadata

    infinite_log "INFO" "VPS '$NAME' created successfully using $BACKEND backend."

    print_line "="
    echo -e "${C_WHITE}  Name      : $NAME"
    echo -e "${C_WHITE}  Backend   : $BACKEND"
    echo -e "${C_WHITE}  Hostname  : $VPS_HOSTNAME"
    echo -e "${C_WHITE}  OS        : $OS_LABEL"
    echo -e "${C_WHITE}  CPU       : $VPS_CPU core(s)"
    echo -e "${C_WHITE}  RAM       : ${VPS_RAM_MB}MB"
    echo -e "${C_WHITE}  Disk      : ${VPS_DISK_GB}GB"
    echo -e "${C_WHITE}  Username  : $VPS_USERNAME"
    echo -e "${C_WHITE}  Password  : $VPS_PASSWORD"
    echo -e "${C_WHITE}  SSH Port  : $SSH_PORT"
    echo -e "${C_WHITE}  IP        : $VPS_IP${C_RESET}"
    print_line "="

    CREATED_RESOURCE=0
    trap - EXIT
}

main
