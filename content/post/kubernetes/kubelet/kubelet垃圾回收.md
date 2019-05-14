---
title: "kubelet垃圾回收机制"
date: 2019-05-14T14:15:59+08:00
draft: false
categories:
- k8s
- kubelet
tags:
- k8s
- kubelet
- gc
keywords:
- k8s
- kubelet
- gc
---

在k8s中节点会通过docker pull机制获取外部的镜像,那么什么时候清除镜像呢?
k8s运行的容器又是什么时候清除呢?

<!--more-->

我们再次回到我们刚学k8s的时候,我们学到k8s由几个重要的组件组成,那么现在我们从垃圾收集的角度去看待这几个组件:

- api-server: 运行在master,无状态组件,go自动内存垃圾回收
- controller-manager:运行在master,无状态组件,go自动内存垃圾回收,owner机制提供resource垃圾回收
- scheduler:运行在master,无状态组件,go自动内存垃圾回收
- kubelet:运行在node,无状态组件,需要管理宿主机的image和container
- kube-proxy:运行在node,无状态组件,无垃圾收集需要

可以看到k8s中的组件大多数都是无状态的(更利于扩展和高可用),其中controller-manager和kubelet具备了垃圾回收功能,接下来我们就来了解一下这两个组件的垃圾回收功能

## kubelet

垃圾收集是kubelet的一个有用功能，它将清理未使用的图像和未使用的容器。Kubelet将**每隔五分钟**对容器执行垃圾收集，每五分钟对图像进行垃圾收集。
建议不要使用外部垃圾收集工具，因为这些工具可能会通过删除预期存在的容器来破坏kubelet的行为。

### 镜像垃圾收集

kubelet在cadvisor配合下通过`imageManager`管理所有图像的生命周期.

影响垃圾收集的参数有两个:

`HighThresholdPercent` : 磁盘最大使用率,默认85%.

`LowThresholdPercent` : 磁盘最小使用率,默认80%.

当镜像存放目录(默认为:/var/lib/docker,其中/var为存放目录)磁盘使用率(df -h) 大于 `HighThresholdPercent`后 开始删除节点中未使用的docker镜像,当磁盘使用率降低至`LowThresholdPercent`时,停止镜像的垃圾回收.

> 注意: 在节点中存在一定的image是必要的,因为可以减少docker拉取镜像的速度减少带宽压力,加速容器启动.

### 容器垃圾回收

容器垃圾回收有三个参数:

`MinAge`:容器可以被垃圾回收的最小年龄,默认0分钟,命令行参数为`minimum-container-ttl-duration`

`MaxPerPodContainer`: 每个pod中保留的最大的停止容器数量,默认为1,命令行参数为`maximum-dead-containers-per-container`

`MaxContainers`: 整个节点保留的最大的停止容器数量,默认为-1,标示没有限制,命令行参数为`maximum-dead-containers`

> 通过设置MinAge**为零**并将设置MaxPerPodContainer和MaxContainers**小于零**分别可以单独禁用这些功能。

容器回收过程如下:

pod中的容器停止经过`minimum-container-ttl-duration`后,该容器标记为可以被回收,一个pod最多可以保留`maximum-dead-containers-per-container`个已经停止的容器,整个node可以保留`maximum-dead-containers`个已停止的容器

回收容器时,kubelet将按照创建时间排序,删除那些创建时间最早的容器.

kubelet的配置文件可以在此查看:

```shell
$ cat /var/lib/kubelet/config.yaml

address: 0.0.0.0
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt	#可信的ca证书位置
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
cgroupDriver: cgroupfs
cgroupsPerQOS: true
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
configMapAndSecretChangeDetectionStrategy: Watch
containerLogMaxFiles: 5
containerLogMaxSize: 10Mi
contentType: application/vnd.kubernetes.protobuf
cpuCFSQuota: true
cpuCFSQuotaPeriod: 100ms
cpuManagerPolicy: none
cpuManagerReconcilePeriod: 10s
enableControllerAttachDetach: true
enableDebuggingHandlers: true
enforceNodeAllocatable:
- pods
eventBurst: 10
eventRecordQPS: 5
evictionHard:
  imagefs.available: 15%
  memory.available: 100Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
evictionPressureTransitionPeriod: 5m0s
failSwapOn: true
fileCheckFrequency: 20s
hairpinMode: promiscuous-bridge
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 20s
imageGCHighThresholdPercent: 85	#镜像垃圾收集配置
imageGCLowThresholdPercent: 80
imageMinimumGCAge: 2m0s
iptablesDropBit: 15
iptablesMasqueradeBit: 14
kind: KubeletConfiguration
kubeAPIBurst: 10
kubeAPIQPS: 5
makeIPTablesUtilChains: true
maxOpenFiles: 1000000
maxPods: 110
nodeLeaseDurationSeconds: 40
nodeStatusReportFrequency: 1m0s
nodeStatusUpdateFrequency: 10s
oomScoreAdj: -999
podPidsLimit: -1
port: 10250
registryBurst: 10
registryPullQPS: 5
resolvConf: /etc/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: 2m0s
serializeImagePulls: true
staticPodPath: /etc/kubernetes/manifests		#静态pod地址
streamingConnectionIdleTimeout: 4h0m0s
syncFrequency: 1m0s
volumeStatsAggPeriod: 1m0s
```

## controller-manager

在k8s中有一个专门负责资源回收的controller,名称为`GarbaseCollector`,同时提供了`finalizer`机制,也就是说对象在删除之前,其`ObjectMeta.Finalizers`数组字段中必须为空,例如:

pod本身的删除需要经过a,b,c 这三个步骤,那么pod的整体情况如下:

```yaml
apiVersion: v1
kind: Pod
metadata:
  finalizers:
  - a
  - b
  - c
```

那么此时pod就具有三个finalizer(是不是可以叫终结器?),那么整体运行的情况如下:

1,执行delete pod,pod进入到 **Terminateing**

2,各个controller会并行的收到pod的删除事件,开始执行自己的逻辑.

3,执行完成后,通过修改pod(patch),移除自身对应的`metadata.finalizers`中的值

4,`metadata.finalizers`数组的len为0时,`GarbaseCollector`才会真正的开始自己的工作.

> finalizers中的`foregroundDeletion` 标示 `前台级联删除`

### 级联删除

那么级联的资源怎么删除呢? 在k8s中deployment下管理ReplicaSet,ReplicaSet下管理Pod

那么就形成了一个级联关系:

**deployment 依赖> ReplicaSet  依赖> Pod**

在k8s中 ReplicaSet为 Pod的拥有者,那么 Pod就成了 ReplicaSet的依赖项,每一个Pod都有一个`metadata.ownerReferences`指向拥有者,k8s会为内置的资源设置`ownerReferences`,例如在创建deployment的时候,会自动为ReplicaSet设置ownerReference,当然对于第三方资源需要自己指定ownerReference

kubebuilder示例代码如下:

```go
if err := controllerutil.SetControllerReference(instance, deploy, r.scheme); err != nil {
		return reconcile.Result{}, err
	}

// SetControllerReference sets owner as a Controller OwnerReference on owned.
// This is used for garbage collection of the owned object and for
// reconciling the owner object on changes to owned (with a Watch + EnqueueRequestForOwner).
// Since only one OwnerReference can be a controller, it returns an error if
// there is another OwnerReference with Controller flag set.
func SetControllerReference(owner, object v1.Object, scheme *runtime.Scheme) error {
	ro, ok := owner.(runtime.Object)
	if !ok {
		return fmt.Errorf("is not a %T a runtime.Object, cannot call SetControllerReference", owner)
	}

	gvk, err := apiutil.GVKForObject(ro, scheme)
	if err != nil {
		return err
	}

	// Create a new ref
	ref := *v1.NewControllerRef(owner, schema.GroupVersionKind{Group: gvk.Group, Version: gvk.Version, Kind: gvk.Kind})

	existingRefs := object.GetOwnerReferences()
	fi := -1
	for i, r := range existingRefs {
		if referSameObject(ref, r) {
			fi = i
		} else if r.Controller != nil && *r.Controller {
			return newAlreadyOwnedError(object, r)
		}
	}
	if fi == -1 {
		existingRefs = append(existingRefs, ref)
	} else {
		existingRefs[fi] = ref
	}

	// Update owner references
	object.SetOwnerReferences(existingRefs)
	return nil
}
```

在删除对象时,可以指定是否自动删除对象的依赖项,删除有两种模式: 

`Foreground`: 在`前景删除`模式中,对象首先进入`deletion in progress`状态,在该状态下:

1.通过 rest api 任然可以看到该对象

2.对象的`deletionTimestamp`已设置

3,对象的`metadata.finalizers`字段中包含值`foregroundDeletion`

在前景删除模式中,**首先删除所有的依赖项,然后再删除所有者对象.**

`Background`: 在`后台级联删除`模式中,kubernetes会**立即删除所有者对象**,然后垃圾收集器(GarbaseCollector)会在后台删除依赖项

要控制级联删除策略,请在删除对象时设置参数`propagationPolicy`字段在`deleteOptions`对象上,可选的值为:

`Orphan`, `Foreground`, `Background` ,其中 `Orphan`为孤立的对象

## 参照

[Configuring kubelet Garbage Collection](https://kubernetes.io/docs/concepts/cluster-administration/kubelet-garbage-collection/)

[Garbage Collection](https://kubernetes.io/docs/concepts/workloads/controllers/garbage-collection/)