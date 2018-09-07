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

Each custom resource has structure. The structure of the custom resource handled by our operator must be specified in `types.go` which resides under `pkg/apis/<api-group>/<version>`. The `Spec` field where we can define the structure for the specification of the custom resource. There is also a `Status` field that is meant to be populated with information that describe the state of the custom resource object.

The `Operator SDK` exposes functions for performing CRUD operations on Kubernetes resources:

*   _query_ package - defines functions for retrieving Kubernetes resources available in the cluster
*   _action_ package - defines functions for creating, updating and deleting Kubernetes resources

For more details on how to use these functions see the concrete [operator example](#the-prometheus-jmx-exporter-case) below.

#### Update and generate code for custom resources

Whenever there are changes done to `types.go` there are some generated code that needs refreshing as it depends on the types defines in the `types.go`.

```
$ operator-sdk generate k8s

```

#### Build and generate the operator deployment manifests

Build the operator and generate deployment files.

```
operator-sdk build <your-docker-image>

```

A docker image that contains the binary of your operator is built and this image needs to be pushed to a registry.

The deployment files for creating custom resource and deploying the operator handling these are generated under `deploy` directory.

*   `operator.yml` - this is for installing the customer resource definition and deploying the operator (custom controller). Any changes to this file will be overwritten whenever `operator-sdk build <your-docker-image>` is executed.
*   `cr.yaml` - this is for defining the specs of the custom resource. This will be unmarshalled into an object and passed to the operator.
*   `rbac.yaml` - this defines the [RBAC](https://kubernetes.io/docs/admin/authorization/rbac/) to be created for the operator in case the Kubernetes cluster has RBAC enabled.

#### Deploy the operator

```
$ kubectl create -f deploy/rbac.yaml
$ kubectl create -f deploy/operator.yaml

```

#### Create custom resources

Once the operator is running you can start creating custom resources that your operator was implemented for. Populate the `spec` section of `deploy/cr.yaml` with data that you want to pass to the operator. The structure of `spec` must comply with the structure of `Spec` field in `types.go`.

```
$ kubectl create -f deploy/cr.yaml

```

To see the customer resource objects in the cluster:

```
$ kubectl get <custom-resource-kind>

```

To see a specific custom resource instance:

```
$ kubectl get <custom-resource-kind> <custom-resource-object-name>

```

#### The Prometheus JMX Exporter case

Our PaaS [Pipeline](https://github.com/banzaicloud/pipeline) deploys applications to Kubernetes clusters and provides enterprise feature like monitoring, centralized logging to name a a few ones.

For monitoring we use [Prometheus](https://prometheus.io) to collect metrics from applications that we deploy. If you’re interested why we chose Prometheus read our [monitoring blog series](https://banzaicloud.com/blog/prometheus-application-monitoring/).

Applications may not publish metrics to Prometheus by themselves so faced the question what can we do to enable publishing metrics to Prometheus out of the box for these apps. There is handy component [Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter) written for Java applications that can query data from mBeans via JMX and expose these in a format required by Prometheus.

The requirements here are:

*   identify pods that run Java applications that don’t publish metrics themselves for Prometheus
*   inject the Prometheus JMX Exporter java agent into the application to expose metrics
*   provide a configuration for the Prometheus JMX Exporter java agent that controls what metrics to be published
*   make Prometheus server automatically aware of the endpoint where it can scrape metrics from
*   these operations should not be intrusive (should not restart the pod)

In order to achieve the requirements listed above we’d to perform quite a few operations thus we decided to implement an operator for it. Let’s see how this is implemented.

[Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter) as it is implemented can be loaded into Java processes only at JVM startup. Happily only a small change was required to make it loadable into an already running Java process. You can take a look at the change in our [jmx_exporter fork](https://github.com/banzaicloud/jmx_exporter/commit/e83a7f123a983402aac2d831a716da4f4cd1ed5d)

We need a loader that loads the JMX exporter Java agent into a running Java process identified by PID. The loader is a fairly small application and its source code is available [here](https://github.com/banzaicloud/jmx-exporter-loader)

[Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter) requires a [configuration](https://github.com/prometheus/jmx_exporter#configuration) to be passed in. We’ll store the configuration for the exporter in a Kubernetes [config map](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)

The custom resource for our operator(`types.go`):

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

*   `LabelSelector` - specifies the labels which Pods are selected
*   `ConfigMapName`, `ConfigMapKey` - the config map that contains the configuration for Prometheus JMX Exporter
*   `Port` - the port number for the endpoint where metrics will be exposed for Prometheus server.

An example yaml file to create a customer resource object:

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

The custom resource spec holds the data that instructs the operator logic what pods to process, the port to expose the metrics at, the config map that stores the metrics configuration for the exporter.

The status of a _PrometheusJmxExporter_ custom resource object should list the metrics endpoints that were created based on it’s specs thus the structure for `Status` field is:

```
type PrometheusJmxExporterStatus struct {
	MetricsEndpoints []*MetricsEndpoint `json: metricsEndpoints,omitempty`
}

type MetricsEndpoint struct {
	Pod  string `json:"pod,required"`
	Port int    `json:"port,required"`
}
```

The operator has to react to events related to _PrometheusJmxExporter_ custom resources and _Pods_ thus it has to set up watches on these kind of resources(`main.go`):

```
func main() {
    ...
    namespace := os.Getenv("OPERATOR_NAMESPACE")
    sdk.Watch("banzaicloud.com/v1alpha1", "PrometheusJmxExporter", namespace, 0)
    sdk.Watch("v1", "Pod", namespace, 0)
    ...
}
```

The handler for handling the events related to _PrometheusJmxExporter_ custom resources and _Pods_ is defined in `handler.go`:

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

When a _PrometheusJmxExporter_ custom resource object is created/updated the operator:

1.  queries all pods in the current namespace of which labels matches the labelSelector of the _PrometheusJmxExporter_ custom resource object spec.
2.  verifies which of the returned pods were already processed to skip those
3.  process the remaining pods
4.  update the status of the current _PrometheusJmxExporter_ custom resource with the newly created metrics endpoints

When a _Pod_ is created/updated/deleted the operator:

1.  searches for the _PrometheusJmxExporter_ custom resource object of which labelSelector matched the pod
2.  if a _PrometheusJmxExporter_ custom resource object is found than continues with processing the pod
3.  update the status of the _PrometheusJmxExporter_ custom resource with the newly created metrics endpoints

In order to query Kubernetes resources we use the `query` package of the `Operator SDK`.

e.g.:

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

To update Kubernetes resources we use the `action` package of the `Operator SDK`. e.g.:

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

The processing of a pod consists of the following steps:

1.  execute `jps` inside the containers of the pod to get the PID of java processes
2.  copy the [Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter) and [java agent loader](https://github.com/banzaicloud/jmx-exporter-loader) artifacts into the containers where there is a Java process found
3.  read the exporter configuration from the config map and copy it into the container as a config file
4.  run the loader inside the container to load the exporter into the Java process
5.  add to the container’s exposed port list the port of the exporter such as Prometheus server will be able to scrape this port.
6.  annotate the pod with `prometheus.io/scrape` and `prometheus.io/port` as Prometheus server scrapes pods with these annotations.
7.  flag the pod with an annotation to mark that it has been successfully processed.

As the Kubernetes API doesn’t support directly the execution of a command inside a container we borrowed the implementation from `kubectl exec`. The same is true for `kubectl cp`.

The source code of `Prometheus JMX Exporter operator` is available on [GitHub](https://github.com/banzaicloud/prometheus-jmx-exporter-operator)

If you are interested in our technology and open source projects, follow us on GitHub, LinkedIn or Twitter:

[Follow @BanzaiCloud](https://twitter.com/BanzaiCloud?ref_src=twsrc%5Etfw)