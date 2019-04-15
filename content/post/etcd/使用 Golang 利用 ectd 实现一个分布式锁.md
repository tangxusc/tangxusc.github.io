---
title: "使用 Golang 利用 ectd 实现一个分布式锁"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- golang
- etcd
- 分布式锁
tags:
- golang
- etcd
- 分布式锁
keywords:
- golang
- etcd
- 分布式锁
---

`etcd`是随着`CoreOS`项目一起成长起来的，随着 Golang 和 CoreOS 等项目在开源社区日益火热， `etcd`作为一个高可用、强一致性的分布式 Key-Value 存储系统被越来越多的开发人员关注和使用。
<!--more-->
> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://www.cnblogs.com/diegodu/p/5603678.html

  本文 [http://blog.codeg.cn/post/blog/2016-02-24-distrubute-lock-over-etcd/](http://blog.codeg.cn/post/blog/2016-02-24-distrubute-lock-over-etcd/) 是作者 [zieckey](http://blog.codeg.cn/) 在研究和学习相关内容时所做的笔记，欢迎广大朋友指正和交流！ 版权所有，欢迎转载和分享，但请保留此段声明。

`etcd`是随着`CoreOS`项目一起成长起来的，随着 Golang 和 CoreOS 等项目在开源社区日益火热， `etcd`作为一个高可用、强一致性的分布式 Key-Value 存储系统被越来越多的开发人员关注和使用。

这篇[文章](http://www.infoq.com/cn/articles/etcd-interpretation-application-scenario-implement-principle)全方位介绍了 etcd 的应用场景，这里简单摘要如下：

*   服务发现（Service Discovery）
*   消息发布与订阅
*   负载均衡
*   分布式通知与协调
*   分布式锁
*   分布式队列
*   集群监控与 Leader 竞选
*   为什么用 etcd 而不用 ZooKeeper

本文重点介绍如何利用`ectd`实现一个分布式锁。 锁的概念大家都熟悉，当我们希望某一事件在同一时间点只有一个线程 (goroutine) 在做，或者某一个资源在同一时间点只有一个服务能访问，这个时候我们就需要用到锁。 例如我们要实现一个分布式的 id 生成器，多台服务器之间的协调就非常麻烦。分布式锁就正好派上用场。

其基本实现原理为：

1.  在 ectd 系统里创建一个 key
2.  如果创建失败，key 存在，则监听该 key 的变化事件，直到该 key 被删除，回到 1
3.  如果创建成功，则认为我获得了锁

具体代码如下：

```
package etcdsync

import (
	"fmt"
	"io"
	"os"
	"sync"
	"time"

	"github.com/coreos/etcd/client"
	"github.com/coreos/etcd/Godeps/_workspace/src/golang.org/x/net/context"
)

const (
	defaultTTL = 60
	defaultTry = 3
	deleteAction = "delete"
	expireAction = "expire"
)

// A Mutex is a mutual exclusion lock which is distributed across a cluster.
type Mutex struct {
	key    string
	id     string // The identity of the caller
	client client.Client
	kapi   client.KeysAPI
	ctx    context.Context
	ttl    time.Duration
	mutex  *sync.Mutex
	logger io.Writer
}

// New creates a Mutex with the given key which must be the same
// across the cluster nodes.
// machines are the ectd cluster addresses
func New(key string, ttl int, machines []string) *Mutex {
	cfg := client.Config{
		Endpoints:               machines,
		Transport:               client.DefaultTransport,
		HeaderTimeoutPerRequest: time.Second,
	}

	c, err := client.New(cfg)
	if err != nil {
		return nil
	}

	hostname, err := os.Hostname()
	if err != nil {
		return nil
	}

	if len(key) == 0 || len(machines) == 0 {
		return nil
	}

	if key[0] != '/' {
		key = "/" + key
	}

	if ttl < 1 {
		ttl = defaultTTL
	}

	return &Mutex{
		key:    key,
		id:     fmt.Sprintf("%v-%v-%v", hostname, os.Getpid(), time.Now().Format("20060102-15:04:05.999999999")),
		client: c,
		kapi:   client.NewKeysAPI(c),
		ctx: context.TODO(),
		ttl: time.Second * time.Duration(ttl),
		mutex:  new(sync.Mutex),
	}
}

// Lock locks m.
// If the lock is already in use, the calling goroutine
// blocks until the mutex is available.
func (m *Mutex) Lock() (err error) {
	m.mutex.Lock()
	for try := 1; try <= defaultTry; try++ {
		if m.lock() == nil {
			return nil
		}

		m.debug("Lock node %v ERROR %v", m.key, err)
		if try < defaultTry {
			m.debug("Try to lock node %v again", m.key, err)
		}
	}
	return err
}

func (m *Mutex) lock() (err error) {
	m.debug("Trying to create a node : key=%v", m.key)
	setOptions := &client.SetOptions{
		PrevExist:client.PrevNoExist,
		TTL:      m.ttl,
	}
	resp, err := m.kapi.Set(m.ctx, m.key, m.id, setOptions)
	if err == nil {
		m.debug("Create node %v OK [%q]", m.key, resp)
		return nil
	}
	m.debug("Create node %v failed [%v]", m.key, err)
	e, ok := err.(client.Error)
	if !ok {
		return err
	}

	if e.Code != client.ErrorCodeNodeExist {
		return err
	}

	// Get the already node's value.
	resp, err = m.kapi.Get(m.ctx, m.key, nil)
	if err != nil {
		return err
	}
	m.debug("Get node %v OK", m.key)
	watcherOptions := &client.WatcherOptions{
		AfterIndex : resp.Index,
		Recursive:false,
	}
	watcher := m.kapi.Watcher(m.key, watcherOptions)
	for {
		m.debug("Watching %v ...", m.key)
		resp, err = watcher.Next(m.ctx)
		if err != nil {
			return err
		}

		m.debug("Received an event : %q", resp)
		if resp.Action == deleteAction || resp.Action == expireAction {
			return nil
		}
	}

}

// Unlock unlocks m.
// It is a run-time error if m is not locked on entry to Unlock.
//
// A locked Mutex is not associated with a particular goroutine.
// It is allowed for one goroutine to lock a Mutex and then
// arrange for another goroutine to unlock it.
func (m *Mutex) Unlock() (err error) {
	defer m.mutex.Unlock()
	for i := 1; i <= defaultTry; i++ {
		var resp *client.Response
		resp, err = m.kapi.Delete(m.ctx, m.key, nil)
		if err == nil {
			m.debug("Delete %v OK", m.key)
			return nil
		}
		m.debug("Delete %v falied: %q", m.key, resp)
		e, ok := err.(client.Error)
		if ok && e.Code == client.ErrorCodeKeyNotFound {
			return nil
		}
	}
	return err
}

func (m *Mutex) debug(format string, v ...interface{}) {
	if m.logger != nil {
		m.logger.Write([]byte(m.id))
		m.logger.Write([]byte(" "))
		m.logger.Write([]byte(fmt.Sprintf(format, v...)))
		m.logger.Write([]byte("\n"))
	}
}

func (m *Mutex) SetDebugLogger(w io.Writer) {
	m.logger = w
}

```

其实类似的实现有很多，但目前都已经过时，使用的都是被官方标记为`deprecated`的项目。且大部分接口都不如上述代码简单。 使用上，跟 Golang 官方 sync 包的 Mutex 接口非常类似，先`New()`，然后调用`Lock()`，使用完后调用`Unlock()`，就三个接口，就是这么简单。示例代码如下：

```
package main

import (
	"github.com/zieckey/etcdsync"
	"log"
)

func main() {
	//etcdsync.SetDebug(true)
	log.SetFlags(log.Ldate|log.Ltime|log.Lshortfile)
	m := etcdsync.New("/etcdsync", "123", []string{"http://127.0.0.1:2379"})
	if m == nil {
		log.Printf("etcdsync.NewMutex failed")
	}
	err := m.Lock()
	if err != nil {
		log.Printf("etcdsync.Lock failed")
	} else {
		log.Printf("etcdsync.Lock OK")
	}

	log.Printf("Get the lock. Do something here.")

	err = m.Unlock()
	if err != nil {
		log.Printf("etcdsync.Unlock failed")
	} else {
		log.Printf("etcdsync.Unlock OK")
	}
}

```

## 参考

1.  [etcdsync 项目地址](https://github.com/zieckey/etcdsync)
2.  [ectd 项目官方地址](https://github.com/coreos/etcd)