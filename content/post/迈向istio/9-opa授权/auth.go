package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/index", index)
	http.HandleFunc("/auth", authHandler)
	serve := http.ListenAndServe("0.0.0.0:8090", nil)
	if serve != nil {
		log.Fatalf("启动失败,%v", serve)
	} else {
		fmt.Fprintf(os.Stdout, "启动成功")
	}
}

func authHandler(writer http.ResponseWriter, request *http.Request) {
	fmt.Printf("authHandler请求begin\n")
	for key, value := range request.Form {
		fmt.Printf("请求参数 [%s]:%s \n", key, value)
	}
	for key, value := range request.Header {
		fmt.Printf("header参数 [%s]:%s \n", key, value)
	}
	writer.WriteHeader(401)
	fmt.Fprintf(writer, "%s", "401")
	fmt.Printf("authHandler请求end\n")
}

func index(writer http.ResponseWriter, request *http.Request) {
	fmt.Printf("index请求begin\n")
	for key, value := range request.Form {
		fmt.Printf("请求参数 [%s]:%s \n", key, value)
	}
	for key, value := range request.Header {
		fmt.Printf("header参数 [%s]:%s \n", key, value)
	}
	fmt.Fprintf(writer, "%s", "index")
	fmt.Printf("index请求end\n")

}
