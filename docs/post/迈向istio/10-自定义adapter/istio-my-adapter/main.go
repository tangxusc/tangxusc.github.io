package main

import (
	"fmt"
	"google.golang.org/grpc"
	"istio-my-adapter/adapter"
	"istio.io/istio/mixer/template/authorization"
	"net"
)

func main() {
	server := grpc.NewServer()
	auth := &adapter.MyAuth{}
	authorization.RegisterHandleAuthorizationServiceServer(server, auth)
	listener, e := net.Listen("tcp", fmt.Sprintf(":%s", "9999"))
	if e != nil {
		println("tcp监听错误,", e.Error())
	}
	if e := server.Serve(listener); e != nil {
		fmt.Println("grpc启动错误,", e.Error())
	}
}
