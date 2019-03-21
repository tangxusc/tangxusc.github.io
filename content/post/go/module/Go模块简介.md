---
title: "Go模块简介"
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


> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://roberto.selbach.ca/intro-to-go-modules/

# Go模块简介

发表于 2018年8月18日(https://roberto.selbach.ca/intro-to-go-modules/) 作者：[Roberto Selbach](https://roberto.selbach.ca/author/robteix/)

即将发布的Go编程语言版本1.11将为_模块_带来实验性支持  ，几天前Go.A的新依赖管理系统，[我写了一篇关于它的快速帖子](https://roberto.selbach.ca/playing-with-go-modules/)。自那篇文章上线以来，事情发生了一些变化，因为我们现在非常接近新版本，我认为现在是另一篇文章更适合实践的好时机。所以这就是我们要做的：我们将创建一个新的包，然后我们将发布一些版本，看看它是如何工作的。

## 创建模块

首先要做的事情。让我们创建我们的包。我们称之为“testmod”。这里有一个重要的细节：**这个目录应该** **_在_****你的****_外面，_****因为默认情况下，模块支持在其中被禁用**。Go模块是可能在某些时候完全消除的第一步。**`$GOPATH`**`$GOPATH`

```
$ mkdir testmod
$ cd testmod

```

我们的包很简单：

```
package testmod

import "fmt" 

// Hi returns a friendly greeting
func Hi(name string) string {
   return fmt.Sprintf("Hi, %s", name)
}
```

包完成但它仍然不是_模块_。让我们改变这一点。

```
$ go mod init github.com/robteix/testmod
go: creating new go.mod: module github.com/robteix/testmod
```

这将`go.mod`在包目录中创建一个新文件，其中包含以下内容：

```
module github.com/robteix/testmod
```

这里不是很多，但这有效地将我们的包变成了一个  _模块_。我们现在可以将这个代码推送到一个存储库：

```
$ git init 
$ git add * 
$ git commit -am "First commit" 
$ git push -u origin master
```

到目前为止，任何愿意使用此软件包的人都会`go get` ：

```
$ go get github.com/robteix/testmod
```

这将获取最新的代码`master`。这仍然有效，但我们应该停止这样做，因为我们有一个Better Way™。提取`master`本质上是危险的，因为我们永远无法确定包裹作者没有做出会破坏我们使用的改变。这就是模块旨在解决的问题。

## 模块版本控制快速入门

Go模块是  _版本化的_，并且某些版本有一些特殊性。您将需要熟悉[语义版本控制](https://semver.org)背后的概念。更重要的是，Go将在查找版本时使用存储库标记，并且某些版本与其他版本不同：例如版本2和更高版本应具有与版本0和版本不同的导入路径（我们将会这样做。）同样，默认情况下，Go将获取存储库中可用的最新_标记版本_。这是一个重要的问题，因为您可能习惯使用master分支。您现在需要记住的是，要发布我们的包，我们需要使用该版本标记我们的存储库。所以，让我们这样做。

## 我们的第一个版本

现在我们的包已经准备就绪，我们可以将它发布到全世界。我们使用版本标签来完成此操作。让我们发布我们的1.0.0版本：

```
$ git tag v1.0.0
$ git push --tags
```

这会在我的Github存储库上创建一个标记，将当前提交标记为1.0.0版本.Go不以任何方式强制执行，但一个好主意是创建一个新分支（“v1”）以便我们可以推送错误修复。

```
$ git checkout -b v1
$ git push -u origin v1
```

现在我们可以继续工作，`master`而不必担心破坏我们的发布。

## 使用我们的模块

现在我们准备好使用该模块了。我们将创建一个使用我们新包的简单程序：

```
package main

import (
    "fmt"

    "github.com/robteix/testmod"
)

func main() {
    fmt.Println(testmod.Hi("roberto"))
}
```

到目前为止，你会`go get github.com/robteix/testmod`去下载软件包，但是使用模块，这会变得更有趣。首先，我们需要在新程序中启用模块。

```
$ go mod init mod
```

正如您对我们上面所看到的那样期望，这将创建一个`go.mod`包含模块名称的新文件：

```
module mod
```

当我们尝试构建新程序时，事情会变得更有趣：

```
$ go build
go: finding github.com/robteix/testmod v1.0.0
go: downloading github.com/robteix/testmod v1.0.0
```

我们可以看到，该`go`命令会自动进行并获取程序导入的包。如果我们检查我们的`go.mod`文件，我们发现情况发生了变化：

```
module mod
require github.com/robteix/testmod v1.0.0
```

我们现在也有一个名为的新文件`go.sum`，其中包含包的哈希值，以确保我们拥有正确的版本和文件。

```
github.com/robteix/testmod v1.0.0 h1:9EdH0EArQ/rkpss9Tj8gUnwx3w5p0jkzJrd5tRAhxnA=
github.com/robteix/testmod v1.0.0/go.mod h1:UVhi5McON9ZLc5kl5iN2bTXlL6ylcxE9VInV71RrlO8=
```

## 制作错误修正版

现在让我们说我们意识到我们的包装有问题：问候语缺少ponctuation！人们很生气，因为我们的友好问候不够友好。所以我们将修复它并发布一个新版本：

```
// Hi returns a friendly greeting
func Hi(name string) string {
-       return fmt.Sprintf("Hi, %s", name)
+       return fmt.Sprintf("Hi, %s!", name)
}
```

我们在v1分支中做了这个改变，因为它与我们以后为v2做的事情无关，但在现实生活中，也许你会在它中进行`master` ，然后再回传它。无论哪种方式，我们都需要在我们的v1分支中进行修复并将其标记为新版本。

```
$ git commit -m "Emphasize our friendliness" testmod.go
$ git tag v1.0.1
$ git push --tags origin v1
```

## 更新模块

默认情况下，Go不会在没有被询问的情况下更新模块。这是一个Good Thing™，因为我们希望在我们的构建中具有可预测性。如果Go模块每次出现新版本时都会自动更新，我们将回到Go1.11之前的不文明时代。不，我们需要  _告诉_ Go为我们更新模块。我们通过使用我们的老朋友来做到这一点`go get`：

*   运行  `go get -u` 以使用最新的  _次要_  版本_或补丁_版本（即它将从1.0.0更新为1.0.1，如果可用，则更新为1.1.0）
*   运行  `go get -u=patch` 以使用最新的  _补丁_  版本（即，将更新到1.0.1但_不会_更新  到1.1.0）
*   运行`go get package@version` 以更新到特定版本（例如`github.com/robteix/testmod@v1.0.1`）

在上面的列表中，似乎没有办法更新到最新的  _主要_版本。这有一个很好的理由，正如我们稍后会看到的那样。由于我们的程序使用的是我们软件包的1.0.0版，我们刚刚创建了1.0.1版本，  以下_任何_命令都会将我们更新为1.0.1：

```shell
$ go get -u
$ go get -u=patch
$ go get github.com/robteix/testmod@v1.0.1
```

运行后，比如说，`go get -u` 我们`go.mod` 改为：

```
module mod
require github.com/robteix/testmod v1.0.1
```

## 主要版本

根据语义版本语义，主要版本  与未成年人_不同_。主要版本可以破坏向后兼容性。从Go模块的角度来看，主要版本是  完全_不同的包_。这听起来可能听起来很奇怪，但它是有道理的：两个版本的库彼此不兼容是两个不同的库。让我们对我们的包进行重大改变，不是吗？随着时间的推移，我们意识到我们的API太简单了，对于我们用户的用例来说太有限了，所以我们需要更改`Hi()` 函数以为问候语言采用新参数：

```
package testmod

import (
    "errors"
    "fmt" 
) 

// Hi returns a friendly greeting in language lang
func Hi(name, lang string) (string, error) {
    switch lang {
    case "en":
        return fmt.Sprintf("Hi, %s!", name), nil
    case "pt":
        return fmt.Sprintf("Oi, %s!", name), nil
    case "es":
        return fmt.Sprintf("¡Hola, %s!", name), nil
    case "fr":
        return fmt.Sprintf("Bonjour, %s!", name), nil
    default:
        return "", errors.New("unknown language")
    }
}
```

使用我们的API的现有软件将会中断，因为它们（a）不传递语言参数，（b）不期望错误返回。我们的新API不再与版本1.x兼容，所以是时候将版本提升到2.0.0。我之前提到过一些版本有一些特性，现在就是这种情况。**版本2** **_及更高_****版本** **应更改导入路径。**它们现在是不同的库。我们通过将新_版本路径_附加  到模块名称的末尾来实现。

```
module github.com/robteix/testmod/v2
```

其余部分与之前相同，我们推送它，将其标记为v2.0.0（并可选择创建v2分支。）

```
$ git commit testmod.go -m "Change Hi to allow multilang"
$ git checkout -b v2 # optional but recommended
$ echo "module github.com/robteix/testmod/v2" > go.mod
$ git commit go.mod -m "Bump version to v2"
$ git tag v2.0.0
$ git push --tags origin v2 # or master if we don't have a branch
```

## 更新到主要版本

即使我们已经发布了一个新的不兼容版本的库，现有的软件  _也不会中断_，因为它将继续使用现有的1.0.1版本。`go get -u` _不会_得到版本2.0.0.At一些点，但是，我作为图书馆用户，可能需要升级到2.0.0版本，因为也许我是谁需要多语言support.I这些用户中的一个做，但修改我的程序相应：

```
package main

import (
    "fmt"
    "github.com/robteix/testmod/v2" 
)

func main() {
    g, err := testmod.Hi("Roberto", "pt")
    if err != nil {
        panic(err)
    }
    fmt.Println(g)
}
```

然后当我运行时`go build`，它将为我提取2.0.0版本。请注意，即使导入路径以“v2”结尾，Go仍将通过其正确的名称（“testmod”）引用该模块。正如我之前提到的，主要版本是出于所有意图和目的而完全不同的包。Go模块根本不会链接这两个模块。这意味着我们可以在同一个二进制文件中使用两个不兼容的版本：

```
package main
import (
    "fmt"
    "github.com/robteix/testmod"
    testmodML "github.com/robteix/testmod/v2"
)

func main() {
    fmt.Println(testmod.Hi("Roberto"))
    g, err := testmodML.Hi("Roberto", "pt")
    if err != nil {
        panic(err)
    }
    fmt.Println(g)
}
```

这消除了依赖关系管理的常见问题：依赖关系依赖于同一个库的不同版本。

## 整理它

回到以前仅使用testmod 2.0.0的版本，如果我们检查`go.mod` 现在的内容，我们会注意到：

```
module mod
require github.com/robteix/testmod v1.0.1
require github.com/robteix/testmod/v2 v2.0.0
```

默认情况下，`go.mod` 除非您要求，否则Go不会删除依赖项。如果您具有不再使用且想要清理的依赖项，则可以使用新`tidy`命令：

```
$ go mod tidy
```

现在我们只剩下真正使用的依赖项了。

## Vendoring

Go模块`vendor/` 默认忽略该目录。我们的想法是_最终_取消售卖<sup id="fnref-1772-0">[1](#fn-1772-0)</sup>。但是如果我们仍然希望将版本化的依赖项添加到我们的版本控制中，我们仍然可以这样做：

```
$ go mod vendor
```

这将`vendor/` 在项目的根目录下创建一个目录，其中包含所有依赖项的源代码`go build` 。默认情况下，将忽略此目录的内容。如果要从`vendor/` 目录构建依赖项，则需要请求它。

```
$ go build -mod vendor
```

我希望许多愿意使用vendoring的开发人员可以`go build`在他们的开发机器上正常运行并`-mod vendor` 在他们的CI中使用.At，Go模块正在逐渐从销售的想法转向使用Go模块代理，以便那些不想依赖的人上游版本直接控制服务。有些方法可以保证`go`不会到达网络（例如`GOPROXY=off`），但这些是未来博客文章的主题。

## 结论

这篇文章可能看起来有点令人生畏，但我试图一起解释很多东西。现实情况是，现在Go模块基本上是透明的。我们总是在代码中导入包，`go`命令会处理剩下的内容。当我们构建一些东西时，依赖项将自动获取。它还消除了使用的需要，`$GOPATH`这对于那些无法理解为什么必须进入特定目录的新Go开发人员来说是个障碍。~~供应（非正式）被弃用以支持使用代理。~~<sup id="fnref2:1772-0">[1](#fn-1772-0)</sup>我可能会单独关于Go模块代理的帖子。_（更新：[现场直播](https://roberto.selbach.ca/go-proxies/)。）

* * *

1.  我认为这有点过于强烈，人们留下的印象是现在正在删除销售。事实并非如此。供应仍然有效，尽管与以前略有不同。似乎有_希望_用更好的东西取代售卖，这可能是也可能不是代理。但就目前而言，这就是它：渴望更好的解决方案。直到一个很好的替代发现Vendoring不会消失（如果有的话）。  [↩](#fnref-1772-0) [↩](#fnref2:1772-0)_ 

