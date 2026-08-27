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
# TensorRT 정보
get_tensorrt_version() {
    TENSORRT_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import tensorrt as trt; print(trt.__version__)" 2>/dev/null)
    [ -z "$TENSORRT_VERSION" ]&&TENSORRT_VERSION="확인 불가"
}
# 추천 버전
recommend_deepstream() {
    DEEPSTREAM_VERSION=""
    case "$TENSORRT_VERSION" in
        10.16*)
            DEEPSTREAM_VERSION="9.1.0"
            ;;
        10.14*)
            DEEPSTREAM_VERSION="9.0.0"
            ;;
        10.9*)
            DEEPSTREAM_VERSION="8.0.0"
            ;;
        10.3*)
            DEEPSTREAM_VERSION="7.1.0"
            ;;
        *)
            return 1
            ;;
    esac
}
# DeepStream 정보
get_deepstream_info() {
    case "$DEEPSTREAM_VERSION" in
        9.1*)
            DEEPSTREAM_PACKAGE="deepstream-9.1"
            PACKAGE_NAME="deepstream-9.1_9.1.0-1_amd64.deb"
            DOWNLOAD_URL="https://github.com/NVIDIA/DeepStream/releases/download/v9.1.0/${PACKAGE_NAME}"
            DEEPSTREAM_PATH="/opt/nvidia/deepstream/deepstream-9.1"
            ;;
        9.0*)
            DEEPSTREAM_PACKAGE="deepstream-9.0"
            PACKAGE_NAME="deepstream-9.0_9.0.0-1_amd64.deb"
            DOWNLOAD_URL="https://github.com/NVIDIA/DeepStream/releases/download/v9.0.0/${PACKAGE_NAME}"
            DEEPSTREAM_PATH="/opt/nvidia/deepstream/deepstream-9.0"
            ;;
        8.0*)
            DEEPSTREAM_PACKAGE="deepstream-8.0"
            PACKAGE_NAME="deepstream-8.0_8.0.0-1_amd64.deb"
            DOWNLOAD_URL="https://github.com/NVIDIA/DeepStream/releases/download/v8.0.0/${PACKAGE_NAME}"
            DEEPSTREAM_PATH="/opt/nvidia/deepstream/deepstream-8.0"
            ;;
        7.1*)
            DEEPSTREAM_PACKAGE="deepstream-7.1"
            PACKAGE_NAME="deepstream-7.1_7.1.0-1_amd64.deb"
            DOWNLOAD_URL="https://api.ngc.nvidia.com/v2/resources/org/nvidia/deepstream/7.1/files?redirect=true&path=${PACKAGE_NAME}"
            DEEPSTREAM_PATH="/opt/nvidia/deepstream/deepstream-7.1"
            ;;
        *)
            return 1
            ;;
    esac
}
# deepstream 설치
install_software() {
    get_system_info
    get_tensorrt_version
    echo ""
    echo "========================================"
    echo "        System Information"
    echo "========================================"
    echo ""
    echo "NVIDIA Driver : ${NVIDIA_DRIVER}"
    echo "CUDA          : ${CUDA_VERSION}"
    echo "TensorRT      : ${TENSORRT_VERSION}"
    echo "Python        : ${SELECTED_PYTHON_VERSION}"
    echo ""
    if recommend_deepstream;then
        RECOMMEND_AVAILABLE=true
        echo "========================================"
        echo "        Recommended DeepStream"
        echo "========================================"
        echo ""
        echo "DeepStream Version : ${DEEPSTREAM_VERSION}"
        echo "TensorRT Version   : ${TENSORRT_VERSION}"
        echo ""
        echo "1. 추천 버전으로 설치"
        echo "2. 직접 입력"
    else
        RECOMMEND_AVAILABLE=false
        echo "[WARNING] 현재 TensorRT 버전에 맞는 추천 DeepStream 버전을 찾을 수 없습니다."
        echo ""
        echo "1. 직접 입력"
    fi
    echo ""
    read -p "DeepStream 설치 방법을 선택하세요 : " DEEPSTREAM_SELECT
    if [[ "$RECOMMEND_AVAILABLE" == "true" ]];then
        case "$DEEPSTREAM_SELECT" in
            1)
                ;;
            2)
                read -p "DeepStream 버전 : " DEEPSTREAM_VERSION
                ;;
            *)
                echo "[ERROR] 올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    else
        case "$DEEPSTREAM_SELECT" in
            1)
                read -p "DeepStream 버전 : " DEEPSTREAM_VERSION
                ;;
            *)
                echo "[ERROR] 올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    fi
    if [ -z "$DEEPSTREAM_VERSION" ];then
        echo "[ERROR] DeepStream 버전을 입력해주세요."
        return 1
    fi
    if ! get_deepstream_info;then
        echo "[ERROR] 지원하지 않는 DeepStream 버전입니다."
        return 1
    fi
    echo ""
    echo "========================================"
    echo "        DeepStream Installation Info"
    echo "========================================"
    echo ""
    echo "DeepStream Version : ${DEEPSTREAM_VERSION}"
    echo "TensorRT Version   : ${TENSORRT_VERSION}"
    echo "CUDA Version       : ${CUDA_VERSION}"
    echo "Conda Environment  : ${SELECTED_VE}"
    echo "Python Version     : ${SELECTED_PYTHON_VERSION}"
    echo ""
    read -p "위 설정으로 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 설치를 취소했습니다."
        return 0
    fi
    DOWNLOAD_PATH="/tmp/${PACKAGE_NAME}"
    echo ""
    echo "[INFO] DeepStream 설치를 시작합니다."
    echo "[INFO] 설치 URL: ${DOWNLOAD_URL}"
    echo ""
    wget -q --show-progress "$DOWNLOAD_URL" -O "$DOWNLOAD_PATH"
    if [ $? -ne 0 ];then
        echo ""
        echo "[ERROR] DeepStream 다운로드에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[INFO] DeepStream 패키지를 설치합니다."
    sudo apt-get install -y "$DOWNLOAD_PATH"
    if [ $? -ne 0 ];then
        echo ""
        echo "[ERROR] DeepStream 설치에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] DeepStream 설치가 완료되었습니다."
    echo ""
    echo "[INFO] 설치 버전을 확인합니다."
    if [ -x "${DEEPSTREAM_PATH}/bin/deepstream-app" ];then
        echo "DeepStream: ${DEEPSTREAM_VERSION}"
        echo "deepstream-app: OK"
        echo "[SUCCESS] DeepStream 설치 및 동작이 확인되었습니다."
    else
        echo "[ERROR] DeepStream 설치 후 deepstream-app을 찾을 수 없습니다."
        return 1
    fi
    SW_META="tensorrt=${TENSORRT_VERSION};cuda=${CUDA_VERSION};package=deb"
    add_installed_software "deepstream" "system" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "${SW_META}"
    if [ $? -ne 0 ];then
        echo "[ERROR] 설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] DeepStream 설치 및 등록이 완료되었습니다."
    return 0
}
# deepstream 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        DeepStream Uninstallation"
    echo "========================================"
    echo ""
    echo "[INFO] 설치된 DeepStream을 확인합니다."
    if dpkg-query -W -f='${Status}' deepstream-9.1 2>/dev/null|grep -q "install ok installed";then
        DEEPSTREAM_PACKAGE="deepstream-9.1"
    elif dpkg-query -W -f='${Status}' deepstream-9.0 2>/dev/null|grep -q "install ok installed";then
        DEEPSTREAM_PACKAGE="deepstream-9.0"
    elif dpkg-query -W -f='${Status}' deepstream-8.0 2>/dev/null|grep -q "install ok installed";then
        DEEPSTREAM_PACKAGE="deepstream-8.0"
    elif dpkg-query -W -f='${Status}' deepstream-7.1 2>/dev/null|grep -q "install ok installed";then
        DEEPSTREAM_PACKAGE="deepstream-7.1"
    else
        echo "[INFO] DeepStream이 설치되어 있지 않습니다."
        return 0
    fi
    DEEPSTREAM_VERSION=$(dpkg-query -W -f='${Version}' "${DEEPSTREAM_PACKAGE}" 2>/dev/null)
    echo "[INFO] 설치된 DeepStream: ${DEEPSTREAM_PACKAGE}"
    echo "[INFO] 버전: ${DEEPSTREAM_VERSION}"
    echo ""
    read -p "DeepStream을 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 삭제를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] DeepStream을 삭제합니다."
    sudo apt-get remove -y "${DEEPSTREAM_PACKAGE}"
    if [ $? -ne 0 ];then
        echo "[ERROR] DeepStream 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] DeepStream 삭제가 완료되었습니다."
    return 0
}