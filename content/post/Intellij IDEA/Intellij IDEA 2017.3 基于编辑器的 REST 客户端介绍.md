---
title: "Intellij IDEA 基于编辑器的 REST 客户端介绍"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- java
- REST
tags:
- java
- REST
keywords:
- java
- REST
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://blog.csdn.net/u011054333/article/details/78705256

最近 Intellij IDEA 更新到了 2017.3 这一版本，这个版本又增加了很多新功能。我觉得其中这个基于编辑器的 REST 客户端这个功能很不错，可以为我们带来很多方便。这个功能并不仅仅在 Intellij IDEA 才有，最近更新的所有 Jetbrains 系 IIDE 都有这个功能。

以往我们开发和调试网络程序，用到的无非是这几种办法：浏览器 F12 工具、Fiddler、Wireshark、curl 等命令行工具、手动使用 HTTP 客户端类库编程。不过这些方法总是有些不好用。Jetbrains 这个基于编辑器的 REST 客户端用起来倒是让我眼前一亮。

<!--more-->

## 使用方法

要使用这个功能很简单，在 IDE 中新建一个后缀名为`.http`的文件，然后就可以使用这个功能了。截图如下。

![](http://upload-images.jianshu.io/upload_images/832668-496bd9fed25516ef.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这个功能使用起来非常简单，使用大写的 HTTP 动词（GET、POST、DELETE、PUT 等等）后面加上要访问的网址即可，如果端口号不是 80 或者 443，可以使用冒号 + 端口号的形式写在网址后面。如果需要修改 Cookie、ContentType、UA 等设置，直接写在后面几行即可，Jetbrains 提供了非常完善的补全支持，我们只要敲第一个大写字母即可获得相应的代码提示。想要发起一个请求的时候，直接点击前面的绿色运行按钮即可。一个文件中可以保存多个请求，如果以后还想再次运行只要打开这个文件即可。

## 配置环境变量

Jetbrains 还提供了一个环境变量的功能，让我们使用这个编辑器 REST 客户端更加简单。只要在项目中添加一个名为`rest-client.env.json`的文件，然后配置不同环境下要使用的环境变量。然后就能在 REST 客户端中使用了。例如配置文件是这样的。

```
{
  "dev": {
    "host": "http://httpbin.org"
  },
  "prod": {
    "host": "http://httpbin.org"
  }
}
```

那么在点击运行按钮的时候就会弹出选择要使用哪个环境变量。我们只要选择就可以针对不同环境使用不同配置了。在代码中只要使用双括号引用环境变量即可。

![](http://upload-images.jianshu.io/upload_images/832668-9691e8eb1d3e6cd3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这个功能就介绍到这里了。因为它使用起来实在是太简单了，不需要记什么复杂命令，也不需要额外的工具支持。可以说是一个非常简单强大的工具。

### 参照
* [restClient](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)