#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=true
# scikit-learn 설치
install_software() {
    echo ""
    echo "========================================"
    echo "        scikit-learn Installation"
    echo "========================================"
    echo ""
    echo "Conda Environment : ${SELECTED_VE}"
    echo "Python Version     : ${SELECTED_PYTHON_VERSION}"
    echo ""
    read -p "scikit-learn을 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "[INFO] 설치를 취소했습니다."
    return 0
    fi
    echo ""
    echo "[INFO] scikit-learn 설치를 시작합니다."
    echo ""
    "${SELECTED_VE_PATH}/bin/python" -m pip install scikit-learn
    if [ $? -ne 0 ]; then
    echo ""
    echo "[ERROR] scikit-learn 설치에 실패했습니다."
    return 1
    fi
    echo ""
    echo "[SUCCESS] scikit-learn 설치가 완료되었습니다."
    INSTALLED_SCIKIT_LEARN_VERSION=$("${SELECTED_VE_PATH}/bin/python" -c "import sklearn; print(sklearn.__version__)" 2>/dev/null)
    if [ -z "$INSTALLED_SCIKIT_LEARN_VERSION" ]; then
    echo "[ERROR] scikit-learn import에 실패했습니다."
    return 1
    fi
    echo ""
    echo "[INFO] 설치 버전을 확인합니다."
    echo "scikit-learn Version : ${INSTALLED_SCIKIT_LEARN_VERSION}"
    "${SELECTED_VE_PATH}/bin/python" -c "import sklearn; print('scikit-learn import: OK')"
    if [ $? -ne 0 ]; then
    echo "[ERROR] scikit-learn 동작 확인에 실패했습니다."
    return 1
    fi
    echo ""
    echo "[SUCCESS] scikit-learn 정상 동작이 확인되었습니다."
    SW_META="scikit-learn=${INSTALLED_SCIKIT_LEARN_VERSION}"
    add_installed_software "scikit-learn" "conda" "${SELECTED_VE}" "${SELECTED_PYTHON_VERSION}" "${SW_META}"
    if [ $? -ne 0 ]; then
    echo "[ERROR] 설치 목록 등록에 실패했습니다."
    return 1
    fi
    echo ""
    echo "[SUCCESS] scikit-learn 설치 및 등록이 완료되었습니다."
    return 0
}
# scikit-learn 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        scikit-learn Uninstallation"
    echo "========================================"
    echo ""
    echo "[INFO] 선택된 가상환경: ${SELECTED_VE}"
    echo "[INFO] Python 버전: ${SELECTED_PYTHON_VERSION}"
    echo "[INFO] 경로: ${SELECTED_VE_PATH}"
    echo ""
    if ! "${SELECTED_VE_PATH}/bin/python" -m pip show scikit-learn >/dev/null 2>&1; then
        echo "[INFO] 해당 가상환경에 scikit-learn이 설치되어 있지 않습니다."
        return 0
    fi
    SCIKIT_LEARN_VERSION=$("${SELECTED_VE_PATH}/bin/python" -m pip show scikit-learn | awk '/^Version:/{print $2}')
    echo "[INFO] 설치된 scikit-learn: ${SCIKIT_LEARN_VERSION}"
    echo ""
    read -p "scikit-learn을 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "[INFO] 삭제를 취소했습니다."
    return 0
    fi
    echo ""
    echo "[INFO] scikit-learn을 삭제합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y scikit-learn
    if [ $? -ne 0 ]; then
    echo "[ERROR] scikit-learn 삭제에 실패했습니다."
    return 1
    fi
    remove_installed_software "scikit-learn" "${SELECTED_VE}"
    echo ""
    echo "[SUCCESS] scikit-learn 삭제가 완료되었습니다."
    return 0
}