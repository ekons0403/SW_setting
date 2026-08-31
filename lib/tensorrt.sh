#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=true
# 서버 정보
get_system_info() {
    NVIDIA_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null|head -n1)
    CUDA_VERSION=$(nvcc --version 2>/dev/null|grep -oP 'release \K[0-9]+\.[0-9]+'|head -n1)
    [ -z "$NVIDIA_DRIVER" ]&&NVIDIA_DRIVER="확인 불가"
    [ -z "$CUDA_VERSION" ]&&CUDA_VERSION="확인 불가"
}
# TensorRT 설치 여부
get_installed_tensorrt() {
    INSTALLED_TENSORRT_VERSION=""
    if [ -n "$SELECTED_VE_PATH" ]&&[ -x "${SELECTED_VE_PATH}/bin/python" ];then
        INSTALLED_TENSORRT_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import tensorrt as trt; print(trt.__version__)" 2>/dev/null)
    fi
    if [ -n "$INSTALLED_TENSORRT_VERSION" ];then
        return 0
    fi
    return 1
}
# 추천 버전
recommend_tensorrt() {
    TENSORRT_VERSION=""
    TENSORRT_PACKAGE=""
    case "$CUDA_VERSION" in
        13.2*)
            TENSORRT_VERSION="10.16.0.72"
            TENSORRT_PACKAGE="tensorrt-cu13"
            ;;
        13.1*)
            TENSORRT_VERSION="10.14.1.48"
            TENSORRT_PACKAGE="tensorrt-cu13"
            ;;
        13.0*)
            TENSORRT_VERSION="10.13.2.6"
            TENSORRT_PACKAGE="tensorrt-cu13"
            ;;
        12.8*)
            TENSORRT_VERSION="10.9.0.34"
            TENSORRT_PACKAGE="tensorrt-cu12"
            ;;
        12.6*)
            TENSORRT_VERSION="10.3.0.26"
            TENSORRT_PACKAGE="tensorrt-cu12"
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}
# TensorRT 설치
install_software() {
    get_installed_tensorrt
    if [ $? -eq 0 ];then
        echo ""
        print_message INFO "TensorRT가 이미 설치되어 있습니다."
        echo ""
        echo "Installed : TensorRT"
        echo "Version   : ${INSTALLED_TENSORRT_VERSION}"
        echo "Environment : ${SELECTED_VE}"
        return 2
    fi
    get_system_info
    echo ""
    echo "========================================"
    echo "        TensorRT Installation"
    echo "========================================"
    echo ""
    echo "NVIDIA Driver : ${NVIDIA_DRIVER}"
    echo "CUDA          : ${CUDA_VERSION}"
    echo "Python        : ${SELECTED_PYTHON_VERSION}"
    echo "Environment   : ${SELECTED_VE}"
    echo ""
    if recommend_tensorrt;then
        RECOMMEND_AVAILABLE=true
        echo "========================================"
        echo "        Recommended TensorRT"
        echo "========================================"
        echo ""
        echo "TensorRT Version : ${TENSORRT_VERSION}"
        echo "Package          : ${TENSORRT_PACKAGE}"
        echo ""
        echo "1. 추천 버전으로 설치"
        echo "2. 직접 입력"
    else
        RECOMMEND_AVAILABLE=false
        print_message WARNING "현재 CUDA 버전에 맞는 추천 TensorRT 버전을 찾을 수 없습니다."
        echo ""
        echo "1. 직접 입력"
    fi
    echo ""
    read -p "TensorRT 설치 방법을 선택하세요 : " TENSORRT_SELECT
    if [[ "$RECOMMEND_AVAILABLE" == "true" ]];then
        case "$TENSORRT_SELECT" in
            1)
                ;;
            2)
                read -p "TensorRT 버전 : " TENSORRT_VERSION
                read -p "TensorRT Package : " TENSORRT_PACKAGE
                ;;
            *)
                print_message ERROR "올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    else
        case "$TENSORRT_SELECT" in
            1)
                read -p "TensorRT 버전 : " TENSORRT_VERSION
                read -p "TensorRT Package : " TENSORRT_PACKAGE
                ;;
            *)
                print_message ERROR "올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    fi
    if [ -z "$TENSORRT_VERSION" ]||[ -z "$TENSORRT_PACKAGE" ];then
        print_message ERROR "TensorRT 버전과 Package를 입력해주세요."
        return 1
    fi
    echo ""
    echo "========================================"
    echo "        TensorRT Installation Info"
    echo "========================================"
    echo ""
    echo "TensorRT Version  : ${TENSORRT_VERSION}"
    echo "Package           : ${TENSORRT_PACKAGE}"
    echo "Conda Environment : ${SELECTED_VE}"
    echo "Python Version    : ${SELECTED_PYTHON_VERSION}"
    echo ""
    read -p "위 설정으로 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "TensorRT 설치를 시작합니다."
    echo ""
    "${SELECTED_VE_PATH}/bin/python" -m pip install "${TENSORRT_PACKAGE}==${TENSORRT_VERSION}"
    if [ $? -ne 0 ];then
        print_message ERROR "TensorRT 설치에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "TensorRT 설치를 확인합니다."
    TENSORRT_INFO=$("${SELECTED_VE_PATH}/bin/python" - <<'PY'
import tensorrt as trt
print(f"TensorRT: {trt.__version__}")
try:
    logger = trt.Logger(trt.Logger.WARNING)
    builder = trt.Builder(logger)
    print("TensorRT Builder: OK")
except Exception as e:
    print(f"TensorRT Builder: ERROR - {e}")
PY
)
    if [ -z "$TENSORRT_INFO" ];then
        print_message ERROR "TensorRT 설치 확인에 실패했습니다."
        return 1
    fi
    echo "$TENSORRT_INFO"
    if ! echo "$TENSORRT_INFO"|grep -q "TensorRT Builder: OK";then
        print_message ERROR "TensorRT Builder 확인에 실패했습니다."
        return 1
    fi
    INSTALLED_TENSORRT_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import tensorrt as trt; print(trt.__version__)" 2>/dev/null)
    if [ -z "$INSTALLED_TENSORRT_VERSION" ];then
        print_message ERROR "TensorRT 버전을 확인할 수 없습니다."
        return 1
    fi
    SW_META="tensorrt=${INSTALLED_TENSORRT_VERSION};cuda=${CUDA_VERSION};package=${TENSORRT_PACKAGE}"
    add_installed_software "tensorrt" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "${SW_META}"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    return 0
}
# TensorRT 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        TensorRT Uninstallation"
    echo "========================================"
    echo ""
    if [ -z "$SELECTED_VE_PATH" ]||[ ! -x "${SELECTED_VE_PATH}/bin/python" ];then
        print_message ERROR "선택된 가상환경을 확인할 수 없습니다."
        return 1
    fi
    get_installed_tensorrt
    if [ $? -ne 0 ];then
        print_message INFO "선택된 가상환경에 TensorRT가 설치되어 있지 않습니다."
        return 2
    fi
    echo "Installed : TensorRT"
    echo "Version   : ${INSTALLED_TENSORRT_VERSION}"
    echo "Environment : ${SELECTED_VE}"
    echo ""
    read -p "TensorRT를 모두 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "삭제를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "TensorRT 관련 패키지를 모두 삭제합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y \
        tensorrt \
        tensorrt-cu12 \
        tensorrt-cu13 \
        tensorrt-libs \
        tensorrt-bindings \
        tensorrt_cu12 \
        tensorrt_cu13
    if [ $? -ne 0 ];then
        print_message ERROR "TensorRT 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "TensorRT 삭제 여부를 확인합니다."
    if "${SELECTED_VE_PATH}/bin/python" -c "import tensorrt" 2>/dev/null;then
        print_message ERROR "TensorRT가 아직 설치되어 있습니다."
        return 1
    fi
    remove_installed_software "tensorrt" "${SELECTED_VE}"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    return 0
}