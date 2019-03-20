# jaeger-operator安装

在一个成规模的微服务系统中,一个功能不单由这一个服务完成,而是多个服务协作来共同完成,但是如果其中一个服务出现了错误,对于错误的追踪,对于整个调用链的追踪便成为了难题.

好在外国佬遇到了这些问题,指定了`opentracing`规范,并且提供了例如`zipkin`,`pinpoint`,`jaeger`等工具供我们使用

jaeger组件如下:

![](https://www.jaegertracing.io/img/architecture.png)

## 安装

### 1. elasticsearch

jaeger的存储是依赖cassandra或elasticsearch的,jaeger本身并不存储数据,在此处我们使用es来存储数据

```shell
$ kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init-cn/efk-elasticsearch.yaml
```
> elasticsearch 他妈的又需要**存储**支持,惊不惊喜,意不意外.

此处建议此es应和k8s中的日志收集使用一个es集群,方便管理,并且追踪数据并不需要支持事务等特性,符合日志存储模式.

### 2. jaeger operator

在[github](https://github.com/jaegertracing/jaeger-operator)中提供了operator的安装,直接使用就行

```shell
$ kubectl create namespace observability
$ kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/crds/jaegertracing_v1_jaeger_crd.yaml
$ kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/service_account.yaml
$ kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role.yaml
$ kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role_binding.yaml
$ kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/operator.yaml
```
>  注意:如果安装在其他命名空间中貌似不行... 起码我使用helm安装在jaeger命名空间中不行.

安装成功后等待几分钟就可以看到如下资源的成功运行

```shell
$ kubectl get all -n observability
NAME                                  READY   STATUS    RESTARTS   AGE
pod/jaeger-operator-69c987b98-grv9n   1/1     Running   0          23h

NAME                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/jaeger-operator   ClusterIP   10.108.199.153   <none>        8383/TCP   23h

NAME                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/jaeger-operator   1/1     1            1           23h

NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/jaeger-operator-69c987b98   1         1         1       23h
```

### 3. jaeger instance

创建了jaeger-operator后,就可以很简单启动jaeger的实例了

```yaml
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: my-jaeger
spec:
  strategy: production
#  allInOne:
#    image: jaegertracing/all-in-one:latest
#    options:
#      log-level: debug
  storage:
    type: elasticsearch
    options:
      es:
        server-urls: http://elasticsearch-logging.kube-system:9200
#  ingress:
#    enabled: true

```

其jaeger对象字段可在 [github](https://github.com/jaegertracing/jaeger-operator#creating-a-new-jaeger-instance)中查阅

```shell
$ kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init/jaeger-instance.yaml
```

> 注意:jaeger-operator会自动给我们创建ingress等资源

