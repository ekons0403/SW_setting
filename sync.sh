#!/bin/bash
# 동기화 대상 SW 확인
is_sync_target() {
    local SW_NAME="${1//-/_}"

    case "$SW_NAME" in
        deepstream|docker|jupyter_lab|keras|nvidia_container_toolkit|nvidia_driver|openfoam|pycharm|pytorch|scikit_learn|tensorflow|tensorrt|vscode)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 동기화 검색 결과
declare -A SYNC_FOUND

# 동기화 오류 상태
SYNC_SCAN_FAILED=0

# 동기화 로그 등록 및 기존 항목 갱신
sync_register_software() {
    local SW_NAME="${1//-/_}"
    local SW_TYPE="$2"
    local ENV_NAME="$3"
    local PYTHON_VERSION="$4"
    local SW_META="$5"
    local EXISTING=""

    if ! is_sync_target "$SW_NAME"; then
        return 1
    fi

    case "$SW_TYPE" in
        system)
            EXISTING=$(awk -F'|' -v name="$SW_NAME" '
                {
                    sw=$1
                    gsub(/-/, "_", sw)

                    if (sw == name && $2 == "system") {
                        found=1
                        exit
                    }
                }
                END {
                    if (found) print "yes"
                }
            ' "$LOG_FILE")
            ;;
        conda)
            EXISTING=$(awk -F'|' -v name="$SW_NAME" -v env="$ENV_NAME" '
                {
                    sw=$1
                    gsub(/-/, "_", sw)

                    if (sw == name && $2 == "conda" && $3 == env) {
                        found=1
                        exit
                    }
                }
                END {
                    if (found) print "yes"
                }
            ' "$LOG_FILE")
            ;;
        *)
            return 1
            ;;
    esac

    # 기존 등록 항목 제거
    if [ "$EXISTING" = "yes" ]; then
        if ! remove_installed_software "$SW_NAME" "$ENV_NAME"; then
            print_message ERROR "${SW_NAME} 기존 등록 항목 제거 실패"
            SYNC_SCAN_FAILED=1
            return 1
        fi
    fi

    # 최신 설치 정보로 다시 등록
    if add_installed_software "$SW_NAME" "$SW_TYPE" \
        "$ENV_NAME" "$PYTHON_VERSION" "$SW_META"; then

        SYNC_FOUND["${SW_NAME}|${SW_TYPE}|${ENV_NAME}"]=1

        if [ "$EXISTING" = "yes" ]; then
            printf "  \033[0;34m[갱신 등록] %s\033[0m\n" "$SW_NAME"
        else
            printf "  \033[0;32m[신규 등록] %s\033[0m\n" "$SW_NAME"
        fi

        return 0
    else
        print_message ERROR "${SW_NAME} 등록 실패"
        SYNC_SCAN_FAILED=1
        return 1
    fi
}

# Debian 패키지 설치 여부 확인
is_dpkg_installed() {
    local PACKAGE="$1"
    local STATUS=""

    STATUS=$(dpkg-query -W -f='${Status}' "$PACKAGE" 2>/dev/null)

    [ "$STATUS" = "install ok installed" ]
}

# System SW 동기화
sync_system_software() {
    local SW_VERSION=""
    local PACKAGE=""
    local CODE_PATH=""
    local DRIVER_INFO=""
    local DRIVER_PACKAGE=""
    local DRIVER_VERSION=""

    echo ""
    echo "========================================"
    echo "        System Software Sync"
    echo "========================================"

    # Docker
    if command -v docker >/dev/null 2>&1; then
        SW_VERSION=$(docker --version 2>/dev/null |
            sed 's/^Docker version //;s/,.*//')

        if [ -n "$SW_VERSION" ]; then
            sync_register_software "docker" "system" "" "" \
                "version=${SW_VERSION}"
        else
            print_message WARNING "Docker 버전을 확인할 수 없습니다."
            SYNC_SCAN_FAILED=1
        fi
    fi

    # DeepStream
    for PACKAGE in deepstream-9.1 deepstream-9.0 deepstream-8.0 deepstream-7.1; do
        if is_dpkg_installed "$PACKAGE"; then
            SW_VERSION=$(dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null)

            if [ -n "$SW_VERSION" ]; then
                sync_register_software "deepstream" "system" "" "" \
                    "version=${SW_VERSION};package=${PACKAGE}"
            else
                SYNC_SCAN_FAILED=1
            fi

            break
        fi
    done
    # NVIDIA Driver
    DRIVER_INFO=$(
        dpkg-query -W \
            -f='${db:Status-Abbrev}|${binary:Package}|${Version}\n' \
            'nvidia-driver-*' 2>/dev/null |
        awk -F'|' '
            $1 ~ /^ii/ &&
            $2 ~ /^nvidia-driver-[0-9]+(-open)?(:.*)?$/ {
                print $2 "|" $3
                exit
            }
        '
    )

    if [ -n "$DRIVER_INFO" ]; then
        DRIVER_PACKAGE="${DRIVER_INFO%%|*}"
        DRIVER_VERSION="${DRIVER_INFO#*|}"
    elif command -v nvidia-smi >/dev/null 2>&1; then
        DRIVER_PACKAGE="runfile"
        DRIVER_VERSION=$(nvidia-smi \
            --query-gpu=driver_version \
            --format=csv,noheader 2>/dev/null | head -n1 | tr -d '[:space:]')
    fi

    # Ubuntu/Debian 패키지 빌드 정보 제거
    if [ -n "$DRIVER_VERSION" ]; then
        DRIVER_VERSION=$(printf '%s\n' "$DRIVER_VERSION" |
            sed -E 's/^[0-9]+://' |
            grep -oE '^[0-9]+(\.[0-9]+)+')
    fi

    if [ -n "$DRIVER_VERSION" ]; then
        sync_register_software "nvidia_driver" "system" "" "" \
            "version=${DRIVER_VERSION};package=${DRIVER_PACKAGE}"
    elif [ -n "$DRIVER_INFO" ] || command -v nvidia-smi >/dev/null 2>&1; then
        print_message WARNING "NVIDIA Driver 버전을 확인할 수 없습니다."
        SYNC_SCAN_FAILED=1
    fi

    # NVIDIA Container Toolkit
    if command -v nvidia-ctk >/dev/null 2>&1; then
        SW_VERSION=$(nvidia-ctk --version 2>/dev/null |
            grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)

        if [ -z "$SW_VERSION" ]; then
            print_message WARNING "NVIDIA Container Toolkit 버전을 확인할 수 없습니다."
            SYNC_SCAN_FAILED=1
        fi

    elif is_dpkg_installed "nvidia-container-toolkit"; then
        SW_VERSION=$(dpkg-query -W -f='${Version}' \
            nvidia-container-toolkit 2>/dev/null)
    else
        SW_VERSION=""
    fi

    if [ -n "$SW_VERSION" ]; then
        sync_register_software "nvidia-container-toolkit" "system" "" "" \
            "version=${SW_VERSION}"
    fi

    # OpenFOAM
    while IFS= read -r PACKAGE; do
        [ -z "$PACKAGE" ] && continue

        if ! is_dpkg_installed "$PACKAGE"; then
            continue
        fi

        SW_VERSION=$(dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null)

        if [ -n "$SW_VERSION" ]; then
            sync_register_software "openfoam" "system" "" "" \
                "version=${SW_VERSION};package=${PACKAGE}"
        else
            SYNC_SCAN_FAILED=1
        fi

    done < <(
        dpkg-query -W -f='${binary:Package}\n' 'openfoam*' 2>/dev/null |
        grep -E '^openfoam[0-9]+$'
    )

    # VSCode
    if is_dpkg_installed "code"; then
        SW_VERSION=$(dpkg-query -W -f='${Version}' code 2>/dev/null)

        if [ -n "$SW_VERSION" ]; then
            sync_register_software "vscode" "system" "" "" \
                "version=${SW_VERSION};package=code"
        else
            SYNC_SCAN_FAILED=1
        fi

    elif command -v snap >/dev/null 2>&1 &&
        snap list code >/dev/null 2>&1; then

        SW_VERSION=$(snap list code 2>/dev/null |
            awk 'NR==2 {print $2}')

        if [ -n "$SW_VERSION" ]; then
            sync_register_software "vscode" "system" "" "" \
                "version=${SW_VERSION};package=snap"
        else
            SYNC_SCAN_FAILED=1
        fi

    else
        CODE_PATH=$(command -v code 2>/dev/null)

        if [ -n "$CODE_PATH" ] &&
            [[ "$CODE_PATH" != *".vscode-server"* ]]; then

            SW_VERSION=$(code --version 2>/dev/null | head -n1)

            if [ -n "$SW_VERSION" ]; then
                sync_register_software "vscode" "system" "" "" \
                    "version=${SW_VERSION}"
            else
                SYNC_SCAN_FAILED=1
            fi
        fi
    fi

    # PyCharm
    if command -v pycharm >/dev/null 2>&1; then
        SW_VERSION=$(pycharm --version 2>/dev/null |
            grep -oP '[0-9]+(\.[0-9]+)+' | head -n1)

        if [ -n "$SW_VERSION" ]; then
            sync_register_software "pycharm" "system" "" "" \
                "version=${SW_VERSION}"
        else
            sync_register_software "pycharm" "system" "" "" \
                "version=확인 불가"
        fi

    elif command -v snap >/dev/null 2>&1; then
        for PACKAGE in pycharm-community pycharm-professional; do
            SW_VERSION=$(snap list "$PACKAGE" 2>/dev/null |
                awk 'NR==2 {print $2}')

            if [ -n "$SW_VERSION" ]; then
                sync_register_software "pycharm" "system" "" "" \
                    "version=${SW_VERSION};package=${PACKAGE}"
                break
            fi
        done
    fi
}

# Conda SW 동기화
sync_conda_software() {
    local ENV_PATH=""
    local ENV_NAME=""
    local PYTHON_VERSION=""
    local SW_RESULT=""
    local SW_NAME=""
    local SW_VERSION=""
    local BASE_PATH=""
    local CONDA_ENV_JSON=""
    local ENV_LIST=""

    echo ""
    echo "========================================"
    echo "          Conda Software Sync"
    echo "========================================"

    # Conda 검색에 실패하면 기존 Conda 로그 보호를 위해 전체 정리 중단
    if ! command -v conda >/dev/null 2>&1; then
        print_message WARNING "Conda 명령어를 찾을 수 없습니다."
        SYNC_SCAN_FAILED=1
        return 1
    fi

    BASE_PATH=$(conda info --base 2>/dev/null)

    if [ -z "$BASE_PATH" ]; then
        print_message ERROR "Conda base 경로를 확인할 수 없습니다."
        SYNC_SCAN_FAILED=1
        return 1
    fi

    # Conda 환경 목록 조회
    CONDA_ENV_JSON=$(conda env list --json 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$CONDA_ENV_JSON" ]; then
        print_message ERROR "Conda 환경 목록 조회에 실패했습니다."
        SYNC_SCAN_FAILED=1
        return 1
    fi

    ENV_LIST=$(printf '%s' "$CONDA_ENV_JSON" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
    envs = data.get("envs")

    if not isinstance(envs, list):
        raise ValueError("Invalid environment list")

    for path in envs:
        print(path)

except Exception:
    sys.exit(1)
')

    if [ $? -ne 0 ]; then
        print_message ERROR "Conda 환경 목록 분석에 실패했습니다."
        SYNC_SCAN_FAILED=1
        return 1
    fi

    # Conda 환경별 SW 검색
    while IFS= read -r ENV_PATH; do
        [ -z "$ENV_PATH" ] && continue

        if [ ! -x "${ENV_PATH}/bin/python" ]; then
            print_message WARNING "${ENV_PATH} Python 실행 파일을 찾을 수 없습니다."
            SYNC_SCAN_FAILED=1
            continue
        fi

        if [ "$ENV_PATH" = "$BASE_PATH" ]; then
            ENV_NAME="base"
        else
            ENV_NAME=$(basename "$ENV_PATH")
        fi

        PYTHON_VERSION=$(
            "${ENV_PATH}/bin/python" --version 2>&1 |
            awk '{print $2}'
        )

        if [ -z "$PYTHON_VERSION" ]; then
            print_message WARNING "${ENV_NAME} Python 버전을 확인할 수 없습니다."
            SYNC_SCAN_FAILED=1
            continue
        fi

        echo ""
        echo "----------------------------------------"
        echo "[Environment] ${ENV_NAME}"
        echo "Python : ${PYTHON_VERSION}"
        echo "----------------------------------------"

        SW_RESULT=$("${ENV_PATH}/bin/python" - <<'PY'
from importlib.metadata import version, PackageNotFoundError

packages = {
    "jupyter_lab": ["jupyterlab"],
    "keras": ["keras"],
    "pytorch": ["torch"],
    "scikit_learn": ["scikit-learn"],
    "tensorflow": ["tensorflow"],
    "tensorrt": ["tensorrt", "tensorrt-cu13", "tensorrt-cu12"],
}

for name, candidates in packages.items():
    for package in candidates:
        try:
            package_version = version(package)
            print(f"{name}|{package_version}")
            break
        except PackageNotFoundError:
            continue
        except Exception:
            continue
PY
)

        if [ $? -ne 0 ]; then
            print_message WARNING "${ENV_NAME} SW 검색에 실패했습니다."
            SYNC_SCAN_FAILED=1
            continue
        fi

        while IFS='|' read -r SW_NAME SW_VERSION; do
            [ -z "$SW_NAME" ] && continue

            sync_register_software "$SW_NAME" "conda" \
                "$ENV_NAME" "$PYTHON_VERSION" \
                "version=${SW_VERSION}"

        done <<< "$SW_RESULT"

    done <<< "$ENV_LIST"
}

# 검색되지 않은 SW 로그 정리
cleanup_unsynced_software() {
    local ENTRY=""
    local LOG_SW=""
    local LOG_TYPE=""
    local LOG_ENV=""
    local NORMALIZED_SW=""
    local SYNC_KEY=""
    local REMOVED_COUNT=0

    declare -A CLEANED_ENTRIES

    echo ""
    echo "========================================"
    echo "        Cleanup Unsynced Software"
    echo "========================================"

    if [ ! -f "$LOG_FILE" ]; then
        return 0
    fi

    # 기존 로그 내용을 메모리에 보관
    local LOG_ENTRIES=()
    mapfile -t LOG_ENTRIES < "$LOG_FILE"

    for ENTRY in "${LOG_ENTRIES[@]}"; do
        IFS='|' read -r LOG_SW LOG_TYPE LOG_ENV _ <<< "$ENTRY"

        [ -z "$LOG_SW" ] && continue

        NORMALIZED_SW="${LOG_SW//-/_}"

        # 동기화 대상이 아닌 SW는 유지
        if ! is_sync_target "$NORMALIZED_SW"; then
            continue
        fi

        case "$LOG_TYPE" in
            system)
                SYNC_KEY="${NORMALIZED_SW}|system|"
                ;;
            conda)
                SYNC_KEY="${NORMALIZED_SW}|conda|${LOG_ENV}"
                ;;
            *)
                continue
                ;;
        esac

        # 검색 결과에 존재하면 유지
        if [[ -n "${SYNC_FOUND[$SYNC_KEY]+x}" ]]; then
            continue
        fi

        # 동일 항목 중복 삭제 방지
        if [[ -n "${CLEANED_ENTRIES[$SYNC_KEY]+x}" ]]; then
            continue
        fi

        CLEANED_ENTRIES["$SYNC_KEY"]=1

        # 검색되지 않은 SW 로그 제거
        if remove_installed_software "$NORMALIZED_SW" "$LOG_ENV"; then
            printf "  \033[0;31m[삭제] %s\033[0m\n" "$NORMALIZED_SW"
            ((REMOVED_COUNT++))
        else
            print_message ERROR "${NORMALIZED_SW} 로그 제거 실패"
            SYNC_SCAN_FAILED=1
        fi
    done

    echo ""
    printf "정리된 SW 항목 : %d개\n" "$REMOVED_COUNT"
}

# 전체 설치 환경 동기화
sync_installed_software() {
    clear_screen

    echo ""
    echo "========================================"
    echo "        Installed Software Sync"
    echo "========================================"
    echo ""
    echo "현재 서버의 설치 환경을 검색하여"
    echo "SW 설치 목록 이력을 동기화합니다."
    echo ""
    read -p "SW 설치 목록 이력을 동기화하겠습니까? (y/n) : " SYNC_CONFIRM

    if [[ ! "$SYNC_CONFIRM" =~ ^[Yy]$ ]]; then
        print_message INFO "동기화를 취소했습니다."
        pause_screen
        return 0
    fi

    # 동기화 상태 초기화
    SYNC_FOUND=()
    SYNC_SCAN_FAILED=0

    echo ""
    print_message INFO "System SW 검색을 시작합니다."

    sync_system_software

    echo ""
    print_message INFO "Conda 환경 검색을 시작합니다."

    sync_conda_software

    echo ""
    echo "========================================"
    echo "        Synchronization Cleanup"
    echo "========================================"

    # 모든 검색이 정상 완료된 경우에만 미검색 로그 정리
    if [ "$SYNC_SCAN_FAILED" -eq 0 ]; then
        cleanup_unsynced_software

        if [ "$SYNC_SCAN_FAILED" -eq 0 ]; then
            echo ""
            print_message SUCCESS "SW 설치 목록 동기화 및 로그 정리가 완료되었습니다."
        else
            echo ""
            print_message WARNING "일부 로그 정리에 실패했습니다."
        fi
    else
        echo ""
        print_message WARNING "검색 과정에서 오류가 발생했습니다."
        print_message WARNING "기존 로그 정리를 건너뜁니다."
    fi

    echo ""
    echo "========================================"
    echo "        Synchronization Complete"
    echo "========================================"

    echo ""
    echo "현재 등록된 SW 목록"
    show_installed_software

    pause_screen
}
