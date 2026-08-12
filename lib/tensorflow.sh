#!/bin/bash
REQUIRE_VENV=true
get_system_info() {
    NVIDIA_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)
    CUDA_VERSION=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9]+\.[0-9]+' | head -n1)
    [ -z "$NVIDIA_DRIVER" ] && NVIDIA_DRIVER="확인 불가"
    [ -z "$CUDA_VERSION" ] && CUDA_VERSION="확인 불가"
}
SW_NAME="tensorflow"
SW_DESCRIPTION="TensorFlow"
SW_CATEGORY="Machine Learning"
SW_INSTALL_TYPE="pip"
install_software() {
    read -p "계속하시겠습니까? [y/n]: " answer
    case "$answer" in
        y|Y)
            ;;
        *)
            echo "설치를 취소했습니다."
            return 0
            ;;
    esac
    echo "TensorFlow 설치 중..."
    "${SELECTED_VE_PATH}/bin/python" -m pip install --upgrade tensorflow
    if [ $? -ne 0 ]; then
        echo "TensorFlow 설치 실패"
        return 1
    fi
    TENSORFLOW_VERSION=$("${SELECTED_VE_PATH}/bin/python" -m pip show tensorflow | awk '/^Version:/{print $2}')
    if [ -z "$TENSORFLOW_VERSION" ]; then
        echo "TensorFlow 버전을 확인할 수 없습니다."
        return 1
    fi
    echo "TensorFlow 설치 완료: ${TENSORFLOW_VERSION}"
    verify_installation
    if [ $? -ne 0 ]; then
        return 1
    fi
    add_installed_software "tensorflow" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "tensorflow=${TENSORFLOW_VERSION}"
}
verify_installation() {
    echo "TensorFlow 작동 여부를 확인합니다."
    PYTHON="${SELECTED_VE_PATH}/bin/python"
    NVIDIA_LIB_DIR=$("$PYTHON" -c "import site, os, glob; base=site.getsitepackages()[0]; print(':'.join(glob.glob(os.path.join(base, 'nvidia', '*', 'lib'))))" 2>/dev/null)
    if [ -n "$NVIDIA_LIB_DIR" ]; then
        export LD_LIBRARY_PATH="$NVIDIA_LIB_DIR:$LD_LIBRARY_PATH"
        echo "[INFO] NVIDIA CUDA Libraries:"
        echo "$NVIDIA_LIB_DIR" | tr ':' '\n'
    else
        echo "[WARNING] NVIDIA CUDA library를 찾을 수 없습니다."
    fi
    "$PYTHON" -c "import sys; import tensorflow as tf; print('Python:', sys.executable); print('TensorFlow:', tf.__version__); gpus=tf.config.list_physical_devices('GPU'); print('GPU:', len(gpus)); exit(0 if gpus else 1)"
    if [ $? -eq 0 ]; then
        echo "TensorFlow GPU 작동 확인 완료"
    else
        echo "TensorFlow GPU 작동 확인 실패"
        return 1
    fi
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
    if ! "${SELECTED_VE_PATH}/bin/python" -m pip show tensorflow >/dev/null 2>&1; then
        echo "[INFO] 해당 가상환경에 TensorFlow가 설치되어 있지 않습니다."
        remove_installed_software "tensorflow" "${SELECTED_VE}"
        return 0
    fi
    TENSORFLOW_VERSION=$("${SELECTED_VE_PATH}/bin/python" -m pip show tensorflow | awk '/^Version:/{print $2}')
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
    remove_installed_software "tensorflow" "${SELECTED_VE}"
    echo ""
    echo "[SUCCESS] TensorFlow 삭제가 완료되었습니다."
    return 0
}