---
layout: post
title: "Online game server works on Akka.NET for the last 2 months"
date: 2016-07-15
categories: akkanet
lang: en
---

I've been working on works related to [Online game server on Akka.NET](http://veblush.github.io/posts/online-game-server-on-akkanet/)
which I made a speech about at NDC 2016. Most of work is for polishing and paying down the technical debt.
This article explains what has been done and what will be (maybe) done later.

### Works done

#### Expressive Interface

[Akka.Interfaced](https://github.com/SaladLab/Akka.Interfaced) uses C# `interface` to define a contract
for communicating with an actor. It's natural for C# programmer and makes easy to send and receive messages with actors.
However `interface` is used and programmers seem to expect that major interface features are possible to use,
generic and inheritance are supported to satisfy this.

###### Generic

Generic interface and method are supported and following interface can be defined.

```csharp
// generic interface
interface IGreeter<T> : IInterfacedActor {
    Task<T> Greet<U>(U name); // generic method
    Task<int> GetCount();
}
```

Actor can implement the previous interface like:

```csharp
class class GreetingActor : InterfacedActor, IGreeter<string> {
    Task<string> Greet(string name) { ... }
    Task<string> Greet<U>(U name) { ... }
}
```

Supporting generic interface was quite simple because generic parameters are determined at the time of creating an actor.
But for generic method, it was not because new generic handler should be instantiated
whenever new message containing different parameters arrives.

Related issue: [Generic interface #30](https://github.com/SaladLab/Akka.Interfaced/issues/30)

###### Inheritance

`Interface` inheritance can be used like following. Work to support it was simple.
 
```csharp
public interface IGreeter : IInterfacedActor {
    Task<string> Greet(string name);
}

public interface IGreeterEx : IGreeter {
    Task<string> GreetEx(string name);
}
```

Related issue: [Support interface inheritance #27](https://github.com/SaladLab/Akka.Interfaced/issues/27)

#### Polishing API

At the previous Proof-Of-Concept stage, all works were for implementing and verifying the idea, not for polishing.
Because polishing itself costs many hours than expected and doesn't always end up with good result.
But this time is good for this polishing.

###### Remove CRTP (Curiously Recurring Template Pattern)

Base class, `InterfacedActor` needs a dedicate place to store a message dispatch table for each class.
CRTP is convenient to handle this because generic class always allocate new static storage when being instantiated.

```csharp
public class GreeterActor : InterfacedActor<GreeterActor>, IGreeter {
    ...
}
```

But this pattern causes programmer make a silly mistake like providing a wrong generic parameter.
For previous case, wrong base class such as `InterfacedActor<GuestActor>` cannot prevent compiler to build it
but will throw runtime exception. It's not good for safe programming environment so it's improved like following.
 
```csharp
public class GreeterActor : InterfacedActor, IGreeter {
    ...
}
```

Related issue: [Change InterfacedActor&lt;T&gt; to InterfacedActor #20](https://github.com/SaladLab/Akka.Interfaced/issues/20)

###### Unhandled exception policy

Previous version of `InterfacedActor` always returns an exception back to a requester
an unhandler exception is thrown while processing requests.
This decision was made because Requester-Responder is similar with Caller-Callee.
But Akka.NET doesn't work like this and it becomes a problem.
Akka.NET actor always propagates unhandled exceptions to a supervisor (usually parent) not to a requester. ([Fault Tolerance](http://getakka.net/docs/Fault%20tolerance))
If the interfaced actor works different from Akka.NET standard way, it could be a source of confusion.
Because of this, `InterfacedActor` is updated to follow the standard way but the other option is provided.
If you want to propagate an unhandled exception to requester like before, `ResponsiveException` can be used.
Following `Greet` method will propagate only `ArgumentException` to requester and others to supervisor.

```csharp
class GreeterActor : InterfacedActor, IGreeter {
    [ResponsiveException(typeof(ArgumentException))]
    Task<string> IGreeter.Greet(string name) {
        ...
    }
}
```

Related issue: [Exception policy for handling request, notification and message. #21](https://github.com/SaladLab/Akka.Interfaced/issues/21)

###### Add extensions to observer and message handler like request handler

`InterfacedActor` can handle 3 different types of message.

- Request: Request messages which are defined at `IInterfacedActor`.
- Notification: Event notification messages which are defined at `IInterfacedObserver`.
- Message: Message which have a handler annotated by `[MessageHandler]`.

Among these kinds of message, only Request handler could make use of filter and the extended handler.
But programmers expect that these kinds of message are equally supported so same features are added to notification and message handler.

`LogFilter` can be used for message handler now.

```csharp
class TestActor : InterfacedActor {
    [MessageHandler, Log]
    private void OnMessage(string message) {
        ...
    }
}
```

Notification handler for observer can be implemented with an extended handler.

```csharp
class TestActor : InterfacedActor, IExtendedInterface<ISubjectObserver>
    [ExtendedHandler]
    void Event(string eventName) {
        ...
    }
}
```

Related issue: [Let observer handler work with ExtendedHandler and Filter like Interfaced handler. #16](https://github.com/SaladLab/Akka.Interfaced/issues/16)

###### Terse SlimClient API

SlimClient does not depend on Akka.NET to make actors accessible from clients outside of Akka.NET.
Because `ActorRef` for SlimClient is implemented quite differently, interpretation is required to
send and receive `InterfacedActorRef` and `InterfacedObserver` across the boundary between SlimClient and Akka.NET.
 
For example, following code shows IUserLogin.Login which gets an observer created at SlimClient and
returns User actorRef created at Akka.NET to SlimClient.
Previous version of library forced you to use ID and translate it manually to pass and construct UserRef.
It is not a transparent API and makes bloated code.

```csharp
interface IUserLogin : IInterfacedActor {
    Task<int> Login(int observerId);
}

var userId = await userLogin.Login(...);
var user = new UserRef(new SlimActor(userId), SlimRequestWaiter(_comm, this)));
```

It's improved like following. `InterfacedActorRef` and `InterfacedObserver` can be used directly like Akka.NET.

```csharp
interface IUserLogin : IInterfacedActor {
    Task<IUser> Login(IUserObserver observer);
}

var user = await userLogin.Login(...);
```

Related issue: [Concise way for retrieving InterfacedActorRef on slim-client. #23](https://github.com/SaladLab/Akka.Interfaced/issues/23)

#### Extend SlimClient channel

Single TCP channel has been extended.

##### UDP Support

UDP channel is introduced in addition to TCP. Rationale for adding UDP channnel is:

- HandOver: There is an issue on TCP for handling handover on mobile environment.
  To make it happen, reliable data transfer layer should be implemented on top of TCP.
  Instead of hard work on TCP, how about using reliable UDP?
  It's better for fast hand-over because it doesn't establish the connection.

- Various QOS:
  TCP allows only reliable and ordered transmission but UDP allows many options
  such as reliable-unoredered and unreliable. For sending player movement notification message,
  unreliable-sequenced is enough and more performant than TCP.

[Lidgren Network Library](https://github.com/lidgren/lidgren-network-gen3) is chosen to be used
even it is not designed for server environment because writing robust communication library 
takes lots of effort. Just [forked](https://github.com/SaladLab/LidgrenUdpNet) it and updated it to meet my own requirements.
Following works are done.

- Support .NET 3.5 for nuget package: [LidgrenUdpNet](https://www.nuget.org/packages/LidgrenUdpNet/)
- Support UnityPackage: [LidgrenUdpNet for Unity3D](https://github.com/SaladLab/LidgrenUdpNet/releases)
- Add fast message handler.
- Connection is defined not by EndPoint but by ConnectionID to allow hand-over between WiFi and 3G.

And also Lidgren Network Library provides a P2P network feature which is a good tool for network game.

##### Remote channel binding

Remote channel binding allow clients to connect another servers owning specfic actors directly.
Previous one allowed clients to access remote actor only via a channel establised at first connection. 
(Forwarding Channel in the following figure)
This method is quite simple to use but it causes unncessary traffic for forwarding channel.

```
   * Forwarding Channel                          * Direct Channel
   Client -> Channel1 -> UserActor               Client -> Channel1 -> UserActor        
                |                                   | 
             ~~~|~~~~                               |      ~~~~~~~~
                |                                   |
                +---- -> GameActor                  +----> Channel2 -> GameActor
```

To deal with this problem, client can establish a channel on remote server to access remote actors.
(Direct Channel in the previous figure)
 
Following code shows how server open a remote channel to allow client to access GameActor directly.
It opens a remote channel and returns connection information to a client.

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

After client receives connection information from server, it establishes new connection to reach GameActor
and commuicate with it as a regular actor.

```csharp
var gamePlayer = User.JoinGame(gameId, ...);
if (gamePlayer.IsChannelConnected() == false)
    await gamePlayer.ConnectChannelAsync();
gamePlayer.CallSomething();
```

##### Bind multiple interfaces to a bound actor

Bound actor to channel could be accessed via one bound interface. (Not means that actor can implement only one interface.)
It changed to bind multiple interfaces to an actor and the following use case can be implemented with this feature.

For example, `UserActor` has two kinds of permission to access. Normal access and administrative access.
Normal access is only permitted before client is confirmed to have an administrative priviledge.
At first, write `UserActor` implementing `IUser` and `IUserForAdmin` as separate methods by permission and
bind only `IUser` to bound user actor.

```csharp
class UserActor : IInterfacedActor, IUser, IUserForAdmin {
    Task IUser.NormalMethod() { }
    Task IUserForAdmin.PowerMethod() { }
}
```

After verifying client is an administrator, tell channel to allow a client to access `IUserForAdmin` methods
by binding `IUserForAdmin` to bound actor. After binding, client can access methods of `IUserForAdmin`.

```csharp
Task Authorize(...) {
    await _channel.BindType(Self, new TaggedType[] { typeof(IUserForAdmin) });
}
```

#### Example works

Writing examples has been an important part through the whole development process.
In developing libraries, it could be the first way to make sure it works well and
show how easy programmer can write features that libraries want to help with.
And it let me know what is missing and what is bad quickly. 
Also it is really helpful to let newcomer understand how the library works and learn best practices.
Because of this several advantages, I have been updating examples even it costs tons of efforts.

##### Keep reference applications up-to-date

There are three reference applications: [Chatty](https://github.com/SaladLab/Chatty),
[TicTacToe](https://github.com/SaladLab/TicTacToe), [Snake](https://github.com/SaladLab/Snake).
These have been updated by the changes of library. (More hours were spent than expected)

These three diffrent applications share common parts and help for extracting common reusable parts.
In this period, [Aim.ClusterNode](https://github.com/SaladLab/Aim.ClusterNode) are written for covering
common cluster node behaviours.

Also all servers in application can run as a service now.

##### Project scaffolding

New tool, [Akka.ProjectScaffolding](https://github.com/SaladLab/Akka.ProjectScaffolding) is introduced
to help for initiating new project with akka.net and unity.
For building online game, at least 3 projects should be created and many libraries have to be installed and configurated,
which are boring and time-consuming. At first, Visual Studio [Project Template](https://msdn.microsoft.com/en-us/library/ms185301.aspx) 
was being considered but it is not easy to support other IDEs such as Visual Sutio Code and to maintain template project without burden
so standalone scaffolding tool was chosen.

Run a program from [Release](https://github.com/SaladLab/Akka.ProjectScaffolding/releases) and
it will create new project configured to work on right now. Following command generates new project using cluster.

```
akka-unity-cluster NewProjectName
```

#### Writing test and documentation

Some tests and documentationwere skipped because of a rapid development. Missing parts have been written.
For tests, writing test itself is a little bit easy, whereas building testing environment is sometimes really hard.
And writing documentation is always difficult. :)

New tests

- [Akka.Interfaced CodeGenerator](https://github.com/SaladLab/Akka.Interfaced/tree/master/core/CodeGenerator.Tests) :
  Make simple test code for verifying result code not by comparing generated code source but by analyzing generated semantic trees.
- [Akka.Interfaced.SlimSocket](https://github.com/SaladLab/Akka.Interfaced.SlimSocket/tree/master/core/Akka.Interfaced.SlimSocket.Tests) :
  It was impossible to write test code because SlimClient and Akka.Interfaced were mutual exclusive but it became possible to write after removing SlimClient project.

New documentation

- [Akka.Interfaced Manual](https://github.com/SaladLab/Akka.Interfaced/blob/master/docs/Manual.md)

### Futher work

These are short summary that want to be implemented. But when and how are not determined.

#### Encrypting UDP communication

Add encryption to UDP communication. UDP channel identifies each connection by connection ID (not endpoint)
so someone can insert a malicious packet into other's connection if he can guess connection ID and sequence number.
To prevent this, encryption have to be adopted.
For the same reason, [QUIC](https://en.wikipedia.org/wiki/QUIC) specifies that TLS/SSL is mandatory for keeping connection safe.

#### Wire instead of Protobuf.NET

SlimSocket uses [protobuf-net](https://github.com/mgravell/protobuf-net) for a message serializer. 
Because of limits of protobuf, it is practically impossible to use inheritance and generic for serializing a message.
Also protobuf-net always make a empty container variable null, which surprises a programmer. (maybe me alone?)
To alleviate this problem, alternative serializer can be used such as [wire](https://github.com/akkadotnet/Wire).

#### Distributed ActorTable 

Current implementation [DistributedActorTable](https://github.com/SaladLab/Akka.Cluster.Utility/blob/master/docs/DistributedActorTable.md)
at [Akka.Cluster.Utility](https://github.com/SaladLab/Akka.Cluster.Utility) provides a distribued actor table across cluster nodes.
But table should be placed at one node, which make this SPOF/B.
To make fault tolerant distributed system, this table should be improved.

#### .NET Core Support

Let's support .NET Core which is the future of .NET. It provides a lot of benefits such as
hosting services on Linux or Windows nano server. But we need to wait for all dependent libraries to
support .NET core first.

### Closing

All these works were estimated for my 1 month work but turned out 2 months. :cry:
But I finished all planned works and I'm happy about it.
