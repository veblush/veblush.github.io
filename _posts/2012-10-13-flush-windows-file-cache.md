---
layout: post
title: 윈도우 파일 캐시 비우기
date: 2012-10-13
categories:
  - windows
lang: ko
---

오랜만에 클라이언트 시동 시간을 줄이는 최적화 작업을 하면서 Cold Start 환경을 만들어야
할 상황이 생겼다.
(Cold Start 는 시동에 필요한 파일들이 캐시에 있지 않에 디스크로부터 파일 데이터를
 읽어야 하는 Start 를 의미한다. 때문에 느리다.)

간단히 File Cache 를 비워주면 되는데 이게 말처럼 간단하지 않다.
파일 캐시를 비운다라는게 일반적으로는 필요한 기능이 아니기 때문에 OS 가 굳이
일반 유저를 위해 기능으로 만들지 않기 때문이다.
때문에 예전에 Windows XP 환경에서 개발을 할 때는 두 가지 우회 방법 중 하나를 사용했다.

- PC 재부팅:
  단순 무식한 방법이지만 확실하다. 다만 부팅 시간이 소요되는 단점이 있다.

- 과중한 메모리 할당:
  PC 재부팅이 오래 걸리니까 메모리를 무지막지하게 할당하는 프로그램을 돌려 캐시가
  할당했던 메모리를 강제로 빼았는 방식이다. 효과적인 방법이나 캐시 메모리만 제거되는게
  아니라 지금 돌고 있는 잘 도는 프로세스의 워킹셋 까지 페이징을 시켜서 한참동안 시스템이
  버벅거리는 문제가 생긴다.

위 두가지 방법을 쓰면서 "OS 가 해주면 좋겠는데 그걸 안해주니 고생하는 구나" 라고 생각했었다.
이번에 Windows 7 환경에서 작업을 하기전에 혹시나 해서 찾아봤더니! 있다! 이제는 있다!

## Sysinternals Cacheset / Rammap

참 고마운 사람들이다. Sysinternals 에서 만든 유틸리티들을 요긴하게 잘 쓰고있는데
캐시를 날리는 유틸리티도 만들어 놨다.
먼저 [Cacheset](http://technet.microsoft.com/en-us/sysinternals/bb897561.aspx)
은 캐시 크기를 제어하는 유틸리티다. 

![]({% asset_path CacheSet.png %})

여기서 Clear 버튼을 누르면 캐시가 날아간다. 하지만 다 날아가지 않는다.
여기에 윈도우 캐시 시스템의 미묘함을 볼 수 있다.
완전히 날리기 위해서는 추가로
[Rammap](http://technet.microsoft.com/en-us/sysinternals/ff700229.aspx) 을 사용해야 한다.
Rammap 은 시스템 메모리의 사용 상태를 보는 유틸리티이다.
거기에 유틸리티 기능으로 Empty 기능이 포함되어 있다.

![]({% asset_path RamMapEmpty.png %})

Empty - Empty Standby List 메뉴를 선택하면 캐시를 완전히 비울 수 있다.
이 RamMap 은 Windows Vista 부터 사용할 수 있기 때문이 이 편리한 과정은
Windows Vista 부터 사용할 수 있다.

특히 Empty Standby List 과정이 중요하고 효과적인 과정이라 만약 번거롭다면
두 번째 과정만 수행해도 큰 무리는 없다.

아래는 각 과정을 밟을 때 작업 관리자로 본 메모리 상태이다.
캐시됨 이라는 항목이 캐시에 관여한 메모리 크기인데 첫 번째 Cacheset Clear 를
눌렀을 때는 오히려 약간 증가한 것을  볼 수 있다. 그리고 두 번째 Empty Standby List 를
눌렀을 때 확연히 줄어드는 것을 볼 수 있다.
(캐시됨 항목에 사실 Cacheset Workingset 이 포함되지 않는다.
 캐시됨 = Standby + Modified.
 따라서 첫번째 Cacheset Clear 때 캐시됨 메모리가 늘어나는 것은 자연스러운 현상이다.)

![]({% asset_path CacheMemoryFlow.png %})

자 이제 부터 Cold Start 를 위해서는 이 방법을 쓰면 좋다.
더 이상 시스템 재시작이나 메모리 과할당을 사용할 필요가 없다.
그럼 왜 Cacheset Clear 만으로 안되는지 살펴보자.

## Windows Cache System with Memory Mapped File

먼저 윈도우의 파일 I/O 요청이 어떻게 동작하는지 Windows Internals 에 있는 도표를 통해 살펴보자.
(Windows Internals 5th Edition, Chapter 10 Cache Manager, Figure 10-10)

![]({% asset_path Internals.png %})

간단히 정리하면 윈도우의 파일 I/O 요청은 다음과 같은 순서로 수행된다.
- File I/O 요청이 들어오면 파일 시스템 드라이버가 캐시 매니저에게 데이터를 요청한다.
- 캐시 매니저 그 요청을 받아서 보고 있는 데이터면 주고 없으면 메모리 매니저에게 데이터를 요청한다. (빨간색 상자)
- 메모리 매니저는 Memory Mapped File 로 파일과 메모리를 연결해 I/O 요청을 수행한다. (파란색 상자)

여기서 Cacheset 이 처리하는 부분은 캐시 매니저의 워킹셋 메모리다.
(엄밀히 말하면 시스템 워킹셋이다)
이것만으로 캐시가 다 지워지지 않는 것은 메모리 매니저의 Standby 메모리 때문이다.
Standby 는 또 뭔가?

메모리 매니저가 캐시 매니저에게 파일에 대한 요청을 받으면 이를 Memory Mapped File 로
메모리를 할당해 I/O 요청을 처리하도록 해준다.
I/O 작업이 끝나서 더 이상 필요 없을 때 메모리 해제 요청을 하면 메모리 매니저는
이를 해제하면서 이 메모리 영역을 Standby 상태로 만들고 그냥 내버려 둔다.
이 상태에서는 실제 소유권이 있지 않아 다른 프로세스가 메모리가 필요하다고 요청을 하면
재깍 초기화 해서 넘겨준다.
하지만 메모리가 여유가 있는 상태라면 Standby 상태로 계속 메모리에 남아있게 된다.
이 때 캐시 매니저가 동일한 파일을 달라고 하면 디스크에서 얻어오는게 아니라
Standby 메모리를 바로 넘겨준다. 일종의 2차 캐시 역할을 하는 셈이다.

때문에 Cacheset Clear 를 아무리 해도 이 Standby 메모리 영역에 남아 있는 캐시 데이터가
있어서 캐시를 완전하게 비울 수 없던 것이다.

Rammap 을 사용하면 어떤 파일이 Standby 상태로 메모리에 올라와 있는지 볼 수 있다.

![]({% asset_path Rammap2.png %})

이런 이유로 Cache 워킹셋을 비우고 Standby 메모리도 비워야 캐시가 완전히 빈 상태를 만들 수 있는 것이다.

## 구현

이제 마지막으로 이 기능들은 실제 어떻게 구현되어 있을까? OS 가 제공하는
특정 API 를 사용할 것 같은데 간단히 살펴보자.
Cacheset 의 Clear 기능은 Sysinternal 의 Cacheset 소개 페이지의 How It Works
부분을 보면 어떻게 구현했는지 설명이 되어 있다.
아래 소스처럼 (문서화되지 않은) NtSetSystemInformation 함수를 사용해 FileCache 의
WorkingSet 크기를 조절한다. (최소소, 최대 값을 모두 -1 을 넣으면 Clear 로 동작한다.)

```cpp
SYSTEM_FILECACHE_INFORMATION i;
ZeroMemory(&info, sizeof(i));
i.MinimumWorkingSet = -1;
i.MaximumWorkingSet = -1;
NtSetSystemInformation(
  SystemFileCacheInformation,   // 21
  &i,
  sizeof(i));
```

Rammap 의 Empty Standby Memory 기능 구현에 대해서는 설명이 없어 Rammap 의
디스어셈블을 통해 살펴보았다.
마찬가지로 NtSetSystemInformation 을 사용하는데 다음과 같이 구현되어 있었다.

```cpp
SYSTEM_MEMORY_LIST_COMMAND c = MemoryPurgeStandbyList; // 4
NtSetSystemInformation(
  SystemMemoryListInformation,  // 80
  &c,
  sizeof(c));
```

어떻게 구현되는지 안김에 콘솔 유틸리티로 구현해보았다.
위 코드에 프로세스 권한 토큰 제어만 추가하면 손쉽게 만들 수 있다.
([FlushFileCache](http://pastebin.com/6kvkdQV2))

## 결론

Windows Vista 이후로는 간단히 유틸리티를 사용해 Cold Start 환경을 만들어 낼 수 있다.
자주 필요한 기능은 아니지만 좀 더 편해져서 좋다!

다음은 Windows 7 부터 추가된 리소스 매니저의 모습이다.
(참고로 작업 관리자와 리소스 매니저에 표시되는 값의 의미는
 [Measuring memory usage in Windows 7](http://brandonlive.com/2010/02/21/measuring-memory-usage-in-windows-7/)
 에 잘 정리되어 있다.)

![]({% asset_path FunnyModified.png %})

한글판와 영문판을 위/아래로 붙여봤는데 Modified 가 수정한 날짜,
Standby 가 대기 모드로 번역된 한글판 윈도우가 참 인상적이다. :)
