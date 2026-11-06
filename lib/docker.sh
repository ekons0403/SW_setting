#!/bin/bash

# 가상환경 여부
REQUIRE_VENV=false


# ============================================================
# Docker 설치
# ============================================================
install_docker() {
    echo ""
    echo "========================================"
    echo "        Docker Installation"
    echo "========================================"
    echo ""

    # 이미 설치되어 있는지 확인
    if command -v docker >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version 2>/dev/null \
            | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' \
            | head -n1)

        echo "Installed : Docker"
        echo "Version   : ${DOCKER_VERSION:-확인 불가}"

        print_message INFO "Docker가 이미 설치되어 있습니다."

        add_installed_software "docker" "system"

        return 2
    fi

    echo "Docker : 설치되지 않음"
    echo ""

    read -p "Docker를 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM

    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi

    echo ""
    print_message INFO "Docker 설치를 시작합니다."

    curl -fsSL https://get.docker.com/ | sudo sh

    if [ $? -ne 0 ]; then
        print_message ERROR "Docker 설치에 실패했습니다."
        return 1
    fi

    echo ""
    print_message INFO "현재 사용자를 Docker 그룹에 추가합니다."

    sudo usermod -aG docker "$USER"

    if [ $? -ne 0 ]; then
        print_message ERROR "Docker 그룹 추가에 실패했습니다."
        return 1
    fi

    echo ""
    print_message INFO "Docker 서비스 상태를 확인합니다."

    if systemctl is-active --quiet docker; then
        print_message SUCCESS "Docker 서비스가 정상적으로 실행 중입니다."
    else
        print_message INFO "Docker 서비스를 시작합니다."

        sudo systemctl start docker

        if [ $? -ne 0 ]; then
            print_message ERROR "Docker 서비스 시작에 실패했습니다."
            return 1
        fi
    fi

    # 설치 확인
    if ! command -v docker >/dev/null 2>&1; then
        print_message ERROR "Docker 설치를 확인할 수 없습니다."
        return 1
    fi

    DOCKER_VERSION=$(docker --version 2>/dev/null \
        | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' \
        | head -n1)

    echo ""
    echo "Docker : ${DOCKER_VERSION:-확인 불가}"

    add_installed_software "docker" "system"

    if [ $? -ne 0 ]; then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi

    echo ""
    print_message INFO "Docker 그룹 적용을 위해 로그아웃 후 다시 로그인하거나 재부팅해주세요."

    return 0
}


# ============================================================
# NVIDIA Container Toolkit 설치 여부 확인
# ============================================================
is_nvidia_container_toolkit_installed() {
    dpkg-query -W \
        -f='${db:Status-Status}' \
        nvidia-container-toolkit 2>/dev/null \
        | grep -qx "installed"
}


# ============================================================
# Docker 삭제
# ============================================================
uninstall_docker() {
    echo ""
    echo "========================================"
    echo "        Docker Uninstallation"
    echo "========================================"
    echo ""

    # Docker 설치 여부 확인
    if ! command -v docker >/dev/null 2>&1; then
        print_message INFO "Docker가 설치되어 있지 않습니다."
        return 2
    fi

    DOCKER_VERSION=$(docker --version 2>/dev/null \
        | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' \
        | head -n1)

    echo "Installed : Docker"
    echo "Version   : ${DOCKER_VERSION:-확인 불가}"
    echo ""

    # --------------------------------------------------------
    # NVIDIA Container Toolkit 의존성 확인
    # --------------------------------------------------------
    if is_nvidia_container_toolkit_installed; then

        echo "========================================"
        echo "        Dependency Warning"
        echo "========================================"
        echo ""

        print_message WARN "NVIDIA Container Toolkit이 설치되어 있습니다."
        print_message WARN "Docker 삭제 시 NVIDIA Container Toolkit도 함께 삭제해야 합니다."

        echo ""
        read -p "Docker와 NVIDIA Container Toolkit을 함께 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM

        if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
            print_message INFO "삭제를 취소했습니다."
            return 3
        fi

        echo ""
        print_message INFO "NVIDIA Container Toolkit을 먼저 삭제합니다."

        # 현재 Docker 모듈과 같은 디렉터리의 Toolkit 모듈 로드
        TOOLKIT_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/nvidia-container-toolkit.sh"

        if [ ! -f "$TOOLKIT_SCRIPT" ]; then
            print_message ERROR "NVIDIA Container Toolkit 모듈을 찾을 수 없습니다."
            return 1
        fi

        source "$TOOLKIT_SCRIPT"

        # Toolkit 전용 함수가 있는지 확인
        if ! declare -F uninstall_nvidia_container_toolkit >/dev/null 2>&1; then
            print_message ERROR "Toolkit 삭제 함수를 찾을 수 없습니다."
            print_message INFO "nvidia-container-toolkit.sh의 삭제 함수명을 확인해주세요."
            return 1
        fi

        # 의존성 삭제 과정이므로 Toolkit의 추가 확인 생략
        DEPENDENCY_UNINSTALL=1 uninstall_nvidia_container_toolkit

        TOOLKIT_RESULT=$?

        if [ "$TOOLKIT_RESULT" -ne 0 ]; then
            print_message ERROR "NVIDIA Container Toolkit 삭제에 실패했습니다."
            print_message ERROR "Docker 삭제를 중단합니다."
            return 1
        fi

        echo ""
        print_message SUCCESS "NVIDIA Container Toolkit 삭제가 완료되었습니다."

    else

        # Toolkit이 없으면 Docker만 삭제 확인
        read -p "Docker를 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM

        if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
            print_message INFO "삭제를 취소했습니다."
            return 3
        fi

    fi

    # --------------------------------------------------------
    # Docker 삭제
    # --------------------------------------------------------
    echo ""
    print_message INFO "Docker를 삭제합니다."

    sudo apt-get purge -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    if [ $? -ne 0 ]; then
        print_message ERROR "Docker 삭제에 실패했습니다."
        return 1
    fi

    echo ""
    print_message INFO "불필요한 패키지를 정리합니다."

    sudo apt-get autoremove -y >/dev/null 2>&1

    # 삭제 확인
    if command -v docker >/dev/null 2>&1; then
        print_message ERROR "Docker 삭제를 확인할 수 없습니다."
        return 1
    fi

    # 설치 목록에서 제거
    remove_installed_software "docker"

    if [ $? -ne 0 ]; then
        print_message ERROR "설치 목록 삭제에 실패했습니다."
        return 1
    fi

    echo ""
    print_message SUCCESS "Docker 삭제가 완료되었습니다."

    return 0
}


# ============================================================
# 공통 모듈 함수
# SW_setting.sh에서 호출하는 함수명 유지
# ============================================================
install_software() {
    install_docker "$@"
}


uninstall_software() {
    uninstall_docker "$@"
}