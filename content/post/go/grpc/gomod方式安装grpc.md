---
title: "使用go mod(1.11)安装grpc"
date: 2019-03-20T14:15:59+08:00
draft: false
---

## 优势

不在使用git clone具体的golang库的源代码

安装较为简单

## 查看golang版本

```shell
$ go version
go version go1.11 linux/amd64
```

因为go1.11才有了go mod 所以在此必须使用1.11版本

## 配置protoc

在 `https://github.com/protocolbuffers/protobuf/releases`中下载对应平台的版本到系统中.

版本规则为`protoc-<version>-<platform>.zip`

```shell
$ wget https://github.com/protocolbuffers/protobuf/releases/download/v3.6.1/protoc-3.6.1-linux-x86_64.zip
$ unzip -o -d /protoc-3.6.1-linux-x86_64 protoc-3.6.1-linux-x86_64.zip
```

protoc 即Protocol Buffers v3 用于生成gRPC服务代码的protoc编译器

### 配置环境变量

```shell
$ sudo vim /etc/profile
export protoc=<刚才解压的路径>/protoc-3.6.1-linux-x86_64
export PATH=$PATH:$GOROOT/bin:$protoc/bin
```

在其中配置protoc的bin文件夹的位置

### 测试

```shell
$ protoc --version
libprotoc 3.6.1
```

## 安装插件

因为在国内是访问不到golang官方的一些仓库的,所以此处我们需要建立一个项目 然后让此项目替我们拉取插件.

### 拉取插件

```shell
#创建文件夹
$ mkdir temp && cd temp
#初始化模块
$ go mod init
#替换模块中一些依赖包
$ go mod edit -replace=golang.org/x/net@v0.0.0-20181023162649-9b4f9f5ad519=github.com/golang/net@v0.0.0-20181023162649-9b4f9f5ad519
$ go mod edit -replace=golang.org/x/tools@v0.0.0-20181221001348-537d06c36207=github.com/golang/tools@v0.0.0-20181221001348-537d06c36207
#获取插件
$ go get -u github.com/golang/protobuf/{proto,protoc-gen-go}
```

需要耐心等待插件的拉取完成,并且在插件拉取完成后会在$GOPATH/bin中生成名称为`protoc-gen-go`的可执行文件

### 配置环境变量

```shell
$ sudo vim /etc/profile
export GOPATH=/home/tangxu/go
export PATH=$PATH:$GOROOT/bin:$protoc/bin:$GOPATH/bin
```

# 测试工程(可选)

接下来我们可以使用一个测试的工程来测试是否安装成功

`helloworld.proto`

```shell
syntax = "proto3";

option java_multiple_files = true;
option java_package = "io.grpc.examples.helloworld";
option java_outer_classname = "HelloWorldProto";

package helloworld;

// The greeting service definition.
service Greeter {
  // Sends a greeting
  rpc SayHello (HelloRequest) returns (HelloReply) {}
}

// The request message containing the user's name.
message HelloRequest {
  string name = 1;
}

// The response message containing the greetings
message HelloReply {
  string message = 1;
}
```

在此目录中执行

```shell
$ protoc --go_out=plugin=grpc:. *.proto
#或者
$ protoc --gofast_out=plugins=grpc:. *.proto
```

即可生成`helloworld.pb.go`文件

#### 参照
1.golang.org\x\net\context => github.com/golang/net 里面包含context，dns，http2

2.golang.org/x/text/secure/bidirule => github.com/golang/text 里面包含cmd，currency，secure

3.google.golang.org/grpc => github.com/grpc/grpc-go 里面包含connectivity，grpclb，grpclog

4.google.golang.org/genproto => github.com/google/go-genproto 里面包含googleapis，protobuf