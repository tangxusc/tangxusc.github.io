---
title: "如何使用 go get 下载 gitlab 私有项目"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- golang
- module
tags:
- golang
- module
- gitlab
keywords:
- golang
- module
- gitlab
---

在我们使用golang开发项目时,会遇到私有仓库问题,本文章讲解golang中私有仓库的使用
<!--more-->
> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 http://holys.im/2016/09/20/go-get-in-gitlab/

据此 [issue](https://github.com/gitlabhq/gitlabhq/pull/7693)，gitlab 7.8 就开始支持 go get private repo。

假设 gitlab 服务是： mygitlab.com

使用方式：

```
$ go get -v  mygitlab.com/user/repo

```

如果 mygitlab.com 不支持 https, 还得加上 `-insecure` 参数

```
$ go get -v  -insecure  mygitlab.com/user/repo

```

但是 `-insecure` 参数是 `go 1.5` 以后才有的，所以如果低于 `1.5` 版本，赶紧升级一下吧。

默认需要输入用户名和密码，比较繁琐。
由于 go get 底层实际还是用了 git 去操作。可以配置 .gitconfig 使之用 http => ssh 的访问方式 (个人感觉就是重写了 url)

```
$ git config --global url."git@mygitlab.com:".insteadOf "http://mygitlab.com/"

// 其实就是在 `.gitconfig 增加了配置`
$ cat ~/.gitconfig

[url "git@mygitlab.com:"]
    insteadOf = http://mygitlab.com/

```

注意： [git@mygitlab.com](mailto:git@mygitlab.com): 后面有个冒号 `:`, 且 [http://mygitlab.com](http://mygitlab.com) 后面有 `/`

另外： url.”aaa”.insteadOf “bbb” 是个相当有用的技巧，对 github 同样适用。

```
$ git config --global url."git@github.com:".insteadOf "https://github.com/"

$ cat ~/.gitconfig
[url "git@github.com:"]
    insteadOf = https://github.com/

```

这样 git clone [https://github.com/golang/go.git](https://github.com/golang/go.git) 就变成 git clone [git@github.com](mailto:git@github.com):golang/go.git , 免去输入账号密码的烦恼。

总结：

1.  gitlab >= 7.8
2.  go >= 1.5 （如果 gitlab 不支持 https）
3.  git url insteadOf

参考：

1.  [https://gist.github.com/shurcooL/6927554](https://gist.github.com/shurcooL/6927554)
2.  [https://github.com/golang/go/issues/9637](https://github.com/golang/go/issues/9637)
3.  [https://github.com/golang/go/issues/6968](https://github.com/golang/go/issues/6968)

本文地址 [http://holys.im/2016/09/20/go-get-in-gitlab/](http://holys.im/2016/09/20/go-get-in-gitlab/)