#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=false
# Docker 설치
install_software() {
    echo ""
    echo "========================================"
    echo "        Docker Installation"
    echo "========================================"
    echo ""
    if command -v docker>/dev/null 2>&1;then
        DOCKER_VERSION=$(docker --version 2>/dev/null|grep -oP '[0-9]+\.[0-9]+\.[0-9]+'|head -n1)
        echo "Installed : Docker"
        echo "Version   : ${DOCKER_VERSION:-확인 불가}"
        print_message INFO "Docker가 이미 설치되어 있습니다."
        add_installed_software "docker" "system"
        return 2
    fi
    echo "Docker : 설치되지 않음"
    echo ""
    read -p "Docker를 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "Docker 설치를 시작합니다."
    curl -fsSL https://get.docker.com/|sudo sh
    if [ $? -ne 0 ];then
        print_message ERROR "Docker 설치에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "현재 사용자를 Docker 그룹에 추가합니다."
    sudo usermod -aG docker "$USER"
    if [ $? -ne 0 ];then
        print_message ERROR "Docker 그룹 추가에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "Docker 서비스 상태를 확인합니다."
    if systemctl is-active --quiet docker;then
        print_message SUCCESS "Docker 서비스가 정상적으로 실행 중입니다."
    else
        print_message INFO "Docker 서비스를 시작합니다."
        sudo systemctl start docker
        if [ $? -ne 0 ];then
            print_message ERROR "Docker 서비스 시작에 실패했습니다."
            return 1
        fi
    fi
    if ! command -v docker>/dev/null 2>&1;then
        print_message ERROR "Docker 설치를 확인할 수 없습니다."
        return 1
    fi
    DOCKER_VERSION=$(docker --version 2>/dev/null|grep -oP '[0-9]+\.[0-9]+\.[0-9]+'|head -n1)
    echo ""
    echo "Docker : ${DOCKER_VERSION:-확인 불가}"
    add_installed_software "docker" "system"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "Docker 그룹 적용을 위해 로그아웃 후 다시 로그인하거나 재부팅해주세요."
    return 0
}
# Docker 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        Docker Uninstallation"
    echo "========================================"
    echo ""
    if ! command -v docker>/dev/null 2>&1;then
        print_message INFO "Docker가 설치되어 있지 않습니다."
        return 2
    fi
    DOCKER_VERSION=$(docker --version 2>/dev/null|grep -oP '[0-9]+\.[0-9]+\.[0-9]+'|head -n1)
    echo "Installed : Docker"
    echo "Version   : ${DOCKER_VERSION:-확인 불가}"
    echo ""
    read -p "삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "삭제를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "Docker를 삭제합니다."
    sudo apt-get purge -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    if [ $? -ne 0 ];then
        print_message ERROR "Docker 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "불필요한 패키지를 정리합니다."
    sudo apt-get autoremove -y>/dev/null 2>&1
    if command -v docker>/dev/null 2>&1;then
        print_message ERROR "Docker 삭제를 확인할 수 없습니다."
        return 1
    fi
    remove_installed_software "docker"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    return 0
}