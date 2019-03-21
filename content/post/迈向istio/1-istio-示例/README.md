---
title: "迈向istio-示例"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- istio
tags:
- istio
keywords:
- istio
---

# istio-示例

[TOC]

在上一节中我们已经成功的安装了istio的各个组件,接下来我们一起来运行一个nginx,体验一下istio的功能

## nginx示例

nginx.yaml文件如下:

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
 name: nginx
 namespace: test
 labels:
   app: nginx
   version: v1
spec:
 template:
    metadata:
     labels:
       app: nginx
       version: v1
    spec:
     containers:
     - name: nginx
       image: nginx
       ports:
       - containerPort: 80
         name: http
         protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  name: nginx
  namespace: test
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - port: 7890
      protocol: TCP
      targetPort: 80
```
### 在kubernetes中创建命名空间test

```shell
$ kubectl create namespace test
#在istio中开启自动sidecar注入,如果不能支持自动注入,则使用下面的方式
$ kubectl label namespace test istio-injection=enable
#使用istioctl注入sidecar
$ istioctl kube-inject -f nginx.yaml -o nginx-injected.yaml 
```
### 部署应用

```shell
$ kubectl create -f nginx-injected.yaml 
```

### 查看应用情况

```shell
tangxu@tangxu-pc:~$ kubectl get all -n test
NAME                        READY   STATUS    RESTARTS   AGE
pod/nginx-78cf67dbd-cfdh8   2/2     Running   0          2h

NAME            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/nginx   ClusterIP   10.99.33.160   <none>        7890/TCP   2h

NAME                    DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx   1         1         1            1           3h

NAME                               DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-6c7ccc4d45   0         0         0       3h
replicaset.apps/nginx-78cf67dbd    1         1         1       2h
```

> 一定注意,pod中的容器是2个.

### 使用istio流量管理

创建文件nginx-istio.yaml

```yaml
#声明网关
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: nginxgateway
  namespace: test #
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
#声明路由
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: nginxvirtualservice
  namespace: test
spec:
  hosts:
  - "*"
  gateways:
  - nginxgateway
  http:
  - match:
    - uri:
        prefix: /test #路由
    rewrite:
      uri: "/" #重写url
    route:
    - destination:
       host: nginx
       subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: nginxdestinationrule
  namespace: test
spec:
  host: nginx
  subsets:
  - name: v1
    labels:
      app: nginx
      version: v1
```

### 使用istio部署此文件

```
$ istioctl create -f nginx-istio.yaml
```

验证应用是否部署成功

```yaml
tangxu@tangxu-pc:~$ curl http://10.6.73.55:31380/test -v
*   Trying 10.6.73.55...
* TCP_NODELAY set
* Connected to 10.6.73.55 (10.6.73.55) port 31380 (#0)
> GET /test HTTP/1.1
> Host: 10.6.73.55:31380
> User-Agent: curl/7.60.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< server: envoy
< date: Tue, 23 Oct 2018 09:54:29 GMT
< content-type: text/html
< content-length: 612
< last-modified: Tue, 02 Oct 2018 14:49:27 GMT
< etag: "5bb38577-264"
< accept-ranges: bytes
< x-envoy-upstream-service-time: 3
< 
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

### 查看istio各种仪表盘

```shell
tangxu@tangxu-pc:~$ kubectl get service -n istio-system
NAME                       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                                                                                   AGE
grafana                    NodePort    10.111.139.30    <none>        3000:31978/TCP                                                                                                            4h
istio-citadel              ClusterIP   10.106.229.144   <none>        8060/TCP,9093/TCP                                                                                                         4h
istio-egressgateway        ClusterIP   10.96.22.182     <none>        80/TCP,443/TCP                                                                                                            4h
istio-galley               ClusterIP   10.107.252.51    <none>        443/TCP,9093/TCP                                                                                                          4h
istio-ingressgateway       NodePort    10.103.0.73      <none>        80:31380/TCP,443:31390/TCP,31400:31400/TCP,15011:31524/TCP,8060:30507/TCP,853:31293/TCP,15030:32557/TCP,15031:31969/TCP   4h
istio-pilot                ClusterIP   10.98.212.161    <none>        15010/TCP,15011/TCP,8080/TCP,9093/TCP                                                                                     4h
istio-policy               ClusterIP   10.96.248.139    <none>        9091/TCP,15004/TCP,9093/TCP                                                                                               4h
istio-sidecar-injector     ClusterIP   10.111.135.28    <none>        443/TCP                                                                                                                   4h
istio-statsd-prom-bridge   ClusterIP   10.111.240.15    <none>        9102/TCP,9125/UDP                                                                                                         4h
istio-telemetry            ClusterIP   10.108.66.51     <none>        9091/TCP,15004/TCP,9093/TCP,42422/TCP                                                                                     4h
jaeger-agent               ClusterIP   None             <none>        5775/UDP,6831/UDP,6832/UDP                                                                                                4h
jaeger-collector           ClusterIP   10.99.92.164     <none>        14267/TCP,14268/TCP                                                                                                       4h
jaeger-query               ClusterIP   10.103.249.192   <none>        16686/TCP                                                                                                                 4h
prometheus                 ClusterIP   10.99.4.46       <none>        9090/TCP                                                                                                                  4h
prometheus-nodeport        NodePort    10.100.130.42    <none>        9090:32090/TCP                                                                                                            4h
servicegraph               NodePort    10.96.147.205    <none>        8088:32756/TCP                                                                                                            4h
tracing                    ClusterIP   10.109.29.44     <none>        80/TCP                                                                                                                    4h
zipkin                     NodePort    10.110.200.41    <none>        9411:31037/TCP                                                                                                            4h

```

### 清理

```shell
$ kubectl delete namespace/test
```

