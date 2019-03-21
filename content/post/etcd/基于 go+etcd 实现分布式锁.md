---
title: "基于 go+etcd 实现分布式锁"
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

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://www.jianshu.com/p/d3068d0ac7c1

```golang
package main

import (
    "context"
    "fmt"
    "go.etcd.io/etcd/clientv3"
    "time"
)

func main() {
    var (
        config clientv3.Config
        client *clientv3.Client
        lease  clientv3.Lease
        leaseResp *clientv3.LeaseGrantResponse
        leaseId clientv3.LeaseID
        leaseRespChan <-chan *clientv3.LeaseKeepAliveResponse
        err    error
    )
    //客户端配置
    config = clientv3.Config{
        Endpoints:   []string{"127.0.0.1:2379"},
        DialTimeout: 5 * time.Second,
    }
    //建立连接
    if client, err = clientv3.New(config); err != nil {
        fmt.Println(err)
        return
    }

    //上锁（创建租约，自动续租）
    lease = clientv3.NewLease(client)

    //设置一个ctx取消自动续租
    ctx,cancleFunc := context.WithCancel(context.TODO())

    //设置10秒租约（过期时间）
    if leaseResp,err = lease.Grant(context.TODO(),10);err != nil {
        fmt.Println(err)
        return
    }
    //拿到租约id
    leaseId = leaseResp.ID

    //自动续租（不停地往管道中扔租约信息）
    if leaseRespChan,err =lease.KeepAlive(ctx,leaseId);err != nil {
        fmt.Println(err)

    }
    //启动一个协程去监听
    go listenLeaseChan(leaseRespChan)
    //业务处理
    kv := clientv3.NewKV(client)
    //创建事务
    txn := kv.Txn(context.TODO())
    txn.If(clientv3.Compare(clientv3.CreateRevision("/cron/lock/job9"),"=",0)).
        Then(clientv3.OpPut("/cron/lock/job9","xxx",clientv3.WithLease(leaseId))).
        Else(clientv3.OpGet("/cron/lock/job9"))//否则抢锁失败

    //提交事务
    if txtResp,err :=txn.Commit();err != nil {
        fmt.Println(err)
        return
    } else {
        //判断是否抢锁
        if !txtResp.Succeeded {
            fmt.Println("锁被占用：",string(txtResp.Responses[0].GetResponseRange().Kvs[0].Value))
            return
        }
    }

    fmt.Println("处理任务")

    //释放锁（停止续租，终止租约）
    defer cancleFunc()//函数退出取消自动续租
    defer lease.Revoke(context.TODO(),leaseId) //终止租约（去掉过期时间）

    time.Sleep(10 * time.Second)

}

func listenLeaseChan(leaseRespChan <-chan *clientv3.LeaseKeepAliveResponse) {
    var (
        leaseKeepResp *clientv3.LeaseKeepAliveResponse
    )
    for {
        select {
        case leaseKeepResp = <-leaseRespChan:
            if leaseKeepResp == nil {
                fmt.Println("租约失效了")
                goto END
            } else {
                fmt.Println(leaseKeepResp.ID)

            }

        }
    }
    END:
}

```

