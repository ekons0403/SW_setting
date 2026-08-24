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
#추천 버전
recommend_tensorrt() {
    TENSORRT_PACKAGE=""
    case "$CUDA_VERSION" in
        13.*)
            TENSORRT_PACKAGE="tensorrt-cu13"
            ;;
        12.*)
            TENSORRT_PACKAGE="tensorrt-cu12"
            ;;
        *)
            return 1
            ;;
    esac
}
#TensorRT 설치
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
        echo "========================================"
        echo "        Recommended TensorRT"
        echo "========================================"
        echo ""
        echo "Package       : ${TENSORRT_PACKAGE}"
    else
        echo "[WARNING] 현재 CUDA 버전에 맞는 TensorRT 패키지를 찾을 수 없습니다."
        return 1
    fi

    echo ""
    echo "Conda Environment : ${SELECTED_VE}"
    echo "Python Version    : ${SELECTED_PYTHON_VERSION}"
    echo ""

    read -p "위 설정으로 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 설치를 취소했습니다."
        return 0
    fi

    echo ""
    echo "[INFO] pip 및 wheel을 업데이트합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip install --upgrade pip wheel
    if [ $? -ne 0 ];then
        echo "[ERROR] pip 업데이트에 실패했습니다."
        return 1
    fi

    echo ""
    echo "[INFO] TensorRT 설치를 시작합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip install --upgrade "${TENSORRT_PACKAGE}"
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
builder = trt.Builder(trt.Logger())
print("TensorRT Builder: OK")
PY
)

    if [ $? -ne 0 ];then
        echo "[ERROR] TensorRT 검증에 실패했습니다."
        return 1
    fi

    echo "$TENSORRT_INFO"

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
#TensorRT 삭제
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

    TENSORRT_PACKAGE=""

    if "${SELECTED_VE_PATH}/bin/python" -m pip show tensorrt-cu13 >/dev/null 2>&1;then
        TENSORRT_PACKAGE="tensorrt-cu13"
    elif "${SELECTED_VE_PATH}/bin/python" -m pip show tensorrt-cu12 >/dev/null 2>&1;then
        TENSORRT_PACKAGE="tensorrt-cu12"
    elif "${SELECTED_VE_PATH}/bin/python" -m pip show tensorrt >/dev/null 2>&1;then
        TENSORRT_PACKAGE="tensorrt"
    else
        echo "[INFO] 해당 가상환경에 TensorRT가 설치되어 있지 않습니다."
        return 0
    fi

    TENSORRT_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import tensorrt as trt; print(trt.__version__)" 2>/dev/null)

    echo "[INFO] 설치된 TensorRT: ${TENSORRT_VERSION}"
    echo "[INFO] 설치 패키지: ${TENSORRT_PACKAGE}"
    echo ""

    read -p "TensorRT를 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 삭제를 취소했습니다."
        return 0
    fi

    echo ""
    echo "[INFO] TensorRT를 삭제합니다."

    case "$TENSORRT_PACKAGE" in
        tensorrt-cu13)
            "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y tensorrt-cu13 tensorrt_cu13_bindings tensorrt_cu13_libs
            ;;
        tensorrt-cu12)
            "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y tensorrt-cu12 tensorrt_cu12_bindings tensorrt_cu12_libs
            ;;
        tensorrt)
            "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y tensorrt
            ;;
    esac

    if [ $? -ne 0 ];then
        echo "[ERROR] TensorRT 삭제에 실패했습니다."
        return 1
    fi

    echo ""
    echo "[SUCCESS] TensorRT 삭제가 완료되었습니다."
    return 0
}