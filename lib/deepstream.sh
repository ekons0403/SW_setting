#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=false
# 서버 정보
get_system_info() {
    NVIDIA_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null|head -n1)
    CUDA_VERSION=$(nvcc --version 2>/dev/null|grep -oP 'release \K[0-9]+\.[0-9]+'|head -n1)
    [ -z "$NVIDIA_DRIVER" ]&&NVIDIA_DRIVER="확인 불가"
    [ -z "$CUDA_VERSION" ]&&CUDA_VERSION="확인 불가"
}
# TensorRT 정보
get_tensorrt_version() {
    TENSORRT_VERSION=""
    TENSORRT_ENV=""
    TENSORRT_PYTHON=""
    while read -r ENV_PATH;do
        [ -z "$ENV_PATH" ]&&continue
        [ -x "${ENV_PATH}/bin/python" ]||continue
        VERSION=$("${ENV_PATH}/bin/python" -c "import tensorrt as trt; print(trt.__version__)" 2>/dev/null)
        if [ -n "$VERSION" ];then
            TENSORRT_VERSION=$(echo "$VERSION"|grep -oP '^[0-9]+\.[0-9]+')
            TENSORRT_ENV=$(basename "$ENV_PATH")
            TENSORRT_PYTHON="${ENV_PATH}/bin/python"
            return 0
        fi
    done < <(conda env list 2>/dev/null|awk '!/^#/&&NF>=2{print $NF}'|grep '^/')
    # 현재 활성화된 Conda 환경 추가 확인
    if command -v python>/dev/null 2>&1;then
        VERSION=$(python -c "import tensorrt as trt; print(trt.__version__)" 2>/dev/null)
        if [ -n "$VERSION" ];then
            TENSORRT_VERSION=$(echo "$VERSION"|grep -oP '^[0-9]+\.[0-9]+')
            TENSORRT_ENV="${CONDA_DEFAULT_ENV:-base}"
            TENSORRT_PYTHON=$(command -v python)
            return 0
        fi
    fi
    # 시스템 TensorRT 확인
    VERSION=$(dpkg-query -W -f='${Version}' libnvinfer10 2>/dev/null|grep -oP '^[0-9]+\.[0-9]+')
    if [ -n "$VERSION" ];then
        TENSORRT_VERSION="$VERSION"
        TENSORRT_ENV="system"
        TENSORRT_PYTHON=""
        return 0
    fi
    return 1
}
# DeepStream 설치 여부
get_installed_deepstream() {
    INSTALLED_DEEPSTREAM_PACKAGE=""
    INSTALLED_DEEPSTREAM_VERSION=""
    for PACKAGE in deepstream-9.1 deepstream-9.0 deepstream-8.0 deepstream-7.1;do
        STATUS=$(dpkg-query -W -f='${Status}' "$PACKAGE" 2>/dev/null)
        if [ "$STATUS" = "install ok installed" ];then
            INSTALLED_DEEPSTREAM_PACKAGE="$PACKAGE"
            INSTALLED_DEEPSTREAM_VERSION=$(dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null)
            return 0
        fi
    done
    return 1
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
    return 0
}
# DeepStream 설치
install_software() {
    get_installed_deepstream
    if [ $? -eq 0 ];then
        echo ""
        print_message INFO "DeepStream이 이미 설치되어 있습니다."
        echo ""
        echo "Installed : ${INSTALLED_DEEPSTREAM_PACKAGE}"
        echo "Version   : ${INSTALLED_DEEPSTREAM_VERSION}"
        return 2
    fi
    get_system_info
    get_tensorrt_version
    echo ""
    echo "========================================"
    echo "        System Information"
    echo "========================================"
    echo ""
    echo "NVIDIA Driver : ${NVIDIA_DRIVER}"
    echo "CUDA          : ${CUDA_VERSION}"
    if [ -n "$TENSORRT_VERSION" ];then
        echo "TensorRT      : ${TENSORRT_VERSION}"
        echo "TensorRT Env  : ${TENSORRT_ENV}"
    else
        echo "TensorRT      : 확인 불가"
    fi
    echo ""
    if recommend_deepstream;then
        echo "Recommended DeepStream : ${DEEPSTREAM_VERSION}"
        echo ""
        echo "1. 추천 버전 설치"
        echo "2. 직접 입력"
        echo ""
        read -p "선택 : " DEEPSTREAM_SELECT
        case "$DEEPSTREAM_SELECT" in
            1)
                ;;
            2)
                echo ""
                read -p "DeepStream 버전 : " DEEPSTREAM_VERSION
                ;;
            *)
                print_message ERROR "올바른 번호를 선택해주세요."
                return 1
                ;;
        esac
    else
        print_message WARNING "현재 설치된 TensorRT에 맞는 추천 버전이 없습니다."
        echo ""
        read -p "DeepStream 버전 : " DEEPSTREAM_VERSION
    fi
    if [ -z "$DEEPSTREAM_VERSION" ];then
        print_message ERROR "DeepStream 버전을 입력해주세요."
        return 1
    fi
    if ! get_deepstream_info;then
        print_message ERROR "지원하지 않는 DeepStream 버전입니다."
        return 1
    fi
    echo ""
    echo "========================================"
    echo "        DeepStream Installation Info"
    echo "========================================"
    echo ""
    echo "DeepStream Version : ${DEEPSTREAM_VERSION}"
    echo "TensorRT           : ${TENSORRT_VERSION:-확인 불가}"
    echo "CUDA               : ${CUDA_VERSION}"
    echo "Package            : deb"
    echo ""
    read -p "위 설정으로 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi
    DOWNLOAD_PATH="/tmp/${PACKAGE_NAME}"
    echo ""
    print_message INFO "DeepStream 설치를 시작합니다."
    echo ""
    wget -q --show-progress "$DOWNLOAD_URL" -O "$DOWNLOAD_PATH"
    if [ $? -ne 0 ];then
        echo ""
        print_message ERROR "DeepStream 다운로드에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "DeepStream 패키지를 설치합니다."
    sudo apt-get install -y "$DOWNLOAD_PATH"
    if [ $? -ne 0 ];then
        echo ""
        print_message ERROR "DeepStream 설치에 실패했습니다."
        return 1
    fi
    echo ""
    if [ -x "${DEEPSTREAM_PATH}/bin/deepstream-app" ];then
        echo "DeepStream       : ${DEEPSTREAM_VERSION}"
        echo "deepstream-app   : OK"
    else
        print_message ERROR "설치 후 deepstream-app을 찾을 수 없습니다."
        return 1
    fi
    SW_META="version=${DEEPSTREAM_VERSION};tensorrt=${TENSORRT_VERSION:-확인 불가};cuda=${CUDA_VERSION};package=deb"
    add_installed_software "deepstream" "system" "" "" "${SW_META}"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    return 0
}
# DeepStream 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        DeepStream Uninstallation"
    echo "========================================"
    echo ""
    if ! get_installed_deepstream;then
        print_message INFO "DeepStream이 설치되어 있지 않습니다."
        return 2
    fi
    echo "Installed : ${INSTALLED_DEEPSTREAM_PACKAGE}"
    echo "Version   : ${INSTALLED_DEEPSTREAM_VERSION}"
    echo ""
    read -p "삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "삭제를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "DeepStream을 삭제합니다."
    sudo apt-get purge -y "$INSTALLED_DEEPSTREAM_PACKAGE"
    if [ $? -ne 0 ];then
        print_message ERROR "DeepStream 삭제에 실패했습니다."
        return 1
    fi
    sudo apt-get autoremove -y>/dev/null 2>&1
    remove_installed_software "deepstream"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    return 0
}