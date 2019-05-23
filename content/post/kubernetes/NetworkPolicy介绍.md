---
title: "NetworkPolicy介绍"
date: 2019-05-23T15:50:45+08:00
categories:
- k8s
- NetworkPolicy
tags:
- k8s
- NetworkPolicy
keywords:
- NetworkPolicy
#thumbnailImage: //example.com/image.jpg
---

在kubernetes中的所有的pod在默认情况下,网络都是互通的,pod接收来自任何来源的流量.

那么我们如何限制pod的网络通信,防止非法访问呢?

<!--more-->

kubernetes为了解决上诉的问题,为我们提供了一个新的资源`NetworkPolicy`,主要用来定义pod之间的网络规则,指定进出pod的流量.

## 先决条件

kubernetes的网络是一个典型的二层网络,pod间为了能够互相通信,专门诞生了`cni`项目,并出现了很多网络插件,例如`Calico`,`WeaveNet`,`flannel`等等,这些插件实现都有各自的方案,但是总体下来目标一致,都是为kubernetes提供一个二层网络,并且让pod可以直接通信.

`NetworkPolicy`资源的实际实现也是由网络插件控制,如果网络插件未实现此资源,那么将不起作用.

在官方文档中现在支持的插件有以下几个:

- [Calico](https://kubernetes.io/docs/tasks/administer-cluster/network-policy-provider/calico-network-policy/)
- [Cilium](https://kubernetes.io/docs/tasks/administer-cluster/network-policy-provider/cilium-network-policy/)
- [Kube-router](https://kubernetes.io/docs/tasks/administer-cluster/network-policy-provider/kube-router-network-policy/)
- [Romana](https://kubernetes.io/docs/tasks/administer-cluster/network-policy-provider/romana-network-policy/)
- [Weave Net](https://kubernetes.io/docs/tasks/administer-cluster/network-policy-provider/weave-network-policy/)

## NetworkPolicy资源介绍

`NetworkPolicy`资源由三个主要部分构成

`podSelector`: 根据命名空间和label来选择需要应用网络策略的pod

`policyTypes`: 网络策略类型,数组类型,可选值为`Ingress`,`engress`或者两个都填写.如果未指定则默认值为`ingress,engress`

`ingress`: 入口白名单规则,可以通过`from`设置从那些地方进入的流量,子字段`ipBlock`,`namespaceSelector`,`podSelector`等字段提供了对于来源的灵活选择,也可以通过`ports`可以设置从那些端口进入的流量

`engress`: 同ingress基本一致,但是`from`修改为了`to`

一个包含进出的网络策略示例如下:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # from配置来源规则,可以多个
  - from:
    # 同时需要满足以下几个规则之一
    - ipBlock:
        cidr: 172.17.0.0/16
        except:
        - 172.17.1.0/24
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    # 同时需要满足端口规则
    ports:
    - protocol: TCP
      port: 6379
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 5978
```

本示例的网络策略如下:

- 通过`podSelector`选择了`default`命名空间下的label为`role: db`的pod,设置网络策略
- 入口规则设置了一个来源,其中开放了tcp协议6379端口,并满足以下情况:
  - 网段为`172.17.0.0/16`,但是排除`172.17.1.0/24`
  - 命名空间的label包含`project: myproject`
  - 在`default`命名空间中,pod标签包含`role: frontend`
- 出口规则为**选择的pod**设置了一个出站规则,从tcp协议的5978端口发出连接,同时需要满足:
  - 子网为`10.0.0.0/24`

> 注意: `NetworkPolicy`资源为命名空间内资源,在使用时需要指定**命名空间**

## 默认策略

在`NetworkPolicy`未指定的情况下(也就是我们平常使用的情况),那么pod是允许所有流量进出的.

在podSelector为空对象(即值为`{}`)时,则是选择`该命名空间`所有的pod,如果`ingress/engress`为空对象(即值为`{}`)时,则允许所有流量进/出,例如:

`默认拒绝所有流量`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
# 未配置 ingress 字段,则标示没有允许的入口,则拒绝所有.
```

`默认允许所有流量`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all
spec:
  podSelector: {}
  # 配置了一个空的ingress,标示 所有的入口,则允许所有的进入
  ingress:
  - {}
  policyTypes:
  - Ingress
```

## 参照

[官方文档](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

[官方示例](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)

[NetworkPolicy资源的完整定义](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.14/#networkpolicy-v1-networking-k8s-io)