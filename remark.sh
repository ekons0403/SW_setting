#!/bin/bash

# REMARK 파일 만들기
create_remark_file() {
    clear_screen

    echo ""
    echo "========================================"
    echo "          REMARK File Generator"
    echo "========================================"

    # 현재 설치된 SW 목록 표시
    show_installed_software

    echo ""
    read -r -p "위 SW를 토대로 REMARK 파일을 만들겠습니까? (Y/N) : " CONFIRM

    case "$CONFIRM" in
        [Yy]|[Yy][Ee][Ss])
            ;;
        [Nn]|[Nn][Oo])
            print_message INFO "REMARK 파일 생성을 취소했습니다."
            return 0
            ;;
        *)
            print_message ERROR "Y 또는 N을 입력해주세요."
            return 1
            ;;
    esac

    # 바탕화면 경로 확인
    REMARK_DIR=$(xdg-user-dir DESKTOP 2>/dev/null)

    if [ -z "$REMARK_DIR" ]; then
        REMARK_DIR="${HOME}/Desktop"
    fi

    mkdir -p "$REMARK_DIR"

    REMARK_FILE="${REMARK_DIR}/REMARK_$(date +%Y%m%d_%H%M%S).txt"

    if [ ! -s "$LOG_FILE" ]; then
        print_message ERROR "설치된 SW 기록이 없습니다."
        return 1
    fi

    {
        echo "========================================"
        echo "        Installed Software REMARK"
        echo "========================================"
        echo ""
        echo "Generated : $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""

        SW_INDEX=0

        while IFS='|' read -r SW_NAME SW_TYPE ENV_NAME PYTHON_VERSION SW_META; do
            [ -z "$SW_NAME" ] && continue

            SW_INDEX=$((SW_INDEX + 1))
            COMMANDS=()

            case "$SW_NAME" in
                deepstream)
                    COMMANDS=(
                        "deepstream-app --version-all"
                    )
                    ;;

                docker)
                    COMMANDS=(
                        "docker --version"
                        "docker info"
                    )
                    ;;

                nvidia-container-toolkit)
                    COMMANDS=(
                        ""path" : "nvidia-container-runtime""
                    )
                    ;;

                pytorch)
                    COMMANDS=(
                        "python -c \"import torch; print('PyTorch:', torch.__version__); print('CUDA:', torch.version.cuda); print('GPU:', torch.cuda.is_available())\""
                    )
                    ;;

                tensorflow)
                    COMMANDS=(
                        "python -c \"import tensorflow as tf; print('TensorFlow:', tf.__version__); print('GPU:', tf.config.list_physical_devices('GPU'))\""
                    )
                    ;;

                tensorrt)
                    COMMANDS=(
                        "python -c \"import tensorrt as trt; print('TensorRT:', trt.__version__)\""
                    )
                    ;;

                keras)
                    COMMANDS=(
                        "python -c \"import keras; print('Keras:', keras.__version__)\""
                    )
                    ;;

                scikit_learn)
                    COMMANDS=(
                        "python -c \"import sklearn; print('Scikit-learn:', sklearn.__version__)\""
                    )
                    ;;

                jupyter_lab)
                    COMMANDS=(
                        "jupyter lab --version"
                    )
                    ;;

                openfoam)
                    COMMANDS=(
                        "foamVersion"
                        "which foamRun"
                    )
                    ;;

                vscode)
                    COMMANDS=(
                        "code --version"
                    )
                    ;;

                *)
                    COMMANDS=()
                    ;;
            esac

            echo "[$SW_INDEX] $SW_NAME"

            if [ "$SW_TYPE" = "conda" ] && [ -n "$ENV_NAME" ]; then
                echo "Environment : $ENV_NAME"
                echo "\$ conda activate $ENV_NAME"
            fi

            if [ ${#COMMANDS[@]} -gt 0 ]; then
                for COMMAND in "${COMMANDS[@]}"; do
                    echo "\$ $COMMAND"
                done
            else
                echo "[확인 명령어 미등록]"
            fi

            echo ""
            echo "----------------------------------------"
            echo ""

        done < "$LOG_FILE"

    } > "$REMARK_FILE"

    if [ $? -ne 0 ]; then
        print_message ERROR "REMARK 파일 생성에 실패했습니다."
        return 1
    fi

    print_message SUCCESS "REMARK 파일 생성이 완료되었습니다."
    echo ""
    echo "파일 경로:"
    echo "$REMARK_FILE"
    echo ""

    return 0
}
