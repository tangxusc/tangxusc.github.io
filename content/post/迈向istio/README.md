---
title: "迈向istio-安装"
date: 2019-03-20T14:15:59+08:00
draft: false
---

# istio-安装

[TOC]

## 下载istio的release

```shell
curl -L https://git.io/getLatestIstio | sh -
cd istio-1.0.2
#设置环境变量,以便后面可以执行istioctl命令
export PATH=$PWD/bin:$PATH
```

## 下载helm

```shell
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz
tar zxvf helm-v2.11.0-linux-amd64.tar.gz
#或者使用我给你下载的
wget https://gitee.com/tanx/kubernetes-test/raw/master/helm/helm-v2.11.0-linux-amd64.tar
tar zxvf helm-v2.11.0-linux-amd64.tar.gz

export PATH=$PWD/linux-amd64/:$PATH
```

## 开始安装

```shell
$ kubectl apply -f install/kubernetes/helm/istio/templates/crds.yaml
```

有两种方式均可以安装istio,这里我们使用helm生成yaml的方式(因为helm的方式安装的istio,不用再去自己下载gcr.io中的镜像)

因为我本人使用的是本地电脑,所以我需要对istio安装的参数进行一定的修改,具体修改如下:

1. 复制一个新的istio-1.0.2/install/kubernetes/helm/istio/values.yaml文件出来

2. 修改gateways为NodePort

   ```yaml
   gateways:
     enabled: true
   #省略n多节点
       type: ClusterIP #修改为NodePort
   ```

3. 启用grafana,将grafana节点下的enabled修改为true

   ```yaml
   grafana:
     enabled: false #修改为true
     #省略...
     service:
       annotations: {}
       name: http
       type: ClusterIP #修改为NodePort
       externalPort: 3000
       internalPort: 3000
   ```

4. 启用prometheus

   ```yaml
   prometheus:
     enabled: true
     replicaCount: 1
     hub: docker.io/prom
     tag: v2.3.1
   
     service:
       annotations: {}
       nodePort:
         enabled: false #修改为true
         port: 32090
   ```

5. 启用servicegraph

   ```yaml
   servicegraph:
     enabled: false #修改为true
     replicaCount: 1
     image: servicegraph
     service:
       annotations: {}
       name: http
       type: ClusterIP #修改为NodePort
       externalPort: 8088
       internalPort: 8088
   ```

6. 启用jaeger

   ```yaml
   tracing:
     enabled: false #修改为true
     provider: jaeger
     #省略...
     service:
       annotations: {}
       name: http
       type: ClusterIP #修改为NodePort
       externalPort: 9411
       internalPort: 9411
   ```

7. (可选) 修改追踪

   ```yaml
   pilot:
     enabled: true
     replicaCount: 1
     autoscaleMin: 1
     autoscaleMax: 5
     image: pilot
     sidecar: true
     traceSampling: 1.0 #修改为100.0,默认采样1%,但是在测试阶段 可以采取大量采样模式
   ```

8. (可选) 启用kiali

   ```yaml
   kiali:
     enabled: false #修改为true
     replicaCount: 1
     hub: docker.io/kiali
     tag: v0.9
     ingress:
   ```


   修改完成后保存文件

```shell
$ helm template install/kubernetes/helm/istio --name istio --namespace istio-system -f 修改后的value路径.yaml > ./istio.yaml
$ kubectl create namespace istio-system
$ kubectl apply -f ./istio.yaml
```

> 在安装istio的过程中某一些镜像下载的时间过长,请耐心等待.


## 确认安装

```shell
tangxu@tangxu-pc:~$ kubectl get all -n istio-system
NAME                                            READY   STATUS      RESTARTS   AGE
pod/grafana-75485f89b9-sv7dd                    1/1     Running     0          4h
pod/istio-citadel-84fb7985bf-dfbw7              1/1     Running     0          4h
pod/istio-cleanup-secrets-knqpr                 0/1     Completed   0          4h
pod/istio-egressgateway-bd9fb967d-dxgjw         1/1     Running     0          4h
pod/istio-galley-655c4f9ccd-g9m6p               1/1     Running     0          4h
pod/istio-grafana-post-install-nj4kh            0/1     Completed   0          4h
pod/istio-ingressgateway-688865c5f7-sszft       1/1     Running     0          4h
pod/istio-pilot-6cd69dc444-jhgmr                2/2     Running     0          4h
pod/istio-policy-6b9f4697d-pv6bx                2/2     Running     0          4h
pod/istio-sidecar-injector-8975849b4-j9mwx      1/1     Running     0          4h
pod/istio-statsd-prom-bridge-7f44bb5ddb-g7vrf   1/1     Running     0          4h
pod/istio-telemetry-6b5579595f-24mj5            2/2     Running     0          4h
pod/istio-tracing-ff94688bb-976q2               1/1     Running     0          4h
pod/prometheus-84bd4b9796-gz6tw                 1/1     Running     0          4h
pod/servicegraph-749b5b897c-wfb79               1/1     Running     3          4h
```

所有组件都running后,则标示安装成功.

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

### 各仪表盘地址

```shell
grafana 			http://node:31978
ingressgateway		http://node:31380
prometheus			http://node:32090
servicegraph		http://node:32756
tracing				http://node:31037
```

### 仪表盘预览

<img src="/post/迈向istio/istio+Naftis+Kiali.gif"/>

[Installation with Helm]: https://istio.io/docs/setup/kubernetes/helm-install/	"istio安装"
[install helm]: https://github.com/helm/helm/releases	"helm安装"
[istio 流量管理]: https://istio.io/docs/concepts/traffic-management/	"istio流量管理"













