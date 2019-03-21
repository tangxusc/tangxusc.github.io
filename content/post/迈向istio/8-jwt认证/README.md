---
title: "迈向istio-jwt认证"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- istio
tags:
- istio
keywords:
- istio
---
# istio-jwt认证

[TOC]

## 背景

在建设企业的各种项目中,我们一定离不开,或者总要和认证授权系统打交道,应用总会入侵一些认证和授权部分的代码,现在在java等方面有大量的安全框架,例如`spring security,shiro`等等框架,这些框架也是为了解决这个重复性的做认证和授权等功能的问题,这也是我们在单体服务的时候一直做的,将各种各样的框架集成到系统中,那么现在在微服务时代,或者说在istio有没有解决方法能解决这个问题呢,让服务真正回归业务,不再去过多的管理认证的问题呢.

在本节中我们将会将我们的应用构建为一个需要使用jwt token才能访问的服务,在没有jwt token的情况下,将会返回401 未授权.

## 服务图

<img src="/post/迈向istio/8-jwt认证/服务图.png"/>

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

## 路由及jwt配置

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
---
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "jwt-example"
  namespace: "test"
spec:
  targets:
  - name: target
  origins:
  - jwt:
      issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/master/security/tools/jwt/samples/jwks.json"
#  originIsOptional: true
  principalBinding: USE_ORIGIN
```

### 在istio中部署此配置

```shell
$ kubectl apply -f istio.yaml -n test
```

## 测试配置

```shell
#现在我们通过gateway访问target 这个服务
$ curl 网关地址/target/index
#返回401
#那我们再使用`jwt token`来访问呢
$ TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/master/security/tools/jwt/samples/demo.jwt -s)
$  curl --header "Authorization: Bearer $TOKEN" 网关地址/target/index -v
#返回200 index
```

## 注意

- jwt证书下发需要一定时间,不会立即生效
- `originIsOptional=true`可以设置在没有jwt认证成功的情况下也可以访问,那么这个访问权限就由下层(授权层)来决定
- `jwks.json`描述的是**公钥**
- 现在对于服务的jwt配置是服务内所有的地址都应用jwt,在**istio1.1**中会有`包含url`,`排除url`等配置
- **jwt是针对认证的!**

## 清理

```shell
$ kubectl delete namespace/test
```