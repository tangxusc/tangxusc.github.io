---
title: "Etcd Lock详解"
date: 2019-05-07T14:38:42+08:00
categories:
- etcd
tags:
- etcd
- lock
keywords:
- lock
- etcd
- mutex
#thumbnailImage: //example.com/image.jpg
---

分布式情况下最终都会面临一个资源抢占的问题,解决问题的方法为抽象一个分布式锁,持有锁则可以操作资源,本文使用etcd实现一个分布式锁

<!--more-->

## 简介

在正式使用之前,先简单介绍一下etcd的`clientv3`,etcd的client和服务器通信在`v3`版本为grpc,所以我们在使用时实际上就是使用grpc和服务器通信.

etcd的github地址为: https://github.com/etcd-io/etcd

在github中源代码中存在两个目录:

```shell
$ tree -L 1
├── alarm
.....
├── client
├── clientv3
.....
```

其中 `clientv3`为我们需要使用的client,本文的主角就是`clientv3/concurrency`

## 下载依赖

在明确我们使用的包后,我们直接依赖clientv3包到我们的工程中.

```shell
go get github.com/etcd-io/etcd/clientv3
```

> 如果需要梯子,请参考: [终端中设置代理](https://tangxusc.github.io/blog/2019/03/%E8%AE%BE%E7%BD%AE%E7%BB%88%E7%AB%AF%E4%BD%BF%E7%94%A8%E4%BB%A3%E7%90%86%E7%9A%84%E5%87%A0%E7%A7%8D%E6%96%B9%E6%B3%95/)

## 连接到etcd

在很多环境中我们启动etcd都是通过配置tls方式进行的,所以在连接etcd的时候需要使用tls的方式连接(可是百度上很多文章居然都没写.),具体的连接方式如下:

```go
	tlsInfo := transport.TLSInfo{
		CertFile:      "etcd-v3.3.12-linux-amd64/etcd.pem",
		KeyFile:       "etcd-v3.3.12-linux-amd64/etcd-key.pem",
		TrustedCAFile: "etcd-v3.3.12-linux-amd64/ca.pem",
	}
	tlsConfig, err := tlsInfo.ClientConfig()
	if err != nil {
		log.Fatal(err)
	}
	config := clientv3.Config{
		Endpoints: []string{"127.0.0.1:12379"},#此处为etcd server监听地址
		TLS:       tlsConfig,
	}
	client, e := clientv3.New(config)
	if e != nil {
		log.Fatal(e.Error())
	}
	defer client.Close()
```

## 使用Mutex获取锁

在使用证书连接到etcd的server后,我们使用`clientv3/concurrency`包中的Mutex进行分布式锁

```go
	# 生成一个30s超时的上下文
	timeout, cancelFunc := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancelFunc()
	# 获取租约
	response, e := client.Grant(timeout, 30)
	if e != nil {
		log.Fatal(e.Error())
	}
	# 通过租约创建session
	session, e := concurrency.NewSession(client, concurrency.WithLease(response.ID))
	if e != nil {
		log.Fatal(e.Error())
	}
	defer session.Close()
	# 通过session和锁前缀
	mutex := concurrency.NewMutex(session, "/lock")
	e = mutex.Lock(timeout)
	if e != nil {
		log.Fatal(e.Error())
	}

	# 业务逻辑

	# 释放锁
	defer mutex.Unlock(timeout)
```

整体流程还是相对复杂的,接下来我们将一点一点解析:

### 1.生成30s超时的上下文(context)

锁的竞争是有时间的,不可能一直竞争下去,设定一个30s的超时时间,是让`mutex.Lock()`的时候有一个获取锁的时间,在此时间内,如果没有获取到锁则应该重试或者提示失败.

### 2.`client.Grant`获取租约

租约设置了一个和上下文一样的超时时间,保证租约有足够的时间

### 3.根据租约创建一个session回话,维护租约的过期时间

在client中抽象出了一个session对象来持续保持租约不过期,具体源码为:

```go
//会话表示在客户端的生存期内保持活动的租约。
//应用程序可能会使用会话来解释活动性。
type Session struct {
	client *v3.Client
	opts   *sessionOptions
	id     v3.LeaseID

	cancel context.CancelFunc
	donec  <-chan struct{}
}

// NewSession gets the leased session for a client.
func NewSession(client *v3.Client, opts ...SessionOption) (*Session, error) {
	ops := &sessionOptions{ttl: defaultSessionTTL, ctx: client.Ctx()}
	for _, opt := range opts {
		opt(ops)
	}

	id := ops.leaseID
	if id == v3.NoLease {
		resp, err := client.Grant(ops.ctx, int64(ops.ttl))
		if err != nil {
			return nil, err
		}
		id = v3.LeaseID(resp.ID)
	}

	ctx, cancel := context.WithCancel(ops.ctx)
	keepAlive, err := client.KeepAlive(ctx, id)
	if err != nil || keepAlive == nil {
		cancel()
		return nil, err
	}

	donec := make(chan struct{})
	s := &Session{client: client, opts: ops, id: id, cancel: cancel, donec: donec}
	//在客户端错误或取消上下文之前保持租约的活动状态
	// keep the lease alive until client error or cancelled context
	go func() {
		defer close(donec)
		for range keepAlive {
            //在保持活动频道关闭前接收信息
			// eat messages until keep alive channel closes
		}
	}()

	return s, nil
}
```

其实就是在newSession中启动一个协程不断读取`keepAlive`这个channel的数据

### 4.`concurrency.NewMutex`创建一个锁,调用lock开始竞争锁

```go
// Lock locks the mutex with a cancelable context. If the context is canceled
// while trying to acquire the lock, the mutex tries to clean its stale lock entry.
func (m *Mutex) Lock(ctx context.Context) error {
	s := m.s
	client := m.s.Client()

    //生成锁的key
	m.myKey = fmt.Sprintf("%s%x", m.pfx, s.Lease())
    //使用事务机制
    //比较key的revision为0(0标示没有key)
	cmp := v3.Compare(v3.CreateRevision(m.myKey), "=", 0)
    //则put key,并设置租约
	// put self in lock waiters via myKey; oldest waiter holds lock
	put := v3.OpPut(m.myKey, "", v3.WithLease(s.Lease()))
    //否则 获取这个key,重用租约中的锁(这里主要目的是在于重入)
    //通过第二次获取锁,判断锁是否存在来支持重入
    //所以只要租约一致,那么是可以重入的.
	// reuse key in case this session already holds the lock
	get := v3.OpGet(m.myKey)
    //通过前缀获取最先创建的key
	// fetch current holder to complete uncontended path with only one RPC
	getOwner := v3.OpGet(m.pfx, v3.WithFirstCreate()...)
	resp, err := client.Txn(ctx).If(cmp).Then(put, getOwner).Else(get, getOwner).Commit()
	if err != nil {
		return err
	}
    //获取到自身的revision
	m.myRev = resp.Header.Revision
	if !resp.Succeeded {
		m.myRev = resp.Responses[0].GetResponseRange().Kvs[0].CreateRevision
	}
    // 通过对比自身的revision和最先创建的key的revision得出谁获得了锁
    // 例如 自身revision:5,最先创建的key createRevision:3  那么不获得锁,进入waitDeletes
    //     自身revision:5,最先创建的key createRevision:5  那么获得锁
    
	// if no key on prefix / the minimum rev is key, already hold the lock
	ownerKey := resp.Responses[1].GetResponseRange().Kvs
	if len(ownerKey) == 0 || ownerKey[0].CreateRevision == m.myRev {
		m.hdr = resp.Header
		return nil
	}
	// 等待其他程序释放锁,并删除其他revisions
	// wait for deletion revisions prior to myKey
	hdr, werr := waitDeletes(ctx, client, m.pfx, m.myRev-1)
	// release lock key if wait failed
	if werr != nil {
		m.Unlock(client.Ctx())
	} else {
		m.hdr = hdr
	}
	return werr
}
// 等待持有锁的key删除,其他所有比当前revision大的,比最后创建小的revision的键进入等待
// waitDeletes efficiently waits until all keys matching the prefix and no greater
// than the create revision.
func waitDeletes(ctx context.Context, client *v3.Client, pfx string, maxCreateRev int64) (*pb.ResponseHeader, error) {
	getOpts := append(v3.WithLastCreate(), v3.WithMaxCreateRev(maxCreateRev))
	for {
        //获取到所有的比当前revision大的,比最后创建小的revision的键
		resp, err := client.Get(ctx, pfx, getOpts...)
		if err != nil {
			return nil, err
		}
		if len(resp.Kvs) == 0 {
			return resp.Header, nil
		}
		lastKey := string(resp.Kvs[0].Key)
        //监听删除事件
		if err = waitDelete(ctx, client, lastKey, resp.Header.Revision); err != nil {
			return nil, err
		}
	}
}
//从revision开始监听删除事件,因为revision存在,所以也避免了ABA问题
func waitDelete(ctx context.Context, client *v3.Client, key string, rev int64) error {
	cctx, cancel := context.WithCancel(ctx)
	defer cancel()

	var wr v3.WatchResponse
	wch := client.Watch(cctx, key, v3.WithRev(rev))
	for wr = range wch {
		for _, ev := range wr.Events {
            //遇到删除事件才返回
			if ev.Type == mvccpb.DELETE {
				return nil
			}
		}
	}
	if err := wr.Err(); err != nil {
		return err
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	return fmt.Errorf("lost watcher waiting for delete")
}

```

> CreateRevision: 创建时的revision
>
> Header.Revision: etcd server现在的revision
>
> ABA问题: [CAS和ABA问题](https://www.cnblogs.com/exceptioneye/p/5373498.html)

### 5.释放锁

这里释放锁,比较简单,就是删除此key

```go
//释放锁
func (m *Mutex) Unlock(ctx context.Context) error {
	client := m.s.Client()
	if _, err := client.Delete(ctx, m.myKey); err != nil {
		return err
	}
	m.myKey = "\x00"
	m.myRev = -1
	return nil
}
```

## revision

刚才说了那么多revision,这里我们需要详细的了解一下etcd中的mvcc多版本机制

那么我们先来明确几个概念:

main ID:在etcd中每个事务的唯一id,全局递增不重复.

sub ID: 在事务中的连续多个修改操作会从0开始编号,这个编号就是sub ID

revision: 由(mainID,subID)组成的唯一标识

所以现在我们的revision就是这么来的啦...





