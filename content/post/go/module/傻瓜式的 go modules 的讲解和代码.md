---
title: "傻瓜式的 go modules 的讲解和代码"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- golang
- module
tags:
- golang
- module
keywords:
- golang
- module
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://it.520mwx.com/view/10804

傻瓜式的 go modules 的讲解和代码
<!--more-->

# 一

国内关于 gomod 的文章，哪怕是使用了百度 -csdn，依然全是理论，虽然 golang 的使用者大多是大神但是也有像我这样的的弱鸡是不是？

所以，我就写个傻瓜式教程了。

# 二

1\. 新建文件夹 go_moudiules_demo

2.go mod 之，生成 gomod.go 文件

<pre>go mod init go_moudiules_demo
语法
go mod init [module]</pre>

![](https://blogimg-1256334314.cos.ap-chengdu.myqcloud.com/b0f99920-62af-41a8-a817-68efc50fd418.png)

3\. 创建 main.go，默认包名是 gomod，需要改成 main

![](https://blogimg-1256334314.cos.ap-chengdu.myqcloud.com/63f68e2f-031c-4cee-b544-83c1a5a14150.png)

4\. 创建正真的存放代码的文件夹 demo 和文件 gomod.go，注意不能与 main 放在同一文件夹下，因为会造成包名冲突

![](https://blogimg-1256334314.cos.ap-chengdu.myqcloud.com/2ec21bec-06f5-4879-a656-fa324e06caae.png)

 5\. 根据规则引入代码，这里有个坑，因为 goland 做的不太好，实际上 golang 的所有工具都做的不太好，导致代码报红，但是实际上 go build/run 还是能跑通的

 ![](https://blogimg-1256334314.cos.ap-chengdu.myqcloud.com/a77aafa0-b5f1-4b72-acff-0463b932b2cf.png)

当然 goland 也可以配置，就是不知道怎么去红名。。。　　

![](https://blogimg-1256334314.cos.ap-chengdu.myqcloud.com/ea1c5dd3-1bb2-46e5-92ee-0a39d536d516.png)

#  三 总结

gomod 最容易让人进了误区就是，把自己之前的代码都 gomod 一次，那么后面使用的时候直接根据 gomod 的 package 找之前的代码，简直美滋滋。

毕竟是 go moudules 但是，实际上只是 go moudule，他只管一个项目里的多个包。

为什么造成这个误区呢？因为国内说的都是包管理，我还真以为是针对包的操作，然后第一次尝试失败后，翻了下官网

```shell
A module is a collection of related Go packages. 
Modules are the unit of source code interchange and versioning.
The go command has direct support for working with modules, including recording and resolving dependencies on other modules.
Modules replace the old GOPATH-based approach to specifying which source files are used in a given build.
```

** a collection of related Go packages.** 相关Go包的集合，这玩意的理解真的是难，什么相关，相关的是什么？这时候根据官网的usage代码反向理解下，显然是module的相关Go包的集合，而module是一个单数啊。。。
``module``和go mudules。。。我该如何理解啊。。。模板我倒是知道。。。总感觉这个怪不到谷歌头上，而且这玩意大家试个两下，就能找到正确理解也不算什么事。而且我要是把自己的代码都丢到github上同样不会报错，只是我是想着不丢到github上面的使用所以进了歪路。

而第二句 **Modules are the unit of source code interchange and versioning. 
**Modules**** 是源码的版本控制和交换的单位，也就说明 go mod 之间是独立的，，，不能互调，除非在 gopath 里面。感觉大神看到这句两下都不用试了。。。

# 四 语法解析

主要是一个人的博客 http://blog.51cto.com/qiangmzsx/2164520?source=dra

我把其中的关键抽出来，去掉他的代码，有兴趣的可以去原文看看

<pre>    go mod init:初始化modules
    go mod download:下载modules到本地cache
    go mod edit:编辑go.mod文件，选项有-json、-require和-exclude，可以使用帮助go help mod edit
    go mod graph:以文本模式打印模块需求图
    go mod tidy:删除错误或者不使用的modules
    go mod vendor:生成vendor目录
    go mod verify:验证依赖是否正确
    go mod why：查找依赖

    go test    执行一下，自动导包

    go list -m  主模块的打印路径
    go list -m -f={{.Dir}}  print主模块的根目录
    go list -m all  查看当前的依赖和版本信息</pre>

原文链接：https://www.cnblogs.com/ydymz/p/9788804.html