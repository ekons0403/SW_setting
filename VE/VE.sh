#!/bin/bash
# Conda 환경 목록 확인
list_virtual_environments() {
    VE_NAMES=()
    VE_TYPES=()
    VE_PATHS=()
    VE_PYTHON_VERSIONS=()
    if ! command -v conda >/dev/null 2>&1;then
        echo ""
        print_message ERROR "Conda가 설치되어 있지 않습니다."
        print_message INFO "Anaconda 또는 Miniconda를 먼저 설치해주세요."
        return 1
    fi
    while IFS= read -r CONDA_LINE;do
        [[ "$CONDA_LINE" =~ ^[[:space:]]*# ]]&&continue
        [ -z "$CONDA_LINE" ]&&continue
        CONDA_NAME=$(echo "$CONDA_LINE"|awk '{print $1}')
        CONDA_PATH=$(echo "$CONDA_LINE"|awk '{print $NF}')
        if [ -n "$CONDA_NAME" ]&&[ -n "$CONDA_PATH" ];then
            PYTHON_VERSION=$("$CONDA_PATH/bin/python" --version 2>&1|awk '{print $2}')
            VE_NAMES+=("$CONDA_NAME")
            VE_TYPES+=("conda")
            VE_PATHS+=("$CONDA_PATH")
            VE_PYTHON_VERSIONS+=("$PYTHON_VERSION")
        fi
    done < <(conda env list|grep -v "^#")
    echo ""
    echo "========================================"
    echo "     Conda Virtual Environment List"
    echo "========================================"
    echo ""
    if [ ${#VE_NAMES[@]} -eq 0 ];then
        print_message INFO "생성된 Conda 가상환경이 없습니다."
        return 1
    fi
    echo "사용할 가상환경을 선택해주세요."
    echo ""
    for i in "${!VE_NAMES[@]}";do
        echo "$((i+1)). [${VE_TYPES[$i]}] ${VE_NAMES[$i]}"
        echo "   Python Version : ${VE_PYTHON_VERSIONS[$i]}"
        echo ""
    done
    echo "$(( ${#VE_NAMES[@]}+1 )). 새로운 Conda 환경 생성"
    return 0
}
# Conda 환경 생성
create_conda() {
    echo ""
    echo "========================================"
    echo "     Create Conda Environment"
    echo "========================================"
    echo ""
    if ! command -v conda >/dev/null 2>&1;then
        print_message ERROR "Conda가 설치되어 있지 않습니다."
        print_message INFO "Anaconda 또는 Miniconda를 먼저 설치해주세요."
        return 1
    fi
    read -p "사용할 Python 버전 : " PYTHON_VERSION
    if [ -z "$PYTHON_VERSION" ];then
        print_message ERROR "Python 버전을 입력해주세요."
        return 1
    fi
    read -p "생성할 Conda 환경 이름 : " VE_NAME
    if [ -z "$VE_NAME" ];then
        print_message ERROR "가상환경 이름을 입력해주세요."
        return 1
    fi
    if conda env list|awk '{print $1}'|grep -qx "$VE_NAME";then
        echo ""
        print_message ERROR "이미 존재하는 Conda 환경입니다."
        print_message INFO "환경 이름: ${VE_NAME}"
        return 1
    fi
    echo ""
    print_message INFO "Conda 환경을 생성합니다."
    print_message INFO "환경 이름: ${VE_NAME}"
    print_message INFO "Python 버전: ${PYTHON_VERSION}"
    echo ""
    conda create -n "$VE_NAME" python="$PYTHON_VERSION" -y
    if [ $? -ne 0 ];then
        echo ""
        print_message ERROR "Conda 환경 생성에 실패했습니다."
        return 1
    fi
    SELECTED_VE_PATH=$(conda env list|awk -v name="$VE_NAME" '$1==name{print $NF}')
    SELECTED_VE="$VE_NAME"
    VE_TYPE="conda"
    SELECTED_PYTHON_VERSION="$PYTHON_VERSION"
    echo ""
    print_message SUCCESS "Conda 환경 생성이 완료되었습니다."
    print_message INFO "환경 이름: ${SELECTED_VE}"
    print_message INFO "Python 버전: ${PYTHON_VERSION}"
    print_message INFO "환경 경로: ${SELECTED_VE_PATH}"
    return 0
}
# Conda 환경 삭제
delete_virtual_environment() {
    echo ""
    echo "========================================"
    echo "     Delete Conda Environment"
    echo "========================================"
    echo ""
    if ! command -v conda >/dev/null 2>&1;then
        print_message ERROR "Conda가 설치되어 있지 않습니다."
        return 1
    fi
    DELETE_NAMES=()
    DELETE_PATHS=()
    while IFS= read -r CONDA_LINE;do
        [[ "$CONDA_LINE" =~ ^[[:space:]]*# ]]&&continue
        [ -z "$CONDA_LINE" ]&&continue
        CONDA_NAME=$(echo "$CONDA_LINE"|awk '{print $1}')
        CONDA_PATH=$(echo "$CONDA_LINE"|awk '{print $NF}')
        if [ "$CONDA_NAME" == "base" ];then
            continue
        fi
        if [ -n "$CONDA_NAME" ]&&[ -n "$CONDA_PATH" ];then
            DELETE_NAMES+=("$CONDA_NAME")
            DELETE_PATHS+=("$CONDA_PATH")
        fi
    done < <(conda env list|grep -v "^#")
    if [ ${#DELETE_NAMES[@]} -eq 0 ];then
        print_message INFO "삭제할 수 있는 Conda 환경이 없습니다."
        return 2
    fi
    echo "삭제할 환경을 선택해주세요."
    echo ""
    for i in "${!DELETE_NAMES[@]}";do
        echo "$((i+1)). [conda] ${DELETE_NAMES[$i]}"
    done
    echo ""
    read -p "Delete Environment Select : " DELETE_SELECT
    if ! [[ "$DELETE_SELECT" =~ ^[0-9]+$ ]];then
        print_message ERROR "올바른 번호를 입력해주세요."
        return 1
    fi
    if [ "$DELETE_SELECT" -lt 1 ]||[ "$DELETE_SELECT" -gt "${#DELETE_NAMES[@]}" ];then
        print_message ERROR "존재하지 않는 환경입니다."
        return 1
    fi
    INDEX=$((DELETE_SELECT-1))
    DELETE_ENV_NAME="${DELETE_NAMES[$INDEX]}"
    DELETE_ENV_PATH="${DELETE_PATHS[$INDEX]}"
    echo ""
    print_message WARNING "선택한 Conda 환경을 삭제합니다."
    print_message WARNING "환경 이름: ${DELETE_ENV_NAME}"
    print_message WARNING "환경 경로: ${DELETE_ENV_PATH}"
    echo ""
    read -p "정말 삭제하시겠습니까? (y/n) : " DELETE_CONFIRM
    if [[ ! "$DELETE_CONFIRM" =~ ^[Yy]$ ]];then
        echo ""
        print_message INFO "Conda 환경 삭제를 취소했습니다."
        return 3
    fi
    echo ""
    print_message INFO "Conda 환경을 삭제합니다."
    conda env remove -n "$DELETE_ENV_NAME" -y
    if [ $? -ne 0 ];then
        echo ""
        print_message ERROR "Conda 환경 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    print_message INFO "가상환경 삭제 여부를 확인합니다."
    if conda env list|awk '{print $1}'|grep -Fxq "$DELETE_ENV_NAME";then
        print_message ERROR "Conda 환경이 아직 존재합니다."
        return 1
    fi
    print_message INFO "설치 목록에서 ${DELETE_ENV_NAME} 환경의 라이브러리를 삭제합니다."
    remove_installed_environment "$DELETE_ENV_NAME"
    if [ $? -ne 0 ];then
        print_message ERROR "가상환경 설치 목록 삭제에 실패했습니다."
        return 1
    fi
    echo ""
    print_message SUCCESS "Conda 환경 및 설치 목록이 삭제되었습니다."
    print_message INFO "삭제된 환경: ${DELETE_ENV_NAME}"
    return 0
}
# 가상환경 선택 또는 생성
select_virtual_environment() {
    list_virtual_environments
    if [ $? -ne 0 ];then
        echo ""
        read -p "새로운 Conda 환경을 생성하시겠습니까? (y/n) : " CREATE_VE
        if [[ "$CREATE_VE" =~ ^[Yy]$ ]];then
            create_conda
            if [ $? -ne 0 ];then
                return 1
            fi
        else
            echo ""
            print_message INFO "가상환경 생성을 취소했습니다."
            return 1
        fi
        return 0
    fi
    echo ""
    read -p "Virtual Environment Select : " VE_SELECT
    if ! [[ "$VE_SELECT" =~ ^[0-9]+$ ]];then
        print_message ERROR "올바른 번호를 입력해주세요."
        return 1
    fi
    NEW_ENV_OPTION=$((${#VE_NAMES[@]}+1))
    if [ "$VE_SELECT" -eq "$NEW_ENV_OPTION" ];then
        create_conda
        if [ $? -ne 0 ];then
            return 1
        fi
        return 0
    fi
    if [ "$VE_SELECT" -lt 1 ]||[ "$VE_SELECT" -gt "${#VE_NAMES[@]}" ];then
        print_message ERROR "존재하지 않는 가상환경입니다."
        return 1
    fi
    INDEX=$((VE_SELECT-1))
    SELECTED_VE="${VE_NAMES[$INDEX]}"
    VE_TYPE="${VE_TYPES[$INDEX]}"
    SELECTED_VE_PATH="${VE_PATHS[$INDEX]}"
    SELECTED_PYTHON_VERSION="${VE_PYTHON_VERSIONS[$INDEX]}"
    echo ""
    print_message SUCCESS "가상환경이 선택되었습니다."
    print_message INFO "이름: ${SELECTED_VE}"
    print_message INFO "종류: ${VE_TYPE}"
    print_message INFO "Python 버전: ${SELECTED_PYTHON_VERSION}"
    print_message INFO "경로: ${SELECTED_VE_PATH}"
    return 0
}
# Conda 가상환경 관리 메뉴
manage_virtual_environment() {
    while true;do
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
                print_message INFO "가상환경 관리 메뉴를 종료합니다."
                return 0
                ;;
            *)
                echo ""
                print_message ERROR "올바른 번호를 선택해주세요."
                ;;
        esac
    done
}