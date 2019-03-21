---
title: "gRPC-interceptor"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- golang
- grpc
- interceptor
tags:
- golang
- grpc
- interceptor
keywords:
- golang
- grpc
- interceptor
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://colobu.com/2017/04/17/dive-into-gRPC-interceptor/

gRPC-Go 增加了拦截器 (interceptor) 的功能， 就像 Java Servlet 中的 filter 一样，可以对 RPC 的请求和响应进行拦截处理，而且既可以在客户端进行拦截，也可以对服务器端进行拦截。

利用拦截器，可以对 gRPC 进行扩展，利用社区的力量将 gRPC 发展壮大，也可以让开发者更灵活地处理 gRPC 流程中的业务逻辑。下面列出了利用拦截器实现的一些功能框架：

1.  [Go gRPC Middleware](https://github.com/grpc-ecosystem/go-grpc-middleware): 提供了拦截器的 interceptor 链式的功能，可以将多个拦截器组合成一个拦截器链，当然它还提供了其它的功能，所以以 gRPC 中间件命名。
2.  [grpc-multi-interceptor](https://github.com/kazegusuri/grpc-multi-interceptor): 是另一个 interceptor 链式功能的库，也可以将单向的或者流式的拦截器组合。
3.  [grpc_auth](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/auth): 身份验证拦截器
4.  [grpc_ctxtags](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/tags): 为上下文增加`Tag` map 对象
5.  [grpc_zap](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/logging/zap): 支持`zap`日志框架
6.  [grpc_logrus](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/logging/logrus): 支持`logrus`日志框架
7.  [grpc_prometheus](https://github.com/grpc-ecosystem/go-grpc-prometheus): 支持 `prometheus`
8.  [otgrpc](https://github.com/grpc-ecosystem/grpc-opentracing/tree/master/go/otgrpc): 支持 opentracing/zipkin
9.  [grpc_opentracing](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/tracing/opentracing): 支持 opentracing/zipkin
10.  [grpc_retry](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/retry): 为客户端增加重试的功能
11.  [grpc_validator](https://github.com/grpc-ecosystem/go-grpc-middleware/blob/master/validator): 为服务器端增加校验的功能
12.  [xrequestid](https://github.com/mercari/go-grpc-interceptor/tree/master/xrequestid): 将 request id 设置到 context 中
13.  [go-grpc-interceptor](https://github.com/mercari/go-grpc-interceptor/tree/master/acceptlang): 解析`Accept-Language`并设置到 context
14.  [requestdump](https://github.com/mercari/go-grpc-interceptor/tree/master/requestdump): 输出 request/response

也有其它一些文章介绍的利用拦截器的例子，如下面的两篇文章：
[Introduction to OAuth on gRPC](https://texlution.com/post/oauth-and-grpc-go/)、[gRPC 实践 拦截器 Interceptor](https://segmentfault.com/a/1190000007997759)

相信会有更多有趣的拦截器被贡献出来。

注意，服务器只能配置一个 unary interceptor 和 stream interceptor，否则会报错，客户端也是，虽然不会报错，但是只有最后一个才起作用。 如果你想配置多个，可以使用前面提到的拦截器链或者自己实现一个。

实现拦截器麻烦吗？一点都不麻烦，相反，非常的简单。

对于服务器端的单向调用的拦截器，只需定义一个`UnaryServerInterceptor`方法:

```go
type UnaryServerInterceptor func(ctx context.Context, req interface{}, info *UnaryServerInfo, handler UnaryHandler) (resp interface{}, err error)
```
对于服务器端 stream 调用的拦截器，只需定义一个`StreamServerInterceptor`方法:
```go
type StreamServerInterceptor func(srv interface{}, ss ServerStream, info *StreamServerInfo, handler StreamHandler) error
```
方法的参数中包含了上下文，请求和 stream 以及要调用对象的信息。

对于客户端的单向的拦截，只需定义一个 `UnaryClientInterceptor` 方法：
```go
type UnaryClientInterceptor func(ctx context.Context, method string, req, reply interface{}, cc *ClientConn, invoker UnaryInvoker, opts ...CallOption) error
```
对于客户端的 stream 的拦截，只需定义一个 `StreamClientInterceptor` 方法：
```go
type StreamClientInterceptor func(ctx context.Context, desc *StreamDesc, cc *ClientConn, method string, streamer Streamer, opts ...CallOption) (ClientStream, error)
```
你可以查看上面提到的一些开源的拦截器的实现，它们的实现都不是太复杂，下面我们以一个简单的例子来距离，在方法调用的前后打印一个 log。

**Server 端的拦截器**
```go
package main
import (
	"log"
	"net"
	"flag"
	pb "github.com/smallnest/grpc/a/pb"
	"golang.org/x/net/context"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)
var (
	port = flag.String("p", ":8972", "port")
)
type server struct{}
func (s *server) SayHello(ctx context.Context, in *pb.HelloRequest) (*pb.HelloReply, error) {
	return &pb.HelloReply{Message: "Hello " + in.Name}, nil
}
func main() {
	flag.Parse()
	lis, err := net.Listen("tcp", *port)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer(grpc.StreamInterceptor(StreamServerInterceptor),
		grpc.UnaryInterceptor(UnaryServerInterceptor))
	pb.RegisterGreeterServer(s, &server{})
	reflection.Register(s)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
func UnaryServerInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	log.Printf("before handling. Info: %+v", info)
	resp, err := handler(ctx, req)
	log.Printf("after handling. resp: %+v", resp)
	return resp, err
}
// StreamServerInterceptor is a gRPC server-side interceptor that provides Prometheus monitoring for Streaming RPCs.
func StreamServerInterceptor(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
	log.Printf("before handling. Info: %+v", info)
	err := handler(srv, ss)
	log.Printf("after handling. err: %v", err)
	return err
}
```

`grpc.NewServer`可以将拦截器作为参数传入，在提供服务的时候，我们可以看到拦截器打印出 log:
```shell
2017/04/17 23:34:20 before handling. Info: &{Server:0x17309c8 FullMethod:/pb.Greeter/SayHello}
2017/04/17 23:34:20 after handling. resp: &HelloReply{Message:Hello world,}
```

**客户端的拦截器**

```go
package main
import (
	//"context"
	"flag"
	"log"
	"golang.org/x/net/context"
	pb "github.com/smallnest/grpc/a/pb"
	"google.golang.org/grpc"
)
var (
	address = flag.String("addr", "localhost:8972", "address")
	name    = flag.String("n", "world", "name")
)
func main() {
	flag.Parse()
	// 连接服务器
	conn, err := grpc.Dial(*address, grpc.WithInsecure(), grpc.WithUnaryInterceptor(UnaryClientInterceptor),
		grpc.WithStreamInterceptor(StreamClientInterceptor))
	if err != nil {
		log.Fatalf("faild to connect: %v", err)
	}
	defer conn.Close()
	c := pb.NewGreeterClient(conn)
	r, err := c.SayHello(context.Background(), &pb.HelloRequest{Name: *name})
	if err != nil {
		log.Fatalf("could not greet: %v", err)
	}
	log.Printf("Greeting: %s", r.Message)
}
func UnaryClientInterceptor(ctx context.Context, method string, req, reply interface{}, cc *grpc.ClientConn, invoker grpc.UnaryInvoker, opts ...grpc.CallOption) error {
	log.Printf("before invoker. method: %+v, request:%+v", method, req)
	err := invoker(ctx, method, req, reply, cc, opts...)
	log.Printf("after invoker. reply: %+v", reply)
	return err
}
func StreamClientInterceptor(ctx context.Context, desc *grpc.StreamDesc, cc *grpc.ClientConn, method string, streamer grpc.Streamer, opts ...grpc.CallOption) (grpc.ClientStream, error) {
	log.Printf("before invoker. method: %+v, StreamDesc:%+v", method, desc)
	clientStream, err := streamer(ctx, desc, cc, method, opts...)
	log.Printf("before invoker. method: %+v", method)
	return clientStream, err
}
```
通过`grpc.WithUnaryInterceptor`、`grpc.WithStreamInterceptor`可以将拦截器传递给`Dial`做参数。在客户端调用的时候，可以查看拦截器输出的日志:
```shell
2017/04/17 23:34:20 before invoker. method: /pb.Greeter/SayHello, request:&HelloRequest{Name:world,}
2017/04/17 23:34:20 after invoker. reply: &HelloReply{Message:Hello world,}
2017/04/17 23:34:20 Greeting: Hello world
```
通过这个简单的例子，你可以很容易的了解拦截器的开发。unary 和 stream 两种类型的拦截器可以根据你的 gRPC server/client 实现的不同，有选择的实现。