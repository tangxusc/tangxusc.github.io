---
title: "迈向istio-自定义mixer adapter"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- istio
tags:
- istio
keywords:
- istio
---

# 自定义mixer adapter

[TOC]

本节我们将自定义一个adapter,adapter和mixer通信使用grpc,所以本节需要对grpc和mixer的adapter有一定的了解.

基于的环境:

- istio 1.0.4
- golang 1.11(go module)
- goland (或者其他go IDE)

## mixer介绍

mixer是istio负责`策略`和`遥测`的组件,实际上是一个抽象的基础设施后端,用于实现访问控制,遥测捕获,配额管理,计费等功能.

在mixer中提供了adapter的机制用来扩展mixer功能,sidecar在每次请求前调用mixer进行`check`,在请求完成后向mixer进行`report`,具体来说mixer提供了:

- 后端adapter的抽象: mixer抽象了后端adapter的实现,sidecar只需要和mixer交互,不再依赖具体的adapter
- 关注点分离: mixer提供的`check`,`report`机制让adapter只需要关注具体的行为,进行细粒度的控制

具体的策略和遥测收集如下图所示:

![](https://istio.io/docs/concepts/policies-and-telemetry/topology-without-cache.svg)

## adapter介绍

adapter是用来扩展mixer行为的组件,mixer和adapter之间使用grpc通信,adapter可以实现日志记录,监控,配额检查,权限检查等,adapter需要向mixer注册,注册后,使用`handler/instance/rule`进行绑定才能生效.

在mixer中提供了两种类型的adapter实现方式:

- `mixer内部的adapter`: 放在mixer组件内部,并且编译在mixer中,随着mixer一起发行

  优点:不用进行grpc网络通信,速度快

  缺点:在mixer内部,无法自定义,如果自定义那么需要求改mixer源码重新编译

- `外部的adapter`: 在k8s集群中以工作负载的方式运行

  优点:可自定义,并且以工作负载等方式运行部署方便,编译简单

  缺点:grpc网络通信,不过grpc通信是可以复用的(http2)

本节我们就要自定义一个外部的adapter来扩展mixer (不实现具体功能,具体功能各位可自行实现,较为简单)

## attributes介绍

在扩展上有mixer和adapter配合进行扩展,在通信协议上使用grpc,那么具体的通信内容是什么呢?

在mixer中有一个重要的概念是`attribute`,用于描述请求的所有环境和变量等等,属性的示例如下:

```yaml
request.path: xyz/abc
request.size: 234
request.time: 12:34:56.789 04/17/2017
source.ip: 192.168.0.1
destination.service: example
```

mixer的本质实际上就是一个属性的处理器,将基础的属性处理后(处理方式参照),发起到具体adapter的grpc调用.

支持的属性可以通过命令k8s命令查看

```shell
kubectl get attributemanifests -o yaml -n istio-system
```

在使用基础属性时,肯定会有很多属性不满足具体的使用需求,这个时候需要使用到属性表达式来做一些简单的属性编辑,具体示例如下:

```yaml
source_name: source.name | ""
source_namespace: source.namespace | ""
destination_name: destination.name | ""
destination_namespace: destination.namespace | ""
source_workload_name: source.workload.name | ""
source_workload_namespace: source.workload.namespace | ""
destination_workload_name: destination.workload.name | ""
destination_workload_namespace: destination.workload.namespace | ""
destination_service_host: destination.service.host | ""
```

## `rule`/`handler`/`instance`

在这里我们再来回顾一下这三个对象(很重要,很容易错)

### handler

> 适配器封装了 Mixer 和特定外部基础设施后端进行交互的必要接口，例如 [Prometheus](https://prometheus.io/) 或者 [Stackdriver](https://cloud.google.com/logging)。各种适配器都需要参数配置才能工作。例如日志适配器可能需要 IP 地址和端口来进行日志的输出。

说白了,handler也就是一个具体的adapter实例绑定对象,通过此服务对接各种的后端.

###  instance

> 配置实例将请求中的属性映射成为适配器的输入。

在isito中,mixer将请求的所有信息都看做属性,那么属性和hander输入参数之间的映射关系,则由instance维护

### rule

> 规则用于指定使用特定实例配置调用某一 Handler 的时机。

规则就是用于告诉istio,什么时候,什么条件下,调用那个instance完成参数转换,然后输入到handler中.

## 自定义adapter

在了解了这些机制和对象之后,我们开始来一步一步(真一步一步)自定义我们的adapter,此adapter特性:

- 支持`authorization` template
- 每个请求到adapter后,都会以json方式打印所附带的信息
- adapter的实现作为一个Deployment运行
- adapter没有进行复杂的实现,只是打印(各位可自行实现,较为简单)
- 使用go 1.11的go module模式管理依赖
- 使用mixc 进行测试

### 准备

1. 克隆istio源代码(必须要克隆啊,没得办法,工具在里面)

```shell
$ mkdir -p $GOPATH/src/istio.io/ && cd $GOPATH/src/istio.io/  && git clone https://github.com/istio/istio
```

2. 安装protoc,并安装grpc插件

   安装方式: [grpc安装](https://gitee.com/tanx/kubernetes-test/blob/master/go/grpc/gomod%E6%96%B9%E5%BC%8F%E5%AE%89%E8%A3%85grpc.md)

2. 编译mixs/mixc

   ```shell
   cd $GOPATH/src/istio.io/istio/ && make mixs && make mixc
   ```

2. 安装 k8s

   [使用kubeadm安装ha集群](https://gitee.com/tanx/kubernetes-test/blob/master/kubeadm/kubeadm%E5%AE%89%E8%A3%85HA%E9%9B%86%E7%BE%A4.md) 

2. 安装 istio

   [使用helm template 方式安装istio1.04](https://gitee.com/tanx/kubernetes-test/blob/master/%E8%BF%88%E5%90%91istio/README.md) 


### 初始化项目

在任意目录(非$gopath包含)创建项目目录,例如:

```shell
cd ~/openProject/ && mkdir istio-my-adapter
#使用go mod初始化项目
$ go mod init
```

### 编辑依赖

`go.mod`

```shell
module istio-my-adapter

replace (
	golang.org/x/net v0.0.0-20181106065722-10aee1819953 => github.com/golang/net v0.0.0-20181106065722-10aee1819953
	golang.org/x/sys v0.0.0-20181206074257-70b957f3b65e => github.com/golang/sys v0.0.0-20181206074257-70b957f3b65e
	golang.org/x/text v0.3.0 => github.com/golang/text v0.3.0
	golang.org/x/tools v0.0.0-20180221164845-07fd8470d635 => github.com/golang/tools v0.0.0-20180221164845-07fd8470d635
	golang.org/x/tools v0.0.0-20180828015842-6cd1fcedba52 => github.com/golang/tools v0.0.0-20180828015842-6cd1fcedba52
	google.golang.org/genproto v0.0.0-20190201180003-4b09977fb922 => github.com/google/go-genproto v0.0.0-20190201180003-4b09977fb922
	google.golang.org/grpc v1.16.0 => github.com/grpc/grpc-go v1.16.0
)

require (
	github.com/BurntSushi/toml v0.3.1 // indirect
	github.com/gogo/googleapis v1.1.0 // indirect
	github.com/gogo/protobuf v1.2.1
	github.com/hashicorp/go-multierror v1.0.0 // indirect
	github.com/inconshreveable/mousetrap v1.0.0 // indirect
	github.com/natefinch/lumberjack v2.0.0+incompatible // indirect
	github.com/pkg/errors v0.8.1 // indirect
	github.com/spf13/cobra v0.0.3 // indirect
	github.com/spf13/pflag v1.0.3 // indirect
	github.com/stretchr/testify v1.3.0 // indirect
	go.uber.org/atomic v1.3.2 // indirect
	go.uber.org/multierr v1.1.0 // indirect
	go.uber.org/zap v1.9.1 // indirect
	golang.org/x/net v0.0.0-20181106065722-10aee1819953
	golang.org/x/sys v0.0.0-20181206074257-70b957f3b65e // indirect
	google.golang.org/genproto v0.0.0-20190201180003-4b09977fb922 // indirect
	google.golang.org/grpc v1.16.0
	gopkg.in/natefinch/lumberjack.v2 v2.0.0 // indirect
	gopkg.in/yaml.v2 v2.2.2 // indirect
	istio.io/api v0.0.0-20190215181734-2b2fabd45153
	istio.io/istio v0.0.0-20190216013735-f62b4fa7d7ad
)
```

编辑好依赖后,在shell运行

```shell
$ go mod tidy
```

其实这里做了两件事

1,require 引入adapter需要的依赖

2,replace 替换无法获取的代码库为github中的地址

在这里将adapter的依赖和需要替换的包全部编辑好,以免后面引入包失败.

如果对go module 了解的较少,可以参考: [**傻瓜式的 go modules 的讲解和代码.md**](https://gitee.com/tanx/kubernetes-test/blob/master/go/%E5%82%BB%E7%93%9C%E5%BC%8F%E7%9A%84%20go%20modules%20%E7%9A%84%E8%AE%B2%E8%A7%A3%E5%92%8C%E4%BB%A3%E7%A0%81.md) , [**Go模块简介.md**](https://gitee.com/tanx/kubernetes-test/blob/master/go/Go%E6%A8%A1%E5%9D%97%E7%AE%80%E4%BB%8B.md)

### 创建my.go

```shell
$ mkdir adapter
```

在`adapter`文件夹中创建my.go文件,文件内容如下:

```go
package adapter

import (
	"golang.org/x/net/context"
	"istio.io/istio/mixer/template/authorization"
)

var _ authorization.HandleAuthorizationServiceServer = &MyAuth{}

type MyAuth struct {
}
```

`authorization.HandleAuthorizationServiceServer`接口则是我们需要实现的Authorization接口

这里可能很多人都会疑问,这个接口在哪里找,其他的template提供的接口怎么去找.

其实这里很简单,在mixer的源代码中就有proto描述,例如Authorization:

```shell
$ cd $GOPATH/src/istio.io/istio/mixer/template && tree
.
├── apikey
│   ├── apiKey.pb.html
│   ├── template_handler.gen.go
│   ├── template_handler_service.descriptor_set
│   ├── template_handler_service.pb.go
│   ├── template_handler_service.proto				#这个就是声明文件
│   ├── template.proto
│   ├── template_proto.descriptor_set
│   └── template.yaml
├── authorization
│   ├── authorization.pb.html
│   ├── template_handler.gen.go
│   ├── template_handler_service.descriptor_set
│   ├── template_handler_service.pb.go
│   ├── template_handler_service.proto				#这个就是声明文件
│   ├── template.proto
│   ├── template_proto.descriptor_set
│   └── template.yaml
├── checknothing
│   ├── checkNothing.pb.html
│   ├── template_handler.gen.go
│   ├── template_handler_service.descriptor_set
│   ├── template_handler_service.pb.go
│   ├── template_handler_service.proto
│   ├── template.proto
│   ├── template_proto.descriptor_set
│   └── template.yaml
...
```

打开`template_handler_service.proto`就可以看到

```protobuf
package authorization;

#省略n个字符
// HandleAuthorizationService is implemented by backends that wants to handle request-time 'authorization' instances.
service HandleAuthorizationService {
    // HandleAuthorization is called by Mixer at request-time to deliver 'authorization' instances to the backend.
    rpc HandleAuthorization(HandleAuthorizationRequest) returns (istio.mixer.adapter.model.v1beta1.CheckResult);
    
}
#省略n个字符
```

通过package的值 和 service的声明就可以直接找到此接口(当然在idea中也可以直接搜索找到此接口)

我们让`MyAuth`实现此接口,则我们的代码中还需要添加如下代码:

```go
package adapter

import (
	"encoding/json"
	"fmt"
	"golang.org/x/net/context"
	"istio.io/api/mixer/adapter/model/v1beta1"
	"istio.io/istio/mixer/pkg/status"
	"istio.io/istio/mixer/template/authorization"
)

var _ authorization.HandleAuthorizationServiceServer = &MyAuth{}

type MyAuth struct {
}

func (*MyAuth) HandleAuthorization(ctx context.Context, request *authorization.HandleAuthorizationRequest) (*v1beta1.CheckResult, error) {
	bytes, e := json.Marshal(request)
	if e != nil {
		fmt.Println("序列化失败,", e.Error())
	}
	fmt.Printf("%s \n", string(bytes))
	return &v1beta1.CheckResult{
		Status: status.OK,
	}, nil
}

```

> 这里我写详细一些,可以让各位少走很多弯路.

根据以上代码,我们的adapter其实什么事情都没有干,只是将 request 序列化为json 然后打印了出来, 然后回复了一个Status为OK的请求,各位可以基于此方法定制自己的逻辑,但是在此处,我将以最简单的方式来做.

### 创建adapter启动文件

adapter的处理已经创建好了,那么接下来我们就启动这个grpc的server就好了.

在项目根目录创建main.go

```go
package main

import (
	"fmt"
	"google.golang.org/grpc"
	"istio-my-adapter/adapter"
	"istio.io/istio/mixer/template/authorization"
	"net"
)

func main() {
    //创建grpc服务器
	server := grpc.NewServer()
	auth := &adapter.MyAuth{}
    //注册服务到grpc
	authorization.RegisterHandleAuthorizationServiceServer(server, auth)
    //启动9999端口监听tcp数据
	listener, e := net.Listen("tcp", fmt.Sprintf(":%s", "9999"))
	if e != nil {
		println("tcp监听错误,", e.Error())
	}
    //启动
	if e := server.Serve(listener); e != nil {
		fmt.Println("grpc启动错误,", e.Error())
	}
}

```

是不是贼简单.

### 创建check数据文件

在项目根目录创建一个config目录(因为istio官方的mixer教程是创建config),并在其中定义通信数据

```shell
mkdir config
```

`my.proto`

```proto
syntax = "proto3";

// config for my-adapter
package adapter.my.config;

import "gogoproto/gogo.proto";

option go_package = "config";

// config for myadapter
// 这里是对应handler中的字段
message Params {
    // Path of the file to save the information about runtime requests.
    //这里是在handler上启动填写的参数
    string file_path = 1;
}
```

写好了proto文件后,我们就可以使用protoc生成我们需要的源代码啦

### protoc生成文件

在开始生成文件前,国内用户一定要做一个准备工作,因为mixer_codegen.sh文件依赖一个`gcr.io/istio-testing/protoc` docker image,所以你需要先拉取下来

```shell
$ docker pull tangxusc/istio-protoc-mirror:latest
$ docker tag tangxusc/istio-protoc-mirror:latest gcr.io/istio-testing/protoc:2018-06-12
```

拉取完成镜像后,麻烦又来了,mixer_codegen.sh 传入的 路径是相对于$GOPATH的,所以这里有两个方式:

1,做个连接(link),把项目的config目录连接到$GOPATH下的某个地方

2,把proto拷贝过去

> 如果有更好的方式,请一定告诉我

为了简单,这里我们直接使用第二种

```shell
$ cp config/*.proto $GOPATH/src/istio.io/istio/myadapter/
```

然后使用protoc开始生成源代码和adapter描述文件

```shell
$ sh $GOPATH/src/istio.io/istio/bin/mixer_codegen.sh -a myadapter/my.proto -x "-s=false -n myadapter -t authorization"
```

或者在my.go中直接写:

```go
//go:generate $GOPATH/src/istio.io/istio/bin/mixer_codegen.sh -a myadapter/my.proto -x "-s=false -n myadapter -t authorization"

package adapter
...
```

然后运行

```shell
go generate ./...
```

重要参数释义:

-s :`true` 基于会话模型(尚未实现) `false` 基于无会话模型

-n : adapter名称

-t : template名称

-a : 输入的文件位置

执行命令后将生成文件如下:

```shell
$ pwd && tree
$GOPATH/src/istio.io/istio/myadapter
.
├── adapter.my.config.pb.html
├── myadapter.yaml
├── my.pb.go
├── my.proto
└── my.proto_descriptor
0 directories, 5 files
```

拷贝`myadapter.yaml`至项目的config目录内
### 配置handler/instance/rule

这三个都是老朋友了,直接给出配置好的文件`istio.yaml`如下:

```yaml
apiVersion: "config.istio.io/v1alpha2"
kind: handler
metadata:
  name: my
  namespace: istio-system
spec:
  adapter: myadapter
  connection:
    address: "my.istio-system:9999"
  params:	#这就是proto中配置的Params
    file_path: "/test/a.txt"
---
apiVersion: "config.istio.io/v1alpha2"
kind: instance
metadata:
  name: my
  namespace: istio-system
spec:
  template: authorization
  params:
    subject:
      properties:
        request_path: request.path | "/"
        source_name: source.name | ""
        source_namespace: source.namespace | ""
        destination_name: destination.name | ""
        destination_namespace: destination.namespace | ""
        source_workload_name: source.workload.name | ""
        source_workload_namespace: source.workload.namespace | ""
        destination_workload_name: destination.workload.name | ""
        destination_workload_namespace: destination.workload.namespace | ""
        destination_service_host: destination.service.host | ""

---
apiVersion: "config.istio.io/v1alpha2"
kind: rule
metadata:
  name: r1
  namespace: istio-system
spec:
  match: ""
  actions:
    - handler: my.handler.istio-system
      instances:
        - my.instance.istio-system
```

## 测试

在做好以上步骤后,我们可以在我们本地测试一下我们的代码是否正确,mixer的adapter测试有两种方式:

- 使用golang代码进行测试 : 在项目中嵌入golang测试文件,并运行golang的单元测试

- 使用mixs和mixc进行测 : 启动mixs作为服务端,并监听本地的配置文件,启动mixc作为客户端向mixs发送check等请求,mixs再通过grpc转发到具体的adapter上.

  毫无疑问,第二种更适合真正的istio集群的情况(不是说第一种不好),所以在此我们选择使用mixs和mixc进行测试

### 准备

1. 编译mixs和mixc (如果前面已经编译,则此处不用再编译)

   ```shell
   cd $GOPATH/src/istio.io/istio/ && make mixs && make mixc
   ```

2. 创建测试文件夹及文件

   ```shell
   mkdir 项目根目录/testdata
   cp 项目根目录/k8s/istio.yaml 项目根目录/testdata/
   cp 项目根目录/config/
   cp $GOPATH/src/istio.io/istio/mixer/testdata/config/attributes.yaml 目根目录/testdata/
   cp $GOPATH/src/istio.io/istio/mixer/template/authorization/template.yaml 目根目录/testdata/
   ```

   拷贝完成后目录是这样的:

   ```shell
   /testdata$ tree
   ├── attributes.yaml
   ├── istio.yaml
   ├── myadapter.yaml
   └── template.yaml
   0 directories, 4 files
   ```

3. 启动adapter

   ```shell
   $ go run main.go
   ```

   在此,我们启动了grpc服务器,并暴露在`9999`端口上

4. 启动mixs

   ```shell
   ./mixs server --configStoreURL=fs:///项目路径/istio-my-adapter/testdata/ --log_output_level=attributes:debug
   ```

   >  注意: 如果出现未找到mixs等错误,请配置你的Path,`$GOPATH/out/linux_amd64/release/`必须包含在path中,才能找到mixs和mixc的执行文件
   >
   > 注意: `fs://` 标示文件系统,后面是文件系统的路径,所以才会出现三个`/`

5. 启动mixc

   ```shell
   ./mixc check -s destination.service="svc.cluster.local" -s request.path="/test222"
   ```

6. 在执行了以上命令后就可以在控制台和adapter上均可以看到结果了

## 部署准备

### 生成adapter镜像

当我们确认好了我们的adapter工作正常后,adapter要以容器的方式来运行,所以我们需要编写Dockerfile,并生成为镜像:

`Dockerfile` 如下:

```dockerfile
# docker build -t my-adapter:2 .
FROM ubuntu
WORKDIR /
ADD main /main
EXPOSE 9999
CMD ["./main"]
```

```shell
$ go build main.go
$ docker build -t my-adapter:2 .
```

### 配置adapter工作负载

adapter需要以工作负载的方式运行在k8s中,所以在此处,我们需要配置工作负载文件`k8s.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my
  namespace: istio-system
  labels:
    app: my
spec:
  replicas: 1
  template:
    metadata:
      name: my
      labels:
        app: my
    spec:
      containers:
        - name: my
          image: my-adapter:2
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 9999
              protocol: TCP
      restartPolicy: Always
  selector:
    matchLabels:
      app: my
---
apiVersion: v1
kind: Service
metadata:
  name: my
  namespace: istio-system
spec:
  selector:
    app: my
  ports:
  - port: 9999
    targetPort: 9999
    protocol: TCP
```

一切就绪后,我们就可以部署到我们的istio集群中进行验证了.

## 部署

### 部署测试服务

​	测试服务部署: [nginx服务](https://gitee.com/tanx/kubernetes-test/tree/master/%E8%BF%88%E5%90%91istio/1-istio-%E7%A4%BA%E4%BE%8B)

### 部署adapter

```shell
kubectl apply -f istio.yaml
kubectl apply -f k8s.yaml
kubectl apply -f myadapter.yaml
```

现在使用curl访问istio集群中的任意服务,在Deployment中的容器将会打印如下信息:

```json
"instance":{"name":"my.instance.istio-system","subject":{"properties":{"request_path":{"Value":{"StringValue":"/test"}},"destination_name":{"Value":{"StringValue":"unknown"}},"destination_namespace":{"Value":{"StringValue":"default"}},"destination_service_host":{"Value":{"StringValue":"nginx.test.svc.cluster.local"}},"destination_workload_name":{"Value":{"StringValue":"unknown"}},"destination_workload_namespace":{"Value":{"StringValue":"unknown"}},"source_name":{"Value":{"StringValue":"istio-ingressgateway-6fc88db97f-98qs8"}},"source_namespace":{"Value":{"StringValue":"istio-system"}},"source_workload_name":{"Value":{"StringValue":"istio-ingressgateway"}},"source_workload_namespace":{"Value":{"StringValue":"istio-system"}}}}},"adapter_config":{"type_url":"type.googleapis.com/adapter.my.config.Params","value":"CgsvdGVzdC9hLnR4dA=="},"dedup_id":"11419436721688692556"}

{"instance":{"name":"my.instance.istio-system","subject":{"properties":{"request_path":{"Value":{"StringValue":"/"}},"destination_name":{"Value":{"StringValue":"nginx-69d9d7887c-rtnbh"}},"destination_namespace":{"Value":{"StringValue":"test"}},"destination_service_host":{"Value":{"StringValue":""}},"destination_workload_name":{"Value":{"StringValue":"nginx"}},"destination_workload_namespace":{"Value":{"StringValue":"test"}},"source_name":{"Value":{"StringValue":"istio-ingressgateway-6fc88db97f-98qs8"}},"source_namespace":{"Value":{"StringValue":"istio-system"}},"source_workload_name":{"Value":{"StringValue":"istio-ingressgateway"}},"source_workload_namespace":{"Value":{"StringValue":"istio-system"}}}}},"adapter_config":{"type_url":"type.googleapis.com/adapter.my.config.Params","value":"CgsvdGVzdC9hLnR4dA=="},"dedup_id":"11419436721688692557"}
```

到此,自定义adapter完成.

## 总结

整体来说,自定义一个adapter还是需要依赖不少的知识的.

- 在通信上需要各位对grpc有一定的了解
- 在整体交互上需要各位了解mixer的一些设计,并且知道sidecar的交互过程
- 在编译istio的过程中可能会出现一些包无法获取到,需要翻墙的情况,这就只能手动去做了
- 在配置handler等声明时,很容易出现各种错误,这就需要一点一点的查日志找原因了
- 本示例本身以简单为主,并没有真正的功能,但是各位在此基础上拓展应该较为容易
- 写好adapter代码后不建议直接放到集群中进行测试需要进一步验证后再进行测试,这样方便确定问题所在

## 参照

[Mixer Out Of Process Adapter Dev Guide](https://github.com/istio/istio/wiki/Mixer-Out-Of-Process-Adapter-Dev-Guide)

[Mixer Out of Process Adapter Walkthrough](https://github.com/istio/istio/wiki/Mixer-Out-Of-Process-Adapter-Walkthrough#step-4-write-sample-operator-config)

[Policies and Telemetry](https://istio.io/docs/concepts/policies-and-telemetry/)

[通过自定义Istio Mixer Adapter在JWT场景下实现用户封禁](https://mp.weixin.qq.com/s?__biz=MzIwNDIzODExOA==&mid=2650166632&idx=1&sn=2417079d18383a399f7dac23a85b3e69&chksm=8ec1c921b9b64037651a7970401cd973eb11718a81d8f2fbc10bba9f190d7e736142c635e210&mpshare=1&scene=1&srcid=#rd)

[mixer template](https://github.com/istio/istio/tree/master/mixer/template)

