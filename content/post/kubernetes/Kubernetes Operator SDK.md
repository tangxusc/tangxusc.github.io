---
title: "Kubernetes Operator SDK"
date: 2019-03-20T14:15:59+08:00
draft: false
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://banzaicloud.com/blog/operator-sdk/

在[Banzai Cloud，](https://banzaicloud.com)我们一直在寻找新的创新技术，以支持我们的用户使用[Pipeline](https://github.com/banzaicloud/pipeline)过渡到部署到Kubernetes的微服务。最近几个月，我们与[CoreOS](https://coreos.com/)和[RedHat](https://coreos.com/)合作，开展了运营商及其刚刚开源的项目，并在[GitHub上提供](https://github.com/operator-framework)。如果您通读这篇博客，您将了解到什么是`operator`，如何使用它`operator sdk`来开发`operator`我们在[Banzai Cloud](https://banzaicloud.com)开发和使用的具体示例。我们的[GitHub上](https://github.com/banzaicloud)还有一些运营商都可以在新的运营商SDK [上](https://github.com/banzaicloud)构建。

### TL;博士：

*   今天[发布](https://github.com/operator-framework)了一个新的Kubernetes运营商框架
*   我们积极参与了新的SDK，因此我们[发布](https://github.com/banzaicloud)了一些
*   本博客中讨论的操作员可以为任何基于JVM的应用程序提供无缝的框控制，而无需实际具有刮擦界面

在Kubernetes上部署和运行由多个相互依赖的组件/服务组成的复杂应用程序并不总是微不足道的Kubernetes提供的构造。就像一个简单的例子，如果一个应用程序需要最少数量的实例，可以通过Kubernetes部署来解决。但是，如果实例的数量发生变化（高级/低级），则必须在运行时重新配置或重新初始化这些实例，而不是我们需要对这些事件作出反应并执行必要的重新配置步骤。尝试通过实现使用Kubernetes命令行工具的脚本来解决这些问题很容易变得麻烦，特别是当我们接近现实生活中的用例时，我们必须处理弹性，日志收集，监视等。

CoreOS引入了[运营商](https://coreos.com/operators/)来自动处理这些复杂的运营场景。简而言之`operators`，通过第三方资源机制（[自定义资源](https://kubernetes.io/docs/concepts/api-extension/custom-resources/)）扩展Kubernetes API，并提供对细胞内部正在进行的细粒度访问和控制。

在我们进一步讨论之前，先谈谈Kubernetes的_自定义资源，_以便更好地了解它`operator`是什么。甲_资源_在Kubernetes是在端点[Kubernetes API](https://kubernetes.io/docs/reference/api-overview/)，其存储一定的Kubernetes对象（例如对象波德）_种类_（例如，POD）。一个_自定义资源_本质上是一种_资源_，可以添加到Kubernetes扩展基本Kubernetes API。一旦_自定义资源_安装用户可以管理这种对象`kubectl`相同的方式，为他们做内置Kubernetes资源，如_豆荚_的例子。必须有一个控制器来执行由此引起的操作`kubectl`。定制控制器是_自定义资源的_控制器。总而言之，a `operator`是一个自定义控制器，可以处理某种_自定义资源_。

CoreOS还开发了用于开发此类的SDK `operators`。SDK简化了a的实现，`operator`因为它提供了高级API来编写操作逻辑，为它生成框架，使开发人员无需编写样板代码。

我们来看看我们如何使用`Operator SDK`。

首先，我们需要将[Operator SDK](https://github.com/coreos/operator-sdk#quick-start)安装到我们的开发机器上。如果您准备冒险使用最新最好的安装来自`master`分支机构的CLI 。安装CLI后，开发流程将如下所示：

1.  [创建一个新的操作员项目](#create-a-new-operator-project)
2.  [定义要监视的Kubernetes资源](#define-the-kubernetes-resources-to-watch)
3.  [在指定的处理程序中定义操作符逻辑](#define-the-operator-logic-in-a-designated-handler)
4.  [更新并生成自定义资源的代码](#update-and-generate-code-for-custom-resources)
5.  [构建并生成运营商部署清单](#build-and-generate-the-operator-deployment-manifests)
6.  [部署运营商](#deploy-the-operator)
7.  [创建自定义资源](#create-custom-resources)

#### 创建一个新的操作员项目

运行CLI以创建新`operator`项目。

```
$ cd $GOPATH/src/github.com/<your-github-repo>/
$ operator-sdk new <operator-project-name> --api-version=<your-api-group>/<version> --kind=<custom-resource-kind>
$ cd <operator-project-name>

```

*   operator-project-name - CLI在此目录下生成项目框架
*   your-api-group - 这是我们处理的[自定义资源](https://kubernetes.io/docs/concepts/api-extension/custom-resources/)的Kubernetes API组`operator`（例如mycompany.com）
*   version - 这是我们处理的自定义资源的Kubernetes API版本`operator`（例如v1alpha，beta等，请参阅[Kubernetes API版本](https://kubernetes.io/docs/concepts/overview/kubernetes-api/)）
*   custom-resource-kind - 自定义资源类型的名称

#### 定义要监视的Kubernetes资源

该`main.go`划归`cmd/<operator-project-name>`为主要切入点来启动和初始化`operator`。这是配置操作员有兴趣从Kubernetes获取通知的资源类型列表的地方。

#### 在指定的处理程序中定义操作符逻辑

与从Kubernetes收到的观察资源相关的事件被引导到`func (h *Handler) Handle(ctx types.Context, event types.Event) error`定义中`pkg/stub/handler.go`。这是实现运算符逻辑的地方，可以对Kubernetes发布的各种事件做出反应。

每个自定义资源都有结构。通过我们的运营商处理的自定义资源的结构必须被指定在`types.go`驻留下`pkg/apis/<api-group>/<version>`。`Spec`我们可以在其中定义自定义资源规范的结构的字段。还有一个`Status`字段用于填充描述自定义资源对象状态的信息。

在`Operator SDK`对Kubernetes资源执行CRUD操作自曝功能：

*   _query_ package - 定义用于检索集群中可用的Kubernetes资源的函数
*   _action_ package - 定义用于创建，更新和删除Kubernetes资源的函数

有关如何使用这些函数的更多详细信息，请参阅下面的具体[运算符示例](#the-prometheus-jmx-exporter-case)。

#### 更新并生成自定义资源的代码

每当进行更改时，`types.go`都会生成一些需要刷新的代码，因为它取决于中定义的类型`types.go`。

```
$ operator-sdk generate k8s

```

#### 构建并生成运营商部署清单

构建运算符并生成部署文件。

```
operator-sdk build <your-docker-image>

```

构建包含运算符二进制文件的docker镜像，并且需要将此图像推送到注册表。

用于创建自定义资源和部署处理这些资源的操作员的部署文件是在`deploy`目录下生成的。

*   `operator.yml` - 这用于安装客户资源定义和部署操作员（自定义控制器）。`operator-sdk build <your-docker-image>`执行时，将覆盖对此文件的任何更改。
*   `cr.yaml` - 这是用于定义自定义资源的规范。这将被解组到一个对象中并传递给操作符。
*   `rbac.yaml`-这定义了[RBAC](https://kubernetes.io/docs/admin/authorization/rbac/)用于在情况下，操作者的Kubernetes集群已启用RBAC来创建。

#### 部署运营商

```
$ kubectl create -f deploy/rbac.yaml
$ kubectl create -f deploy/operator.yaml

```

#### 创建自定义资源

运营商运行后，您可以开始创建运营商实施的自定义资源。使用要传递给操作员的数据填充`spec`部分`deploy/cr.yaml`。结构`spec`必须符合`Spec`现场结构`types.go`。

```
$ kubectl create -f deploy/cr.yaml

```

要查看集群中的客户资源对象：

```
$ kubectl get <custom-resource-kind>

```

要查看特定的自定义资源实例：

```
$ kubectl get <custom-resource-kind> <custom-resource-object-name>

```

#### Prometheus JMX Exporter案例

我们的PaaS [Pipeline将](https://github.com/banzaicloud/pipeline)应用程序部署到Kubernetes集群，并提供企业功能，如监控，集中式日志记录等等。

对于监控，我们使用[Prometheus](https://prometheus.io)从我们部署的应用程序中收集指标。如果您对我们为什么选择Prometheus感兴趣，请阅读我们的[监控博客系列](https://banzaicloud.com/blog/prometheus-application-monitoring/)。

应用程序可能不会自己向Prometheus发布指标，因此我们可以采取哪些措施来启用针对这些应用程序的Prometheus发布指标。为Java应用程序编写的便捷组件[Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter)可以通过JMX从mBeans查询数据，并以Prometheus所需的格式公开这些数据。

这里的要求是：

*   识别运行Java应用程序的pod，这些应用程序不会为Prometheus发布指标
*   将Prometheus JMX Exporter java代理注入应用程序以公开指标
*   为Prometheus JMX Exporter java代理提供配置，以控制要发布的度量标准
*   使Prometheus服务器自动识别可以从中抓取指标的端点
*   这些操作不应该是侵入性的（不应该重启pod）

为了达到上面列出的要求，我们将执行相当多的操作，因此我们决定为它实现一个运算符。让我们看看这是如何实现的。

[实现的Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter)只能在JVM启动时加载到Java进程中。令人高兴的是，只需要进行一些小的更改就可以将其加载到已经运行的Java进程中。您可以查看我们的[jmx_exporter fork](https://github.com/banzaicloud/jmx_exporter/commit/e83a7f123a983402aac2d831a716da4f4cd1ed5d)中的更改[](https://github.com/banzaicloud/jmx_exporter/commit/e83a7f123a983402aac2d831a716da4f4cd1ed5d)

我们需要一个加载器，它将JMX导出器Java代理加载到由PID标识的正在运行的Java进程中。加载器是一个相当小的应用程序，其源代码可[在此处获得](https://github.com/banzaicloud/jmx-exporter-loader)

[Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter)需要传入[配置](https://github.com/prometheus/jmx_exporter#configuration)。我们将导出器的配置存储在Kubernetes [配置映射中](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)

我们的operator（`types.go`）的自定义资源：

```
type PrometheusJmxExporter struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata"`
	Spec              PrometheusJmxExporterSpec   `json:"spec"`
	Status            PrometheusJmxExporterStatus `json:"status,omitempty"`
}

type PrometheusJmxExporterSpec struct {
	LabelSelector map[string]string `json:"labelSelector,required"`
	Config        struct {
		ConfigMapName string `json:"configMapName,required"`
		ConfigMapKey  string `json:"configMapKey,required"`
	} `json:"config"`
	Port int `json: port,required`
}
```

*   `LabelSelector` - 指定选择Pod的标签
*   `ConfigMapName`，`ConfigMapKey`- 包含Prometheus JMX Exporter配置的配置映射
*   `Port` - 端点的端口号，其中将为Prometheus服务器公开度量标准。

用于创建客户资源对象的示例yaml文件：

```
apiVersion: "banzaicloud.com/v1alpha1"
kind: "PrometheusJmxExporter"
metadata:
  name: "example-prom-jmx-exp"
spec:
  labelSelector:
    app: dummyapp
  config:
    configMapName: prometheus-jmx-exporter-config
    configMapKey: config.yaml
  port: 9400
```

自定义资源规范包含指示操作员逻辑要处理哪些pod的数据，用于公开度量标准的端口，用于存储导出器的度量配置的配置映射。

_PrometheusJmxExporter_自定义资源对象的状态应列出根据其规范创建的度量标准端点，因此`Status`字段的结构为：

```
type PrometheusJmxExporterStatus struct {
	MetricsEndpoints []*MetricsEndpoint `json: metricsEndpoints,omitempty`
}

type MetricsEndpoint struct {
	Pod  string `json:"pod,required"`
	Port int    `json:"port,required"`
}
```

运营商必须对与_PrometheusJmxExporter_自定义资源和_Pod_相关的事件作出反应，因此必须在这些资源上设置_监视_（`main.go`）：

```
func main() {
    ...
    namespace := os.Getenv("OPERATOR_NAMESPACE")
    sdk.Watch("banzaicloud.com/v1alpha1", "PrometheusJmxExporter", namespace, 0)
    sdk.Watch("v1", "Pod", namespace, 0)
    ...
}
```

处理与_PrometheusJmxExporter_自定义资源和_Pod_相关的事件的处理程序在`handler.go`以下位置定义：

```
func (h *Handler) Handle(ctx types.Context, event types.Event) error {
    switch o := event.Object.(type) {
    case *v1alpha1.PrometheusJmxExporter:
        prometheusJmxExporter := o
    ...
    ...
    case *v1.Pod:
        pod := o
    ...
    ...
}
```

当创建/更新_PrometheusJmxExporter_自定义资源对象时，运算符：

1.  查询当前命名空间中哪些标签与_PrometheusJmxExporter_自定义资源对象规范的labelSelector匹配的所有pod 。
2.  验证已处理哪些已返回的pod以跳过这些pod
3.  处理剩余的豆荚
4.  使用新创建的度量标准端点更新当前_PrometheusJmxExporter_自定义资源的状态

当创建/更新/删除_Pod时_，运营商：

1.  搜索与LabelBlector匹配的_PrometheusJmxExporter_自定义资源对象
2.  如果找到_PrometheusJmxExporter_自定义资源对象，则继续处理pod
3.  使用新创建的度量标准端点更新_PrometheusJmxExporter_自定义资源的状态

为了查询Kubernetes资源，我们使用了`query`包的`Operator SDK`。

例如：

```
podList := v1.PodList{
    TypeMeta: metav1.TypeMeta{
        Kind:       "Pod",
        APIVersion: "v1",
    },
}

listOptions := query.WithListOptions(&metav1.ListOptions{
    LabelSelector:        labelSelector,
    IncludeUninitialized: false,
})

err := query.List(namespace, &podList, listOptions)
if err != nil {
    logrus.Errorf("Failed to query pods : %v", err)
    return nil, err
}
```

```
jmxExporterList := v1alpha1.PrometheusJmxExporterList{
    TypeMeta: metav1.TypeMeta{
        Kind:       "PrometheusJmxExporter",
        APIVersion: "banzaicloud.com/v1alpha1",
    },
}

listOptions := query.WithListOptions(&metav1.ListOptions{
    IncludeUninitialized: false,
})

if err := query.List(namespace, &jmxExporterList, listOptions); err != nil {
    logrus.Errorf("Failed to query prometheusjmxexporters : %v", err)
    return nil, err
}
```

要更新Kubernetes资源，我们使用的`action`是`Operator SDK`。例如：

```
// update status
newStatus := createPrometheusJmxExporterStatus(podList.Items)

if !prometheusJmxExporter.Status.Equals(newStatus) {
    prometheusJmxExporter.Status = createPrometheusJmxExporterStatus(podList.Items)

    logrus.Infof(
        "PrometheusJmxExporter: '%s/%s' : Update status",
        prometheusJmxExporter.Namespace,
        prometheusJmxExporter.Name)

    action.Update(prometheusJmxExporter)
}
```

pod的处理包括以下步骤：

1.  `jps`在pod的容器内执行以获取java进程的PID
2.  将[Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter)和[java代理加载器](https://github.com/banzaicloud/jmx-exporter-loader)工件复制到找到Java进程的容器中
3.  从配置映射中读取导出器配置，并将其作为配置文件复制到容器中
4.  在容器内运行加载程序以将导出程序加载到Java进程中
5.  添加到容器的公开端口列表，导出器的端口，如Prometheus服务器将能够刮除此端口。
6.  使用`prometheus.io/scrape`和注释pod，`prometheus.io/port`因为Prometheus服务器使用这些注释擦除pod。
7.  使用注释标记pod以标记它已成功处理。

由于Kubernetes API不直接支持在容器内执行命令，因此我们从中借用了实现`kubectl exec`。同样如此`kubectl cp`。

源代码`Prometheus JMX Exporter operator`可在[GitHub上获得](https://github.com/banzaicloud/prometheus-jmx-exporter-operator)

如果您对我们的技术和开源项目感兴趣，请关注GitHub，LinkedIn或Twitter：

[关注@BanzaiCloud](https://twitter.com/BanzaiCloud?ref_src=twsrc%5Etfw)