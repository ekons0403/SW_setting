```bash
#!/bin/bash
REQUIRE_VENV=true

SW_NAME="tensorflow"
SW_DESCRIPTION="TensorFlow"
SW_CATEGORY="Machine Learning"
SW_INSTALL_TYPE="pip"

TENSORFLOW_VERSION="2.21.0"

# TensorFlow 설치 확인
get_installed_tensorflow() {
    INSTALLED_TENSORFLOW_VERSION=$("${SELECTED_VE_PATH}/bin/python" -m pip show tensorflow 2>/dev/null|awk '/^Version:/{print $2}')
    if [ -n "$INSTALLED_TENSORFLOW_VERSION" ];then
        return 0
    fi
    return 1
}

# NVIDIA CUDA Runtime 패키지 확인
get_cuda_runtime_packages() {
    NVIDIA_CUBLAS=$("${SELECTED_VE_PATH}/bin/python" -m pip show nvidia-cublas-cu12 2>/dev/null|awk '/^Version:/{print $2}')
    NVIDIA_CUDA_RUNTIME=$("${SELECTED_VE_PATH}/bin/python" -m pip show nvidia-cuda-runtime-cu12 2>/dev/null|awk '/^Version:/{print $2}')
    NVIDIA_CUDNN=$("${SELECTED_VE_PATH}/bin/python" -m pip show nvidia-cudnn-cu12 2>/dev/null|awk '/^Version:/{print $2}')
    NVIDIA_CUSOLVER=$("${SELECTED_VE_PATH}/bin/python" -m pip show nvidia-cusolver-cu12 2>/dev/null|awk '/^Version:/{print $2}')
    NVIDIA_CUSPARSE=$("${SELECTED_VE_PATH}/bin/python" -m pip show nvidia-cusparse-cu12 2>/dev/null|awk '/^Version:/{print $2}')

    if [ -n "$NVIDIA_CUBLAS" ]&&[ -n "$NVIDIA_CUDA_RUNTIME" ]&&[ -n "$NVIDIA_CUDNN" ]&&[ -n "$NVIDIA_CUSOLVER" ]&&[ -n "$NVIDIA_CUSPARSE" ];then
        return 0
    fi
    return 1
}

# Conda 환경의 NVIDIA CUDA Library 경로 설정
setup_cuda_library_path() {
    local PYTHON="$SELECTED_VE_PATH/bin/python"
    local NVIDIA_LIB_PATH

    NVIDIA_LIB_PATH=$("$PYTHON" -c '
import site
import os
import glob

paths=[]

for base in site.getsitepackages():
    paths.extend(glob.glob(os.path.join(base,"nvidia","*","lib")))

print(":".join(dict.fromkeys(paths)))
' 2>/dev/null)

    if [ -z "$NVIDIA_LIB_PATH" ];then
        print_message ERROR "Conda 환경에서 NVIDIA CUDA Library를 찾을 수 없습니다."
        return 1
    fi

    export LD_LIBRARY_PATH="${NVIDIA_LIB_PATH}:${LD_LIBRARY_PATH}"

    return 0
}

# NVIDIA CUDA Python Library 확인
verify_cuda_runtime() {
    local PYTHON="$SELECTED_VE_PATH/bin/python"

    if ! "$PYTHON" -c "import nvidia.cublas.lib,nvidia.cudnn.lib,nvidia.cusolver.lib,nvidia.cusparse.lib" 2>/dev/null;then
        print_message ERROR "NVIDIA CUDA Python Library 확인에 실패했습니다."
        return 1
    fi

    return 0
}

# TensorFlow GPU 동작 확인
verify_installation() {
    local PYTHON="$SELECTED_VE_PATH/bin/python"

    print_message INFO "TensorFlow GPU 동작 상태를 확인합니다."

    if ! setup_cuda_library_path;then
        return 1
    fi

    if ! verify_cuda_runtime;then
        return 1
    fi

    "$PYTHON" -c '
import tensorflow as tf
import sys

gpus=tf.config.list_physical_devices("GPU")

print("Python          :",sys.executable)
print("TensorFlow      :",tf.__version__)
print("GPU Count       :",len(gpus))

if not gpus:
    raise SystemExit(1)

print("GPU             :",gpus[0].name)
'
    if [ $? -ne 0 ];then
        print_message ERROR "TensorFlow GPU 인식에 실패했습니다."
        return 1
    fi

    "$PYTHON" -c '
import tensorflow as tf

a=tf.random.normal([4096,4096])
b=tf.random.normal([4096,4096])
c=tf.matmul(a,b)

print("Device          :",c.device)
print("Shape           :",c.shape)

if "GPU:" not in c.device:
    raise SystemExit(1)
'
    if [ $? -ne 0 ];then
        print_message ERROR "TensorFlow GPU 연산 확인에 실패했습니다."
        return 1
    fi

    print_message SUCCESS "TensorFlow GPU 동작 확인 완료."

    return 0
}

# TensorFlow 설치
install_software() {
    local INSTALL_NEEDED=true

    if get_installed_tensorflow;then
        print_message WARNING "TensorFlow ${INSTALLED_TENSORFLOW_VERSION}이 이미 설치되어 있습니다."

        if get_cuda_runtime_packages;then
            if verify_installation;then
                add_installed_software "tensorflow" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "tensorflow=${INSTALLED_TENSORFLOW_VERSION}"
                if [ $? -ne 0 ];then
                    print_message ERROR "TensorFlow 설치 목록 등록에 실패했습니다."
                    return 1
                fi
                return 2
            fi

            print_message WARNING "TensorFlow는 설치되어 있지만 GPU 환경이 정상적으로 구성되지 않았습니다."
        else
            print_message WARNING "TensorFlow NVIDIA CUDA Runtime이 설치되어 있지 않습니다."
        fi

        read -p "TensorFlow 환경을 다시 구성하시겠습니까? [y/n]: " ANSWER

        case "$ANSWER" in
            y|Y) ;;
            *) print_message WARNING "TensorFlow 설치를 취소했습니다."; return 3 ;;
        esac
    else
        read -p "TensorFlow ${TENSORFLOW_VERSION}을 설치하시겠습니까? [y/n]: " ANSWER

        case "$ANSWER" in
            y|Y) ;;
            *) print_message WARNING "TensorFlow 설치를 취소했습니다."; return 3 ;;
        esac
    fi

    print_message INFO "TensorFlow ${TENSORFLOW_VERSION} 설치 중..."

    "${SELECTED_VE_PATH}/bin/python" -m pip install --upgrade "tensorflow[and-cuda]==${TENSORFLOW_VERSION}"

    if [ $? -ne 0 ];then
        print_message ERROR "TensorFlow 설치에 실패했습니다."
        return 1
    fi

    INSTALLED_TENSORFLOW_VERSION=$("${SELECTED_VE_PATH}/bin/python" -m pip show tensorflow 2>/dev/null|awk '/^Version:/{print $2}')

    if [ -z "$INSTALLED_TENSORFLOW_VERSION" ];then
        print_message ERROR "TensorFlow 버전을 확인할 수 없습니다."
        return 1
    fi

    print_message SUCCESS "TensorFlow ${INSTALLED_TENSORFLOW_VERSION} 설치 완료."

    if ! get_cuda_runtime_packages;then
        print_message ERROR "TensorFlow NVIDIA CUDA Runtime 설치 확인에 실패했습니다."
        return 1
    fi

    if ! verify_installation;then
        return 1
    fi

    add_installed_software "tensorflow" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "tensorflow=${INSTALLED_TENSORFLOW_VERSION}"

    if [ $? -ne 0 ];then
        print_message ERROR "TensorFlow 설치 목록 등록에 실패했습니다."
        return 1
    fi

    return 0
}

# TensorFlow 삭제
uninstall_software() {
    if ! get_installed_tensorflow;then
        print_message WARNING "TensorFlow가 설치되어 있지 않습니다."
        return 2
    fi

    read -p "TensorFlow ${INSTALLED_TENSORFLOW_VERSION}을 삭제하시겠습니까? [y/n]: " ANSWER

    case "$ANSWER" in
        y|Y) ;;
        *) print_message WARNING "TensorFlow 삭제를 취소했습니다."; return 3 ;;
    esac

    print_message INFO "TensorFlow 삭제 중..."

    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y tensorflow

    if [ $? -ne 0 ];then
        print_message ERROR "TensorFlow 삭제에 실패했습니다."
        return 1
    fi

    if get_installed_tensorflow;then
        print_message ERROR "TensorFlow 삭제 확인에 실패했습니다."
        return 1
    fi

    print_message SUCCESS "TensorFlow 삭제 완료."

    return 0
}
```
