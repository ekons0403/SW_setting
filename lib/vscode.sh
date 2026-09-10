#!/bin/bash
REQUIRE_VENV=false

VSCODE_REPO="/etc/apt/sources.list.d/vscode.list"
VSCODE_KEY="/etc/apt/trusted.gpg.d/microsoft.gpg"
VSCODE_DESKTOP="code.desktop"

setup_vscode_repository() {
    echo ""
    print_message INFO "Microsoft VS Code 저장소를 확인합니다."

    if [ ! -f "$VSCODE_KEY" ];then
        print_message INFO "Microsoft GPG Key를 등록합니다."

        TMP_GPG=$(mktemp)

        if ! wget -qO- https://packages.microsoft.com/keys/microsoft.asc|gpg --dearmor>"$TMP_GPG";then
            print_message ERROR "Microsoft GPG Key 다운로드에 실패했습니다."
            rm -f "$TMP_GPG"
            return 1
        fi

        sudo install -o root -g root -m 644 "$TMP_GPG" "$VSCODE_KEY"
        if [ $? -ne 0 ];then
            rm -f "$TMP_GPG"
            print_message ERROR "Microsoft GPG Key 등록에 실패했습니다."
            return 1
        fi

        rm -f "$TMP_GPG"
        print_message SUCCESS "Microsoft GPG Key 등록이 완료되었습니다."
    fi

    if [ ! -f "$VSCODE_REPO" ];then
        print_message INFO "Microsoft VS Code 저장소를 등록합니다."

        echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main"|sudo tee "$VSCODE_REPO">/dev/null

        if [ $? -ne 0 ];then
            print_message ERROR "Microsoft VS Code 저장소 등록에 실패했습니다."
            return 1
        fi

        print_message SUCCESS "Microsoft VS Code 저장소 등록이 완료되었습니다."
    fi

    return 0
}

launch_vscode() {
    if [ -n "$DISPLAY" ]||[ -n "$WAYLAND_DISPLAY" ];then
        print_message INFO "VS Code를 실행합니다."
        code &
    else
        print_message INFO "GUI 환경을 찾을 수 없습니다."
        print_message INFO "VS Code 자동 실행을 건너뜁니다."
    fi
}

install_software() {
    echo ""
    echo "========================================"
    echo "          VS Code Installation"
    echo "========================================"
    echo ""

    if ! command -v apt>/dev/null 2>&1;then
        print_message ERROR "apt를 찾을 수 없습니다."
        return 1
    fi

    if command -v code>/dev/null 2>&1;then
        print_message INFO "VS Code가 이미 설치되어 있습니다."
        echo ""

        code --version

        echo ""
        add_installed_software "vscode" "system" "" "" ""

        if [ $? -ne 0 ];then
            print_message ERROR "설치 목록 등록에 실패했습니다."
            return 1
        fi

        print_message SUCCESS "VS Code 설치 목록 등록이 완료되었습니다."

        launch_vscode
        return 0
    fi

    setup_vscode_repository
    if [ $? -ne 0 ];then
        return 1
    fi

    echo ""
    print_message INFO "APT 패키지 목록을 업데이트합니다."

    sudo apt update
    if [ $? -ne 0 ];then
        print_message ERROR "APT 패키지 목록 업데이트에 실패했습니다."
        return 1
    fi

    echo ""
    print_message INFO "VS Code 설치를 시작합니다."

    sudo apt install -y code
    if [ $? -ne 0 ];then
        print_message ERROR "VS Code 설치에 실패했습니다."
        return 1
    fi

    echo ""
    print_message INFO "VS Code 설치 상태를 확인합니다."

    if ! command -v code>/dev/null 2>&1;then
        print_message ERROR "VS Code 설치 확인에 실패했습니다."
        return 1
    fi

    echo ""
    code --version

    echo ""
    add_installed_software "vscode" "system" "" "" ""

    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi

    echo ""
    print_message SUCCESS "VS Code 설치 및 등록이 완료되었습니다."

    launch_vscode
    return 0
}

uninstall_software() {
    echo ""
    echo "========================================"
    echo "          VS Code Uninstallation"
    echo "========================================"
    echo ""

    if ! dpkg -l|grep -qE '^ii\s+code\s';then
        print_message INFO "VS Code가 설치되어 있지 않습니다."
        remove_installed_software "vscode"
        return 2
    fi

    echo "VS Code 버전:"
    /usr/bin/code --version
    echo ""

    read -p "VS Code를 삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM

    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "VS Code 삭제를 취소했습니다."
        return 3
    fi

    clear_screen

    echo ""
    echo "========================================"
    echo "          VS Code Uninstallation"
    echo "========================================"
    echo ""

    print_message INFO "VS Code 삭제를 시작합니다."

    sudo apt remove -y code
    if [ $? -ne 0 ];then
        print_message ERROR "VS Code 삭제에 실패했습니다."
        return 1
    fi

    echo ""
    print_message INFO "VS Code 삭제 여부를 확인합니다."

    if dpkg -l|grep -qE '^ii\s+code\s';then
        print_message ERROR "VS Code 삭제 확인에 실패했습니다."
        return 1
    fi

    remove_installed_software "vscode"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 삭제에 실패했습니다."
        return 1
    fi

    echo ""
    print_message SUCCESS "VS Code 삭제가 완료되었습니다."
    return 0
}