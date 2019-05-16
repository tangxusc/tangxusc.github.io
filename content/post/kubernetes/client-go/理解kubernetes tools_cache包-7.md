---
title: "理解kubernetes tools/cache包-7"
date: 2019-05-16T16:13:14+08:00
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
> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://blog.csdn.net/weixin_39961559/article/details/81948541

本系列深入介绍了informer的原理,这是本系列第七节,也是最后一节
<!--more-->

在本系列的第六节中（如果需要，可以[从头开始](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-1/)），我们得到了一个相当完整的 sharedIndexInformer 结构视图及其导致的所有概念。

现在是时候看看这一切的行为方面了。

在下图中，我使用了 UML 2.0 构造。 

具体来说，填充箭头表示同步调用，实线上的空心箭头表示异步调用，虚线上的空心箭头表示返回值。 标记为 alt 的帧是遵循 UML 2.0 的条件分支点。 最后，我简化了一些刻板印象，我希望这些刻板印象是合情合理的。

![](https://img-blog.csdn.net/20180822174602902?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl8zOTk2MTU1OQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

此图以在 sharedIndexInformer 上调用 Run 函数的某人或某事开始。 Run 函数创建一个新的 DeltaFIFO，传递 MetaNamespaceKeyFunc 作为其 KeyFunc，以及 sharedIndexInformer 的 Indexer（它也是一个 KeyLister 和一个 KeyGetter，但你不能只看代码）。

然后，Run 函数创建一个新的 Controller，我在 [part 2](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-2/) 中详细介绍了它，并异步调用它的 run 函数。 sharedIndexInformer 的 Run 函数现在阻塞，直到显式关闭。

Controller 的 run 函数创建了一个 Reflector，为了本系列的目的，您可以手动过滤：相信通过使用其嵌入式 ListerWatcher，它可以准确地将 Kubernetes 资源放入其存储中，这恰好是之前创建的 DeltaFIFO。

在这一点上，我们在高层次上拥有一台 Rube Goldberg 机器，可将 Kubernetes 资源复制到 DeltaFIFO 中。 例如，如果新的 Pod 出现在 Kubernetes 中，那么它会显示在 DeltaFIFO 中。

现在 Controller 的运行进入一个[无限直到显式停止的循环](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/controller.go#L124)，它每秒调用 Controller 的 [processLoop](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/controller.go#L139-L161) 函数。

processLoop 函数通过 Reflector 将单个线程中存储 items 的 DeltaFIFO 出队。 换句话说，DeltaFIFO 是（如名称所示）缓冲队列，其中生产者通过 Reflector 实际上是 Kubernetes 本身，[并且消费者（有效地）在构建时提供给 Controller 的任何功能](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/controller.go#L39-L40)。

那么在构建时，该特定 Controller 提供了哪些功能？ [sharedIndexInformer 的 handleDeltas 函数](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L343-L372)。

因此，handleDeltas 函数是一个队列排除器，并且出于许多行为分析的目的，我们可以方便地忽略之前的所有内容。 我们知道，当调用此函数时，它已从（有效）Kubernetes 收到一组添加，更改，完全替换或删除。 这是它的样子：
```go
func (s *sharedIndexInformer) HandleDeltas(obj interface{}) error {
    s.blockDeltas.Lock()
    defer s.blockDeltas.Unlock()

    // from oldest to newest
    for _, d := range obj.(Deltas) {
        switch d.Type {
        case Sync, Added, Updated:
            isSync := d.Type == Sync
            s.cacheMutationDetector.AddObject(d.Object)
            if old, exists, err := s.indexer.Get(d.Object); err == nil && exists {
                if err := s.indexer.Update(d.Object); err != nil {
                    return err
                }
                s.processor.distribute(updateNotification{oldObj: old, newObj: d.Object}, isSync)
            } else {
                if err := s.indexer.Add(d.Object); err != nil {
                    return err
                }
                s.processor.distribute(addNotification{newObj: d.Object}, isSync)
            }
        case Deleted:
            if err := s.indexer.Delete(d.Object); err != nil {
                return err
            }
            s.processor.distribute(deleteNotification{oldObj: d.Object}, false)
        }
    }
    return nil
}
```

根据它正在处理的事情，它可以向另一个队列添加，更新或删除事件，这次是由驾驶整个列车的 [sharedIndexInformer 创建的](created%20by%20the%20sharedIndexInformer) <pangu></pangu> [Indexer](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/index.go#L26-L43)。 一旦 Add，Update 或 Delete 调用返回，它就会调用 sharedIndexInformer 的[关联 sharedProcessor](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L130) 上的 [distribute 函数](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L403-L416)。

sharedProcessor 的分发函数将通知转发给其相应的 processorListeners，有效地将通知多路复用。 因此，如果给定的 Delta 对象是添加，则将调用 processorListener 的 add 函数。

processorListener add 函数只是将传入通知放在名为 [addCh 的同步队列（Go 通道）](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L508-L510)上。 在这一点上，我们的通知之行暂时结束。

同时，回到 sharedIndexInformer，回想一下它的 Run 方法仍在使用中。 在创建 DeltaFIFO（现在正在入队和出队）和 Controller（间接入队并耗尽它）之后，它执行的第三个有意义的事情是在[单独的线程上调用其 sharedProcessor 上的 run 函数](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L219)。

sharedProcessor 运行函数产生另外两个线程，然后挂起，直到被告知关闭。 第一个线程调用 sharedProcessor 的[每个 processorListener 上的 run 函数](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L542-L557)。 第二个线程在每个 processorListener 上调用 pop 方法。 我们先来看一下 processListener 的 run 函数。

processListener 的 [run 函数](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L542-L557)只是从其 nextCh 同步队列（Go 通道）中拉出任何通知，并且根据它的类型，最终在用户提供的 ResourceEventHandler 上调用 OnUpdate，OnAdd 或 OnDelete。 这很简单，我可以在这里重现它：

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

那么什么东西放在 nextCh channel?pop 函数。 [此函数一直运行，直到被告知显式关闭，并将传入的通知从其 addCh 同步队列（Go 通道）中拉出并将它们放在 nextCh 通道上](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L518-L539)。

那么什么把东西放在 addCh channel 呢？ 查看几段并回想起这是我们 Kubernetes 事件之旅的逻辑结束：表示事件的通知由 processorListener 的 add 函数放置在 addCh 上，由 sharedProcessor 的 distribute 函数调用。

这似乎是结束这篇文章的时候了。 我建议您查看序列图的完整大小版本，并在重新阅读该系列时将其打印出来或保留在您旁边，此包中的许多结构将更有意义。