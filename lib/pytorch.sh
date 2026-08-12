#!/bin/bash
#가상환경 여부
REQUIRE_VENV=true
#서버 정보
get_system_info() {
    NVIDIA_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null|head -n1)
    CUDA_VERSION=$(nvcc --version 2>/dev/null|grep -oP 'release \K[0-9]+\.[0-9]+'|head -n1)
    [ -z "$NVIDIA_DRIVER" ]&&NVIDIA_DRIVER="확인 불가"
    [ -z "$CUDA_VERSION" ]&&CUDA_VERSION="확인 불가"
}
# 추천 버전
recommend_pytorch() {
    PYTORCH_VERSION=""
    TORCHVISION_VERSION=""
    CUDA_WHEEL=""
    case "$CUDA_VERSION" in
        13.2*)
            PYTORCH_VERSION="2.12.1"
            TORCHVISION_VERSION="0.27.1"
            CUDA_WHEEL="cu132"
            ;;
        12.8*)
            PYTORCH_VERSION="2.8.0"
            TORCHVISION_VERSION="0.23.0"
            CUDA_WHEEL="cu128"
            ;;
        12.6*)
            PYTORCH_VERSION="2.7.1"
            TORCHVISION_VERSION="0.22.1"
            CUDA_WHEEL="cu126"
            ;;
        *)
            return 1
            ;;
    esac
}
# pytorch 설치
install_software() {
    get_system_info
    echo ""
    echo "========================================"
    echo "        System Information"
    echo "========================================"
    echo ""
    echo "NVIDIA Driver : ${NVIDIA_DRIVER}"
    echo "CUDA          : ${CUDA_VERSION}"
    echo "Python        : ${SELECTED_PYTHON_VERSION}"
    echo ""
    if recommend_pytorch;then
        RECOMMEND_AVAILABLE=true
        echo "========================================"
        echo "        Recommended PyTorch"
        echo "========================================"
        echo ""
        echo "PyTorch Version     : ${PYTORCH_VERSION}"
        echo "torchvision Version : ${TORCHVISION_VERSION}"
        echo "torchaudio Version  : ${PYTORCH_VERSION}"
        echo "CUDA Wheel          : ${CUDA_WHEEL}"
        echo ""
        echo "1. 추천 버전으로 설치"
        echo "2. 직접 입력"
    else
        RECOMMEND_AVAILABLE=false
        echo "[WARNING] 현재 CUDA 버전에 맞는 추천 조합을 찾을 수 없습니다."
        echo ""
        echo "1. 직접 입력"
    fi
    echo ""
    read -p "PyTorch 설치 방법을 선택하세요 : " PYTORCH_SELECT
    if [[ "$RECOMMEND_AVAILABLE" == "true" ]];then
        case "$PYTORCH_SELECT" in
            1)
                ;;
            2)
                read -p "PyTorch 버전 : " PYTORCH_VERSION
                read -p "torchvision 버전 : " TORCHVISION_VERSION
                read -p "CUDA Wheel : " CUDA_WHEEL
                ;;
            *)
                echo "[ERROR] 올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    else
        case "$PYTORCH_SELECT" in
            1)
                read -p "PyTorch 버전 : " PYTORCH_VERSION
                read -p "torchvision 버전 : " TORCHVISION_VERSION
                read -p "CUDA Wheel : " CUDA_WHEEL
                ;;
            *)
                echo "[ERROR] 올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    fi
    TORCH_INDEX="https://download.pytorch.org/whl/${CUDA_WHEEL}"
    echo ""
    echo "========================================"
    echo "        PyTorch Installation Info"
    echo "========================================"
    echo ""
    echo "PyTorch Version     : ${PYTORCH_VERSION}"
    echo "torchvision Version : ${TORCHVISION_VERSION}"
    echo "torchaudio Version  : ${PYTORCH_VERSION}"
    echo "CUDA Wheel          : ${CUDA_WHEEL}"
    echo "Conda Environment   : ${SELECTED_VE}"
    echo "Python Version      : ${SELECTED_PYTHON_VERSION}"
    echo ""
    read -p "위 설정으로 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[INFO] 설치를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] PyTorch 설치를 시작합니다."
    echo "[INFO] 설치 URL: ${TORCH_INDEX}"
    echo ""
    "${SELECTED_VE_PATH}/bin/python" -m pip install "torch==${PYTORCH_VERSION}" "torchvision==${TORCHVISION_VERSION}" "torchaudio==${PYTORCH_VERSION}" --index-url "${TORCH_INDEX}"
    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] PyTorch 설치에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] PyTorch 설치가 완료되었습니다."
    INSTALLED_PYTORCH_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import torch; print(torch.__version__)")
    INSTALLED_TORCHVISION_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import torchvision; print(torchvision.__version__)")
    INSTALLED_CUDA_WHEEL=$("${SELECTED_VE_PATH}/bin/python" -c "import torch; print(torch.version.cuda)")
    echo ""
    echo "[INFO] 설치 버전을 확인합니다."
TORCH_INFO=$("${SELECTED_VE_PATH}/bin/python" - <<'PY'
import torch

print(f"PyTorch: {torch.__version__}")
print(f"PyTorch CUDA: {torch.version.cuda}")
print(f"CUDA Available: {torch.cuda.is_available()}")
print(f"GPU Count: {torch.cuda.device_count()}")

for i in range(torch.cuda.device_count()):
    print(f"GPU {i}: {torch.cuda.get_device_name(i)}")
PY
)
    echo "$TORCH_INFO"
    if echo "$TORCH_INFO" | grep -q "CUDA Available: True"; then
        echo "[SUCCESS] CUDA 및 GPU 인식이 확인되었습니다."
    else
        echo "[WARNING] PyTorch는 설치되었지만 CUDA GPU를 인식하지 못했습니다."
    fi
    SW_META="torch=${PYTORCH_VERSION};torchvision=${TORCHVISION_VERSION};cuda=${CUDA_WHEEL}"
    add_installed_software "pytorch" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "${SW_META}"
    if [ $? -ne 0 ]; then
        echo "[ERROR] 설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] PyTorch 설치 및 등록이 완료되었습니다."
    return 0
}

uninstall_software() {
    echo ""
    echo "========================================"
    echo "        PyTorch Uninstallation"
    echo "========================================"
    echo ""
    echo "[INFO] 선택된 가상환경: ${SELECTED_VE}"
    echo "[INFO] Python 버전: ${SELECTED_PYTHON_VERSION}"
    echo "[INFO] 경로: ${SELECTED_VE_PATH}"
    echo ""
    if ! "${SELECTED_VE_PATH}/bin/python" -c "import torch" 2>/dev/null; then
        echo "[INFO] 해당 가상환경에 PyTorch가 설치되어 있지 않습니다."
        return 0
    fi
    TORCH_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import torch; print(torch.__version__)" 2>/dev/null)
    TORCHVISION_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import torchvision; print(torchvision.__version__)" 2>/dev/null)
    echo "[INFO] 설치된 PyTorch: ${TORCH_VERSION}"
    echo "[INFO] 설치된 torchvision: ${TORCHVISION_VERSION}"
    echo ""
    read -p "PyTorch와 torchvision을 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[INFO] 삭제를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] PyTorch를 삭제합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y torch torchvision torchaudio
    if [ $? -ne 0 ]; then
        echo "[ERROR] PyTorch 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] PyTorch 삭제가 완료되었습니다."
    return 0
}