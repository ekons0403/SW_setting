
#!/bin/bash

# 기본 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VE_SCRIPT="${SCRIPT_DIR}/VE/VE.sh"
LIB_DIR="${SCRIPT_DIR}/lib"
LOG_DIR="${SCRIPT_DIR}/log"
LOG_FILE="${LOG_DIR}/installed_sw.log"
REMARK_SCRIPT="${SCRIPT_DIR}/remark.sh"
LOGGER_SCRIPT="${SCRIPT_DIR}/logger.sh"
UTILS_SCRIPT="${SCRIPT_DIR}/utils.sh"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

# 다른 스크립트 로드
if [ ! -f "$VE_SCRIPT" ]; then
    echo "[ERROR] 가상환경 관리 스크립트를 찾을 수 없습니다."
    echo "[ERROR] 경로: ${VE_SCRIPT}"
    exit 1
fi
source "$VE_SCRIPT"

if [ ! -f "$UTILS_SCRIPT" ]; then
    echo "[ERROR] Utility 스크립트를 찾을 수 없습니다."
    exit 1
fi
source "$UTILS_SCRIPT"

if [ ! -f "$LOGGER_SCRIPT" ]; then
    echo "[ERROR] 로그 관리 스크립트를 찾을 수 없습니다."
    exit 1
fi

if [ ! -f "$REMARK_SCRIPT" ]; then
    echo "[ERROR] REMARK 관리 스크립트를 찾을 수 없습니다."
    echo "[ERROR] 경로: ${REMARK_SCRIPT}"
    exit 1
fi

source "$REMARK_SCRIPT"
source "$LOGGER_SCRIPT"

validate_installed_software

# 화면 대기
pause_screen() {
    read -p "계속하려면 Enter를 누르세요."
}

# 동기화 대상 SW 확인
is_sync_target() {
    local SW_NAME="${1//-/_}"

    case "$SW_NAME" in
        deepstream|docker|jupyter_lab|keras|nvidia_container_toolkit|openfoam|pycharm|pytorch|scikit_learn|tensorflow|tensorrt|vscode)
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

# 동기화 대상 System SW
sync_system_software() {
    local SW_VERSION=""
    local PACKAGE=""
    local STATUS=""
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
    # APT 패키지
    if is_dpkg_installed "code"; then
        SW_VERSION=$(dpkg-query -W -f='${Version}' code 2>/dev/null)

        sync_register_software "vscode" "system" "" "" \
            "version=${SW_VERSION};package=code"

    # Snap 패키지
    elif command -v snap >/dev/null 2>&1 &&
        snap list code >/dev/null 2>&1; then

        SW_VERSION=$(snap list code 2>/dev/null |
            awk 'NR==2 {print $2}')

        sync_register_software "vscode" "system" "" "" \
            "version=${SW_VERSION};package=snap"
    else
        # 실행 파일 확인
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

        # Python 패키지 설치 여부 및 버전 검색
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

# SW 설치 여부 확인
is_library_installed() {
    local LIBRARY_NAME="${1//-/_}"

    [ -z "$LIBRARY_NAME" ] && return 1
    [ ! -f "$LOG_FILE" ] && return 1

    awk -F'|' -v name="$LIBRARY_NAME" '
        {
            gsub(/-/, "_", $1)
            if ($1 == name) {
                found=1
                exit
            }
        }
        END {
            exit !found
        }
    ' "$LOG_FILE"
}

# SW Library 목록
get_library_list() {
    LIBRARIES=()

    for file in "$LIB_DIR"/*.sh; do
        [ -f "$file" ] || continue

        LIBRARY=$(basename "$file" .sh)
        LIBRARIES+=("$LIBRARY")
    done
}

# SW Library 번호 변환
get_library_by_number() {
    local NUMBER="$1"

    get_library_list

    if [[ "$NUMBER" =~ ^[0-9]+$ ]] &&
        [ "$NUMBER" -ge 1 ] &&
        [ "$NUMBER" -le "${#LIBRARIES[@]}" ]; then

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

    for library in "${LIBRARIES[@]}"; do
        if is_library_installed "$library"; then
            printf "  \033[0;34m%2d. %s [설치됨]\033[0m\n" \
                "$i" "$library"
        else
            printf "  \033[0;37m%2d. %s\033[0m\n" \
                "$i" "$library"
        fi

        ((i++))
    done

    echo "========================================"
    echo ""

    read -p "Install Library : " LIBRARY

    if [ -z "$LIBRARY" ]; then
        print_message ERROR "설치할 라이브러리를 입력해주세요."
        pause_screen
        return 1
    fi

    if [[ "$LIBRARY" =~ ^[0-9]+$ ]]; then
        LIBRARY=$(get_library_by_number "$LIBRARY")

        if [ -z "$LIBRARY" ]; then
            print_message ERROR "올바른 라이브러리 번호를 입력해주세요."
            pause_screen
            return 1
        fi
    fi

    LIBRARY=$(to_lower "$LIBRARY")

    MODULE=$(get_library_module "$LIBRARY")

    if [ -z "$MODULE" ]; then
        MODULE_LIBRARY="${LIBRARY//-/_}"
        MODULE=$(get_library_module "$MODULE_LIBRARY")
    fi

    if [ -z "$MODULE" ]; then
        print_message ERROR "설치 가능한 라이브러리가 아닙니다."
        pause_screen
        return 1
    fi

    if ! check_internet; then
        print_message ERROR "인터넷 연결 상태를 확인한 후 다시 실행해주세요."
        pause_screen
        return 1
    fi

    if ! load_module_function "$MODULE" install_software; then
        print_message ERROR "install_software 함수를 찾을 수 없습니다."
        pause_screen
        return 1
    fi

    clear_screen

    if ! select_required_venv; then
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

    if [ -z "$LIBRARY" ]; then
        print_message ERROR "삭제할 라이브러리를 입력해주세요."
        pause_screen
        return 1
    fi

    SELECTED_VE=""

    if [[ "$LIBRARY" =~ ^[0-9]+$ ]]; then
        if ! get_installed_software_by_index "$LIBRARY"; then
            print_message ERROR "올바른 설치 SW 번호를 입력해주세요."
            pause_screen
            return 1
        fi

        LIBRARY="$SELECTED_SW_NAME"
        SELECTED_VE="$SELECTED_SW_ENV"
    fi

    LIBRARY=$(to_lower "$LIBRARY")

    MODULE=$(get_library_module "$LIBRARY")

    if [ -z "$MODULE" ]; then
        MODULE_LIBRARY="${LIBRARY//-/_}"
        MODULE=$(get_library_module "$MODULE_LIBRARY")
    fi

    if [ -z "$MODULE" ]; then
        print_message ERROR "해당 라이브러리 모듈을 찾을 수 없습니다."
        pause_screen
        return 1
    fi

    if ! load_module_function "$MODULE" uninstall_software; then
        print_message ERROR "${LIBRARY}에는 삭제 기능이 구현되어 있지 않습니다."
        pause_screen
        return 1
    fi

    if [ -n "$SELECTED_VE" ]; then
        if ! conda env list | awk '{print $1}' | grep -qx "$SELECTED_VE"; then
            print_message ERROR "선택된 Conda 환경을 찾을 수 없습니다."
            pause_screen
            return 1
        fi

        SELECTED_VE_PATH=$(
            conda env list |
            awk -v name="$SELECTED_VE" '$1==name {print $NF}'
        )

        SELECTED_PYTHON_VERSION=$(
            "${SELECTED_VE_PATH}/bin/python" --version 2>&1 |
            awk '{print $2}'
        )
    else
        clear_screen

        if ! select_required_venv; then
            pause_screen
            return 1
        fi
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

    if [ -n "$SELECTED_VE" ]; then
        remove_installed_software "$LIBRARY" "$SELECTED_VE"
    else
        remove_installed_software "$LIBRARY"
    fi

    if [ $? -ne 0 ]; then
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
    while true; do
        clear_screen

        echo ""
        echo "========================================"
        echo "        SW Library Installer"
        echo "========================================"
        echo ""
        echo "0. 설치 환경 동기화"
        echo "1. SW Library 설치"
        echo "2. SW Library 삭제"
        echo "3. 가상환경 관리"
        echo "4. 현재 설치된 SW"
        echo "5. REMARK.txt 생성"
        echo "6. 종료"
        echo ""

        read -p "Select : " MAIN_SELECT

        case "$MAIN_SELECT" in
            0)
                sync_installed_software
                ;;
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
                create_remark_file
                pause_screen
                ;;
            6)
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
