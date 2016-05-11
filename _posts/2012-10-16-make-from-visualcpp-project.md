---
layout: post
title: Make from VC++ Project
date: 2012-10-16
categories:
  - cpp
lang: ko
---

작년에 있었던 팀의 서버 프로그램은 윈도우, 리눅스 양쪽에서 실행 가능했다.
윈도우에서는 Visual C++ 를 리눅스에서는 gcc 를 사용해서 빌드를 했다.
팀내 빌드, 테스트 시나리오는 다음과 같다.

- 개발 단계에서는 Visual C++ IDE 를 사용해서 개발
- 개발 테스트는 Visual C++ 혹은 gcc 사용 (개발자 선호에 따라)
- 내부 테스트 및 실제 서비스는 gcc 로 빌드해 리눅스에서 서비스.

때문에 윈도우 빌드용 vcxproj 와 리눅스 빌드용 makefile 이 개별적으로 유지되고 있었다.
그래서 프로젝트 구성을 변경해야 할 경우 vcxproj 와 makefile 양쪽을 수정해야 하는 번거로움이 있었다.
양쪽을 동일하게 맞추는 것을 놓쳐 빌드가 깨지는 경우도 종종 있었다.

일반적으로 이런 상황을 해결하는 방법은 둘 다 커버할 수 있는 하나의 빌드 시스템을 사용하는 것이다.
cmake, scons 가 대표적인 멀티 플랫폼 빌드 시스템이다.
([Make Alternatives](http://freecode.com/articles/make-alternatives) 에서 잘 다루고 있다.)
두 시스템이 잘 되어 있어보여 적용할지를 고민하다가 최종적으로 쓰지 않는 것으로 결정했다.
이유는 다음과 같다.

- cmake, scons 는 마스터 빌드 설정 파일을 따로 만들어야 한다.
  즉 Visual C++ 프로젝트도 아니고 makefile 도 아닌 별도의 빌드 설정을 만들어야 한다.
  이 마스터 빌드 파일을 가지고 각 플랫폼별 빌드 파일을 만들어 주거나 직접 빌드를 한다.
  좋아보이나 마스터 빌드 설정을 하기 위해 모든 프로그래머가 사용법을 익혀야 하는 부담이 있다.
- Visual C++ IDE 를 사용해 개발하는데 이 IDE 에서 파일 추가/삭제 하던 작업을 마스터 빌드 설정을 통해서 해야 한다.
  쉬운 툴 작업이 번거로운 텍스트 편집 작업이 된다
- cmake, scons 모두 Visual C++ 를 지원하지만 (여러 오픈 소스가 그러하듯) 우선순위가 낮다.
  최신 버전 Visual C++ 지원이 엉성하거나 특정 컴파일 옵션을 사용할 수 없거나 할 수 있다.

만약 처음부터 cmake 나 scons 등을 썼다면 상황이 많이 달랐겠지만 중간에 빌드 솔루션을 바꾼다는게
간단하지 않을 뿐더러 이득보다 손해가 많을 상황이라 다른 해결책을 찾기로 했다. 그래서 생각해낸 것은

- 윈도우 빌드는 원래 하듯 Visual C++ 프로젝트 파일로 빌드 
- 리눅스 빌드는 make 가 Visual C++ 프로젝트 파일 내용을 읽어서 빌드

이렇게 하면 프로젝트 파일을 하나만 유지할 수 있어서 원래 해결하려 했던 문제가 자연스럽게 해결된다.
또한 새 시스템을 도입하는 것이 아니니 큰 학습 비용 없이 적응해 사용할 수 있다. 자 그럼 어떻게 할까?

![]({% asset_path GNU-VS.jpg %})

## Make, the Legacy

Make 는 1977 년에 첫 개발되어서 30 년 넘도록 Unix 계열 OS 에서 널리 사용되고 있다.
Rule 의 집합으로 이루어진 파일 makefile 을 바탕으로 빌드 작업을 수행해 주는데 Rule 의
간결하고 강력한 특성으로 아직까지도 광범위 하게 사용되고 있다.
다음은 makefile 의 간단한 예제이다. 

```make
# <rule>
# target: prerequisite
#   recipe

exe: main.o lib.o
  g++ main.o lib.o -o exe

main.o: main.cpp
  g++ -c main.cpp

lib.o: lib.cpp
  g++ -c lib.cpp
```

기본 개념이 강력한데 반해 (Rule 개념은 거의 모든 빌드 시스템에서 차용하고 있다.)
다만 워낙 옛날에 만들어지고 이러한 형태의 첫 프로그램이다 보니 Rule 외의 기능은 엉성하다.
변수, 제어, 함수 등 언어적 지원은 빈약하고 shell 명령으로 이루어져 다양하게 확장 가능한
recipe 에 비해 prerequisite 은 확장이 어렵다.
make 로 어떻게 하면 vcxproj 빌드를 할 수 있을까? 를 염두하며
[Make Manual](http://www.gnu.org/software/make/manual/) 을 읽고 나니 쉽지 않겠구나 라는 생각이 들었다.
(make 도 리눅스 개발 환경도 제대로 써본건 이때가 처음이기도 했다)

## Import File List

기본 개념은 간단하다. Make 가 실행될 때 프로젝트 파일인 vcxproj 포함되어 있는 cpp 파일
목록을 가져와 makefile 에 넣기. 목록을 제외한 나머지 부분은 (예를 들면 컴파일 옵션)
미리 파일에 적어두고 변경이 많고 플랫폼별 차이가 없는 파일 목록을 끌어오면 되지 않을까?

- 먼저 VC++ 프로젝트 파일로 부터 포함되어 있는 cpp 파일 목록을 추리는 기능을 만든다.
  makefile 로는 불가능해보여 (XML 파싱이 필요하므로) python 으로 작성한 스크립트를 만든다. (Import.py)
- makefile 의 include 기능을 이용해 목록을 가져와 해당 cpp 파일들을 빌드하게 만든다.

Import.py 는 프로젝트 파일로 부터 파일을 읽어 아래와 같은 형태의 결과를 출력한다.

```make
SRCS := main.cpp lib.cpp
OBJS := $(I)main.o $(I)lib.o

$(I)main.o : main.cpp
  g++ $(CXXFLAGS) -c $< -o $@

$(I)lib.o : lib.cpp
  g++ $(CXXFLAGS) -c $< -o $@
```

그 결과를 받아다가 make 가 처리하도록 makefile 에 아래와 같은 구문을 넣는다.

```make
include $(shell Import.py Program.vcproj > l.tmp && echo l.tmp)

exe : $(OBJS)
  g++ -o $@ $(OBJS)
```

이제 빌드할 파일 목록을 자동으로 가져올 수 있게 되었다.
이 목록은 컴파일 뿐 아니라 clean 에도 사용된다.
정확히 어떤 파일이 있고 (SRCS) 어떤 중간 생성물을 만드는지 (OBJS) makefile 이
알기 때문에 clean 도 해당 파일들만 깨끗하게 지울 수 있다.

## Include Dependency

앞서 만든 빌드 Rule 셋을 보면 사실 불완전한 부분이 있는데 바로 prerequisite 부분이다.
C/C++ 은 cpp 파일 뿐 아니라 #include 헤더가 변경되어도 재컴파일을 해야 하는데 이 부분이 빠져있다.
(예를 들어 main.cpp 가 lib.h 를 #include 하고 있다면 lib.h 가 변경되어도 main.cpp 가
 재컴파일이 되어야 한다. 따라서 저 위 main.o 룰의 prerequisite 은 main.cpp lib.h 가 되어야 한다)

 이 부분이 make 의 까다로운 부분인데 make 스스로 할 수 없으므로 (언어 종속적이라)
보통 makedep 과 같은 외부 프로그램을 사용해 makefile 파일 뒷부분에 dependency 룰을
추가하는 방식으로 동작한다. (make dep 이 그 과정을 수행한다)
반면 Visual C++ 의 경우 이 과정이 숨겨져 있어 자연스럽게 프로그래머는 이 부분을 신경쓰지 않아도 된다.
그래서 새 makefile 도 자연스럽게 #include 종속 관계를 얻을 수 있도록 Import.py 에 기능을 넣었다.

- Import.py 가 실행될 때 Dependency 를 얻어올 수 있는 Rule 파일을 생성함
- makefile 이 생성된 모든 Dependency Rule 파일을 가져옴

특정 C/C++ 파일이 어떤 파일에 대해 #include 종속을 가지는지는 gcc 를 사용해 쉽게 알아낼 수 있다.
gcc 의 -M 과 -MM [옵션](http://gcc.gnu.org/onlinedocs/cpp/Invocation.html)을 사용하면
다음과 같은 형태로 종속 룰을 출력한다.

```make
main.o : main.cpp lib.h
```

이와 같은 gcc 기능을 사용하도록 Import.py 는 프로젝트 파일로 부터 파일을 읽어 아래와 같은 형태의 결과를 출력한다.

```make
DEPS := $(I)main.d $(I)lib.h

$(I)main.o : $(I)main.d
$(I)main.d : main.cpp
  g++ -MM $< | sed 's,\(.*\)\.o[ :]*,$(I)\1.o $(I)\1.d : , ' > $@

$(I)lib.o : $(I)lib.d
$(I)lib.d : lib.cpp
  g++ -MM $< | sed 's,\(.*\)\.o[ :]*,$(I)\1.o $(I)\1.d : , ' > $@
```

file.d 형태의 dependency 파일을 생성하는 Rule 이다.
file.o 보다 먼저 file.d 를 생성하기 위해 prerequisite 설정해준다.
또한 file.o 뿐 아니라 file.d 도 #include dependency 가 걸리도록 sed 로 gcc 결과를 살짝 수정해준다.
Recipe 에 의해 생성된 main.d 파일은 다음과 같다.

```make
main.o main.d : main.cpp lib.h
```

생성된 \*.d 파일을 make 가 처리하도록 makefile 에 아래와 같은 구문을 넣는다.

```make
include $(filter $(DEPS),$(wildcard $(I)*.d))
```

이렇게 해서 Include Dependency 를 해결한다. 별도의 make dep 과정 없이 build 요청에
따라 알아서 재컴파일이 필요한 소스 파일을 make 가 잘 찾아 주게 되었다.

## Precompiled Header

Visual C++ 프로젝트는 precompiled header 를 사용하도록 되어있고 gcc 프로젝트는 그렇지 않도록 되어 있었다.
Precompiled header 를 사용하면 gcc 에서도 빌드 시간이 단축되므로 gcc make 에서도 사용하도록  Import.py 에 기능을 추가했다.

- Import.py 가 실행될 때 프로젝트 파일에서 Precompiled header 파일을 찾아서 gch 빌드 명령을 추가한다.
- gch 가 다른 파일 보다 먼저 빌드가 되어 소스파일의 #include 경로에 존재하면 gcc 가 빌드 때 gch 파일을 우선적으로 사용한다.
  (VC++ 와 명시적으로 지정하지 않아도 된다.)

Import.py 는 다음과 같은 형태의 명령을 추가한다.

```make
GCHS := $(I)pch.h.gch

$(I)pch.h.gch : pch.h
  g++ $(CXXFLAGS) -x c++-header $< -o $@

$(OBJS) : $(GCHS)
```

간단히 gcc 빌드에도 precompiled header 를 사용할 수 있게 되었다.

## More

작업을 하다보니 있으면 편한 자잘한 기능이 추가되었다. 추가한 기능을 정리하면

- 자동 병렬 빌드 기능
  빌드가 되는 CPU 의 코어 개수를 파악해 권장 개수 만큼 make 의 병렬 빌드 기능을 사용한다.
  (make 의 -j [옵션](http://www.gnu.org/software/make/manual/html_node/Parallel.html) 사용)
- vcxproj 파일을 지정하지 않았을 때 실행 폴더에 vcxproj 가 1개만 있는 경우 그 파일을 자동 선택.
  이런 기능은 make 도 있는데 은근히 편리하다.
- Prebuild, Postbuild 이벤트 지원
  프로그램의 Version 정보를 태깅하거나 symbol 등록을 할 때 사용한다.
- Google Performance Tools 빌드 옵션 지원
- 빌드에 필요한 라이브러리 지정 기능

처음에 생각했던 것보다 더 많은 기능이 추가 되었는데 이는 서버 관련 프로젝트가 10개 이상이었고
기능을 추가했을 때 이득을 볼 프로젝트가 많아서 였다.
추가 기능들로 makefile 은 다음과 같은 정보만 가지고 있었다.

- 종속 라이브러리 목록. 
- 출력 폴더/파일 이름. 
- 컴파일, 링크 옵션. 
- 병렬 빌드 여부, Google Performance Tools 사용 여부 등 기타 옵션.

다음은 위 작업이 적용된 어느 서버의 Makefile 내용이다.

```make
OUTDIR = ./Bin/
OUTPUT = $(OUTDIR)server

DEPLIB = Core Network Data

CXXFLAGS_CUSTOM = $(call lib_I,MySQL) -I./Bin -D_CHECK
LDFLAGS_CUSTOM  = $(call lib_L,MySQL) -lmysql

include MakefileTemplate
```

MakefileTemplate 은 Import.py 를 사용하며 다음과 같다. (일부만 표시)

```make
.PHONY : BuildEntry
BuildEntry : $(MAKE_BUILD_DEFAULTCONFIG) ;

ifneq ($(CONFIG),)
  ifndef VCXPROJ
    VCXPROJ := $(wildcard *.vcxproj)
  endif
  include $(shell Import.py $(VCXPROJ) > l.tmp && echo l.ret)
  include $(filter $(DEPS),$(wildcard $(I)*.d))
endif

$(OBJS) $(DEPS) $(GCHS) : | $(I)

$(I) :
  mkdir -p $(I)
```

## 결론

간단한 파이썬 스크립트와 make script 로 로 원하던 목표를 달성했다.
(파이썬 스크립트와 관련 make 스크립트의 라인 수가 200 이 채 되지 않는다) 
