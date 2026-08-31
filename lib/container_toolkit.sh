#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=false
# NVIDIA Container Toolkit 설치
install_software() {
    echo ""
    echo "========================================"
    echo "  NVIDIA Container Toolkit Installation"
    echo "========================================"
    echo ""
    if ! command -v docker>/dev/null 2>&1;then
        print_message ERROR "Docker가 설치되어 있지 않습니다. Docker를 먼저 설치해주세요."
        return 1
    fi
    if command -v nvidia-ctk>/dev/null 2>&1;then
        NVIDIA_CTK_VERSION=$(nvidia-ctk --version 2>/dev/null|grep -oP '[0-9]+\.[0-9]+\.[0-9]+'|head -n1)
        echo "Installed : NVIDIA Container Toolkit"
        echo "Version   : ${NVIDIA_CTK_VERSION:-확인 불가}"
        print_message INFO "NVIDIA Container Toolkit이 이미 설치되어 있습니다."
        add_installed_software "nvidia-container-toolkit" "system"
        return 2
    fi
    echo "NVIDIA Container Toolkit : 설치되지 않음"
    echo ""
    read -p "NVIDIA Container Toolkit을 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "NVIDIA Container Toolkit 설치를 시작합니다."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey|sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg>/dev/null 2>&1||{
        print_message ERROR "NVIDIA Container Toolkit 저장소 등록에 실패했습니다."
        return 1
    }
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list|sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g'|sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list>/dev/null||{
        print_message ERROR "NVIDIA Container Toolkit 저장소 등록에 실패했습니다."
        return 1
    }
    sudo apt-get update>/dev/null 2>&1||{
        print_message ERROR "패키지 목록 업데이트에 실패했습니다."
        return 1
    }
    sudo apt-get install -y nvidia-container-toolkit>/dev/null 2>&1||{
        print_message ERROR "NVIDIA Container Toolkit 설치에 실패했습니다."
        return 1
    }
    sudo nvidia-ctk runtime configure --runtime=docker>/dev/null 2>&1||{
        print_message ERROR "NVIDIA Container Runtime 설정에 실패했습니다."
        return 1
    }
    sudo systemctl restart docker>/dev/null 2>&1||{
        print_message ERROR "Docker 서비스 재시작에 실패했습니다."
        return 1
    }
    if ! command -v nvidia-ctk>/dev/null 2>&1;then
        print_message ERROR "NVIDIA Container Toolkit 설치를 확인할 수 없습니다."
        return 1
    fi
    NVIDIA_CTK_VERSION=$(nvidia-ctk --version 2>/dev/null|grep -oP '[0-9]+\.[0-9]+\.[0-9]+'|head -n1)
    echo ""
    echo "NVIDIA Container Toolkit : ${NVIDIA_CTK_VERSION:-확인 불가}"
    add_installed_software "nvidia-container-toolkit" "system"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi
    return 0
}
# NVIDIA Container Toolkit 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "  NVIDIA Container Toolkit Uninstallation"
    echo "========================================"
    echo ""
    if ! command -v nvidia-ctk>/dev/null 2>&1;then
        print_message INFO "NVIDIA Container Toolkit이 설치되어 있지 않습니다."
        return 0
    fi
    NVIDIA_CTK_VERSION=$(nvidia-ctk --version 2>/dev/null|grep -oP '[0-9]+\.[0-9]+\.[0-9]+'|head -n1)
    echo "Installed : NVIDIA Container Toolkit"
    echo "Version   : ${NVIDIA_CTK_VERSION:-확인 불가}"
    echo ""
    read -p "삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "삭제를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "NVIDIA Container Toolkit을 삭제합니다."
    sudo apt-get purge -y nvidia-container-toolkit>/dev/null 2>&1||{
        print_message ERROR "NVIDIA Container Toolkit 삭제에 실패했습니다."
        return 1
    }
    sudo apt-get autoremove -y>/dev/null 2>&1
    remove_installed_software "nvidia-container-toolkit"
    return 0
}