---
title: "微服务分布式事务Saga模式简介"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- DDD
tags:
- DDD
keywords:
- 电商网站
- DDD
---

该文是基于《微服务模式》作者Chris Richardson的QCONSF 2017会议上的PPT文章(这里)和其 Eventuate Tram Saga框架之上，对Saga模式进行的原理性解说，其中包含banq个人经验总结和见解，请从批判性视角看待。Chris Richardson的另外一本书籍《POJO in Action》曾经是帮助Spring成功挑战了EJB2。

在微服务环境下为什么不能使用ACID事务？因为每个微服务都拥有自己的私有数据库，比如订单服务有自己的订单数据库，而客户服务有自己的客户数据库，如果有一个业务操作需要跨订单和客户一起操作，那么一般使用JTA+XA方式跨订单数据库和客户数据库操作：
```
@ Transactional //事务元注解
public void crossAction(XX){
	//事务开始

	//这里ORDERS是属于订单服务的私有数据库
	SELECT ORDER_TOTAL FROM ORDERS WHERE CUSTOMER_ID = ?

    //这里CUSTOMERS是属于客户服务的私有数据库
	SELECT CREDIT_LIMIT FROM CUSTOMERS WHERE CUSTOMER_ID=?

	INERT INTO ORDERS .....

    //提交事务

}
```
以上JTA操作如果结合XA数据源配置，将会实现2PC两段事务提交。

通过这段事务操作主要目的是为了维持业务上的不变性约束，比如一个人下订单的总金额不能超过这个人的信用卡授信额度，也就是说：一个人购买的商品总金额只能小于或等于他的信用卡授信额度。

但是，2PC两段提交并不是微服务分布式架构的选择，因为存在单点风险，因为锁也会降低吞吐量。分布式事务如果不结合CAP定理是无法认识清楚，2PC其实只是选择了CAP中CA，虽然CA保证了可靠性，但是忽视网络通讯随时可能堵塞或失败，形成网络分区，反而不可靠，2PC带来的可靠性在分布式环境中是虚幻的。

在分布式系统中，CAP定理是King，CAP定理无论是理论高度或是工程实施高度都是要高于传统事务的，在CAP定理的干预下，传统ACID事务走向了妥协，变成了BASE，也就是走向最终一致性的柔性事务。

Saga是来自于1987年Hector GM和Kenneth Salem论文，从原理上看Saga好像比较简单：
1. 客户端发出订单创建请求createOrder()
2. OrderService会在其内部本地事务进行Order数据库操作，此时订单状态是待确认状态。
3. CustomerService会在其内部本地事务进行信用卡预授权操作，检查订单金额是否超过信用卡授信额度？
4. OrderService会在上一步确认业务不变性约束得到满足后，再次操作订单数据库状态，将订单状态改为确认状态。

但是，传统2PC/ACID事务中在上面任何一个步骤失败时会使用回滚操作，比如第三步出错，因为是两段提交，所以，第二段就不会进行确认提交，而是进行回滚Rollback，这样订单状态就恢复到当前事务之前的状态，但是在Saga这种BASE模式下,是无法实现像2PC回滚的，因为2PC是同步的，而Saga是异步的。

那么在Saga这种异步模式如何实现客户的及时响应呢？有两种可选方案：首先是当Saga流程全部完成时再发送响应，这样的好处是响应中带有处理结果，但是这样会降低可用性，CAP定理中，分布式环境中满足了C一致性，只能降低了可用性A。

第二种方案是推荐的，也就是在创建Saga之时，并不是等这个Saga流程完成时候，就发送响应给客户端，当然客户端可能只会得到一个事务ID号，并没有得到如期的处理结果，但是这样数据一致性比较弱的情况下，我们能获得很高的可用性A。

客户端可以根据事务ID号再次查询处理结果（通过浏览器异步调用或服务器端推送都可以），比如之前调用createOrder()，获得order的id，然后，根据这个id号调用getOrder(id)，这样就能获得自己创建的订单。在传统同步环境下，这两步其实是在同一个步骤实现的，也就是createOrder()的结果就是一个订单order。

通过UI界面设计可以降低这种不一致性导致的延迟体验：
1. UI会通过异步方式进行查询调用，给用户的体验感觉还是创建订单后返回了一个创建好的订单
2. Saga处理也是可以很快的，小于100毫秒。
3. 如果会花费很长时间，可以显示“正在处理中...”
4. Saga处理完成后可以采取服务器推送结果到浏览器。

### Saga是否实现了ACID？
ACID是原子性 一致性 隔离性和持久性的总称：

1. 原子性是确保事务中所有步骤要么全部完成，要么全部撤销回滚。Saga可以在事务中任何一个步骤发生失败时，通过调用应用服务的回滚接口实现撤销。

2. 一致性其实是数据的完整性，这个可以由一个应用服务内部的本地事务通过数据库机制完成，跨服务的完整性(Referential integrity)由应用完成。

3. 持久性Durability是由本地事务完成。

下面就剩下关键的隔离性，隔离性能够保证每个事务独立进行，不互相干扰，是与并发控制有关的，缺乏隔离性，会造成脏读 或者数据重复 更新丢失等问题。

在Saga中解决隔离性的策略可通过两种方式：
1. 可交换的更新(Commutative updates), 比如借方帐户可以看成是贷方帐户的补偿

2. 版本化，记录状态改变的历史记录，这些改变是可以交换的， 这其实是非常类似Event Sourcing事件溯源。
通过引入事件溯源能够实现很好的隔离性，因为回避了状态的实时并发修改，而是将这些修改动作作为事件记录下来，而是在状态需要读取时，对修改动作一个个进行播放，从而更新状态值到最新状态，也就是说，事件溯源回避了对状态的并发写操作，而是在读操作时进行状态实时计算。
比如a的初始状态是1，有三个修改动作：加入了100，减去了50，加入了20，事件溯源是将这三个动作作为事件先记录下来，并不是立即计算a的最终状态，而是当有状态读取动作时，遍历事件集合进行计算：1+100-50+20=71，客户端会获得a的最终状态是71。

### Saga的两个形态
Saga有两个方式：Orchestration(有中心协调者)和Choreography(无中心协调者)。

* Orchestration：各个服务围绕一个协调中心点，类似乐队需要一个指挥。
* Choreography：各个服务之间没有一个协调点，靠服务自己相互直接协调，如果跳集体舞一样(当然有时会有一个领舞者，但是不明显)。

无中心协调者的Saga方式需要使用事件概念，比如订单服务发布订单创建事件到客户服务那里，客户服务发布授信通过或不通过事件给订单服务。引入事件概念可能会增加业务应用开发的难度，除非业务应用时遵循DDD领域事件开发方式。

有中心协调者的Saga方式需要可能存在协调者本身失败的单点风险，但是能够方便减轻业务应用的开发量，能够形成Saga框架，由框架自己管理流程前进和回退。

比如以Eventuate Tram Saga框架代码应用为例，它定义了流程下一步和上一步补偿的各个业务动作：
```
SagaDefinition<CreateOrderSagaData> sagaDefinition =
          step()
            .withCompensation(this::reject)
          .step()
            .invokeParticipant(this::reserveCredit)
          .step()
            .invokeParticipant(this::approve)
          .build();
```
withCompensation是定义回退补偿动作，这里补偿是当前类的reject方法，而流程前进有两步：reserveCredit和approve两个方法。

reserveCredit方法其实是进行信用卡授信额度验证的动作，发送一个ReserveCreditCommand命令到客户服务：
```
private CommandWithDestination reserveCredit(CreateOrderSagaData data) {

    long orderId = data.getOrderId();
    Long customerId = data.getOrderDetails().getCustomerId();
    Money orderTotal = data.getOrderDetails().getOrderTotal();
    return send(new ReserveCreditCommand(customerId, orderId, orderTotal))
            .to("customerService")
            .build();
  }
```
而客户服务则监听这个命令形式的消息：
```
SagaCommandHandlersBuilder
            .fromChannel("customerService")
            .onMessage(ReserveCreditCommand.class, this::reserveCredit)
            .build();
```

相关资源：

* [Eventuate Tram Saga框架](https://github.com/eventuate-tram/eventuate-tram-sagas)
* [两个领域事件驱动的开源项目介绍](http://www.jdon.com/49112)
