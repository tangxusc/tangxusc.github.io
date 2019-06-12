---
title: "理解kubernetes tools/cache包-6"
date: 2019-05-16T16:13:13+08:00
categories:
- k8s
- client
tags:
- k8s
- client-go
keywords:
- client-go
- client
#thumbnailImage: //example.com/image.jpg
---
> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://blog.csdn.net/weixin_39961559/article/details/81948239

本系列深入介绍了informer的原理,这是本系列第六节
<!--more-->

![](https://img-blog.csdn.net/20180822164709316?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl8zOTk2MTU1OQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
在本系列的`第五节`中（如果您愿意，可以[从头](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-1/)开始）,我们将工具 / 缓存包的所有结构部分放在一起。 但是，我意识到我犯了一个错误，并没有涵盖 sharedProcessor 和 processorListener 结构！ 在继续研究包的行为方面之前，我会在这里做。

我们先来看看 [processorListener](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L468-L491)：
首先，让我们同意 processorListener 是程序中的糟糕名称。同意不？ OK，好的; 让我们继续。

processsorListener 是 tools/cache 项目中的实现构造，它缓冲一组通知并将它们分发到 ResourceEventHandler（在 [part 3](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-3/) 中介绍）。

如果添加通知，最终将在单独的线程上调用 ResourceEventHandler 的 OnAdd，OnUpdate 或 OnDelete 函数。 它的结构代码非常简单：

```go
type processorListener struct {
    nextCh chan interface{}
    addCh  chan interface{}

    handler ResourceEventHandler
    
    // pendingNotifications is an unbounded ring buffer that holds all notifications not yet distributed.
    // There is one per listener, but a failing/stalled listener will have infinite pendingNotifications
    // added until we OOM.
    // TODO: This is no worse than before, since reflectors were backed by unbounded DeltaFIFOs, but
    // we should try to do something better.
    pendingNotifications buffer.RingGrowing
    
    // requestedResyncPeriod is how frequently the listener wants a full resync from the shared informer
    requestedResyncPeriod time.Duration
    // resyncPeriod is how frequently the listener wants a full resync from the shared informer. This
    // value may differ from requestedResyncPeriod if the shared informer adjusts it to align with the
    // informer's overall resync check period.
    resyncPeriod time.Duration
    // nextResync is the earliest time the listener should get a full resync
    nextResync time.Time
    // resyncLock guards access to resyncPeriod and nextResync
    resyncLock sync.Mutex
}
```

processorListener 有一个[不会退出的运行函数](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L542-L557)，可以从其 nextCh Go 通道（基本上是同步阻塞队列）中提取通知，并将它们转发到它的 ResourceEventHandler：
```go
func (p *processorListener) run() {
    defer utilruntime.HandleCrash()

    for next := range p.nextCh {
        switch notification := next.(type) {
        case updateNotification:
            p.handler.OnUpdate(notification.oldObj, notification.newObj)
        case addNotification:
            p.handler.OnAdd(notification.newObj)
        case deleteNotification:
            p.handler.OnDelete(notification.oldObj)
        default:
            utilruntime.HandleError(fmt.Errorf("unrecognized notification: %#v", next))
        }
    }
}
```

那么通知如何在 nextCh 中获得的？ processorListener 有一个永不停止的 [pop 函数](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L512-L540)（有点令人惊讶）。 

代码对我来说根本不直观，但是如果你眯着眼睛，你可以看到它基本上是从 pendingNotifications 环缓冲区中拉出 items 并将它们放在 nextCh Go 通道上：

```go
func (p *processorListener) pop() {
    defer utilruntime.HandleCrash()
    defer close(p.nextCh) // Tell .run() to stop

    var nextCh chan<- interface{}
    var notification interface{}
    for {
        select {
        case nextCh <- notification:
            // Notification dispatched
            var ok bool
            notification, ok = p.pendingNotifications.ReadOne()
            if !ok { // Nothing to pop
                nextCh = nil // Disable this select case
            }
        case notificationToAdd, ok := <-p.addCh:
            if !ok {
                return
            }
            if notification == nil { // No notification to pop (and pendingNotifications is empty)
                // Optimize the case - skip adding to pendingNotifications
                notification = notificationToAdd
                nextCh = p.nextCh
            } else { // There is already a notification waiting to be dispatched
                p.pendingNotifications.WriteOne(notificationToAdd)
            }
        }
    }
}
```

因此必须启动 run 和 pop 函数。 该工作属于 sharedProcessor。 [sharedProcessor 非常简单](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L374-L380)：

```go
type sharedProcessor struct {
    listenersLock    sync.RWMutex
    listeners        []*processorListener
    syncingListeners []*processorListener
    clock            clock.Clock
    wg               wait.Group
}
```

它也有[不会退出的 Run 功能](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L188-L227)。 它首先要做的是在不同的线程上启动 processorListeners 的 run 和 pop 函数。 然后它阻塞并等待信号关闭：

```go
func (p *sharedProcessor) run(stopCh <-chan struct{}) {
    func() {
        p.listenersLock.RLock()
        defer p.listenersLock.RUnlock()
        for _, listener := range p.listeners {
            p.wg.Start(listener.run)
            p.wg.Start(listener.pop)
        }
    }()
    <-stopCh
    p.listenersLock.RLock()
    defer p.listenersLock.RUnlock()
    for _, listener := range p.listeners {
        close(listener.addCh) // Tell .pop() to stop. .pop() will tell .run() to stop
    }
    p.wg.Wait() // Wait for all .pop() and .run() to stop
}
```

好的，谁告诉 sharedProcessor 的 run 方法做什么事情？ sharedIndexInformer 的 run 方法。 在那里，[你会发现这一行](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L219)：

```go
wg.StartWithChannel(processorStopCh, s.processor.run)
```

这会在新线程中生成 sharedIndexInformer 的 sharedProcessor 的 run 函数（如果信号给 processorStopCh 通道发送，那么它将停止）。

退一步，为什么所有这些线程？ 为什么这么复杂？

我能想到的最好解释就是：

rocessorListener 实际上是一个线程的内容，它可能会被一个行为不当的 ResourceEventListener 阻塞一段时间，该资源受最终用户的控制。 所以你希望它的 “出队” 行为在它自己的线程上，这样一个表现不好的 ResourceEventListener 不会意外地导致整个 Pinball 停止工作，而 Kubernetes 继续以疯狂的速度发送事件。

sharedProcessor 实际上是一种将一堆 processorListeners 捆绑在一起，除了管理其线程问题之外，还可以在[给他们发送单个通知](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L403-L416)。 

例如，在 Java 中，我们有能够中断内置线程的内容，我们可能会将这两个问题混合在一起。 这个东西的更好名称可能更像是 EventDistributor。

[如前所述](https://blog.csdn.net/weixin_39961559/article/details/81945559)，sharedIndexInformer 有其自己的线程问题，以免减慢 Kubernetes 事件的接收速度。
现在我们已经将 processorListener 和 sharedProcessor 类型添加到组合中，让我们修改我们的整体结构图以包含它们：
![](https://img-blog.csdn.net/20180822174009505?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl8zOTk2MTU1OQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)