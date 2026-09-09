#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=true
# scikit-learn 설치 여부
get_installed_scikit_learn() {
    INSTALLED_SCIKIT_LEARN_VERSION=$("${SELECTED_VE_PATH}/bin/python" -m pip show scikit-learn 2>/dev/null|awk '/^Version:/{print $2}')
    if [ -n "$INSTALLED_SCIKIT_LEARN_VERSION" ];then
        return 0
    fi
    return 1
}
# scikit-learn 설치
install_software() {
    echo ""
    echo "========================================"
    echo "        scikit-learn Installation"
    echo "========================================"
    echo ""
    if get_installed_scikit_learn;then
        echo "Installed           : scikit-learn"
        echo "Version             : ${INSTALLED_SCIKIT_LEARN_VERSION}"
        echo "Conda Environment   : ${SELECTED_VE}"
        echo "Python Version      : ${SELECTED_PYTHON_VERSION}"
        print_message INFO "scikit-learn이 이미 설치되어 있습니다."
        return 2
    fi
    echo "Conda Environment   : ${SELECTED_VE}"
    echo "Python Version      : ${SELECTED_PYTHON_VERSION}"
    echo ""
    read -p "scikit-learn을 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "scikit-learn 설치를 시작합니다."
    echo ""
    "${SELECTED_VE_PATH}/bin/python" -m pip install scikit-learn
    if [ $? -ne 0 ];then
        print_message ERROR "scikit-learn 설치에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "scikit-learn 설치 상태를 확인합니다."
    if ! get_installed_scikit_learn;then
        print_message ERROR "scikit-learn 설치 확인에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "scikit-learn 동작 상태를 확인합니다."
    "${SELECTED_VE_PATH}/bin/python" -c "import sklearn; print('scikit-learn import: OK')"
    if [ $? -ne 0 ];then
        print_message ERROR "scikit-learn import에 실패했습니다."
        return 1
    fi
    echo ""
    echo "scikit-learn Version : ${INSTALLED_SCIKIT_LEARN_VERSION}"
    echo "Conda Environment   : ${SELECTED_VE}"
    echo "Python Version      : ${SELECTED_PYTHON_VERSION}"
    echo ""
    print_message SUCCESS "scikit-learn 정상 동작이 확인되었습니다."
    SW_META="version=${INSTALLED_SCIKIT_LEARN_VERSION};package=scikit-learn"
    add_installed_software "scikit-learn" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "${SW_META}"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    print_message SUCCESS "scikit-learn 설치 및 등록이 완료되었습니다."
    return 0
}
# scikit-learn 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        scikit-learn Uninstallation"
    echo "========================================"
    echo ""
    if [ -z "$SELECTED_VE_PATH" ]||[ ! -x "${SELECTED_VE_PATH}/bin/python" ];then
        print_message ERROR "선택된 가상환경을 확인할 수 없습니다."
        return 1
    fi
    if ! get_installed_scikit_learn;then
        print_message INFO "선택된 가상환경에 scikit-learn이 설치되어 있지 않습니다."
        return 2
    fi
    echo "Installed           : scikit-learn"
    echo "Version             : ${INSTALLED_SCIKIT_LEARN_VERSION}"
    echo "Conda Environment   : ${SELECTED_VE}"
    echo "Python Version      : ${SELECTED_PYTHON_VERSION}"
    echo ""
    read -p "scikit-learn을 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "삭제를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "scikit-learn 삭제를 시작합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y scikit-learn
    if [ $? -ne 0 ];then
        print_message ERROR "scikit-learn 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "scikit-learn 삭제 여부를 확인합니다."
    if get_installed_scikit_learn;then
        print_message ERROR "scikit-learn이 아직 설치되어 있습니다."
        return 1
    fi
    remove_installed_software "scikit-learn" "${SELECTED_VE}"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    print_message SUCCESS "scikit-learn 삭제가 완료되었습니다."
    return 0
}