#!/bin/bash

# NVIDIA Driver 지원 버전
NVIDIA_DRIVER_VERSIONS=("580" "595" "615")

AVAILABLE_DRIVERS=()
AVAILABLE_PACKAGES=()
AVAILABLE_CANDIDATES=()
NVIDIA_REMOVE_PACKAGES=()

UBUNTU_VERSION=""
UBUNTU_NAME=""
SELECTED_DRIVER_VERSION=""
SELECTED_DRIVER_PACKAGE=""

# Ubuntu 버전 확인
detect_ubuntu_version() {
    if [ ! -f /etc/os-release ]; then
        echo "[ERROR] OS 정보를 확인할 수 없습니다."
        return 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [ "$ID" != "ubuntu" ]; then
        echo "[ERROR] Ubuntu 환경에서만 사용할 수 있습니다."
        return 1
    fi

    UBUNTU_VERSION="$VERSION_ID"
    UBUNTU_NAME="${VERSION_CODENAME:-unknown}"

    return 0
}

# 환경 확인
check_nvidia_driver_environment() {
    if ! command -v apt-get >/dev/null 2>&1; then
        echo "[ERROR] apt-get을 찾을 수 없습니다."
        return 1
    fi

    if ! command -v apt-cache >/dev/null 2>&1; then
        echo "[ERROR] apt-cache를 찾을 수 없습니다."
        return 1
    fi

    if ! command -v dpkg-query >/dev/null 2>&1; then
        echo "[ERROR] dpkg-query를 찾을 수 없습니다."
        return 1
    fi

    detect_ubuntu_version || return 1

    return 0
}

# APT 패키지 설치 상태 확인
is_package_installed() {
    local PACKAGE="$1"
    local PACKAGE_STATUS=""

    PACKAGE_STATUS=$(dpkg-query -W \
        -f='${db:Status-Abbrev}' \
        "$PACKAGE" 2>/dev/null) || return 1

    [[ "${PACKAGE_STATUS:0:2}" == "ii" ]]
}

# 설치된 NVIDIA Driver 확인
check_nvidia_driver() {
    echo ""
    echo "========================================"
    echo "       Installed NVIDIA Driver"
    echo "========================================"

    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi
    else
        echo "[INFO] nvidia-smi를 찾을 수 없습니다."
    fi

    echo ""
    echo "[Installed Packages]"

    dpkg-query -W \
        -f='${db:Status-Abbrev} ${binary:Package} ${Version}\n' \
        'nvidia-driver-*' 2>/dev/null |
        awk '$1 ~ /^ii/'

    echo ""
}

# APT 저장소 업데이트
update_apt_repository() {
    echo ""
    echo "[INFO] APT 저장소를 업데이트합니다."

    if ! sudo apt-get update; then
        echo "[ERROR] APT 저장소 업데이트에 실패했습니다."
        return 1
    fi

    return 0
}

# 설치 가능한 NVIDIA Driver 검색
detect_available_nvidia_drivers() {
    local VERSION=""
    local PACKAGE=""
    local CANDIDATE=""

    AVAILABLE_DRIVERS=()
    AVAILABLE_PACKAGES=()
    AVAILABLE_CANDIDATES=()

    for VERSION in "${NVIDIA_DRIVER_VERSIONS[@]}"; do
        PACKAGE="nvidia-driver-${VERSION}-open"

        CANDIDATE=$(
            apt-cache policy "$PACKAGE" 2>/dev/null |
                awk '/Candidate:/ {print $2; exit}'
        )

        if [ -n "$CANDIDATE" ] && [ "$CANDIDATE" != "(none)" ]; then
            AVAILABLE_DRIVERS+=("$VERSION")
            AVAILABLE_PACKAGES+=("$PACKAGE")
            AVAILABLE_CANDIDATES+=("$CANDIDATE")
        fi
    done

    if [ "${#AVAILABLE_DRIVERS[@]}" -eq 0 ]; then
        echo "[ERROR] 설치 가능한 NVIDIA Driver가 없습니다."
        return 1
    fi

    return 0
}

# NVIDIA Driver 설치
install_nvidia_driver() {
    local INDEX="$1"
    local VERSION=""
    local PACKAGE=""
    local CANDIDATE=""
    local CONFIRM=""
    local INSTALLED_VERSION=""

    VERSION="${AVAILABLE_DRIVERS[$INDEX]}"
    PACKAGE="${AVAILABLE_PACKAGES[$INDEX]}"
    CANDIDATE="${AVAILABLE_CANDIDATES[$INDEX]}"

    SELECTED_DRIVER_VERSION="$VERSION"
    SELECTED_DRIVER_PACKAGE="$PACKAGE"

    echo ""
    echo "========================================"
    echo "       NVIDIA Driver Installation"
    echo "========================================"
    echo ""
    echo "Ubuntu          : ${UBUNTU_VERSION} (${UBUNTU_NAME})"
    echo "Driver Version  : ${VERSION} Open"
    echo "Package         : ${PACKAGE}"
    echo "APT Candidate   : ${CANDIDATE}"
    echo ""

    if is_package_installed "$PACKAGE"; then
        echo "[INFO] 해당 드라이버가 이미 설치되어 있습니다."
        return 0
    fi

    read -r -p "선택한 NVIDIA Driver를 설치하시겠습니까? (Y/N) : " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[INFO] 설치를 취소했습니다."
        return 2
    fi

    echo ""
    echo "[INFO] NVIDIA Driver 설치를 시작합니다."

    if ! sudo apt-get install -y "$PACKAGE"; then
        echo "[ERROR] NVIDIA Driver 설치에 실패했습니다."
        return 1
    fi

    # 재부팅 전에는 nvidia-smi가 드라이버와 통신하지 못할 수 있으므로
    # 실행 여부가 아닌 APT 패키지 설치 상태로 설치 성공을 판정합니다.
    if is_package_installed "$PACKAGE"; then
        INSTALLED_VERSION=$(dpkg-query -W \
            -f='${Version}' "$PACKAGE" 2>/dev/null)

        echo ""
        echo "[SUCCESS] NVIDIA Driver 설치가 완료되었습니다."
        echo "[INFO] 설치 버전 : ${INSTALLED_VERSION:-$CANDIDATE}"
        echo "[INFO] 재부팅 후 드라이버가 적용됩니다."
        return 0
    fi

    echo "[ERROR] NVIDIA Driver 설치 여부를 확인할 수 없습니다."
    return 1
}

# NVIDIA Driver 설치 메뉴
nvidia_driver_menu() {
    local INDEX=""
    local INPUT=""
    local RESULT=0

    if ! check_nvidia_driver_environment; then
        return 1
    fi

    if ! sudo -v; then
        echo "[ERROR] 관리자 권한을 얻지 못했습니다."
        return 1
    fi

    if ! update_apt_repository; then
        return 1
    fi

    if ! detect_available_nvidia_drivers; then
        return 1
    fi

    clear

    echo "========================================"
    echo "       NVIDIA Driver Installation"
    echo "========================================"
    echo ""
    echo "Ubuntu : Ubuntu ${UBUNTU_VERSION} (${UBUNTU_NAME})"
    echo ""
    echo "========================================"
    echo "       Recommended NVIDIA Driver"
    echo "========================================"
    echo ""

    for INDEX in "${!AVAILABLE_DRIVERS[@]}"; do
        printf "%d. NVIDIA Driver %s Open (%s)\n" \
            "$((INDEX + 1))" \
            "${AVAILABLE_DRIVERS[$INDEX]}" \
            "${AVAILABLE_CANDIDATES[$INDEX]}"
    done

    echo ""
    echo "0. 설치 취소"
    echo ""
    read -r -p "설치할 NVIDIA Driver를 선택하세요 : " INPUT

    if [[ "$INPUT" == "0" ]]; then
        echo "[INFO] 설치를 취소했습니다."
        return 2
    fi

    if [[ "$INPUT" =~ ^[0-9]+$ ]] &&
        [ "$INPUT" -ge 1 ] &&
        [ "$INPUT" -le "${#AVAILABLE_DRIVERS[@]}" ]; then

        install_nvidia_driver "$((INPUT - 1))"
        RESULT=$?
        return "$RESULT"
    fi

    echo "[ERROR] 올바른 번호를 선택해주세요."
    echo "[ERROR] nvidia_driver 설치에 실패했습니다."
    read -r -p "계속하려면 Enter를 누르세요."
    return 1
}

# NVIDIA Driver 설치 기록
install_software() {
    local RESULT=0
    local DRIVER_VERSION=""
    local DRIVER_PACKAGE=""
    local PACKAGE_VERSION=""

    SELECTED_DRIVER_VERSION=""
    SELECTED_DRIVER_PACKAGE=""

    nvidia_driver_menu
    RESULT=$?

    case "$RESULT" in
        0)
            DRIVER_PACKAGE="$SELECTED_DRIVER_PACKAGE"

            # 실제 드라이버가 이미 로드되어 있으면 nvidia-smi 버전 사용
            if command -v nvidia-smi >/dev/null 2>&1; then
                DRIVER_VERSION=$(
                    nvidia-smi --query-gpu=driver_version \
                        --format=csv,noheader 2>/dev/null |
                        head -n1 | tr -d '[:space:]'
                )
            fi

            # 재부팅 전 등 nvidia-smi에서 버전을 얻지 못하면
            # 설치된 APT 패키지 버전을 사용
            if [ -z "$DRIVER_VERSION" ] && [ -n "$DRIVER_PACKAGE" ]; then
                PACKAGE_VERSION=$(dpkg-query -W \
                    -f='${Version}' "$DRIVER_PACKAGE" 2>/dev/null)
                DRIVER_VERSION="${PACKAGE_VERSION:-설치 완료}"
            fi

            if [ -z "$DRIVER_VERSION" ]; then
                DRIVER_VERSION="설치 완료"
            fi

            if ! declare -F add_installed_software >/dev/null 2>&1; then
                echo "[ERROR] add_installed_software 함수를 찾을 수 없습니다."
                return 1
            fi

            add_installed_software \
                "nvidia_driver" \
                "system" \
                "" \
                "" \
                "version=${DRIVER_VERSION};type=Open;package=${DRIVER_PACKAGE}"

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

# NVIDIA Driver 관련 APT 패키지 검색
get_nvidia_driver_packages() {
    local PACKAGE=""
    local STATUS=""

    NVIDIA_REMOVE_PACKAGES=()

    while IFS='|' read -r STATUS PACKAGE; do
        [ -z "$PACKAGE" ] && continue
        [[ "$STATUS" =~ ^ii ]] || continue

        # NVIDIA Container Toolkit은 삭제 대상에서 제외
        case "$PACKAGE" in
            nvidia-container-*|libnvidia-container*)
                continue
                ;;
        esac

        # NVIDIA Driver 관련 패키지만 삭제 대상으로 지정
        if [[ "$PACKAGE" =~ ^nvidia-driver-[0-9]+(-open)?(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^nvidia-dkms-[0-9]+(-open)?(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^nvidia-kernel-common-[0-9]+(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^nvidia-kernel-source-[0-9]+(-open)?(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^nvidia-utils-[0-9]+(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^nvidia-compute-utils-[0-9]+(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^nvidia-firmware-[0-9]+- ]] ||
           [[ "$PACKAGE" =~ ^nvidia-modprobe(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^nvidia-persistenced(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^nvidia-settings(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^nvidia-prime(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^libnvidia-[a-zA-Z0-9.-]+(:.*)?$ ]] ||
           [[ "$PACKAGE" =~ ^linux-modules-nvidia-[0-9]+ ]] ||
           [[ "$PACKAGE" =~ ^xserver-xorg-video-nvidia-[0-9]+ ]]; then

            NVIDIA_REMOVE_PACKAGES+=("$PACKAGE")
        fi
    done < <(
        dpkg-query -W \
            -f='${db:Status-Abbrev}|${binary:Package}\n' \
            'nvidia-*' 'libnvidia-*' \
            'linux-modules-nvidia-*' \
            'xserver-xorg-video-nvidia-*' 2>/dev/null
    )
}

# NVIDIA Driver 삭제
uninstall_software() {
    local CONFIRM=""
    local PACKAGE=""
    local RESULT=0

    echo ""
    echo "========================================"
    echo "        NVIDIA Driver Uninstaller"
    echo "========================================"

    if ! sudo -v; then
        echo "[ERROR] 관리자 권한을 얻지 못했습니다."
        return 1
    fi

    # APT 패키지 설치 여부 확인
    get_nvidia_driver_packages

    if [ "${#NVIDIA_REMOVE_PACKAGES[@]}" -gt 0 ]; then
        echo ""
        echo "[INFO] 삭제할 NVIDIA Driver 패키지"

        for PACKAGE in "${NVIDIA_REMOVE_PACKAGES[@]}"; do
            echo "  - ${PACKAGE}"
        done

        echo ""
        echo "[주의] NVIDIA Driver 관련 패키지만 삭제합니다."
        echo "[주의] CUDA 및 NVIDIA Container Toolkit은 삭제하지 않습니다."
        echo ""

        read -r -p "NVIDIA Driver를 삭제하시겠습니까? (Y/N) : " CONFIRM

        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo "[INFO] 삭제를 취소했습니다."
            return 2
        fi

        echo ""
        echo "[INFO] NVIDIA Driver 패키지를 삭제합니다."

        if sudo apt-get purge -y "${NVIDIA_REMOVE_PACKAGES[@]}"; then
            echo ""
            echo "[SUCCESS] NVIDIA Driver 패키지 삭제가 완료되었습니다."
            echo "[INFO] 재부팅 후 잔여 드라이버 모듈이 정리됩니다."
            return 0
        else
            echo "[ERROR] NVIDIA Driver 삭제에 실패했습니다."
            return 1
        fi
    fi

    # APT 패키지가 아닌 NVIDIA 공식 RUN 파일 설치 확인
    if command -v nvidia-uninstall >/dev/null 2>&1; then
        echo ""
        echo "[INFO] NVIDIA RUN 파일 방식 설치를 확인했습니다."
        echo ""
        read -r -p "NVIDIA Driver를 삭제하시겠습니까? (Y/N) : " CONFIRM

        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo "[INFO] 삭제를 취소했습니다."
            return 2
        fi

        sudo nvidia-uninstall
        RESULT=$?

        if [ "$RESULT" -eq 0 ]; then
            echo "[SUCCESS] NVIDIA Driver 삭제가 완료되었습니다."
            return 0
        fi

        echo "[ERROR] NVIDIA Driver 삭제에 실패했습니다."
        return 1
    fi

    echo "[INFO] 삭제할 NVIDIA Driver 패키지를 찾을 수 없습니다."
    return 2
}

# 직접 실행 시 메뉴 표시
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    nvidia_driver_menu
    RESULT=$?

    case "$RESULT" in
        0)
            echo "[SUCCESS] NVIDIA Driver 작업이 완료되었습니다."
            ;;
        2)
            echo "[INFO] 작업을 종료했습니다."
            ;;
        *)
            echo "[ERROR] NVIDIA Driver 작업에 실패했습니다."
            ;;
    esac
fi
