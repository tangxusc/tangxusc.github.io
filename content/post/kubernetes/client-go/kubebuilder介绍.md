---
title: "kubebuilder介绍"
date: 2019-05-20T14:10:08+08:00
draft: true
categories:
- k8s
- client
tags:
- k8s
- kubebuilder
keywords:
- kubebuilder
- client
- k8s
#thumbnailImage: //example.com/image.jpg
---

在之前的文章中我们讲到了kubernetes的rest api,并使用client-go等客户端来调用api.

接下来我们将使用到kubernetes为构建controller诞生的专用工具`kubebuilder`

<!--more-->

## 介绍

如果你对kubernetes的使用仅仅停留在rest api和client-go,那么就大错特错了.

在kubernetes中广泛存在的controller,从最基础的controller-manager到crd的自定义controller虽然都使用了client-go,但是实际的使用方式却并不完全一样.

例如: 垃圾收集`controller`则是充分使用dynamic client对资源进行回收操作.

kubernetes的每一项重要的功能几乎都是从sig兴趣小组中诞生出来的(特别佩服这种机制),其中就有一个kubebuilder小组,小组中维护了一个非常重要的工具 `kubebuilder`

那么, kubebuilder是什么呢?

kubebuilder是一个基于CRD来构建kubernetes api的框架,主要可以用来构建CRD api,Controller,和 admission web hook.

## 解决的问题

那么kubebuilder解决了什么问题呢?

- crd定义比较麻烦,毕竟那么多yaml
- 使用informer机制操作crd资源比较繁琐,且代码重复率很高(都是注册ResourceEventHandler)
- 自定义的controller基础行为是一致的,都是监听对象然后根据status进行某些操作
- 使用更简单,工程更规范.
- 默认提供Dockerfile等支持

## 简单使用

说了这么多,那 怎么使用呢?

### 1,安装

```shell
os=$(go env GOOS)
arch=$(go env GOARCH)

# download kubebuilder and extract it to tmp
curl -sL https://go.kubebuilder.io/dl/2.0.0-alpha.1/${os}/${arch} | tar -xz -C /tmp/

# move to a long-term location and put it on your path
# (you'll need to set the KUBEBUILDER_ASSETS env var if you put it somewhere else)
sudo mv /tmp/kubebuilder_2.0.0-alpha.1_${os}_${arch} /usr/local/kubebuilder
export PATH=$PATH:/usr/local/kubebuilder/bin
```

kubebuilder是依赖kustomize的,安装脚本如下:

```shell
os=$(go env GOOS)
arch=$(go env GOARCH)

# download kustomize to the kubebuilder assets folder
curl -o /usr/local/kubebuilder/bin/kustomize -sL https://go.kubebuilder.io/kustomize/${os}/${arch}
```

### 2,初始化项目

```shell
#创建项目目录,并使用kubebuilder初始化
$ mkdir kubebuilder-demo && cd kubebuilder-demo
#使用go mod 初始化golang 模块支持
$ go mod init demo
#使用kubebuilder初始化项目
$ kubebuilder init --domain my.domain
```

请注意,`--domain`的值



项目初始化失败,原因:kubebuilder现在是2.0的a版本

tangxu@tangxu-pc:~/openProject/kubebuilder-demo$ kubebuilder init --domain test.com
2019/05/20 15:30:20 kubebuilder must be run from the project root under $GOPATH/src/<package>. 
Current GOPATH=/home/tangxu/go.  
Current directory=/home/tangxu/openProject/kubebuilder-demo





### 参照

[client-go文档](https://godoc.org/k8s.io/client-go)

[kubernetes client library](https://kubernetes.io/docs/reference/using-api/client-libraries/)

[示例代码](https://github.com/tangxusc/k8s-client-go-demo/blob/master/cluster_info_test.go)

[clientcmd package 介绍](https://godoc.org/k8s.io/client-go/tools/clientcmd)

[集群内通过service account的token和ca.crt连接api-server](https://github.com/kubernetes/client-go/blob/master/examples/in-cluster-client-configuration/main.go)

[client-go示例](https://github.com/kubernetes/client-go/blob/master/examples)

