---
title: "迈向istio-11 升级到1.1.2"
date: 2019-04-01T14:15:59+08:00
categories:
- istio
tags:
- istio
keywords:
- istio
- 1.1.2
#thumbnailImage: //example.com/image.jpg
---

istio经过8个月的发展和社区中的各位大佬的孜孜不倦的贡献,终于发布了1.1版本,新版本为`企业级就绪`

<!--more-->

## 介绍

这8个月中可以看到istio还是发生了很大的变化的,纵观历史,istio进行了三次腾飞:

- 0.8 	不在是模型了
- 1.0 	生产就绪了(其实没有),抛弃了ingress,模型改动比较大
- 1.1	 企业就绪了,理清楚了流量管理的模型,sidecar不再操碎了心,pilot解放了,mixer adapter又被默认的关了,ServiceEntry存在感突然就没啦.

废话太多了,接下来我们进入正题,去看看istio1.1到底更新了那些东西

> 注意,因个人知识有限,不会全部解析,请见谅.

## 升级内容

### 安装

#### 1.安装模式变化

   现在提供了两个helm chart来安装,分别为`istio-init`和`istio` 这两个职责如下:

   `istio-init`: 负责通过`job.batch/istio-init-crd-10`,`job.batch/istio-init-crd-11` 这两个job来安装istio的crd资源(一共53个,如果启用`cert-manager`则为58个),可通过命令查看:

```shell
$ kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l
53
```

   `istio`: 现在istio安装的时候是没有启用`grafana`,`kiali`的,并且已经说明使用`kiali`替换`servicegraph`,所以在安装时,需要手动开启:

```yaml
#
# addon grafana configuration
#
grafana:
  enabled: true
#
# addon kiali tracing configuration
#
kiali:
  enabled: true
  createDemoSecret: true
```

   并且现在支持自定义kiali的用户名密码了,如果还是使用admin/admin 那么就需要`createDemoSecret: true`

   istio现在提供了一个cni组件来避免init-container的privilege问题,不过这个cni需要kubelet的cni支持,kubelet的网络就两种`kubenet`和`cni`,也就是说
   `/etc/systemd/system/kubelet.service.d/10-kubeadm.conf`文件中的

```shell
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
```
   这里的`--network-plugin=cni` 值只能是 `cni`了

   现在轮到mixer自闭了(以前是sidecar忙不过来),默认的check被关闭了,那么你的adapter的check功能就不能用了,如果要使用,那么就需要开启

```yaml
# disablePolicyChecks disables mixer policy checks.
# if mixer.policy.enabled==true then disablePolicyChecks has affect.
# Will set the value with same name in istio config map - pilot needs to be restarted to take effect.
  disablePolicyChecks: false
```

   不过mixer的功能是有了增强,现在能`修改请求`了.

   ServiceEntry这功能现在贼弱了,默认的出流量规则已经变成了允许所有,如要修改可以设置:

```yaml
# Set the default behavior of the sidecar for handling outbound traffic from the application:
# ALLOW_ANY - outbound traffic to unknown destinations will be allowed, in case there are no
#   services or ServiceEntries for the destination port
# REGISTRY_ONLY - restrict outbound traffic to services defined in the service registry as well
#   as those defined through ServiceEntries
# ALLOW_ANY is the default in 1.1.  This means each pod will be able to make outbound requests 
# to services outside of the mesh without any ServiceEntry.
# REGISTRY_ONLY was the default in 1.0.  If this behavior is desired, set the value below to REGISTRY_ONLY.
outboundTrafficPolicy:
  mode: ALLOW_ANY
```


#### 2.提供了一些大家常用的安装模板

   提供了几种常用的安装模板供大家选择

```shell
├── values-istio-demo-auth.yaml
├── values-istio-demo.yaml
├── values-istio-minimal.yaml
├── values-istio-remote.yaml
├── values-istio-sds-auth.yaml
```

   当然,强烈建议你自己修改values.yaml体验istio(不介意的化,你也可以下载我的 [values.yaml]( https://tangxusc.github.io/blog/post/迈向istio/11-升级到1.1.2/values.yaml))

#### 3.改进多集群集成

   多集群提供了新的集成方式,但限于知识体系和篇幅就不在此讲述.

### 流量管理

#### 1.新资源`sidecar`

   新的sidecar资源限制了此命名空间中的某些工作负载(全部,或者通过selecter)的访问范围,在sidecar资源中可以使用ingress和engress**字段**来限制此命名空间可以访问到其他的那些命名空间中的服务,也可以规定流量从那个端口进入

   并且此处的hosts字段的写法也有了一定的变更,现在推荐的写法是:`namespace-name/service.ns.svc.cluster.local`

#### 2.`exportTo`字段

   在1.0中 `DestinationRule,VirtualService,ServiceEntry`都是针对集群内所有的sidecar的,并没有针对单个的sidecar的选项,这导致了sidecar中存在了大量无用的其他命名空间的配置,在1.1中问题得到了**一定**解决,现在通过exportTo字段来决定你的`DestinationRule,VirtualService,ServiceEntry`是否可以暴露给全局或者当前命名空间,可选值如下:

   `.` : 资源在当前命名空间中生效,也就是只会发给当前命名空间的sidecar

   `*` : 资源在所有命名空间中有效,也就是所有的ns中有会有这个资源的记录

   > 从这里也可以看出来,其实没有企业就绪,因为后续可以选择暴露给某个命名空间,某个服务这样才最好

#### 3.基于位置的负载均衡

   要启用基于位置的负载均衡需要在pilot实例中需要设置环境变量`PILOT_ENABLE_LOCALITY_LOAD_BALANCING`

   然后在你的node上用label标注`Region`,`Zone`,`Sub-zone`后,例如:

```shell
Region=us-west
Zone=zone1
#抱歉,k8s不支持sub-zone
```

   进入k8s的集群就有了位置属性了,那么只需要在`MeshConfig`资源中定义`localityLbSetting`为

```yaml
distribute:
  - from: us-west/zone1/*
    to:
      "us-west/zone1/*": 80
      "us-west/zone2/*": 20
  - from: us-west/zone2/*
    to:
      "us-west/zone1/*": 20
      "us-west/zone2/*": 80
```

#### 4.性能提升了

   得益于sidecar资源和exportTo字段,让sidecar不再拥有所有的服务的配置,我们也不用看那么大的一个配置了(起码几千行啊),pilot也不那么累了,整体性能和延时都提升了,用性能最好的版本只有8ms的延迟了

> 详细解析请参照: [Istio1.1新特性之限制服务可见性](http://www.servicemesher.com/blog/istio-service-visibility/)

#### 5.值得注意的gateway

   在这里我一定要把这个拿出来说,虽然文档中只有小小的一句话,但是对于理解istio来说非常重要

   A: gateway中的hosts字段写法也变成了 `ns-name/service.ns.svc.cluster.local`这个模式

   B: (**极其重要**) selector用来选择网关的工作负载,但是推荐的做法是 gateway资源和 istio-ingressgateway 这个容器 放在同一命名空间中,听起来有点绕,咱们把舌头捋顺:

   推荐做法, gateway资源放在运行istio-ingressgateway这个pod的命名空间中.

   其实大部分人安装都是放在istio-system的,那接下来你的gateway都要放在istio-system这里面(istio文档中推荐)

   > 其实,网络入口的控制权限应该更高,所以确实放在istio-system中更好

### 安全

#### 1.k8s的健康检查终于可以用了

   在1.0之前是不能使用健康检查的,因为在启用Policy的https加密后,所有进入sidecar的流量都需要使用https协议并且带上https的证书,但是k8s在进行健康检查的时候,它是真不知道去哪里弄个证书...

> 注意 1.0的时候使用健康检查并且在集群中开启https后会出现pod频繁被杀死,因为健康检查过不了

#### 2.RbacConfig替换为ClusterRbacConfig

  其实在此处有一个比较麻烦的问题,如果使用istio的rbac对于很多用户量较大的企业,就需要生成许多crd的资源应用到k8s中,etcd压力是不小的,个人认为使用mixer中的OPA(open policy agent)或者自定义adapter更为合适.

### 策略和遥测

#### 1.check默认被关闭

   mixer的check功能被关闭了,现在需要手动启动,1.1的性能提高有一点点原因也是得益于关闭了check功能

   那么我们来看看check功能到底有什么问题:

   A: check功能迫使sidecar 和mixs上都需要使用缓存

   B: check功能是阻塞的,必须等到返回才执行下一步

   C: check功能对延时还是影响挺大的,毕竟网关到具体的sidecar要check,sidecar到其他服务又要check

#### 2.终于可以修改请求头了(header)

   在1.0中是不能修改请求的,也就是说check返回的只有`通过/不通过`,不过现在这一情况得到了改善.

   现在用户传入jwt的token,在adapter中校验出结果后,可以直接在header中设置uid等等字段,不用再让下游的服务再去计算一次,减少机房热量

```yaml
apiVersion: config.istio.io/v1alpha2
kind: rule
metadata:
  name: keyval
  namespace: istio-system
spec:
  actions:
  - handler: keyval.istio-system
    instances: [ keyval ]
    name: x
  requestHeaderOperations:
  - name: user-group
    values: [ x.output.value ]
```

  

#### 3. 1.2后就要移除mixer内的adapter了

   现在很多mixer是放在mixer的源码内部的,影响了mixer的发布速度,你想想这么多的adapter,你都要去测试兼容性等等功能,多麻烦啊,丢给提供者自己去测试多好,享受生活

### 配置

#### 1.galley组件现在正式服役

   其实在1.0的版本中该组件就存在,只是现在升级后正式服役了,具体使用方法请参考:

   [Istio 庖丁解牛三：galley](http://www.servicemesher.com/blog/istio-analysis-3/)

### 命令行

#### 1.istioctl 现在只需要了解三个命令

`istioctl experimental verify-install`

`istioctl proxy-config`

`istio proxy-status新的配置示例`

其他的create,get 这些命令被废弃了.

#### 2.kubectl 可以使用 短名称获取istio资源

```shell
#以前 kubelet get virtualservice
#现在
$ kubectl get vs
```


## 个人理解

既然升级了这么多内容,那么istio现在模型就已经有了一次较大的改变,更强调整体性(体现出了istio社区的各位贡献者的孜孜不倦的努力贡献)

- gateway 放在 istio-system 命名空间中
- 每一个命名空间的服务 自己配置自己的 VirtualService,DestinationRule,并在VirtualService中`gateway字段`填写`gateway资源`的名称,**这样把流量引进来**
- 要调用其他命名空间的服务 需要在目标命名空间中 声明VirtualService和DestinationRule,但是并不填写`gateway字段`,但是需要极度[**注意**](https://istio.io/help/ops/traffic-management/deploy-guidelines/#multiple-virtual-services-and-destination-rules-for-the-same-host), 这样 服务间的熔断,故障注入等等功能也就齐活了
- 其他的命名空间如过不需要引用就不做上一步就好了

> 在istio1.0中是不推荐一个host配置多个VirtualService的

## 参考

- [一个host多VirtualService配置](https://istio.io/help/ops/traffic-management/deploy-guidelines/#multiple-virtual-services-and-destination-rules-for-the-same-host)
- [Istio 庖丁解牛三：galley](http://www.servicemesher.com/blog/istio-analysis-3/)
- [基于位置的负载均衡](https://istio.io/help/ops/traffic-management/locality-load-balancing/)
- [istio 1.1发行说明](https://istio.io/about/notes/1.1/)
- [Istio1.1新特性之限制服务可见性](http://www.servicemesher.com/blog/istio-service-visibility/)
- [新的配置示例](https://tangxusc.github.io/blog/post/迈向istio/11-升级到1.1.2/all.yaml)

