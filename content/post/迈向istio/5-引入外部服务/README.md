---
title: "迈向istio-引入外部服务"
date: 2019-04-01T14:15:59+08:00
draft: false
categories:
- istio
tags:
- istio
keywords:
- istio
---

在istio中所有的流量都是通过istio的initContainer启动的时候对iptable进行了劫持的,那么外部流量就无法通过dns等服务发现机制进行路由了,这个时候怎么办呢? 这一节我们就来解决这个问题.

<!--more-->

## 服务规划

<img src="/post/迈向istio/5-引入外部服务/外部服务.png"/>

注意:istio-egressGateway这个服务是路由的出口,这样做有几个优点

- 企业通过统一的ingressGateway控制流量的进入

- 通过EgressGateway控制流量的总体出

这样更有利于网络管理人员进行统一的流量控制和安全检查.

但是这也会引起几个问题,希望各位注意:

- IngressGateway需要高可用,并且流量较大
- EgressGateway外部出口流量一样不会小,这个时候很考研公司的基础网络环境

那么在我们这一节的示例中我们引入 `www.baidu.com` 这个服务来做我们的测试

> 注意:此节基于上节部署的服务

### 百度(baidu)服务

istio.yaml

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: baidu
  namespace: test
spec:
  hosts:
  - "www.baidu.com"
  location: MESH_EXTERNAL
#  location: MESH_INTERNAL
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
#  endpoints:
#  - address: www.baidu.com
#    ports:
#      http: 80

---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: istio-egressgateway
  namespace: test
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"

---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: gateway-routing
  namespace: test
spec:
  hosts:
  - www.baidu.com
  gateways:
  - mesh
  - istio-egressgateway
  http:
  - match:
    - port: 80
      gateways:
      - mesh
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
  - match:
    - port: 80
      gateways:
      - istio-egressgateway
    route:
    - destination:
        host: www.baidu.com
```
将baidu服务部署:
```shell
$ istioctl create -f istio.yaml -n test
```

### 验证服务

使用curl对整个服务链路进行测试:

```shell
$ curl 10.108.228.41/proxy/proxy?url=http://target/proxy?url=http://www.baidu.com
#返回百度首页内容
```
## 配置说明

istio.yaml内容中最让人疑惑的是怎么转发到egressGateway中的,这里我们需要仔细的看看这个yaml

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: baidu
  namespace: test
spec:
  hosts: #声明hosts
  - "www.baidu.com"
  location: MESH_EXTERNAL #声明外部服务是不是k8s里面的服务
  ports: #声明 协议端口等等
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS #声明这个服务怎么去查找具体的ip,怎么去访问
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: gateway-routing
  namespace: test
spec:
  hosts:
  - www.baidu.com #声明百度域名
  gateways:
  - mesh #此virtualService应用到那些gateway,mesh标示所有sidecar(注意是sidecar,不包括网关)
  - istio-egressgateway #同时也应用到istio-egressgateway这个网关
  http:
  - match: #匹配配置,sidecar中所有的面向www.baidu.com:80的都路由到egressgateway
    - port: 80
      gateways:
      - mesh 
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
  - match: #同时,网关中面向www.baidu.com:80的都路由到www.baidu.com,由于在ServiceEntry中已经配置了这个域名,所以会被直接应用ServiceEntry的配置
    - port: 80
      gateways:
      - istio-egressgateway
    route:
    - destination:
        host: www.baidu.com
```
## 清理

```shell
$ kubectl delete namespace/test
```

