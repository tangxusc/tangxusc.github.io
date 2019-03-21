---
title: "迈向istio-服务路由"
date: 2019-03-20T14:15:59+08:00
draft: false
---

# 服务路由

[TOC]

在上一节中,我们使用nginx开启了我们istio的第一个应用,现在我们加入另外一个服务tomcat

> 本节内容基于上节内容,请先运行上一节的yaml文件,然后再体验本节内容

## tomcat

tomcat.yaml文件如下:

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
 name: tomcat
 namespace: test
 labels:
   app: tomcat
   version: v1
spec:
 template:
    metadata:
     labels:
       app: tomcat
       version: v1
    spec:
     containers:
     - name: tomcat
       image: tomcat:8
       ports:
       - containerPort: 8080
         name: http
         protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  name: tomcat
  namespace: test
spec:
  type: ClusterIP
  selector:
    app: tomcat
  ports:
    - port: 8890
      protocol: TCP
      targetPort: 8080
```
### 创建tomcat服务

```shell
$ istioctl kube-inject -f tomcat.yaml | kubectl apply -f -
```
### 创建服务路由

使用yaml创建两个路由:

```shell
/nginx---->service/nginx:7880
/tomcat--->service/tomcat:8890
```

创建文件istio.yaml

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: test
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
  name: nginx
  namespace: test
spec:
  hosts:
  - "*"
  gateways:
  - test
  http:
  - match:
    - uri:
        prefix: /nginx
    rewrite:
      uri: "/"
    route:
    - destination:
       host: nginx
       subset: v1
  - match:
    - uri:
        prefix: /tomcat
    rewrite:
      uri: "/"
    route:
    - destination:
       host: tomcat
       subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: nginx
  namespace: test
spec:
  host: nginx
  subsets:
  - name: v1
    labels:
      app: nginx
      version: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: tomcat
  namespace: test
spec:
  host: tomcat
  subsets:
  - name: v1
    labels:
      app: tomcat
      version: v1
```

### 使用istio部署此文件

```
$ istioctl create -f nginx-istio.yaml
```

验证应用是否部署成功

```yaml
tangxu@tangxu-pc:~ curl http://10.103.0.73/tomcat -v
*   Trying 10.103.0.73...
* TCP_NODELAY set
* Connected to 10.103.0.73 (10.103.0.73) port 80 (#0)
> GET /tomcat HTTP/1.1
> Host: 10.103.0.73
> User-Agent: curl/7.60.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< content-type: text/html;charset=UTF-8
< date: Thu, 25 Oct 2018 07:09:48 GMT
< x-envoy-upstream-service-time: 3
< server: envoy
< transfer-encoding: chunked
```

### 清理

```shell
$ kubectl delete namespace/test
```

