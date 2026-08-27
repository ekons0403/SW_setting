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
}
# tensorrt 설치
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
        echo "[WARNING] 현재 CUDA 버전에 맞는 추천 TensorRT 버전을 찾을 수 없습니다."
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
                echo "[ERROR] 올바른 번호를 선택해주세요."
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
                echo "[ERROR] 올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
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
        echo "[INFO] 설치를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] TensorRT 설치를 시작합니다."
    echo ""
    "${SELECTED_VE_PATH}/bin/python" -m pip install "${TENSORRT_PACKAGE}==${TENSORRT_VERSION}"
    if [ $? -ne 0 ];then
        echo ""
        echo "[ERROR] TensorRT 설치에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] TensorRT 설치가 완료되었습니다."
    echo ""
    echo "[INFO] 설치 버전을 확인합니다."
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
    echo "$TENSORRT_INFO"
    if echo "$TENSORRT_INFO"|grep -q "TensorRT Builder: OK";then
        echo "[SUCCESS] TensorRT 및 Builder 확인이 완료되었습니다."
    else
        echo "[WARNING] TensorRT는 설치되었지만 Builder 확인에 실패했습니다."
    fi
    INSTALLED_TENSORRT_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import tensorrt as trt; print(trt.__version__)" 2>/dev/null)
    SW_META="tensorrt=${INSTALLED_TENSORRT_VERSION};cuda=${CUDA_VERSION};package=${TENSORRT_PACKAGE}"
    add_installed_software "tensorrt" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "${SW_META}"
    if [ $? -ne 0 ];then
        echo "[ERROR] 설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] TensorRT 설치 및 등록이 완료되었습니다."
    return 0
}
# tensorrt 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        TensorRT Uninstallation"
    echo "========================================"
    echo ""
    echo "[INFO] 선택된 가상환경: ${SELECTED_VE}"
    echo "[INFO] Python 버전: ${SELECTED_PYTHON_VERSION}"
    echo "[INFO] 경로: ${SELECTED_VE_PATH}"
    echo ""
    if ! "${SELECTED_VE_PATH}/bin/python" -c "import tensorrt" 2>/dev/null;then
        echo "[INFO] 해당 가상환경에 TensorRT가 설치되어 있지 않습니다."
        return 0
    fi
    TENSORRT_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import tensorrt as trt; print(trt.__version__)" 2>/dev/null)
    echo "[INFO] 설치된 TensorRT: ${TENSORRT_VERSION}"
    echo ""
    read -p "TensorRT를 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 삭제를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] TensorRT를 삭제합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y tensorrt tensorrt-cu12 tensorrt-cu13 tensorrt-libs tensorrt-bindings tensorrt_cu12 tensorrt_cu13
    if [ $? -ne 0 ];then
        echo "[ERROR] TensorRT 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] TensorRT 삭제가 완료되었습니다."
    return 0
}