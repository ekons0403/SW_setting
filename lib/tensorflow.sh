#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=true

# 서버 정보
get_system_info() {
    NVIDIA_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)
    CUDA_VERSION=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9]+\.[0-9]+' | head -n1)

    [ -z "$NVIDIA_DRIVER" ] && NVIDIA_DRIVER="확인 불가"
    [ -z "$CUDA_VERSION" ] && CUDA_VERSION="확인 불가"
}

# TensorFlow 설치 여부
get_installed_tensorflow() {
    INSTALLED_TENSORFLOW_VERSION=$(
        "${SELECTED_VE_PATH}/bin/python" -m pip show tensorflow 2>/dev/null |
        awk '/^Version:/{print $2}'
    )

    [ -n "$INSTALLED_TENSORFLOW_VERSION" ]
}

# Keras 설치 및 Backend 확인
get_installed_keras_backend() {
    local PYTHON="${SELECTED_VE_PATH}/bin/python"

    INSTALLED_KERAS_VERSION=$(
        "$PYTHON" -m pip show keras 2>/dev/null |
        awk '/^Version:/{print $2}'
    )

    KERAS_BACKEND=""

    [ -z "$INSTALLED_KERAS_VERSION" ] && return 1

    KERAS_BACKEND=$(
        "$PYTHON" -c "import keras; print(keras.config.backend())" 2>/dev/null
    )

    [ -n "$KERAS_BACKEND" ]
}

# 설치된 Keras를 설치 목록에 등록
register_installed_keras() {
    local PYTHON="${SELECTED_VE_PATH}/bin/python"
    local KERAS_VERSION
    local KERAS_BACKEND_VALUE
    local KERAS_META

    KERAS_VERSION=$(
        "$PYTHON" -m pip show keras 2>/dev/null |
        awk '/^Version:/{print $2}'
    )

    if [ -z "$KERAS_VERSION" ]; then
        print_message WARNING "Keras가 설치되어 있지 않아 별도 등록하지 않습니다."
        return 0
    fi

    KERAS_BACKEND_VALUE=$(
        "$PYTHON" -c "import keras; print(keras.config.backend())" 2>/dev/null
    )
    [ -z "$KERAS_BACKEND_VALUE" ] && KERAS_BACKEND_VALUE="unknown"

    KERAS_META="version=${KERAS_VERSION};backend=${KERAS_BACKEND_VALUE};package=keras"

    if ! add_installed_software \
        "keras" "conda" "${SELECTED_VE}" \
        "${SELECTED_PYTHON_VERSION}" "${KERAS_META}"; then
        print_message ERROR "Keras 설치 목록 등록에 실패했습니다."
        return 1
    fi

    print_message SUCCESS "Keras ${KERAS_VERSION} 설치 목록 등록이 완료되었습니다."
    return 0
}

# 추천 버전
recommend_tensorflow() {
    TENSORFLOW_VERSION=""
    TENSORFLOW_CUDA=""
    CUDNN_VERSION=""

    case "$CUDA_VERSION" in
        13.*|12.8*|12.7*|12.6*|12.5*)
            TENSORFLOW_VERSION="2.21.0"
            TENSORFLOW_CUDA="12.5"
            CUDNN_VERSION="9.3"
            ;;
        12.4*|12.3*)
            TENSORFLOW_VERSION="2.17.0"
            TENSORFLOW_CUDA="12.3"
            CUDNN_VERSION="8.9"
            ;;
        12.2*)
            TENSORFLOW_VERSION="2.15.0"
            TENSORFLOW_CUDA="12.2"
            CUDNN_VERSION="8.9"
            ;;
        11.8*)
            TENSORFLOW_VERSION="2.14.0"
            TENSORFLOW_CUDA="11.8"
            CUDNN_VERSION="8.7"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

# TensorFlow GPU 확인
verify_installation() {
    local PYTHON="${SELECTED_VE_PATH}/bin/python"

    echo ""
    print_message INFO "TensorFlow GPU 작동 여부를 확인합니다."

    NVIDIA_LIB_DIR=$(
        "$PYTHON" -c "
import site, os, glob
base = site.getsitepackages()[0]
print(':'.join(glob.glob(os.path.join(base, 'nvidia', '*', 'lib'))))
" 2>/dev/null
    )

    if [ -n "$NVIDIA_LIB_DIR" ]; then
        export LD_LIBRARY_PATH="${NVIDIA_LIB_DIR}:${LD_LIBRARY_PATH}"
        echo "[INFO] NVIDIA CUDA Libraries:"
        echo "$NVIDIA_LIB_DIR" | tr ':' '\n'
    else
        print_message WARNING "NVIDIA CUDA 라이브러리를 찾을 수 없습니다."
    fi

    "$PYTHON" - <<'PY'
import sys
import tensorflow as tf

print("Python:", sys.executable)
print("TensorFlow:", tf.__version__)

gpus = tf.config.list_physical_devices("GPU")
print("GPU Count:", len(gpus))

for i, gpu in enumerate(gpus):
    print(f"GPU {i}: {gpu.name}")

if not gpus:
    sys.exit(1)
PY

    if [ $? -ne 0 ]; then
        print_message ERROR "TensorFlow GPU 작동 확인에 실패했습니다."
        return 1
    fi

    print_message SUCCESS "TensorFlow GPU 작동이 확인되었습니다."
    return 0
}

# TensorFlow 설치
install_software() {
    echo ""
    echo "========================================"
    echo "        TensorFlow Installation"
    echo "========================================"
    echo ""

    if [ -z "$SELECTED_VE_PATH" ] || [ ! -x "${SELECTED_VE_PATH}/bin/python" ]; then
        print_message ERROR "선택된 가상환경을 확인할 수 없습니다."
        return 1
    fi

    if get_installed_tensorflow; then
        echo "Installed   : TensorFlow"
        echo "Version     : ${INSTALLED_TENSORFLOW_VERSION}"
        echo "Environment : ${SELECTED_VE}"
        print_message INFO "TensorFlow가 이미 설치되어 있습니다."

        # TensorFlow가 이미 설치된 경우에도 Keras 로그 누락 여부를 보정
        register_installed_keras || return 1
        return 2
    fi

    get_system_info

    echo "NVIDIA Driver : ${NVIDIA_DRIVER}"
    echo "CUDA          : ${CUDA_VERSION}"
    echo "Python        : ${SELECTED_PYTHON_VERSION}"
    echo "Environment   : ${SELECTED_VE}"
    echo ""

    if recommend_tensorflow; then
        RECOMMEND_AVAILABLE=true

        echo "========================================"
        echo "        Recommended TensorFlow"
        echo "========================================"
        echo ""
        echo "TensorFlow Version : ${TENSORFLOW_VERSION}"
        echo "CUDA Build         : ${TENSORFLOW_CUDA}"
        echo "cuDNN              : ${CUDNN_VERSION}"
        echo ""
        echo "1. 추천 버전으로 설치"
        echo "2. 직접 입력"
    else
        RECOMMEND_AVAILABLE=false
        print_message WARNING "현재 CUDA 버전에 맞는 추천 버전을 찾을 수 없습니다."
        echo ""
        echo "1. 직접 입력"
    fi

    echo ""
    read -p "TensorFlow 설치 방법을 선택하세요 : " TF_SELECT

    if [ "$RECOMMEND_AVAILABLE" = "true" ]; then
        case "$TF_SELECT" in
            1)
                ;;
            2)
                read -p "TensorFlow 버전 : " TENSORFLOW_VERSION
                ;;
            *)
                print_message ERROR "올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    else
        case "$TF_SELECT" in
            1)
                read -p "TensorFlow 버전 : " TENSORFLOW_VERSION
                ;;
            *)
                print_message ERROR "올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    fi

    if [ -z "$TENSORFLOW_VERSION" ]; then
        print_message ERROR "TensorFlow 버전을 입력해주세요."
        return 1
    fi

    echo ""
    echo "========================================"
    echo "        TensorFlow Installation Info"
    echo "========================================"
    echo ""
    echo "TensorFlow Version : ${TENSORFLOW_VERSION}"
    echo "Conda Environment : ${SELECTED_VE}"
    echo "Python Version    : ${SELECTED_PYTHON_VERSION}"
    echo ""

    read -p "위 설정으로 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM

    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi

    echo ""
    print_message INFO "TensorFlow 설치 시 Keras가 의존성 패키지로 함께 설치됩니다."
    print_message INFO "TensorFlow 설치를 시작합니다."

    "${SELECTED_VE_PATH}/bin/python" -m pip install --upgrade "tensorflow[and-cuda]==${TENSORFLOW_VERSION}"

    if [ $? -ne 0 ]; then
        print_message ERROR "TensorFlow 설치에 실패했습니다."
        return 1
    fi

    if ! get_installed_tensorflow; then
        print_message ERROR "TensorFlow 설치 확인에 실패했습니다."
        return 1
    fi

    echo ""
    echo "TensorFlow Version : ${INSTALLED_TENSORFLOW_VERSION}"

    if ! verify_installation; then
        print_message WARNING "TensorFlow는 설치되었지만 GPU 확인에 실패했습니다."
        return 1
    fi

    SW_META="tensorflow=${INSTALLED_TENSORFLOW_VERSION};cuda=${CUDA_VERSION}"

    add_installed_software \
        "tensorflow" "conda" "${SELECTED_VE}" \
        "${SELECTED_PYTHON_VERSION}" "${SW_META}"

    if [ $? -ne 0 ]; then
        print_message ERROR "TensorFlow 설치 목록 등록에 실패했습니다."
        return 1
    fi

    # TensorFlow 설치 과정에서 함께 설치된 Keras도 별도 로그 등록
    if ! register_installed_keras; then
        return 1
    fi

    echo ""
    print_message SUCCESS "TensorFlow 및 Keras 설치 목록 등록이 완료되었습니다."
    return 0
}

# TensorFlow 삭제
uninstall_software() {
    local PYTHON="${SELECTED_VE_PATH}/bin/python"
    local REMOVE_KERAS=false

    echo ""
    echo "========================================"
    echo "        TensorFlow Uninstallation"
    echo "========================================"
    echo ""

    if [ -z "$SELECTED_VE_PATH" ] || [ ! -x "$PYTHON" ]; then
        print_message ERROR "선택된 가상환경을 확인할 수 없습니다."
        return 1
    fi

    if ! get_installed_tensorflow; then
        print_message INFO "선택된 가상환경에 TensorFlow가 설치되어 있지 않습니다."
        remove_installed_software "tensorflow" "${SELECTED_VE}"
        return 2
    fi

    echo "Installed   : TensorFlow"
    echo "Version     : ${INSTALLED_TENSORFLOW_VERSION}"
    echo "Environment : ${SELECTED_VE}"
    echo ""

    # Keras Backend 확인
    if get_installed_keras_backend; then
        if [ "$KERAS_BACKEND" = "tensorflow" ]; then
            echo "Installed   : Keras"
            echo "Version     : ${INSTALLED_KERAS_VERSION}"
            echo "Backend     : TensorFlow"
            echo ""

            print_message WARNING "Keras가 TensorFlow Backend를 사용하고 있습니다."
            read -p "TensorFlow와 Keras를 함께 삭제하시겠습니까? (y/n) : " KERAS_CONFIRM

            if [[ "$KERAS_CONFIRM" =~ ^[Yy]$ ]]; then
                REMOVE_KERAS=true
            else
                print_message INFO "Keras는 유지하고 TensorFlow만 삭제합니다."
            fi
        else
            print_message INFO "Keras Backend가 ${KERAS_BACKEND}이므로 Keras는 유지합니다."
        fi
    elif [ -n "$INSTALLED_KERAS_VERSION" ]; then
        print_message WARNING "Keras Backend를 확인할 수 없어 Keras는 유지합니다."
    fi

    echo ""
    read -p "TensorFlow를 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM

    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
        print_message INFO "삭제를 취소했습니다."
        return 3
    fi

    echo ""

    # Keras 삭제
    if [ "$REMOVE_KERAS" = "true" ]; then
        print_message INFO "Keras를 삭제합니다."

        if ! "$PYTHON" -m pip uninstall -y keras; then
            print_message ERROR "Keras 삭제 명령 실행에 실패했습니다."
            return 1
        fi

        if "$PYTHON" -m pip show keras >/dev/null 2>&1; then
            print_message ERROR "Keras가 아직 설치되어 있습니다."
            return 1
        fi

        if ! remove_installed_software "keras" "${SELECTED_VE}"; then
            print_message ERROR "Keras 설치 목록 삭제에 실패했습니다."
            return 1
        fi

        print_message SUCCESS "Keras 삭제가 완료되었습니다."
    fi

    # TensorFlow 삭제
    print_message INFO "TensorFlow를 삭제합니다."

    if ! "$PYTHON" -m pip uninstall -y tensorflow; then
        print_message ERROR "TensorFlow 삭제 명령 실행에 실패했습니다."
        return 1
    fi

    if "$PYTHON" -m pip show tensorflow >/dev/null 2>&1; then
        print_message ERROR "TensorFlow가 아직 설치되어 있습니다."
        return 1
    fi

    if ! remove_installed_software "tensorflow" "${SELECTED_VE}"; then
        print_message ERROR "TensorFlow 설치 목록 삭제에 실패했습니다."
        return 1
    fi

    echo ""
    print_message SUCCESS "TensorFlow 삭제가 완료되었습니다."
    return 0
}
