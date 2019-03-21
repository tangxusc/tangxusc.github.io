package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/proxy", handler)
	http.HandleFunc("/index", indexHandler)
	serve := http.ListenAndServe("0.0.0.0:8090", nil)
	if serve != nil {
		log.Fatalf("启动失败,%v", serve)
	} else {
		fmt.Fprintf(os.Stdout, "启动成功")
	}
}

func handler(writer http.ResponseWriter, request *http.Request) {
	fmt.Printf("proxy请求begin\n")
	request.ParseForm()
	get := request.Form.Get("url")
	fmt.Printf("请求地址:%s\n", get)
	for key, value := range request.Form {
		fmt.Printf("请求参数 [%s]:%s \n", key, value)
	}
	for key, value := range request.Header {
		fmt.Printf("header参数 [%s]:%s \n", key, value)
	}

	client := http.DefaultClient
	newRequest, e := http.NewRequest("GET", get, nil)
	if e != nil {
		fmt.Printf("NewRequest error: %v", e)
	}

	//设置header
	//for key, _ := range request.Header {
	//	newRequest.Header.Add(key, request.Header.Get(key))
	//	fmt.Printf("设置转发请求header [%s]:%s \n", key, request.Header.Get(key))
	//}
	if len(request.Header.Get("x-request-id")) > 0 {
		newRequest.Header.Set("x-request-id", request.Header.Get("x-request-id"))
	}
	if len(request.Header.Get("x-b3-traceid")) > 0 {
		newRequest.Header.Set("x-b3-traceid", request.Header.Get("x-b3-traceid"))
	}
	if len(request.Header.Get("x-b3-spanid")) > 0 {
		newRequest.Header.Set("x-b3-spanid", request.Header.Get("x-b3-spanid"))
	}
	if len(request.Header.Get("x-b3-parentspanid")) > 0 {
		newRequest.Header.Set("x-b3-parentspanid", request.Header.Get("x-b3-parentspanid"))
	}
	if len(request.Header.Get("x-b3-sampled")) > 0 {
		newRequest.Header.Set("x-b3-sampled", request.Header.Get("x-b3-sampled"))
	}
	if len(request.Header.Get("x-b3-flags")) > 0 {
		newRequest.Header.Set("x-b3-flags", request.Header.Get("x-b3-flags"))
	}
	if len(request.Header.Get("x-ot-span-context")) > 0 {
		newRequest.Header.Set("x-ot-span-context", request.Header.Get("x-ot-span-context"))
	}

	resp, err := client.Do(newRequest)
	//resp, err := http.Get(get)
	if err != nil {
		fmt.Fprintf(writer, "response:%v", err)
	} else {
		bytes, _ := ioutil.ReadAll(resp.Body)
		defer resp.Body.Close()
		fmt.Fprintf(writer, "%s", bytes)
	}
	fmt.Printf("proxy请求end\n")
}

func indexHandler(writer http.ResponseWriter, request *http.Request) {
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
