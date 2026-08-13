#!/bin/bash
REQUIRE_VENV=false
launch_pycharm() {
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        echo "[INFO] PyCharm을 실행합니다."
        pycharm-community &
    else
        echo "[INFO] GUI 환경을 찾을 수 없습니다."
        echo "[INFO] PyCharm 자동 실행을 건너뜁니다."
    fi
}
install_software() {
    echo ""
    echo "========================================"
    echo "          PyCharm Installation"
    echo "========================================"
    echo ""
    echo "[INFO] PyCharm Community Edition 설치를 시작합니다."
    echo ""
    if ! command -v snap &>/dev/null; then
        echo "[ERROR] Snap이 설치되어 있지 않습니다."
        return 1
    fi
    if snap list pycharm-community &>/dev/null; then
        echo "[INFO] PyCharm Community Edition이 이미 설치되어 있습니다."
        echo ""
        pycharm-community --version 2>/dev/null || true
        echo ""
        echo "[INFO] 설치 목록에 등록합니다."
        SW_META=""
        add_installed_software \
            "pycharm" "system" "" "" "${SW_META}"
        if [ $? -ne 0 ]; then
            echo "[ERROR] 설치 목록 등록에 실패했습니다."
            return 1
        fi
        echo ""
        echo "[SUCCESS] PyCharm 설치 및 등록이 완료되었습니다."
        echo ""
        add_pycharm_to_dock
        launch_pycharm
        return 0
    fi
    sudo snap install pycharm-community --classic
    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] PyCharm 설치에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[INFO] PyCharm 설치 상태를 확인합니다."
    if ! snap list pycharm-community &>/dev/null; then
        echo "[ERROR] PyCharm 설치 확인에 실패했습니다."
        return 1
    fi
    echo ""
    pycharm-community --version 2>/dev/null || true
    echo ""
    echo "[INFO] 설치 목록에 등록합니다."
    SW_META=""
    add_installed_software \
        "pycharm" "system" "" "" "${SW_META}"
    if [ $? -ne 0 ]; then
        echo "[ERROR] 설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] PyCharm 설치 및 등록이 완료되었습니다."
    echo ""
    add_pycharm_to_dock
    launch_pycharm
    return 0
}
uninstall_software() {
    echo ""
    echo "========================================"
    echo "          PyCharm Uninstallation"
    echo "========================================"
    echo ""
    if ! snap list pycharm-community &>/dev/null; then
        echo "[INFO] PyCharm이 설치되어 있지 않습니다."
        return 0
    fi
    read -p "PyCharm을 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[INFO] PyCharm 삭제를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] PyCharm 삭제를 시작합니다."
    sudo snap remove pycharm-community
    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] PyCharm 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    if snap list pycharm-community &>/dev/null; then
        echo "[ERROR] PyCharm 삭제 확인에 실패했습니다."
        return 1
    fi
    echo "[SUCCESS] PyCharm 삭제가 완료되었습니다."
    return 0
}