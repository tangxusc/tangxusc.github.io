---
title: "Local Persistent Volume 介绍"
date: 2019-05-20T15:34:24+08:00
categories:
- k8s
- volume
tags:
- volume
- local PV
keywords:
- volume
#thumbnailImage: //example.com/image.jpg
---

在kubernetes中,存储一直是一个较为头疼的问题,在面对持久化存储,我们可以选择各种文件系统,但是对于那些临时存储的文件,我们则需要一种本地存储的能力,在kubernetes1.14中为我们提供了一种本地存储`localPV`,本文将围绕此展开.

<!--more-->

在4月,kubernetes发布了新的版本1.14,其中对windows节点有了支持,但是其中对于应用程序开发来说最大的一个亮点是,Local PersistentVolume 发布了GA版本.

## 那么什么是本地持久卷呢?

本地持久卷表示直接连接到node的本地磁盘卷.

再明确一点说就是node本身提供的磁盘作为卷来供pod使用,也就类似docker的volume方式直接可以挂载宿主机目录.

在kubernetes中也有直接使用node磁盘的卷`hostpath`,我们可以从以下几个方面进行对比:

`hostpath`:

- 绑定在pod的生命周期上,pod结束,pv则被删除. 

- 可以通过pvc引用,也可以直接使用pv
- 使用node的磁盘,不经过网络,开销非常小

`本地持久卷`:

- 生命周期和node绑定,Kubernetes调度程序始终确保使用本地永久卷的Pod安排到同一节点
- 无法通过storageclass动态创建.
- 使用node磁盘,不经过网络,开销非常小.

在了解了`本地持久卷`之后我们一定要了解几个问题:

- 本地持久卷依然会丢失数据,例如node本身出了问题.

- 本地持久卷需要提供`volumeBindingMode:WaitForFirstConsumer`支持
- 不支持动态卷配置,实际上需要一个外部的controller来控制,包括创建pv和销毁pv并清理磁盘

## 示例

我们将创建一个statefulset使用local pv,并使用service将服务暴露出来

`localPV.yaml`内容如下

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 2Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /home/tangxu/localpv
  # 比普通的pv就多了这个亲和性调度
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - tangxu-pc
---
kind: Service
apiVersion: v1
metadata:
  name: local-pv-service
spec:
  selector:
    app: local-test
  clusterIP: None
  ports:
    - port: 8090
      targetPort: 80
      protocol: tcp
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: local-test
spec:
  serviceName: "local-pv-service"
  replicas: 3
  selector:
    matchLabels:
      app: local-test
  template:
    metadata:
      labels:
        app: local-test
    spec:
      containers:
        - name: test-container
          image: nginx:latest
          ports:
            - containerPort: 80
              protocol: tcp
              name: http
          volumeMounts:
            - name: local-vol
              mountPath: /usr/test-pod
  volumeClaimTemplates:
    - metadata:
        name: local-vol
      spec:
        accessModes:
          - "ReadWriteMany"
        storageClassName: "local-storage"
        resources:
          requests:
            storage: 1Gi
```

接下来我们创建命名空间`test`作为演示

```shell
$ kubectl create ns test
namespace/test created
$ kubectl apply -f localPV.yaml
```

接下来就可以看到服务的正确运行了

```shell
$ kubectl get all
NAME               READY   STATUS    RESTARTS   AGE
pod/local-test-0   1/1     Running   0          8m57s

NAME                       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
service/local-pv-service   ClusterIP   None         <none>        8090/TCP   8m57s

NAME                          READY   AGE
statefulset.apps/local-test   1/1     8m57s
```

### 清理

在使用了local pv之后,清理就不再是简单的使用命令删除了,因为kubernetes不会为我们管理local pv的创建和删除工作(并且删除是阻塞的,主要依靠`finalizer`机制)

那么整体的清理步骤如下:

```shell
#先删除使用pv的资源
$ kubectl delete -f localPV.yaml
persistentvolume "example-pv" deleted
service "local-pv-service" deleted
statefulset.apps "local-test" deleted
#此处应该阻塞...
```

再起一个终端,执行如下命令:

```shell
$ kubectl patch pv example-pv -p '{"metadata":{"finalizers": []}}' --type=merge
```

在执行完成此命令后,pv才会真正的被删除,终端的阻塞才会结束.

## 实际使用场景

了解了local pv后,那么使用场景在什么地方呢?

- 使用本地磁盘作为缓存的系统
- ci/cd中用于存储构建中的文件
- 一些允许丢失和不需要保证可靠的数据(session,token)

## 参照

[Kubernetes 1.14：本地持续卷GA](https://kubernetes.io/blog/2019/04/04/kubernetes-1.14-local-persistent-volumes-ga/)

[HostPath卷](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath)

[垃圾回收机制](/2019/05/kubelet垃圾回收机制/)

[官方文档](https://kubernetes.io/docs/concepts/storage/volumes/#local)

