#!/bin/bash
# 색상
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
# 메시지
print_message() {
    local TYPE="$1"
    local MESSAGE="$2"
    case "$TYPE" in
        INFO)echo -e "${BLUE}[INFO]${NC} ${MESSAGE}";;
        SUCCESS)echo -e "${GREEN}[SUCCESS]${NC} ${MESSAGE}";;
        WARNING)echo -e "${YELLOW}[WARNING]${NC} ${MESSAGE}";;
        ERROR)echo -e "${RED}[ERROR]${NC} ${MESSAGE}";;
        *)echo "$MESSAGE";;
    esac
}
# SW 버전 출력
print_sw_meta() {
    local SW_META="$1"
    [ -z "$SW_META" ]&&return
    IFS=';' read -ra META<<<"$SW_META"
    for ITEM in "${META[@]}";do
        printf "  %-14s : %s\n" "${ITEM%%=*}" "${ITEM#*=}"
    done
}
# SW 소문자로 입력받기
to_lower() {
    echo "$1"|tr '[:upper:]' '[:lower:]'
}
# 인터넷 연결 확인
check_internet() {
    curl -fsS --connect-timeout 5 https://www.google.com>/dev/null
}
# 공통 함수
get_library_module() {
    local LIBRARY
    LIBRARY=$(to_lower "$1")
    [ -z "$LIBRARY" ]&&return 1
    [ -f "${LIB_DIR}/${LIBRARY}.sh" ]||return 1
    echo "${LIB_DIR}/${LIBRARY}.sh"
}
# 가상환경
select_required_venv() {
    [[ "$REQUIRE_VENV" != "true" ]]&&return 0
    select_virtual_environment
    if [ $? -ne 0 ];then
        print_messaage ERROR "가상환경을 선택하지 못했습니다."
        return 1
    fi
}
# 모듈
load_module_function() {
    local MODULE="$1"
    local FUNCTION="$2"
    if [ ! -f "$MODULE" ];then
        return 1
    fi
    source "$MODULE"
    if ! declare -F "$FUNCTION" >/dev/null 2>&1;then
        return 1
    fi
    return 0
}
# 화면 초기화
clear_screen() {
    clear
}