#!/bin/bash
# 기본 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"&&pwd)"
VE_SCRIPT="${SCRIPT_DIR}/VE/VE.sh"
LIB_DIR="${SCRIPT_DIR}/lib"
LOG_DIR="${SCRIPT_DIR}/log"
LOG_FILE="${LOG_DIR}/installed_sw.log"
LOGGER_SCRIPT="${SCRIPT_DIR}/logger.sh"
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
# 다른 스크립트 로드
if [ ! -f "$VE_SCRIPT" ];then
    echo "[ERROR] 가상환경 관리 스크립트를 찾을 수 없습니다."
    echo "[ERROR] 경로: ${VE_SCRIPT}"
    exit 1
fi
source "$VE_SCRIPT"
UTILS_SCRIPT="${SCRIPT_DIR}/utils.sh"
if [ ! -f "$UTILS_SCRIPT" ];then
    echo "[ERROR] Utility 스크립트를 찾을 수 없습니다."
    exit 1
fi
source "$UTILS_SCRIPT"
if [ ! -f "$LOGGER_SCRIPT" ];then
    echo "[ERROR] 로그 관리 스크립트를 찾을 수 없습니다."
    exit 1
fi
source "$LOGGER_SCRIPT"
validate_installed_software
# 화면 대기
pause_screen() {
    read -p "계속하려면 Enter를 누르세요."
}
# SW Library 목록
get_library_list() {
    LIBRARIES=()
    for file in "$LIB_DIR"/*.sh;do
        [ -f "$file" ]||continue
        LIBRARY=$(basename "$file" .sh)
        LIBRARIES+=("$LIBRARY")
    done
}
# SW Library 번호 변환
get_library_by_number() {
    local NUMBER="$1"
    get_library_list
    if [[ "$NUMBER" =~ ^[0-9]+$ ]]&&[ "$NUMBER" -ge 1 ]&&[ "$NUMBER" -le "${#LIBRARIES[@]}" ];then
        echo "${LIBRARIES[$((NUMBER-1))]}"
        return 0
    fi
    return 1
}
# SW Library 설치
install_library() {
    clear_screen
    get_library_list
    echo ""
    echo "========================================"
    echo "          Installable Libraries"
    echo "========================================"
    local i=1
    for library in "${LIBRARIES[@]}";do
        printf "  %2d. %s\n" "$i" "$library"
        ((i++))
    done
    echo "========================================"
    echo ""
    read -p "Install Library : " LIBRARY
    if [ -z "$LIBRARY" ];then
        print_message ERROR "설치할 라이브러리를 입력해주세요."
        pause_screen
        return 1
    fi
    if [[ "$LIBRARY" =~ ^[0-9]+$ ]];then
        LIBRARY=$(get_library_by_number "$LIBRARY")
        if [ -z "$LIBRARY" ];then
            print_message ERROR "올바른 라이브러리 번호를 입력해주세요."
            pause_screen
            return 1
        fi
    fi
    LIBRARY="${LIBRARY//-/_}"
    LIBRARY=$(to_lower "$LIBRARY")
    MODULE=$(get_library_module "$LIBRARY")
    if [ -z "$MODULE" ];then
        print_message ERROR "설치 가능한 라이브러리가 아닙니다."
        pause_screen
        return 1
    fi
    if ! check_internet;then
        print_message ERROR "인터넷 연결 상태를 확인한 후 다시 실행해주세요."
        pause_screen
        return 1
    fi
    if ! load_module_function "$MODULE" install_software;then
        print_message ERROR "install_software 함수를 찾을 수 없습니다."
        pause_screen
        return 1
    fi
    if ! select_required_venv;then
        pause_screen
        return 1
    fi
    clear_screen
    install_software
    INSTALL_RESULT=$?
    case "$INSTALL_RESULT" in
        0)
            print_message SUCCESS "${LIBRARY} 설치가 완료되었습니다."
            pause_screen
            return 0
            ;;
        2)
            pause_screen
            return 0
            ;;
        3)
            pause_screen
            return 0
            ;;
        *)
            print_message ERROR "${LIBRARY} 설치에 실패했습니다."
            pause_screen
            return 1
            ;;
    esac
}
# SW Library 삭제
uninstall_library() {
    clear_screen
    show_installed_software
    echo ""
    read -p "Uninstall Library : " LIBRARY
    if [ -z "$LIBRARY" ];then
        print_message ERROR "삭제할 라이브러리를 입력해주세요."
        pause_screen
        return 1
    fi
    if [[ "$LIBRARY" =~ ^[0-9]+$ ]];then
        get_library_list
        if [ "$LIBRARY" -lt 1 ]||[ "$LIBRARY" -gt "${#LIBRARIES[@]}" ];then
            print_message ERROR "올바른 라이브러리 번호를 입력해주세요."
            pause_screen
            return 1
        fi
        LIBRARY="${LIBRARIES[$((LIBRARY-1))]}"
    fi
    LIBRARY="${LIBRARY//-/_}"
    LIBRARY=$(to_lower "$LIBRARY")
    MODULE=$(get_library_module "$LIBRARY")
    if [ -z "$MODULE" ];then
        print_message ERROR "해당 라이브러리 모듈을 찾을 수 없습니다."
        pause_screen
        return 1
    fi
    if ! load_module_function "$MODULE" uninstall_software;then
        print_message ERROR "${LIBRARY}에는 삭제 기능이 구현되어 있지 않습니다."
        pause_screen
        return 1
    fi
    if ! select_required_venv;then
        pause_screen
        return 1
    fi
    clear_screen
    uninstall_software
    UNINSTALL_RESULT=$?
    case "$UNINSTALL_RESULT" in
        0)
            ;;
        2)
            pause_screen
            return 0
            ;;
        3)
            pause_screen
            return 0
            ;;
        *)
            print_message ERROR "${LIBRARY} 삭제에 실패했습니다."
            pause_screen
            return 1
            ;;
    esac
    if [ -n "$SELECTED_VE" ];then
        remove_installed_software "$LIBRARY" "$SELECTED_VE"
    else
        remove_installed_software "$LIBRARY"
    fi
    if [ $? -ne 0 ];then
        print_message ERROR "${LIBRARY} 설치 목록 삭제에 실패했습니다."
        pause_screen
        return 1
    fi
    print_message SUCCESS "${LIBRARY} 삭제가 완료되었습니다."
    pause_screen
    return 0
}
# 메인 메뉴
main_menu() {
    while true;do
        clear_screen
        echo ""
        echo "========================================"
        echo "        SW Library Installer"
        echo "========================================"
        echo ""
        echo "1. SW Library 설치"
        echo "2. SW Library 삭제"
        echo "3. 가상환경 관리"
        echo "4. 현재 설치된 SW"
        echo "5. 종료"
        echo ""
        read -p "Select : " MAIN_SELECT
        case "$MAIN_SELECT" in
            1)
                install_library
                ;;
            2)
                uninstall_library
                ;;
            3)
                clear_screen
                manage_virtual_environment
                pause_screen
                ;;
            4)
                clear_screen
                show_installed_software
                pause_screen
                ;;
            5)
                exit 0
                ;;
            *)
                print_message ERROR "올바른 번호를 선택해주세요."
                pause_screen
                ;;
        esac
    done
}
# 프로그램 시작
main_menu
