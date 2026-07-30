#!/bin/bash
# Conda 환경 목록 확인
list_virtual_environments() {
    VE_NAMES=()
    VE_TYPES=()
    VE_PATHS=()
    VE_PYTHON_VERSIONS=()
    # Conda 설치 여부 확인
    if ! command -v conda > /dev/null 2>&1; then
        echo ""
        echo "[ERROR] Conda가 설치되어 있지 않습니다."
        echo "[INFO] Anaconda 또는 Miniconda를 먼저 설치해주세요."
        return 1
    fi
    # Conda 환경 검색
    while IFS= read -r CONDA_LINE; do
        [[ "$CONDA_LINE" =~ ^[[:space:]]*# ]] && continue
        [ -z "$CONDA_LINE" ] && continue
        CONDA_NAME=$(echo "$CONDA_LINE" | awk '{print $1}')
        CONDA_PATH=$(echo "$CONDA_LINE" | awk '{print $NF}')
        if [ -n "$CONDA_NAME" ] && [ -n "$CONDA_PATH" ]; then
            if [ "$CONDA_NAME" == "base" ]; then
                PYTHON_VERSION=$(
                    "$CONDA_PATH/bin/python" --version 2>&1 |
                    awk '{print $2}'
                )
            else
                PYTHON_VERSION=$(
                    "$CONDA_PATH/bin/python" --version 2>&1 |
                    awk '{print $2}'
                )
            fi
            VE_NAMES+=("$CONDA_NAME")
            VE_TYPES+=("conda")
            VE_PATHS+=("$CONDA_PATH")
            VE_PYTHON_VERSIONS+=("$PYTHON_VERSION")
        fi
    done < <(conda env list | grep -v "^#")
    # 목록 출력
    echo ""
    echo "========================================"
    echo "     Conda Virtual Environment List"
    echo "========================================"
    echo ""
    if [ ${#VE_NAMES[@]} -eq 0 ]; then
        echo "[INFO] 생성된 Conda 가상환경이 없습니다."
        return 1
    fi
    echo "사용할 가상환경을 선택해주세요."
    echo ""
    for i in "${!VE_NAMES[@]}"; do
        echo "$((i + 1)). [${VE_TYPES[$i]}] ${VE_NAMES[$i]}"
        echo "   Python Version : ${VE_PYTHON_VERSIONS[$i]}"
        echo ""
    done
    echo "$(( ${#VE_NAMES[@]} + 1 )). 새로운 Conda 환경 생성"
    return 0
}
# Conda 환경 생성
create_conda() {
    echo ""
    echo "========================================"
    echo "     Create Conda Environment"
    echo "========================================"
    echo ""
    if ! command -v conda > /dev/null 2>&1; then
        echo "[ERROR] Conda가 설치되어 있지 않습니다."
        echo "[INFO] Anaconda 또는 Miniconda를 먼저 설치해주세요."
        return 1
    fi
    read -p "사용할 Python 버전 : " PYTHON_VERSION
    if [ -z "$PYTHON_VERSION" ]; then
        echo "[ERROR] Python 버전을 입력해주세요."
        return 1
    fi
    read -p "생성할 Conda 환경 이름 : " VE_NAME
    if [ -z "$VE_NAME" ]; then
        echo "[ERROR] 가상환경 이름을 입력해주세요."
        return 1
    fi
    if conda env list | awk '{print $1}' | grep -qx "$VE_NAME"; then
        echo ""
        echo "[ERROR] 이미 존재하는 Conda 환경입니다."
        echo "[INFO] 환경 이름: ${VE_NAME}"
        return 1
    fi
    echo ""
    echo "[INFO] Conda 환경을 생성합니다."
    echo "[INFO] 환경 이름: ${VE_NAME}"
    echo "[INFO] Python 버전: ${PYTHON_VERSION}"
    echo ""
    conda create -n "$VE_NAME" \
        python="$PYTHON_VERSION" \
        -y
    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] Conda 환경 생성에 실패했습니다."
        return 1
    fi
    # 생성된 환경 경로 확인
    SELECTED_VE_PATH=$(
        conda env list |
        awk -v name="$VE_NAME" '$1 == name {print $NF}'
    )
    SELECTED_VE="$VE_NAME"
    VE_TYPE="conda"
    SELECTED_PYTHON_VERSION="$PYTHON_VERSION"
    echo ""
    echo "[SUCCESS] Conda 환경 생성이 완료되었습니다."
    echo "[INFO] 환경 이름: ${SELECTED_VE}"
    echo "[INFO] Python 버전: ${PYTHON_VERSION}"
    echo "[INFO] 환경 경로: ${SELECTED_VE_PATH}"
    return 0
}
# Conda 환경 삭제
delete_virtual_environment() {
    echo ""
    echo "========================================"
    echo "     Delete Conda Environment"
    echo "========================================"
    echo ""
    if ! command -v conda > /dev/null 2>&1; then
        echo "[ERROR] Conda가 설치되어 있지 않습니다."
        return 1
    fi
    DELETE_NAMES=()
    DELETE_PATHS=()
    while IFS= read -r CONDA_LINE; do
        [[ "$CONDA_LINE" =~ ^[[:space:]]*# ]] && continue
        [ -z "$CONDA_LINE" ] && continue
        CONDA_NAME=$(echo "$CONDA_LINE" | awk '{print $1}')
        CONDA_PATH=$(echo "$CONDA_LINE" | awk '{print $NF}')
        if [ "$CONDA_NAME" == "base" ]; then
            continue
        fi
        if [ -n "$CONDA_NAME" ] && [ -n "$CONDA_PATH" ]; then
            DELETE_NAMES+=("$CONDA_NAME")
            DELETE_PATHS+=("$CONDA_PATH")
        fi
    done < <(conda env list | grep -v "^#")
    if [ ${#DELETE_NAMES[@]} -eq 0 ]; then
        echo "[INFO] 삭제할 수 있는 Conda 환경이 없습니다."
        return 0
    fi
    echo "삭제할 환경을 선택해주세요."
    echo ""
    for i in "${!DELETE_NAMES[@]}"; do
        echo "$((i + 1)). [conda] ${DELETE_NAMES[$i]}"
    done
    echo ""
    read -p "Delete Environment Select : " DELETE_SELECT
    if ! [[ "$DELETE_SELECT" =~ ^[0-9]+$ ]]; then
        echo "[ERROR] 올바른 번호를 입력해주세요."
        return 1
    fi
    if [ "$DELETE_SELECT" -lt 1 ] || \
       [ "$DELETE_SELECT" -gt "${#DELETE_NAMES[@]}" ]; then
        echo "[ERROR] 존재하지 않는 환경입니다."
        return 1
    fi
    INDEX=$((DELETE_SELECT - 1))
    DELETE_ENV_NAME="${DELETE_NAMES[$INDEX]}"
    DELETE_ENV_PATH="${DELETE_PATHS[$INDEX]}"
    # 삭제 확인
    echo ""
    echo "[WARNING] 선택한 Conda 환경을 삭제합니다."
    echo "[WARNING] 환경 이름: ${DELETE_ENV_NAME}"
    echo "[WARNING] 환경 경로: ${DELETE_ENV_PATH}"
    echo ""
    read -p "정말 삭제하시겠습니까? (y/n) : " DELETE_CONFIRM
    if [[ "$DELETE_CONFIRM" != "y" ]]; then
        echo ""
        echo "[INFO] Conda 환경 삭제를 취소했습니다."
        return 0
    fi
    echo ""
    echo "[INFO] Conda 환경을 삭제합니다."
    conda env remove -n "$DELETE_ENV_NAME" -y
    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] Conda 환경 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    echo "[SUCCESS] Conda 환경이 삭제되었습니다."
    echo "[INFO] 삭제된 환경: ${DELETE_ENV_NAME}"
    return 0
}
# 가상환경 선택 또는 생성
select_virtual_environment() {
    list_virtual_environments
    if [ $? -ne 0 ]; then
        echo ""
        read -p "새로운 Conda 환경을 생성하시겠습니까? (y/n) : " CREATE_VE
        if [[ "$CREATE_VE" == "y" ]]; then
            create_conda
            if [ $? -ne 0 ]; then
                return 1
            fi
        else
            echo ""
            echo "[INFO] 가상환경 생성을 취소했습니다."
            return 1
        fi
        return 0
    fi
    echo ""
    read -p "Virtual Environment Select : " VE_SELECT
    if ! [[ "$VE_SELECT" =~ ^[0-9]+$ ]]; then
        echo "[ERROR] 올바른 번호를 입력해주세요."
        return 1
    fi
    NEW_ENV_OPTION=$((${#VE_NAMES[@]} + 1))
    if [ "$VE_SELECT" -eq "$NEW_ENV_OPTION" ]; then
        create_conda
        if [ $? -ne 0 ]; then
            return 1
        fi
        return 0
    fi
    if [ "$VE_SELECT" -lt 1 ] || \
       [ "$VE_SELECT" -gt "${#VE_NAMES[@]}" ]; then
        echo "[ERROR] 존재하지 않는 가상환경입니다."
        return 1
    fi
    INDEX=$((VE_SELECT - 1))
    SELECTED_VE="${VE_NAMES[$INDEX]}"
    VE_TYPE="${VE_TYPES[$INDEX]}"
    SELECTED_VE_PATH="${VE_PATHS[$INDEX]}"
    SELECTED_PYTHON_VERSION="${VE_PYTHON_VERSIONS[$INDEX]}"
    echo ""
    echo "[SUCCESS] 가상환경이 선택되었습니다."
    echo "[INFO] 이름: ${SELECTED_VE}"
    echo "[INFO] 종류: ${VE_TYPE}"
    echo "[INFO] Python 버전: ${SELECTED_PYTHON_VERSION}"
    echo "[INFO] 경로: ${SELECTED_VE_PATH}"
    return 0
}
# Conda 가상환경 관리 메뉴
manage_virtual_environment() {
    while true; do
        echo ""
        echo "========================================"
        echo "     Conda Virtual Environment Manager"
        echo "========================================"
        echo ""
        echo "1. 가상환경 선택"
        echo "2. 가상환경 생성"
        echo "3. 가상환경 삭제"
        echo "4. 종료"
        echo ""
        read -p "Select : " VE_MENU
        case "$VE_MENU" in
            1)select_virtual_environment;;
            2)create_conda;;
            3)delete_virtual_environment;;
            4)
                echo ""
                echo "[INFO] 가상환경 관리 메뉴를 종료합니다."
                return 0
                ;;
            *)
                echo ""
                echo "[ERROR] 올바른 번호를 선택해주세요."
                ;;
        esac
    done
}