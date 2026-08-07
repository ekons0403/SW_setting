#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=false
# NVIDIA Container Toolkit 설치
install_software() {
    # docker 설치 여부
    if ! command -v docker>/dev/null 2>&1;then
        echo "[ERROR] Docker가 설치되어 있지 않습니다."
        echo "[ERROR] NVIDIA Container Toolkit 설치 전에 Docker를 먼저 설치해주세요."
        return 1
    fi
    echo ""
    echo "========================================"
    echo "   NVIDIA Container Toolkit Installation"
    echo "========================================"
    echo ""
    if command -v nvidia-ctk > /dev/null 2>&1; then
        echo "[INFO] NVIDIA Container Toolkit이 이미 설치되어 있습니다."
        echo "[INFO] 설치를 건너뜁니다."
        add_installed_software "nvidia-container-toolkit" "system"
        return 0
    fi
    echo "[INFO] NVIDIA Container Toolkit 저장소를 등록합니다."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] NVIDIA Container Toolkit 저장소 등록에 실패했습니다."
        return 1
    fi
    echo "[SUCCESS] 저장소 등록이 완료되었습니다."
    echo ""
    echo "[INFO] 패키지 목록을 업데이트합니다."
    sudo apt-get update
    if [ $? -ne 0 ]; then
        echo "[ERROR] 패키지 목록 업데이트에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[INFO] NVIDIA Container Toolkit을 설치합니다."
    sudo apt-get install -y nvidia-container-toolkit
    if [ $? -ne 0 ]; then
        echo "[ERROR] NVIDIA Container Toolkit 설치에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[INFO] Docker에 NVIDIA Container Runtime을 설정합니다."
    sudo nvidia-ctk runtime configure --runtime=docker
    if [ $? -ne 0 ]; then
        echo "[ERROR] NVIDIA Container Runtime 설정에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[INFO] Docker 서비스를 재시작합니다."
    sudo systemctl restart docker
    if [ $? -ne 0 ]; then
        echo "[ERROR] Docker 서비스 재시작에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] NVIDIA Container Toolkit 설치가 완료되었습니다."
    echo ""
    echo "[INFO] NVIDIA Container Toolkit Version:"
    nvidia-ctk --version
    add_installed_software "nvidia-container-toolkit" "system"
    if [ $? -ne 0 ]; then
        echo "[ERROR] 설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] NVIDIA Container Toolkit 설치 및 등록이 완료되었습니다."
    return 0
}

# NVIDIA Container Toolkit 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "  NVIDIA Container Toolkit Uninstallation"
    echo "========================================"
    echo ""
    if ! command -v nvidia-ctk > /dev/null 2>&1; then
        echo "[INFO] NVIDIA Container Toolkit이 설치되어 있지 않습니다."
        return 0
    fi
    echo "[INFO] NVIDIA Container Toolkit을 삭제합니다."
    sudo apt-get purge -y nvidia-container-toolkit
    if [ $? -ne 0 ]; then
        echo "[ERROR] NVIDIA Container Toolkit 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[INFO] 불필요한 패키지를 정리합니다."
    sudo apt-get autoremove -y
    echo ""
    echo "[SUCCESS] NVIDIA Container Toolkit 삭제가 완료되었습니다."
    remove_installed_software "nvidia-container-toolkit"
    return 0
}