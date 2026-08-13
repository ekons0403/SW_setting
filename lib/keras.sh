#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=true
install_software() {
    echo ""
    echo "========================================"
    echo "          Keras Backend"
    echo "========================================"
    echo ""
    echo "Keras는 다음 Backend를 사용할 수 있습니다."
    echo ""
    echo "1. PyTorch"
    echo "2. TensorFlow"
    echo ""
    read -p "Keras Backend를 선택하세요 : " BACKEND_SELECT
    case "$BACKEND_SELECT" in
        1) KERAS_BACKEND="torch" BACKEND_PACKAGE="torch" BACKEND_NAME="PyTorch";;
        2) KERAS_BACKEND="tensorflow" BACKEND_PACKAGE="tensorflow" BACKEND_NAME="TensorFlow";;
        *)
            echo "[ERROR] 올바른 번호를 선택해주세요."
            return 1
            ;;
    esac
    echo ""
    echo "[INFO] 선택한 Backend : ${BACKEND_NAME}"
    echo "[INFO] Backend 확인 환경 : ${SELECTED_VE}"
    echo ""
    # Backend 설치 여부 확인
    if ! "${SELECTED_VE_PATH}/bin/python" -c "import ${BACKEND_PACKAGE}" 2>/dev/null; then
        echo "[ERROR] ${BACKEND_NAME}이(가) 선택한 가상환경에 설치되어 있지 않습니다."
        echo ""
        echo "현재 환경 : ${SELECTED_VE}"
        echo "필요한 패키지 : ${BACKEND_PACKAGE}"
        echo ""
        echo "[INFO] 먼저 ${BACKEND_NAME}을 설치한 후 Keras를 설치해주세요."
        return 1
    fi
    echo "[SUCCESS] ${BACKEND_NAME}이(가) 선택한 가상환경에 설치되어 있습니다."
    echo ""
    echo "========================================"
    echo "          Keras Installation"
    echo "========================================"
    echo ""
    echo "Python            : ${SELECTED_PYTHON_VERSION}"
    echo "Conda Environment : ${SELECTED_VE}"
    echo "Python Path       : ${SELECTED_VE_PATH}/bin/python"
    echo ""
    echo "[INFO] Keras 설치를 시작합니다."
    KERAS_BACKEND="${KERAS_BACKEND}" \
    "${SELECTED_VE_PATH}/bin/python" -m pip install --upgrade keras
    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] Keras 설치에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] Keras 설치가 완료되었습니다."
    echo ""
    echo "[INFO] Keras 및 ${BACKEND_NAME} Backend 인식 상태를 확인합니다."
    KERAS_INFO=$(
        KERAS_BACKEND="${KERAS_BACKEND}" \
        "${SELECTED_VE_PATH}/bin/python" - <<PY
import keras
print(f"Keras Backend : {keras.config.backend()}")
if "${KERAS_BACKEND}" == "torch":
    import torch
    print(f"PyTorch Version: {torch.__version__}")
    print(f"CUDA Available : {torch.cuda.is_available()}")
    print(f"GPU Count      : {torch.cuda.device_count()}")
    if torch.cuda.is_available():
        for i in range(torch.cuda.device_count()):
            print(f"GPU {i}          : {torch.cuda.get_device_name(i)}")
elif "${KERAS_BACKEND}" == "tensorflow":
    import tensorflow as tf
    print(f"TensorFlow Version: {tf.__version__}")
    print(f"GPU Count        : {len(tf.config.list_physical_devices('GPU'))}")
    for i, gpu in enumerate(tf.config.list_physical_devices('GPU')):
        print(f"GPU {i}            : {gpu.name}")
PY
    )
    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] Keras 또는 ${BACKEND_NAME} Backend 인식에 실패했습니다."
        return 1
    fi
    echo ""
    echo "$KERAS_INFO"
    KERAS_BACKEND_RESULT=$(echo "$KERAS_INFO" | grep "Keras Backend" | awk -F': ' '{print $2}')
    if [ "$KERAS_BACKEND_RESULT" = "$KERAS_BACKEND" ]; then
        echo ""
        echo "[SUCCESS] Keras ${BACKEND_NAME} Backend가 정상적으로 인식되었습니다."
    else
        echo ""
        echo "[ERROR] Keras ${BACKEND_NAME} Backend 인식에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[INFO] 설치 목록에 등록합니다."
    SW_META="backend=${KERAS_BACKEND}"
    add_installed_software \
        "keras" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "${SW_META}"
    if [ $? -ne 0 ]; then
        echo "[ERROR] 설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] Keras 설치 및 등록이 완료되었습니다."
    return 0
}

uninstall_software() {
    echo ""
    echo "========================================"
    echo "          Keras Uninstallation"
    echo "========================================"
    echo ""
    echo "Conda Environment : ${SELECTED_VE}"
    echo "Python Version    : ${SELECTED_PYTHON_VERSION}"
    echo ""
    read -p "Keras를 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[INFO] Keras 삭제를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] Keras 삭제를 시작합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y keras
    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] Keras 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] Keras 삭제가 완료되었습니다."
    return 0
}