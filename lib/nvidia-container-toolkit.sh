#!/bin/bash
# 가상환경 여부
REQUIRE_VENV=false
# NVIDIA Container Toolkit 설치
install_software() {
    echo ""
    echo "========================================"
    echo "  NVIDIA Container Toolkit Installation"
    echo "========================================"
    echo ""
    if ! command -v docker>/dev/null 2>&1;then
        print_message ERROR "Docker가 설치되어 있지 않습니다. Docker를 먼저 설치해주세요."
        return 1
    fi
    if command -v nvidia-ctk>/dev/null 2>&1;then
        NVIDIA_CTK_VERSION=$(nvidia-ctk --version 2>/dev/null|grep -oP '[0-9]+\.[0-9]+\.[0-9]+'|head -n1)
        echo "Installed : NVIDIA Container Toolkit"
        echo "Version   : ${NVIDIA_CTK_VERSION:-확인 불가}"
        print_message INFO "NVIDIA Container Toolkit이 이미 설치되어 있습니다."
        add_installed_software "nvidia-container-toolkit" "system"
        return 2
    fi
    echo "NVIDIA Container Toolkit : 설치되지 않음"
    echo ""
    read -p "NVIDIA Container Toolkit을 설치하시겠습니까? (y/n) : " INSTALL_CONFIRM
    if [[ ! "$INSTALL_CONFIRM" =~ ^[Yy]$ ]];then
        print_message INFO "설치를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "NVIDIA Container Toolkit 설치를 시작합니다."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey|sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg>/dev/null 2>&1||{
        print_message ERROR "NVIDIA Container Toolkit 저장소 등록에 실패했습니다."
        return 1
    }
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list|sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g'|sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list>/dev/null||{
        print_message ERROR "NVIDIA Container Toolkit 저장소 등록에 실패했습니다."
        return 1
    }
    sudo apt-get update>/dev/null 2>&1||{
        print_message ERROR "패키지 목록 업데이트에 실패했습니다."
        return 1
    }
    sudo apt-get install -y nvidia-container-toolkit>/dev/null 2>&1||{
        print_message ERROR "NVIDIA Container Toolkit 설치에 실패했습니다."
        return 1
    }
    sudo nvidia-ctk runtime configure --runtime=docker>/dev/null 2>&1||{
        print_message ERROR "NVIDIA Container Runtime 설정에 실패했습니다."
        return 1
    }
    sudo systemctl restart docker>/dev/null 2>&1||{
        print_message ERROR "Docker 서비스 재시작에 실패했습니다."
        return 1
    }
    if ! command -v nvidia-ctk>/dev/null 2>&1;then
        print_message ERROR "NVIDIA Container Toolkit 설치를 확인할 수 없습니다."
        return 1
    fi
    NVIDIA_CTK_VERSION=$(nvidia-ctk --version 2>/dev/null|grep -oP '[0-9]+\.[0-9]+\.[0-9]+'|head -n1)
    echo ""
    echo "NVIDIA Container Toolkit : ${NVIDIA_CTK_VERSION:-확인 불가}"
    add_installed_software "nvidia-container-toolkit" "system"
    if [ $? -ne 0 ];then
        print_message ERROR "설치 목록 등록에 실패했습니다."
        return 1
    fi
    return 0
}

# NVIDIA Container Toolkit 삭제

# NVIDIA Container Toolkit 삭제
uninstall_software() {
    echo ""
    echo "========================================"
    echo "  NVIDIA Container Toolkit Uninstallation"
    echo "========================================"
    echo ""

    # 설치 여부 확인
    if ! dpkg-query -W -f='${Status}' nvidia-container-toolkit 2>/dev/null \
        | grep -q "install ok installed"; then

        print_message INFO "NVIDIA Container Toolkit이 설치되어 있지 않습니다."

        remove_installed_software "nvidia-container-toolkit"
        return 0
    fi

    # 버전 확인
    NVIDIA_CTK_VERSION=$(nvidia-ctk --version 2>/dev/null \
        | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' \
        | head -n1)

    echo "Installed : NVIDIA Container Toolkit"
    echo "Version   : ${NVIDIA_CTK_VERSION:-확인 불가}"
    echo ""

    # 삭제 확인
    read -p "삭제하시겠습니까? (y/n) : " UNINSTALL_CONFIRM

    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
        print_message INFO "삭제를 취소했습니다."
        return 3
    fi

    echo ""
    print_message INFO "NVIDIA Container Toolkit을 삭제합니다."

    # 실제 설치된 NVIDIA Container Toolkit 관련 패키지 검색
    mapfile -t TOOLKIT_PACKAGES < <(
        dpkg-query -W \
            -f='${db:Status-Status} ${binary:Package}\n' 2>/dev/null \
        | awk '
            $1 == "installed" &&
            $2 ~ /^(nvidia-container-toolkit|libnvidia-container)/ {
                print $2
            }
        '
    )

    # 관련 패키지 삭제
    if [ ${#TOOLKIT_PACKAGES[@]} -gt 0 ]; then
        sudo apt-get purge -y "${TOOLKIT_PACKAGES[@]}" || {
            print_message ERROR "NVIDIA Container Toolkit 삭제에 실패했습니다."
            return 1
        }
    fi

    # 불필요한 패키지 정리
    sudo apt-get autoremove -y || {
        print_message ERROR "불필요한 패키지 제거에 실패했습니다."
        return 1
    }

    # NVIDIA APT 저장소 및 GPG Key 제거
    print_message INFO "NVIDIA Container Toolkit 저장소 설정을 정리합니다."

    sudo rm -f \
        /etc/apt/sources.list.d/nvidia-container-toolkit.list \
        /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

    # Docker NVIDIA Runtime 설정 제거
    if [ -f /etc/docker/daemon.json ]; then

        print_message INFO "Docker NVIDIA Runtime 설정을 정리합니다."

        sudo python3 - <<'PY'
import json
import os
import tempfile

config_path = "/etc/docker/daemon.json"

try:
    with open(config_path, "r") as f:
        config = json.load(f)

    if not isinstance(config, dict):
        raise ValueError("Docker 설정 형식이 올바르지 않습니다.")

    changed = False

    # NVIDIA Runtime 설정 제거
    runtimes = config.get("runtimes")

    if isinstance(runtimes, dict) and "nvidia" in runtimes:
        del runtimes["nvidia"]
        changed = True

        if not runtimes:
            del config["runtimes"]

    # NVIDIA를 기본 Runtime으로 지정한 경우 제거
    if config.get("default-runtime") == "nvidia":
        del config["default-runtime"]
        changed = True

    # 변경 사항이 있는 경우에만 저장
    if changed:
        directory = os.path.dirname(config_path)

        fd, temp_path = tempfile.mkstemp(
            prefix=".daemon.json.",
            dir=directory
        )

        try:
            with os.fdopen(fd, "w") as f:
                json.dump(config, f, indent=4)
                f.write("\n")

            os.chmod(temp_path, 0o644)
            os.replace(temp_path, config_path)

        except Exception:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            raise

        print("NVIDIA Runtime 설정을 제거했습니다.")

    else:
        print("제거할 NVIDIA Runtime 설정이 없습니다.")

except Exception as e:
    print(f"Docker 설정 정리 실패: {e}")
    raise SystemExit(1)
PY

        if [ $? -ne 0 ]; then
            print_message ERROR "Docker NVIDIA Runtime 설정 정리에 실패했습니다."
            return 1
        fi
    fi

    # Docker 서비스 재시작
    if command -v docker >/dev/null 2>&1; then
        sudo systemctl restart docker || {
            print_message ERROR "Docker 서비스 재시작에 실패했습니다."
            return 1
        }
    fi

    # 설치 기록 제거
    remove_installed_software "nvidia-container-toolkit" || {
        print_message ERROR "설치 목록 제거에 실패했습니다."
        return 1
    }

    # 최종 삭제 확인
    if dpkg-query -W -f='${Status}' nvidia-container-toolkit 2>/dev/null \
        | grep -q "install ok installed"; then

        print_message ERROR "NVIDIA Container Toolkit이 아직 설치되어 있습니다."
        return 1
    fi

    if command -v nvidia-ctk >/dev/null 2>&1; then
        print_message ERROR "nvidia-ctk 실행 파일이 아직 남아 있습니다."
        return 1
    fi

    print_message INFO "NVIDIA Container Toolkit 삭제가 완료되었습니다."
    return 0
}

