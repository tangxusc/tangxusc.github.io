---
title: "golang package和module解析"
date: 2019-05-15T09:15:59+08:00
draft: false
categories:
- golang
tags:
- golang
- module
keywords:
- golang
- module
---

go语言中的package和module是我们经常会用到的功能,本文将详细的描述这两个功能的用法.

> 本文基于golang 1.12.2和go module,之前老的gopath的使用方式不再推荐.

<!--more-->

## package

在golang中我们使用到的很多功能都会由第三方提供,那么在第三方提供这些包的时候,我们会使用import在go文件中引入package,那么package的一些知识你有过了解吗?

1. go的package是由多个`xxx.go`的文件组成的,package内的函数是分布在各个go文件中的(感觉这样不利于查找...)
2. 在同一个package中可以访问私有变量和函数(小写),即时跨越文件.
3. package和目录名称可以不一致,不过文件夹内的package名称必须一致.
4. package不能循环依赖,**推荐的方式是子package依赖父package,但是父package不能依赖子package**
5. package引入的路径书写方式为`<ModuleName>/包所在的目录路径`,也就是说import 后的路径实际上是Module+package的路径(注意,不是名称,因为包的名称和路径不一样)
6. package路径的寻址是从`$Go_path/pkg/mod`开始的,例如`client-go@v0.0.0-20190425172711-65184652c889`,实际的地址为`/home/tangxu/go/pkg/mod/k8s.io/client-go@v0.0.0-20190425172711-65184652c889`,其中`/home/tangxu/go`为`gopath`
7. 对于go.mod中的依赖的修改,推荐使用`go get`方式,避免出现修改不了.

## module

1. 使用`go mod init "导入路径"`来生成`go.mod`文件,例如:

   ```shell
   $ go mod init github.com/robteix/testmod
   go: creating new go.mod: module github.com/robteix/testmod
   ```

2. 使用`go mod vendor` 和 `go build -mod=vendor`可以很好的避免库的变动引起的问题

3. 在go.mod中`indirect`标示间接依赖,`+incompatible`标示不兼容

4. go使用[semver (Semantic Versioning)](https://semver.org/)控制版本,格式为:`vMAJOR.MINOR.PATCH`

### module的版本管理

这里以一个实例的方式为大家举例,现有一个testmod模块,go.mod声明如下:

```go
module github.com/robteix/testmod
```

现在将模块提交到github:

```shell
$ git init 
$ git add * 
$ git commit -am "First commit" 
$ git push -u origin master
$ git tag v1.0.0
$ git push --tags
```

向github提交了此包,并且生成了第一个版本v1.0.0,提交完成后,其他人就可以通过go get获取此包:

```shell
$ go get github.com/robteix/testmod
```

但此时请注意,获取到的代码是最新的master的代码,master的代码是变动的,所以极有可能其他人会遇到不兼容等问题.

那么我们如何做呢? 在go的文档中有详细说明,特别是针对[go mod的版本](https://research.swtch.com/vgo-import)

> "If an old package and a new package have the same import path, the new package must be backwards compatible with the old package."
>
> “如果旧软件包和新软件包具有相同的导入路径，则新软件包必须向后兼容旧软件包。”

那么具体怎么操作呢,接下来我们一起操作一下:

#### 1.建立新的分支

```shell
$ git checkout -b v2 
```

建立一个新的分支来开发我们的代码,方便进行代码的管理

#### 2.修改模块描述

```shell
$ echo "module github.com/robteix/testmod/v2" > go.mod
```

在此主要是修改`go.mod`文件,将导入路径加上`/v2`

#### 3.发布新版本

```shell
$ git commit go.mod -m "升级到v2"
$ git tag v2.0.0
$ git push --tags origin v2 
```

#### 4.其他使用者更新到新版本

```shell
$ go get github.com/robteix/testmod/v2
```

使用`go get`命令依赖`v2版本`,但是之前的版本依然可以使用,实际上这被看做两个依赖了.

如果不想依赖新版本,只想升级到v1的最新版本,可以使用

```shell
$ go get -u=patch github.com/robteix/testmod
```

#### 5.修改代码中的依赖,并使用tidy整理依赖

```shell
$ go mod tidy
```

#### 6.如果发布错了,那么其他人获取的为什么还是旧的内容?

在golang的module中,依赖不会重复去获取,而是缓存在本地的,缓存的地址为:`$GO_PATH/pkg/mod/cache`

如果发布错了,有两个办法

1,通过版本升级的方式升级到v2.0.1

2,删除tag重新发布,那么就需要手动清理缓存

## module命令参照

`go mod init`:初始化modules

`go mod download`:下载modules到本地cache

`go mod edit`:编辑go.mod文件，选项有-json、-require和-exclude，可以使用帮助go help mod edit

`go mod graph`:以文本模式打印模块需求图

`go mod tidy`:删除错误或者不使用的modules

`go mod vendor`:生成vendor目录

`go mod verify`:验证依赖是否正确

`go mod why`:查找依赖

`go test` :执行一下，自动导包

`go list -m`  主模块的打印路径

`go list -m -f={{.Dir}}`  print主模块的根目录

`go list -m all`  查看当前的依赖和版本信息



## 参照

[Go模块简介](https://tangxusc.github.io/blog/2019/03/go%E6%A8%A1%E5%9D%97%E7%AE%80%E4%BB%8B/)

[Module compatibility and semantic versioning](https://golang.org/cmd/go/#hdr-Module_compatibility_and_semantic_versioning)

[Semantic Import Versioning](https://research.swtch.com/vgo-import)

