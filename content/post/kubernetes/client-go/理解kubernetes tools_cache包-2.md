---
title: "理解kubernetes tools/cache包-2"
date: 2019-05-16T16:13:09+08:00
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
> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://blog.csdn.net/weixin_39961559/article/details/81940918

本系列深入介绍了informer的原理,这是本系列第二节
<!--more-->

在[上一篇文章中](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-1/)，我们研究了 k8s controller 的一些基础，并开始研究 tools/cache 包背后的概念，特别是 ListerWatcher，Store 和 Reflector。在这篇文章中，我们健康到 Controller 的实际概念。

我想说，我写过”Kubernetes controller”，不是”Kubernetes Controller” 或”Kubernetes controller”“Kubernetes Controller”。这是故意的，这部分是因为 tools/cache 包有 Controller 类型，逻辑位于 Reflector 之前。你可以自己[看看](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/controller.go#L74-L86)：

```go
// Controller is a generic controller framework.
type controller struct {
    config         Config
    reflector      *Reflector
    reflectorMutex sync.RWMutex
    clock          clock.Clock
}

type Controller interface {
    Run(stopCh <-chan struct{})
    HasSynced() bool
    LastSyncResourceVersion() string
}
```

请注意，有趣的是，严格来说，实现 Controller 类型所需要做的就是提供一个 Run()函数 (对于其他 Java 程序员，stopCh“stop channel” 是 Go 的 (基本上) 允许中断的方式)。如果同步已经完成，HasSynced ()函数返回 true。LastSyncResourceVersion()函数返回被 watched 和 reflected 的 k8s 资源列表的 resourceVersion。

这里有一个有趣的观点，这意味着虽然 Reflector 是一个完全与 Kubernetes 分离的通用接口，但这个接口在概念上与 Kubernetes 耦合 (注意术语 Resource 和 resource version，这两个概念都来自于 k8s 体系)。这种观察模式可以帮助我们改进 Java 模型。

接下来，看看 controller 结构体，他是 controller 实现的承载。它接受 Config 来实现配置，并有一个变量接受 Reflector，同时还有线程安全相关参数。

那么，Controller 究竟是做什么的，Reflector 还没开始工作呢？
答案的线索在于 [Config](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/controller.go#L29-L72) 参数，它作为 Controller 类型的一个特定实现细节：
```go
// Config contains all the settings for a Controller.
type Config struct {
    // The queue for your objects; either a FIFO or
    // a DeltaFIFO. Your Process() function should accept
    // the output of this Queue's Pop() method.
    Queue

    // Something that can list and watch your objects.
    ListerWatcher
    
    // Something that can process your objects.
    Process ProcessFunc
    
    // The type of your objects.
    ObjectType runtime.Object
    
    // Reprocess everything at least this often.
    // Note that if it takes longer for you to clear the queue than this
    // period, you will end up processing items in the order determined
    // by FIFO.Replace(). Currently, this is random. If this is a
    // problem, we can change that replacement policy to append new
    // things to the end of the queue instead of replacing the entire
    // queue.
    FullResyncPeriod time.Duration
    
    // ShouldResync, if specified, is invoked when the controller's reflector determines the next
    // periodic sync should occur. If this returns true, it means the reflector should proceed with
    // the resync.
    ShouldResync ShouldResyncFunc
    
    // If true, when Process() returns an error, re-enqueue the object.
    // TODO: add interface to let you inject a delay/backoff or drop
    //       the object completely if desired. Pass the object in
    //       question to this interface as a parameter.
    RetryOnError bool
}

// ShouldResyncFunc is a type of function that indicates if a reflector should perform a
// resync or not. It can be used by a shared informer to support multiple event handlers with custom
// resync periods.
type ShouldResyncFunc func() bool

// ProcessFunc processes a single object.
type ProcessFunc func(obj interface{}) error
```

当你阅读上面的摘录时，请记住它位于 controller.go 文件中，但是还有很多其它文档的类型和概念我们尚未遇到。

因此，并非所有 Controller 实现都必须使用它。实际上，Controller 并没有完全说明。实际上唯一重要的 Controller 实现，由 [New()](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/controller.go#L88-L95) 函数返回实现，由 controller 结构体支持，为了使用它，我们应该要更好的理解它。

首先要注意的是 Config 结构中包含一个 Queue。我们可以在 [fifo.go](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/fifo.go#L46-L67) 文件中找到它的定义：
```go
// Queue is exactly like a Store, but has a Pop() method too.
type Queue interface {
    Store

    // Pop blocks until it has something to process.
    // It returns the object that was process and the result of processing.
    // The PopProcessFunc may return an ErrRequeue{...} to indicate the item
    // should be requeued before releasing the lock on the queue.
    Pop(PopProcessFunc) (interface{}, error)
    
    // AddIfNotPresent adds a value previously
    // returned by Pop back into the queue as long
    // as nothing else (presumably more recent)
    // has since been added.
    AddIfNotPresent(interface{}) error
    
    // Return true if the first batch of items has been popped
    HasSynced() bool
    
    // Close queue
    Close()
}
```

所以一般来说 Queue 的所有实现也必须满足 Store 约定。用 Java 术语来说，这意味着假设 Queue 接口会扩展 Store，我们先把它归档以供日后使用。

我们在这个接口里还遗漏了一些概念，回想一下，Controller 实现必须具有 HasSynced 函数，但它的目的和原因并没有说明。当我们回顾 Controller-struct 支持的实现 (Controller 类型的一种可能实现) 时，我们可以看到它的 HasSynced 函数的实现仅仅委托给它的 Config 包含的 Queue。

所以我们假设 Controller 的实现最有可能是得到 Queue 的支持。尽管严格来说这不合适必须的，但这是实现 HasSynced 函数最简单的方法。这也是我们将要了解该函数的作用：如果第一批 items 已经 popped，返回 true。

回到 Config，它也包含了 ListerWatcher。咦，这个我们在哪里见过之前？我们意识到它是 Reflector 的核心组件，那么为什么 Config 也有一个 Reflector 呢？为什么要在这里打破封装，ListerWatcher 难道不是 Reflector 的实现细节？是的，似乎还没有充分的理由。
稍后我们可以从源码看 controller 的结构体实现方法 Run() 函数，它使用 Config 的 ListerWatcher 实时的创建了 Reflector。有个问题是 Reflector 为什么不作为 Config 的参数传入，不得而知。无论如何，从逻辑上将，Reflector 是 Controller 接口的 controller-struct 实现的一部分。
接下来我们的第一个真正有趣的部分是之前没有见过的，它让我们更好的了解 Controller 应该做什么：ProcessFunc，从文档中查看时对 k8s 的某种资源执行某些操作：
```go
ProcessFunc processes a single object.
```

即使从这一点文档黄总我们也可以看到，Controller 的实现最终使用了 Config(记住，它不是必需的)，它不仅获取 k8s 资源 cache 到 Store 中，也会对 Store 中的 Object 发现起作用。
这个是不确定的假设，并没有任何规定要这么去实现，但结果非常重要，不仅仅是对 Controller 类型的标准实现 (使用 Config 的 controller-struct 支持)，而是隐含的，但技术上没有指定。

总而言之，大多数 Controller 的实现都可能是使用 Reflector 来填充特定资源类型的 Queue(特定类型的 Store)，然后还处理 Queue 的内容，通过 popping objects 来实现。
我们看到的模型如下：
![](https://img-blog.csdn.net/20180822120942591?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl8zOTk2MTU1OQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
这里，Controller 使用 Reflector 来填充 Queue，并且有一个受保护的进程方法知道如何对给定 Object 执行某些操作。它还有一个受保护的方法 shouldResync()，一个 public hasSynced() 方法，能够在同步后报告最后一个 kubernetes resource version，我们将极大的改进和重构这个模型。