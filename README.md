# SW_setting

Ubuntu 환경에서 딥러닝 및 개발 관련 소프트웨어를 설치하고 관리하기 위한 자동화 스크립트입니다.

Conda 가상환경 관리부터 CUDA 버전에 따른 소프트웨어 설치, 설치 상태 확인, 삭제 및 설치 목록 관리까지 하나의 메뉴에서 수행할 수 있습니다.

---

## 주요 기능

- **소프트웨어 설치 및 삭제**
  - 번호 또는 소프트웨어 이름으로 설치 및 삭제
  - 실제 설치 상태 확인
  - 설치된 소프트웨어 중복 설치 방지
- **Conda 가상환경 관리**
  - 가상환경 생성 및 삭제
  - Python 버전별 환경 관리
  - 소프트웨어별 가상환경 설치 지원
- **CUDA 버전별 소프트웨어 설치**
  - 시스템 CUDA 버전 확인
  - CUDA 버전에 맞는 추천 소프트웨어 버전 제공
- **설치 목록 관리**
  - 설치된 소프트웨어 정보 기록
  - 가상환경 및 Python 버전 기록
  - 중복 로그 방지
  - 삭제 시 설치 기록 정리
- **의존성 관리**
  - Docker 삭제 시 NVIDIA Container Toolkit 연동 삭제 확인
  - TensorFlow 설치 시 Keras 의존성 패키지 설치 및 별도 기록
  - TensorFlow 삭제 시 Keras Backend 확인
  - PyTorch 삭제 시 Keras Backend 확인
- **REMARK 파일 생성**
  - 설치된 소프트웨어 목록 기반으로 REMARK.txt 생성
  - 소프트웨어별 버전 확인 명령어 포함

---

## 지원 소프트웨어

현재 관리 대상 소프트웨어는 다음과 같습니다.

| 번호 | Software | 설치 유형 |
|---:|---|---|
| 1 | DeepStream | System |
| 2 | Docker | System |
| 3 | JupyterLab | Conda |
| 4 | Keras | Conda |
| 5 | NVIDIA Container Toolkit | System |
| 6 | OpenFOAM | System |
| 7 | PyCharm | Conda |
| 8 | PyTorch | Conda |
| 9 | Scikit-learn | Conda |
| 10 | TensorFlow | Conda |
| 11 | TensorRT | Conda |
| 12 | VS Code | System |

*설치 유형은 현재 스크립트의 가상환경 사용 설정을 기준으로 구분합니다.*

---

## 프로젝트 구조

```text
SW_setting/
├── SW_setting.sh
├── VE/
│   └── VE.sh
├── lib/
│   ├── deepstream.sh
│   ├── docker.sh
│   ├── jupyter_lab.sh
│   ├── keras.sh
│   ├── nvidia-container-toolkit.sh
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
└── remark.sh
```

### 주요 파일

| 파일 | 역할 |
|---|---|
| `SW_setting.sh` | 메인 메뉴 및 전체 프로그램 실행 |
| `VE/VE.sh` | Conda 가상환경 관리 |
| `lib/*.sh` | 개별 소프트웨어 설치 및 삭제 |
| `logger.sh` | 설치 목록 등록 및 삭제 |
| `utils.sh` | 공통 유틸리티 함수 |
| `remark.sh` | REMARK.txt 생성 |
| `log/installed_sw.log` | 설치된 소프트웨어 정보 저장 |

---

## 설치 및 실행

### 1. 저장소 다운로드

```bash
git clone https://github.com/ekons0403/SW_setting.git
cd SW_setting
```

### 2. 실행 권한 부여

```bash
chmod +x SW_setting.sh
```

### 3. 프로그램 실행

```bash
./SW_setting.sh
```

일부 시스템 소프트웨어 설치 및 삭제 과정에서는 sudo 권한이 필요할 수 있습니다.

---

## 메뉴 구성

프로그램 실행 시 다음 메뉴를 제공합니다.

```text
========================================
        SW Library Installer
========================================

1. SW Library 설치
2. SW Library 삭제
3. 가상환경 관리
4. 현재 설치된 SW
5. REMARK.txt 생성
6. 종료

Select :
```

### 1. SW Library 설치

- 설치 가능한 소프트웨어 목록 표시
- 이미 설치된 소프트웨어는 파란색 `[설치됨]` 표시
- 번호 또는 소프트웨어 이름으로 선택
- Conda 환경 선택
- 추천 버전 또는 직접 버전 입력

### 2. SW Library 삭제

- 설치 목록에서 소프트웨어 선택
- 해당 소프트웨어의 삭제 함수 실행
- 실제 삭제 여부 확인
- 설치 로그 정리

### 3. 가상환경 관리

- Conda 가상환경 생성
- 가상환경 삭제
- 가상환경 목록 관리

### 4. 현재 설치된 SW

- 설치 로그를 기준으로 현재 등록된 소프트웨어 확인
- Conda 환경 및 Python 버전 확인

### 5. REMARK.txt 생성

- 설치된 소프트웨어 목록을 기반으로 REMARK.txt 생성
- Desktop 경로에 파일 저장
- 기존 REMARK.txt가 있으면 덮어쓰기

---

## 설치 로그

설치된 소프트웨어 정보는 `log/installed_sw.log`에 저장됩니다.

### 로그 형식

**System 소프트웨어**

```text
docker|system|||version=...
```

**Conda 소프트웨어**

```text
tensorflow|conda|tensorflow|3.12|tensorflow=2.21.0;cuda=13.2
```

각 항목은 `|` 구분자로 구분됩니다.

| 필드 | 설명 |
|---|---|
| SW_NAME | 소프트웨어 이름 |
| SW_TYPE | system 또는 conda |
| ENV_NAME | Conda 환경 이름 |
| PYTHON_VERSION | Python 버전 |
| SW_META | 소프트웨어 버전 및 추가 정보 |

설치 로그는 중복 항목이 등록되지 않도록 관리합니다.

---

## 소프트웨어 의존성 관리

### TensorFlow와 Keras

TensorFlow 설치 시 Keras가 의존성 패키지로 함께 설치됩니다.

- TensorFlow 설치 후 Keras 설치 여부 확인
- Keras 설치 정보 별도 기록
- TensorFlow 삭제 시 Keras Backend 확인
- TensorFlow Backend를 사용하는 Keras의 동반 삭제 여부 확인

### PyTorch와 Keras

PyTorch는 기본적으로 Keras를 의존성으로 설치하지 않습니다.

- PyTorch 설치와 Keras 설치를 별도로 관리
- PyTorch 삭제 시 Keras Backend 확인
- Torch Backend를 사용하는 Keras의 동반 삭제 여부 확인

### Docker와 NVIDIA Container Toolkit

NVIDIA Container Toolkit은 Docker를 필요로 합니다.

- Toolkit 설치 전 Docker 설치 여부 확인
- Docker 삭제 시 Toolkit 설치 여부 확인
- Toolkit 동반 삭제 여부 확인

---

## 지원 환경

- Linux / Ubuntu
- NVIDIA GPU 환경
- Conda 가상환경
- CUDA 및 NVIDIA Driver가 설치된 시스템

소프트웨어별 지원 버전과 CUDA 호환성은 개별 설치 스크립트의 추천 버전 설정을 따릅니다.

---

## 향후 개선 예정

- 기존에 설치된 소프트웨어 자동 탐지
- 기존 설치 소프트웨어의 `installed_sw.log` 자동 등록
- 모든 Conda 환경의 설치 상태 동기화
- 설치 로그와 실제 설치 상태의 일관성 개선
- 소프트웨어별 설치 및 삭제 기능 지속 개선

---

## Repository

GitHub: https://github.com/ekons0403/SW_setting
