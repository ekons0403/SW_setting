#!/bin/bash
#가상환경 여부
REQUIRE_VENV=false
#DeepStream 버전
DEEPSTREAM_VERSION="9.1.0"
#서버 정보
get_system_info() {
    NVIDIA_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null|head -n1)
    CUDA_VERSION=$(nvcc --version 2>/dev/null|grep -oP 'release \K[0-9]+\.[0-9]+'|head -n1)
    TRT_VERSION=$(dpkg-query -W -f='${Version}' libnvinfer10 2>/dev/null|head -n1)
    [ -z "$NVIDIA_DRIVER" ]&&NVIDIA_DRIVER="확인 불가"
    [ -z "$CUDA_VERSION" ]&&CUDA_VERSION="확인 불가"
    [ -z "$TRT_VERSION" ]&&TRT_VERSION="확인 불가"
}
#추천 버전
recommend_deepstream() {
    DEEPSTREAM_VERSION=""
    case "$CUDA_VERSION" in
        13.2*)
            DEEPSTREAM_VERSION="9.1.0"
            ;;
        *)
            return 1
            ;;
    esac
}
#TensorRT 확인
check_tensorrt() {
    if [ "$TRT_VERSION" == "확인 불가" ];then
        echo "[ERROR] TensorRT가 설치되어 있지 않습니다."
        return 1
    fi
    TRT_MAJOR_VERSION=$(echo "$TRT_VERSION"|grep -oP '^[0-9]+\.[0-9]+'|head -n1)
    if [[ "$TRT_MAJOR_VERSION" != "10.16" ]];then
        echo "[WARNING] DeepStream ${DEEPSTREAM_VERSION}은 TensorRT 10.16.x를 권장합니다."
        echo "[WARNING] 현재 TensorRT: ${TRT_VERSION}"
    fi
}
#DeepStream 설치
install_software() {
    get_system_info
    echo ""
    echo "========================================"
    echo "        System Information"
    echo "========================================"
    echo ""
    echo "NVIDIA Driver : ${NVIDIA_DRIVER}"
    echo "CUDA          : ${CUDA_VERSION}"
    echo "TensorRT      : ${TRT_VERSION}"
    echo ""
    if recommend_deepstream;then
        RECOMMEND_AVAILABLE=true
        echo "========================================"
        echo "        Recommended DeepStream"
        echo "========================================"
        echo ""
        echo "DeepStream Version : ${DEEPSTREAM_VERSION}"
        echo "CUDA Version       : 13.2"
        echo "TensorRT Version   : 10.16.x"
    else
        RECOMMEND_AVAILABLE=false
        echo "[WARNING] 현재 CUDA 버전에 맞는 추천 DeepStream 버전을 찾을 수 없습니다."
        echo ""
        read -p "DeepStream 버전 : " DEEPSTREAM_VERSION
        if [ -z "$DEEPSTREAM_VERSION" ];then
            echo "[ERROR] DeepStream 버전을 입력해주세요."
            return 1
        fi
    fi
    echo ""
    if ! check_tensorrt;then
        return 1
    fi
    echo ""
    echo "========================================"
    echo "        DeepStream Installation Info"
    echo "========================================"
    echo ""
    echo "DeepStream Version : ${DEEPSTREAM_VERSION}"
    echo "CUDA Version       : ${CUDA_VERSION}"
    echo "TensorRT Version   : ${TRT_VERSION}"
    echo "Install Type       : Debian Package"
    echo ""
    read -p "위 설정으로 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 설치를 취소했습니다."
        return 0
    fi
    PACKAGE_NAME="deepstream-9.1_9.1.0-1_amd64.deb"
    DOWNLOAD_URL="https://github.com/NVIDIA/DeepStream/releases/download/v9.1.0/${PACKAGE_NAME}"
    DOWNLOAD_PATH="/tmp/${PACKAGE_NAME}"
    echo ""
    echo "[INFO] DeepStream 설치를 시작합니다."
    echo "[INFO] 다운로드 URL: ${DOWNLOAD_URL}"
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
    DEEPSTREAM_PATH="/opt/nvidia/deepstream/deepstream-9.1"
    if [ -x "${DEEPSTREAM_PATH}/bin/deepstream-app" ];then
        DEEPSTREAM_INFO=$("${DEEPSTREAM_PATH}/bin/deepstream-app" --version 2>/dev/null)
        [ -z "$DEEPSTREAM_INFO" ]&&DEEPSTREAM_INFO="DeepStream ${DEEPSTREAM_VERSION}"
        echo "$DEEPSTREAM_INFO"
        echo "[SUCCESS] DeepStream 설치가 확인되었습니다."
    elif command -v deepstream-app >/dev/null 2>&1;then
        deepstream-app --version 2>/dev/null||true
        echo "[SUCCESS] DeepStream 설치가 확인되었습니다."
    else
        echo "[ERROR] DeepStream 설치 후 실행 파일을 찾을 수 없습니다."
        return 1
    fi
    SW_META="cuda=${CUDA_VERSION};tensorrt=${TRT_VERSION};package=deb"
    add_installed_software "deepstream" "system" "system" "system" "${SW_META}"
    if [ $? -ne 0 ];then
        echo "[ERROR] 설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] DeepStream 설치 및 등록이 완료되었습니다."
    return 0
}
#DeepStream 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        DeepStream Uninstallation"
    echo "========================================"
    echo ""
    echo "[INFO] 설치된 DeepStream을 확인합니다."
    DEEPSTREAM_PACKAGE=$(dpkg-query -W -f='${Status}' deepstream-9.1 2>/dev/null)
    if ! echo "$DEEPSTREAM_PACKAGE"|grep -q "install ok installed";then
        echo "[INFO] DeepStream 9.1이 설치되어 있지 않습니다."
        return 0
    fi
    INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' deepstream-9.1 2>/dev/null)
    echo "[INFO] 설치된 DeepStream: ${INSTALLED_VERSION}"
    echo ""
    read -p "DeepStream을 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 삭제를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] DeepStream을 삭제합니다."
    sudo apt-get remove -y deepstream-9.1
    if [ $? -ne 0 ];then
        echo "[ERROR] DeepStream 삭제에 실패했습니다."
        return 1
    fi
    sudo apt-get autoremove -y
    echo ""
    echo "[SUCCESS] DeepStream 삭제가 완료되었습니다."
    return 0
}
