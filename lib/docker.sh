# lib/docker.sh - Instalação do Docker

has_docker_compose() {
    docker compose version >/dev/null 2>&1 && return 0
    command -v docker-compose >/dev/null 2>&1 && return 0
    return 1
}

docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose "$@"
    else
        return 127
    fi
}

ensure_docker_compose() {
    if has_docker_compose; then
        return 0
    fi

    log "${DOCKER_COMPOSE_INSTALLING}"

    apt-get update -y >/dev/null 2>&1 || true

    if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
        apt-get install -y docker-compose-plugin || return 1
    elif apt-cache show docker-compose-v2 >/dev/null 2>&1; then
        apt-get install -y docker-compose-v2 || return 1
    elif apt-cache show docker-compose >/dev/null 2>&1; then
        apt-get install -y docker-compose || return 1
    else
        err "${DOCKER_COMPOSE_NOT_AVAILABLE}"
        return 1
    fi

    if ! has_docker_compose; then
        err "${DOCKER_COMPOSE_INSTALL_FAILED}"
        return 1
    fi

    log "${DOCKER_COMPOSE_READY}"
    return 0
}

ensure_container_running() {
    local container="$1"
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$container"; then
        err "${DOCKER_CONTAINER_NOT_RUNNING}: $container"
        return 1
    fi
    return 0
}

install_docker() {
    echo ""
    echo -e "${BD}${C}${MSG_MENU_DOCKER_BANNER}${NC}"
    echo ""
    echo "  ${MSG_MENU_DOCKER_WILL_INSTALL}"
    echo "    ${MSG_MENU_DOCKER_ENGINE}"
    echo "    ${MSG_MENU_DOCKER_REPO}"
    echo ""

    if has_docker; then
        info "${MSG_DOCK_ALREADY}"
        ensure_docker_compose || return 1
        return 0
    fi

    confirm "${PROMPT_CONFIRM}" || return 1

    create_backup "vps" "before-docker-install"

    echo ""
    spinner "${MSG_DOCK_ADDING_REPO}"
    if ! apt-get update -y; then
        err "${ERR_DOCKER_NOT_INSTALLED}. ${MSG_DOCKER_CHECK_CONNECTION}"
    fi
    if ! apt-get install -y ca-certificates curl gnupg; then
        err "${ERR_DOCKER_NOT_INSTALLED} (${MSG_DOCKER_FAILED_DEPS})."
    fi
    install -m 0755 -d /etc/apt/keyrings
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        err "${ERR_DOCKER_NOT_INSTALLED} ${MSG_DOCKER_FAILED_GPG}."
    fi
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

    spinner "${MSG_DOCK_INSTALLING}"
    if ! apt-get update -y; then
        err "${ERR_DOCKER_NOT_INSTALLED} Docker. ${MSG_DOCKER_CHECK_DEPS}"
    fi
    if ! apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        err "${ERR_DOCKER_NOT_INSTALLED}. ${MSG_DOCKER_CHECK_POLICY}"
    fi
    systemctl enable docker && systemctl start docker

    ensure_docker_compose || return 1

    log "${MSG_DOCK_INSTALLED}"
}
