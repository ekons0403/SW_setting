#!/bin/bash
# 설치된 SW 목록 등록
add_installed_software() {
    local SW_NAME="$1"
    local SW_TYPE="$2"
    local ENV_NAME="$3"
    local PYTHON_VERSION="$4"
    local SW_META="$5"
    if [[ "$SW_TYPE" == "system" ]];then
        local LOG_ENTRY="${SW_NAME}|system|||${SW_META}"
        if grep -Fxq "$LOG_ENTRY" "$LOG_FILE";then
            return 0
        fi
        echo "$LOG_ENTRY">>"$LOG_FILE"
        return 0
    fi
    if [[ "$SW_TYPE" == "conda" ]];then
        local LOG_ENTRY="${SW_NAME}|conda|${ENV_NAME}|${PYTHON_VERSION}|${SW_META}"
        if grep -Fxq "$LOG_ENTRY" "$LOG_FILE";then
            return 0
        fi
        echo "$LOG_ENTRY">>"$LOG_FILE"
        return 0
    fi
    print_message ERROR "알 수 없는 SW 설치 유형입니다."
    return 1
}
# 설치된 SW 목록 삭제
remove_installed_software() {
    local SW_NAME="$1"
    local ENV_NAME="$2"
    if [ -z "$SW_NAME" ];then
        return 1
    fi
    if [ ! -f "$LOG_FILE" ];then
        return 0
    fi
    if [ -n "$ENV_NAME" ];then
        awk -F'|' -v sw="$SW_NAME" -v env="$ENV_NAME" '$1!=sw||$2!="conda"||$3!=env' "$LOG_FILE" > "${LOG_FILE}.tmp"
    else
        awk -F'|' -v sw="$SW_NAME" '$1!=sw' "$LOG_FILE" > "${LOG_FILE}.tmp"
    fi
    if [ $? -ne 0 ];then
        rm -f "${LOG_FILE}.tmp"
        return 1
    fi
    mv "${LOG_FILE}.tmp" "$LOG_FILE"
    return 0
}
# 가상환경 설치 목록 전체 삭제
remove_installed_environment() {
    local ENV_NAME="$1"
    if [ -z "$ENV_NAME" ];then
        return 1
    fi
    if [ ! -f "$LOG_FILE" ];then
        return 0
    fi
    awk -F'|' -v env="$ENV_NAME" '$2!="conda"||$3!=env' "$LOG_FILE" > "${LOG_FILE}.tmp"
    if [ $? -ne 0 ];then
        rm -f "${LOG_FILE}.tmp"
        return 1
    fi
    mv "${LOG_FILE}.tmp" "$LOG_FILE"
    return 0
}
# 설치된 SW 목록 출력
show_installed_software() {
    echo ""
    echo "========================================"
    echo "        Installed Software"
    echo "========================================"
    echo ""
    if [ ! -f "$LOG_FILE" ]||[ ! -s "$LOG_FILE" ];then
        print_message INFO "설치된 SW가 없습니다."
        return 0
    fi
    SW_NAMES=()
    SW_TYPES=()
    SW_ENVS=()
    SW_PYTHONS=()
    SW_METAS=()
    SYSTEM_COUNT=0
    CONDA_COUNT=0
    while IFS='|' read -r SW_NAME SW_TYPE ENV_NAME PYTHON_VERSION SW_META;do
        [ -z "$SW_NAME" ]&&continue
        SW_NAMES+=("$SW_NAME")
        SW_TYPES+=("$SW_TYPE")
        SW_ENVS+=("$ENV_NAME")
        SW_PYTHONS+=("$PYTHON_VERSION")
        SW_METAS+=("$SW_META")
        case "$SW_TYPE" in
            system)SYSTEM_COUNT=$((SYSTEM_COUNT+1));;
            conda)CONDA_COUNT=$((CONDA_COUNT+1));;
        esac
    done < "$LOG_FILE"
    if [ ${#SW_NAMES[@]} -eq 0 ];then
        print_message INFO "설치된 SW가 없습니다."
        return 0
    fi
    SW_INDEX=0
    if [ "$SYSTEM_COUNT" -gt 0 ];then
        echo "[System Software]"
        echo "----------------------------------------"
        for i in "${!SW_NAMES[@]}";do
            [ "${SW_TYPES[$i]}" != "system" ]&&continue
            SW_INDEX=$((SW_INDEX+1))
            echo "[${SW_INDEX}] ${SW_NAMES[$i]}"
            echo "    Type        : ${SW_TYPES[$i]}"
            if [ -n "${SW_METAS[$i]}" ];then
                print_sw_meta "${SW_METAS[$i]}"
            fi
            echo ""
        done
    fi
    if [ "$SYSTEM_COUNT" -gt 0 ]&&[ "$CONDA_COUNT" -gt 0 ];then
        echo "========================================"
        echo ""
    fi
    if [ "$CONDA_COUNT" -gt 0 ];then
        echo "[Conda Software]"
        echo "----------------------------------------"
        for i in "${!SW_NAMES[@]}";do
            [ "${SW_TYPES[$i]}" != "conda" ]&&continue
            SW_INDEX=$((SW_INDEX+1))
            echo "[${SW_INDEX}] ${SW_NAMES[$i]}"
            echo "    Type        : ${SW_TYPES[$i]}"
            echo "    Environment : ${SW_ENVS[$i]}"
            echo "    Python      : ${SW_PYTHONS[$i]}"
            if [ -n "${SW_METAS[$i]}" ];then
                print_sw_meta "${SW_METAS[$i]}"
            fi
            echo ""
        done
    fi
    return 0
}
# 설치된 SW 출력 번호 조회
get_installed_software_by_index() {
    local SELECT_INDEX="$1"
    local CURRENT_INDEX=0
    local SW_NAME SW_TYPE ENV_NAME PYTHON_VERSION SW_META
    local SYSTEM_NAMES=()
    local SYSTEM_TYPES=()
    local SYSTEM_ENVS=()
    local SYSTEM_PYTHONS=()
    local SYSTEM_METAS=()
    local CONDA_NAMES=()
    local CONDA_TYPES=()
    local CONDA_ENVS=()
    local CONDA_PYTHONS=()
    local CONDA_METAS=()
    if ! [[ "$SELECT_INDEX" =~ ^[0-9]+$ ]];then
        return 1
    fi
    if [ ! -f "$LOG_FILE" ]||[ ! -s "$LOG_FILE" ];then
        return 1
    fi
    while IFS='|' read -r SW_NAME SW_TYPE ENV_NAME PYTHON_VERSION SW_META;do
        [ -z "$SW_NAME" ]&&continue
        if [ "$SW_TYPE" == "system" ];then
            SYSTEM_NAMES+=("$SW_NAME")
            SYSTEM_TYPES+=("$SW_TYPE")
            SYSTEM_ENVS+=("$ENV_NAME")
            SYSTEM_PYTHONS+=("$PYTHON_VERSION")
            SYSTEM_METAS+=("$SW_META")
        elif [ "$SW_TYPE" == "conda" ];then
            CONDA_NAMES+=("$SW_NAME")
            CONDA_TYPES+=("$SW_TYPE")
            CONDA_ENVS+=("$ENV_NAME")
            CONDA_PYTHONS+=("$PYTHON_VERSION")
            CONDA_METAS+=("$SW_META")
        fi
    done < "$LOG_FILE"
    for i in "${!SYSTEM_NAMES[@]}";do
        CURRENT_INDEX=$((CURRENT_INDEX+1))
        if [ "$CURRENT_INDEX" -eq "$SELECT_INDEX" ];then
            SELECTED_SW_NAME="${SYSTEM_NAMES[$i]}"
            SELECTED_SW_TYPE="${SYSTEM_TYPES[$i]}"
            SELECTED_SW_ENV="${SYSTEM_ENVS[$i]}"
            SELECTED_SW_PYTHON="${SYSTEM_PYTHONS[$i]}"
            SELECTED_SW_META="${SYSTEM_METAS[$i]}"
            return 0
        fi
    done
    for i in "${!CONDA_NAMES[@]}";do
        CURRENT_INDEX=$((CURRENT_INDEX+1))
        if [ "$CURRENT_INDEX" -eq "$SELECT_INDEX" ];then
            SELECTED_SW_NAME="${CONDA_NAMES[$i]}"
            SELECTED_SW_TYPE="${CONDA_TYPES[$i]}"
            SELECTED_SW_ENV="${CONDA_ENVS[$i]}"
            SELECTED_SW_PYTHON="${CONDA_PYTHONS[$i]}"
            SELECTED_SW_META="${CONDA_METAS[$i]}"
            return 0
        fi
    done
    return 1
}