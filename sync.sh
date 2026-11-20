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

# 동기화 로그 등록 및 중복 확인
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

    if [ "$EXISTING" = "yes" ]; then
        printf "  \033[0;34m[기존 등록] %s\033[0m\n" "$SW_NAME"
        return 0
    fi

    if add_installed_software "$SW_NAME" "$SW_TYPE" \
        "$ENV_NAME" "$PYTHON_VERSION" "$SW_META"; then

        printf "  \033[0;32m[신규 등록] %s\033[0m\n" "$SW_NAME"
        return 0
    else
        print_message ERROR "${SW_NAME} 등록 실패"
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
        fi
    fi

    # DeepStream
    for PACKAGE in deepstream-9.1 deepstream-9.0 deepstream-8.0 deepstream-7.1; do
        if is_dpkg_installed "$PACKAGE"; then
            SW_VERSION=$(dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null)

            sync_register_software "deepstream" "system" "" "" \
                "version=${SW_VERSION};package=${PACKAGE}"
            break
        fi
    done

    # NVIDIA Driver
    local DRIVER_PACKAGE=""
    local DRIVER_VERSION=""

    # 실제 동작 중인 NVIDIA Driver 버전 확인
    if command -v nvidia-smi >/dev/null 2>&1; then
        DRIVER_VERSION=$(nvidia-smi \
            --query-gpu=driver_version \
            --format=csv,noheader 2>/dev/null |
            head -n1 | tr -d '[:space:]')
    fi

    # 설치된 NVIDIA Driver 패키지 확인
    DRIVER_PACKAGE=$(
        dpkg-query -W \
            -f='${db:Status-Abbrev}|${binary:Package}\n' \
            'nvidia-driver-*' 2>/dev/null |
        awk -F'|' '
            $1 ~ /^ii/ &&
            $2 ~ /^nvidia-driver-[0-9]+(-open)?(:.*)?$/ {
                print $2
                exit
            }
        '
    )

    # nvidia-smi에서 버전을 확인하지 못한 경우 패키지 버전 사용
    if [ -z "$DRIVER_VERSION" ] && [ -n "$DRIVER_PACKAGE" ]; then
        DRIVER_VERSION=$(dpkg-query -W \
            -f='${Version}' "$DRIVER_PACKAGE" 2>/dev/null)
    fi

    # 설치 방식과 관계없이 드라이버 등록
    if [ -n "$DRIVER_VERSION" ]; then
        sync_register_software "nvidia_driver" "system" "" "" \
            "version=${DRIVER_VERSION};package=${DRIVER_PACKAGE:-runfile}"
    else
        print_message WARNING "NVIDIA Driver를 감지하지 못했습니다."
    fi

    # NVIDIA Container Toolkit
    if command -v nvidia-ctk >/dev/null 2>&1; then
        SW_VERSION=$(nvidia-ctk --version 2>/dev/null |
            grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
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

        sync_register_software "openfoam" "system" "" "" \
            "version=${SW_VERSION};package=${PACKAGE}"

    done < <(
        dpkg-query -W -f='${binary:Package}\n' 'openfoam*' 2>/dev/null |
        grep -E '^openfoam[0-9]+$'
    )

    # VSCode
    if is_dpkg_installed "code"; then
        SW_VERSION=$(dpkg-query -W -f='${Version}' code 2>/dev/null)

        sync_register_software "vscode" "system" "" "" \
            "version=${SW_VERSION};package=code"

    elif command -v snap >/dev/null 2>&1 &&
        snap list code >/dev/null 2>&1; then

        SW_VERSION=$(snap list code 2>/dev/null |
            awk 'NR==2 {print $2}')

        sync_register_software "vscode" "system" "" "" \
            "version=${SW_VERSION};package=snap"
    else
        CODE_PATH=$(command -v code 2>/dev/null)

        if [ -n "$CODE_PATH" ] &&
            [[ "$CODE_PATH" != *".vscode-server"* ]]; then

            SW_VERSION=$(code --version 2>/dev/null | head -n1)

            if [ -n "$SW_VERSION" ]; then
                sync_register_software "vscode" "system" "" "" \
                    "version=${SW_VERSION}"
            fi
        fi
    fi

    # PyCharm
    if command -v pycharm >/dev/null 2>&1; then
        SW_VERSION=$(pycharm --version 2>/dev/null |
            grep -oP '[0-9]+(\.[0-9]+)+' | head -n1)

        sync_register_software "pycharm" "system" "" "" \
            "version=${SW_VERSION:-확인 불가}"

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

    echo ""
    echo "========================================"
    echo "          Conda Software Sync"
    echo "========================================"

    if ! command -v conda >/dev/null 2>&1; then
        print_message WARNING "Conda 명령어를 찾을 수 없습니다."
        return 0
    fi

    BASE_PATH=$(conda info --base 2>/dev/null)

    if [ -z "$BASE_PATH" ]; then
        print_message WARNING "Conda base 경로를 확인할 수 없습니다."
        return 1
    fi

    while IFS= read -r ENV_PATH; do
        [ -z "$ENV_PATH" ] && continue
        [ -x "${ENV_PATH}/bin/python" ] || continue

        if [ "$ENV_PATH" = "$BASE_PATH" ]; then
            ENV_NAME="base"
        else
            ENV_NAME=$(basename "$ENV_PATH")
        fi

        PYTHON_VERSION=$(
            "${ENV_PATH}/bin/python" --version 2>&1 |
            awk '{print $2}'
        )

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

        while IFS='|' read -r SW_NAME SW_VERSION; do
            [ -z "$SW_NAME" ] && continue

            sync_register_software "$SW_NAME" "conda" \
                "$ENV_NAME" "$PYTHON_VERSION" \
                "version=${SW_VERSION}"

        done <<< "$SW_RESULT"

    done < <(
        conda env list --json 2>/dev/null |
        python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
    for path in data.get("envs", []):
        print(path)
except Exception:
    pass
'
    )
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

    echo ""
    print_message INFO "System SW 검색을 시작합니다."
    sync_system_software

    echo ""
    print_message INFO "Conda 환경 검색을 시작합니다."
    sync_conda_software

    echo ""
    echo "========================================"
    echo "        Synchronization Complete"
    echo "========================================"
    echo ""
    print_message SUCCESS "SW 설치 목록 동기화가 완료되었습니다."

    echo ""
    echo "현재 등록된 SW 목록"
    show_installed_software

    pause_screen
}