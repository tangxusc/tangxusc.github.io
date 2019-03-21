---
title: "迈向istio-镜像流量"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- istio
tags:
- istio
keywords:
- istio
---
# istio-镜像流量

[TOC]

我们在前面几个章节中使用了两个服务(proxy,target),现在我们想对target进行一次升级,但是现在我们这个代码写的还不够好(没人能说他的代码一次就是期望的行为),希望通过复制一部分现在的流量 用来测试这个服务是否正确,那么这个时候就会使用到istio的镜像流量功能了

好了,大幕拉开,开始我们的表演.

## 服务图

<img src="/post/迈向istio/6-镜像流量/服务图.png"/>

### target代码

serviceProxy2.go

```go
package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/proxy", handler)
	http.HandleFunc("/index", indexHandler)
	serve := http.ListenAndServe("0.0.0.0:8090", nil)
	if serve != nil {
		log.Fatalf("启动失败,%v", serve)
	} else {
		fmt.Fprintf(os.Stdout, "启动成功")
	}
}

func handler(writer http.ResponseWriter, request *http.Request) {
	fmt.Printf("我是v2的proxy请求begin\n")	
	fmt.Printf("我是v2的proxy请求begin\n")
	request.ParseForm()
	get := request.Form.Get("url")
	fmt.Printf("我是v2的请求地址:%s\n", get)
	for key, value := range request.Form {
		fmt.Printf("我是v2的请求参数 [%s]:%s \n", key, value)
	}
	for key, value := range request.Header {
		fmt.Printf("我是v2的header参数 [%s]:%s \n", key, value)
	}

	client := http.DefaultClient
	newRequest, e := http.NewRequest("GET", get, nil)
	if e != nil {
		fmt.Printf("我是v2的NewRequest error: %v", e)
	}

	//设置header
	//for key, _ := range request.Header {
	//	newRequest.Header.Add(key, request.Header.Get(key))
	//	fmt.Printf("设置转发请求header [%s]:%s \n", key, request.Header.Get(key))
	//}
	if len(request.Header.Get("x-request-id")) > 0 {
		newRequest.Header.Set("x-request-id", request.Header.Get("x-request-id"))
	}
	if len(request.Header.Get("x-b3-traceid")) > 0 {
		newRequest.Header.Set("x-b3-traceid", request.Header.Get("x-b3-traceid"))
	}
	if len(request.Header.Get("x-b3-spanid")) > 0 {
		newRequest.Header.Set("x-b3-spanid", request.Header.Get("x-b3-spanid"))
	}
	if len(request.Header.Get("x-b3-parentspanid")) > 0 {
		newRequest.Header.Set("x-b3-parentspanid", request.Header.Get("x-b3-parentspanid"))
	}
	if len(request.Header.Get("x-b3-sampled")) > 0 {
		newRequest.Header.Set("x-b3-sampled", request.Header.Get("x-b3-sampled"))
	}
	if len(request.Header.Get("x-b3-flags")) > 0 {
		newRequest.Header.Set("x-b3-flags", request.Header.Get("x-b3-flags"))
	}
	if len(request.Header.Get("x-ot-span-context")) > 0 {
		newRequest.Header.Set("x-ot-span-context", request.Header.Get("x-ot-span-context"))
	}

	resp, err := client.Do(newRequest)
	//resp, err := http.Get(get)
	if err != nil {
		fmt.Fprintf(writer, "response:%v", err)
	} else {
		bytes, _ := ioutil.ReadAll(resp.Body)
		defer resp.Body.Close()
		fmt.Fprintf(writer, "%s", bytes)
	}
	fmt.Printf("我是v2的proxy请求end\n")
}

func indexHandler(writer http.ResponseWriter, request *http.Request) {
	fmt.Printf("我是v2的index请求begin\n")
	for key, value := range request.Form {
		fmt.Printf("我是v2的请求参数 [%s]:%s \n", key, value)
	}
	for key, value := range request.Header {
		fmt.Printf("我是v2的header参数 [%s]:%s \n", key, value)
	}
	fmt.Fprintf(writer, "%s", "index")
	fmt.Printf("我是v2的index请求end\n")

}
```
可以看到,其实就是在输出上加了一个`我是v2`的前缀

将target v2编译并做成镜像:

```shell
$ go build serviceProxy2.go
$ docker build -t service-proxy:go-2 -f go-Dockerfile .
```

### 在k8s中部署服务

```shell
$ kubectl apply -f <(istioctl kube-inject -f k8s.yaml) -n test
$ istioctl create -f istio.yaml -n test
```
### 验证配置

<img src="/post/迈向istio/6-镜像流量/服务图.png"/>

好了,现在可以开始我们正式的表演

1. 使用kubectl logs -f 查看这两个pod(target,target2)的日志

   ```shell
   $ kubectl logs -f target2-544c4fbb6-4zvzm -n test -c target
   $ kubectl logs -f target-85fb8c6f7f-2cxpb -n test -c target
   ```

2. 使用curl访问target

   ```shell
   $ curl 10.108.228.41/target/index
   ```

现在就可以看到实际上流量到达的是target,但是新的版本v2也接收到了请求的流量,那么我们再看kiali上的展示:

<img src="/post/迈向istio/6-镜像流量/效果.png"/>

### 配置说明

那么这个功能如何做到的呢,其实只需要在yaml中做一点小配置

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: test4
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
  name: proxy
  namespace: test
spec:
  hosts:
  - "*"
  gateways:
  - test4
  http:
  - match:
    - uri:
        prefix: /proxy/
    rewrite:
      uri: "/"
    route:
    - destination:
       host: proxy
       subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: proxy
  namespace: test
spec:
  host: proxy
  subsets:
  - name: v1
    labels:
      app: proxy
      version: v1
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
  - test4
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
    mirror: #加入了mirror节点,指明镜像流量发送到什么地址
     host: target
     subset: v2
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
#创建了一个新的 DestinationRule用来指定version=v2的pod接受流量
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: target2
  namespace: test
spec:
  host: target
  subsets:
  - name: v2
    labels:
      app: target
      version: v2
```
注意:

- 镜像流量不能传多个
- 镜像流量现在只能使用labels来标记到那个pod,也就是说pod上要能通过label区分
- 镜像的流量是不会在kiali中展示的,并且在jaeger中也是区分不出来的,需要自己添加一些手段来区分(也就是说没有任何地方会记录...)
- DestinationRule可以写为多个也可以写为一个,subsets中可以有多个值

## 清理

```shell
$ kubectl delete namespace/test
```

