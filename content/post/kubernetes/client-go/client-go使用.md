---
title: "Client Go使用"
date: 2019-05-15T15:13:08+08:00
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

kubernetes提供了rest api供我们操作集群,针对go语言专门提供了client-go来操作,并且在很多controller中都使用到了client-go,本文将介绍client-go简单使用

<!--more-->

## kubernetes api介绍

kubernetes通过http rest协议向外暴露api,各组件间和kubectl都是通过rest api调用api-server,并在rest api中使用多个api版本进行版本控制,每个版本有不同的api路径,例如:`/api/v1`或`/api/extension/v1beta1`

### api-group

kubernetes 的api是按照api-group进行分组的,各api在不同的组下:

`core`: 核心组,kubernetes早期就存在或者必须的资源,其路径为 `/api/v1`,对应的yaml为:`apiVersion: v1`

 `其他组`: 核心组意外的资源,路径为`/apis/Group_Name/Version`,yaml为`apiVersion: GroupName/Version`,例如Deployment其`apiVersion: apps/v1`,那么其Rest地址为`/apis/apps/v1/namespaces/{namespace}/deployments`

### client-go

kubernetes为各主流语言提供了client方便了我们使用(不用直接使用rest api调用,并且封装了资源的建模序列化等过程),本文以go语言的client为例,简单说明调用方式.

#### 1,创建项目,初始化依赖

```shell
#创建目录
$ mkdir client-go-test && cd client-go-test
#初始化项目
$ go mod init client-go-test
# 获取依赖
$ go get k8s.io/client-go/...
# 修正依赖
$ go get k8s.io/client-go@v7.0.0
```

在此处修正依赖关系是因为 go get到的是最新的包,但是client-go是需要根据k8s的版本来使用的,详细的版本关系请参照 [client-go 兼容性矩阵](https://github.com/kubernetes/client-go/#compatibility-matrix) ,也可以直接使用 [示例go.mod](https://github.com/tangxusc/k8s-client-go-demo/blob/master/go.mod)

#### 2,读取连接配置

kubernetes是通过api-server的端口+证书/token进行连接的,所以我们需要先读取kubeconfig配置

```go
//kubelet.kubeconfig  是文件对应地址
	kubeconfig := flag.String("kubeconfig", "/home/tangxu/.kube/config", "(optional) absolute path to the kubeconfig file")
	flag.Parse()

	// 解析到config
	config, err := clientcmd.BuildConfigFromFlags("10.30.21.238:6443", *kubeconfig)
	if err != nil {
		panic(err.Error())
	}
```

#### 3,建立clientset

kubernetes的资源是按照api-group分割的,在client-go中体现的十分突出(就像腰间盘那样)

```go
clientset, err := kubernetes.NewForConfig(config)
```

其中的返回值 clientSet的声明如下:

```go
// Clientset contains the clients for groups. Each group has exactly one
// version included in a Clientset.
type Clientset struct {
	*discovery.DiscoveryClient
	admissionregistrationV1alpha1 *admissionregistrationv1alpha1.AdmissionregistrationV1alpha1Client
	admissionregistrationV1beta1  *admissionregistrationv1beta1.AdmissionregistrationV1beta1Client
	appsV1beta1                   *appsv1beta1.AppsV1beta1Client
	appsV1beta2                   *appsv1beta2.AppsV1beta2Client
	appsV1                        *appsv1.AppsV1Client
	authenticationV1              *authenticationv1.AuthenticationV1Client
	authenticationV1beta1         *authenticationv1beta1.AuthenticationV1beta1Client
	authorizationV1               *authorizationv1.AuthorizationV1Client
	authorizationV1beta1          *authorizationv1beta1.AuthorizationV1beta1Client
	autoscalingV1                 *autoscalingv1.AutoscalingV1Client
	autoscalingV2beta1            *autoscalingv2beta1.AutoscalingV2beta1Client
	batchV1                       *batchv1.BatchV1Client
	batchV1beta1                  *batchv1beta1.BatchV1beta1Client
	batchV2alpha1                 *batchv2alpha1.BatchV2alpha1Client
	certificatesV1beta1           *certificatesv1beta1.CertificatesV1beta1Client
	coreV1                        *corev1.CoreV1Client
	eventsV1beta1                 *eventsv1beta1.EventsV1beta1Client
	extensionsV1beta1             *extensionsv1beta1.ExtensionsV1beta1Client
	networkingV1                  *networkingv1.NetworkingV1Client
	policyV1beta1                 *policyv1beta1.PolicyV1beta1Client
	rbacV1                        *rbacv1.RbacV1Client
	rbacV1beta1                   *rbacv1beta1.RbacV1beta1Client
	rbacV1alpha1                  *rbacv1alpha1.RbacV1alpha1Client
	schedulingV1alpha1            *schedulingv1alpha1.SchedulingV1alpha1Client
	settingsV1alpha1              *settingsv1alpha1.SettingsV1alpha1Client
	storageV1beta1                *storagev1beta1.StorageV1beta1Client
	storageV1                     *storagev1.StorageV1Client
	storageV1alpha1               *storagev1alpha1.StorageV1alpha1Client
}
```

可以看到clientset其实就是原生的资源的集合,通过group来进行区分,简单使用如下:

```go
deploymentsClient := clientset.AppsV1beta1().Deployments("kube-system")
	deploymentList, err := deploymentsClient.List(v1.ListOptions{})
	if err != nil {
		panic(err.Error())
	}
	for key, value := range deploymentList.Items {
		fmt.Println("deployment", key)
		bytes, err := json.Marshal(value)
		if err != nil {
			println(err.Error())
			return
		}
		fmt.Println("内容为", string(bytes))
	}
	fmt.Println("============获取pod==============")

	pods := clientset.CoreV1().Pods("kube-system")
	podList, err := pods.List(v1.ListOptions{})
	if err != nil {
		println(err.Error())
		return
	}

	for key, value := range podList.Items {
		fmt.Println("第", key, "个pod.................")
		bytes, err := json.Marshal(value)
		if err != nil {
			return
		}
		fmt.Println(string(bytes))
	}
```

从上面的代码可以看到整体的调用非常简单,获取deployment也非常简单,不过写着写着就发现了一个问题,**如何获取关联资源?**

#### 4,关联资源获取

我们都知道在kubernetes中deployment是依赖ReplicaSet的,ReplicaSet是依赖Pod的,那么怎么获取deployment中的Pod呢?(毕竟我们真的不怎么关心ReplicaSet!)

```go
clientset.CoreV1().Pods(namespace.Name).List(v1.ListOptions{})
```

请注意上面代码的`v1.ListOptions{}`这个参数,其声明如下:

```go
// ListOptions is the query options to a standard REST list call.
type ListOptions struct {
	TypeMeta `json:",inline"`

	// A selector to restrict the list of returned objects by their labels.
	// Defaults to everything.
	// +optional
	LabelSelector string `json:"labelSelector,omitempty" protobuf:"bytes,1,opt,name=labelSelector"`
	// A selector to restrict the list of returned objects by their fields.
	// Defaults to everything.
	// +optional
	FieldSelector string `json:"fieldSelector,omitempty" protobuf:"bytes,2,opt,name=fieldSelector"`
... 其他字段省略
```

deployment的selector字段中的label和pod中的label是统一的,那么我们可以通过此机制来直接获取pod,并且`ListOptions`也提供了这个参数.

```go
podInterface := client.CoreV1().Pods("kube-system")
	podList, e := podInterface.List(metav1.ListOptions{
		LabelSelector: "app=helm,component=kube-controller-manager,tier=control-plane",
	})
	if e != nil {
		println(e.Error())
	}
	for _, value := range podList.Items {
		bytes, e := json.Marshal(value)
		if e != nil {
			println(e.Error())
			continue
		}
		fmt.Println("pod", value.Name, string(bytes))
	}
```

通过这样的方式就能直接获取关联的pod了..

### 参照

[client-go文档](https://godoc.org/k8s.io/client-go)

[kubernetes client library](https://kubernetes.io/docs/reference/using-api/client-libraries/)

[示例代码](https://github.com/tangxusc/k8s-client-go-demo/blob/master/cluster_info_test.go)

[clientcmd package 介绍](https://godoc.org/k8s.io/client-go/tools/clientcmd)

[集群内通过service account的token和ca.crt连接api-server](https://github.com/kubernetes/client-go/blob/master/examples/in-cluster-client-configuration/main.go)

[client-go示例](https://github.com/kubernetes/client-go/blob/master/examples)

