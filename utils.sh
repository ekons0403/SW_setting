#!/bin/bash
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
    echo ""
    echo "[INFO] 이 라이브러리는 가상환경이 필요합니다."
    select_virtual_environment
    if [ $? -ne 0 ];then
        echo ""
        echo "[ERROR] 가상환경을 선택하지 못했습니다."
        return 1
    fi
    echo ""
    echo "[INFO] 선택된 가상환경: ${SELECTED_VE}"
    echo "[INFO] Python 버전: ${SELECTED_PYTHON_VERSION}"
    echo "[INFO] 경로: ${SELECTED_VE_PATH}"
}
# 모듈
load_module_function() {
    local MODULE="$1"
    local FUNCTION="$2"
    source "$MODULE"
    declare -F "$FUNCTION">/dev/null
}