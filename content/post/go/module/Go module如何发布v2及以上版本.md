---
title: "Go Module如何发布v2及以上版本"
date: 2019-11-20T09:15:59+08:00
draft: false
categories:
- golang
tags:
- golang
keywords:
- golang
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://blog.cyeam.com/go/2019/03/12/go-version

用上 go mod 之后，依赖包都是通过版本打 tag 的形式确定版本号。比如 `github.com/mnhkahn/gogogo v1.0.9`。每次都改动都是在累加低位的版本号，一直这么用也挺安逸的。突然有一天，我的一个底层包需要大改，导致和之前的版本彻底不兼容，这种情况下如何设置版本号，如何能让调用方成功接入？

<!--more-->

### Go module 版本号

先讲一下 Go 在用的版本号协议 [semver (Semantic Versioning)](https://semver.org/)。它定义的版本号格式是：

> vMAJOR.MINOR.PATCH

*   MAJOR 主版本号，如果有大的版本更新，导致 API 和之前版本不兼容。我们遇到的就是这个问题。
*   MINOR 次版本号，当你做了向下兼容的新 feature。
*   PATCH 修订版本号，当你做了向下兼容的修复 bug fix。
*   v 所有版本号都是 v 开头。

比如我们用的 Go 语言，目前是 1.12.0。它还是 Go 1，每次升级都保证是兼容的，12 的版本号是新 feature，而最末尾的版本号是修复。说明当前的版本上了之后还没有修复过问题。

我这次也是搞了一个不兼容的更新，所以需要升级到 v2.0.0。

### Go 项目如何升级 v2？

假设你的项目已经支持 go module 了。

1.  修改 go.mod 第一行，在`module`那行最后加上`/v2`。`module github.com/mnhkahn/aaa/v2`。
2.  对于不兼容的改动（除了 v0 和 v1），都必须显示得修改 import 的路径。所以我们的引用需要改成 `import "github.com/mnhkahn/aaa/v2/config"`。在所有的地方都需要修改，包括自己的包内和调用方包。
3.  底层包的更新有个小工具可以帮助快速实现 [mod](https://github.com/marwan-at-work/mod)。`GO111MODULE=on go get github.com/marwan-at-work/mod/cmd/mod` `mod upgrade`。
4.  代码提交之后需要打新 tag，v2.0.0。
5.  调用方修改引用代码，需要加`v2`，和第二步提到的一样。
6.  `go get github.com/mnhkahn/aaa/v2`。

### incompatible

有时候你能在 go.mod 文件中发现不兼容的标记，`v3.2.1+incompatible`，这是因为这个依赖包没有使用 go module，并且它通过 git 打了 tag。

### v0.0.0-20190312205133-abcdefghijklm

对于没有打 tag 的仓库，go.mod 就会很丑陋，它的格式是 [pseudo-version](https://golang.org/cmd/go/#hdr-Pseudo_versions)。它的含义是`v0.0.0-yyyymmddhhmmss-abcdefabcdef`。

### tag 删除了重建为什么没效果？

困扰了我很久的一个问题。有一个 tag v2.0.0 的代码有问题，我删除了这个 tag，新建了一个好的版本，但是`go get`依然报错，困扰了很久，一直以为是 v2 的版本号写错了。后来才发现是 go 有本地缓存，缓存在 $GOPATH/pkg/mod/cache 下面，把里面的内容清掉，重新获取即可。
