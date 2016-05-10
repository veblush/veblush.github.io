---
layout: post
title: Windows Installer 동작과 SSD 여유 공간
date: 2012-11-03
categories:
  - windows
lang: ko
---

## 도입

업무 PC 에 80GB SSD 를 장착하고 Windows 7 와 작업에 필요한 소프트웨어를 설치하고
디스크 여유 공간 확보 작업을 시작했다.
C 드라이브로 사용하는 80GB SSD 가 OS + 작업 공간으로 쓰기에 빠듯해
몇백 메가라도 줄일 수 있다면 줄일 작정이었다.
먼저 설치한 것들은 다음과 같다.

- Windows 7 64bit Ultimate (+SP1)
- Visual Studio 2008 Standard (+SP1)
- Visual Studio 2010 Premium (+SP1)
- Office 2010 Plus (+SP1)
- MS Update 의 모든 Hotfix 설치

설치 하고 나서 SSD 를 위해 다음과 같은 용량 확보 설정을 했다.

- 가상 메모리 끄기
- 최대 절전 모드 끄기
- 시스템 보호 기능 끄기
- 디스크 정리의 모든 항목 처리
- 윈도우 서비스팩 백업 삭제 (dism ...)

그리고 며칠 작업을 하고 나서 [SpaceSniffer](http://www.uderzo.it/main_products/space_sniffer/)
로 용량 측정을 해봤다. 사용 용량 43GB! SSD 전체 용량의 50% 가 넘는 크기다.
만약 2TB HDD 를 썼다면 신경도 않쓸 2% 의 용량인데 SSD 입장에서는 그렇지 못하다.
이 43GB 를 돈으로 환산하면 HDD 는 2천원인데 반해 SSD 는 6만원이나 된다.
(2TB HDD, 80GB SSD 모두 11만원 기준)

[![](http://4.bp.blogspot.com/-vaFKNeBnFlY/UJPAGeJO4kI/AAAAAAAAAHI/1OVTcwPAuMY/s1600/S_Space_1.png)](http://4.bp.blogspot.com/-vaFKNeBnFlY/UJPAGeJO4kI/AAAAAAAAAHI/1OVTcwPAuMY/s1600/S_Space_1.png)

누가 이렇게 용량을 차지하나 봤더니 Windows 폴더가 28GB 로 1등이다.
아니 왜 Windows 폴더가 28GB 나 하지? 설치는 DVD 1장으로도 되는데?
라는 생각에 더 살펴보니 Windows 폴더 아래 Installer 폴더가 9.8GB,
winsxs 폴더가 7.3GB 로 대부분의 용량을 차지하고 있었다.
그래서 Installer 폴더를 더 열어보면,
[![](http://3.bp.blogspot.com/-Tq0il9oTGKg/UJPBqzYwByI/AAAAAAAAAHQ/MPFMPrR6msc/s1600/S_Space_1b.png)](http://3.bp.blogspot.com/-Tq0il9oTGKg/UJPBqzYwByI/AAAAAAAAAHQ/MPFMPrR6msc/s1600/S_Space_1b.png)

Installer 폴더 바로 아래에 있는 msi, msp 확장자의 파일들이 4.6GB 를 차지하고 있고
$PatchCache$ 폴더 아래에 있는 여러 폴더안에 있는 파일들이 5.2GB 를 차지하고 있었다.
Installer 폴더에는 아래 그림처럼 여러 msi, msp 파일이 있다.
탐색기의 컬럼에 "제목" 필드를 추가하면 어떤 내용인지 알수 있는 정보를 볼 수 있다.
(모든 파일이 다 나오는 것은 아니다.)

[![](http://1.bp.blogspot.com/-4D4hSqxFTNI/UJSixycgCaI/AAAAAAAAAIo/I7__RlC9gxs/s1600/Installer_Files.png)](http://1.bp.blogspot.com/-4D4hSqxFTNI/UJSixycgCaI/AAAAAAAAAIo/I7__RlC9gxs/s1600/Installer_Files.png)

Installer/$PatchCache$ 폴더 아래엔 Managed 폴더가 있고 그 아래 여러 폴더가 있다.
그 중 하나의 폴더를 예로 살펴보면 다음과 같은 파일들을 볼 수 있다
[![](http://2.bp.blogspot.com/-pLGty6jOtJc/UJPJLMInQbI/AAAAAAAAAIQ/yd-xXrP6fVQ/s1600/Patch_Files.png)](http://2.bp.blogspot.com/-pLGty6jOtJc/UJPJLMInQbI/AAAAAAAAAIQ/yd-xXrP6fVQ/s1600/Patch_Files.png)

도대체 Installer 폴더는 어떤 용도의 폴더이길래 이런 파일들이 용량을 차지하고 있나 궁금해서 자료를 살펴보았다.

## Windows Installer 동작 방식

Windows Installer 는 윈도우용 프로그램을 설치/패치 해주는 시스템이다. 이 시스템의 동작방식에 대해서 Heath Stewart 가 잘 정리해 두어 자세히 익히지 않아도 대강 어떻게 돌아가는지 파악할 수 있었다. 직접적으로 관련된 블로그는 다음과 같다.

- [Windows Installer Cache](http://blogs.msdn.com/b/heaths/archive/2005/11/29/498018.aspx)
- [The Patch Cache and Freeing Space](http://blogs.msdn.com/b/heaths/archive/2007/01/17/the-patch-cache-and-freeing-space.aspx)
- [Why Windows Installer May Require so much Disk Space](http://blogs.msdn.com/b/heaths/archive/2008/07/24/why-windows-installer-may-require-so-much-disk-space.aspx)

위 블로그와 몇몇 자료를 살펴보고 대략적으로 파악한 Windows Installer 동작 방식은 아래와 같다.

- Windows Installer 로 설치 프로그램 (msi) 와 패치 프로그램 (msp) 을 만들 수 있다.
- 설치, 패치 둘 다 기본적인 역할에 더해 복구(Repair), 제거(Uninstall) 기능을 제공한다.
  특히 패치 제거 기능은 Windows Installer 3.0 부터 지원하기 시작했다.
- 설치, 패치 모두 복구나 구성 변경이 필요하면 설치 디스크를 요구할 수 있다.
- 하지만 이 과정 중에 사용자에게 설치 디스크를 요구하는 것은 좋은 경험을 제공하는 것이
  아니므로 가능한 피하는 것이 좋다라는 것이 Windows Installer 팀의 입장.
  때문에 이 과정에 필요할 만한 파일을 하드에 남겨두는 것을 전략적으로 선택.
- 설치 과정에서 선택적으로 설치 원본 파일을 하드에 남겨둘 수 있다.
  이는 구성 변경 때나 패치가 적용될 때 원본 디스크를 요구가 필요 없는 장점이 있다.
- 패치 데이터는 경우에 따라서 delta encoding 을 사용한다.
  따라서 패치를 수행할 때 원본 파일이 하드에 없는 경우 원본 디스크를 요구할 수도 있다.
- 패치의 경우 제거를 하려면 패치 전 원본 파일이 필요하다.
  원본 파일이 백업되어 있다면 그것을 사용하고 아니라면 사용자에게 설치 디스크를 요구해야 한다.
- 패치의 경우 복구를 하려면 패치 파일이 필요하다.
  하지만 패치의 경우 설치 디스크가 없으니 패치 파일 자체를 백업해 둬야 한다.

정리하면 패치를 설치하면 해당 패치의 복구/제거를 위해 패치 과정에 관련된
모든 파일의 패치 전/후 상태를 백업해야 한다는 의미가 된다.
백업은 어떤 형태로 진행되냐하면

- 패치 전 파일은 Installer/$PatchCache$ 에 백업
  (패치를 복구하거나 제거할 때 패치 전 파일이 필요한 경우 백업된 곳에서 원본 파일을 가져다 사용한다.
   하지만 원본 파일이 백업 되어 있지 않다면 설치 디스크를 요구할 수 있다.
   따라서 반드시 필요한 백업은 아님)
- 패치 후 파일은 Installer 아래 msp 파일을 그대로 백업
  (만약 설치된 프로그램을 복구 하는 경우 이미 패치되었다면 패치가 반영된 파일로 복구를 해야 한다.
   그런 경우 패치에 관련된 msp 파일이 없다면 복구를 할 수가 없다.
   따라서 msp 를 삭제하면 정상적으로 복구를 할 수 없다. 반드시 필요.)

이런 이유로 $PatchCache$ 는 삭제가 가능하고 Installer 아래의 파일은 불가능하다.

## 설치된 프로그램별 용량

누가 누가 얼마나 차지하는지 간단한 프로그램을 작성해 살펴보았다.
([WinstView](http://pastebin.com/QwKFdSd1))

이 프로그램은 단순히 Installer 폴더에 있는 파일/폴더가 어떤 프로그램과 연결되어 있는지 확인해주는 역할을 한다.
연결을 위해 아래의 레지스트리를 탐색한다.

- HKLM\\SOFTWARE\\Classes\\Installer\\Products
- HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Installer

이제 실행한 결과를 살펴보면 먼저 Installer 에 있는 msi, msp 파일들이 어떤 프로그램인지 알 수 있다.
상위 6개를 보면 오피스, Visual Studio 의 패치 파일인 것을 알 수 있다.

[![](http://1.bp.blogspot.com/-De4ADoCByQY/UJPI8TaPvFI/AAAAAAAAAH8/-o_mgckFfpo/s1600/WinstView_Report_3.png)](http://1.bp.blogspot.com/-De4ADoCByQY/UJPI8TaPvFI/AAAAAAAAAH8/-o_mgckFfpo/s1600/WinstView_Report_3.png)

실행한 결과 두 번째를 보면 Installer/$PatchCache$ 폴더의 하위에 있는 여러 폴더가
어떤 프로그램을 위한 폴더인지 알 수 있다.
상위 6개를 보면 역시 오피스, Visual Studio 를 위한 폴더임을 알 수 있다.

[![](http://1.bp.blogspot.com/-LfJEBpcp_UY/UJPI83yTraI/AAAAAAAAAIE/GE54Xj5kIC4/s1600/WinstView_Report_4.png)](http://1.bp.blogspot.com/-LfJEBpcp_UY/UJPI83yTraI/AAAAAAAAAIE/GE54Xj5kIC4/s1600/WinstView_Report_4.png)

특히 $PatchCache$ 는 원래 프로그램의 최대 2배까지 커질 수 있어 용량이 어마어마하다.
(2배인 이유는 RTM 파일, 서비스팩이 적용된 파일을 보관할 수 있기 때문이다)

## Windows Installer 의 PatchCache 삭제 및 기능 끄기

$PatchCache$ 폴더는 삭제할 수 있다. 속시원하게 $PatchCache$ 폴더를 지워보자.
> rd /s /q %WINDIR%\\Installer\\$PatchCache$

그리고 Installer 가 이 폴더에 새로 데이터를 넣지 않도록 레지스트리 설정도 하자. ([MaxPatchCacheSize](http://msdn.microsoft.com/en-us/library/windows/desktop/aa369798(v=vs.85).aspx) 를 0 으로 설정하는 것으로 가능)
> reg add HKLM\\Software\\Policies\\Microsoft\\Windows\\Installer /v MaxPatchCacheSize /t REG\_DWORD /d 0 /f

이제 아래 그림처럼 Installer 폴더가 9.8GB 에서 5.2GB 줄어 4.6GB 가 된 것을 볼 수 있다.

[![](http://3.bp.blogspot.com/-zGKJdo3MjYw/UJPGz88zTBI/AAAAAAAAAHk/hP68-hLNYmY/s1600/S_Space_2.png)](http://3.bp.blogspot.com/-zGKJdo3MjYw/UJPGz88zTBI/AAAAAAAAAHk/hP68-hLNYmY/s1600/S_Space_2.png)

하지만 아쉽게도 Installer 폴더 아래에 있는 파일은 지울 수 없다.
Windows Update 등에서 원격으로 받아올 수 있는건 필요할 때 마다 받아오거나
직접 사용자가 제공할 수 있는 방법이 있으면 좋겠지만 아직 그런 기능은 없는 것으로 보인다.

## WinSxS 폴더

이제 winsxs 폴더가 7.3GB 로 1등이다. 의심스러운 용량이다.
DLL Hell 을 해결하기 위한 시스템인 Windows Side by Side 가 사용하는 폴더다.
(간략한 설명은 [The Secret Of Windows 7 WinSxS Folder](http://www.winvistaclub.com/f16.html) 에서 볼 수 있다)
간단히 말해 같은 DLL 의 여러 버전을 winsxs 아래에 보관하고 있다가 프로그램이 원하는 버전의 DLL 을 제공하는 역할을 한다.
만약 A.DLL 파일의 버전이 10개 존재한다면 10개 다 저장해 놓고 있을 수 있다.

게다가 winsxs 에 있는 파일 중 일부는 다른 경로의 파일과 하드 링크로 연결되어 있다.
(예를 들면 ntdll.dll 은 system32 에 있는 파일과 winsxs 에 있는 파일이 연결되어 있다.)
따라서 실제 winsxs 폴더에만 있는 파일의 순수 용량은 적다.
그래서 간단한 프로그램으로 winsxs 에 있는 파일이 어떤 파일과 연결되어 있는지 살펴보았다.
([ScanWinSxS](http://pastebin.com/iwskvePE))

결과를 보면 7.3GB 중 실제 하드링크가 연결되어 있는 파일은 4.5GB (60%) 이고
그렇지 않은 파일은 2.8GB (40%) 였다.
하드링크된 파일의 70% 인 3.3GB 의 파일은 Windows/System32 와 Windows/SysWOW64 에 연결되어 있었다.
따라서 WinSxS 폴더는 하드링크에 의해서 실제보다 부풀려 측정되는 것이라고 볼 수 있다.

여기서 하드링크가 연결되어 있지 않은 2.8GB 중에서 용량 순으로 파일 순위를 보면 다음과 같다.
(Size 는 해당 파일의 버전별 크기 총합. Count 는 버전 개수.)

[![](http://3.bp.blogspot.com/-QJkbpUtPk4I/UJS7Lb62Z2I/AAAAAAAAAI8/mFPUIhyd6zc/s1600/WinsxsTop.png)](http://3.bp.blogspot.com/-QJkbpUtPk4I/UJS7Lb62Z2I/AAAAAAAAAI8/mFPUIhyd6zc/s1600/WinsxsTop.png)

인터넷 익스플로러, 윈도우 시스템, .NET 컴포넌트, MFC 파일등이 업데이트 될 때마다
WinSxS 에 등록해 파일이 8~12 개씩 쌓여 용량을 많이 차지하고 있는 것을 볼 수 있다.
(저 리스트에 있는 파일 용량만 합쳐도 686MB 이다) 실제로 저 파일들이 모두 사용되고
있는지 의심스럽지만 winsxs 폴더는 삭제하면 안되기 때문에 그냥 내버려 뒀다.

## 정리

Windows Installer 의 동작 방식의 의도는 이해가 간다.
지난 20년간 HDD 용량은 꾸준히 늘어 왔고 이에 맞춰 용량 대비 가격은 급격히 떨어졌다.
하드 용량이 많이 남으니까 설치/패치의 안정성과 유저편의성을 하드 용량과 맞바꾼 것은
괜찮은 선택이라고 할 수 있다.
다만 최근에 등장한 SSD 는 이 관계를 틀어놨고 이제는 이 전략이 수정되어야 할 필요가 생겼다.
네트워크 시대에 맞춰 주요 파일을 Windows Update 서버에 넣고 필요할 때 받아가게
하는 장치가 있으면 좋지 않을까? 게다가 설치된 패치를 복구 하거나 제거하는 일의 빈도가 낮다면
(옵션으로) 백업으로 저장하지 말고 원본 디스크를 요청해도 되지 않을까?
(요즘 설치 디스크는 DVD 로 보관하지 않고 네트워크 폴더의 이미지 파일로 보관하니까)
