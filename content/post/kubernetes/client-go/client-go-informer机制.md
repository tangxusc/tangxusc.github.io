---
title: "Client-Go informer机制"
date: 2019-05-16T15:13:08+08:00
categories:
- k8s
- client
tags:
- k8s
- client-go
- informer
keywords:
- client-go
- client
- informer
#thumbnailImage: //example.com/image.jpg
---

在之前的文章中我们了解了client-go的使用,接下来我们深入的了解一下client-go中的informer机制.

<!--more-->

## client-go介绍

client-go包下主要有以下几个子包:

**[discovery](https://godoc.org/k8s.io/client-go/discovery)**:通过Kubernetes API 进行服务发现

**[dynamic](https://godoc.org/k8s.io/client-go/dynamic)**:对任意Kubernetes对象执行通用操作的动态client

**[informers](https://godoc.org/k8s.io/client-go/informers)**:一个非常牛逼的交互方式,通过reflector watch资源的事件放入队列(DeltaFIFO)中,通过sharedProcessor的pendingNotifications(buffer.RingGrowing)来分发事件到具体的ResourceEventHandler中的OnAdd/OnUpdate/OnDelete进行处理.

**[kubernetes](https://godoc.org/k8s.io/client-go/kubernetes)**:一组内置的clientset集合,在上一篇文章中我们都有用过

**[tools/clientcmd](https://godoc.org/k8s.io/client-go/tools/clientcmd)**:提供了创建客户端的一些基础的工具

> 还有一些其他的包需要自行去了解.. 毕竟这个包里面内容还是比较多.

通过这些包,client-go为我们提供了4种方式来处理资源:

#### REST Client

提供rest的方式与kubernetes交互,提供的方法大多是基于rest协议的方法,例如 get,post,put,delete.

其特点如下:

1,支持json和protobuf

2,支持原生的资源和crd资源

#### ClientSet

client-go调用kubernetes的资源最基础也最实用的方式就是clientSet,并且在上一篇文章中也是使用此方式来调用.

clientset主要根据group,kind和version来获取资源,并提供了可选的namespace字段,其特点如下:

1,十分优雅

2,支持所有原生资源

3,提供了deepCopy,保证了序列化反序列化性能.

#### DynamicClient

dynamicClient是一种动态的client,实际为RestClient的包装,主要在`garbage collector`和`namespace controller`中有应用,主要关注通用的属性的值,特点如下:

1,支持所有资源

2,只支持json

3,返回值为map

#### informer

client-go中区别其他语言的client的一个较为牛逼的设计就在于此,其他语言很多都直接通过rest api同kubernetes交互,虽然在少量的情况下是没有问题的,但是在大量的连接下会出现各种问题,例如连接太多,状态不同步等等问题,client-go作为在kubernetes源码中都有很多应用的库,在解决这些问题上提供了一个高端的做法.

informer在初始化的时先通过reflector List去从Kubernetes API中取出资源的全部object对象,并同时缓存,然后开启Watch的机制去监控资源,并放入DeltaFIFO中.这样每次获取资源不需要再去kubernetes实时获取,而是通过本地的indexer缓存得到对象,整体连接资源的使用率都降低了不少.
Informer还提供了handler机制,需要提供ResourceEventHandler接口的实现来响应OnAdd/OnUpdate/OnDelete事件,当然这其中也少不了功劳,不过这里使用了更为高级的DeltaFIFO+RingGrowing(环形队列)来实现.

informer提供了内置的原生的资源的支持,不过对于其他crd资源,需要使用kubernetes的另外一个项目 code-generator 来进行生成(其实kubernetes中的代码有很多生成的)

整体架构如下图:

<img src="/post/kubernetes/client-go/informer.jpeg"/>

### informer使用

informer的使用方式也比较简单,主要通过NewSharedInformerFactory来获取一个实例.

```go
//https://github.com/kubernetes/client-go/blob/master/examples/workqueue/main.go#L174
//https://github.com/kubernetes/sample-controller/blob/master/controller.go#L87:6
func TestInformer(t *testing.T) {
	config, e := clientcmd.BuildConfigFromFlags("10.30.21.238:6443", "/home/tangxu/.kube/config")
	if e != nil {
		println(e.Error())
		return
	}
	client, e := kubernetes.NewForConfig(config)
	if e != nil {
		println(e.Error())
		return
	}
	stopChan := make(chan struct{})
	factory := informers.NewSharedInformerFactory(client, 30*time.Second)
	podInformer := factory.Core().V1().Pods()
	factory.Apps().V1().Deployments()
	//添加eventHandler
	podInformer.Informer().AddEventHandler(&EventHandler{})
	//使用lister方式获取pod资源
	ret1, e := podInformer.Lister().List(labels.Nothing())
	fmt.Println(ret1, e)

	//也可以通过此方式获取informer
	informer, e := factory.ForResource(schema.GroupVersionResource{
		Group:    "apps",
		Version:  "v1",
		Resource: "deployments",
	})
	if e != nil {
		println(e.Error())
	}
	//具体某个资源的group,version,resource的获取如下:
	fmt.Println(appsv1.SchemeGroupVersion.WithResource("deployments"))

	//获取列表
	ret, e := informer.Lister().ByNamespace("kube-system").List(labels.Nothing())
	fmt.Println(ret, e)

	factory.Start(stopChan)
    
	time.Sleep(5 * time.Minute)

	stopChan <- EventHandler{}

}

type EventHandler struct {
}

func (*EventHandler) OnAdd(obj interface{}) {
	fmt.Println("OnAdd")
	bytes, _ := json.Marshal(obj)
	fmt.Println(string(bytes))
}

func (*EventHandler) OnUpdate(oldObj, newObj interface{}) {
	fmt.Println("OnUpdate")
	bytes1, _ := json.Marshal(oldObj)
	bytes2, _ := json.Marshal(newObj)
	fmt.Println(string(bytes1))
	fmt.Println(string(bytes2))
}

func (*EventHandler) OnDelete(obj interface{}) {
	fmt.Println("OnDelete")
	bytes, _ := json.Marshal(obj)
	fmt.Println(string(bytes))
}
```

通过以上的示例大概能表达出informer的使用方法,如果需要深入的了解 还需要自己在编辑器中写代码来体会.



## 参照

[Kubernetes的client-go库介绍](https://www.jianshu.com/p/d17f70369c35)

[client-go文档](https://godoc.org/k8s.io/client-go)

[sample-controller示例](https://github.com/kubernetes/sample-controller)

[Kubernetes Deep Dive: Code Generation for CustomResources](https://blog.openshift.com/kubernetes-deep-dive-code-generation-customresources/) (非常好的文章)

[github-code-generator](https://github.com/kubernetes/code-generator)

[informer源码分析](https://yq.aliyun.com/articles/688485#)

[本文源代码](https://github.com/tangxusc/k8s-client-go-demo/blob/master/resource_crud_test.go#L129)