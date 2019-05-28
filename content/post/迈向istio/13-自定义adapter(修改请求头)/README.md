---
title: "迈向istio-13 自定义adapter(修改请求头)"
date: 2019-05-28T14:15:59+08:00
categories:
- istio
tags:
- istio
- adapter
keywords:
- istio
- adapter
#thumbnailImage: //example.com/image.jpg
---

在istio中mixer组件负责策略控制和遥测收集数据,是高度模块化和可扩展的组件.

mixer处理不同基础设施后端的灵活性是通过适配器模型插件来实现的,每个插件都被成为`Adapter`,用户通过配置使用Adapter向mixer注册自身,并设置适配规则,绑定模板,mixer通过和每个插件进行grpc连接,对策略和遥测进行操作

<!--more-->

## 前言

在istio的整体设计中,流量管理和mixer应该是我们交互最多的组件了.

流量管理我们侧重使用配置文件对我们的服务流量进行分流管理,而mixer的扩展我们更多的就需要写代码进行扩展了.

在isito1.1.x版本中mixer的adapter已经能修改请求的header了,这给我们带来了太多的便宜.

本文我们将在istio1.1.x版本中实现一个自定义的adapter,使用自定义的template,并在请求的header中注入user,serviceName等信息.

> 注意: 在1.1.x版本中使用mixer的check功能,需要启用check功能,详见 [升级到1.1.2安装](/2019/04/迈向istio-11-升级到1.1.2/)

## 自定义adapter

### 1.准备 基础环境

- istio 1.1.x
- golang 1.2.x(go module)
- goland (或者其他IDE)
- [protoc并安装grpc](/2019/03/使用go-mod1.11安装grpc/)
- k8s集群 

### 2.克隆istio源代码并编译

```shell
$ mkdir -p $GOPATH/src/istio.io/ && cd $GOPATH/src/istio.io/  && git clone https://github.com/istio/istio
## 编译istio
$ cd $GOPATH/src/istio.io/istio && go build ./...
```

编译主要是为了生成出mixs服务端和mixc客户端,在我们测试时将会使用到.

### 3.定义模板

在istio的源码目录中创建文件`authservice`,并在其中生成我们的模板文件:

```shell
$ mkdir authservice 
```

在文件夹中创建文件`template.proto`,内容如下:

```protobuf
syntax = "proto3";

//注意,和文件夹名称一致
package authservice;

import "mixer/adapter/model/v1beta1/extensions.proto";
//声明 模板种类
option (istio.mixer.adapter.model.v1beta1.template_variety) = TEMPLATE_VARIETY_CHECK_WITH_OUTPUT;
//声明 输入参数
message Template {
  string request_jwt = 1;
  string request_path = 2;
  string request_method = 3;
  string source_name= 4;
  string source_namespace= 5;
  string destination_name= 6;
  string destination_namespace= 7;
  string source_workload_name= 8;
  string source_workload_namespace= 9;
  string destination_workload_name= 10;
  string destination_workload_namespace= 11;
  string destination_service_host= 12;
}
//声明输出参数
message OutputTemplate {
  string user = 1;
  string service_name= 2;
}
```

在文件中我们声明了模板`template_variety`,可选值为`Check`,`Report`,`Quota`,`AttributeGenerator`等.

模板的`template_variety`决定了适配器必须实现的方法签名,并且决定了mixer的整体行为.

在文件中我们定义了`Template`和`OutputTemplate`对象,并分别设置了我们关注的字段(输入和输出)

>  整体的格式可以参照 [istio的mixer测试实例](https://github.com/istio/istio/blob/master/mixer/test/keyval/template.proto)
>
> 模板原型文件的具体格式可以在 [模板原型文件](https://github.com/istio/istio/wiki/Mixer-Out-Of-Process-Adapter-Dev-Guide#template-proto-file) 中看到

在定义了模板之后,我们需要将模板生成为go文件,命令如下:

```shell
#在istio的根目录执行
$ bin/mixer_codegen.sh -t authservice/template.proto
no comment found for authservice
authservice/template.proto:19:0: no comment found for OutputTemplate
#省略很多...
authservice/template.proto:16:2: no comment found for destination_service_host
rm：是否删除有写保护的普通文件 '/istio.io/istio/authservice/template.pb.go'？n
#此时目录下的文件
$ tree
.
├── authservice.pb.html
├── template_handler.gen.go
├── template_handler_service.descriptor_set
├── template_handler_service.pb.go
├── template_handler_service.proto
├── template.pb.go
├── template.proto
├── template_proto.descriptor_set
└── template.yaml  #模板文件,描述istio的模板配置
```

> 其中的警告部分输出为提示我们为proto添加注释,便于生成文档
>
> grpc真香.

### 4.生成adapter配置

在`authservice`文件夹中创建子目录`config`

```shell
$ cd authservice && mkdir config && cd config
```

在目录内创建文件`config.proto`,内容如下:

```protobuf
syntax = "proto3";
import "google/protobuf/duration.proto";
import "gogoproto/gogo.proto";
package config;
message Params {
  google.protobuf.Duration valid_duration = 1 [(gogoproto.nullable)=false, (gogoproto.stdduration) = true];
}
```

然后通过命令生成适配器的定义:

```shell
$ cd .. && bin/mixer_codegen.sh -a authservice/config/config.proto -x "-s=false -n authservice -t authservice"
no comment found for config
authservice/config/config.proto:4:0: no comment found for Params
authservice/config/config.proto:5:2: no comment found for valid_duration
#此时目录下的文件
$tree
.
├── authservice.pb.html
├── config
│   ├── authservice.yaml  #此文件为istio的adapter描述文件
│   ├── config.pb.go
│   ├── config.pb.html
│   ├── config.proto
│   └── config.proto_descriptor
├── template_handler.gen.go
├── template_handler_service.descriptor_set
├── template_handler_service.pb.go
├── template_handler_service.proto
├── template.pb.go
├── template.proto
├── template_proto.descriptor_set
└── template.yaml
```

`-n`: 适配器名称

`-t`: 模板名称

`-s`: [基于无会话的模型](https://github.com/istio/istio/wiki/Mixer-Out-Of-Process-Adapter-Dev-Guide#adapter-implementation-choices)

传递这三个参数就是指定 **输出的模板文件中的适配器名称,模板名称**

到此处,`template`和`adapter`的描述文件就生成出来了,`handler`需要实现的接口也生成为了go文件

### 5.实现adapter

在`gopath`外建立go项目,并初始化依赖:

```shell
$ mkdir authService-1.1 && cd authService-1.1 && go mod init authService
```

将`istio/authservice` 拷贝至`authService-1.1`目录下

```shell
$ cp -R istio/authservice authService-1.1/
```

在`authService-1.1`目录下建立`main.go`,内容如下:

```go
package main

import (
	"authService/authservice"
	"encoding/json"
	"fmt"
	"github.com/gogo/googleapis/google/rpc"
	"golang.org/x/net/context"
	"google.golang.org/grpc"
	"istio.io/api/mixer/adapter/model/v1beta1"
	"istio.io/istio/mixer/pkg/status"
	"log"
	"net"
)

type AuthAdapter struct {
}

func (*AuthAdapter) HandleAuthservice(ctx context.Context, request *authservice.HandleAuthserviceRequest) (*authservice.HandleAuthserviceResponse, error) {
	bytes, e := json.Marshal(request)
	if e != nil {
		return nil, e
	}
	fmt.Println("===========请求开始=============")
	fmt.Printf("%s \n", string(bytes))
	fmt.Println("===========请求结束=============")

    //此处模拟认证过程,实际认证需要自行处理
    //当传入了jwt就认为认证通过.
    //返回user:user1,ServiceName:serviceName1 作为模拟数据
	if len(request.Instance.RequestJwt) > 0 {
		return &authservice.HandleAuthserviceResponse{
			Result: &v1beta1.CheckResult{
				Status: status.OK,
			},
			Output: &authservice.OutputMsg{
				User:        "user1",
				ServiceName: "serviceName1",
			},
		}, nil
	} else {
		return &authservice.HandleAuthserviceResponse{
			Result: &v1beta1.CheckResult{
				Status: rpc.Status{Code: int32(rpc.PERMISSION_DENIED)},
			},
			Output: &authservice.OutputMsg{
				User:        "User_PERMISSION_DENIED",
				ServiceName: "ServiceName_PERMISSION_DENIED",
			},
		}, nil
	}

}

func main() {
	//创建grpc服务器
	server := grpc.NewServer()
	auth := &AuthAdapter{}
	//注册服务到grpc
	authservice.RegisterHandleAuthserviceServiceServer(server, auth)
	//启动9999端口监听tcp数据
	listener, e := net.Listen("tcp", fmt.Sprintf(":%s", "9999"))
	if e != nil {
		log.Fatal(fmt.Sprintln("tcp监听错误,%s", e.Error()))
	}
	//启动
	if e := server.Serve(listener); e != nil {
		log.Fatal(fmt.Sprintln("grpc启动错误,%s", e.Error()))
	}
}
```

### 6.测试[可选]
#### 1, 编译mixs和mixc (如果前面已经编译,则此处不用再编译)

```shell
cd $GOPATH/src/istio.io/istio/ && make mixs && make mixc
```

#### 2, 创建测试文件夹及文件

```shell
mkdir 项目根目录/testdata
```
新建文件`项目根目录/testdata/istio.yaml`,内容如下:

```yaml
# handler adapter
apiVersion: "config.istio.io/v1alpha2"
kind: handler
metadata:
  name: my
  namespace: istio-system
spec:
  adapter: authservice
  connection:
    # 请一定注意,这里的地址  和正式部署的地址不一样
    address: "localhost:9999"
  params:
    valid_duration: 1h
---
# instances
apiVersion: "config.istio.io/v1alpha2"
kind: instance
metadata:
  name: my
  namespace: istio-system
spec:
  template: authservice
  params:
    request_jwt: request.headers["jwt"] | ""
    request_path: request.path | "/"
    request_method: request.method | "GET"
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
# rule to dispatch to handler h1
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
    name: result
  requestHeaderOperations:
  - name: user
    values:
    - result.output.user
  - name: serviceName
    values:
    - result.output.service_name
```

拷贝其他文件到testdata:

```shell
cp $GOPATH/src/istio.io/istio/mixer/testdata/config/attributes.yaml 项目根目录/testdata/
cp $GOPATH/src/istio.io/istio/authservice/template.yaml 项目根目录/testdata/
cp $GOPATH/src/istio.io/istio/authservicetest/config/authservice.yaml 项目根目录/testdata/
#拷贝完成后目录是这样的:
/testdata$ tree
├── attributes.yaml
├── authservice.yaml
├── istio.yaml
└── template.yaml
```

#### 3, 启动adapter

```shell
# 在此,我们启动grpc服务器,并暴露在`9999`端口上
$ go run main.go
```

#### 4, 启动mixs

```shell
./mixs server --configStoreURL=fs:///项目路径/testdata/ --log_output_level=attributes:debug
```

>  注意: 如果出现未找到mixs等错误,请配置你的Path,`$GOPATH/out/linux_amd64/release/`必须包含在path中,才能找到mixs和mixc的执行文件
>
> 注意: `fs://` 标示文件系统,后面是文件系统的路径,所以才会出现三个`/`

#### 5, 启动mixc

```shell
./mixc check -s destination.service="svc.cluster.local" -s request.path="/test222"
```

在执行了以上命令后就可以在控制台和adapter上均可以看到结果了

### 7,编译&制作镜像

#### 1,编译

```shell
$ go build main.go
```

编译后将生成`main`这个可执行文件

#### 2,制作为镜像

在目录下创建`Dockerfile`文件,文件内容如下:

```dockerfile
FROM ubuntu
WORKDIR /
ADD main /main
EXPOSE 9999
CMD ["./main"]
```

制作docker镜像命令如下:

```shell
$ docker build -t authservice:v1 .
```

### 8,部署到k8s集群中

#### 1,部署k8s编排

新建文件`k8s.yaml`,内容如下:

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
          # 使用上一步构建的镜像
          image: authservice:v1
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
  name: authservice
  namespace: istio-system
spec:
  selector:
    app: my
  ports:
  - port: 9999
    targetPort: 9999
    protocol: TCP
```

使用kubectl部署Deployment:

```shell
$ kubectl apply -f k8s.yaml
```

#### 2,部署istio配置

新建`istio.yaml`,内容如下:

```yaml
# handler adapter
apiVersion: "config.istio.io/v1alpha2"
kind: handler
metadata:
  name: my
  namespace: istio-system
spec:
  adapter: authservice
  connection:
  # 请一定注意,这里的地址  和正式部署的地址不一样
    address: "authservice.istio-system:9999"
#    address: "localhost:9999"
# params的值为 config.proto中的配置
  params:
    valid_duration: 1h
---
# instances
apiVersion: "config.istio.io/v1alpha2"
kind: instance
metadata:
  name: my
  namespace: istio-system
spec:
  #模板的名称一定要和template.proto对应
  template: authservice
  #模板的参数需要对应
  params:
    request_jwt: request.headers["jwt"] | ""
    request_path: request.path | "/"
    request_method: request.method | "GET"
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
# rule to dispatch to handler h1
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
    name: result
  #此属性用来配置header
  requestHeaderOperations:
  - name: user
    values:
    - result.output.user
  - name: serviceName
    values:
    - result.output.service_name
```

> requestHeaderOperations的具体配置,请参照 [requestHeaderOperations](https://istio.io/docs/reference/config/policy-and-telemetry/istio.policy.v1beta1/#Rule)

然后将template,adapter和istio配置文件依次部署到k8s中.

```shell
$ kubectl apply -f authservice/template.yaml
$ kubectl apply -f authservice/config/authservice.yaml
$ kubectl apply -f istio.yaml
```

至此,完成了整体的自定义adapter的使用. 

> 官方的测试adapter 使用示例如下
>
> https://istio.io/docs/tasks/policy-enforcement/control-headers/




## 答疑

### 在定义mixer的模板中 很多人都会问,这`template_variety`的值在哪里定义的呢?

答: 在定义模板的时候文件中有这么一句:

```protobuf
import "mixer/adapter/model/v1beta1/extensions.proto";
```

此处声明了导入`mixer/adapter/model/v1beta1/extensions.proto`文件,但是这个文件是一个相对的位置,并且使用protoc的`--proto_path`参数指定上下文.

在`bin/mixer_codegen.sh`文件中([源代码](https://github.com/istio/istio/blob/master/bin/mixer_codegen.sh#L73)):

```shell
IMPORTS=(
  "--proto_path=${ROOTDIR}"
  "--proto_path=${ROOTDIR}/vendor/istio.io/api"
  "--proto_path=${ROOTDIR}/vendor/github.com/gogo/protobuf"
  "--proto_path=${ROOTDIR}/vendor/github.com/gogo/googleapis"
  "--proto_path=$optimport"
)
```

`--proto_path`: 指定了要去哪个目录中搜索import中导入的和要编译为.go的proto文件，可以定义多个

所以实际的`extensions.proto`文件位置为:`istio.io/istio/vendor/istio.io/api/mixer/adapter/model/v1beta1/extensions.proto`,在这个文件中对于`TemplateVariety`定义如下([源代码](https://github.com/istio/istio/blob/master/vendor/istio.io/api/mixer/adapter/model/v1beta1/extensions.proto#L25)):

```protobuf

// The available varieties of templates, controlling the semantics of what an adapter does with each instance.
enum TemplateVariety {
    // Makes the template applicable for Mixer's check calls. Instances of such template are created during
    // check calls in Mixer and passed to the handlers based on the rule configurations.
    TEMPLATE_VARIETY_CHECK = 0;
    // Makes the template applicable for Mixer's report calls. Instances of such template are created during
    // report calls in Mixer and passed to the handlers based on the rule configurations.
    TEMPLATE_VARIETY_REPORT = 1;
    // Makes the template applicable for Mixer's quota calls. Instances of such template are created during
    // quota check calls in Mixer and passed to the handlers based on the rule configurations.
    TEMPLATE_VARIETY_QUOTA = 2;
    // Makes the template applicable for Mixer's attribute generation phase. Instances of such template are created during
    // pre-processing attribute generation phase and passed to the handlers based on the rule configurations.
    TEMPLATE_VARIETY_ATTRIBUTE_GENERATOR = 3;
    // Makes the template applicable for Mixer's check calls. Instances of such template are created during
    // check calls in Mixer and passed to the handlers that produce values.
    TEMPLATE_VARIETY_CHECK_WITH_OUTPUT = 4;
}
```

### 生成template出现没找到镜像

`Unable to find image 'gcr.io/istio-testing/protoc:xxxx' locally`

答: `mixer_codegen.sh`通过docker方式工作,依赖`gcr.io/istio-testing/protoc`,所以需要拉取:

```shell
$ docker pull tangxusc/istio-protoc-mirror:latest
$ docker tag tangxusc/istio-protoc-mirror:latest gcr.io/istio-testing/protoc:2018-06-12
```



## 后语

在使用mixer的适配器的时候,同时我们也需要注意到,mixer本身是`无状态的,带有缓存的`,所以这也同时要求我们的adapter需要最好设计为无状态的,带有缓存的,通过这两种缓存机制才能大大降低istio的qps延迟.

mixer的性能问题一直是社区中纠结的所在,并且在1.1中暂时关闭了mixer的check功能,希望在1.2中有所改善吧.

## 参考

- [mixer 介绍(中文)](https://preliminary.istio.io/zh/docs/concepts/policies-and-telemetry/)
- [安装grpc](/2019/03/使用go-mod1.11安装grpc/)
- [使用kubeadm安装HA集群](/2019/03/kubeadm安装ha集群/)
- [官方mixer测试实例](https://github.com/istio/istio/tree/master/mixer/test/keyval)
- [proto文件导入路径](https://www.cnblogs.com/hsnblog/p/9615742.html)
- [官方使用示例](https://istio.io/docs/tasks/policy-enforcement/control-headers/)
