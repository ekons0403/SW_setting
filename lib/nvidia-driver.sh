
#!/bin/bash

# ============================================================
# NVIDIA Driver Library
# SW_setting ver.2
# Ubuntu Bare Metal Driver Installation
# ============================================================

NVIDIA_DRIVER_VERSIONS=("580" "595" "615")

AVAILABLE_DRIVERS=()
AVAILABLE_PACKAGES=()
AVAILABLE_CANDIDATES=()

UBUNTU_VERSION=""
UBUNTU_NAME=""

# ------------------------------------------------------------
# Ubuntu Version Detection
# ------------------------------------------------------------
detect_ubuntu_version() {

    if [[ ! -f /etc/os-release ]]; then
        echo "[ERROR] Cannot detect OS version."
        return 1
    fi

    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        echo "[ERROR] Ubuntu environment required."
        return 1
    fi

    UBUNTU_VERSION="${VERSION_ID}"
    UBUNTU_NAME="${PRETTY_NAME}"

    return 0
}

# ------------------------------------------------------------
# Environment Check
# ------------------------------------------------------------
check_nvidia_driver_environment() {

    detect_ubuntu_version || return 1

    if ! command -v apt-get &>/dev/null; then
        echo "[ERROR] APT package manager not found."
        return 1
    fi

    if ! command -v apt-cache &>/dev/null; then
        echo "[ERROR] APT cache not found."
        return 1
    fi

    if ! command -v dpkg-query &>/dev/null; then
        echo "[ERROR] dpkg-query not found."
        return 1
    fi

    return 0
}

# ------------------------------------------------------------
# Installed Driver Check
# ------------------------------------------------------------
check_nvidia_driver() {

    echo
    echo "========== NVIDIA Driver Status =========="

    local INSTALLED_DRIVERS

    INSTALLED_DRIVERS=$(
        dpkg-query -W \
            -f='${db:Status-Abbrev} ${binary:Package} ${Version}\n' \
            'nvidia-driver-*' 2>/dev/null |
            awk '$1 ~ /^ii/ {print}'
    )

    if [[ -n "$INSTALLED_DRIVERS" ]]; then
        echo "$INSTALLED_DRIVERS"
    else
        echo "[INFO] No NVIDIA Driver installed."
    fi

    if command -v nvidia-smi &>/dev/null; then
        echo
        nvidia-smi
    fi

    echo "=========================================="
    echo
}

# ------------------------------------------------------------
# APT Repository Update
# ------------------------------------------------------------
update_apt_repository() {

    echo
    echo "[INFO] Updating APT repositories..."

    if ! sudo apt-get update; then
        echo "[ERROR] Failed to update APT repositories."
        return 1
    fi

    echo "[SUCCESS] APT repositories updated."

    return 0
}

# ------------------------------------------------------------
# Available Driver Detection
# ------------------------------------------------------------
detect_available_nvidia_drivers() {

    AVAILABLE_DRIVERS=()
    AVAILABLE_PACKAGES=()
    AVAILABLE_CANDIDATES=()

    echo
    echo "[INFO] Checking available NVIDIA Drivers..."

    local VERSION
    local PACKAGE
    local CANDIDATE

    for VERSION in "${NVIDIA_DRIVER_VERSIONS[@]}"; do

        PACKAGE="nvidia-driver-${VERSION}-open"

        CANDIDATE=$(
            apt-cache policy "$PACKAGE" 2>/dev/null |
                awk '/Candidate:/ {print $2}'
        )

        if [[ -n "$CANDIDATE" && "$CANDIDATE" != "(none)" ]]; then

            AVAILABLE_DRIVERS+=("$VERSION")
            AVAILABLE_PACKAGES+=("$PACKAGE")
            AVAILABLE_CANDIDATES+=("$CANDIDATE")

            echo "[INFO] Found: ${PACKAGE} (${CANDIDATE})"

        else

            echo "[INFO] Not available: ${PACKAGE}"

        fi

    done

    if [[ ${#AVAILABLE_DRIVERS[@]} -eq 0 ]]; then
        echo "[ERROR] No supported NVIDIA Open Drivers found."
        return 1
    fi

    return 0
}

# ------------------------------------------------------------
# NVIDIA Driver Installation
# ------------------------------------------------------------
install_nvidia_driver() {

    local INDEX="$1"

    local VERSION="${AVAILABLE_DRIVERS[$INDEX]}"
    local PACKAGE="${AVAILABLE_PACKAGES[$INDEX]}"
    local CANDIDATE="${AVAILABLE_CANDIDATES[$INDEX]}"

    echo
    echo "========== NVIDIA Driver Installation =========="
    echo "[INFO] Ubuntu  : ${UBUNTU_VERSION}"
    echo "[INFO] Driver  : ${VERSION} Open"
    echo "[INFO] Package : ${PACKAGE}"
    echo "[INFO] Version : ${CANDIDATE}"
    echo

    # 이미 설치되어 있는지 확인
    if dpkg-query -W -f='${Status}' "$PACKAGE" 2>/dev/null |
        grep -q "install ok installed"; then

        echo "[INFO] Driver ${VERSION} Open is already installed."
        return 0
    fi

    # 기존 드라이버 확인
    check_nvidia_driver

    echo "[WARNING] Existing NVIDIA Driver packages may be replaced."
    echo

    read -r -p "Install NVIDIA Driver ${VERSION} Open? (Y/N): " ANSWER

    if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
        echo "[INFO] Installation cancelled."
        return 2
    fi

    # 드라이버 설치
    echo
    echo "[INFO] Installing ${PACKAGE}..."

    if ! sudo apt-get install -y "$PACKAGE"; then
        echo "[ERROR] NVIDIA Driver installation failed."
        return 1
    fi

    # 설치 결과 확인
    if dpkg-query -W -f='${Status}' "$PACKAGE" 2>/dev/null |
        grep -q "install ok installed"; then

        echo
        echo "[SUCCESS] NVIDIA Driver ${VERSION} Open installed."
        echo "[INFO] System reboot required."
        echo

        return 0

    else

        echo "[ERROR] Installation verification failed."
        return 1

    fi
}

# ------------------------------------------------------------
# NVIDIA Driver Menu
# ------------------------------------------------------------
nvidia_driver_menu() {

    # Ubuntu 환경 확인
    check_nvidia_driver_environment || return 1

    # 관리자 권한 확인
    if ! sudo -v; then
        echo "[ERROR] Administrator permission required."
        return 1
    fi

    # APT 저장소 업데이트 (메뉴 진입 시 1회)
    if ! update_apt_repository; then
        return 1
    fi

    # 업데이트된 저장소 기준 드라이버 검색
    if ! detect_available_nvidia_drivers; then
        echo
        echo "[INFO] Check your Ubuntu APT repositories."
        return 1
    fi

    while true; do

        clear

        echo "================================================"
        echo "             NVIDIA Driver Installer"
        echo "================================================"
        echo
        echo "[SYSTEM INFORMATION]"
        echo " Ubuntu : ${UBUNTU_NAME}"
        echo " Version: ${UBUNTU_VERSION}"
        echo
        echo "================================================"
        echo "             AVAILABLE DRIVERS"
        echo "================================================"

        local i

        for i in "${!AVAILABLE_DRIVERS[@]}"; do

            printf " %d. NVIDIA Driver %s Open [%s]\n" \
                "$((i + 1))" \
                "${AVAILABLE_DRIVERS[$i]}" \
                "${AVAILABLE_CANDIDATES[$i]}"

        done

        echo
        echo " C. Check Installed Driver"
        echo " 0. Back"
        echo
        echo "================================================"

        local SELECT

        read -r -p "Select: " SELECT

        case "$SELECT" in

            0)
                return 2
                ;;

            [Cc])
                check_nvidia_driver
                read -r -p "Press Enter to continue..."
                ;;

            *)

                if [[ "$SELECT" =~ ^[0-9]+$ ]] &&
                    (( SELECT >= 1 && SELECT <= ${#AVAILABLE_DRIVERS[@]} )); then

                    install_nvidia_driver "$((SELECT - 1))"
                    local RESULT=$?

                    case "$RESULT" in
                        0)
                            return 0
                            ;;
                        2)
                            ;;
                        *)
                            echo
                            echo "[ERROR] Driver installation failed."
                            read -r -p "Press Enter to continue..."
                            ;;
                    esac

                else

                    echo "[ERROR] Invalid selection."
                    sleep 1

                fi

                ;;

        esac

    done
}

# ------------------------------------------------------------
# SW_setting Library Interface
# ------------------------------------------------------------
install_software() {

    nvidia_driver_menu
    local RESULT=$?

    case "$RESULT" in

        0)

            add_installed_software \
                "nvidia_driver" \
                "system" \
                "" \
                "" \
                "NVIDIA Driver Open"

            return $?
            ;;

        2)
            return 2
            ;;

        *)
            return 1
            ;;

    esac
}

# ------------------------------------------------------------
# Direct Execution
# ------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then

    nvidia_driver_menu
    RESULT=$?

    case "$RESULT" in
        0)
            echo "[SUCCESS] NVIDIA Driver installation completed."
            ;;
        2)
            echo "[INFO] Returned to previous menu."
            ;;
        *)
            echo "[ERROR] NVIDIA Driver operation failed."
            ;;
    esac

fi
