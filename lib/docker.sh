# lib/docker.sh - Instalação do Docker

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
        return 0
    fi

    confirm "${PROMPT_CONFIRM}" || return 0

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

    log "${MSG_DOCK_INSTALLED}"
}
