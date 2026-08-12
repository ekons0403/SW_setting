#!/bin/bash
REQUIRE_VENV=true
get_system_info() {
    NVIDIA_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null|head -n1)
    CUDA_VERSION=$(nvcc --version 2>/dev/null|grep -oP 'release \K[0-9]+.[0-9]+'|head -n1)
    [ -z "$NVIDIA_DRIVER" ]&&NVIDIA_DRIVER="확인 불가"
    [ -z "$CUDA_VERSION" ]&&CUDA_VERSION="확인 불가"
}
install_software() {
    get_system_info
    echo ""
    echo "========================================"
    echo "        TensorFlow Installation Info"
    echo "========================================"
    echo ""
    echo "TensorFlow Version : 최신 버전"
    echo "Package            : tensorflow[and-cuda]"
    echo "Conda Environment  : ${SELECTED_VE}"
    echo "Python Version     : ${SELECTED_PYTHON_VERSION}"
    echo ""
    read -p "위 설정으로 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "[INFO] 설치를 취소했습니다."
    return 0
    fi
    echo ""
    echo "[INFO] TensorFlow 설치를 시작합니다."
    echo "[INFO] 설치 패키지: tensorflow[and-cuda]"
    echo ""
    "${SELECTED_VE_PATH}/bin/python" -m pip install "tensorflow[and-cuda]"
    if [ $? -ne 0 ]; then
    echo ""
    return 1
    fi
    echo ""
    echo "[SUCCESS] TensorFlow 설치가 완료되었습니다."
    TENSORFLOW_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null)
    if [ -z "$TENSORFLOW_VERSION" ]; then
    echo "[ERROR] TensorFlow 설치 확인에 실패했습니다."
    return 1
    fi
    echo ""
    echo "[INFO] 설치된 TensorFlow 버전: ${TENSORFLOW_VERSION}"
TF_INFO=$("${SELECTED_VE_PATH}/bin/python" - <<'PY'
import tensorflow as tf
print(f"TensorFlow: {tf.__version__}")
print(f"GPU Available: {len(tf.config.list_physical_devices('GPU')) > 0}")
print(f"GPU Count: {len(tf.config.list_physical_devices('GPU'))}")
for i, gpu in enumerate(tf.config.list_physical_devices('GPU')): print(f"GPU {i}: {gpu.name}")
PY
)
    echo "$TF_INFO"
    if echo "$TF_INFO" | grep -q "GPU Available: True"; then
    echo "[SUCCESS] TensorFlow에서 GPU 인식이 확인되었습니다."
    else
    echo "[WARNING] TensorFlow는 설치되었지만 GPU를 인식하지 못했습니다."
    fi
    SW_META="tensorflow=${TENSORFLOW_VERSION}"
    add_installed_software "tensorflow" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "${SW_META}"
    if [ $? -ne 0 ]; then
    echo "[ERROR] 설치 목록 등록에 실패했습니다."
    return 1
    fi
    echo ""
    echo "[SUCCESS] TensorFlow 설치 및 등록이 완료되었습니다."
    return 0
}
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        TensorFlow Uninstallation"
    echo "========================================"
    echo ""
    echo "[INFO] 선택된 가상환경: ${SELECTED_VE}"
    echo "[INFO] Python 버전: ${SELECTED_PYTHON_VERSION}"
    echo "[INFO] 경로: ${SELECTED_VE_PATH}"
    echo ""
    if ! "${SELECTED_VE_PATH}/bin/python" -c "import tensorflow" 2>/dev/null; then
    echo "[INFO] 해당 가상환경에 TensorFlow가 설치되어 있지 않습니다."
    return 0
    fi
    TENSORFLOW_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null)
    echo "[INFO] 설치된 TensorFlow: ${TENSORFLOW_VERSION}"
    echo ""
    read -p "TensorFlow를 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "[INFO] 삭제를 취소했습니다."
    return 0
    fi
    echo ""
    echo "[INFO] TensorFlow를 삭제합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y tensorflow
    if [ $? -ne 0 ]; then
    echo "[ERROR] TensorFlow 삭제에 실패했습니다."
    return 1
    fi
    echo ""
    echo "[SUCCESS] TensorFlow 삭제가 완료되었습니다."
    return 0
}