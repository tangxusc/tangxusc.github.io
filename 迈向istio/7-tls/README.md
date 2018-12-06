# istio-tls

[TOC]

我们已经完成了我们服务的路由,并且也已经有了镜像流量了,那么接下来我们要做什么呢?

## 背景

安全-所有应用都离不开的话题,在微服务中也一样会存在安全问题,特别是在一个企业的微服务系统中,各服务对外的接口安全都做的很好,但是服务间的安全等问题很多企业都做的不够好.这里我给大家一个例子:

企业x有一个混合云集群,node节点分别位于 某云服务器提供商和本地机房这两个地方,并且部署了两个服务,其中存在不少敏感信息,我们用一个表单来说明这样的情况:

|       | 某云        | 本地        |
| ----- | ----------- | ----------- |
| 服务A |             | local-node1 |
| 服务B | cloud-node2 |             |

这个时候,我们发现,服务A调用服务B实际上是一次跨云之旅,但是这个跨云之旅中途会出现以下几个安全问题:

- 中途被劫道(劫持)
- 到目标服务的可能是间谍(请求被修改,替换)

那么,我们如何应对这样的情况呢?

在istio的安全章节中 我找到了一个应对此问题的答案,各位请跟我来,我指给各位看*[istio-安全](https://preliminary.istio.io/zh/docs/concepts/security/)*

好了,大幕拉开,表演开始.

## 服务图

![服务图](./服务图.png)

## target配置

```yaml
#记得开启自动注入
#kubectl label namespace test istio-injection=enabled
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
 name: target
 namespace: test
 labels:
   app: target
   version: v1
spec:
 template:
    metadata:
     labels:
       app: target
       version: v1
    spec:
     containers:
     - name: target
       image: service-proxy:go-1
       ports:
       - containerPort: 8090
         name: http
         protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  name: target
  namespace: test
spec:
  selector:
    app: target
  ports:
    - port: 80
      name: http #一定注意命名
      protocol: TCP
      targetPort: 8090
```
### 在k8s中部署服务

```shell
$ kubectl create ns test
$ kubectl label namespace test istio-injection=enabled
$ kubectl apply -f k8s.yaml -n test
```
### 验证配置

```shell
$ curl 服务地址/index -v
#返回 index
```

这是一个很平常的服务,我们将对此服务流量进行tls加密,来防止被劫道和间谍行为.

## 路由及tls配置

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: target
  namespace: test
spec:
  selector:
    istio: ingressgateway
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
  name: target
  namespace: test
spec:
  hosts:
  - "*"
  gateways:
  - target
  http:
  - match:
    - uri:
        prefix: /target/
    rewrite:
      uri: "/"
    route:
    - destination:
       host: target
       subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: target
  namespace: test
spec:
  host: target
  subsets:
  - name: v1
    labels:
      app: target
      version: v1
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
---
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "default"
  namespace: "test"
spec:
  peers:
  - mtls: {}
#---
#apiVersion: "authentication.istio.io/v1alpha1"
#kind: "MeshPolicy"
#metadata:
#  name: "default"
#spec:
#  peers:
#  - mtls: {}
```

### 在istio中部署此配置

```shell
$ kubectl apply -f istio.yaml -n test
```

## 表演开始

```shell
#现在我们通过gateway访问target 这个服务
$ curl 网关地址/target/index
#返回index
#那我们再使用`服务地址`来访问呢
$ curl 服务地址/index
curl: (56) Recv failure: 连接被对方重设
```

可以看到,现在我们访问istio,居然是连接被对方重设,不再是以前的直接返回结果了;

那么发生了什么呢?

![tls](tls.svg)

> 我们可以将target这个服务视作 service A

我们使用`kubectl apply -f istio.yaml`的时候,其实配置是将这些crd(第三方资源)存储到了kubernetes中,pilot,citadel监听到这些文件的创建后,pilot下发tls配置,citadel生成相应的证书下发到具体的sidecar中.

整个通信过程就很简单了,我们使用http流量到达 ingress gateway 再转发到 Service A对应的proxy,此时proxy会根据下发的配置来对此请求进行证书的校验,不通过的 就直接拒绝这个连接,通过的再转发到Service A进行请求处理.

### Policy/MeshPolicy

那么看过配置文件的就会问了,那这个Policy 和 MeshPolicy有什么区别呢,或者说最佳实践是什么呢?

Policy:只作用于该规则namespace的策略,也就是说,这个策略只能在一个namespace中生效

MeshPolicy:显然 这个是针对所有namespace的,但是这个MeshPolicy的name只能是`default`,并且没有target属性

### ingress-Gateway tls

那么我们设置Ingress-gateway的tls呢?

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: my-gateway
spec:
  selector:
    app: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
    tls:
      httpsRedirect: true # 用 301 重定向指令响应 http 协议的请求。
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "*"
    tls:
      mode: SIMPLE # 在这一端口开放 https 服务
      serverCertificate: /etc/certs/servercert.pem
      privateKey: /etc/certs/privatekey.pem
```

请一定注意,`ingress-gateway`是对外的服务,那么此处要求的证书一定是对外的,并且经过正确签名的证书才不会出错.

## 注意

- MeshPolicy/Policy 在name为`default`时,都不能设置target属性
- 使用服务间的tls时,在消费端(DestinationRule)需要配置对请求进行tls加密
- 在服务端(Service)需要配置Policy来指定服务端对流量进行进行校验

## 清理

```shell
$ kubectl delete namespace/test
```

