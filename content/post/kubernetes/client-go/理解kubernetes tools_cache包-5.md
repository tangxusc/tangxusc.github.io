---
title: "理解kubernetes tools/cache包-5"
date: 2019-05-16T16:13:12+08:00
categories:
- k8s
- client
tags:
- k8s
- client-go
keywords:
- client-go
- client
#thumbnailImage: //example.com/image.jpg
---
> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://blog.csdn.net/weixin_39961559/article/details/81946899

本系列深入介绍了informer的原理,这是本系列第五节
<!--more-->

[在第四节中](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-4/)，我们在 DeltaFIFO 结构中单独查看了一些细节，它将逻辑 “将此对象添加到请求” 请求转换为 “添加表示对象添加的事件” 操作。 这结束了我们对 tools/cache 包的结构演练。 从行为的角度来看，显然还有很多东西要看，但是现在值得停下来展示全局。

在下图中，您将看到一个毫无歉意的粗糙和简单混合的，UML，一些 Java 概念，一些 Go 类型名称 - 简而言之，一个大杂烩的符号应该证明有助于显示整个包在高水平。 

同样，这不是 Go 结构，Java 类或其他任何东西的一对一表示，而是有用的名词和框和线的组合，勾勒出工具 / 缓存包的一般形状，并希望给出一个 整个事物的可用结构概述：
![](https://img-blog.csdn.net/20180822163834757?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl8zOTk2MTU1OQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
一般而言，我可能不一致，橙色框表示构成用户希望直接理解或使用的 tools/cache 框架的概念或结构。 粉色框表示实现相关。 浅蓝色框表示与 Kubernetes 直接相关的事物。 

我已经尝试将 UML 正确用于其他一切。 大多数（但不是全部）名称都与 Go 代码足够接近，以一种方式或另一种方式搜索它们应该可以帮助您浏览[所有. go](https://github.com/kubernetes/kubernetes/tree/v1.9.0/staging/src/k8s.io/client-go/tools/cache) 文件。

要处理这张大图，你可以打印出来并阅读本系列的前几篇文章，从[第一节](/2019/05/%E7%90%86%E8%A7%A3kubernetes-tools/cache%E5%8C%85-1/)开始。用 SharedIndexInformer 概念 / 类开始图示并按照箭头操作。

在文本上，SharedIndexInformer“是一个”SharedInformer，它管理一个 Controller，间接一个 Reflector，它使用 Kubernetes 客户端和 ListerWatcher 实现来更新特定类型的 Store，即 DeltaFIFO，其逻辑事件代表修改，添加和删除列出和观看的 Kubernetes 资源。

它从 getStore()方法返回的 Store，实际上是一个 Indexer，通过 Go 代码中的缓存类型实现。（特别注意，它的 getStore()方法返回其 getIndexer()方法的返回值，这意味着调用者有权访问的 Store 不是它作为实现关注内部更新的 DeltaFIFO。还记得在如果您手中有任何类型的 Store，只有特定函数的调用。）

在本系列的下一篇中，我们将介绍整个 tools/cache 包的线程和行为问题。