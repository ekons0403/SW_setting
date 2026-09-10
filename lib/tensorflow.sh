버전#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=true
# 서버 정보
get_system_info() {
    NVIDIA_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null|head -n1)
    CUDA_VERSION=$(nvcc --version 2>/dev/null|grep -oP 'release \K[0-9]+\.[0-9]+'|head -n1)
    [ -z "$NVIDIA_DRIVER" ]&&NVIDIA_DRIVER="확인 불가"
    [ -z "$CUDA_VERSION" ]&&CUDA_VERSION="확인 불가"
}
# TensorFlow 설치 여부
get_installed_tensorflow() {
    INSTALLED_TENSORFLOW_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null)
    if [ -n "$INSTALLED_TENSORFLOW_VERSION" ];then
        return 0
    fi
    return 1
}
# 추천 버전
recommend_tensorflow() {
    TENSORFLOW_VERSION=""
    TENSORFLOW_CUDA=""
    TENSORFLOW_CUDNN=""
    TENSORFLOW_PYTHON=""

    case "$CUDA_VERSION" in
        13.*)
            TENSORFLOW_VERSION="2.21.0"
            TENSORFLOW_CUDA="12.5"
            TENSORFLOW_CUDNN="9.3"
            TENSORFLOW_PYTHON="3.10-3.13"
            ;;
        12.8*|12.7*|12.6*|12.5*)
            TENSORFLOW_VERSION="2.21.0"
            TENSORFLOW_CUDA="12.5"
            TENSORFLOW_CUDNN="9.3"
            TENSORFLOW_PYTHON="3.10-3.13"
            ;;
        12.4*|12.3*)
            TENSORFLOW_VERSION="2.17.0"
            TENSORFLOW_CUDA="12.3"
            TENSORFLOW_CUDNN="8.9"
            TENSORFLOW_PYTHON="3.9-3.12"
            ;;
        12.2*)
            TENSORFLOW_VERSION="2.15.0"
            TENSORFLOW_CUDA="12.2"
            TENSORFLOW_CUDNN="8.9"
            TENSORFLOW_PYTHON="3.9-3.11"
            ;;
        11.8*)
            TENSORFLOW_VERSION="2.14.0"
            TENSORFLOW_CUDA="11.8"
            TENSORFLOW_CUDNN="8.7"
            TENSORFLOW_PYTHON="3.9-3.11"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}
# TensorFlow 설치
install_software() {
    get_installed_tensorflow
    if [ $? -eq 0 ];then
        echo ""
        echo "Installed   : TensorFlow"
        echo "Version     : ${INSTALLED_TENSORFLOW_VERSION}"
        echo "Environment : ${SELECTED_VE}"
        print_message INFO "TensorFlow가 이미 설치되어 있습니다."
        return 2
    fi

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

    if recommend_tensorflow;then
        RECOMMEND_AVAILABLE=true

        echo "========================================"
        echo "        Recommended TensorFlow"
        echo "========================================"
        echo ""
        echo "TensorFlow Version : ${TENSORFLOW_VERSION}"
        echo "CUDA Build         : ${TENSORFLOW_CUDA}"
        echo "cuDNN              : ${TENSORFLOW_CUDNN}"
        echo "Python             : ${TENSORFLOW_PYTHON}"
        echo ""
        echo "1. 추천 버전으로 설치"
        echo "2. 직접 입력"
    else
        RECOMMEND_AVAILABLE=false

        print_message WARNING "현재 CUDA 버전에 맞는 추천 조합을 찾을 수 없습니다."
        echo ""
        echo "1. 직접 입력"
    fi

    echo ""
    read -p "TensorFlow 설치 방법을 선택하세요 : " TENSORFLOW_SELECT

    if [[ "$RECOMMEND_AVAILABLE" == "true" ]];then
        case "$TENSORFLOW_SELECT" in
            1)
                clear_screen;;
            2)
                clear_screen
                read -p "TensorFlow 버전 : " TENSORFLOW_VERSION
                ;;
            *)
                print_message ERROR "올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    else
        case "$TENSORFLOW_SELECT" in
            1)
                clear_screen
                read -p "TensorFlow 버전 : " TENSORFLOW_VERSION
                ;;
            *)
                print_message ERROR "올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    fi

    if [ -z "$TENSORFLOW_VERSION" ];then
        print_message ERROR "TensorFlow 버전을 입력해주세요."
        return 1
    fi

    echo ""
    echo "========================================"
    echo "        TensorFlow Installation Info"
    echo "========================================"
    echo ""
    echo "TensorFlow Version : ${TENSORFLOW_VERSION}"
    echo "Install Type       : tensorflow[and-cuda]"
    echo "Conda Environment  : ${SELECTED_VE}"
    echo "Python Version     : ${SELECTED_PYTHON_VERSION}"
    echo ""
    echo "※ TensorFlow의 CUDA/cuDNN 라이브러리는"
    echo "  Python 환경에 함께 설치됩니다."
    echo ""

    read -p "위 설정으로 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM

    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi

    echo ""
    print_message INFO "TensorFlow 설치를 시작합니다."

    "${SELECTED_VE_PATH}/bin/python" -m pip install --upgrade pip

    if [ $? -ne 0 ];then
        print_message ERROR "pip 업데이트에 실패했습니다."
        return 1
    fi

    "${SELECTED_VE_PATH}/bin/python" -m pip install --upgrade "tensorflow[and-cuda]==${TENSORFLOW_VERSION}"

    if [ $? -ne 0 ];then
        print_message ERROR "TensorFlow 설치에 실패했습니다."
        return 1
    fi

    echo ""
    print_message INFO "설치 버전을 확인합니다."

    INSTALLED_TENSORFLOW_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null)

    if [ -z "$INSTALLED_TENSORFLOW_VERSION" ];then
        print_message ERROR "TensorFlow 설치 확인에 실패했습니다."
        return 1
    fi

    echo "TensorFlow : ${INSTALLED_TENSORFLOW_VERSION}"
    echo ""

    verify_installation

    if [ $? -ne 0 ];then
        return 1
    fi

    SW_META="tensorflow=${INSTALLED_TENSORFLOW_VERSION};cuda=${CUDA_VERSION}"

    add_installed_software "tensorflow" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "${SW_META}"

    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi

    echo ""
    return 0
}
# TensorFlow GPU 확인
verify_installation() {
    print_message INFO "TensorFlow GPU 동작 여부를 확인합니다."

    PYTHON="${SELECTED_VE_PATH}/bin/python"

    NVIDIA_LIB_DIR=$("$PYTHON" -c "
import site
import os
import glob

paths=[]

for base in site.getsitepackages():
    paths.extend(glob.glob(os.path.join(base,'nvidia','*','lib')))

print(':'.join(dict.fromkeys(paths)))
" 2>/dev/null)

    if [ -n "$NVIDIA_LIB_DIR" ];then
        export LD_LIBRARY_PATH="$NVIDIA_LIB_DIR:$LD_LIBRARY_PATH"

        echo ""
        echo "[INFO] NVIDIA CUDA Libraries:"
        echo "$NVIDIA_LIB_DIR"|tr ':' '\n'
    else
        print_message WARNING "NVIDIA CUDA Python Library 경로를 찾을 수 없습니다."
    fi

    echo ""

    TF_INFO=$("$PYTHON" - <<'PY'
import tensorflow as tf
import sys

print(f"Python          : {sys.executable}")
print(f"TensorFlow      : {tf.__version__}")

gpus=tf.config.list_physical_devices("GPU")

print(f"GPU Count       : {len(gpus)}")

for i,gpu in enumerate(gpus):
    print(f"GPU {i}          : {gpu.name}")

if not gpus:
    raise SystemExit(1)
PY
)

    if [ $? -ne 0 ];then
        print_message WARNING "TensorFlow는 설치되었지만 GPU를 인식하지 못했습니다."
        return 1
    fi

    echo "$TF_INFO"
    echo ""

    print_message INFO "TensorFlow GPU 연산을 확인합니다."

    "$PYTHON" - <<'PY'
import tensorflow as tf

with tf.device("/GPU:0"):
    a=tf.random.normal([4096,4096])
    b=tf.random.normal([4096,4096])
    c=tf.matmul(a,b)

print(f"Device          : {c.device}")
print(f"Shape           : {c.shape}")

if "GPU" not in c.device.upper():
    raise SystemExit(1)
PY

    if [ $? -ne 0 ];then
        print_message ERROR "TensorFlow GPU 연산 확인에 실패했습니다."
        return 1
    fi

    print_message SUCCESS "TensorFlow GPU 동작 확인 완료."

    return 0
}
# TensorFlow 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        TensorFlow Uninstallation"
    echo "========================================"
    echo ""

    if [ -z "$SELECTED_VE_PATH" ]||[ ! -x "${SELECTED_VE_PATH}/bin/python" ];then
        print_message ERROR "선택된 가상환경을 확인할 수 없습니다."
        return 1
    fi

    get_installed_tensorflow

    if [ $? -ne 0 ];then
        print_message INFO "선택된 가상환경에 TensorFlow가 설치되어 있지 않습니다."
        return 2
    fi

    echo "Installed   : TensorFlow"
    echo "Version     : ${INSTALLED_TENSORFLOW_VERSION}"
    echo "Environment : ${SELECTED_VE}"
    echo ""

    read -p "TensorFlow를 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM

    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "삭제를 취소했습니다."
        return 3
    fi

    echo ""
    print_message INFO "TensorFlow를 삭제합니다."

    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y tensorflow

    if [ $? -ne 0 ];then
        print_message ERROR "TensorFlow 삭제에 실패했습니다."
        return 1
    fi

    echo ""
    print_message INFO "TensorFlow 삭제 여부를 확인합니다."

    if "${SELECTED_VE_PATH}/bin/python" -c "import tensorflow" 2>/dev/null;then
        print_message ERROR "TensorFlow가 아직 설치되어 있습니다."
        return 1
    fi

    remove_installed_software "tensorflow" "${SELECTED_VE}"

    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 삭제에 실패했습니다."
        return 1
    fi

    echo ""
    print_message SUCCESS "TensorFlow 삭제가 완료되었습니다."

    return 0
}