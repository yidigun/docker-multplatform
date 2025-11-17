# Docker 다중 플랫폼 이미지 빌드 템플릿

## `Makefile` 사용법

본 Makefile 과 스크립트는 다중 플랫폼 이미지 빌드 과정을 편리하게 할 수 있도록 제작되었다.

### 요구사항

* GNU bash: https://www.gnu.org/software/bash/
* GNU make: https://www.gnu.org/software/make/
* `docker-cli`, `docker-buildx-pligin`: https://www.docker.com/
* `regclient/regctl`: https://regclient.org/install/
* 필요한 호스트 목록 (Windows PC 1대로도 가능은 함)
    * make를 실행할 Linux 호스트 (WSL 가능)
    * 리눅스 이미지 빌드 가능한 x86_64(amd64), aarch64(arm64) 호스트 (WSL 가능, 느리지만 `qemu-user-static` 가능)
    * Windows 컨테이너 빌드 가능한 호스트
        * Docker Desktop 사용시 Docker Desktop은 Windows 컨테이너로 설정하고, WSL에는 리눅스용 docker 별도 설치

### 로컬 설정 파일 `config.local.mk`

`local.config.mk` 파일을 생성해서 변수를 수정하면 로컬에 맞는 환경 정보를 덮어쓰도록 할 수 잇다.

```makefile
# local.config.mk

IMAGE_NAME=test1/my-hello
CONTEXT_WINDOWS=default
```

### 명령행 설정(매크로)

기본적으로 퍼블릭 레포지토리(레지스트리)에 푸시하지 않도록 되어있는데,
릴리즈할 때는 다음과 같이 명령행에서 오버라이드 가능하다.

```shell
make PUSH_PUBLIC=yes SET_LATEST=yes
```

### Buildx용 builder 생성

`Makefile`의 `$(BUILDER_CONFIG)` 설정을 수정한다.

```makefile
define BUILDER_CONFIG
anas ssh://anas linux/arm64,linux/arm/v7,linux/arm/v6
xvms ssh://xvms linux/amd64,linux/amd64/v2,linux/riscv64,linux/ppc64,linux/ppc64le,linux/s390x, linux/386, linux/loong64
endef
```

`$builder`는 `Makefile`에 설정된 `$(BUILDER)` 이름이어야 한다.

```shell
make create-$builder
```

## 다중 플랫폼 이미지의 구조

Docker 레지스트리의 이미지 저장 구조는 실제 이미지와 이에 대한 정보를 담고 있는 manifest로 구성되어 있다.
Manifest 중에는 단일 이미지에 대한 manifest가 아니라 여러 manifest의 참조 목록을 가지고 있는 것이 있는데,
이를 Docker에서는 'manifest list'라고 하고 OCI 표준에서는 'index' 라고 한다.

우리가 사용하는 `:latest` 같은 `tag`는 이 manifest를 지정하는 포인터라고 생각하면 된다.
따라서 어떤 `:latest`는 하나의 이미지일 수도 있고, 여러 이미지에 대한 목록일 수도 있다.

그리고 각각의 manifest에는 `Platform`이라는 속성으로 어떤 시스템에서 구동 가능한지가 지정하도록 되어있다.
Docker 데몬은 이 `Platform`을 보고 자신에게 맞는 이미지를 선택해서 `pull`하게 된다.

```
$ docker buildx imagetools inspect dagui0/my-hello:latest
Name:      docker.io/dagui0/my-hello:latest
MediaType: application/vnd.docker.distribution.manifest.list.v2+json
Digest:    sha256:d2ec59f68e235b250157f1f03f2a7a5177362341ec489e494fc01580fe1b3a41
           
Manifests: 
  Name:      docker.io/dagui0/my-hello:latest@sha256:fadf49d7011c5478e9e0f589651fb776e5d8205b4def73852806cabf97ff189d
  MediaType: application/vnd.oci.image.manifest.v1+json
  Platform:  linux/amd64
             
  Name:      docker.io/dagui0/my-hello:latest@sha256:5d7263677ef187f5563d7282583915b5e523e8713d3e1d29a4cee3ebc28a76fb
  MediaType: application/vnd.oci.image.manifest.v1+json
  Platform:  linux/arm64
             
  Name:      docker.io/dagui0/my-hello:latest@sha256:5995f61672ae515d63d10d39053bd829ba5f57c1a46f62f52746e1e5f1b19458
  MediaType: application/vnd.oci.image.manifest.v1+json
  Platform:  linux/arm/v7
             
  Name:      docker.io/dagui0/my-hello:latest@sha256:cadc87f4a91eee0f50710be285d6f69b57598b4e24b964ea7ce68dec8528f4ab
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  windows/amd64
  OSVersion: 10.0.17763.8027
             
  Name:      docker.io/dagui0/my-hello:latest@sha256:4644f2f4f21ca85437ad07ae598457760e0ed56f00d33aa252a4b580afb128d8
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  windows/amd64
  OSVersion: 10.0.20348.4405
             
  Name:      docker.io/dagui0/my-hello:latest@sha256:a628b385a080418b0caab013d592b82e631af4953e75d824659142916dc1e7e2
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  windows/amd64
  OSVersion: 10.0.26100.7171
```

### Windows 컨테이너 버전 문제

Windows 컨테이너는 호스트 OS버전과 컨테이너의 버전이 맞아야만 하는 문제가 있다.
버전이 딱 맞는 경우만 최상의 성능을 보여주는 `--isolation=process` 격리 방식으로 구동이 가능하다.

| Host OS             | `ltsc2025` | `ltsc2022` | `ltsc20019`     |
|---------------------|------------|------------|-----------------|
| Windows 11          | 가능       | 가능       | `hyperv`만 가능 |
| Windows Server 2022 | 불가       | 가능       | `hyperv`만 가능 |

OS 버전이 호환되지 않는 경우 구동이 불가능한 경우 아래와 같은 오류 발생하며, `hyperv`방식으로는 구동이 가능할 수 있다.

WSL이나 macOS에서 docker를 구동할 경우 1개의 Linux VM에서 모든 컨테이너를 돌리지만, 
`hyperv` 방식은 컨테이너마다 VM을 하나씩 생성하는 것으로 오버헤드가 상당히 클 수 밖에 없다.

```
C:\Users\dagui>docker run --rm --isolation=process anas:5000/dagui0/my-hello:windows-ltsc2019-20251117-7
docker: Error response from daemon: container e69d2e7285e9cfd4ea3cfc7ae51719cfe393cd51453e77befa07a40861ba68ea encountered an error during hcs::System::Start: failure in a Windows system call: The container operating system does not match the host operating system. (0xc0370101)

Run 'docker run --help' for more information
```

하지만 호스트 OS보다 높은 버전의 컨테이너 이미지는 `hyperv`로도 구동이 불가능하다. (이건 아무래도 라이센스와 어른들의 사정이 문제일듯 싶다)

따라서 Windows 컨테이너를 만들어서 공개하기 위해서는, 각 Windows 버전별로 이미지를 만들어서 manifest list에 추가해줘야 한다.
이 경우 위 예시의 `OSVersion` 속성으로 구분되게 되어 있다.

### Windows 컨테이너 버전 전체 호환성 목록

* Microsoft 문서 참조: 

https://learn.microsoft.com/ko-kr/virtualization/windowscontainers/deploy-containers/version-compatibility?tabs=windows-server-2025%2Cwindows-11

## 다중 플랫폼 이미지를 만드는 방법

### `docker-buildx-plugin`

리눅스만 만드는 경우는 Buildx 플러그인을 이용하면 다중 플랫폼 이미지를 쉽게 생성할 수 있다.

```shell
docker buildx build --builder mybuilder \
-t my-img:latest \
--platform linux/amd64,linux/386,linux/arm64,linux/arm/v7 \
--push .
```

Buildx 플러그인은 buildkit 이라는 컨테이너를 생성하고, buildx 플러그인은 buildkit에게 명령을 줘서 buildkit이 빌드의 작업을 실행하는 것이다.

### Windows 컨테이너용 다중 플랫폼 이미지

Windows 컨테이너는 플랫폼 별로 빌드하는 것이 아니라 버전별로 따로 빌드(Dockerfile 수정 또는 `--build-arg` 필요)해야 하는 상황이므로
Buildkit을 사용할 수가 없다. OS버전 마다 `docker build`를 이용해서 개별 이미지를 빌드한 후 `push` 해야한다.

그리고 Docker 빌드 호스트는 위의 버전 이슈 때문에 최신 버전의 OS를 사용해야 한다. (현재 Windows 11 또는 Windows Server 2025)

각각의 이미지를 만들어서 레지스트리에 push 한 이후에 `regctl`명령으로 manifest list를 수동으로 생성해줘야 한다.

```shell
# 통합 태그 생성
regctl index create --media-type application/vnd.docker.distribution.manifest.list.v2+json \
docker.io/dagui0/my-hello:20251117-6 \
--ref docker.io/dagui0/my-hello:linux-20251117-6 --platform linux/amd64 --platform linux/arm64 --platform linux/arm/v7 \
--ref docker.io/dagui0/my-hello:windows-ltsc2019-20251117-6 --platform windows/amd64,osver=10.0.17763.8027 \
--ref docker.io/dagui0/my-hello:windows-ltsc2022-20251117-6 --platform windows/amd64,osver=10.0.20348.4405 \
--ref docker.io/dagui0/my-hello:windows-ltsc2025-20251117-6 --platform windows/amd64,osver=10.0.26100.7171

# latest 생성(또는 덮어쓰기)
regctl index create --media-type application/vnd.docker.distribution.manifest.list.v2+json \
docker.io/dagui0/my-hello:latest \
--ref docker.io/dagui0/my-hello:linux-20251117-6 --platform linux/amd64 --platform linux/arm64 --platform linux/arm/v7 \
--ref docker.io/dagui0/my-hello:windows-ltsc2019-20251117-6 --platform windows/amd64,osver=10.0.17763.8027 \
--ref docker.io/dagui0/my-hello:windows-ltsc2022-20251117-6 --platform windows/amd64,osver=10.0.20348.4405 \
--ref docker.io/dagui0/my-hello:windows-ltsc2025-20251117-6 --platform windows/amd64,osver=10.0.26100.7171

# OS별 태그 삭제
regctl tag delete docker.io/dagui0/my-hello:linux-20251117-6
regctl tag delete docker.io/dagui0/my-hello:windows-ltsc2019-20251117-6
regctl tag delete docker.io/dagui0/my-hello:windows-ltsc2022-20251117-6
regctl tag delete docker.io/dagui0/my-hello:windows-ltsc2025-20251117-6
```
