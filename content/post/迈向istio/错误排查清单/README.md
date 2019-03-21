---
title: "迈向istio-错误排查清单"
date: 2019-03-20T14:15:59+08:00
draft: false
---

# istio-错误排查清单

[TOC]

使用到istio的时候,我发现istio对于调试方面,错误提示方面还是不怎么友好,很多时候都不知道去哪里找错误原因,突然想到飞机那么复杂的系统是如何做到一直按照正确的方式运行的呢,遂提出此错误排查清单,用于排查部分错误,各位同仁可以一句此错误清单进行异常的排查,或者一句不同的因素对错误进行处理.

## 错误排查清单

1. #### 工作负载中的service端口必须正确的命名

   > 服务端口必须进行命名。端口名称只允许是`<协议>[-<后缀>-]`模式，其中`<协议>`部分可选择范围包括 `http`、`http2`、`grpc`、`mongo` 以及 `redis`，Istio 可以通过对这些协议的支持来提供路由能力。例如 `name: http2-foo` 和 `name: http` 都是有效的端口名，但 `name: http2foo` 就是无效的。如果没有给端口进行命名，或者命名没有使用指定前缀，那么这一端口的流量就会被视为普通 TCP 流量（除非[显式](https://kubernetes.io/docs/concepts/services-networking/service/#defining-a-service)的用 `Protocol: UDP` 声明该端口是 UDP 端口）

2. #### pod必须关联到服务,并且同一端口只能同一协议

   > Pod 必须关联到service，如果一个 Pod 属于多个服务，这些服务不能再同一端口上使用不同协议，例如 HTTP 和 TCP

3. #### **Deployment 应带有 app 以及 version 标签**

   > 在使用 Kubernetes `Deployment` 进行 Pod 部署的时候，建议显式的为 `Deployment` 加上 `app` 以及 `version`标签。每个 Deployment 都应该有一个有意义的 `app` 标签和一个用于标识 `Deployment` 版本的 `version` 标签。`app` 标签在分布式跟踪的过程中会被用来加入上下文信息。Istio 还会用 `app` 和 `version` 标签来给遥测指标数据加入上下文信息。

4. #### 使用短名称时,Istio 会根据规则所在的命名空间来处理这一名称，而非服务所在的命名空间

   > 当使用服务的短名称时（例如使用 `reviews`，而不是 `reviews.default.svc.cluster.local`），Istio 会根据规则所在的命名空间来处理这一名称，而非服务所在的命名空间。假设 “default” 命名空间的一条规则中包含了一个 `reviews` 的 `host` 引用，就会被视为 `reviews.default.svc.cluster.local`，而不会考虑 `reviews` 服务所在的命名空间。**为了避免可能的错误配置，建议使用 FQDN 来进行服务引用。**

5. #### **一个主机名只能在一个 VirtualService 中定义**

6. #### 保留字 `mesh` 用来指代网格中的所有 Sidecar

   > mesh代表所有的sidecar,但是网关不是sidecar,要让规则同时对 `Gateway` 和网格内服务生效，需要显式的将 `mesh` 加入 `gateways`列表。

7. #### VirtualService.spec.http只对http流量生效

   > http列表对名称前缀为 `http-`、`http2-`、`grpc-` 的服务端口，或者协议为 `HTTP`、`HTTP2`、`GRPC`以及终结的 TLS，另外还有使用 `HTTP`、`HTTP2` 以及 `GRPC` 协议的 `ServiceEntry` 都是有效的

8. #### VirtualService.spec.http.match.url.prefix和rewrite配合使用时,prefix的值请以`/`结尾

   > `HTTPRewrite` 用来在 HTTP 请求被转发到目标之前，对请求内容进行部分改写, 但是prefix的值不以`/`结尾,就成了`302`跳转

9. #### jwt认证存在一定延时

   > 在配置了jwt后,并不会立即生效,存在一定的延时情况,需要等待1分钟以内.

10. #### 请使用kubectl apply 应用你的配置

    > 在执行 [`istioctl proxy-status`](https://preliminary.istio.io/docs/reference/commands/istioctl/#istioctl-proxy-status) 命令获取代理同步状态时，Pilot 可能会发生死锁。要避免这一情况的发生，应避免使用 `istioctl proxy-status`。Pilot 进入死锁的表现是 `goroutine` 持续增长，直到耗尽内存。

11. #### 调用链追踪并不是无入侵,并且还需要注意不能传入空的值

    >
    >```java
    > if (xreq != null) {
    >             requestHeaders.put("x-request-id", Collections.singletonList(xreq));
    >         }
    >```

12. #### jaeger使用的是all in one的安装方式,数据是放在内存中的

    > ```shell 
    > $ kubectl get deployment.apps/istio-tracing -n istio-system -o yaml
    > image: docker.io/jaegertracing/all-in-one:1.5
    > ```

13. #### istio使用helm安装的时候,默认追踪采样是1%

    > values.yaml
    >
    > ```java
    > pilot:
    >   traceSampling: 1.0
    > ```

14. #### kiali的grafana,jaeger地址需要重写

    > values.yaml
    >
    > ```yaml
    > kiali:
    > # Override the automatically detected Grafana URL, usefull when Grafana service has no ExternalIPs
    > grafanaURL: http://grafana:3000
    > 
    > # Override the automatically detected Jaeger URL, usefull when Jaeger service has no ExternalIPs
    > jaegerURL: http://jaeger-query:16686
    > ```
    > 注意,*一定要写成外部能访问到的地址*

15. #### 自动注入sidecar,需要admissionWebHook支持

    > ```shell
    > $ kubectl api-versions | grep admissionregistration
    > admissionregistration.k8s.io/v1alpha1
    > admissionregistration.k8s.io/v1beta1
    > ```
    >
    > 启用自动注入:
    >
    > ```shell
    > $ kubectl label namespace default istio-injection=enabled
    > ```







