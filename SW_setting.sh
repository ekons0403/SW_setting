#!/bin/bash
# 기본 경로
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    VE_SCRIPT="${SCRIPT_DIR}/VE/VE.sh"
    LIB_DIR="${SCRIPT_DIR}/lib"
    LOG_DIR="${SCRIPT_DIR}/log"
    LOG_FILE="${LOG_DIR}/installed_sw.log"
    LOGGER_SCRIPT="${SCRIPT_DIR}/logger.sh"
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"

# 다른 스크립트 로드
    if [ ! -f "$VE_SCRIPT" ]; then
        echo "[ERROR] 가상환경 관리 스크립트를 찾을 수 없습니다."
        echo "[ERROR] 경로: ${VE_SCRIPT}"
        exit 1
    fi
    source "$VE_SCRIPT"
    UTILS_SCRIPT="${SCRIPT_DIR}/utils.sh"
    if [ ! -f "$UTILS_SCRIPT" ]; then
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

# SW Library 설치
install_library() {
    local libraries=()
    for file in "$LIB_DIR"/*.sh; do
        [ -f "$file" ] || continue
        local library
        library=$(basename "$file" .sh)
        libraries+=("$library")
    done
    echo ""
    echo "========================================"
    echo "          Installable Libraries"
    echo "========================================"
    local i=1
    for library in "${libraries[@]}"; do
        echo "  ${i}. ${library}"
        ((i++))
    done
    echo "========================================"
    echo ""
    read -p "Install Library : " LIBRARY
    if [ -z "$LIBRARY" ]; then
        echo "[ERROR] 설치할 라이브러리를 입력해주세요."
        return 1
    fi
    echo ""
    echo "[INFO] 선택한 라이브러리: ${LIBRARY}"
    LIBRARY=$(to_lower "$LIBRARY")
    MODULE=$(get_library_module "$LIBRARY")
    if [ -z "$MODULE" ];then
        echo "[ERROR] 설치 가능한 라이브러리가 아닙니다."
        return 1
    fi
    echo "[INFO] 설치 모듈 확인: ${MODULE}"
    # 인터넷 연결 확인
    if check_internet; then
        echo "[SUCCESS] 인터넷 연결이 확인되었습니다."
    else
        echo "[ERROR] 인터넷 연결 상태를 확인한 후 다시 실행해주세요."
        return 1
    fi
    #모듈
    if ! load_module_function "$MODULE" install_software;then
    echo "[ERROR] install_software 함수를 찾을 수 없습니다."
    echo "[ERROR] 모듈: ${MODULE}"
    return 1
    fi
    # 가상환경 필요 여부 확인
    if ! select_required_venv;then
        return 1
    fi
    # SW 설치 모듈 실행
    echo "[INFO] ${LIBRARY} 설치를 시작합니다."
    install_software
    if [ $? -ne 0 ]; then
        echo "[ERROR] ${LIBRARY} 설치에 실패했습니다."
        return 1
    fi
    echo "[SUCCESS] ${LIBRARY} 설치가 완료되었습니다."
    return 0
}

# SW Library 삭제
uninstall_library() {
    show_installed_software
    echo ""
    read -p "Uninstall Library : " LIBRARY
    if [ -z "$LIBRARY" ]; then
        echo "[ERROR] 삭제할 라이브러리를 입력해주세요."
        return 1
    fi
    echo ""
    echo "[INFO] 선택한 라이브러리: ${LIBRARY}"
    LIBRARY=$(to_lower "$LIBRARY")
    MODULE=$(get_library_module "$LIBRARY")
    if [ -z "$MODULE" ];then
        echo "[ERROR] 해당 라이브러리 모듈을 찾을 수 없습니다."
        return 1
    fi
    echo "[INFO] 삭제 모듈 확인: ${MODULE}"
    echo "[INFO] 삭제 모듈을 찾았습니다."
    if ! load_module_function "$MODULE" uninstall_software;then
        echo "[ERROR] ${LIBRARY}에는 삭제 기능이 구현되어 있지 않습니다."
        return 1
    fi
    if ! select_required_venv;then
        return 1
    fi

    echo ""
    echo "[INFO] ${LIBRARY} 삭제를 시작합니다."
    uninstall_software
    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] ${LIBRARY} 삭제에 실패했습니다."
        return 1
    fi
    # 로그에서 삭제된 SW 제거
    remove_installed_software "$LIBRARY"
    echo ""
    echo "[SUCCESS] ${LIBRARY} 삭제가 완료되었습니다."
    return 0
}

# 메인 메뉴
main_menu() {
    while true; do
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
            1) install_library;;
            2) uninstall_library;;
            3) manage_virtual_environment;;
            4) show_installed_software;;
            5)  echo ""
                echo "[INFO] SW Setting을 종료합니다."
                exit 0;;
            *)  echo ""
                echo "[ERROR] 올바른 번호를 선택해주세요.";;
        esac
    done
}
# 프로그램 시작
main_menu