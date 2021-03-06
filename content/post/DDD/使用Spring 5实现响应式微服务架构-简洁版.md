---
title: "使用Spring 5实现响应式微服务架构-简洁版"
date: 2019-07-11T09:30:59+08:00
draft: false
categories:
- DDD
tags:
- DDD
keywords:
- DDD
---

随着以 Dubbo、Spring Cloud 等框架为代表的分布式服务调用和治理工具的大行其道，以及以 Docker、Kubernetes 等容器技术的日渐成熟，微服务架构（Microservices Architecture）毫无疑问是近年来最热门的一种服务化架构模式。所谓微服务，就是一些具有足够小的粒度、能够相互协作且自治的服务体系。正因为每个微服务都比较简单，仅关注于完成一个业务功能，所以具备技术、业务和组织上的优势 <sup>[1]</sup>。
<!--more-->

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://www.toutiao.com/i6712191658521264647/?w2atif=1&channel=__all__

另一方面，随着 Spring 5 的正式发布，我们引来了响应式编程（Reactive Programming）的全新发展时期。Spring 5 中内嵌了响应式 Web 框架、响应式数据访问、响应式消息通信等多种响应式组件，从而极大地简化了响应式应用程序的开发过程和难度。

本章作为全书的开篇，将对微服务架构和响应式系统（Reactive System）的核心概念做简要介绍，同时给出两者之间的整合点，即如何构建响应式微服务架构。在本章最后，我们也会给出全书的组织架构以总领全书。

## **响应式系统核心概念**

在本节中，我们将带领大家进入响应式系统的世界。为了让大家更好地理解响应式编程和响应式系统的核心概念，我们将先从传统编程方法出发逐步引出响应式编程方法。同时，我们还将通过响应式宣言（Reactive Manifesto）了解响应式系统的基本特性和设计理念。

### **从传统编程方法到响应式编程方法**

在电商系统中，订单查询是一个典型的业务场景。用户可以通过多种维度获取自己已下订单的列表信息和各个订单的明细信息。我们就通过订单查询这一特定场景来分析传统编程方法和响应式编程方法之间的区别。

#### 1．订单查询场景的传统方法

在典型的三层架构中，图 1-1 展示了基于传统实现方法的订单查询场景时序图。一般用户会使用前端组件所提供的操作入口进行订单查询，然后该操作入口会调用后台系统的服务层，服务层再调用数据访问层，进而访问数据库，数据从数据库中获取之后逐层返回，最后显示在包括前端服务或用户操作界面在内的前端组件上。

![](http://p3.pstatp.com/large/pgc-image/RVrxtxKClD7CuY)

图 1-1 订单查询场景的传统实现方法时序图

显然，在图 1-1 所展示的整个过程中，前端组件通过主动拉取的方式从数据库中获取数据。如果用户不触发前端操作，那么就无法获取数据库中的数据状态。也就是说，前端组件对数据库中的任何数据变更一无所知。

#### 2．订单查询场景的响应式方法

主动拉取数据的方式在某些场景下可以运作得很好，但如果我们希望数据库中的数据一有变化就通知到前端组件，这种方式就不是很合理。这种场景下，我们希望前端组件通过注册机制获取数据变更的事件，图 1-2 展示了这一过程。

在图 1-2 中，我们并不是直接访问数据库来获取数据，而是订阅了 OrderChangedEvent 事件。当订单数据发生任何变化时，系统就会生成这一事件，然后通过一定的方式传播出来。而订阅了该事件的服务就会捕获该事件，从而通过前端组件响应该事件。事件处理的基本步骤涉及对某个特定事件进行订阅，然后等待事件的发生。如果不需要再对该事件做出响应，我们就可以取消对事件的订阅。

![](http://p1.pstatp.com/large/pgc-image/RVrxtxhFbpMaI8)

图 1-2 订单查询场景的响应式实现方法时序图

图 1-2 体现的是响应式系统中一种变化传递（Propagation Of Change）思想，即当数据变化之后，会像多米诺骨牌一样，导致直接和间接引用它的其他数据均发生相应变化。一般而言，生产者只负责生成并发出事件，然后消费者来监听并负责定义如何处理事件的变化传递方式。

显然，这些事件连起来会形成一串数据流（Data Stream），如果我们能够及时对数据流的每一个事件做出响应，就会有效提高系统的响应能力。基于数据流是响应式系统的另一个核心特点。

我们再次回到图 1-1，如果从底层数据库驱动，经过数据访问层到服务层，最后到前端组件的这个服务访问链路全部都采用响应式的编程方式，从而搭建一条能够传递变化的管道，这样一旦数据库中的数据有更新，系统的前端组件上就能相应地发生变化。而且，当这种变化发生时，我们不需要通过各种传统调用方式来传递这种变化，而是由搭建好的数据流自动进行传递。

#### 3．传统方法与响应式方法的对比

图 1-1 展示的传统方法和图 1-2 展示的响应式方法具有明显的差异性，我们分别从处理过程、线程管理和伸缩性角度做简要对比。

**（1）处理过程**

传统开发方式下，我们拉取（Pull）数据的变化，这意味着整个过程是一种间歇性、互不相关的处理过程。前端组件不关心数据库中的数据是否有变化。

在响应式开发方式下，一旦对事件进行注册，处理过程只有在数据变化时才会被触发，类似一种推（Push）的工作方式。

**（2）线程管理**

在传统开发方式下，线程的生命周期比较长。在线程存活的状态下，该线程所使用的资源都会被锁住。当服务器在同时处理多个线程时，就会存在资源的竞争问题。

在响应式开发方式下，生成事件和消费事件的线程的存活时间都很短，所以资源之间存在较少的竞争关系。

**（3）伸缩性**

传统开发方式下，系统伸缩性涉及数据库和应用服务器的伸缩，一般我们需要专门采用一些服务器架构和资源来应对伸缩性需求。

在响应式开发方式下，因为线程的生命周期很短，同样的基础设施可以处理更多的用户请求。同时，响应式开发方式同样支持传统开发方式下的各种伸缩性实现机制，并提供了更多的分布式实现选择。图 1-3 展示了事件处理与系统伸缩性之间的关系。

![](http://p3.pstatp.com/large/pgc-image/RVrxtxy2cCtNaO)

图 1-3 事件处理与系统伸缩性示意图

在图 1-3 中，显然 Web 应用程序和事件处理程序可以分别进行伸缩，这为伸缩性实现机制提供更多的选型余地。

### **响应式宣言与响应式系统**

如同业界的其他宣言一样，响应式宣言是一组设计原则，符合这些原则的系统可以认为是响应式系统。同时，响应式宣言也是一种架构风格，是一种关于分布式环境下系统设计的思考方式，响应式系统也是具备这一架构风格的系统。

#### 1．响应式系统特性

响应式宣言给出了响应式系统所应该具备的特性，包括即时响应性（Responsive）、回弹性（Resilient）、弹性（Elastic）以及消息驱动（Message Driven）。具备这些特性的系统可以称为响应式系统。图 1-4 给出了响应式宣言的图形化描述。

![](http://p1.pstatp.com/large/pgc-image/RVrxtyI7wuWGBz)

图 1-4 响应式宣言（来自响应式宣言官网）

在图 1-4 中，响应式宣言认为，响应式系统的价值在于提供了即时响应性、可维护（Maintainable）和扩展性（E 意味着可以快速地检测到问题并且有效地对其进行处理。即时响应的系统专注于提供快速而一致的响应时间，确立可靠的反馈上限，以提供一致的服务质量。这种一致的行为转而将简化错误处理、建立最终用户的信任，并促使用户与系统做进一步互动。

**（2）回弹性**

回弹性指的是系统在出现失败时依然保持即时响应性。这不仅适用于高可用的、任务关键型系统——任何不具备回弹性的系统都将会在发生失败之后丢失即时响应性。回弹性是通过复制、遏制、隔离以及委托来实现的。失败的扩散被遏制在了每个组件内部，与其他组件相互隔离，从而确保系统某部分的失败不会危及整个系统，并能独立恢复。每个组件的恢复都被委托给了另一个内部或外部组件。此外，在必要时可以通过复制来保证高可用性。因此，组件的客户端不再承担组件失败的处理。

**（3）弹性**

弹性指的是系统在不断变化的工作负载之下依然保持即时响应性。响应式系统可以对输入的速率变化做出反应，比如，通过增加或者减少被分配用于服务这些输入的资源。这意味着设计上并没有竞争点和中央瓶颈，系统得以进行组件的分片或者复制，并在它们之间分布输入。通过提供相关的实时性能指标，响应式系统能支持预测式以及响应式的伸缩算法。这些系统可以在常规的硬件以及软件平台上实现高效的弹性。

**（4）消息驱动**

消息驱动指的是响应式系统依赖异步的消息传递，从而确保松耦合、隔离、位置透明的组件之间有着明确边界。这一边界还提供了将失败作为消息委托出去的手段。使用显式的消息传递，可以通过在系统中塑造并监视消息流队列，并在必要时应用背压，从而实现负载管理、弹性以及流量控制。使用位置透明的消息传递作为通信的手段，使得跨集群或者在单个主机中使用相同的结构成分和语义来管理失败成为了可能。非阻塞的通信使得接收者可以只在活动时才消耗资源，从而减少系统开销。

#### 2．响应式的维度

响应式的概念还体现在不同维度上，包含响应事件、响应压力、响应错误和响应用户。

**（1）响应事件**

基于消息驱动机制，响应式系统可以对事件做出快速响应。

**（2）响应压力**

响应式系统可以在不同的系统压力下进行灵活响应。当压力较大时，使用更多的资源；而当压力变小时，则释放不需要的资源。

**（3）响应错误**

响应式系统可以优雅地处理错误，监控组件的可用性，并在必要时冗余组件。

**（4）响应用户**

响应式系统一方面能够积极响应用户请求，但当消费者没有订阅事件时，就不会浪费资源进行不必要的处理。

## **剖析微服务架构**

目前，微服务架构已经成为一种主流的软件开发方法论，它把一种特定的软件应用设计方法描述为能够独立部署的服务套件。本节将对微服务设计原理与架构做精简而全面的介绍。

### **分布式系统与微服务架构**

微服务架构首先表现为一种分布式系统（Distributed System），而分布式系统是传统单块系统（Monolith System）的一种演进。

#### 1．单块系统

在软件技术发展过程的很长一段时间内，软件系统都表现为一种单块系统。时至今日，很多单块系统仍然在一些行业和组织中得到开发和维护。所谓单块系统，简单讲就是把一个系统所涉及的各个组件都打包成一个一体化结构并进行部署和运行。在 Java EE 领域，这种一体化结构很多时候就体现为一个 WAR 包，而部署和运行的环境就是以 Tomcat 为代表的各种应用服务器。

单块系统有其存在和发展的固有优势。当团队规模并不是太大的时候，一个单块应用可以由一个开发者团队进行独立维护。该团队的成员能够对单块应用进行快速学习、理解和修改，因为其结构非常简单。同时，因为单块系统的表现形式就是一个独立的 WAR 包，想要对它进行集成、部署以及实现无状态集群相对也比较简单，通常只要采用负载均衡机制并运行该单块系统的多个实例，就能达到系统伸缩性要求。

但在另一方面，随着公司或者组织业务的不断扩张、业务结构的不断变化以及用户量的不断增加，单块系统的优势已无法适应互联网时代的快速发展，面临着越来越多的挑战，例如，如何处理业务复杂度、如何防止代码腐化、如何处理团队协作问题以及如何应对系统伸缩性问题 <sup>[1]</sup>。针对以上集中式单块系统所普遍存在的问题，基本的解决方案就要依赖于分布式系统的合理构建。

#### 2．分布式系统

所谓分布式系统，是指硬件或软件组件分布在不同的网络计算机上，彼此通过一定的通信机制进行交互和协调的系统。我们从这个定义中可以看出分布式系统包含两个区别于单块系统的本质性特征：一个是网络，分布式系统的所有组件都位于网络之中，对互联网应用而言，则位于更为复杂的互联网环境中；另一个是通信和协调，与单块系统不同，位于分布式系统中的各个组件只有通过约定、高效且可靠的通信机制进行相关协作，才能完成某项业务功能。这是我们在设计和实现分布式系统时首先需要考虑的两个方面。

分布式系统相较于集中式系统而言具备优势的同时，也存在一些我们不得不考虑的特性，包括但不限于网络传输的三态性、系统之间的异构性、数据一致性、服务的可用性等 <sup>[1]</sup>。以上问题是分布式系统的基本特性，我们无法避免，只能想办法进行利用和管理，这就给我们设计和实现分布式系统提出了挑战。微服务架构本质上也是一种分布式系统，但在遵循通用分布式特性的基础上，微服务架构还表现出一定的特殊性。接下来我们将围绕微服务架构的这些特殊性展开讨论。

#### 3．微服务架构

Martin Fowler 指出 <sup>[2]</sup>，微服务架构具有以下特点。

**（1）服务组件化**

组件（Component）是一种可独立替换和升级的软件单元。在日常开发过程中，我们可能会设计和使用很多组件，这些组件可能服务于系统内部，也可能存在于系统所运行的进程之外。而服务就是一种进程外组件，服务之间利用诸如 RPC（Remote Procedure Call，远程过程调用）的通信机制完成交互。服务组件化的主要目的是服务可以独立部署。如果你的应用程序由一个运行在独立进程中的很多组件组成，那么对任何一个组件的改变都将导致必须重新部署整个应用程序。但是如果你把应用程序拆分成很多服务，显然，通常情况下，你只需要重新部署那个改变的服务。在微服务架构中，每个服务运行在其独立的进程中，服务与服务之间采用轻量级通信机制互相沟通。

**（2）按业务能力组织服务**

当寻找把一个大的应用程序进行拆分的方法时，研发过程通常都会围绕产品团队、UED 团队、APP 前端团队和服务器端团队而展开，这些团队也就是通常所说的职能团队（Function Team）。当使用这种标准对团队进行划分时，任何一个需求变更，无论大小，都将导致跨团队协作，从而增加沟通和协作成本。而微服务架构下的划分方法有所不同，它倾向围绕业务功能的组织来分割服务。这些服务面向具体业务结构，而不是面向某项技术能力。因此，团队是跨职能的（Cross-Functional）的特征团队（Feature Team），包含用户体验、项目管理和技术研发等开发过程中要求的所有技能。每个服务都围绕着业务进行构建，并且能够被独立部署到生产 / 类生产环境。

**（3）去中心化**

服务集中治理的一种好处是在单一平台上进行标准化，但采用微服务的团队更喜欢不同的标准。把集中式系统中的组件拆分成不同的服务，我们在构建这些服务时就会有更多的选择。对具体的某一个服务而言，应该根据业务上下文选择合适的语言和工具进行构建。

另一方面，微服务架构也崇尚于对数据进行分散管理。当集中式的应用使用单一逻辑数据库进行数据持久化时，通常选择在应用的范围内使用一个数据库。然而，微服务让每个服务管理自己的数据库，无论是相同数据库的不同实例，还是不同的数据库系统。

**（4）基础设施自动化**

许多使用微服务架构产品或者系统的团队拥有丰富的持续集成（Continue Integration）和持续交付（Continuous Delivery）经验。团队使用微服务架构构建软件需要更广泛地依赖基础设施自动化技术。

在微服务中同样需要考虑服务容错性设计等分布式系统所需要考虑的问题，我们对以上特点进行总结和提炼，认为微服务具备业务独立、进程隔离、团队自主、技术无关轻量级通信和交付独立性等 “微” 特性。

### **服务拆分与集成**

本节在微服务架构基本概念的基础上，简要分析服务拆分的策略和手段，同时也给出对拆分之后的服务进行集成的各种实现方法和技术体系。

#### 1．服务拆分

在微服务架构中，我们认为服务是业务能力的代表，需要围绕业务进行组织。服务拆分的关键在于正确理解业务，识别单个服务内部的业务领域及其边界，并按边界进行拆分。所以微服务的拆分模式本质上是基于不同的业务进行拆分。业务体现在各种功能代码中，通过确定业务的边界，并使用领域与界限上下文（Boundary Context）、领域事件（Domain Event）等技术手段可以实现拆分。

数据对微服务架构而言同样可以认为是一种依赖关系，因为任务业务都需要使用某个数据容器作为持久化的机制或者数据处理的媒介，这里的数据容器不仅指关系型数据库，还泛指包括消息队列、搜索引擎索引以及各种 Nosql 在内的数据媒介。微服务架构中存在一种说法，即我们需要将微服务用到的所有资源全部嵌入到该服务中，从而确保微服务的独立性。而数据的拆分则体现在如何将集中式的中心化数据转变为各微服务各自拥有的独立数据，这部分工作同样十分具有挑战性。

关于业务和数据应该先拆分谁的问题，可以是先数据库后业务代码，也可以是先业务代码后数据库。然而在拆分中遇到的最大挑战可能会是数据层的拆分，因为在数据库中，可能会存在各种跨表连接查询、跨库连接查询以及不同业务模块的代码与数据耦合得非常紧密的场景，这会导致服务的拆分非常困难。因此，在拆分步骤上我们更多地推荐数据库先行。数据模型能否彻底分开，很大程度上决定了微服务的边界功能是否彻底划清。

服务拆分的方法根据系统自身的特点和运行状态，通常可分为绞杀者与修缮者两种模式。绞杀者模式（Strangler Pattern）<sup>[3]</sup> 指的是在现有系统外围将新功能用新的方式构建为新的服务的策略，通过将新功能做成微服务方式，而不是直接修改原有系统，逐步实现对老系统替换。采用这种策略，随着时间的推移，新的服务就会逐渐 “绞杀” 老的系统。对于那些规模很大又难以对现有架构进行修改的遗留系统，推荐采用绞杀者模式。而修缮者模式就如修房或修路一样，将老旧待修缮的部分进行隔离，用新的方式对其进行单独修复。修复的同时，需保证与其他部分仍能协同功能。从这种思路出发，修缮者模式更多地表现为一种重构技术，具体实现上可以参考 Martine Fowler 的 BranchByAbstraction 重构方法 <sup>[4]</sup>。

#### 2．服务集成

服务之间势必需要集成，而这种集成关系远比简单的 API 调用要复杂。对于微服务架构而言，我们的思路是尽量采用标准化的数据结构和通信机制并降低系统集成的耦合度。我们把微服务架构中服务之间的集成模式分为以下四大类 <sup>[1]</sup>，同时还会引入其他一些手段来达到服务与服务之间的有效集成。

**（1）接口集成**

接口集成是服务之间集成的最常见手段，通常基于业务逻辑的需要进行集成。RPC、REST、消息传递和服务总线都可以归为这种集成方式。

RPC 架构是服务之间进行集成的最基本方式。在 RPC 架构实现思路上，远程服务提供者以某种形式提供服务调用相关信息，远程代理对象通过动态代理拦截机制生成远程服务的本地代理，让远程调用在使用上如同本地调用一样。而网络通信应该与具体协议无关，通过序列化和反序列化方式对网络数据进行有效传输。

REST（Representational State Transfer，表述性状态转移）从技术上讲也可以认为是 RPC 架构的一种具体表现形式，因为 RPC 架构中最基本的网络通信、序列化 / 反序列化、传输协议和服务调用等组件都能在 REST 中有所体现。但 REST 代表的并不是一种技术，也不是一种标准和规范，而是一种设计风格。要理解 RESTful 架构，最好的方法就是去理解它的全称 Representational State Transfer 这个词组，直译过来就是 “表述性状态转移”，针对的是网络上的各种资源（Resource）。所以 REST 通俗地讲就是：资源在网络中以某种表现形式进行状态转移。

消息通信（Messaging）机制（或者称为消息传递机制）可以认为是一种系统集成组件，是在分布式系统中完成消息的发送和接收的基础软件，用于消除服务交互过程中的耦合度。关于耦合度的具体表现形式，我们在下一节中还会具体展开，消息通信机制实现系统解耦的做法是在服务与服务之间添加一个中间层，这样紧耦合的单阶段方法调用就转变成松耦合的两阶段过程，可以通过中间层进行消息的存储和处理，这个中间层就是以各种消息中间件为代表的消息通信系统（Messaging System）。

企业服务总线（Enterprise Service Bus，ESB）本质上也是一种系统集成组件，用于解决分布式环境下的异步协作问题，可以看作是对消息通信系统的扩展和延伸。ESB 提供了一批核心组件，包括路由器、转换器和端点。路由器（Router）在一个位置上维护消息目标地址并基于消息本身或上下文进行路由；转换器（Transformer）用于异构系统之间进行数据适配，数据结构、类型、表现形式、传输方式都是潜在的需要转换的对象；端点（Endpoint）封装了应用系统与服务总线系统的交互。

**（2）数据集成**

数据集成同样可以用于微服务之间的交互，常见的共享数据库（Shared Database）是一个选择，但也可以通过数据复制（Data Replication）的方式实现数据集成。

在微服务架构中，我们追求数据的独立性。但对于一些遗留系统而言，我们无法重新打造数据体系，数据复制就成为一种折中的集成方法。所谓数据复制，就是在不同的数据容器中保存同一份业务数据。这里的同一份业务数据的概念不在于数据内容的完全一致性，而在于这些数据背后的业务逻辑的一致性。

**（3）客户端集成**

由于微服务是一个能够独立运行的整体，有些微服务会包含一些 UI 界面，这也意味着微服务之间也可以通过 UI 界面进行集成。从某一个微服务的角度讲，调用它的服务就是该服务的客户端。关于客户端与微服务之间的集成可以分为三种方式，即直接集成、使用 FrontEnd 服务器和使用 API 网关。

直接集成方式比较简单，就是客户端通过微服务提供的访问入口直接对微服务进行集成。这种方式适合于微服务数量不是太多的场景。如果采用直接集成的方式，服务按照业务模块进行边界划分和命名是一项最佳实践。

FrontEnd 服务器有时候也可以认为是一种 Portal（门户）机制，即把客户端所需要的各种 CSS、Javascript 等公共资源统一放在 FrontEnd 服务器，然后每个微服务包含自身特有的 HTML 等客户端代码片段以及业务逻辑，通过集成 FrontEnd 服务器上的公共资源完成独立服务的运行。

当微服务数量较多且客户端集成场景比较复杂时，通常就需要单独抽取一层作为客户端访问的统一入口，这一层在微服务架构里称为 API 网关（Gateway）。API 网关的主要作用是对后端的各个微服务进行整合，从而为不同的客户端提供定制化的内容。

**（4）外部集成**

这里把外部集成单独剥离出来的原因在于现实中很多服务之间的集成需求来自于与外部服务的依赖和整合，而在集成方式上也可以综合采用接口集成、数据集成和客户端集成。

以上集成方式各有其应用场景和特点，现实中的很多系统包含的集成方式并不限于其中一种。关于服务拆分和服务集成的方法论与工程实践不是本书的重点，读者可参看笔者的《微服务设计原理与架构》<sup>[1]</sup> 一书做进一步了解。在本书中，我们重点介绍的接口集成，并试图通过响应式编程的方式实现基于 RESTful 风格以及消息通信的微服务集成需求。

### **微服务架构的核心组件**

微服务架构的实现首先需要提供一系列基础组件，包括事件驱动、集群与负载均衡、服务路由等分布式环境下的通用组件，也包括 API 网关和配置管理等微服务架构所特有的功能组件。同时，基于服务注册中心的服务发布和订阅机制是微服务体系下实现服务治理的基本手段。而关于如何保证服务的可靠性，我们也需要考虑服务容错、服务隔离、服务限流和服务降级等需求和实现方案。最后，我们也需要使用服务监控手段来管理服务质量和运行时状态。

#### 1．事件驱动

事件驱动架构（Event-Driven Architecture，EDA）定义了一个设计和实现应用系统的架构风格，在这个架构风格里事件可传输于松散耦合的组件和服务之间。事件处理架构的优势就在于当系统中需要添加另一个业务逻辑来完成整个流程时，只需要对处于该流程中的事件添加一个订阅者即可，不需要对原有系统做大量修改。考虑到在微服务架构中服务数量较多且不可避免地需要对服务进行重构，事件处理在系统扩展性上的优势就尤为明显。而在技术实现上，通过消息通信机制，我们不必花费太大代价就能实现事件驱动架构。响应式编程从一定程度上也是事件驱动架构的一种表现形式。

#### 2．负载均衡

集群（Cluster）指的是将几台服务器集中在一起实现同一业务。而负载均衡（Load Balance）就是将请求分摊到位于集群中的多个服务器上进行执行。负载均衡根据服务器地址列表所存放的位置可以分成两大类，一类是服务器端负载均衡，另一类是客户端负载均衡。另一方面，以各种负载均衡算法为基础的分发策略决定了负载均衡的效果。在集群化环境中，当客户端请求到达集群，如何确定由某一台服务器进行请求响应就是服务路由（Routing）问题。从这个角度讲，负载均衡也是一种路由方案，但是负载均衡的出发点是提供服务分发而不是解决路由问题，常见的静态、动态负载均衡算法也无法实现精细化的路由管理。服务路由的管理可以归为几个大类，包括直接路由、间接路由和路由规则 <sup>[1]</sup>。

#### 3．API 网关

API 网关本质上就是一种外观模式（FaçadePattren）的具体实现，它是一种服务器端应用程序并作为系统访问的唯一入口。API 网关封装了系统内部架构，为每个客户端提供一个定制的 API。同时，它可能还具有身份验证、监控、缓存、请求管理、静态响应处理等功能。在微服务架构中，API 网关的核心要点是所有的客户端和消费端都通过统一的网关接入微服务，在网关层处理通用的非业务功能。

#### 4．配置中心

在微服务架构中，一般都需要引入配置中心（Configuration Center）的相关工具。采用配置中心也就意味着采用集中式配置管理的设计思想。对于集中式配置中心而言，开发、测试和生产等不同的环境配置信息保存在统一存储媒介中，这是一个维度。而另一个维度就是分布式集群环境，需要确保集群中同一类服务的所有服务器保存同一份配置文件，并且能够同步更新。

#### 5．服务治理

在微服务架构中，服务治理（Service Governance）可以说是最关键的一个要素，因为各个微服务需要通过服务治理实现自动化的服务注册（Registration）和发现（Discovery）。服务治理的需求来自服务的数量。如果在服务数量并不是太多的场景下，服务消费者获取服务提供者地址的基本思路是通过配置中心，当服务的消费者需要调用某个服务时，基于配置中心中存储的目标服务的具体地址构建链路完成调用。但当服务数量较多时，为了实现微服务架构中的服务注册和发现，通常都需要构建一个独立的媒介来管理服务的实例，这个媒介一般被称为服务注册中心（Service Registration Center）。

另一方面，服务提供者和服务消费者都相当于服务注册中心的客户端应用程序。在系统运行时，服务提供者的注册中心客户端程序会向注册中心注册自身提供的服务，而服务消费者的注册中心客户端程序则从注册中心查询当前订阅的服务信息并周期性地刷新服务状态。同时，为了提高服务路由的效率和容错性，服务消费者可以配备缓存机制以加速服务路由。更重要的是，当服务注册中心不可用时，服务消费者可以利用本地缓存路由实现对现有服务的可靠调用。

#### 6．服务可靠

在微服务架构中，各个服务独立部署且服务与服务之间存在相互依赖关系。和单块系统相比，微服务架构中出现服务访问失败的原因和场景非常复杂，这就需要我们从服务可靠性的角度出发对服务自身以及服务与服务之间的交互过程进行设计。

针对服务失败，常见的应对策略包括超时（Timeout）和重试（Retry）机制。超时机制指的是调用服务的操作可以配置为执行超时，如果服务未能在这个时间内响应，将回复一个失败消息。同时，为了降低网络瞬态异常所造成的网络通信问题，可以使用重试机制。这两种方式都会产生同步等待，因此合理限制超时时间和重试次数是一般的做法。

当服务运行在一个集群中，出现通信链路故障、服务端超时以及业务异常等场景都会导致服务调用失败。容错（Fault Tolerance）机制的基本思想是冗余和重试，即当一个服务器出现问题时不妨试试其他服务器。集群的建立已经满足冗余的条件，而围绕如何进行重试就产生了 Failover、Failback 等几种常见的集群容错策略。

服务隔离（Isolation）包括一些常见的隔离思路以及特定的隔离实现技术框架。所谓隔离，本质上是对系统或资源进行分割，从而实现当系统发生故障时能限定传播范围和影响范围，即发生故障后只有出问题的服务不可用，保证其他服务仍然可用。常见的隔离措施包括线程隔离、进程隔离、集群隔离、机房隔离和读写隔离等 <sup>[5]</sup>。

关于服务可靠性，还有一个重要的概念称为服务熔断（Circuit Breaker）。服务熔断类似现实世界中的 “保险丝”，当某个异常条件被触发时，就直接熔断整个服务，并不是一直等到此服务超时。而服务降级就是当某个服务熔断之后，服务端准备一个本地的回退（Fallback）方法，该方法返回一个默认值。

#### 7．服务监控

我们知道在传统的单块系统中，所有的代码都在同一台服务器上，如果服务运行时出现错误和异常，我们只要关注一台服务器就可以快速定位和处理问题。但在微服务架构中，事情显然没有那么简单。微服务架构的本质也是一种分布式架构，微服务架构的特点决定了各个服务部署在分布式环境中。各个微服务独立部署和运行，彼此通过网络交互，而且都是无状态的服务，一个客户端请求可能需要经过很多个微服务的处理和传递才能完成业务逻辑。在这种场景下，我们首先面临的一个核心问题是如何管理服务之间的调用关系；另一方面，如何跟踪业务流的处理顺序和结果也是服务监控的核心问题。通常，我们需要借助于日志聚合和服务跟踪技术来解决这两个核心问题。

### **微服务架构技术体系**

本书的定位是讨论响应式微服务架构构建过程中的工程实践。无论是实现响应式微服务架构还是传统的微服务架构，都需要借助于某一种具体的技术体系。

为了实现微服务架构，首先需要选择一种主流的工具来构建单个微服务。当系统中存在多个微服务时，我们就应该提供服务治理、负载均衡、服务容错、API 网关、配置中心、事件驱动等实现方案以完成服务之间的交互和集成。同时，微服务架构的技术体系也包括如何对微服务进行测试，以及基于日志聚合和服务跟踪的服务监控管理。

#### 1．微服务核心组件的实现技术

微服务之间首先需要进行通信。对于服务通信，微服务架构明确要求服务之间通过跨进程的远程调用方式进行通信。关于远程调用，有三种风格的解决方案，即 RPC、REST 和自定义实现。而在服务与服务的交互方式上，也存在两个维度，即按照交互对象的数量分为一对一和一对多，以及按照请求响应的方式分为同步和异步。目前 RPC 框架可供选型的余地很大，如 AlibabaDubbo、Facebook Thrift 以及 Google gRPC 等都是非常主流的实现，而基于 REST 的实现框架则包括 Jersey、Spring MVC 以及本书中将要详细介绍的响应式 Spring WebFlux 等。

事件驱动架构实现工具的表现形式通常是各种消息中间件，如基于 JMS（Java Message Service，Java 消息服务）规范的 ActiveMQ、基 AMQP（Advanced Message Queuing Protocol，高级消息队列协议）规范的 RabbitMQ、在大数据流式计算领域中应用非常广泛的 Kafka，当然还有像 Alibaba 自研的 RocketMQ。在这些消息中间件中，ActiveMQ 一般不考虑，如果是相对比较轻量级的应用，则可以选择 RabbitMQ，而 Kafka 和 RocketMQ 则适合大型应用的场景。

负载均衡分为服务器端负载均衡和客户端负载均衡两大类实现方案。在服务器软件中，我们可以选择 Nginx、HA proxy、Apache、LVS 等工具。而类似 Netflix Ribbon 的工具则是一种单独可以使用的负载均衡机制。事实上，所有的分布式服务框架几乎都内置了负载均衡的实现，所以负载均衡本身并不需要做太多的选择。

API 网关是微服务架构的核心组件之一。Netflix OSS（Open Source Software）中有一个 Zuul 提供了一套过滤器机制，可以很好地支持签名校验、登录校验等前置过滤功能处理，同时它也维护了路由规则和服务实例，以便完成服务路由功能。其他可供参考的 API 网关还有开源的 Spring Cloud Gateway 和 Kong 等。

配置管理的作用是完成集中式的配置信息管理。目前比较主流的包括 Spring 旗下的 Spring Cloud Config、淘宝的 Diamond 和百度的 Disconf 等。在实现上，Spring Cloud Config 支持将配置信息存放在配置服务本地的内存中，也支持放在远程 Git 仓库中，这点与其他工具在设计上有较大不同。Diamond 和 Disconf 都是基于 Mysql 作为存储媒介，Diamond 采用拉模型，即每隔 15s 拉一次全量数据；而 Disconf 基于 Zookeeper 的推模型，实时推送。在配置数据模型上，Diamond 只支持 Key-Value 结构的数据，采用的是非配置文件模式；而 Disconf 支持传统的配置文件模式，也支持 Key-Value 结构数据。

关于服务注册和服务发现，比较常见的分布式一致性协议是 Paxos 协议 <sup>[6]</sup> 和 Raft 协议 <sup>[7]</sup>。相比 Paxos 协议，Raft 协议易于理解和实现，因此，最新的分布式一致性方案大都选择 Raft 协议。我们知道 Zookeeper 采用的是基于 Paxos 协议改进的 ZAB（Zookeeper Atomic Broadcast，Zookeeper 原子消息广播）协议，而 Raft 协议的实现工具主要是 Consul 和 Etcd。注册中心是任何一个微服务框架所必不可少的组件，很多框架都内建了对服务注册中心的支持。例如，Alibaba 的 Dubbo 框架支持包括 Zookeeper、Redis 等在内的多种注册中心实现，默认采用的是 Zookeeper；新浪的 Motan 支持 Zookeeper，也支持 Consul；Spring Cloud 也同时提供了 Spring Cloud Consul 和 Spring Cloud Zookeeper 两种实现方案；而 Netflix OSS 中使用的是 Eureka。

服务可靠性相关的功能主要包括服务容错、服务隔离、服务限流和服务降级，其中大多数机制都偏向于实现策略而不是实现工具。我们需要明确的是如何实现服务隔离和服务熔断机制的框架。服务熔断器可选的开源方案包括 NetflixHystrix 和 Resilience4j。

#### 2．Spring Cloud

在本书中，我们将采用 Spring Cloud 作为微服务架构的实现框架。组件完备性是我们选择该框架的主要原因。Spring Cloud 是 Spring 家族中新的一员，重点打造面向服务化的功能组件，在功能上服务注册中心、API 网关、服务熔断器、分布式配置中心和服务监控等组件都能在 Spring Cloud 中找到对应的实现。

另一个选择 Spring Cloud 的原因在于服务之间的交互方式。我们知道微服务架构中推崇基于 HTTP 协议的 RESTful 风格实现服务间通信，而诸如 Dubbo 等框架的服务调用基于长连接的 RPC 实现。采用 RPC 方式会导致服务提供方与调用方接口产生较强依赖，而且服务对技术敏感，无法做到完全通用。Spring Cloud 采用的就是 RESTful 风格，这方面更加符合微服务架构的设计理念。

Spring Cloud 还具备一个天生的优势，因为它是 Spring 家族中的一员，而 Spring 在开发领域的强大地位给 Spring Cloud 起到了很好的推动作用。同时，Spring Cloud 基于 Spring Boot，而 Spring Boot 目前已经在越来越多的公司得到应用和推广，用来简化 Spring 应用的框架搭建以及开发过程。Spring Cloud 也继承了 Spring Boot 简单配置、快速开发、轻松部署的特点，让原本复杂的开发工作变得相对容易上手。

在本书后续章节中，我们将看到如何使用 Spring Cloud 实现微服务架构中的各个核心组件。

## **构建响应式微服务架构**

使用微服务架构最关键的一个原则就是将系统划分成一个个相互隔离、无依赖的微服务，这些微服务通过定义良好的协议进行通信。本节将讨论构建响应式微服务架构的一些设计原则和理念，并探讨整合响应式编程和微服务架构的方法。

### **响应式微服务架构设计原则**

_Reactive Microservices Architecture_<sup>[8]</sup> 一书讲述了响应式微服务架构的核心概念以及实施过程中的一些最佳实践。本节将介绍这些核心概念和最佳实践，以便读者能够更好地理解响应式微服务架构。

#### 1．隔离一切事物

在微服务架构中，我们经常会提到雪崩效应（Avalanche Effect）这一概念。服务雪崩的产生是一种扩散效应。当系统中存在两个服务 A 和 B，如果 A 服务出现问题，而 B 服务会通过用户不断提交服务请求等手工重试或代码逻辑自动重试等手段进一步加大对 A 服务的访问流量。因为 B 服务使用同步调用，会产生大量的等待线程占用系统资源。一旦线程资源被耗尽，B 服务提供的服务本身也将处于不可用状态，整个过程的演变可参考图 1-5。而这一效果在整个服务访问链路上进行扩散，就形成了雪崩效应。

雪崩效应的预防需要依赖于架构设计中的一种称为舱壁隔离（Bulkhead Isolation）的架构模式。所谓舱壁隔离，顾名思义就是像舱壁一样对资源或失败单元进行隔离，如果一个船舱破了进水，只损失一个船舱，其他船舱可以不受影响。舱壁隔离模式在微服务架构中的应用就是各种服务隔离思想。

![](http://p1.pstatp.com/large/pgc-image/RVrxtybFbpPDCs)

图 1-5 雪崩效应示意图

隔离是微服务架构中最重要的特性，也是实现响应式宣言中所提倡的弹性、可伸缩系统的前提。所谓弹性，就是从失败中恢复的能力，依赖于这种舱壁和失败隔离的设计，并且需要打破同步通信机制。由此，微服务一般是在边界之间使用异步消息传输，从而使得正常的业务逻辑避免对捕获错误、错误处理的依赖。

#### 2．自主行动

上面所讲的隔离性是自主性的前提。只有当服务之间是完全隔离的，才可能实现完全的自主，包括独立的决策、独立的行动以及与其他服务协调合作来解决问题。

从实现上讲，服务自主性仅仅需要确保其对外公布协议的正确性即可。自主性不仅能够让我们更好地了解微服务系统以及各个服务的领域模型，也能够在面对冲突和失败状况时，确保快速定位到问题出在具体的哪一个微服务中。

#### 3．只做一件事，并且尽量做好

大家都知道面向对象设计中有一条单一职责原则（Single Responsibility Principle，SRP），而在微服务架构中一个很大的问题是如何正确地划分各个服务的大小。多大的粒度才能被称之为 “微” 服务，显然，这个 “微” 是和服务本身的职责有直接关系，我们希望一个服务只做一件事，而且在服务内部要把相关的功能做到尽量好。

每一个服务都应该只有一个存在的原因，业务和职责不应该糅杂在一起。如果满足这个要求，所有的服务组织在一起从整体上就能够便于扩展、具有弹性、易理解和维护。

#### 4．拥有自己的私有状态

在软件设计领域经常会提到状态（State）这个词，而服务之间的状态本质上体现的还是一种数据关系。如果一个数据需要在多个服务之间共享才能完成一项业务功能，那么这项业务功能就被称为有状态。基于这项业务功能所设计和实现的一系列服务之间就形成了一种状态性，这一系列服务就是有状态服务。

很多服务都会把自己的状态下沉到一个庞大的共享数据库中，这也是一些传统 Web 框架的做法。这种做法就会造成在扩展性、可用性以及数据集成上很难做好把控。而在本质上，一个使用共享数据库的微服务架构本质还是一个单体应用。一个服务既然具有单一职责，那么合理的方式就应该是该服务拥有自己的状态和持久化机制，建模成一个边界上下文。这里就需要充分应用领域驱动设计（Domain Driven Design，DDD）中的相关策略设计和技术设计方面的方法和工程实践。关于领域驱动设计以及背后的 Event Sourcing（事件溯源）和 CQRS（Command Query Responsibility Segreation，命令查询职责分离）等概念，读者可参考《实现领域驱动设计》<sup>[9]</sup>，这里不做具体展开。

#### 5．拥抱异步消息传递

从软件设计上讲存在三种不同层级的耦合度，即技术耦合、空间耦合和时间耦合。技术耦合度表现在服务提供者与服务消费者之间需要使用同一种技术实现方式。如图 1-6a 中服务提供者与服务消费者都使用 RMI（Remote Method Invocation）作为通信的基本技术，而 RMI 是 Java 领域特有的技术，也就意味着其他服务消费者想要使用该服务也只能采用 Java 作为它的基本开发语言；空间耦合度指的是服务提供者与服务消费者都需要使用统一的方法签名才能相互协作，图 1-6b 中的 getUserById(id) 方法名称和参数的定义就是这种耦合的具体体现；而时间耦合度则表现在服务提供者与服务消费者只有同时在线才能完成一个完整的服务调用过程，如果出现图 1-6c 中所示的服务提供者不可用的情况，显然，服务消费者调用该服务就会发生失败。

![](http://p1.pstatp.com/large/pgc-image/RVrxu9F2Vk3UGI)

图 1-6 耦合度的三种表现形式

微服务之间通信的最佳机制就是异步消息传递，消息传递能够从技术、空间和时间等多个维度上缓解甚至消除图 1-6 中的三种耦合度。我们在第 5 章中会进一步对该话题展开讨论。

同时，异步非阻塞执行是对资源的高效操作，能够最小化访问共享资源时的阻塞消耗，从而提升整体系统的性能。

#### 6．保持移动，但可寻址

异步消息传递带来了服务的位置透明性。所谓位置透明，指的是在多核或者多结点上的微服务在运行时无须改变结点，即可动态扩展的能力。这也决定了系统的弹性和移动性，要实现这些需要依赖云计算带来的一些特性和按需使用的模型。

另一方面，可寻址则是指服务的地址需要稳定，从而可以无限地引用此服务，无论服务目前是否可以被定位到。当服务在运行中、已停止、被挂起、升级中、已崩溃等情形下，地址都应该是可用的，任意客户端能够随时发送消息给一个地址。从这个角度讲，地址应该是虚拟的，可以代表一组实例提供的服务。使用虚拟地址能够让服务消费方无须关心服务目前是如何配置操作的，只要知道地址即可。

## **整合响应式编程与微服务架构**

构建一个分布式系统是复杂而困难的一项工作，微服务架构基于分布式，同时又需要考虑弹性、可伸缩性、隔离性等一系列问题。作为一个微服务架构，服务与服务之间、服务与外部系统之间的通信都是必需的。当我们对被依赖的服务和外部系统无法把控时，就会有很大的失败风险。因此，即使双方之间的通信协议定义得再好，也不能信赖外部服务或系统，需要做好各种措施以保证自身服务的安全。这里我们就可以充分整合响应式编程和微服务架构来实现这一目标。

响应式编程和微服务架构的一个整合点在于我们可以采用响应式编程中的背压（Backpressure）机制来实现数据流处理速度的一致性。在背压机制下，接收方根据自己的接受状况调节接受速率，通过反向的响应来控制发送方的发送速率，以防止一个系统中快速生成数据的部分压垮处理数据较慢的部分。目前，越来越多的工具和框架都在开始拥抱响应式流（Reactive Streams）规范，这些技术使用异步背压实时流来桥接系统，从而在总体上提高系统的可靠性、性能以及互操作性。关于背压和响应式流的具体概念和实现方法，将在下一章具体展开讨论。

在微服务架构的通信模式上，要尽量避免使用同步通信机制，否则就把自身服务的可用性放在了所依赖的第三方服务的控制范围中。上一节中对雪崩效应的产生原因分析已经非常明确地说明了这一点。避免级联失败需要服务足够解耦和隔离，使用异步通信机制是一个最佳的方案。当然，传统的 RESTful 风格的服务调用仍然适用于可控的服务调用上。本书也会分别介绍响应式编程环境下 RESTful 风格和异步通信风格的服务通信模式及实现方法。

另一方面，整个微服务架构需要的是一种全栈式的响应式环境，即响应式微服务开发方式的有效性取决于在整个请求链路中采用了全栈的响应式编程模型。如果某一个环节或步骤不是响应式的，就会出现同步阻塞，从而导致背压机制无法生效。常见的同步阻塞产生的环节除了服务与服务之间的同步通信，还有基于关系型数据库的数据访问，因为传统的关系型数据库都是采用非响应式的数据访问机制。本书也会详细介绍如何使用响应式的数据访问组件实现全栈的响应式编程模型。

本文节选自电子工业出版社《Spring 响应式微服务：Spring Boot 2+Spring 5+Spring Cloud 实战》第一章，由电子工业出版社博文视点授权。本书主要包含构建响应式微服务架构过程中所应具备的技术体系和工程实践。围绕响应式编程和微服务 架构的整合，讨论如何使用 Reactor 响应式编程框架、如何构建响应式 RESTful 服务、如何构建响应式数据访问组件、如何构建响应式消息通信组件、如何构建响应式微服务架构，以及如何测试响应式微服务 架构等核心主题，并基于这些核心主题给出具体的案例分析。

![](http://p1.pstatp.com/large/pgc-image/RVrxu9b3SggGdx)

基于篇幅的考虑，部分内容进行了简化，想了解本书全部详细内容，可以点击阅读原文直接购买。

**本次活动我们采取文章留言送书的活动。在本周末前，留言点赞数最高的前 5 名我们将免费赠送本书！图书由电子工业出版社博文视点提供。**

**参考阅读：**

*   终于有人把服务调用说清楚了

*   一文理解分布式服务架构下的混沌工程实践（含 PPT）

*   从工具到社区，美图秀秀大规模性能优化实践

技术原创及架构实践文章，欢迎通过公众号菜单「联系我们」进行投稿。转载请注明来自高可用架构「ArchNotes」微信公众号及包含以下二维码。

**高可用架构**

**改变互联网的构建方式**

长按二维码 关注「高可用架构」公众号