#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=false
# PyCharm 설치 여부
get_installed_pycharm() {
    if snap list pycharm-community >/dev/null 2>&1;then
        return 0
    fi
    return 1
}
# PyCharm Dock 등록
add_pycharm_to_dock() {
    if ! command -v gsettings >/dev/null 2>&1;then
        return 0
    fi
    if [ -z "$DISPLAY" ]&&[ -z "$WAYLAND_DISPLAY" ];then
        return 0
    fi
    CURRENT_FAVORITES=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null)
    if echo "$CURRENT_FAVORITES"|grep -q "pycharm-community";then
        return 0
    fi
    return 0
}
# PyCharm 실행
launch_pycharm() {
    if [ -n "$DISPLAY" ]||[ -n "$WAYLAND_DISPLAY" ];then
        print_message INFO "PyCharm을 실행합니다."
        pycharm-community &
    else
        print_message INFO "GUI 환경을 찾을 수 없습니다."
        print_message INFO "PyCharm 자동 실행을 건너뜁니다."
    fi
}
# PyCharm 설치
install_software() {
    echo ""
    echo "========================================"
    echo "          PyCharm Installation"
    echo "========================================"
    echo ""
    if ! command -v snap >/dev/null 2>&1;then
        print_message ERROR "Snap이 설치되어 있지 않습니다."
        return 1
    fi
    if get_installed_pycharm;then
        echo "Installed : PyCharm Community Edition"
        echo "Package   : pycharm-community"
        echo ""
        pycharm-community --version 2>/dev/null||true
        print_message INFO "PyCharm Community Edition이 이미 설치되어 있습니다."
        return 2
    fi
    echo ""
    print_message INFO "PyCharm Community Edition 설치를 시작합니다."
    echo ""
    read -p "PyCharm을 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi
    echo ""
    sudo snap install pycharm-community --classic
    if [ $? -ne 0 ];then
        print_message ERROR "PyCharm 설치에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "PyCharm 설치 상태를 확인합니다."
    if ! get_installed_pycharm;then
        print_message ERROR "PyCharm 설치 확인에 실패했습니다."
        return 1
    fi
    echo ""
    pycharm-community --version 2>/dev/null||true
    SW_META="package=pycharm-community;install_type=snap"
    add_installed_software "pycharm" "system" "" "" "${SW_META}"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi
    echo ""
    print_message SUCCESS "PyCharm 설치 및 등록이 완료되었습니다."
    echo ""
    add_pycharm_to_dock
    launch_pycharm
    return 0
}
# PyCharm 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "          PyCharm Uninstallation"
    echo "========================================"
    echo ""
    if ! command -v snap >/dev/null 2>&1;then
        print_message ERROR "Snap이 설치되어 있지 않습니다."
        return 1
    fi
    if ! get_installed_pycharm;then
        print_message INFO "PyCharm이 설치되어 있지 않습니다."
        return 2
    fi
    echo "Installed : PyCharm Community Edition"
    echo "Package   : pycharm-community"
    echo ""
    pycharm-community --version 2>/dev/null||true
    echo ""
    read -p "PyCharm을 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "삭제를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "PyCharm 삭제를 시작합니다."
    sudo snap remove pycharm-community
    if [ $? -ne 0 ];then
        print_message ERROR "PyCharm 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "PyCharm 삭제 여부를 확인합니다."
    if get_installed_pycharm;then
        print_message ERROR "PyCharm이 아직 설치되어 있습니다."
        return 1
    fi
    remove_installed_software "pycharm"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    print_message SUCCESS "PyCharm 삭제가 완료되었습니다."
    return 0
}