#!/bin/bash

# SW 이름 정규화
normalize_sw_name() {
    local SW_NAME="$1"

    case "$SW_NAME" in
        scikit-learn)
            echo "scikit_learn"
            ;;
        *)
            echo "$SW_NAME"
            ;;
    esac
}

# 정렬된 설치 SW 목록 반환
get_sorted_installed_entries() {
    [ ! -f "$LOG_FILE" ] && return 0

    awk -F'|' '
        NF >= 2 {
            name = $1

            if (name == "scikit-learn") {
                name = "scikit_learn"
            }

            if ($2 == "system") {
                group = 1
            } else if ($2 == "conda") {
                group = 2
            } else {
                next
            }

            printf "%d|%s|%s|%s|%s|%s|%s\n", \
                group, name, $3, name, $2, $4, $5
        }
    ' "$LOG_FILE" |
        sort -t'|' -k1,1n -k2,2 -k3,3 |
        cut -d'|' -f4-
}

# 설치된 SW 목록 등록
add_installed_software() {
    local SW_NAME
    local SW_TYPE="$2"
    local ENV_NAME="$3"
    local PYTHON_VERSION="$4"
    local SW_META="$5"
    local LOG_ENTRY=""

    SW_NAME=$(normalize_sw_name "$1")

    if [ -z "$SW_NAME" ]; then
        return 1
    fi

    if [[ "$SW_TYPE" == "system" ]]; then
        # 동일한 System SW 중복 등록 방지
        if awk -F'|' -v sw="$SW_NAME" '
            {
                name = $1
                if (name == "scikit-learn") name = "scikit_learn"

                if (name == sw && $2 == "system") {
                    found = 1
                    exit
                }
            }
            END { exit !found }
        ' "$LOG_FILE"; then
            return 0
        fi

        LOG_ENTRY="${SW_NAME}|system|||${SW_META}"

    elif [[ "$SW_TYPE" == "conda" ]]; then
        if [ -z "$ENV_NAME" ]; then
            print_message ERROR "Conda 환경 이름이 없습니다."
            return 1
        fi

        # 동일한 SW와 Conda 환경 중복 등록 방지
        if awk -F'|' -v sw="$SW_NAME" -v env="$ENV_NAME" '
            {
                name = $1
                if (name == "scikit-learn") name = "scikit_learn"

                if (name == sw && $2 == "conda" && $3 == env) {
                    found = 1
                    exit
                }
            }
            END { exit !found }
        ' "$LOG_FILE"; then
            return 0
        fi

        LOG_ENTRY="${SW_NAME}|conda|${ENV_NAME}|${PYTHON_VERSION}|${SW_META}"

    else
        print_message ERROR "알 수 없는 SW 설치 유형입니다."
        return 1
    fi

    echo "$LOG_ENTRY" >> "$LOG_FILE"
    return $?
}

# 설치된 SW 목록 삭제
remove_installed_software() {
    local SW_NAME
    local ENV_NAME="$2"

    SW_NAME=$(normalize_sw_name "$1")

    if [ -z "$SW_NAME" ]; then
        return 1
    fi

    if [ ! -f "$LOG_FILE" ]; then
        return 0
    fi

    if [ -n "$ENV_NAME" ]; then
        awk -F'|' -v sw="$SW_NAME" -v env="$ENV_NAME" '
            {
                name = $1
                if (name == "scikit-learn") name = "scikit_learn"

                if (name != sw || $2 != "conda" || $3 != env) {
                    print $0
                }
            }
        ' "$LOG_FILE" > "${LOG_FILE}.tmp"
    else
        awk -F'|' -v sw="$SW_NAME" '
            {
                name = $1
                if (name == "scikit-learn") name = "scikit_learn"

                if (name != sw) {
                    print $0
                }
            }
        ' "$LOG_FILE" > "${LOG_FILE}.tmp"
    fi

    if [ $? -ne 0 ]; then
        rm -f "${LOG_FILE}.tmp"
        return 1
    fi

    mv "${LOG_FILE}.tmp" "$LOG_FILE"
    return $?
}

# 가상환경 설치 목록 전체 삭제
remove_installed_environment() {
    local ENV_NAME="$1"

    if [ -z "$ENV_NAME" ]; then
        return 1
    fi

    if [ ! -f "$LOG_FILE" ]; then
        return 0
    fi

    awk -F'|' -v env="$ENV_NAME" '
        $2 != "conda" || $3 != env
    ' "$LOG_FILE" > "${LOG_FILE}.tmp"

    if [ $? -ne 0 ]; then
        rm -f "${LOG_FILE}.tmp"
        return 1
    fi

    mv "${LOG_FILE}.tmp" "$LOG_FILE"
    return $?
}

# SW 메타데이터 출력 형식 통일
print_installed_sw_meta() {
    local SW_META="$1"
    local ITEM=""
    local KEY=""
    local VALUE=""
    local META_ITEMS=()

    [ -z "$SW_META" ] && return 0

    IFS=';' read -ra META_ITEMS <<< "$SW_META"

    for ITEM in "${META_ITEMS[@]}"; do
        [ -z "$ITEM" ] && continue

        KEY="${ITEM%%=*}"
        VALUE="${ITEM#*=}"

        case "$KEY" in
            version)
                printf "    %-12s : %s\n" "Version" "$VALUE"
                ;;
            package)
                # package 정보는 출력하지 않음
                ;;
            *)
                KEY="${KEY//_/ }"
                KEY="${KEY^}"
                printf "    %-12s : %s\n" "$KEY" "$VALUE"
                ;;
        esac
    done
}

# 설치된 SW 목록 출력
show_installed_software() {
    local BLUE='\033[0;34m'
    local NC='\033[0m'

    local SYSTEM_COUNT=0
    local CONDA_COUNT=0
    local SW_INDEX=0

    local SW_NAME=""
    local SW_TYPE=""
    local ENV_NAME=""
    local PYTHON_VERSION=""
    local SW_META=""

    echo ""
    echo "========================================"
    echo "        Installed Software"
    echo "========================================"
    echo ""

    if [ ! -f "$LOG_FILE" ] || [ ! -s "$LOG_FILE" ]; then
        print_message INFO "설치된 SW가 없습니다."
        return 0
    fi

    # 설치 유형별 개수 확인
    while IFS='|' read -r SW_NAME SW_TYPE ENV_NAME PYTHON_VERSION SW_META; do
        case "$SW_TYPE" in
            system)
                SYSTEM_COUNT=$((SYSTEM_COUNT + 1))
                ;;
            conda)
                CONDA_COUNT=$((CONDA_COUNT + 1))
                ;;
        esac
    done < <(get_sorted_installed_entries)

    # System Software
    if [ "$SYSTEM_COUNT" -gt 0 ]; then
        echo "[System Software]"
        echo "----------------------------------------"

        while IFS='|' read -r SW_NAME SW_TYPE ENV_NAME PYTHON_VERSION SW_META; do
            [ "$SW_TYPE" != "system" ] && continue

            SW_INDEX=$((SW_INDEX + 1))

            printf "${BLUE}[%d] %s${NC}\n" \
                "$SW_INDEX" "$SW_NAME"

            printf "    %-12s : %s\n" "Type" "$SW_TYPE"

            print_installed_sw_meta "$SW_META"

            echo ""
        done < <(get_sorted_installed_entries)
    fi

    # System / Conda 구분선
    if [ "$SYSTEM_COUNT" -gt 0 ] && [ "$CONDA_COUNT" -gt 0 ]; then
        echo "========================================"
        echo ""
    fi

    # Conda Software
    if [ "$CONDA_COUNT" -gt 0 ]; then
        echo "[Conda Software]"
        echo "----------------------------------------"

        while IFS='|' read -r SW_NAME SW_TYPE ENV_NAME PYTHON_VERSION SW_META; do
            [ "$SW_TYPE" != "conda" ] && continue

            SW_INDEX=$((SW_INDEX + 1))

            printf "${BLUE}[%d] %s${NC}\n" \
                "$SW_INDEX" "$SW_NAME"

            printf "    %-12s : %s\n" "Type" "$SW_TYPE"
            printf "    %-12s : %s\n" "Environment" "$ENV_NAME"
            printf "    %-12s : %s\n" "Python" "$PYTHON_VERSION"

            print_installed_sw_meta "$SW_META"

            echo ""
        done < <(get_sorted_installed_entries)
    fi

    return 0
}

# 설치된 SW 출력 번호 조회
get_installed_software_by_index() {
    local SELECT_INDEX="$1"
    local CURRENT_INDEX=0

    local SW_NAME=""
    local SW_TYPE=""
    local ENV_NAME=""
    local PYTHON_VERSION=""
    local SW_META=""

    if ! [[ "$SELECT_INDEX" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [ ! -f "$LOG_FILE" ] || [ ! -s "$LOG_FILE" ]; then
        return 1
    fi

    # 화면 출력과 동일한 정렬 순서로 번호 조회
    while IFS='|' read -r SW_NAME SW_TYPE ENV_NAME PYTHON_VERSION SW_META; do
        [ -z "$SW_NAME" ] && continue

        CURRENT_INDEX=$((CURRENT_INDEX + 1))

        if [ "$CURRENT_INDEX" -eq "$SELECT_INDEX" ]; then
            SELECTED_SW_NAME="$SW_NAME"
            SELECTED_SW_TYPE="$SW_TYPE"
            SELECTED_SW_ENV="$ENV_NAME"
            SELECTED_SW_PYTHON="$PYTHON_VERSION"
            SELECTED_SW_META="$SW_META"

            return 0
        fi
    done < <(get_sorted_installed_entries)

    return 1
}