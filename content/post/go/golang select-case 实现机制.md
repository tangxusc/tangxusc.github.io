---
title: "golang select-case实现机制"
date: 2019-11-15T09:15:59+08:00
draft: false
categories:
- golang
tags:
- golang
keywords:
- golang
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://hitzhangjie.github.io/jekyll/update/2018/05/19/golang-select-case%E5%AE%9E%E7%8E%B0%E6%9C%BA%E5%88%B6.html

在介绍 select-case 实现机制之前，最好先了解下 chan 操作规则，明白 goroutine 何时阻塞，又在什么时机被唤醒，这对后续理解 select-case 实现有帮助。所以接下来先介绍 chan 操作规则，然后再介绍 select-case 的实现。

<!--more-->

## 1.1 chan 操作规则 1

当一个 goroutine 要从一个 non-nil & non-closed chan 上接收数据时，goroutine 首先会去获取 chan 上的锁，然后执行如下操作直到某个条件被满足：

1）如果 chan 上的 value buffer 不空，这也意味着 chan 上的 recv goroutine queue 也一定是空的，该接收 goroutine 将从 value buffer 中 unshift 出一个 value。

这个时候，如果 send goroutine 队列不空的情况下，因为刚才 value buffer 中空出了一个位置，有位置可写，所以这个时候会从 send goroutine queue 中 unshift 出一个发送 goroutine 并让其恢复执行，让其执行把数据写入 chan 的操作，实际上是恢复该发送该 goroutine 执行，并把该发送 goroutine 要发送的数据 push 到 value buffer 中。

然后呢，该接收 goroutine 也拿到了数据了，就继续执行。

这种情景，channel 的接收操作称为 non-blocking 操作。

2）另一种情况，如果 value buffer 是空的，但是 send goroutine queue 不空，这种情况下，该 chan 一定是 unbufferred chan，不然 value buffer 肯定有数据嘛，这个时候接收 goroutine 将从 send goroutine queue 中 unshift 出一个发送 goroutine，并将该发送 goroutine 要发送的数据接收过来（两个 goroutine 一个有发送数据地址，一个有接收数据地址，拷贝过来就 ok），然后这个取出的发送 goroutine 将恢复执行，这个接收 goroutine 也可以继续执行。

这种情况下，chan 接收操作也是 non-blocking 操作。

3）另一种情况，如果 value buffer 和 send goroutine queue 都是空的，没有数据可接收，将把该接收 goroutine push 到 chan 的 recv goroutine queue，该接收 goroutine 将转入 blocking 状态，什么时候恢复期执行呢，要等到有一个 goroutine 尝试向 chan 发送数据的时候了。

这种场景下，chan 接收操作是 blocking 操作。

## 1.2 chan 操作规则 2

当一个 goroutine 常识向一个 non-nil & non-closed chan 发送数据的时候，该 goroutine 将先尝试获取 chan 上的锁，然后执行如下操作直到满足其中一种情况。

1）如果 chan 的 recv goroutine queue 不空，这种情况下，value buffer 一定是空的。发送 goroutine 将从 recv goroutine queue 中 unshift 出一个 recv goroutine，然后直接将自己要发送的数据拷贝到该 recv goroutine 的接收地址处，然后恢复该 recv goroutine 的运行，当前发送 goroutine 也继续执行。这种情况下，chan send 操作是 non-blocking 操作。

2）如果 chan 的 recv goroutine queue 是空的，并且 value buffer 不满，这种情况下，send goroutine queue 一定是空的，因为 value buffer 不满发送 goroutine 可以发送完成不可能会阻塞。该发送 goroutine 将要发送的数据 push 到 value buffer 中然后继续执行。这种情况下，chan send 操作是 non-blocking 操作。

3）如果 chan 的 recv goroutine queue 是空的，并且 value buffer 是满的，发送 goroutine 将被 push 到 send goroutine queue 中进入阻塞状态。等到有其他 goroutine 尝试从 chan 接收数据的时候才能将其唤醒恢复执行。这种情况下，chan send 操作是 blocking 操作。

## 1.3 chan 操作规则 3

当一个 goroutine 尝试 close 一个 non-nil & non-closed chan 的时候，close 操作将依次执行如下操作。

1）如果 chan 的 recv goroutine queue 不空，这种情况下 value buffer 一定是空的，因为如果 value buffer 如果不空，一定会继续 unshift recv goroutine queue 中的 goroutine 接收数据，直到 value buffer 为空（这里可以看下 chan send 操作，chan send 写入数据之前，一定会从 recv goroutine queue 中 unshift 出一个 recv goroutine）。recv goroutine queue 里面所有的 goroutine 将一个个 unshift 出来并返回一个 val=0 值和 sentBeforeClosed=false。

2）如果 chan 的 send goroutine queue 不空，所有的 goroutine 将被依次取出并生成一个 panic for closing a close chan。在这 close 之前发送到 chan 的数据仍然在 chan 的 value buffer 中存着。

## 1.4 chan 操作规则 4

一旦 chan 被关闭了，chan recv 操作就永远也不会阻塞，chan 的 value buffer 中在 close 之前写入的数据仍然存在。一旦 value buffer 中 close 之前写入的数据都被取出之后，后续的接收操作将会返回 val=0 和 sentBeforeClosed=true。

理解这里的 goroutine 的 blocking、non-blocking 操作对于理解针对 chan 的 select-case 操作是很有帮助的。下面介绍 select-case 实现机制。

select-case 中假如没有 default 分支的话，一定要等到某个 case 分支满足条件然后将对应的 goroutine 唤醒恢复执行才可以继续执行，否则代码就会阻塞在这里，即将当前 goroutine push 到各个 case 分支对应的 ch 的 recv 或者 send goroutine queue 中，对同一个 chan 也可能将当前 goroutine 同时 push 到 recv、send goroutine queue 这两个队列中。

不管是普通的 chan send、recv 操作，还是 select chan send、recv 操作，因为 chan 操作阻塞的 goroutine 都是依靠其他 goroutine 对 chan 的 send、recv 操作来唤醒的。前面我们已经讲过了 goroutine 被唤醒的时机，这里还要再细分一下。

chan 的 send、recv goroutine queue 中存储的其实是一个结构体指针 * sudog，成员 gp *g 指向对应的 goroutine，elem unsafe.Pointer 指向待读写的变量地址，c *hchan 指向 goroutine 阻塞在哪个 chan 上，isSelect 为 true 表示 select chan send、recv，反之表示 chan send、recv。g.selectDone 表示 select 操作是否处理完成，即是否有某个 case 分支已经成立。

## 2.1 chan 操作阻塞的 goroutine 唤醒时执行逻辑

下面我们先描述下 chan 上某个 goroutine 被唤醒时的处理逻辑，假如现在有个 goroutine 因为 select chan 操作阻塞在了 ch1、ch2 上，那么会创建对应的 sudog 对象，并将对应的指针 * sudog push 到各个 case 分支对应的 ch1、ch2 上的 send、recv goroutine queue 中，等待其他协程执行 (select) chan send、recv 操作时将其唤醒： 1）源码文件 **chan.go**，假如现在有另外一个 goroutine 对 ch1 进行了操作，然后对 ch1 的 goroutine 执行 unshift 操作取出一个阻塞的 goroutine，在 unshift 时要执行方法 **func (q *waitq) dequeue() *sudog**，这个方法从 ch1 的等待队列中返回一个阻塞的 goroutine。

```go
func (q *waitq) dequeue() *sudog {
	for {
		sgp := q.first
		if sgp == nil {
			return nil
		}
		y := sgp.next
		if y == nil {
			q.first = nil
			q.last = nil
		} else {
			y.prev = nil
			q.first = y
			sgp.next = nil // mark as removed (see dequeueSudog)
		}

		// if a goroutine was put on this queue because of a
		// select, there is a small window between the goroutine
		// being woken up by a different case and it grabbing the
		// channel locks. Once it has the lock
		// it removes itself from the queue, so we won't see it after that.
		// We use a flag in the G struct to tell us when someone
		// else has won the race to signal this goroutine but the goroutine
		// hasn't removed itself from the queue yet.
		if sgp.isSelect {
			if !atomic.Cas(&sgp.g.selectDone, 0, 1) {
				continue
			}
		}
	
		return sgp
	}
}
```

假如队首元素就是之前阻塞的 goroutine，那么检测到其 sgp.isSelect=true，就知道这是一个因为 select chan send、recv 阻塞的 goroutine，然后通过 CAS 操作将 sgp.g.selectDone 设为 true 标识当前 goroutine 的 select 操作已经处理完成，之后就可以将该 goroutine 返回用于从 value buffer 读或者向 value buffer 写数据了，或者直接与唤醒它的 goroutine 交换数据，然后该阻塞的 goroutine 就可以恢复执行了。

这里将 sgp.g.selectDone 设为 true，相当于传达了该 sgp.g 已经从刚才阻塞它的 select-case 块中退出了，对应的 select-case 块可以作废了。有必要提提一下为什么要把这里的 sgp.g.selectDone 设为 true 呢？直接将该 goroutine 出队不就完了吗？不行！考虑以下对 chan 的操作 dequeue 是需要先拿到 chan 上的 lock 的，但是在尝试 lock chan 之前有可能同时有多个 case 分支对应的 chan 准备就绪。看个示例代码：

```go
// g1
go func() {
  ch1 <- 1
}()

// g2
go func() {
  ch2 <- 2
}

select {
  case <- ch1:
    doSomething()
  case <- ch2:
    doSomething()
}
```

协程 g1 在 chan.chansend 方法中执行了一般，准备 lock ch1，协程 g2 也执行了一半，也准备 lock ch2; 协程 g1 成功 lock ch1 执行 dequeue 操作，协程 g2 页成功 lock ch2 执行 deq ueue 操作； 因为同一个 select-case 块中只能有一个 case 分支允许激活，所以在协程 g 里面加了个成员 g.selectDone 来标识该协程对应的 select-case 是否已经成功执行结束（一个协程在某个时刻只可能有一个 select-case 块在处理，要么阻塞没执行完，要么立即执行完），因此 dequeue 时要通过 CAS 操作来更新 g.selectDone 的值，更新成功者完成出队操作激活 case 分支，CAS 失败的则认为该 select-case 已经有其他分支被激活，当前 case 分支作废，select-case 结束。

这里的 CAS 操作也就是说的多个分支满足条件时，golang 会随机选择一个分支执行的道理。

## 2.2 select-case 块 golang 是如何执行处理的

源文件 **select.go** 中方法 **selectgo(sel *hselect)** ，实现了对 select-case 块的处理逻辑，但是由于代码篇幅较长，这里不再复制粘贴代码，感兴趣的可以自己查看，这里只简要描述下其执行流程。

**selectgo 逻辑处理简述：**

*   预处理部分 对各个 case 分支按照 ch 地址排序，保证后续按序加锁，避免产生死锁问题；
*   pass 1 部分处理各个 case 分支的判断逻辑，依次检查各个 case 分支是否有立即可满足 ch 读写操作的。如果当前分支有则立即执行 ch 读写并回，select 处理结束；没有则继续处理下一分支；如果所有分支均不满足继续执行以下流程。
*   pass 2 没有一个 case 分支上 chan 操作立即可就绪，当前 goroutine 需要阻塞，遍历所有的 case 分支，分别构建 goroutine 对应的 sudog 并 push 到 case 分支对应 chan 的对应 goroutine queue 中。然后 gopark 挂起当前 goroutine，等待某个分支上 chan 操作完成来唤醒当前 goroutine。怎么被唤醒呢？前面提到了 chan.waitq.dequeue() 方法中通过 CAS 将 sudog.g.selectDone 设为 1 之后将该 sudog 返回并恢复执行，其实也就是借助这个操作来唤醒。
*   pass 3 整个 select-case 块已经结束使命，之前阻塞的 goroutine 已被唤醒，其他 case 分支没什么作用了，需要废弃掉，pass 3 部分会将该 goroutine 从之前阻塞它的 select-case 块中各 case 分支对应的 chan recv、send goroutine queue 中移除，通过方法 chan.waitq.dequeueSudog(sgp *sudog) 来从队列中移除，队列是双向链表，通过 sudog.prev 和 sudog.next 删除 sudog 时间复杂度为 O(1)。

本文简要描述了 golang 中 select-case 的实现逻辑，介绍了 goroutine 与 chan 操作之间的协作关系。之前 ZMQ 作者 Martin Sustrik 仿着 golang 写过一个面向 c 的库，libmill，实际实现思路差不多，感兴趣的也可以翻翻看，[libmill 源码分析](https://hitzhangjie.github.io/2017/12/03/go%E9%A3%8E%E6%A0%BC%E5%8D%8F%E7%A8%8B%E5%BA%93libmill%E4%B9%8B%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90.html)。

