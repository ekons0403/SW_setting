#!/bin/bash
# ========================================
# Docker 설정
# ========================================
REQUIRE_VENV=false

# ========================================
# Docker 설치
# ========================================
install_software() {
    echo ""
    echo "========================================"
    echo "        Docker Installation"
    echo "========================================"
    echo ""
    # ========================================
    # Docker 설치 여부 확인
    # ========================================
    if command -v docker > /dev/null 2>&1; then
        echo "[INFO] Docker가 이미 설치되어 있습니다."
        echo "[INFO] 설치를 건너뜁니다."
        # 이미 설치된 SW도 목록에 등록
        add_installed_software "docker" "system"
        return 0
    fi

    # ========================================
    # Docker 설치
    # ========================================
    echo "[INFO] Docker를 설치합니다."
    echo ""
    curl -fsSL https://get.docker.com/ | sudo sh
    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] Docker 설치에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] Docker 설치가 완료되었습니다."

    # ========================================
    # 현재 사용자 Docker 그룹 추가
    # ========================================
    echo ""
    echo "[INFO] 현재 사용자를 Docker 그룹에 추가합니다."
    sudo usermod -aG docker "$USER"
    if [ $? -ne 0 ]; then
        echo "[ERROR] Docker 그룹 추가에 실패했습니다."
        return 1
    fi
    echo "[SUCCESS] Docker 그룹 추가가 완료되었습니다."

    # ========================================
    # Docker 서비스 확인
    # ========================================
    echo ""
    echo "[INFO] Docker 서비스 상태를 확인합니다."
    if systemctl is-active --quiet docker; then
        echo "[SUCCESS] Docker 서비스가 정상적으로 실행 중입니다."
    else
        echo "[WARNING] Docker 서비스가 실행 중이지 않습니다."
        echo "[INFO] Docker 서비스를 시작합니다."
        sudo systemctl start docker
    fi

    # ========================================
    # 설치 완료
    # ========================================
    echo ""
    echo "========================================"
    echo "     Docker 설치 완료"
    echo "========================================"
    echo ""
    echo "[INFO] Docker Version:"
    docker --version
    echo ""
    echo "[INFO] Docker를 현재 사용자 권한으로 사용하려면"
    echo "[INFO] 로그아웃 후 다시 로그인하거나 재부팅해야 합니다."

    # ========================================
    # 설치 목록 등록
    # ========================================
    add_installed_software "docker" "system"
    return 0
}

# ========================================
# Docker 삭제
# ========================================
uninstall_software() {

    echo ""
    echo "========================================"
    echo "        Docker Uninstallation"
    echo "========================================"
    echo ""

    # Docker 설치 여부 확인
    if ! command -v docker > /dev/null 2>&1; then
        echo "[INFO] Docker가 설치되어 있지 않습니다."
        return 0
    fi

    echo "[INFO] Docker를 삭제합니다."
    echo ""

    # Docker 관련 패키지 삭제
    sudo apt-get purge -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] Docker 삭제에 실패했습니다."
        return 1
    fi

    # 사용하지 않는 의존성 제거
    echo ""
    echo "[INFO] 불필요한 패키지를 정리합니다."

    sudo apt-get autoremove -y

    echo ""
    echo "[SUCCESS] Docker 삭제가 완료되었습니다."

    return 0
}