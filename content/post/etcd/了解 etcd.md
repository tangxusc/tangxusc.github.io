---
title: "了解 etcd"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- golang
- etcd
tags:
- golang
- etcd
keywords:
- golang
- etcd
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://segmentfault.com/a/1190000008361945

## 说明

这是一篇非常入门的文章，让你大概了解一下 etcd。写这篇文章时使用 etcd 的版本是 3.1.0。
etcd 是以实现共享配置和服务发现为目的，提供一致性的键值存储的分布式数据库。kubernetes 等项目使用了 etcd。

## 下载安装

去[这里](https://github.com/coreos/etcd/releases)下载 release 包，解压后是一些文档和两个二进制文件 etcd 和 etcdctl。etcd 是 server 端，etcdctl 是客户端。将 etcd 和 etcdctl 加入 PATH 路径方便我们执行命令。

## 运行 server

执行命令 etcd，即可启动 server

```
ming@ming:/tmp$ etcd
2017-02-14 14:04:40.164639 I | etcdmain: etcd Version: 3.1.0
2017-02-14 14:04:40.164725 I | etcdmain: Git SHA: 8ba2897
2017-02-14 14:04:40.164736 I | etcdmain: Go Version: go1.7.4
2017-02-14 14:04:40.164776 I | etcdmain: Go OS/Arch: linux/amd64
2017-02-14 14:04:40.164784 I | etcdmain: setting maximum number of CPUs to 4, total number of available CPUs is 4
2017-02-14 14:04:40.164850 W | etcdmain: no data-dir provided, using default data-dir ./default.etcd
2017-02-14 14:04:40.164934 I | etcdmain: advertising using detected default host "192.168.1.124"
2017-02-14 14:04:40.165855 I | embed: listening for peers on http://localhost:2380
2017-02-14 14:04:40.167090 I | embed: listening for client requests on localhost:2379
......
```

## etcdctl

说明：etcd 最新的 API 版本是 v3。与 v2 相比，v3 更高效更清晰。设置环境变量 ETCDCTL_API=3。

```
ming@ming:/tmp$ export ETCDCTL_API=3
ming@ming:/tmp$ etcdctl version
etcdctl version: 3.1.0
API version: 3.1
```

### 键值对命令

`put`设置 key，`get`取得 key

```
ming@ming:/tmp$ etcdctl put msg "Hello TenxCloud"
OK
ming@ming:/tmp$ etcdctl get msg  
msg
Hello TenxCloud
```

`del`删除 key

```
ming@ming:/tmp$ etcdctl get msg  
msg
Hello TenxCloud
ming@ming:/tmp$ etcdctl del msg
1
ming@ming:/tmp$ etcdctl get msg
ming@ming:/tmp$ 
```

`txn`事务
txn 从标准输入中读取多个请求，将它们看做一个原子性的事务执行。事务是由条件列表，条件判断成功时的执行列表（条件列表中全部条件为真表示成功）和条件判断失败时的执行列表（条件列表中有一个为假即为失败）组成的。
看文字解释容易晕，来看实例吧

```
ming@ming:/tmp$ etcdctl put flag 1
OK
ming@ming:/tmp$ etcdctl txn -i
compares:
value("flag") = "1"
success requests (get, put, delete):
put result true
failure requests (get, put, delete):
put result false
SUCCESS
OK
ming@ming:/tmp$ etcdctl get result
result
true
```

解释一下：

1.  etcdctl put flag 1 设置 flag 为 1

2.  etcdctl txn -i 开启事务（-i 表示交互模式）

3.  第 2 步输入命令后回车，终端显示出 compares：

4.  输入 value("flag") = "1"，此命令是比较 flag 的值与 1 是否相等

5.  第 4 步完成后输入回车，终端会换行显示，此时可以继续输入判断条件（前面说过事务由条件列表组成），再次输入回车表示判断条件输入完毕

6.  第 5 步连续输入两个回车后，终端显示出 success requests (get, put, delete):，表示下面输入判断条件为真时要执行的命令

7.  与输入判断条件相同，连续两个回车表示成功时的执行列表输入完成

8.  终端显示 failure requests (get, put, delete): 后输入条件判断失败时的执行列表

9.  为了看起来简洁，此实例中条件列表和执行列表只写了一行命令，实际可以输入多行

10.  总结上面的事务，要做的事情就是 flag 为 1 时设置 result 为 true，否则设置 result 为 false

11.  事务执行完成后查看 result 值为 true

`watch`监听
watch 后 etcdctl 阻塞，在另一个终端中执行 etcdctl put flag 2 后，watch 会打印出相关信息

```
ming@ming:/tmp$ etcdctl watch flag
PUT
flag
2
```

`lease`租约
etcd 也能为 key 设置超时时间，但与 redis 不同，etcd 需要先创建 lease，然后使用 put 命令加上参数–lease=<lease ID> 来设置

```
ming@ming:/tmp$ etcdctl lease grant 100
lease 38015a3c00490513 granted with TTL(100s)
ming@ming:/tmp$ etcdctl put k1 v1 --lease=38015a3c00490513
OK
ming@ming:/tmp$ etcdctl lease timetolive 38015a3c00490513
lease 38015a3c00490513 granted with TTL(100s), remaining(67s)
ming@ming:/tmp$ etcdctl lease timetolive 38015a3c00490513
lease 38015a3c00490513 granted with TTL(100s), remaining(64s)
ming@ming:/tmp$ etcdctl lease timetolive 38015a3c00490513 --keys
lease 38015a3c00490513 granted with TTL(100s), remaining(59s), attached keys([k1])
ming@ming:/tmp$ etcdctl put k2 v2 --lease=38015a3c00490513
OK
ming@ming:/tmp$ etcdctl lease timetolive 38015a3c00490513 --keys
lease 38015a3c00490513 granted with TTL(100s), remaining(46s), attached keys([k1 k2])
ming@ming:/tmp$ etcdctl lease revoke 38015a3c00490513 
lease 38015a3c00490513 revoked
ming@ming:/tmp$ etcdctl get k1
ming@ming:/tmp$ etcdctl get k2
ming@ming:/tmp$ 
ming@ming:/tmp$ etcdctl lease grant 10
lease 38015a3c0049051d granted with TTL(10s)
ming@ming:/tmp$ etcdctl lease keep-alive 38015a3c0049051d
lease 38015a3c0049051d keepalived with TTL(10)
lease 38015a3c0049051d keepalived with TTL(10)
lease 38015a3c0049051d keepalived with TTL(10)
```

`lease grant <ttl>`
创建 lease，返回 lease ID。创建的 lease 生存时间大于或等于 ttl 秒（TODO：为什么可能大于？）
`lease revoke <lease ID>`
删除 lease，并删除所有关联的 key
`lease timetolive <lease ID>`
取得 lease 的总时间和剩余时间
`lease keep-alive <lease ID>`
此命令不会只更新一次 lease 时间，而是周期性地刷新，保证它不会过期。

### 集群管理命令

TODO

### 并发控制命令

`lock <lock name>`
通过指定的名字加锁。注意，只有当正常退出且释放锁后，lock 命令的退出码是 0，否则这个锁会一直被占用直到过期（默认 60 秒）

```
使用Ctrl+C正常退出lock命令，退出码为0，第二次能正常lock：
ming@ming:/tmp$ etcdctl lock test
test/38015a3fd6795e04
^Cming@ming:/tmp$ echo $?
0
ming@ming:/tmp$ etcdctl lock test
test/38015a3fd6795e0a

kill掉lock命令，退出码不为0，第二次lock被阻塞：
终端1，第一次正常锁住test：
ming@ming:/tmp$ etcdctl lock test
test/38015a3fd6795e11

终端2，kill掉lock命令：
ming@ming:~$ ps aux|grep 'etcdctl lock'
ming      44546  0.5  0.5  19876 11436 pts/5    Sl+  11:42   0:00 etcdctl lock test
ming      44560  0.0  0.0  14224  1084 pts/6    S+   11:43   0:00 grep --color=auto etcdctl lock
ming@ming:~$ kill -9 44546

终端1，退出码不为0，第二次锁test被阻塞
ming@ming:/tmp$ etcdctl lock test
test/38015a3fd6795e1e
Killed
ming@ming:/tmp$ echo $?
137
ming@ming:/tmp$ etcdctl lock test
```

elect
TODO

### 权限命令

`user`
可以为 etcd 创建多个用户并设置密码，子命令有：

*   add 添加用户

*   delete 删除用户

*   get 取得用户详情

*   list 列出所有用户

*   passwd 修改用户密码

*   grant-role 给用户分配角色

*   revoke-role 给用户移除角色

`role`
可以为 etcd 创建多个角色并设置权限，子命令有：

*   add 添加角色

*   delete 删除角色

*   get 取得角色信息

*   list 列出所有角色

*   grant-permission 为角色设置某个 key 的权限

*   revoke-permission 为角色移除某个 key 的权限

`auth`
开启 / 关闭权限控制

示例
下面以示例来学习这三个命令

```
root用户存在时才能开启权限控制
ming@ming:/tmp$ etcdctl auth enable
Error:  etcdserver: root user does not exist
ming@ming:/tmp$ etcdctl user add root
Password of root: 
Type password of root again for confirmation: 
User root created
ming@ming:/tmp$ etcdctl auth enable
Authentication Enabled

开启权限控制后需要用--user指定用户
ming@ming:/tmp$ etcdctl user list
Error:  etcdserver: user name not found
ming@ming:/tmp$ etcdctl user list --user=root
Password: 
root
ming@ming:/tmp$ etcdctl user get root --user=root
Password: 
User: root
Roles: root

添加用户，前两个密码是新用户的，后一个密码是root的
ming@ming:/tmp$ etcdctl user add mengyuan --user=root
Password of mengyuan: 
Type password of mengyuan again for confirmation: 
Password: 
User mengyuan created

使用新用户执行put命令，提示没有权限
ming@ming:/tmp$ etcdctl put key1 v1 --user=mengyuan
Password: 
Error:  etcdserver: permission denied
创建名为rw_key_的role，添加对字符串"key"做为前缀的key的读写权限，为mengyuan添加角色
ming@ming:/tmp$ etcdctl role add rw_key_ --user=root
Password: 
Role rw_key_ created
ming@ming:/tmp$ etcdctl --user=root role grant-permission rw_key_ readwrite key --prefix=true
Password: 
Role rw_key_ updated
ming@ming:/tmp$ etcdctl --user=root user grant-role mengyuan rw_key_
Password: 
Role rw_key_ is granted to user mengyuan

添加权限成功后执行put key1成功，执行put k1失败（因为上面只给前缀为"key"的key添加了权限）
ming@ming:/tmp$ etcdctl put key1 v1 --user=mengyuan
Password: 
OK
ming@ming:/tmp$ etcdctl put k1 v1 --user=mengyuan
Password: 
Error:  etcdserver: permission denied

执行user list命令失败，没有权限
ming@ming:/tmp$ etcdctl user list --user=mengyuan
Password: 
Error:  etcdserver: permission denied
为新用户添加root的角色后就能执行user list命令了，注意命令中第一个root是角色，第二个root是用户
ming@ming:/tmp$ etcdctl user grant-role mengyuan root --user=root
Password: 
Role root is granted to user mengyuan
ming@ming:/tmp$ etcdctl user list --user=mengyuan
Password: 
mengyuan
root
```

## 进一步学习

*   etcdctl <command> -h 查看子命令的帮助（例：etcdctl watch -h）

*   [http://play.etcd.io/play](http://play.etcd.io/play) 是网页版集群环境

*   etcdctl 能够设置 --prefix=true 来操作多个指定前缀的 key

## 参考文档

[https://github.com/coreos/etcd](https://github.com/coreos/etcd)
[https://github.com/coreos/etc...](https://github.com/coreos/etcd/tree/master/etcdctl)