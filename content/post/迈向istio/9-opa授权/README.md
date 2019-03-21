---
title: "迈向istio-opa授权"
date: 2019-03-20T14:15:59+08:00
draft: false
---

# istio-opa授权

[TOC]

## 背景

在上一章节中,我们使用jwt进行了认证,那么我们如何对资源进行授权检查呢?

在istio中,我们一个请求实际的调用链,我们来看看一个请求的流程图:

```flow
start=>start: 请求 
end=>end: 结束 
gateway=>operation: gateway
target=>operation: 目标服务
out401=>inputoutput: 返回401
out200=>inputoutput: 返回200
mixer=>condition: mixer-check 

start->gateway->mixer
mixer(no)->out401
mixer(yes)->target->out200
```

一个请求在到达网关后,需要请求mixer-check进行请求的授权验证,对于符合此授权验证的,则开始请求目标服务,如果不符合的,那么则会直接拒绝这个请求,向前端返回401/403

那么我们如何接入istio的授权验证呢?看过istio的可能会说istio提供了rbac的handler,那么这里有必要分析一下,istio提供的rbac的handler有什么要求.

- istio中所有的认证和授权都希望我们将信息放在istio的系统中,这样在本地就完成了认证和授权,则会少一次链路调用
- rbac的handler需要将授权信息以特定格式放在k8s的文件系统中,或者存放在k8s的etcd中
- 

那么这有什么缺陷呢?

- 有一些信息放在istio中是可以的,例如jwt的公钥,这样可以加快认证
- 授权信息放在k8s还是有待商榷的,权限是用户\*资源\*权限的集合,这个集合比较大,放在etcd中是否不太合适呢?
- 有一些地址不需要检查权限

那么我们如何解决这些问题呢? 通过查找istio文档,找到了另外一种`open policy agent(简称OPA)` Handler,我们看看opa官方的介绍:

> OPA是一种轻量级的通用策略引擎，可以与您的服务共存。您可以将OPA集成为边车，主机级守护程序或库。
>
> 服务通过执行*查询*将策略决策卸载到OPA 。OPA评估策略和数据以生成查询结果（将其发送回客户端）。策略使用高级声明性语言编写，可以通过文件系统或定义良好的API加载到OPA中。

现在opa已经内置在mixer中(istio 1.0.4),可以为我们提供了一种mixer之外的认证模式:

<img src="/post/迈向istio/9-opa授权/opa.png"/>


## 流程图

```flow
start=>start: 请求 
end=>end: 结束 
gateway=>operation: gateway
target=>operation: 目标服务
gateway=>operation: gateway
out401=>inputoutput: 返回401
out200=>inputoutput: 返回200
opa认证=>subroutine: opa认证 
mixer=>operation: mixer-check 
认证服务=>condition: 认证服务 

start->gateway->mixer->opa认证->认证服务
认证服务(no)->out401
认证服务(yes)->target->out200
```

## istio中的`rule`/`handler`/`instance`

在istio中我们需要理解`rule` `handler` `instance`这三个对象,这里我简要说明一下这三个对象

### handler

> 适配器封装了 Mixer 和特定外部基础设施后端进行交互的必要接口，例如 [Prometheus](https://prometheus.io/) 或者 [Stackdriver](https://cloud.google.com/logging)。各种适配器都需要参数配置才能工作。例如日志适配器可能需要 IP 地址和端口来进行日志的输出。

说白了,handler也就是一个适配器模式做成的小的服务,通过此服务对接各种的后端.

### instance

> 配置实例将请求中的属性映射成为适配器的输入。

在isito中,mixer将请求的所有信息都看做属性,那么属性和hander输入参数之间的映射关系,则由instance维护

### rule

> 规则用于指定使用特定实例配置调用某一 Handler 的时机。

规则就是用于告诉istio,什么时候,什么条件下,调用那个instance完成参数转换,然后输入到handler中.

在清楚了这些地方以后,我们拉开大幕,开始我们的配置.

## 构建认证镜像

`auth.go`

```go
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/index", index)
	http.HandleFunc("/auth", authHandler)
	serve := http.ListenAndServe("0.0.0.0:8090", nil)
	if serve != nil {
		log.Fatalf("启动失败,%v", serve)
	} else {
		fmt.Fprintf(os.Stdout, "启动成功")
	}
}

func authHandler(writer http.ResponseWriter, request *http.Request) {
	fmt.Printf("authHandler请求begin\n")
	for key, value := range request.Form {
		fmt.Printf("请求参数 [%s]:%s \n", key, value)
	}
	for key, value := range request.Header {
		fmt.Printf("header参数 [%s]:%s \n", key, value)
	}
	writer.WriteHeader(401)
	fmt.Fprintf(writer, "%s", "401")
	fmt.Printf("authHandler请求end\n")
}

func index(writer http.ResponseWriter, request *http.Request) {
	fmt.Printf("index请求begin\n")
	for key, value := range request.Form {
		fmt.Printf("请求参数 [%s]:%s \n", key, value)
	}
	for key, value := range request.Header {
		fmt.Printf("header参数 [%s]:%s \n", key, value)
	}
	fmt.Fprintf(writer, "%s", "index")
	fmt.Printf("index请求end\n")

}
```

构建镜像:

```shell
$ go build auth.go
$ docker build -t auth:go-1 .
```

## 部署k8s的服务

`k8s.yaml`

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
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
 name: auth
 namespace: test
 labels:
   app: auth
   version: v1
spec:
 template:
    metadata:
     labels:
       app: auth
       version: v1
    spec:
     containers:
     - name: auth
       image: auth:go-1
       ports:
       - containerPort: 8090
         name: http
         protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  name: auth
  namespace: test
spec:
  selector:
    app: auth
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
### 配置路由

`router.yaml`

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
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: auth
  namespace: test
spec:
  hosts:
  - "*"
  gateways:
  - target
  http:
  - match:
    - uri:
        prefix: /auth/
    rewrite:
      uri: "/"
    route:
    - destination:
       host: auth
       subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: auth
  namespace: test
spec:
  host: auth
  subsets:
  - name: v1
    labels:
      app: auth
      version: v1
```

可以看到这里的配置和以前并没有太多的变化,只是新增了一个auth的服务

### 部署opa认证

`auth.yaml`

```yaml
---
apiVersion: "config.istio.io/v1alpha2"
kind: authorization
metadata:
  name: auth
  namespace: test
spec:
 subject:
   user: destination.service
   groups: destination.service
   properties:
    iss: destination.service
 action:
   namespace: destination.namespace | "default"
   service: destination.service | ""
   path: request.path | "/"
   method: request.method | "post"
   properties:
     version: destination.name | ""
---
apiVersion: config.istio.io/v1alpha2
kind: opa
metadata:
  name: handler
  namespace: test
spec:
  policy:
    - |+
      package authz
      default allow=false
      allow = true {
       http.send({"method": "GET", "url": "http://auth.test.svc.cluster.local/auth?a=1","body": {"a": "1" } } , output)
        output.status_code=200
      }
  checkMethod: "data.authz.allow"
  failClose: true
---
apiVersion: config.istio.io/v1alpha2
kind: rule
metadata:
  name: authrule
  namespace: test
spec:
  match: destination.service == "target.test.svc.cluster.local"
  actions:
  - handler: handler.opa.test
    instances:
    - auth.authorization.test
```

在`kind: opa`中,我们使用了opa的一个内置函数 http.send()发送一个请求到auth服务进行认证,如果auth返回200则标示认证成功,如果返回其他状态码则标示认证失败.

> http.send()释义
>
> `http.send`执行HTTP请求并返回响应。`request`是一个包含键的对象`method`，`url`也可以`body`是`enable_redirect`和`headers`。例如，`http.send({"method": "get", "url": "http://www.openpolicyagent.org/", "headers": {"X-Foo":"bar", "X-Opa": "rules"}}, output)`。`output`为含有键的对象`status`，`status_code`并且`body`它们分别代表HTTP状态，状态码和应答体。样本输出，`{"status": "200 OK", "status_code": 200, "body": null`}。默认情况下，不会启用http重定向。要启用，请设置`enable_redirect`为`true`。

## 测试

```shell
$ curl 网关地址/target/index -v
#返回 401
```

## 注意

- jwt可以配合使用,以实现认证授权
- opa使用`rego`语言进行处理,**不过这语言很魔性**
- 这里链路有3跳,网关>mixer>认证,性能是有一定损失的(不过不大,很多人可能又要逼逼了,不过逼逼的人恰好暴露了自己的目光短浅)
- 具体的业务服务在应用此模式后,不再管权限了,那么每个到服务的请求都应该进行处理
- 在自己做测试的时候,请多**注意多观察日志**,istio的问题不怎么好排查
- **认证服务一定只有一个认证接口,不要有其他接口**,因为访问其他接口也会进行一次认证,多了一跳链路
- 推荐**event bus**方式协同
- TODO: 现在的示例中,我们是直接访问的auth的服务,没有解析instance中的参数,需要自行测试参数解析

## 清理

```shell
$ kubectl delete namespace/test
```