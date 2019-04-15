---
title: "Controller manager高可用实现方式"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- k8s
- Controller manager
tags:
- k8s
- Controller manager
keywords:
- k8s
- Controller manager
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://www.colabug.com/2801661.html

这不是一系列入门级别的文章，也不是按部就班而来的，而是我看到哪里，发现有些代码写的精妙的地方，都值得我们学习下，顺手记录下来，一方面是让自己将来可以有迹可循，另外对大家应该也会有所帮助。而且记录本身成本并不是很高。

高可用部署情况下，需要部署多个 controller manager （以下简称 cm ），每个 cm 需要 `--leader-elect=true`
启动参数，即告知 cm 以高可用方式启动，谁要想进行真正的工作，必须先抢到锁，被选举为 leader 才行，而抢不到所得只能待机，在 leader 因为异常终止的时候，由剩余的其余节点再次获得锁。

<!--more-->

关于分布式锁的实现很多，可以自己从零开始制造。当然更简单的是基于现有中间件，比如有基于 Redis 或数据库的实现方式，最近 Zookeeper/ETCD 也提供了相关功能。但 K8s 的实现并没有使用这些方式，而是另辟蹊径使用了资源锁的概念，简单来说就是通过创建 K8s 的资源（当前的实现中实现了 ConfigMap 和 Endpoint 两种类型的资源）来维护锁的状态。

分布式锁一般实现原理就是大家先去抢锁，抢到的人成为 leader ，然后 leader 会定期更新锁的状态，声明自己的活动状态，不让其他人把锁抢走。K8s 的资源锁也类似，抢到锁的节点会将自己的标记（目前是 hostname）设为锁的持有者，其他人则需要通过对比锁的更新时间和持有者来判断自己是否能成为新的 leader ，而 leader 则可以通过更新 `RenewTime`
来确保持续保有该锁。

大概看了下 K8s 的实现，老实说其实现方式并不算高雅，但是却给我们开拓了一种思路：K8s 里的 resource 是万能的，不要以为 Endpoint 只是 Endpoint 。不过反过来有时候也挺让人费解的，刚了解的时候容易摸不着头脑，也不是好事。而且 scheduler 和 cm 都采用了资源锁，但是实现起来却不尽相同，也值得吐槽下。不管怎么说，这个实现算是挺有意思的实现，值得我们深入了解下。

我们首先来看一下 cm 启动的时候，是如何去 [初始化](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9jbWQva3ViZS1jb250cm9sbGVyLW1hbmFnZXIvYXBwL2NvbnRyb2xsZXJtYW5hZ2VyLmdvI0wxODQtTDIwOA==)
抢锁的。启动的时候，如果指定了 `--leader-elect=true`
参数的话，则会进入下面的代码，首先获取自己的资源标志（这里是 hostname 加一串随机数字）。

```shell
id, err := os.Hostname()

// add a uniquifier so that two processes on the same host don't accidentally both become active
id = id + "_" + string(uuid.NewUUID())
rl, err := resourcelock.New(c.Generic.ComponentConfig.GenericComponent.LeaderElection.ResourceLock,
  "kube-system",                                 // 该资源所在 Namespace
  "kube-controller-manager",                     // 资源名称
  c.Generic.LeaderElectionClient.CoreV1(),
  resourcelock.ResourceLockConfig{
​      Identity:      id,                         // 锁持有者标志
​      EventRecorder: c.Generic.EventRecorder,
  })
}
```

上面创建资源锁的代码说明请参考文中中文注释。

之后，在下面的代码中，资源锁，即上面的 rl（resource lock） 变量，被用于进行 leader 选举。具体的说明也嵌入在了下面的代码中。

```
leaderelection.RunOrDie(leaderelection.LeaderElectionConfig{
  Lock:          rl,
  // 下面 3 个参数是一些重时间，租赁期间等的设置，不是很重要
  LeaseDuration: c.Generic.ComponentConfig.GenericComponent.LeaderElection.LeaseDuration.Duration,
  RenewDeadline: c.Generic.ComponentConfig.GenericComponent.LeaderElection.RenewDeadline.Duration,
  RetryPeriod:   c.Generic.ComponentConfig.GenericComponent.LeaderElection.RetryPeriod.Duration,
  Callbacks: leaderelection.LeaderCallbacks{
      OnStartedLeading: run,                   // cm 的主要工作函数
      OnStoppedLeading: func() {
          glog.Fatalf("leaderelection lost")
      },
  },
})
```

我们再来看看 [LeaderElectionConfig](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL2xlYWRlcmVsZWN0aW9uLmdvI0w4NS1MMTAz)
的内容，说明见注释（其实就是将代码的英文翻译过来而已）

```
type LeaderElectionConfig struct {
  // 资源锁的实现对象
  Lock rl.Interface

  // 是非 leader 在获取锁之前需要检查 leader 过期的时间
  LeaseDuration time.Duration

  // 当前 leader 尝试更新锁状态的期限。
  RenewDeadline time.Duration

  // 抢锁时尝试间隔
  RetryPeriod time.Duration

  // 锁状态发生变化的时候，需要进行处理的一组回调函数
  Callbacks LeaderCallbacks
}
```

这里的 [Callbacks](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL2xlYWRlcmVsZWN0aW9uLmdvI0wxMTAtTDExOQ==)
具体如下：

```
Callbacks: leaderelection.LeaderCallbacks{
  OnStartedLeading: run,
  OnStoppedLeading: func() {
      glog.Fatalf("leaderelection lost")
  },
},
```

也就是说，在获取锁（成为 leader， `OnStartedLeading`
）之后，将会执行 [`run`](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9jbWQva3ViZS1jb250cm9sbGVyLW1hbmFnZXIvYXBwL2NvbnRyb2xsZXJtYW5hZ2VyLmdvI0wxMzc=) 
方法，在失去锁（ `OnStoppedLeading`
）之后打印错误消息后退出。 `run`
方法是 cm 的主要方法，和抢锁选主流程没什么关系，这里就不介绍了。

下面的 [LeaderElectionRecord](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL3Jlc291cmNlbG9jay9pbnRlcmZhY2UuZ28jTDM3LUw0Mw==)
结构，保存了锁的信息，包括持有者（的 hostname），获取时间，更新时间，leader 切换次数等（ `LeaseDurationSeconds`
虽然定义了，但是并没有使用的感觉）。

这个结构可以说是资源锁中最重要的信息了，大家一定先混个脸熟，多念几遍 struct 的名字。

```
// LeaderElectionRecord is the record that is stored in the leader election annotation.
// This information should be used for observational purposes only and could be replaced
// with a random string (e.g. UUID) with only slight modification of this code.
type LeaderElectionRecord struct {
  HolderIdentity       string      `json:"holderIdentity"`
  LeaseDurationSeconds int         `json:"leaseDurationSeconds"`
  AcquireTime          metav1.Time `json:"acquireTime"`
  RenewTime            metav1.Time `json:"renewTime"`
  LeaderTransitions    int         `json:"leaderTransitions"`
}
```

这个锁信息，就是存在 K8s 的 ConfigMap 或者 Endpoint 里面的，当然，存哪里可能大家已经想到了，只能存 annotation 里面，该 annotation 的 key 就是 [`control-plane.alpha.kubernetes.io/leader`](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL3Jlc291cmNlbG9jay9pbnRlcmZhY2UuZ28jTDI4) 
。

到这里总结一下就是：LeaderElectionRecord 用于保存锁的信息，但是这一信息会以 annotation 的方式，保存到 k8s 的 ConfigMap 或者 Endpoint 等资源里面。

下面我们来看一下资源锁的实现。

[资源锁接口](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL3Jlc291cmNlbG9jay9pbnRlcmZhY2UuZ28jTDU3LUw3Ng==)
的定义如下：

```
type Interface interface {
  Get() (*LeaderElectionRecord, error)
  Create(ler LeaderElectionRecord) error
  Update(ler LeaderElectionRecord) error
  RecordEvent(string)
  Identity() string
  Describe() string
}
```

基本实现了 CRUD 几个方法，当然这里没有 D ，即 Delete，因为也没必要 Delete， 下一次抢锁的时候，抢到的 Leader 直接 Update 就可以了。

关键的方法我们看前 3 个就够了： Get 用于获取锁的最新信息，Update 用于更新，Create 用于创建资源锁对象，估计对大多数集群来说，只有第一次的时候才会调用 Create 创建这个对象。RecordEvent 也可以关注下，这个 event 属于锁资源，里面会记录 leader 切换等事件。

这里我们以 [Endpoint](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL3Jlc291cmNlbG9jay9lbmRwb2ludHNsb2NrLmdvI0wzOQ==)
为例（这也是默认的资源锁类型，该参数可以通过 `leader-elect-resource-lock`
来设置），来看看资源锁的具体实现。

下面的代码省略了对 error 的检查，你懂得。

```
// Get returns the election record from a Endpoints Annotation
func (el *EndpointsLock) Get() (*LeaderElectionRecord, error) {
  var record LeaderElectionRecord
  var err error
  // el.e 就是一个正经的 Endpoint 资源对象。
  el.e, err = el.Client.Endpoints(el.EndpointsMeta.Namespace).Get(el.EndpointsMeta.Name, metav1.GetOptions{})

  // 去获取 control-plane.alpha.kubernetes.io/leader annotation。
  if recordBytes, found := el.e.Annotations[LeaderElectionRecordAnnotationKey]; found {
​      if err := json.Unmarshal([]byte(recordBytes), &record); err != nil {
​          return nil, err
​      }
  }
  return &record, nil
}
```

[Create](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL3Jlc291cmNlbG9jay9lbmRwb2ludHNsb2NrLmdvI0w1OA==)
也很简单，就是一个普通的 Endpoint 对象，加上锁专用的 annotation ：

```
el.e, err = el.Client.Endpoints(el.EndpointsMeta.Namespace).Create(&v1.Endpoints{
  ObjectMeta: metav1.ObjectMeta{
      Name:      el.EndpointsMeta.Name,
      Namespace: el.EndpointsMeta.Namespace,
      Annotations: map[string]string{
          LeaderElectionRecordAnnotationKey: string(recordBytes),
      },
  },
})
```

[更新方法](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL3Jlc291cmNlbG9jay9lbmRwb2ludHNsb2NrLmdvI0w3Ng==)
的主体如下，将 `LeaderElectionRecord`
结构的对象序列化为字符串后，存到 annotation：

```
el.e.Annotations[LeaderElectionRecordAnnotationKey] = string(recordBytes)
el.e, err = el.Client.Endpoints(el.EndpointsMeta.Namespace).Update(el.e)
```

通过上面的方法，我们应该已经了解到了，锁的实现主要载体是 LeaderElectionRecord 对象，其实我们完全可以自己实现其他类型的资源锁了，比如基于 Secret ，不过好像也没啥意义。

介绍了上面的实现基础，我们最后来看看抢锁及使用锁的过程， [主要的入口](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL2xlYWRlcmVsZWN0aW9uLmdvI0wxMzgtTDE0OA==)
如下：

```
// Run starts the leader election loop
func (le *LeaderElector) Run() {
  // 先去抢锁，阻塞操作
  le.acquire()
  stop := make(chan struct{})
  // 抢到锁后，执行主函数，就是我们前面提到的 run 函数，通过 Callbacks.OnStartedLeading 回调启动
  go le.config.Callbacks.OnStartedLeading(stop)
  // 抢到锁后，需要定期更新，确保自己一直持有该锁
  le.renew()
  close(stop)
}
```

可以看到，里面主要调用了两个方法： [`acquire`](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL2xlYWRlcmVsZWN0aW9uLmdvI0wxNzItTDE4Nw==) 
和 [`renew`](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL2xlYWRlcmVsZWN0aW9uLmdvI0wxOTAtTDIwNg==) 
。

我们先来看看 `acquire`
方法：

```
func (le *LeaderElector) acquire() {
  stop := make(chan struct{})
  wait.JitterUntil(func() {
      succeeded := le.tryAcquireOrRenew()
      le.maybeReportTransition()
      if !succeeded {
          glog.V(4).Infof("failed to acquire lease %v", desc)
          return
      }
      le.config.Lock.RecordEvent("became leader")
      glog.Infof("successfully acquired lease %v", desc)
      close(stop)
  }, le.config.RetryPeriod, JitterFactor, true, stop)
}
```

实现也很短，这个函数会通过 `wait.JitterUntil`
来定期调用 [`tryAcquireOrRenew`
方法](https://www.colabug.com/goto/aHR0cHM6Ly9naXRodWIuY29tL2t1YmVybmV0ZXMva3ViZXJuZXRlcy9ibG9iL3JlbGVhc2UtMS4xMC9zdGFnaW5nL3NyYy9rOHMuaW8vY2xpZW50LWdvL3Rvb2xzL2xlYWRlcmVsZWN0aW9uL2xlYWRlcmVsZWN0aW9uLmdvI0wyMTEtTDI2NA==)
来获取锁，直到成功为止，如果获取不到锁，则会以 `RetryPeriod`
为间隔不断尝试。如果获取到锁，就会关闭 stop 通道（ `close(stop)`
），通知 `wait.JitterUntil`
停止尝试。 `tryAcquireOrRenew`
是最核心的方法，我们会在介绍完 `renew`
方法之后再进行介绍。

`renew`
只有在获取锁之后才会调用，它会通过持续更新资源锁的数据，来确保继续持有已获得的锁，保持自己的 leader 状态。这里还是用到了很多 `wait`
包里的方法。

```
func (le *LeaderElector) renew() {
  stop := make(chan struct{})
  wait.Until(func() {
      err := wait.Poll(le.config.RetryPeriod, le.config.RenewDeadline, func() (bool, error) {
          return le.tryAcquireOrRenew(), nil
      })
      le.maybeReportTransition()
      desc := le.config.Lock.Describe()
      if err == nil {
          glog.V(4).Infof("successfully renewed lease %v", desc)
          return
      }
      le.config.Lock.RecordEvent("stopped leading")
      glog.Infof("failed to renew lease %v: %v", desc, err)
      close(stop)
  }, 0, stop)
}
```

这里的精妙之处在于， `wait.Until`
会不断的调用 `wait.Poll`
方法，前者是进行无限循环操作，直到 `stop`
chan 被关闭， `wait.Poll`
则不断的对某一条件进行检查，以 `RetryPeriod`
为间隔，直到该条件返回 true、error 或者超时（上面的 RenewDeadline 参数）。这一条件是一个需要满足 `func() (bool, error)`
签名的方法，比如这个例子很简单，只是调用了 `le.tryAcquireOrRenew()`
。

`tryAcquireOrRenew`
方法本身不是一个阻塞操作，只返回 true/false，对应为获取到锁和没有获取到锁的状态。结合 `wait.Poll`
来使用，该函数返回会有以下几种情况：

*   `tryAcquireOrRenew`
    获取到锁，返回 true
*   `tryAcquireOrRenew`
    没有获取到锁，返回 false
*   `tryAcquireOrRenew`
    超时，返回 `ErrWaitTimeout`
    （errors.New(“timed out waiting for the condition”)）

最后，我们再来重点了解下 `tryAcquireOrRenew`
的内容。renew 有两个功能，获取锁，或者在已经获取锁的时候，对锁进行更新，确保锁不被他人抢走。

具体的说明也放到了注释里，这段代码流程上不不复杂，但是需要对前后两个状态，以及 leader 和非 leader 两个角色的不同执行流程有所分辨。

```
func (le *LeaderElector) tryAcquireOrRenew() bool {
  now := metav1.Now()
  // 这个 leaderElectionRecord 就是保存在 Endpoint 的 annotation 中的值。
  // 每个节点都将 HolderIdentity 设置为自己，以及关于获取和更新锁的时间。后面会对时间进行修正，才会更新到 API server
  leaderElectionRecord := rl.LeaderElectionRecord{
      HolderIdentity:       le.config.Lock.Identity(),
      LeaseDurationSeconds: int(le.config.LeaseDuration / time.Second),
      RenewTime:            now,
      AcquireTime:          now,
  }

  // 1\. 获取或者创建 ElectionRecord
  oldLeaderElectionRecord, err := le.config.Lock.Get()
  // 获取记录出错，有可能是记录不存在，这种错误需要处理。
  if err != nil {
​      if !errors.IsNotFound(err) {
​          glog.Errorf("error retrieving resource lock %v: %v", le.config.Lock.Describe(), err)
​          return false
​      }
​      // 记录不存在的话，则创建一条新的记录
​      if err = le.config.Lock.Create(leaderElectionRecord); err != nil {
​          glog.Errorf("error initially creating leader election record: %v", err)
​          return false
​      }
​      // 创建记录成功，同时表示获得了锁，返回true
​      le.observedRecord = leaderElectionRecord
​      le.observedTime = time.Now()
​      return true
  }

  // 2\. 正常获取了锁资源的记录，检查锁持有者和更新时间。
  if !reflect.DeepEqual(le.observedRecord, *oldLeaderElectionRecord) {
​      // 记录之前的锁持有者，其实有可能就是自己。
​      le.observedRecord = *oldLeaderElectionRecord
​      le.observedTime = time.Now()
  }
  // 在满足以下所有的条件下，认为锁由他人持有，并且还没有过期，返回 false
  // a. 当前锁持有者的并非自己
  // b. 上一次观察时间 + 观测检查间隔大于现在时间，即距离上次观测的间隔，小于 `LeaseDuration` 的设置值。
  if le.observedTime.Add(le.config.LeaseDuration).After(now.Time) &&
​      oldLeaderElectionRecord.HolderIdentity != le.config.Lock.Identity() {
​      glog.V(4).Infof("lock is held by %v and has not yet expired", oldLeaderElectionRecord.HolderIdentity)
​      return false
  }
  // 3\. 更新资源的 annotation 内容。
  // 在本函数开头 leaderElectionRecord 有一些字段被设置成了默认值，这里来设置正确的值。
  if oldLeaderElectionRecord.HolderIdentity == le.config.Lock.Identity() {
​      // 如果自己持有锁，则继承之前的获取时间和 leader 切换次数
​      leaderElectionRecord.AcquireTime = oldLeaderElectionRecord.AcquireTime
​      leaderElectionRecord.LeaderTransitions = oldLeaderElectionRecord.LeaderTransitions
  } else {
​      // 发生 leader 切换，所以 LeaderTransitions + 1
​      leaderElectionRecord.LeaderTransitions = oldLeaderElectionRecord.LeaderTransitions + 1
  }

  // 更新锁资源对象
  if err = le.config.Lock.Update(leaderElectionRecord); err != nil {
​      glog.Errorf("Failed to update lock: %v", err)
​      return false
  }
  le.observedRecord = leaderElectionRecord
  le.observedTime = time.Now()
  return true
}
```

再回到 `renew`
方法，在被 `Poll`
阻塞住之后，只要 `Poll`
返回了，就可以继续执行下面的代码。 `le.maybeReportTransition()`
很关键，里面会判断是否出现了 leader 的切换，进而调用 `Callbacks`
的 `OnNewLeader`
方法，尽管 cm 初始化的时候并没有设置这个 Callback 方法。

```
func (l *LeaderElector) maybeReportTransition() {
  if l.observedRecord.HolderIdentity == l.reportedLeader {
      return
  }
  l.reportedLeader = l.observedRecord.HolderIdentity
  if l.config.Callbacks.OnNewLeader != nil {
      go l.config.Callbacks.OnNewLeader(l.reportedLeader)
  }
}
```

代码看起来比较烧脑，本文读起来也比较摸不着头，可能最好的办法就是一遍遍的阅读源代码了。
