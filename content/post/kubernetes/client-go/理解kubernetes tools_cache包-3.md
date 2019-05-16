---
title: "理解kubernetes tools/cache包-3"
date: 2019-05-16T16:13:10+08:00
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
> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://blog.csdn.net/weixin_39961559/article/details/81945559

本系列深入介绍了informer的原理,这是本系列第三节
<!--more-->

[在第三节中](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-2/)，我们谈到了 Controller 概念，探讨了它是怎么使用到了 Reclector 提供的功能。如果你没还有关注并了解它的全部内容，建议你从 [从头开始](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-1/)）开始阅读。

在这一节中，我们将详细介绍一下亮点：

1.controller 类型的标准实现 (严格来讲，这只是众多可能性的一种，但不幸的是，它对 Controller 概念的期望添加了色彩)；

2.informer 和 SharedInformer 的概念，尤其是 SharedIndexInformer；

### controller–struct-Backed Controller Implementation

从前面的文章看，Controller 类型并不明确。
Controller 只要实现 3 个未说明的函数：Run，HasSynced 和 LastSyncResourceVersion 即可。
从技术上讲，你可以以任何方式实现它。

实际上，这种 controller-struct-backed 是有标准参考实现的，也表明存在一个隐含的要求，假定任何 Controller 都将实现 Run 函数作为其一部分，同时也要处理 Queue，另外 Reflector 也必须要有。这是很多假设，当我们用 Java 对比进行建模时，我们将正式提到他们。

让我们仔细观察 queue 处理的细节。首先，回想下 Queue 只是一个具有 Pop 功能的 Store(详情见 [第二节](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-2/)））。
在 controller.go 中，我们单独查看 [processLoop](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/controller.go#L139-L161) 函数：

```go
// processLoop drains the work queue.
// TODO: Consider doing the processing in parallel. This will require a little thought
// to make sure that we don't end up processing the same object multiple times
// concurrently.
//
// TODO: Plumb through the stopCh here (and down to the queue) so that this can
// actually exit when the controller is stopped. Or just give up on this stuff
// ever being stoppable. Converting this whole package to use Context would
// also be helpful.
func (c *controller) processLoop() {
    for {
        obj, err := c.config.Queue.Pop(PopProcessFunc(c.config.Process))
        if err != nil {
            if err == FIFOClosedError {
                return
            }
            if c.config.RetryOnError {
                // This is the safe way to re-enqueue.
                c.config.Queue.AddIfNotPresent(obj)
            }
        }
    }
}
```

由于这是 go 函数并且以小写 p 开头，因此我们知道它对于 controller-struct 支持的实现是私有的。现在，我们相信在其它的函数中调用了它。

在这个 loop 中，我们可以直观的看到 Obj 从 Queue 中 popoed，如果发生错误会重新将 obj 入队。

更具体的说，PopProcessFunc（c.config.Process）的结果是 [go 类型转换](https://tour.golang.org/basics/13)，在这种情况下，将创建时提供给此 Controller 实现的 Config 中存储的 [ProcessFunc](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/fifo.go#L26-L28) 转换为 fifo.go 文件定义的 PopProcessFunc。回想一下 c.config.Process 的类型是 [ProcessFunc](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/controller.go#L71-L72)。 （无论如何，对于这个 Go 菜鸟来说，这两种类型似乎相当。)

从 Java 程序员的角度来看，我们开始看到了一个抽象类 - 而不是一个接口。

具体来说，其强制执行的 Run 函数显然” 应该” 与上面的 processLoop 中的概述具有相同的调用逻辑方式。

并且可以以一种或另一种方式预期 Controlle 实现，将 Queue 中的内容耗尽，并且期望 Run 并行的完成这些。我们暂时将其归档，但现在我们已经非常详细地了解了 Controller 的预期实现，即使这些内容在 contract 中没有真正被提及。

在这一点上你可能会遇到的一个问题是：我们不是这样做的吗？我们是否通过一种机制 reflect k8s 的 apiserver 通过 lists 和 watches 到 cache，以及我们对 Controller 实现的了解，处理 cache 的能力？这不是给我们一个框架来接收和处理 k8s specification 消息 ？

现在，答案是否定的，随意到目前为止，所有的东西都推到了 Controller 的总称之下。回想一下，隐藏在它下面的是 Reflectors，Stores，Queues，ListerWatchers，ProcessFuncs 等概念，但是现在你可以将它们全部包装到 Controller 中，并释放一些空间用于下一步：informers。

### Informers

此时你可能知道了文件命名格式：Controller 定义在 controller.go 中，ListerWatcher 在 listwatch.go 中定义，依此类推。 但是你找不到一个 informer.go 文件。

你不会找到一个 Informer 类型。然而，informer 的概念，你可以从它的逻辑中拼凑起来，虽然不具体。
首先，让我们查看 [NewInformer function](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/controller.go#L264-L327)，它定义在 controller.go:

```go
// NewInformer returns a Store and a controller for populating the store
// while also providing event notifications. You should only used the returned
// Store for Get/List operations; Add/Modify/Deletes will cause the event
// notifications to be faulty.
//
// Parameters:
//  * lw is list and watch functions for the source of the resource you want to
//    be informed of.
//  * objType is an object of the type that you expect to receive.
//  * resyncPeriod: if non-zero, will re-list this often (you will get OnUpdate
//    calls, even if nothing changed). Otherwise, re-list will be delayed as
//    long as possible (until the upstream source closes the watch or times out,
//    or you stop the controller).
//  * h is the object you want notifications sent to.
//
func NewInformer(
    lw ListerWatcher,
    objType runtime.Object,
    resyncPeriod time.Duration,
    h ResourceEventHandler,
) (Store, Controller) {
    // This will hold the client state, as we know it.
    clientState := NewStore(DeletionHandlingMetaNamespaceKeyFunc)

    // This will hold incoming changes. Note how we pass clientState in as a
    // KeyLister, that way resync operations will result in the correct set
    // of update/delete deltas.
    fifo := NewDeltaFIFO(MetaNamespaceKeyFunc, nil, clientState)
    
    cfg := &Config{
        Queue:            fifo,
        ListerWatcher:    lw,
        ObjectType:       objType,
        FullResyncPeriod: resyncPeriod,
        RetryOnError:     false,
    
        Process: func(obj interface{}) error {
            // from oldest to newest
            for _, d := range obj.(Deltas) {
                switch d.Type {
                case Sync, Added, Updated:
                    if old, exists, err := clientState.Get(d.Object); err == nil && exists {
                        if err := clientState.Update(d.Object); err != nil {
                            return err
                        }
                        h.OnUpdate(old, d.Object)
                    } else {
                        if err := clientState.Add(d.Object); err != nil {
                            return err
                        }
                        h.OnAdd(d.Object)
                    }
                case Deleted:
                    if err := clientState.Delete(d.Object); err != nil {
                        return err
                    }
                    h.OnDelete(d.Object)
                }
            }
            return nil
        },
    }
    return clientState, New(cfg)
}
```

正如你所看到的，没有 informer 这样的东西。

但是你也可以看到这里有一个隐式构造：一种特殊的 Controller，实际上，它的相关队列叫做 DeltaFIFO(后面我们会讲到)，因此可以在增量上运行，并且有某种类型的在给定增量之后被通知的事件处理程序的概念被 “转换” 回其各自的对象 - 动词组合。

我们看到 ListerWatcher 和 Config 也在那里：你可以看到你正在为 Reflector 及其包含的 Controller 提供原材料，以及自定义 ProcessFunc 通过委托方式给事件处理程序。

实际上，NewInformer 函数只是利用 Go 的能力来拥有多个返回类型并返回一个 Controller 及其关联的 Store，而不是一个 Informer，因为没有这样的东西，并添加了一些未强制要求的 Store 的使用 (即不要修改它)。

客户端可以 “丢弃”Controller 并仅使用返回的 Store，可能与它提供的事件处理程序一起使用，也可能不使用，并且 Store 可以作为 Kubernetes apiserver 的 cache。
从这一切我们可以假定概念上 informer”是一个 Controller，它具有将其 Queue 相关的操作分发到适当的事件处理 (event handler) 的能力。

当我们在 Java 中对此进行建模时，这将有助于我们，对 Java 程序员来说，应该开始看起来有点像旧的 JavaBeans 事件监听器。

这是一个特别好的见解，因为我们最终想要让一些 Java 程序员编写某种方法，在发现添加，修改或删除时调用，而不需要程序员担心所有多线程到目前为止我们遇到的队列操作。 它也有帮助，因为这种情况是 Java 最终可以帮助我们编写更简单的代码的情况之一。
正如您所料，有不同的具体类型的 informers。 我们将特别关注一个，但肯定还有其他的 informers。 我们将看到的那个叫做 [SharedIndexInformer](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go)，可以在 shared_informer.go 文件中找到。

### SharedIndexInformer

SharedIndexInformer 本身就是一个 SharedInformer 实现，它增加了索引其内容的能力。 我提到它的所有之前的参考只是在 set 阶段：你应该问一些问题：什么是共享的？ 什么被索引？ 为什么我们需要分享东西等？
我们看下 [SharedInformer](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L33-L63) 定义:

```go
// SharedInformer has a shared data cache and is capable of distributing notifications for changes
// to the cache to multiple listeners who registered via AddEventHandler. If you use this, there is
// one behavior change compared to a standard Informer.  When you receive a notification, the cache
// will be AT LEAST as fresh as the notification, but it MAY be more fresh.  You should NOT depend
// on the contents of the cache exactly matching the notification you've received in handler
// functions.  If there was a create, followed by a delete, the cache may NOT have your item.  This
// has advantages over the broadcaster since it allows us to share a common cache across many
// controllers. Extending the broadcaster would have required us keep duplicate caches for each
// watch.
type SharedInformer interface {
    // AddEventHandler adds an event handler to the shared informer using the shared informer's resync
    // period.  Events to a single handler are delivered sequentially, but there is no coordination
    // between different handlers.
    AddEventHandler(handler ResourceEventHandler)
    // AddEventHandlerWithResyncPeriod adds an event handler to the shared informer using the
    // specified resync period.  Events to a single handler are delivered sequentially, but there is
    // no coordination between different handlers.
    AddEventHandlerWithResyncPeriod(handler ResourceEventHandler, resyncPeriod time.Duration)
    // GetStore returns the Store.
    GetStore() Store
    // GetController gives back a synthetic interface that "votes" to start the informer
    GetController() Controller
    // Run starts the shared informer, which will be stopped when stopCh is closed.
    Run(stopCh <-chan struct{})
    // HasSynced returns true if the shared informer's store has synced.
    HasSynced() bool
    // LastSyncResourceVersion is the resource version observed when last synced with the underlying
    // store. The value returned is not synchronized with access to the underlying store and is not
    // thread-safe.
    LastSyncResourceVersion() string
}
```

这告诉我们所有的 SharedInformer(Controller 和事件分发机制的组合) 必须做什么。SharedInformer 是一种可以支持许多事件处理程序的 informer。

由于这个特定的 informer 构造可以有许多事件处理程序 (event handlers)，然后构建它的单个缓存 - 由它构建的 Controller 所包含的 Queue，在大多数情况下 - 在这些处理程序之间变为 “共享”。
所有 SharedIndexInformer 添加到 [picture 中都是为了能够通过各种键在其缓存中查找 items](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L65-L70)：

```go
type SharedIndexInformer interface {
    SharedInformer
    // AddIndexers add indexers to the informer before it starts.
    AddIndexers(indexers Indexers) error
    GetIndexer() Indexer
}
```

在这里你需要非常注意单数和复数名词。 请注意，您添加的是一个索引器 (Indexers)，复数 (plural)，您得到的是一个索引器 (Indexer)，单数 (singular)。 

让我们来看看它们是什么。
我们将从复数形式的索引器开始，因为奇怪的是它原来是单个项目，而不是，最值得注意的是，它是一堆 Indexer 实例！
这实际上只是一种 [map](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/index.go#L83-L84)(单数) 类型，可以在 index.go 文件中找到：

```go
// Indexers maps a name to a IndexFunc
type Indexers map[string]IndexFunc
```

反过来，[IndexFunc](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/index.go#L45-L46) 只是一个映射函数：

```go
// IndexFunc knows how to provide an indexed value for an object.
type IndexFunc func(obj interface{}) ([]string, error)
```

因此，将它交给 Kubernetes 资源，它将以某种方式返回一组（我假设）与其对应的字符串值。因此，索引器是具有复数名称的单个对象，因此是这些函数的简单映射，其中每个函数依次在其自己的字符串键下索引。

因此，您可以将一堆这些映射添加到 SharedIndexInformer 中以供其使用。Indexer 是一个描述聚合概念（！）的单数名词，是这类 [Indexers 实例的集合](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/index.go#L26-L43)（！），其中一些额外的聚合行为分层在顶层：

```go
// Indexer is a storage interface that lets you list objects using multiple indexing functions
type Indexer interface {
    Store
    // Retrieve list of objects that match on the named indexing function
    Index(indexName string, obj interface{}) ([]interface{}, error)
    // IndexKeys returns the set of keys that match on the named indexing function.
    IndexKeys(indexName, indexKey string) ([]string, error)
    // ListIndexFuncValues returns the list of generated values of an Index func
    ListIndexFuncValues(indexName string) []string
    // ByIndex lists object that match on the named indexing function with the exact key
    ByIndex(indexName, indexKey string) ([]interface{}, error)
    // GetIndexer return the indexers
    GetIndexers() Indexers

    // AddIndexers adds more indexers to this store.  If you call this after you already have data
    // in the store, the results are undefined.
    AddIndexers(newIndexers Indexers) error
}
```

因此，从 SharedIndexInformer 可以获得一个真正的索引器，该索引器在逻辑上由通过（希望）添加的 SharedIndexInformer 的 AddIndexers 函数添加的各种 Indexers 实例组成，尽管也可以直接从 Indexer 添加它们。

另一个非常重要的事情是，Indexer 也是 Store！ 但要非常小心地注意它作为 Store 的使用方式。
具体来说，让我们首先回想起一个非共享的 informer - 它没有 Go 语言的具体化 - 在概念上是 Controller 和 Store 的组合。

例如，我们已经看到 NewInformer 函数返回一个 Controller 和一个附加到该 Controller 的 Store; 该组合为您提供自动填充缓存的能力。
在 SharedIndexInformer 中，反映 Kubernetes apiserver 事件的 Store 是 [DeltaFIFO](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L191)，而不是 Indexer。

但是 Indexer 被[提供给](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L191) DeltaFIFO，并且作为 SharedIndexInformer 的 [GetStore 函数的返回值](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/shared_informer.go#L249-L251)！ 这告诉我们更多关于 GetStore 隐含的信息：显然它返回的 Store 不得用于修改！
另一个非常重要的事情是任何 [Store 也是 KeyListerGetter](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/store.go#L38-L39)，KeyLister 和 KeyGetter。 KeyListerGetter 是 KeyLister 和 KeyGetter 类型的组合。[KeyLister](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/delta_fifo.go#L596-L599) 可以列出其所有 keys 包含的，[KeyGetter](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/delta_fifo.go#L601-L604) 可以通过 key 检索（就像 map 一样）。

因此，当 SharedIndexInformer 创建一个新的 DeltaFIFO 用作其 Store 时，然后为该 DeltaFIFO 提供一个 Indexer，它仅以 KeyListerGetter 的身份提供该 Indexer。 类似地，它的 GetStore 方法可能真的应该返回比实际 Store 更接近 KeyListerGetter 的东西，因为禁止调用它的修改方法。

我们将不得不潜入 DeltaFIFO，我们现在已经看到它是所有这一切的核心，并将成为下一篇文章的主题。
让我们回顾一下到目前为止我们在这里提出的问题：

*   Controller 实际上必须像引用 controller–struct-backed 的 Controller 实现一样。 具体来说，它需要管理一个 Queue，它通常是 DeltaFIFO，并且填充和排空它，并包含一个事件监听器机制。
*   存在 informer，它是 Controller 和它所连接的 Store 的组合，但除了 “共享” 形式外，它不存在。
*   SharedIndexInformer 实例化具有多个事件处理程序的 informer 的概念，并且根据定义，它们共享一个 Queue，一个 DeltaFIFO。
    我们的视图如下所示：
    ![](https://img-blog.csdn.net/20180822155719426?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl8zOTk2MTU1OQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)