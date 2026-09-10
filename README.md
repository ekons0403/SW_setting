# SW_setting

Linux 서버 환경에서 자주 사용하는 **AI / Machine Learning / Development Software를 쉽고 일관된 방식으로 설치·삭제·관리하기 위한 Shell 기반 Software Installer**입니다.

각 Software를 개별적으로 설치하는 대신 하나의 CLI 메뉴에서 Software 설치, 삭제, Conda 가상환경 관리 및 설치 상태 확인을 수행할 수 있도록 구성되어 있습니다.

## Features

* SW Library 통합 설치 / 삭제
* Software별 독립적인 설치 Script 관리
* Conda Virtual Environment 관리
* 설치된 Software 목록 및 버전 관리
* 설치 / 삭제 상태 확인
* Software 설치 시 시스템 환경에 따른 버전 추천
* Library 번호 또는 이름을 이용한 설치
* 컬러 기반 상태 메시지
* 설치 결과 Log 관리
* GUI 환경에서 VS Code, PyCharm 등의 자동 실행 지원
* Software별 설치 방식에 맞춘 개별 검증

## Supported Software

현재 다음 Software Library를 지원합니다.

| No. | Software          | Category               | Installation |
| --: | ----------------- | ---------------------- | ------------ |
|   1 | Container Toolkit | Container / GPU        | System       |
|   2 | DeepStream        | AI / Video Analytics   | System       |
|   3 | Docker            | Container              | System       |
|   4 | JupyterLab        | Development / Notebook | Conda        |
|   5 | Keras             | Machine Learning       | Conda        |
|   6 | OpenFOAM          | CFD / Simulation       | System       |
|   7 | PyCharm           | Development            | System       |
|   8 | PyTorch           | Machine Learning       | Conda        |
|   9 | Scikit-learn      | Machine Learning       | Conda        |
|  10 | TensorFlow        | Machine Learning       | Conda        |
|  11 | TensorRT          | AI / Inference         | Conda        |
|  12 | VS Code           | Development            | System       |

> `lib` 디렉토리에 새로운 Library Script를 추가하면 `SW_setting.sh`에서 Library 목록을 자동으로 인식합니다.

## Project Structure

```text
SW_setting/
├── SW_setting.sh
├── VE/
│   └── VE.sh
├── lib/
│   ├── container_toolkit.sh
│   ├── deepstream.sh
│   ├── docker.sh
│   ├── jupyter_lab.sh
│   ├── keras.sh
│   ├── openfoam.sh
│   ├── pycharm.sh
│   ├── pytorch.sh
│   ├── scikit_learn.sh
│   ├── tensorflow.sh
│   ├── tensorrt.sh
│   └── vscode.sh
├── log/
│   └── installed_sw.log
├── logger.sh
├── utils.sh
└── README.md
```

## Requirements

기본적으로 Ubuntu 기반 Linux 서버 환경을 대상으로 합니다.

### Required

* Ubuntu Linux
* Bash
* `sudo`
* `curl`
* `wget`
* `git`

### Conda

Conda 기반 Software를 설치하려면 Anaconda 또는 Miniconda가 필요합니다.

```bash
conda --version
```

Conda가 설치되어 있지 않은 경우 Anaconda 또는 Miniconda를 먼저 설치해야 합니다.

## Installation

Repository를 Clone합니다.

```bash
git clone https://github.com/ekons0403/SW_setting.git
cd SW_setting
```

실행 권한을 부여합니다.

```bash
chmod +x SW_setting.sh
```

실행합니다.

```bash
./SW_setting.sh
```

또는

```bash
bash SW_setting.sh
```

## Main Menu

프로그램을 실행하면 다음과 같은 메뉴를 사용할 수 있습니다.

```text
========================================
 SW Library Installer
========================================

1. SW Library 설치
2. SW Library 삭제
3. 가상환경 관리
4. 현재 설치된 SW
5. 종료

Select :
```

### 1. SW Library 설치

설치 가능한 Software Library 목록을 확인하고 설치할 수 있습니다.

```text
========================================
 Installable Libraries
========================================

  1. container_toolkit
  2. deepstream
  3. docker
  4. jupyter_lab
  5. keras
  6. openfoam
  7. pycharm
  8. pytorch
  9. scikit_learn
 10. tensorflow
 11. tensorrt
 12. vscode

========================================

Install Library :
```

Library 이름을 직접 입력할 수도 있고 번호를 입력할 수도 있습니다.

```text
Install Library : 8
```

또는

```text
Install Library : pytorch
```

입력한 Library에 따라 필요한 설치 환경을 자동으로 구성합니다.

## Virtual Environment

Conda 환경이 필요한 Software는 설치 전에 사용할 Virtual Environment를 선택합니다.

```text
========================================
     Conda Virtual Environment List
========================================

1. [conda] pytorch
   Python Version : 3.12.13

2. [conda] tensorflow
   Python Version : 3.12.13

3. 새로운 Conda 환경 생성
```

기존 환경을 선택하거나 새로운 Conda 환경을 생성할 수 있습니다.

### Create Conda Environment

```text
사용할 Python 버전 : 3.12
생성할 Conda 환경 이름 : pytorch
```

다음 명령과 동일한 방식으로 Conda 환경이 생성됩니다.

```bash
conda create -n pytorch python=3.12 -y
```

## Software Version Recommendation

일부 Software는 시스템 환경을 확인한 후 적절한 버전을 추천합니다.

예를 들어 GPU Software의 경우 다음과 같은 시스템 정보를 확인할 수 있습니다.

```text
NVIDIA Driver : 595.71.05
CUDA          : 13.2
Python        : 3.12
Environment   : pytorch
```

이후 현재 환경에 맞는 Software 버전을 추천하고 사용자가 선택할 수 있도록 구성되어 있습니다.

```text
1. 추천 버전으로 설치
2. 직접 입력
```

추천 버전을 사용하지 않고 직접 버전을 지정하는 것도 가능합니다.

## Installation Verification

각 Library는 단순히 패키지를 설치하는 것에 그치지 않고 설치 후 동작 여부를 확인하도록 구성되어 있습니다.

예를 들어 PyTorch의 경우 다음과 같은 정보를 확인합니다.

```text
PyTorch Version
CUDA Version
CUDA Available
GPU Count
GPU Name
```

TensorFlow 역시 GPU 인식 여부를 확인하며, TensorRT는 TensorRT Builder 생성 여부를 확인합니다.

이를 통해 단순히 `pip install`이 성공했는지만 확인하는 것이 아니라 **실제 Software가 정상적으로 동작하는지 확인**합니다.

## Installed Software

메인 메뉴의 `4. 현재 설치된 SW`를 선택하면 설치 기록을 확인할 수 있습니다.

설치 정보는 다음 파일에 저장됩니다.

```text
log/installed_sw.log
```

설치 Software의 이름, 설치 환경, Python 버전 및 Software별 Metadata를 관리합니다.

예:

```text
pytorch | conda | pytorch | 3.12.13 | pytorch=...
tensorflow | conda | tensorflow | 3.12.13 | tensorflow=...
vscode | system | ...
```

## Software Uninstallation

메인 메뉴에서

```text
2. SW Library 삭제
```

를 선택하면 현재 설치된 Software 목록을 확인할 수 있습니다.

Library 이름 또는 설치 목록의 번호를 사용하여 삭제할 수 있습니다.

```text
Uninstall Library : 8
```

삭제가 완료되면 실제 Software가 제거되었는지 확인하고 설치 기록에서도 해당 Software를 제거합니다.

## System Software

일부 Software는 Conda 환경이 아닌 시스템 전체에 설치됩니다.

예:

* Docker
* NVIDIA Container Toolkit
* DeepStream
* OpenFOAM
* PyCharm
* VS Code

이러한 Library는 `REQUIRE_VENV=false` 설정을 사용하여 별도의 Conda 환경 선택 없이 설치합니다.

## Conda Software

다음과 같은 Python 기반 Software는 Conda 환경을 선택하여 설치할 수 있습니다.

* JupyterLab
* Keras
* PyTorch
* Scikit-learn
* TensorFlow
* TensorRT

각 Software Script에서

```bash
REQUIRE_VENV=true
```

를 사용하여 Virtual Environment 사용 여부를 지정합니다.

## Library Module Structure

각 Software는 `lib` 디렉토리에서 독립적인 Shell Script로 관리됩니다.

기본적인 Library 구조는 다음과 같습니다.

```bash
#!/bin/bash

REQUIRE_VENV=true

get_system_info() {
    ...
}

get_installed_software() {
    ...
}

install_software() {
    ...
}

uninstall_software() {
    ...
}
```

`SW_setting.sh`는 Library Script를 동적으로 로드하여 `install_software`와 `uninstall_software` 함수를 실행합니다.

따라서 새로운 Software를 추가할 경우 기존 Main Script를 크게 수정하지 않고 `lib`에 새로운 Script를 추가할 수 있습니다.

## Utility Functions

공통 기능은 `utils.sh`에서 관리합니다.

주요 기능:

```text
print_message()
print_sw_meta()
to_lower()
check_internet()
get_library_module()
select_required_venv()
load_module_function()
clear_screen()
```

상태 메시지는 다음과 같이 색상으로 구분됩니다.

| Type    | Description |
| ------- | ----------- |
| INFO    | 일반 정보       |
| SUCCESS | 작업 성공       |
| WARNING | 경고          |
| ERROR   | 오류          |

예:

```bash
print_message INFO "설치를 시작합니다."
print_message SUCCESS "설치가 완료되었습니다."
print_message WARNING "주의가 필요합니다."
print_message ERROR "설치에 실패했습니다."
```

## Logging

설치된 Software 정보는 다음 파일에서 관리합니다.

```text
log/installed_sw.log
```

Logging 관련 기능은 `logger.sh`에서 관리합니다.

주요 목적은 다음과 같습니다.

* 설치 Software 기록
* Software 버전 기록
* Conda 환경 기록
* 설치 Metadata 관리
* Software 삭제 시 기록 정리

## Adding a New Software

새로운 Software를 추가하려면 `lib` 디렉토리에 Script를 추가합니다.

예:

```bash
touch lib/example.sh
```

기본 구조:

```bash
#!/bin/bash

REQUIRE_VENV=true

get_system_info() {
    ...
}

install_software() {
    ...
}

uninstall_software() {
    ...
}
```

Script를 추가한 후:

```bash
./SW_setting.sh
```

를 실행하면 Library 목록에서 자동으로 인식됩니다.

## Design

SW_setting은 다음과 같은 구조로 동작합니다.

```text
                    SW_setting.sh
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
      utils.sh        VE/VE.sh      logger.sh
          │              │              │
          │              ▼              ▼
          │        Conda Environment   Log
          │
          ▼
       lib/*.sh
          │
    ┌─────┼─────┬───────────────┐
    ▼     ▼     ▼               ▼
 PyTorch  TF  TensorRT       VS Code
```

Main Script는 공통적인 설치/삭제 흐름과 메뉴를 담당하고, 실제 Software별 설치 방법은 각 Library Script에서 담당합니다.

## Current Status

현재 지원되는 Library:

* [x] Container Toolkit
* [x] DeepStream
* [x] Docker
* [x] JupyterLab
* [x] Keras
* [x] OpenFOAM
* [x] PyCharm
* [x] PyTorch
* [x] Scikit-learn
* [x] TensorFlow
* [x] TensorRT
* [x] VS Code

## Future Work

향후 다음 기능을 추가할 예정입니다.

* [ ] 더 많은 AI / ML Framework 지원
* [ ] AMD ROCm Software 지원 확대
* [ ] NVIDIA / AMD GPU 환경 자동 감지 개선
* [ ] Software Compatibility Matrix 연동
* [ ] 설치 환경 자동 검증 강화
* [ ] 설치 실패 원인 분석 개선
* [ ] 설치 결과 Report 기능
* [ ] Software Version 관리 기능 강화

## License

This project is currently maintained for internal development and server environment setup purposes.

License information will be added in a future release.

## Repository

[SW_setting GitHub Repository](https://github.com/ekons0403/SW_setting?utm_source=chatgpt.com)

```

이 정도면 지금 단계의 README로 꽤 적절해. 특히 현재 코드가 **`lib/*.sh`를 동적으로 읽는 구조**라서, README에도 그 구조를 중심으로 설명했어. 실제 `SW_setting.sh`도 `lib`의 `.sh` 파일을 자동으로 Library 목록으로 만들고 번호 선택을 지원하고 있어.

한 가지는 **README에 버전 번호를 박아 넣지 않은 것**도 의도한 거야. 지금 프로젝트가 계속 버전 추천 로직을 수정하는 단계라 README에는 "현재 지원 Software / 구조 / 사용법" 위주로 두는 게 유지보수하기 좋아.
```
