#!/bin/bash
#가상환경 여부
REQUIRE_VENV=false
#서버 정보
get_system_info() {
    UBUNTU_VERSION=$(lsb_release -ds 2>/dev/null)
    UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null)
    [ -z "$UBUNTU_VERSION" ]&&UBUNTU_VERSION="확인 불가"
    [ -z "$UBUNTU_CODENAME" ]&&UBUNTU_CODENAME="확인 불가"
}
# OpenFOAM 버전 확인
check_openfoam_version() {
    OPENFOAM_PACKAGE="openfoam${OPENFOAM_VERSION}"
    if ! apt-cache show "$OPENFOAM_PACKAGE" >/dev/null 2>&1;then
        return 1
    fi
    return 0
}
# Repository 등록
setup_repository() {
    echo ""
    echo "[INFO] OpenFOAM Repository를 설정합니다."
    sudo sh -c "wget -O - https://dl.openfoam.org/gpg.key > /etc/apt/trusted.gpg.d/openfoam.asc"
    if [ $? -ne 0 ];then
        echo "[ERROR] OpenFOAM GPG Key 등록에 실패했습니다."
        return 1
    fi
    sudo rm -f /etc/apt/sources.list.d/*dl_openfoam_org*list
    sudo add-apt-repository "http://dl.openfoam.org/ubuntu main dev"
    if [ $? -ne 0 ];then
        echo "[ERROR] OpenFOAM Repository 등록에 실패했습니다."
        return 1
    fi
    sudo apt update
    if [ $? -ne 0 ];then
        echo "[ERROR] apt 업데이트에 실패했습니다."
        return 1
    fi
    return 0
}
# openfoam 설치
install_software() {
    get_system_info
    echo ""
    echo "========================================"
    echo "        System Information"
    echo "========================================"
    echo ""
    echo "Ubuntu          : ${UBUNTU_VERSION}"
    echo "Ubuntu Codename : ${UBUNTU_CODENAME}"
    echo ""
    case "$UBUNTU_CODENAME" in
        jammy|noble)
            ;;
        *)
            echo "[WARNING] 현재 Ubuntu 버전은 OpenFOAM 13 공식 지원 대상이 아닐 수 있습니다."
            ;;
    esac
    echo ""
    echo "========================================"
    echo "        OpenFOAM Installation"
    echo "========================================"
    echo ""
    read -p "OpenFOAM 버전 (기본값: 13) : " OPENFOAM_VERSION
    [ -z "$OPENFOAM_VERSION" ]&&OPENFOAM_VERSION="13"
    if ! [[ "$OPENFOAM_VERSION" =~ ^[0-9]+$ ]];then
        echo "[ERROR] 올바른 OpenFOAM 버전을 입력해주세요."
        return 1
    fi
    OPENFOAM_PACKAGE="openfoam${OPENFOAM_VERSION}"
    OPENFOAM_PATH="/opt/openfoam${OPENFOAM_VERSION}"
    echo ""
    echo "[INFO] OpenFOAM 버전: ${OPENFOAM_VERSION}"
    echo "[INFO] 패키지: ${OPENFOAM_PACKAGE}"
    echo ""
    if dpkg-query -W -f='${Status}' "$OPENFOAM_PACKAGE" 2>/dev/null|grep -q "install ok installed";then
        echo "[INFO] OpenFOAM ${OPENFOAM_VERSION}이 이미 설치되어 있습니다."
        return 0
    fi
    echo "[INFO] OpenFOAM Repository를 확인합니다."
    if ! grep -R "dl.openfoam.org" /etc/apt/sources.list /etc/apt/sources.list.d/ >/dev/null 2>&1;then
        if ! setup_repository;then
            echo "[ERROR] OpenFOAM Repository 설정에 실패했습니다."
            return 1
        fi
    else
        echo "[INFO] OpenFOAM Repository가 등록되어 있습니다."
        sudo apt update
        if [ $? -ne 0 ];then
            echo "[ERROR] apt 업데이트에 실패했습니다."
            return 1
        fi
    fi
    if ! check_openfoam_version;then
        echo "[ERROR] OpenFOAM ${OPENFOAM_VERSION} 패키지를 찾을 수 없습니다."
        echo "[INFO] 현재 Ubuntu: ${UBUNTU_CODENAME}"
        echo "[INFO] 입력한 버전: ${OPENFOAM_VERSION}"
        return 1
    fi
    echo ""
    echo "========================================"
    echo "        OpenFOAM Installation Info"
    echo "========================================"
    echo ""
    echo "OpenFOAM Version : ${OPENFOAM_VERSION}"
    echo "Package          : ${OPENFOAM_PACKAGE}"
    echo "Install Path     : ${OPENFOAM_PATH}"
    echo "Ubuntu           : ${UBUNTU_VERSION}"
    echo ""
    read -p "위 설정으로 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 설치를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] OpenFOAM 설치를 시작합니다."
    sudo apt install -y "$OPENFOAM_PACKAGE"
    if [ $? -ne 0 ];then
        echo ""
        echo "[ERROR] OpenFOAM 설치에 실패했습니다."
        return 1
    fi
    if [ ! -f "${OPENFOAM_PATH}/etc/bashrc" ];then
        echo ""
        echo "[ERROR] OpenFOAM 설치 경로를 찾을 수 없습니다."
        echo "[ERROR] 경로: ${OPENFOAM_PATH}"
        return 1
    fi
    echo ""
    echo "[SUCCESS] OpenFOAM 설치가 완료되었습니다."
    echo ""
    echo "[INFO] 환경 변수를 설정합니다."
    OPENFOAM_BASHRC=". /opt/openfoam${OPENFOAM_VERSION}/etc/bashrc"
    if grep -Fqx "$OPENFOAM_BASHRC" "$HOME/.bashrc" 2>/dev/null;then
        echo "[INFO] OpenFOAM 환경 변수가 이미 등록되어 있습니다."
    else
        sed -i '/\/opt\/openfoam[0-9]*\/etc\/bashrc/d' "$HOME/.bashrc"
        echo "$OPENFOAM_BASHRC" >> "$HOME/.bashrc"
        echo "[SUCCESS] OpenFOAM 환경 변수가 등록되었습니다."
    fi
    source "$HOME/.bashrc"
    echo ""
    echo "[INFO] 설치 버전을 확인합니다."
    OPENFOAM_PROJECT=$(. "${OPENFOAM_PATH}/etc/bashrc" >/dev/null 2>&1;echo "$WM_PROJECT")
    OPENFOAM_INSTALLED_VERSION=$(. "${OPENFOAM_PATH}/etc/bashrc" >/dev/null 2>&1;echo "$WM_PROJECT_VERSION")
    FOAM_RUN_PATH=$(. "${OPENFOAM_PATH}/etc/bashrc" >/dev/null 2>&1;echo "$FOAM_RUN")
    FOAM_RUN_RESULT=$(. "${OPENFOAM_PATH}/etc/bashrc" >/dev/null 2>&1;command -v foamRun)
    echo "OpenFOAM       : ${OPENFOAM_PROJECT}"
    echo "Version        : ${OPENFOAM_INSTALLED_VERSION}"
    echo "Install Path   : ${OPENFOAM_PATH}"
    echo "foamRun        : ${FOAM_RUN_RESULT}"
    if . "${OPENFOAM_PATH}/etc/bashrc" >/dev/null 2>&1 && foamRun -help >/dev/null 2>&1;then
        echo "[SUCCESS] OpenFOAM 실행 및 동작이 확인되었습니다."
    else
        echo "[ERROR] OpenFOAM 실행 테스트에 실패했습니다."
        return 1
    fi
    SW_META="openfoam=${OPENFOAM_INSTALLED_VERSION};package=${OPENFOAM_PACKAGE};path=${OPENFOAM_PATH}"
    add_installed_software "openfoam" "system" "" "" "${SW_META}"
    if [ $? -ne 0 ];then
        echo "[ERROR] 설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] OpenFOAM 설치 및 등록이 완료되었습니다."
    return 0
}
# openfoam 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        OpenFOAM Uninstallation"
    echo "========================================"
    echo ""
    echo "[INFO] 설치된 OpenFOAM을 확인합니다."
    OPENFOAM_PACKAGES=$(dpkg-query -W -f='${binary:Package}\n' 'openfoam*' 2>/dev/null|grep -E '^openfoam[0-9]+$')
    if [ -z "$OPENFOAM_PACKAGES" ];then
        echo "[INFO] OpenFOAM이 설치되어 있지 않습니다."
        return 0
    fi
    echo ""
    echo "[INFO] 설치된 OpenFOAM:"
    echo "$OPENFOAM_PACKAGES"
    echo ""
    read -p "OpenFOAM을 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 삭제를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] OpenFOAM을 삭제합니다."
    sudo apt remove -y $OPENFOAM_PACKAGES
    if [ $? -ne 0 ];then
        echo "[ERROR] OpenFOAM 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[INFO] OpenFOAM 환경 변수를 삭제합니다."
    sed -i '/\/opt\/openfoam[0-9]*\/etc\/bashrc/d' "$HOME/.bashrc"
    source "$HOME/.bashrc"
    echo ""
    echo "[SUCCESS] OpenFOAM 삭제가 완료되었습니다."
    return 0
}