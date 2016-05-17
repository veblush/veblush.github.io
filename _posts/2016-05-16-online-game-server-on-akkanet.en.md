---
layout: post
title: "Online game server on Akka.NET"
date: 2016-05-16
categories: akkanet
lang: en
---

I made a speech about "Online game server on Akka.NET" at [NDC](https://ndc.nexon.com) 2016.
Following are slides and Q&As in the session.

## Slides

- [Slideshare](http://www.slideshare.net/veblush/online-game-server-on-akkanet-ndc2016)
- [PPT]({% asset_path NDC2016_OnlineGameServer_With_AkkaNet_English.pptx %})

## Q&A

#### Basic

###### # Should I concern about multi-thread synchronization and thread-blocking on Akka.NET?

Basically, No.
Actor model which akka provides is the another way to write concurrent code
without complex issues such as multi-threading and thread-blocking.

###### # Is message passing only method for accessing the state of actor? Any latency or IO overhead related with?

Yes. Message passing only and it adds more latency and IO overhead but it's well-optimized and good to go.

###### # What does happen to child actors when their parent actor stops? Is it could be SPOF?

Child actors will stop when their parent actor stops.
SPOF could be handled with high level tools such as akka.cluster not with actor itself.

###### # Any performance problem when there are lots of messages in one actor mailbox.

One actor processes one message at a time. So that actor will be busy in processing all messages
and take more time to response requests. But it doesn't affect other actors because they are isolated from each others. 

###### # How can I synchronize data when one actor is shared from several nodes in a cluster. Any lock is required?

Actor is only accessable via ActorRef so nodes cannot access data of actor just can send a message to it.
When several messages received from nodes, the actor will process a message at a time so no lock is required to synchronize requests.

###### # Is there a way to broadcast a message to many actors on Akka.NET?

Yes. There are two ways for that. First one is using wildcard included 
[ActorSelection](http://getakka.net/docs/Working%20with%20actors#identifying-actors-via-actor-selection) and 
second one is using 
[Broadcast Router](http://getakka.net/docs/working-with-actors/Routers#broadcast).

#### Programming Pattern

###### # Deadlock may occur when two actors send a message to each other and await. How can we handle it?

Yes it can cause deadlock. Because of this problem, send and await pattern is [not recommended](http://bartoszsypytkowski.com/dont-ask-tell-2/).
But if you want, there are three workarounds.

- Like a lock-use scenario, you can set await hierarchies for actors.
  For more info about lock hierarchy, read [Use Lock Hierarchies to Avoid Deadlock](http://www.drdobbs.com/parallel/use-lock-hierarchies-to-avoid-deadlock/204801163).

- ReentrantAttribute in Akka.Interfaced allows an actor to handle other messages while waiting await response.
  This can makes you avoid deadlock but you need to take care of reentrancy in await state.
  
###### # MMORPG can be implemented with the actor model? There could be many interactions between actors in MMORPG and it seems hard to build it.

If actors depend on each others' state and need lots of synchronized interactions, it will be hard to build a system with actors. 
Therefore we need a system to make this easy. In case of TicTacToe, there is a GameActor for handling this problem.
This GameActor receives all game commands from users in a game and processes it easily. (It's like a single-threaded programming.)
If a MMORPG whose world is separate into several isolated zones, you can use same approch for each zones.
But for a MMORPG whose world is not separate such as a seemless world, it will be a challenging work.

###### # Transaction for multiple actors? For examples, trade between two users requires transaction to implement it.

If we can sqeeze multiple entities into one actor like zone actor, it will be solve easily.
But an user inventory doesn't seem to work like this. In this case, regular distributed transation will be an answer.
[Two-Phase commit protocol](https://en.wikipedia.org/wiki/Two-phase_commit_protocol) is a common solution and
you can check 
[How do I do transactions across a distributed system?](http://www.slideshare.net/petabridge/distributed-transactions-in-akkanet).

###### # Any race condition for TrackableData Set?

No. TrackableData is not for concurrent data modification.
It just tracks the changes of data and propages changes to other systems such as DB and client.
There is no race condition because an actor owns trackabledata instances and processes a message at a time.

#### Integration

###### # Languages other than C# can interoperate with Akka.NET?

Yes. Any languages supporting .NET such as C#, F# and VB.NET can interoperate with Akka.NET.
However, it's not easy now for the environment beyond .NET.

###### # It it easy or hard to write test code on Akka.NET?

Fundamentally it is harder than writing test code consisting of calling synchronized methods
because the environment with multiple actors sending messages to each others is not deterministic.
But Akka.NET provides handy tools helping for writing unit tests.
Check out [How to Unit Test Akka.NET Actors with Akka.TestKit](https://petabridge.com/blog/how-to-unit-test-akkadotnet-actors-akka-testkit/).

###### # Can Akka.NET interop with Akka on JVM?

Unfortunately, No. Check this [Issue](https://github.com/akkadotnet/akka.net/issues/1629).

#### Performance

###### # It seems to have performance issues. Do you have stress tests?

Still I don't have any benchmark on whole system but I did tests on components and results looked good.
From the Akka.NET manual, 50 million msg/sec on a single machine and ~2.5 million actors per GB of heap.

###### # Latency could be problematic when hundreds of servers send messages on network?
 
When an actor send a message to other actor in same machine,
it doens't use network just put a message in a recipient's mailbox.
So you need to put actors interacting with each others alot in same machine to avoid network stress.

#### Etc

###### # You said that MonsterSweeperz uses C# IOCP but there is no IOCP API on .NET how did you do?

Yes, there is no IOCP API on .NET and I didn't make a lib for that.
MonsterSweeperz uses .NET socket which is implemented on IOCP so I said like that.

###### # Any problem with full GC latency? If not, could you tell me the maximum size of heap?

MonsterSweeperz has not suffered any GC problems because basic memory optimization already has been done
and quick responsiveness was not a requirement of system. The maximum size of heap was about 1-2 GB.
