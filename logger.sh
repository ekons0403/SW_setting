#!/bin/bash
# SW 설치 목록 추가
add_installed_software() {
    local SW_NAME="$1"
    local SW_TYPE="$2"
    local ENV_NAME="$3"
    local PYTHON_VERSION="$4"
    local SW_META="$5"

    if [[ "$SW_TYPE" == "system" ]]; then
        local LOG_ENTRY="${SW_NAME}|system|||${SW_META}"

        if grep -Fxq "$LOG_ENTRY" "$LOG_FILE"; then
            echo "[INFO] ${SW_NAME}은 설치 목록에 등록되어 있습니다."
            return 0
        fi

        echo "$LOG_ENTRY" >> "$LOG_FILE"
        echo "[INFO] 설치 목록에 ${SW_NAME}을(를) 추가했습니다."
        return 0
    fi

    if [[ "$SW_TYPE" == "conda" ]]; then
        local LOG_ENTRY="${SW_NAME}|conda|${ENV_NAME}|${PYTHON_VERSION}|${SW_META}"

        if grep -Fxq "$LOG_ENTRY" "$LOG_FILE"; then
            echo "[INFO] ${SW_NAME}은(는) ${ENV_NAME} 환경에 이미 등록되어 있습니다."
            return 0
        fi

        echo "$LOG_ENTRY" >> "$LOG_FILE"

        echo "[INFO] 설치 목록에 추가했습니다."
        echo "[INFO] SW: ${SW_NAME}"
        echo "[INFO] 환경: ${ENV_NAME}"
        echo "[INFO] Python: ${PYTHON_VERSION}"
        return 0
    fi

    echo "[ERROR] 알 수 없는 SW 설치 유형입니다."
    return 1
}

# 설치 목록 출력
show_installed_software() {

    echo ""
    echo "========================================"
    echo "        Installed SW List"
    echo "========================================"
    echo ""

    if [ ! -s "$LOG_FILE" ]; then
        echo "[INFO] 설치된 SW가 없습니다."
        return 0
    fi

    echo "[System]"
    echo ""

    while IFS='|' read -r SW_NAME SW_TYPE ENV_NAME PYTHON_VERSION SW_META; do
        if [[ "$SW_TYPE" == "system" ]]; then
            echo "- ${SW_NAME}"
            print_sw_meta "$SW_META"
            echo ""
        fi
    done < "$LOG_FILE"

    echo ""
    echo "[Conda Environment]"
    echo ""

    while IFS='|' read -r SW_NAME SW_TYPE ENV_NAME PYTHON_VERSION SW_META; do
        if [[ "$SW_TYPE" == "conda" ]]; then
            echo "- ${SW_NAME}"
            echo "  Environment : ${ENV_NAME}"
            echo "  Python      : ${PYTHON_VERSION}"
            print_sw_meta "$SW_META"
            echo ""
        fi
    done < "$LOG_FILE"
}

# 설치 목록 제거
remove_installed_software() {
    local SW_NAME="$1"
    local VE_NAME="$2"

    if [ -n "$VE_NAME" ]; then
        grep -v "^${SW_NAME}|.*|${VE_NAME}|" "$LOG_FILE" > "${LOG_FILE}.tmp"
    else
        grep -v "^${SW_NAME}|" "$LOG_FILE" > "${LOG_FILE}.tmp"
    fi

    mv "${LOG_FILE}.tmp" "$LOG_FILE"
}

# 설치 목록 검증
validate_installed_software() {

    [ ! -f "$LOG_FILE" ] && return

    local TMP="${LOG_FILE}.tmp"
    > "$TMP"

    while IFS='|' read -r NAME ENV_TYPE ENV_NAME PYTHON_VERSION SW_META; do

        [ -z "$NAME" ] && continue

        case "$NAME" in

            docker)
                command -v docker >/dev/null 2>&1 &&
                echo "$NAME|$ENV_TYPE|$ENV_NAME|$PYTHON_VERSION|$SW_META" >> "$TMP"
                ;;

            nvidia-container-toolkit)
                command -v nvidia-ctk >/dev/null 2>&1 &&
                echo "$NAME|$ENV_TYPE|$ENV_NAME|$PYTHON_VERSION|$SW_META" >> "$TMP"
                ;;

            pytorch)
                if [ "$ENV_TYPE" = "conda" ]; then
                    VE_PATH=$(conda env list | awk -v env="$ENV_NAME" '$1==env {print $NF}')

                    if [ -n "$VE_PATH" ] &&
                       "$VE_PATH/bin/python" -c "import torch" >/dev/null 2>&1; then
                        echo "$NAME|$ENV_TYPE|$ENV_NAME|$PYTHON_VERSION|$SW_META" >> "$TMP"
                    fi
                fi
                ;;

            *)
                echo "$NAME|$ENV_TYPE|$ENV_NAME|$PYTHON_VERSION|$SW_META" >> "$TMP"
                ;;

        esac

    done < "$LOG_FILE"

    sort -u "$TMP" -o "$LOG_FILE"
}