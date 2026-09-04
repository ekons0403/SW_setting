#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=true
# JupyterLab 설치
install_software() {
    echo ""
    echo "========================================"
    echo "      JupyterLab Installation"
    echo "========================================"
    echo ""
    JUPYTER_VERSION=$("${SELECTED_VE_PATH}/bin/python" -m pip show jupyterlab 2>/dev/null|awk '/^Version:/{print $2}')
    if [ -n "$JUPYTER_VERSION" ];then
        echo "Installed : JupyterLab"
        echo "Version   : ${JUPYTER_VERSION}"
        echo "Environment : ${SELECTED_VE}"
        print_message INFO "JupyterLab이 이미 설치되어 있습니다."
        add_installed_software "jupyter_lab" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "jupyterlab=${JUPYTER_VERSION};package=jupyterlab"
        return 2
    fi
    echo "JupyterLab : 설치되지 않음"
    echo ""
    read -p "JupyterLab을 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "JupyterLab 설치를 시작합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip install jupyterlab
    if [ $? -ne 0 ];then
        print_message ERROR "JupyterLab 설치에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "JupyterLab 설치를 확인합니다."
    JUPYTER_VERSION=$("${SELECTED_VE_PATH}/bin/python" -m pip show jupyterlab 2>/dev/null|awk '/^Version:/{print $2}')
    if [ -z "$JUPYTER_VERSION" ];then
        print_message ERROR "JupyterLab 설치를 확인할 수 없습니다."
        return 1
    fi
    echo ""
    echo "JupyterLab : ${JUPYTER_VERSION}"
    SW_META="jupyterlab=${JUPYTER_VERSION};package=jupyterlab"
    add_installed_software "jupyter_lab" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "${SW_META}"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    return 0
}
# JupyterLab 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "      JupyterLab Uninstallation"
    echo "========================================"
    echo ""
    if [ -z "$SELECTED_VE_PATH" ]||[ ! -x "${SELECTED_VE_PATH}/bin/python" ];then
        print_message ERROR "선택된 가상환경을 확인할 수 없습니다."
        return 1
    fi
    JUPYTER_VERSION=$("${SELECTED_VE_PATH}/bin/python" -m pip show jupyterlab 2>/dev/null|awk '/^Version:/{print $2}')
    if [ -z "$JUPYTER_VERSION" ];then
        print_message INFO "선택된 가상환경에 JupyterLab이 설치되어 있지 않습니다."
        return 2
    fi
    echo "Installed : JupyterLab"
    echo "Version   : ${JUPYTER_VERSION}"
    echo "Environment : ${SELECTED_VE}"
    echo ""
    read -p "JupyterLab을 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "삭제를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "JupyterLab을 삭제합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y jupyterlab
    if [ $? -ne 0 ];then
        print_message ERROR "JupyterLab 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "JupyterLab 삭제 여부를 확인합니다."
    if "${SELECTED_VE_PATH}/bin/python" -m pip show jupyterlab>/dev/null 2>&1;then
        print_message ERROR "JupyterLab이 아직 설치되어 있습니다."
        return 1
    fi
    remove_installed_software "jupyter_lab" "${SELECTED_VE}"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    return 0
}