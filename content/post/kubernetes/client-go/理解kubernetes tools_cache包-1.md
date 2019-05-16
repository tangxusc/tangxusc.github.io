---
title: "理解kubernetes tools/cache包-1"
date: 2019-05-16T16:13:08+08:00
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
> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://blog.csdn.net/weixin_39961559/article/details/81938716

本系列深入介绍了informer的原理,这是本系列第一节
<!--more-->



​	想知道如何编写 k8s controller(例如我的案例)，在 java 中,我们必须知道事件的真实来源。
如果 k8s 可以被看作是一个分布式消息传递系统，你想要获得的是消息的 specifications 状态，那么 “消息” 来自何处呢？

在任意时刻，kubectl 创建应用或者是删除某些内容，都需要发布消息。这些消息包括 kubernetes 想要创建，更新或删除的资源。这些消息由 3 部分组成：

`kind`，表示消息的是什么类型

`specification`，描述了你想要的资源创建，更改或删除的状态

`status`，表示了实际运行状况的状态

通常，如果你正在编辑 yaml 文件并使用 kubectl，那么你只需要关注 specification 因为只有 kubernetes 本身才能告诉你 yaml 运行的具体情况。

那么你需要向谁发送 specification 消息呢？答案是：api server。

我们以不同的方式看待它。

在略高的级别，它也是一个消息代理，kubectl POST、PUT、PATCH 或 DELETE 一个 resource，api server 接收它并将这个操作有效的广播给其它想对该操作响应的 listeners。想要监听这些 specification 消息，你需要用到 k8s 的监听机制。

K8s 提供了 watch 接口 (但是实际上这种做法是不推荐使用的)，当你使用后，k8s 将返回一个 [WatchEvents](https://kubernetes.io/docs/api-reference/v1.9/#watchevent-v1-meta) 流，描述该类型资源的 [Events](https://kubernetes.io/docs/api-reference/v1.9/#event-v1-core)。

如果你愿意，消息 channel 可以根据 kind 过滤消息。K8s 的 watch 是建立在 etcd 之上并继承了他们的概念属性。(更多特性可以查看文章 [kubernetes Events Can be Complicated](https://lairdnelson.wordpress.com/2017/04/27/kubernetes-events-can-be-complicated/))。

因此，要编写一个消息监听器来响应特定类型资源的 specification 消息，我们所要做的只是实现一个合适的 k8s 监听器，难道不是吗？答案是，不完全正确。虽然监听器比之前的要轻巧，但他们并不完全轻巧，更重要的是，你可能会对所有的 specification 变化做出相应，你可能会进入一个逻辑事件流中。因此，你首先要列出所要处理的事，然后再开始建立你的监听机制。

为了编写一个好的 k8s controllers，有必要深入研究 tools/cache 包，它是用 go 语言实现的一个框架。这个包必须列出给定类型的所有资源，例如 pod，deployment，然后监听它们。这个组合会给你提供对象的逻辑集合和对它们的修改。

果然，如果你足够深入，你最终会看到 listwatch.go 文件，在该文件里，你会看到 listerWatcher 类型，什么如下：

```go
// ListerWatcher is any object that knows how to perform an initial list and start a watch on a resource.
type ListerWatcher interface {
    // List should return a list type object; the Items field will be extracted, and the
    // ResourceVersion field will be used to start the watch in the right place.
    List(options metav1.ListOptions) (runtime.Object, error)
    // Watch should begin a watch at the specified version.
    Watch(options metav1.ListOptions) (watch.Interface, error)
}
```

我们想找到这个类型的实现以支持由 k8s 客户端或 http 客户端等，因此，k8s apiserver 应该要满足这样的 List() 函数。看，这里有个[函数](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/listwatch.go#L64-L85)：

```go
// NewListWatchFromClient creates a new ListWatch from the specified client, resource, namespace and field selector.
func NewListWatchFromClient(c Getter, resource string, namespace string, fieldSelector fields.Selector) *ListWatch {
    listFunc := func(options metav1.ListOptions) (runtime.Object, error) {
        options.FieldSelector = fieldSelector.String()
        return c.Get().
            Namespace(namespace).
            Resource(resource).
            VersionedParams(&options, metav1.ParameterCodec).
            Do().
            Get()
    }
    watchFunc := func(options metav1.ListOptions) (watch.Interface, error) {
        options.Watch = true
        options.FieldSelector = fieldSelector.String()
        return c.Get().
            Namespace(namespace).
            Resource(resource).
            VersionedParams(&options, metav1.ParameterCodec).
            Watch()
    }
    return &ListWatch{ListFunc: listFunc, WatchFunc: watchFunc}
}
```

你可以在源码中进一步挖掘，你将会发现对 c 的调用实际上是在调用 k8s 客户端。

因此我们需要一个组件能够对指定类型 list 和 watch。还要注意它能够 fieldSelector，用来根据过滤消息流。不幸的是，fieldSelector 现在还非常原始并且大部分还没文档介绍，但总比没有好。

假设我们的 k8s client 支持 ListerWatcher，我们现在有指定类型的 k8s 逻辑集合以及与这类资源有关的一定数量的消息，我们应该将这些东西存储在哪里呢，放在 [Store](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/store.go) 里怎样？

```go
type Store interface {
    Add(obj interface{}) error
    Update(obj interface{}) error
    Delete(obj interface{}) error
    List() []interface{}
    ListKeys() []string
    Get(obj interface{}) (item interface{}, exists bool, err error)
    GetByKey(key string) (item interface{}, exists bool, err error)

    // Replace will delete the contents of the store, using instead the
    // given list. Store takes ownership of the list, you should not reference
    // it after calling this function.
    Replace([]interface{}, string) error
    Resync() error
}
```

Store 似乎比较好用和通用 (除了 go 语言之外没有任何类型的参数)，如果我们要扩展 ListerWatcher 以接收可以转存其内容的 Store，那将是一件好事。基于各种原因，tools/cache 包创建了 [Reflector](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/reflector.go#L49-L74) 的概念，它将 ListerWatcher 和 Store 组合在一起，并将 ListerWatcher List() 函数的返回值存进 Store，[同时将 WatchEvents 关联到 Store 的添加，更新和删除](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/reflector.go#L395-L416)。

我们想一想，为什么要叫它为 reflector。从某种角度来说，它将 k8s 消息通道中的内容反映 (reflector) 到缓存中。然后你现在 k8s controller 中使用了定类型资源的 specifications 和 statuses 做逻辑时，你可以查看 cache 而不是直接访问 apiserver。

需要注意的是，目前这个子系统是独立运行的，如果你有一个 k8s 客户端支持 ListerWatcher，Store 和 Reflector 绑定在一起，你就有了一个在很多场景下都适用的组件。更重要的是，从理论上来说，通过 Rflector 清理空间，理解一个缓存时间我们想要去响应，并且我们已经深入研究它的其它机制和实现细节。

如果我们利用面向对象编程和一点 Java 的概念 (毕竟，这个系列是关于推到 k8s controller 框架的 java 实现)，我们可以省去 ListerWatcher 概念并将其折叠成 Reflector 概念去实现它的细节。如果我们这样做，我们的这些模型可能会如下所示：
![](https://img-blog.csdn.net/20180822094718670?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl8zOTk2MTU1OQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

这里，KubernetesResourceReflector 是 Reflector(假设的) 的具体实现，设置为由 T 参数表示的特定类型资源。在构造它时给它一个 kubernetesClient 和 Store 实现它并 run()，它复制 k8s 指定类型资源 cache 到 Store 中 (我们都知道实际使用了某种机制，类似于 ListerWatcher 机制，但是终端用户并不关心这个机制的实际 listening 和 watching，只是填充了缓存)。随着时间的推移，我们将极大地改进和重构这个模型。