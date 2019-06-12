---
title: "理解kubernetes tools/cache包-4"
date: 2019-05-16T16:13:11+08:00
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
> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://blog.csdn.net/weixin_39961559/article/details/81946398

本系列深入介绍了informer的原理,这是本系列第四节
<!--more-->


[在第三节中](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-3/)，我们深入研究了 Controller 实现必须遵守的实际规约，并研究了什么是 informers 和 SharedIndexInformers。

在这篇文章中，我们将看看 [DeltaFIFO](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/delta_fifo.go)，因为它是很多内容的核心。 我们主要是孤立地做这件事，然后可能会在后来的文章中尝试 “将其重新插入”，这样我们就可以在更大的背景下理解它。

从 DeltaFIFO 名称来看，我们可以猜测我们将在某种程度上讨论差异，并在 queue 的背景下。 我们来看看它的[规约](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/delta_fifo.go#L63-L127)：
```go
// DeltaFIFO is like FIFO, but allows you to process deletes.
//
// DeltaFIFO is a producer-consumer queue, where a Reflector is
// intended to be the producer, and the consumer is whatever calls
// the Pop() method.
//
// DeltaFIFO solves this use case:
//  * You want to process every object change (delta) at most once.
//  * When you process an object, you want to see everything
//    that's happened to it since you last processed it.
//  * You want to process the deletion of objects.
//  * You might want to periodically reprocess objects.
//
// DeltaFIFO's Pop(), Get(), and GetByKey() methods return
// interface{} to satisfy the Store/Queue interfaces, but it
// will always return an object of type Deltas.
//
// A note on threading: If you call Pop() in parallel from multiple
// threads, you could end up with multiple threads processing slightly
// different versions of the same object.
//
// A note on the KeyLister used by the DeltaFIFO: It's main purpose is
// to list keys that are "known", for the purpose of figuring out which
// items have been deleted when Replace() or Delete() are called. The deleted
// object will be included in the DeleteFinalStateUnknown markers. These objects
// could be stale.
//
// You may provide a function to compress deltas (e.g., represent a
// series of Updates as a single Update).
type DeltaFIFO struct {
    // lock/cond protects access to 'items' and 'queue'.
    lock sync.RWMutex
    cond sync.Cond

    // We depend on the property that items in the set are in
    // the queue and vice versa, and that all Deltas in this
    // map have at least one Delta.
    items map[string]Deltas
    queue []string
    
    // populated is true if the first batch of items inserted by Replace() has been populated
    // or Delete/Add/Update was called first.
    populated bool
    // initialPopulationCount is the number of items inserted by the first call of Replace()
    initialPopulationCount int
    
    // keyFunc is used to make the key used for queued item
    // insertion and retrieval, and should be deterministic.
    keyFunc KeyFunc
    
    // deltaCompressor tells us how to combine two or more
    // deltas. It may be nil.
    deltaCompressor DeltaCompressor
    
    // knownObjects list keys that are "known", for the
    // purpose of figuring out which items have been deleted
    // when Replace() or Delete() is called.
    knownObjects KeyListerGetter
    
    // Indication the queue is closed.
    // Used to indicate a queue is closed so a control loop can exit when a queue is empty.
    // Currently, not used to gate any of CRED operations.
    closed     bool
    closedLock sync.Mutex
}

var (
    _ = Queue(&DeltaFIFO{}) // DeltaFIFO is a Queue
)
```

为了进一步说明这一点，让我们现在概念性地忽略线程问题，由 delta Compressor 字段表示的 “delta compression” 和“queue is closed”问题。
我们留下的的类型可以描述如下：

*   DeltaFIFO 是 Deltas Queue 实例。 事实证明，Deltas 类型只是 Delta 实例的集合。 我们马上就会看到那些是什么。
*   DeltaFIFO 的 Deltas 实例是 “keyable”。 可以通过 KeyFunc 从给定的 Deltas 实例中提取字符串 key。
*   DeltaFIFO 中的某些 Deltas 实例可以 “known”。

让我们来看看 [Delta 类型](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/delta_fifo.go#L637-L645)是什么：
```go
// Delta is the type stored by a DeltaFIFO. It tells you what change
// happened, and the object's state after* that change.
//
// [*] Unless the change is a deletion, and then you'll get the final
// state of the object before it was deleted.
type Delta struct {
    Type DeltaType
    Object interface{}
}
``` 

换句话说，Delta 是一个事件！ 它是[动词（DeltaType）](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/delta_fifo.go#L623-L635)和有效负载（存储在 Object 字段中的对象）的组合。
或者，换句话说，它是一个队列，将 Add（someObject）形式的函数调用转换为假设的 AddEvent（ObjectAdded，someObject）函数的有效调用，以及 Update（someObject）形式的函数的调用有效调用假设的 AddEvent（ObjectUpdated，someObject）函数等。

好吧，还记得您需要与 Kubernetes 资源实例的初始列表一起设置 watches，并且该列表不包含 WatchEvents。 

因此，从非常高的层面来看，我们已经合并了 list 操作和 watch 操作的概念，并且根据 Delta 实例表达了它们，这些都在 DeltaFIFO 构造中结束。 然后，可以使用它将事件 JavaBean 样式分发给事件处理程序。

让我们看看我们是否可以将其放回到有限的背景中。 我们正在谈论一个队列，所以你应该能够添加一些东西。 它基本上是内部的 Delta 实例队列（通过 Deltas 实例）。 那么你如何建立一个 Delta 呢？
事实证明，[DeltaFIFO 为您构建了一个](https://github.com/kubernetes/kubernetes/blob/v1.9.0/staging/src/k8s.io/client-go/tools/cache/delta_fifo.go#L172-L179)：
```go
// Add inserts an item, and puts it in the queue. The item is only enqueued
// if it doesn't already exist in the set.
func (f *DeltaFIFO) Add(obj interface{}) error {
    f.lock.Lock()
    defer f.lock.Unlock()
    f.populated = true
    return f.queueActionLocked(Added, obj)
}

[snip]
// queueActionLocked appends to the delta list for the object, calling
// f.deltaCompressor if needed. Caller must lock first.
func (f *DeltaFIFO) queueActionLocked(actionType DeltaType, obj interface{}) error {
    id, err := f.KeyOf(obj)
    if err != nil {
        return KeyError{obj, err}
    }

    // If object is supposed to be deleted (last event is Deleted),
    // then we should ignore Sync events, because it would result in
    // recreation of this object.
    if actionType == Sync && f.willObjectBeDeletedLocked(id) {
        return nil
    }
    
    newDeltas := append(f.items[id], Delta{actionType, obj})
    newDeltas = dedupDeltas(newDeltas)
    if f.deltaCompressor != nil {
        newDeltas = f.deltaCompressor.Compress(newDeltas)
    }
    
    _, exists := f.items[id]
    if len(newDeltas) > 0 {
        if !exists {
            f.queue = append(f.queue, id)
        }
        f.items[id] = newDeltas
        f.cond.Broadcast()
    } else if exists {
        // The compression step removed all deltas, so
        // we need to remove this from our map (extra items
        // in the queue are ignored if they are not in the
        // map).
        delete(f.items, id)
    }
    return nil
}
```

因此，从 Java 建模的角度来看，我们必须认识到，我们在建模 DeltaFIFO 时使用的任何泛型类型实际上必须是两种通用类型：一种是 T，Kubernetes 资源的实际类型受到影响，两种是类似的东西 比如 Delta ，它将是队列内部实际存储的 “事件” 类型。

DeltaFIFO 的内部通过存储键的映射以及内部对象切片来建模集合。 由此我们可以推断出在这种队列中不允许重复，因此它设置了语义。

从 Java 的角度来看，这是一个重要的见解，因为我们可能会使用某种 Set 实现。 此外，在 Java 中，Objects 有一个 equals（Object）方法，这可能允许我们简化 KeyFunc 语义。
如下模型所示：
![](https://img-blog.csdn.net/20180822162535731?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl8zOTk2MTU1OQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)