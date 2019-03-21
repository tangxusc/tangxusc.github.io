---
title: "迈向istio-网关"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- istio
tags:
- istio
keywords:
- istio
---

# istio-网关

[TOC]

在上一节中我们已经成功的简单运行了istio的一个路由,也有了一番流量管理的体验,那么很多人都不禁要问,这些配置和yaml是什么意思呢? 

那接下来我们基于istio示例中的配置,一点一点的解析这些yaml文件.

> nginx.yaml中的内容为k8s的yaml文件,再此不做赘述.

## gateway

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway	#声明类型
metadata:
  name: nginx		#名称
  namespace: test		#作用的namespace
spec:
  selector:				#配置选择器,istio将根据此选择器选择具体的pod来作为网关用于承载网格边缘的进入和发出连接
    istio: ingressgateway
  servers:				#声明具体的服务的host和port的绑定关系
  - port:				#注意,此处是pod已经开放的端口,如果pod没有开放此端口,配置将不生效
      number: 80
      name: http
      protocol: HTTP
    hosts:				#声明port绑定的host
    - "*"
```
## VirtualService

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: nginx
  namespace: test
spec:
  hosts:					#流量的目标主机,可以是带有通配符前缀的DNS名称，也可以是IP地址,FQDN地址,使用FQDN地址要格外注意,例如配置host为nginx,那么在此处服务全路径为nginx.test.svc.cluster.local
  - "*"
  gateways:					#gateway 名称列表					
  - nginx
  http:						#HTTP 流量规则的有序列表,用于匹配端口服务前缀为http-、http2-、grpc- 或者协议为HTTP、HTTP2、GRPC 以及终结的TLS
  - match:					#激活规则所需的匹配条件
    - uri:
        prefix: /test
    rewrite:				#重写请求url
      uri: "/"
    route:					#对流量可能进行重定向或者转发配置
    - destination:			#请求或连接在经过路由规则的处理之后，就会被发送给目标
       host: nginx			#目标的host
       subset: v1			#目标的子集
```
- **使用FQDN地址要格外注意,例如配置host为nginx,那么在此处服务全路径为nginx.test.svc.cluster.local(最佳实践,写全名,或者至少包含namespace)**
- 一个主机名只能在一个 VirtualService中定义,也就是说host绑定唯一一个VirtualService
- gateways字段中 `mesh` 用来指代网格中的所有 Sidecar,并且默认值就是`mesh`如果要同时生效(即配置了指定网关,又想默认),那么需要将默认的mesh加入网关值中
- 重写url后(rewrite),请求到目标服务的路径就为uri的值
- 重写还可以重写写认证/主机部分(authority)

## DestinationRule

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: nginx
  namespace: test
spec:
  host: nginx				#指定host,要注意,如果没找到 会丢弃流量
  subsets:
  - name: v1
    labels:					#子集label
      app: nginx
      version: v1
```

## 一个探索

对于上面的配置有一定认识后,不禁想问是不是所有的pod经过istio注入sidecar后,都可以担任Gateway呢?

我们先来看看istio安装的时候提供的ingressGateway

``` shell
kubectl get deployment.apps/istio-ingressgateway -n istio-system -o yaml
apiVersion: apps/v1
kind: Deployment
#省略部分节点...
      containers:
      - args:
        - proxy
        - router
        - -v
        - "2"
        - --discoveryRefreshDelay
        - 1s
        - --drainDuration
        - 45s
        - --parentShutdownDuration
        - 1m0s
        - --connectTimeout
        - 10s
        - --serviceCluster
        - istio-ingressgateway
        - --zipkinAddress
        - zipkin:9411
        - --statsdUdpAddress
        - istio-statsd-prom-bridge:9125
        - --proxyAdminPort
        - "15000"
        - --controlPlaneAuthPolicy
        - NONE
        - --discoveryAddress
        - istio-pilot:8080
#省略部分节点
        image: docker.io/istio/proxyv2:1.0.2
        imagePullPolicy: IfNotPresent
#省略部分节点
```

再来看看istio注入的sidecar是否也是用的此镜像

```shell
kubectl get deployment/nginx -n test -o yaml
apiVersion: extensions/v1beta1
kind: Deployment
#省略部分节点
    spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
 #省略部分节点         
      - args:
        - proxy
        - sidecar
        - --configPath
        - /etc/istio/proxy
        - --binaryPath
        - /usr/local/bin/envoy
        - --serviceCluster
        - nginx
        - --drainDuration
        - 45s
        - --parentShutdownDuration
        - 1m0s
        - --discoveryAddress
        - istio-pilot.istio-system:15007
        - --discoveryRefreshDelay
        - 1s
        - --zipkinAddress
        - zipkin.istio-system:9411
        - --connectTimeout
        - 10s
        - --statsdUdpAddress
        - istio-statsd-prom-bridge.istio-system:9125
        - --proxyAdminPort
        - "15000"
        - --controlPlaneAuthPolicy
        - NONE
#省略部分节点
        image: docker.io/istio/proxyv2:1.0.2
        imagePullPolicy: IfNotPresent
#省略部分节点
```

可以看到,这两个pod虽然都有`proxyv2:1.0.2`这个镜像 ,但是他们的启动方式是不一样的,所以不能替代.