---
layout: post
title: "Akka.NET 으로 만드는 온라인 게임 서버의 최근 2개월간 작업"
date: 2016-07-15
categories: akkanet
lang: ko
---



NDC 2016 에서 발표한 [Akka.NET 으로 만드는 온라인 게임 서버](http://veblush.github.io/ko/posts/online-game-server-on-akkanet/) 에
관한 작업을 지난 2개월간 진행했다. 주로 과거 작업에서 거칠게 처리된 부분을 다듬고 기술 부채를 갚는데 초점을 맞췄다.
이 글을 통해 수행한 작업을 설명하고 앞으로 진행 할 만한 남은 작업을 정리한다.

### 한 일

#### 표현력 있는 Interface

[Akka.Interfaced](https://github.com/SaladLab/Akka.Interfaced) 는 C# `interface` 를 사용해 액터의 메시지를 기술한다.
이는 C# 프로그래머에게는 자연스러운 개념이며 이를 통해 매끄럽게 액터와 메시지를 주고 받을 수 있다.
하지만 `interface` 를 사용하기 때문에 프로그래머는 일반적인 `interface` 의 기능이 모두 사용 가능하리라 기대한다.
떄문에 이를 만족시키기 위해 제네릭과 상속을 추가로 구현하였다.

###### 제네릭

제네릭 인터페이스와 메소드를 지원하며 다음과 같은 형태의 인터페이스를 사용할 수 있다.

```csharp
// generic interface
interface IGreeter<T> : IInterfacedActor {
    Task<T> Greet<U>(U name); // generic method
    Task<int> GetCount();
}
```

이렇게 정의된 제네릭 인터페이스와 메소드는 다음과 같이 클래스에서 구현할 수 있다.

```csharp
class class GreetingActor : InterfacedActor, IGreeter<string> {
    Task<string> Greet(string name) { ... }
    Task<string> Greet<U>(U name) { ... }
}
```

제네릭 인터페이스를 지원하는 작업은 상대적으로 간단했다. 왜냐하면 액터가 생성되는 시점에 generic 파라미터가 모두 결정되어 있기 때문이다.
하지만 제네릭 메소드는 그렇지 않은데 메소드 실체가 제네릭 파라미터가 바뀔 때마다 새롭게 구축되어야 하기 때문이다.

관련 이슈: [Generic interface #30](https://github.com/SaladLab/Akka.Interfaced/issues/30)

###### 상속

`Interface` 상속은 다음과 같이 사용할 수 있다. 구현도 간단히 가능했다. 
 
```csharp
public interface IGreeter : IInterfacedActor {
    Task<string> Greet(string name);
}

public interface IGreeterEx : IGreeter {
    Task<string> GreetEx(string name);
}
```

관련 이슈: [Support interface inheritance #27](https://github.com/SaladLab/Akka.Interfaced/issues/27)

#### API 다듬기

Proof-Of-Concept 단계에서는 생각한 것이 제대로 잘 구현되는지 보기위해 API 를 다듬는 과정을 거의 하지 않았다.
매끄러운 API 를 만드는 과정은 생각보다 시간이 많이 소요되며 경우에 따라서는 더 사용하기 좋은 API 가
나오지 못하는 경우도 있기 때문이다. 이런 이유로 첫 작업때 진행하지 못한 다듬기 작업을 이번에 진행했다.

###### CRTP (Curiously Recurring Template Pattern) 제거

`InterfacedActor` 는 매시지 디스패쳐 테이블을 클래스 타입별로 따로따로 구축해 저장해 두는데 저장할 장소가
마땅치 않아 이를 CRTP 를 사용해 해결했었다. 제네릭 클래스는 해당 클래스가 구체화 될 때마다 static member 공간이
할당되는데 이를 테이블을 저장 하는 용도로 사용했다.

```csharp
public class GreeterActor : InterfacedActor<GreeterActor>, IGreeter {
    ...
}
```

이런 패턴에서 보통 하는 실수는 `InterfacedActor` 의 파라미터를 엉뚱하게 넣는 것인데 
위의 경우 `InterfacedActor<GuestActor>` 와 같이 잘못 넣으면 넣으면 컴파일은 잘 되나 실행 중에 예외가 발생한다.
이런 이슈는 안전한 작업 환경에 방해가 되기 때문에 아래와 같이 문제의 여지를 제거하는 방향으로 개선했다.

```csharp
public class GreeterActor : InterfacedActor, IGreeter {
    ...
}
```

관련 이슈: [Change InterfacedActor&lt;T&gt; to InterfacedActor #20](https://github.com/SaladLab/Akka.Interfaced/issues/20)

###### 처리되지 않은 예외 정책

기존 `InterfacedActor` 는 요청 처리 중 처리되지 않은 예외가 발생하면 이를 잡아다가 요청한 곳으로 돌려 보냈다.
이것은 Requester-Responder 가 Caller-Callee 관계와 1:1 대응 된다라는 관점에서 결정된 것이었다.
문제는 Akka.NET 은 처리되지 않은 예외가 발생했을 때 [Fault Tolerance](http://getakka.net/docs/Fault%20tolerance) 의 일환으로
부모 액터에게 처리를 위임한다는데 있다.
InterfacedActor 가 예외를 처리할 때 Akka.NET 의 표준 방식과 다르게 동작하는 것은 프로그래머에게 불필요한 혼란을 만들기 좋다.
떄문에 처리되지 않은 예외가 발생했을 때 기본적으로는 Akka.NET 방식을 따르도록 변경했다.
다만 기존과 같이 요청자에게 예외를 넘기기 위해서는 다음과 같이 `ResponsiveException` 을 사용하면 된다.
이 경우에는 `ArgumentException` 는 요청자에게 예외를 넘기고 그 외의 다른 예외는 Akka.NET 방식을 따르게 된다.

```csharp
class GreeterActor : InterfacedActor, IGreeter {
    [ResponsiveException(typeof(ArgumentException))]
    Task<string> IGreeter.Greet(string name) {
        ...
    }
}
```

관련 이슈: [Exception policy for handling request, notification and message. #21](https://github.com/SaladLab/Akka.Interfaced/issues/21)

###### Observer, Message Handler 도 Request Handler 의 확장 기능 담기

`InterfacedActor` 는 총 3가지 타입의 메시지를 처리할 수 있다.

- Request: `IInterfacedActor` 로 정의된 인터페이스를 통한 요청 메시지
- Notification: `IInterfacedObserver` 로 정의된 옵저거의 이벤트 통지 메시지
- Message: `[MessageHandler]` 에 의해 핸들러가 정의된 메시지


이 메시지 타입중 Request 는 기존에 필터와 확장 핸들러 기능을 사용할 수 있었다.
프로그래머는 Notification 과 Message 의 핸들러도 Request 와 같이 해당 기능을 가질 것이라 기대할 것이므로 동일하게 기능을 추가해 주었다.

따라서 일반 메시지 핸들러에도 다음과 같이 `LogFilter` 를 사용할 수 있다.

```csharp
class TestActor : InterfacedActor {
    [MessageHandler, Log]
    private void OnMessage(string message) {
        ...
    }
}
```

옵저버 이벤트 통지 메시지 처리도 확장 인터페이스를 사용할 수 있게 되었다.

```csharp
class TestActor : InterfacedActor, IExtendedInterface<ISubjectObserver>
    [ExtendedHandler]
    void Event(string eventName) {
        ...
    }
}
```

관련 이슈: [Let observer handler work with ExtendedHandler and Filter like Interfaced handler. #16](https://github.com/SaladLab/Akka.Interfaced/issues/16)

###### 매끄러운 SlimClient API

SlimClient 은 Akka.NET 없이 `InterfacedActorRef` 에 접근할 수 있도록 만들어주는 라이브러리다. 
Akka.NET 을 사용하지 않기 때문에 구현은 상당히 다르게 되어 있는데 이 때문에
`InterfacedActorRef` 나 `InterfacedObserver` 를 SlimClient 경계로 주고 받을 때 번역이 필요했었다.
 
예를 들면 다음은 UserLogin 액터의 Login 메소드인데 이 메소드는 SlimClient 에서 생성된
Observer 를 받고 Akka.NET 에서 생성된 User 액터의 Ref 를 다시 클라이언트에게 넘겨준다.
기존에는 다음과 같이 인터페이스 정의 때부터 정수형 ID 를 사용해야 했고 ID 를 받고 나면 직접 UserRef 를 구축했어야 했다.
이는 투명항 API 사용 경험을 방해하며 꽤 번잡한 코드를 작성해야만 했다.

```csharp
interface IUserLogin : IInterfacedActor {
    Task<int> Login(int observerId);
}

var userId = await userLogin.Login(...);
var user = new UserRef(new SlimActor(userId), SlimRequestWaiter(_comm, this)));
```

이를 다음과 같이 정리했다. Akka.NET 환경에서와 마찬가지로 SlimClient 에서도
`InterfacedActorRef` 와 `InterfacedObserver` 를 그대로 사용할 수 있다.

```csharp
interface IUserLogin : IInterfacedActor {
    Task<IUser> Login(IUserObserver observer);
}

var user = await userLogin.Login(...);
```

관련 이슈: [Concise way for retrieving InterfacedActorRef on slim-client. #23](https://github.com/SaladLab/Akka.Interfaced/issues/23)

#### SlimClient 채널 확장

기존의 단순한 TCP 단일 채널을 확장했다.

##### UDP 지원

기존 TCP 에 더해 UDP 채널을 추가했다. UDP 채널을 지원하게 된 이유는 다음과 같다.

- HandOver: 모바일 환경에서 HandOver 를 TCP 로 구현하는데 추가 작업이 있다.
  제대로 된 HandOver 를 구현하기 위해서는 TCP 위에다가 다시 전송 레이어를 올려야 하는데
  이게 배보다 배꼽이 커지는 구현이다.
  그러느니 Reliable UDP 을 가져다 쓰면 되지 않을까?
  거기에 더해 TCP 는 HandOver 가 느리게 수행되는데 UDP 는 애초에 비접속 프로토콜이라 빠르게 수행될 수 있다.  
 
- 다양한 QoS 지원:
  TCP 는 Reliable & Ordered 만 지원하는데 반해 UDP 를 가지고는 Reliable & Unordered 혹은
  Unreliable 등을 추가로 지원할 수 있다.
  플레이어 움직임 패킷은 unreliable-sequenced 만으로도 충분하며 TCP 에 비해 더 좋은 성능을 보인다.
  
쓸만한 Reliable UDP 를 찾다가 [Lidgren Network Library](https://github.com/lidgren/lidgren-network-gen3) 를 사용하기로 했다.
서버에서 쓰기엔 성능이 살짝 아쉽지만 일단 사용에는 문제가 없고 특히 견고한 통신 라이브러리는 금방 만들 수 없으므로
가져다가 아쉬운 부분은 고쳐 쓰기로 했다. 라이브러리를 [포크](https://github.com/SaladLab/LidgrenUdpNet)해 다음과 같은
기능을 추가했다.

- nuget package 에 .NET 3.5 지원: [LidgrenUdpNet](https://www.nuget.org/packages/LidgrenUdpNet/)
- 유니티 패키징 지원: [LidgrenUdpNet for Unity3D](https://github.com/SaladLab/LidgrenUdpNet/releases)
- 빠른 메시지 핸들링을 위한 기능 추가
- HandOver 를 위해 접속 EndPoint 가 아닌 Connection ID 로 커넥션 구분

Lidgren Network Library 를 가져다 쓰게되어서 가지게 된 또 하나의 장점은 서버 없이 (혹은 서버도 함께)
P2P 네트워크를 구축할 수 있다는 점이다. 당장 서버 프레임웍에서는 중요하지 않지만 여러모도 쓸모가 있는 기능이다.

##### 원격 채널 바인딩

접속한 클라이언트를 다른 서버의 Actor 에 연결해주는데 사용한다.
예전에는 클라이언트가 다른 서버의 Actor 를 접근할 때 처음에 접속한 채널을 통해 접근했었다. (아래 그림 Forwarding Channel)
이 방법은 구성이 간결하고 클라이언트 작업이 단순한데 반해 원격 Actor 와의 트래픽이 많은 경우
불필요한 포워딩 비용을 발생시킨다.

```
   * Forwarding Channel                          * Direct Channel
   Client -> Channel1 -> UserActor               Client -> Channel1 -> UserActor        
                |                                   | 
             ~~~|~~~~                               |      ~~~~~~~~
                |                                   |
                +---- -> GameActor                  +----> Channel2 -> GameActor
```

이를 해결하기 위해 클라이언트가 원격에 있는 Actor 가 있는 서버와 직접 채널을 만들어 통신하도록 할 수 있는
방법을 추가했다. (위 그림 Direct Channel)

예를 들어 원격에 있는 GameActor 에 클라이언트가 직접 통신하도록 채널을 열기위한 코드는 다음과 같다.
원격 Gateway 를 통해 채널과 액터를 연결하고 연결된 정보를 클라이언트에게 반환한다.

```csharp
async Task<IGamePlayer> IUser.JoinGame(long id) {
    var game = GetGame(id);
    await game.Join(_id, ...);
    var boundTarget = await _channel.BindActorOrOpenChannel(
        game.CastToIActorRef(), new[] { new TaggedType(typeof(IGamePlayer), _id) },
        ActorBindingFlags.OpenThenNotification | ActorBindingFlags.CloseThenNotification,
        "GameGateway", _id);
    return boundTarget.Cast<GamePlayerRef>();
}
```

클라이언트는 다음 코드와 같이 원격 Actor 의 `InterfacedActorRef` 를 받고 나서 해당 Actor 를 접근하기 위해
추가 채널 구성이 필요한지 확인 한 뒤에 필요하면 채널을 연결한 뒤에 일반적인 Actor 처럼 사용할 수 있다.

```csharp
var gamePlayer = User.JoinGame(gameId, ...);
if (gamePlayer.IsChannelConnected() == false)
    await gamePlayer.ConnectChannelAsync();
gamePlayer.CallSomething();
```

##### 채널에 바인딩 된 Actor 에 여러 Interface 허용

예전에는 채널에 바인딩 된 Actor 에 대해 한 가지 종류의 인터페이스만 허용이 되었다. (액터가 구현할 수 있는 인터페이스가 한 개라는 의미가 아님)
이를 복수개의 인터페이스를 동시에 바인딩 할 수 있도록 변경했다. 이를 통해 다음과 같은 케이스를 구현할 수 있다.

예를 들어 `UserActor` 에 두 가지 권한 접근이 있다고 하자.
일반 접근과, 관리자 접근이 있는데 관리자 인증이 되기 전까지는 일반 접근만을 허용하고 인증이 된 이후에는 두 접근이 모두 가능하도록 해보자.
우선 `UserActor` 에는 `IUser` 와 `IUserForAdmin` 의 권한으로 분리된 인터페이스를 만들고 첫 접근 때는 `IUser` 만 채널에 바인딩한다.

```csharp
class UserActor : IInterfacedActor, IUser, IUserForAdmin {
    Task IUser.NormalMethod() { }
    Task IUserForAdmin.PowerMethod() { }
}
```

관리자임이 확인이 되면 다음고 같이 채널의 `BindType` 을 사용해 `IUserForAdmin` 타입을 바인드 한다.
이 이후 부터는 클라이언트가 `IUserForAdmin `의 메소드를 호출할 수 있게 된다.

```csharp
Task Authorize(...) {
    await _channel.BindType(Self, new TaggedType[] { typeof(IUserForAdmin) });
}
```

#### 예제 작업

예제를 만드는 과정은 전체 개발 과정에서 중요한 과정이었다. 개발 과정에서 예제는
작성한 라이브러리가 잘 동작하는지 확인할 수 있는 첫번째 구체화된 어플리케이션이고
어떤 기능을 구현할 때 얼마나 간결하게 표현할 수 있는지 혹은 어떤 기능이 부족하거나 없는지를
즉시적으로 보여주기 때문이다. 또한 예제는 중요한 튜토리얼이 되며 개발자가 원하는
best practice 를 효과적으로 보여주는 장치가 된다. 따라서 손이 많이 감에도 작업을 계속 신경쓰면서 진행했다.

##### 레퍼런스 어플리케이션 업데이트

예전에 만들어 둔 3개의 레퍼런스 앱이 [Chatty](https://github.com/SaladLab/Chatty),
[TicTacToe](https://github.com/SaladLab/TicTacToe), [Snake](https://github.com/SaladLab/Snake)
가 있는데 이를 모두 라이브러리 변경에 맞춰 업데이트했다. (마이그래이션에 생각보다 시간이 많이 들었다.)

3개는 서로 기능이 겹치는 부분도 있고 아닌 부분도 있는데 3개가 있다보니 공통된 부분을 쉽게 찾을 수 있다.
이번 작업때는 클러스터 노드 관련 부분을 추려 [Aim.ClusterNode](https://github.com/SaladLab/Aim.ClusterNode) 를 만들었다.
또한 모든 예제에 테스트 프로젝트를 추가하고 서버를 서비스 형태로 사용할 수 있도록 변경했다.

##### Project Scaffolding

이번에 새롭게 [Akka.ProjectScaffolding](https://github.com/SaladLab/Akka.ProjectScaffolding) 을 추가했다. 
새 게임을 만들기 위해 프로젝트 환경을 구축할 하기 위해서는 여러개의 프로젝트를 만들고 라이브러리를 설치하고
종속 관계를 만드는 과정 등을 진행해야 하는데 생각보다 절차가 많고 지루한 과정이라 만들게 되었다.
처음에는 Visual Studio [Project Template](https://msdn.microsoft.com/en-us/library/ms185301.aspx) 
형태로 할까 하다가 Visual Studio Code 등 타 개발 환경에 대응하기 어렵고 템플릿 프로젝트를 계속 유지 보수하기 어려워 독립된 프로젝트로 구성했다.

[배포 페이지](https://github.com/SaladLab/Akka.ProjectScaffolding/releases)에서 프로그램을
받아 다음과 같이 실행하면 기본 프로젝트를 구성해준다.
다음와 같이 클러스터 구성이된 새 프로젝트를 만들 수 있다.

```
akka-unity-cluster NewProjectName
```

#### 테스트, 문서 작성

빠른 개발로 빠진 테스트를 구현하고 문서를 작성했다. 테스트의 경우에는 테스트 하나를 만드는 것 보다는
테스트가 가능하게 만드는 틀을 만드는 과정이 보통 어려웠다. 그리고 문서 작성은 언제나 어렵다. :)

추가된 테스트

- [Akka.Interfaced CodeGenerator](https://github.com/SaladLab/Akka.Interfaced/tree/master/core/CodeGenerator.Tests) :
  생성된 코드를 텍스트로 비교하지 않고 생성된 코드를 파싱하고 난 결과를 검사하는 식으로 테스트 assert 코드를 짧게 유지.
- [Akka.Interfaced.SlimSocket](https://github.com/SaladLab/Akka.Interfaced.SlimSocket/tree/master/core/Akka.Interfaced.SlimSocket.Tests) :
  기존에는 SlimClient 프로젝트와 Akka 가 상호 충돌하는 구조라 테스트 프로젝트 구성이 아예 불가능했는데 SlimClient 프로젝트를 제거하면서 가능하게 되어 테스트 구성.

작성된 문서

- [Akka.Interfaced Manual](https://github.com/SaladLab/Akka.Interfaced/blob/master/docs/Manual.md)

### 남은 일

했으면 좋겠다 싶은 일들을 정리했다. 다만 언제 어떻게 진행할지는 아직 미정이다.
머리속에서 컨텍스트가 날아가기 전에 정리하는 의미.

#### UDP 통신 보안.

UDP 에 암호화된 통신 보안 기능을 추가한다. UDP 의 경우 EndPoint 가 아닌 Connection ID 를 통해
독립된 접속을 구성하는데 이 말은 누구라도 Connection ID 만 맞춰서 데이터를 끼워넣을 수 있다는 의미다.
따라서 이를 방지하기 위해 암호화된 통신 기능을 추가해야 한다.
비슷한 이유로 [QUIC](https://en.wikipedia.org/wiki/QUIC) 은 TLS/SSL 을 끌 수 없도록 되어 있다.

#### Protobuf.NET 대신 Wire

SlimSocket 은 메시지 시리얼라이져로 [protobuf-net](https://github.com/mgravell/protobuf-net) 을 사용한다.
떄문에 메시지에 상속과 제네릭을 사용할 수 없다.
또한 빈 컨테이너를 null 로 만드는 특성으로 종종 프로그래머를 골탕먹이는 문제도 있다.
이를 해결하기 위해 [wire](https://github.com/akkadotnet/Wire) 혹은 다른 것을 사용해보자. 

#### Distributed ActorTable 

현재 [Akka.Cluster.Utility](https://github.com/SaladLab/Akka.Cluster.Utility) 에 있는 
[DistributedActorTable](https://github.com/SaladLab/Akka.Cluster.Utility/blob/master/docs/DistributedActorTable.md) 는
분산 액터 테이블을 제공한다. 다만 테이블 자체는 분산되지 못해 SPOF/B 가 된다.
때문에 이를 완전히 분산된 테이블로 개선하는 작업이 필요하다.

#### .NET Core 지원
 
.NET Core 를 지원하자. 이를 통해 가벼운 배포가 가능하고 리눅스에서도 서버를 돌릴 수 있다.
다만 이것은 종속 라이브러가 모두 .NET Core 를 지원하는 시점에서 시작 할 수 있다.

### 정리

한 1개월이면 충분하지 않을까 했던 작업이 2개월이나 걸려 완료되었다.
생각보다 오래 걸린 것은 아쉽지만 잘 마무리되어 다행이다 :)

