---
title: "Etcd搭建及使用"
date: 2019-04-25T16:41:39+08:00
categories:
- etcd
tags:
- etcd
keywords:
- etcd
#thumbnailImage: //example.com/image.jpg
---

etcd是云原生的存储基石,在kubernetes中的存储便采用的etcd.

<!--more-->

## 下载

在github的release中(https://github.com/etcd-io/etcd/releases) 下载etcd(本文下载最新版本-v3.3.12),下载后解压可以看到如下:

```shell
.
├── Documentation
├── etcd
├── etcdctl
├── README-etcdctl.md
├── README.md
├── READMEv2-etcdctl.md
```

其中`etcd`为启动etcd的服务端,etcdctl为etcd客户端.

> 在etcd 3 版本中使用的是grpc和服务端通信了,不再是以前的http了,请注意哟.

## 启动server

> 证书的生成请查看文章 [cfssl生成证书](https://tangxusc.github.io/blog/2019/04/%E4%BD%BF%E7%94%A8cfssl%E7%94%9F%E6%88%90etcd%E8%AF%81%E4%B9%A6pem/)

在很多博客中都是直接启动etcd的,这里我不推荐这种方式来启动,特别是在生产环境中我们应该使用证书的方式来启动etcd集群,所以在本文中,我们将按照生产的方式启动etcd集群,启动命令如下:

```shell
./etcd --name infra0 --initial-advertise-peer-urls https://127.0.0.1:12380 \
  --listen-peer-urls https://127.0.0.1:12380 \
  --listen-client-urls https://127.0.0.1:12379 \
  --advertise-client-urls https://127.0.0.1:12379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=https://127.0.0.1:12380 \
  --initial-cluster-state new \
  --client-cert-auth --trusted-ca-file=ca.pem \
  --cert-file=etcd.pem --key-file=etcd-key.pem \
  --peer-client-cert-auth --peer-trusted-ca-file=ca.pem \
  --peer-cert-file=etcd.pem --peer-key-file=etcd-key.pem
```

这里详细解释一下传入的参数:

- `name`:指明当前etcd节点名称
- `initial-advertise-peer-urls`: 初始化节点时广播集群通信地址
- `listen-peer-urls`: 当前(自己)监听的集群通信地址
- `listen-client-urls`: 监听的客户端通信地址
- `advertise-client-urls`: 广播客户端通信地址
- `initial-cluster-token`:初始化集群的token
- `initial-cluster-state`:集群状态,new标示初始化
- `initial-cluster`:初始化集群,格式为  `节点1name=节点peer地址:端口,节点2name=节点peer地址:端口`
- `client-cert-auth`: 要求客户端提供证书
- `trusted-ca-file`: ca证书
- `cert-file`:ca签发的证书
- `key-file`:cert-file证书对应的秘钥
- `peer-client-cert-auth`:集群使用证书通信
- `peer-trusted-ca-file`:集群ca证书
- `peer-cert-file`:集群通信证书
- `peer-key-file`:peer-cert-file秘钥

请注意`initial-cluster-state`这个值为`new`,在此状态下`initial-*`的这些命令才会生效...

在命令行执行启动命令后,输出如下:

```shell
2019-04-30 15:17:07.810766 I | etcdmain: etcd Version: 3.3.12
2019-04-30 15:17:07.810824 I | etcdmain: Git SHA: d57e8b8
2019-04-30 15:17:07.810831 I | etcdmain: Go Version: go1.10.8
2019-04-30 15:17:07.810841 I | etcdmain: Go OS/Arch: linux/amd64
2019-04-30 15:17:07.810849 I | etcdmain: setting maximum number of CPUs to 4, total number of available CPUs is 4
2019-04-30 15:17:07.810861 W | etcdmain: no data-dir provided, using default data-dir ./infra0.etcd
2019-04-30 15:17:07.810911 N | etcdmain: the server is already initialized as member before, starting as etcd member...
2019-04-30 15:17:07.810943 I | embed: peerTLS: cert = etcd.pem, key = etcd-key.pem, ca = , trusted-ca = ca.pem, client-cert-auth = true, crl-file = 
2019-04-30 15:17:07.827298 I | embed: listening for peers on https://127.0.0.1:12380
2019-04-30 15:17:07.827388 I | embed: listening for client requests on 127.0.0.1:12379
2019-04-30 15:17:08.165395 I | etcdserver: name = infra0
2019-04-30 15:17:08.165414 I | etcdserver: data dir = infra0.etcd
2019-04-30 15:17:08.165423 I | etcdserver: member dir = infra0.etcd/member
2019-04-30 15:17:08.165429 I | etcdserver: heartbeat = 100ms
2019-04-30 15:17:08.165435 I | etcdserver: election = 1000ms
2019-04-30 15:17:08.165441 I | etcdserver: snapshot count = 100000
2019-04-30 15:17:08.165460 I | etcdserver: advertise client URLs = https://127.0.0.1:12379
2019-04-30 15:17:08.336901 I | etcdserver: restarting member d05e7521f6de6bab in cluster 7d0764d1262439e9 at commit index 8981
2019-04-30 15:17:08.337324 I | raft: d05e7521f6de6bab became follower at term 2
2019-04-30 15:17:08.337339 I | raft: newRaft d05e7521f6de6bab [peers: [], term: 2, commit: 8981, applied: 0, lastindex: 8981, lastterm: 2]
2019-04-30 15:17:08.461289 W | auth: simple token is not cryptographically signed
2019-04-30 15:17:08.500924 I | etcdserver: starting server... [version: 3.3.12, cluster version: to_be_decided]
2019-04-30 15:17:08.522066 I | etcdserver/membership: added member d05e7521f6de6bab [https://127.0.0.1:12380] to cluster 7d0764d1262439e9
2019-04-30 15:17:08.522173 N | etcdserver/membership: set the initial cluster version to 3.3
2019-04-30 15:17:08.522219 I | etcdserver/api: enabled capabilities for version 3.3
2019-04-30 15:17:08.622425 I | embed: ClientTLS: cert = etcd.pem, key = etcd-key.pem, ca = , trusted-ca = ca.pem, client-cert-auth = true, crl-file = 
2019-04-30 15:17:10.337687 I | raft: d05e7521f6de6bab is starting a new election at term 2
2019-04-30 15:17:10.337714 I | raft: d05e7521f6de6bab became candidate at term 3
2019-04-30 15:17:10.337744 I | raft: d05e7521f6de6bab received MsgVoteResp from d05e7521f6de6bab at term 3
2019-04-30 15:17:10.337765 I | raft: d05e7521f6de6bab became leader at term 3
2019-04-30 15:17:10.337777 I | raft: raft.node: d05e7521f6de6bab elected leader d05e7521f6de6bab at term 3
2019-04-30 15:17:10.338016 I | etcdserver: published {Name:infra0 ClientURLs:[https://127.0.0.1:12379]} to cluster 7d0764d1262439e9
2019-04-30 15:17:10.338067 I | embed: ready to serve client requests
2019-04-30 15:17:10.339306 E | etcdmain: forgot to set Type=notify in systemd service file?
2019-04-30 15:17:10.370981 I | embed: serving client requests on 127.0.0.1:12379
```

## 客户端使用

`etcdctl`是etcd为我们提供的客户端,用来调用etcd的集群设置键值对.

在使用etcdctl之前,必须要了解一下etcdctl的一个使用方式

etcd在v2版本时使用http通信,在v3版本使用的则是grpc,但是etcdctl现在默认的居然还是以前的老方式(不是说好的大版本不兼容么,这怎么还要兼容?),所以我们在使用时先要声明etcdctl使用的api版本,设置如下:

```shell
$ export ETCDCTL_API=3
```

> 当然设置在环境变量中更为方便.

在设置好api后,就可以使用etcd了,先来看看服务器的节点情况: 

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem member list
d05e7521f6de6bab, started, infra0, https://127.0.0.1:12380, https://127.0.0.1:12379

$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem member list -w json
{"header":{"cluster_id":9009280429028817385,"member_id":15014566996435954603,"raft_term":3},"members":[{"ID":15014566996435954603,"name":"infra0","peerURLs":["https://127.0.0.1:12380"],"clientURLs":["https://127.0.0.1:12379"]}]}

```

可以看到etcd只有一个节点,叫infra0(好孤独)..

## etcd常用命令及参数

### 常用参数(OPTIONS)

#### endpoints

etcd服务器地址,数组格式例如:`--endpoints=127.0.0.1:12379,127.0.0.1:12379`

#### cacert/cert/key

证书三连,依次为ca证书,ca签发的证书,证书对应的秘钥

#### w

指定输出格式,可选的参数为:`fields, json, protobuf, simple, table`(json格式可以看到更多信息,默认为simple)

#### rev(revision)

在etcd中每个事务有唯一id,叫main ID,全局递增不重复.

在一个事务中,有多个修改操作,共享一个mainID,多个修改操作有一个编号叫Sub ID

每一个revision由main ID,Sub ID组成.

在源码中struct结构如下:

```golang
type revision struct{
// mainisthe mainrevision ofa setofchanges that happen atomically.

mainint64
// sub isthe the sub revision ofa changeina setofchanges that happen
// atomically. Eachchangehas different increasing sub revision inthat
// set.

sub int64
}
```

### 常用命令(COMMANDS)

#### put

设置键值对

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem put test test1 -w json
{"header":{"cluster_id":9009280429028817385,"member_id":15014566996435954603,"revision":8976,"raft_term":3}}
```

#### get

获取键值对

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem get test -w json
{"header":{"cluster_id":9009280429028817385,"member_id":15014566996435954603,"revision":8976,"raft_term":3},"kvs":[{"key":"dGVzdA==","create_revision":8975,"mod_revision":8976,"version":2,"value":"dGVzdDE="}],"count":1}
```

#### del

删除键值对

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem del test -w json
{"header":{"cluster_id":9009280429028817385,"member_id":15014566996435954603,"revision":8977,"raft_term":3},"deleted":1}
```

#### watch

监听键值对事件

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem watch test
PUT
test
test1
PUT
test
test2
DELETE
test
```

注意,这里还可以传入版本`--rev=1`标示从第一个版本开始watch,rev=0表示键不存在,存在都以1作为第一个版本

#### compaction

压缩etcd的log日志,etcd使用raft算法,其中键值对同步是使用log复制的方式.

#### lease grant

获得一个租约

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem lease grant 10
lease 6bab6a6d1ab6710c granted with TTL(10s)
```

#### lease revoke

收回租约,租约下的key会被删除

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem lease grant 10
lease 6bab6a6d1ab67113 granted with TTL(10s)

$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem lease revoke 6bab6a6d1ab67113 -w json
{"header":{"cluster_id":9009280429028817385,"member_id":15014566996435954603,"revision":8980,"raft_term":3}}
```

#### lease timetolive

租约的时间

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem lease timetolive 6bab6a6d1ab67116 -w json
{"cluster_id":9009280429028817385,"member_id":15014566996435954603,"revision":8980,"raft_term":3,"id":7758411799907954966,"ttl":574,"granted-ttl":600,"keys":null}
```

#### lease list

租约列表

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem lease list
found 1 leases
6bab6a6d1ab67116
```

#### lease keep-alive

保持租约不过期

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem lease keep-alive 6bab6a6d1ab67116
lease 6bab6a6d1ab67116 keepalived with TTL(600)
```

#### member list

节点列表

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem  member list -w json
{"header":{"cluster_id":9009280429028817385,"member_id":15014566996435954603,"raft_term":3},"members":[{"ID":15014566996435954603,"name":"infra0","peerURLs":["https://127.0.0.1:12380"],"clientURLs":["https://127.0.0.1:12379"]}]}
```

#### check perf

性能测试

```shell
$ ./etcdctl --endpoints=127.0.0.1:12379 --cacert=ca.pem --key=etcd-key.pem --cert=etcd.pem check perf
 60 / 60 Boooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo! 100.00%1m0s
PASS: Throughput is 150 writes/s
Slowest request took too long: 0.871827s
PASS: Stddev is 0.084639s
FAIL
```

## 参照

共识算法:raft https://www.jianshu.com/p/8e4bbe7e276c

raft动画 http://thesecretlivesofdata.com/raft/#replication