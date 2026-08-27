#!/bin/bash
#가상환경 여부
REQUIRE_VENV=true
#서버 정보
get_system_info() {
    PYTHON_VERSION=$("${SELECTED_VE_PATH}/bin/python" --version 2>/dev/null|awk '{print $2}')
    [ -z "$PYTHON_VERSION" ]&&PYTHON_VERSION="확인 불가"
}
# jupyter lab 설치
install_software() {
    get_system_info
    echo ""
    echo "========================================"
    echo "        System Information"
    echo "========================================"
    echo ""
    echo "Conda Environment : ${SELECTED_VE}"
    echo "Python            : ${PYTHON_VERSION}"
    echo ""
    read -p "JupyterLab을 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 설치를 취소했습니다."
        return 0
    fi
    echo ""
    echo "========================================"
    echo "        JupyterLab Installation Info"
    echo "========================================"
    echo ""
    echo "Conda Environment : ${SELECTED_VE}"
    echo "Python Version    : ${PYTHON_VERSION}"
    echo ""
    echo "[INFO] JupyterLab 설치를 시작합니다."
    echo ""
    "${SELECTED_VE_PATH}/bin/python" -m pip install jupyterlab
    if [ $? -ne 0 ];then
        echo ""
        echo "[ERROR] JupyterLab 설치에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] JupyterLab 설치가 완료되었습니다."
    echo ""
    echo "[INFO] 설치 버전을 확인합니다."
    JUPYTERLAB_VERSION=$("${SELECTED_VE_PATH}/bin/jupyter" lab --version 2>/dev/null)
    if [ -z "$JUPYTERLAB_VERSION" ];then
        echo "[ERROR] JupyterLab 버전을 확인할 수 없습니다."
        return 1
    fi
    echo "JupyterLab: ${JUPYTERLAB_VERSION}"
    echo "[SUCCESS] JupyterLab 설치 확인이 완료되었습니다."
    echo ""
    echo "[INFO] JupyterLab 실행 테스트를 시작합니다."
    JUPYTER_LOG="/tmp/jupyter_lab_test.log"
    "${SELECTED_VE_PATH}/bin/jupyter" lab --no-browser --ip=127.0.0.1 --port=8888 --ServerApp.token="" --ServerApp.password="" >"${JUPYTER_LOG}" 2>&1 &
    JUPYTER_PID=$!
    JUPYTER_READY=false
    for i in {1..10};do
        sleep 1
        if curl -s --max-time 2 http://127.0.0.1:8888/lab >/dev/null 2>&1;then
            JUPYTER_READY=true
            break
        fi
        if ! kill -0 "$JUPYTER_PID" 2>/dev/null;then
            break
        fi
    done
    if [[ "$JUPYTER_READY" == "true" ]];then
        echo "[SUCCESS] JupyterLab 실행 및 접속 테스트가 완료되었습니다."
    else
        echo "[WARNING] JupyterLab 설치는 완료되었지만 실행 테스트에 실패했습니다."
        if [ -f "$JUPYTER_LOG" ];then
            tail -n 10 "$JUPYTER_LOG"
        fi
        kill "$JUPYTER_PID" 2>/dev/null
        wait "$JUPYTER_PID" 2>/dev/null
        rm -f "$JUPYTER_LOG"
        return 1
    fi
    kill "$JUPYTER_PID" 2>/dev/null
    wait "$JUPYTER_PID" 2>/dev/null
    rm -f "$JUPYTER_LOG"
    SW_META="jupyterlab=${JUPYTERLAB_VERSION}"
    add_installed_software "jupyter_lab" "conda" "${SELECTED_VE}" "${PYTHON_VERSION}" "${SW_META}"
    if [ $? -ne 0 ];then
        echo "[ERROR] 설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] JupyterLab 설치 및 등록이 완료되었습니다."
    return 0
}
# jupyter lab 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "        JupyterLab Uninstallation"
    echo "========================================"
    echo ""
    echo "[INFO] 선택된 가상환경: ${SELECTED_VE}"
    echo "[INFO] Python 버전: ${PYTHON_VERSION}"
    echo "[INFO] 경로: ${SELECTED_VE_PATH}"
    echo ""
    if ! "${SELECTED_VE_PATH}/bin/jupyter" lab --version >/dev/null 2>&1;then
        echo "[INFO] 해당 가상환경에 JupyterLab이 설치되어 있지 않습니다."
        return 0
    fi
    JUPYTERLAB_VERSION=$("${SELECTED_VE_PATH}/bin/jupyter" lab --version 2>/dev/null)
    echo "[INFO] 설치된 JupyterLab: ${JUPYTERLAB_VERSION}"
    echo ""
    read -p "JupyterLab을 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        echo "[INFO] 삭제를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] JupyterLab을 삭제합니다."
    "${SELECTED_VE_PATH}/bin/python" -m pip uninstall -y jupyterlab
    if [ $? -ne 0 ];then
        echo "[ERROR] JupyterLab 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] JupyterLab 삭제가 완료되었습니다."
    return 0
}