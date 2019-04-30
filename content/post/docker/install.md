---
title: "docker安装(国内环境)"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- docker
tags:
- docker
keywords:
- docker
- install
---

docker安装(国内环境)
<!--more-->

## rancher安装

此安装方式为rancher提供,此安装方式好处在于提供了兼容k8s的版本进行安装.

```
curl https://releases.rancher.com/install-docker/17.03.sh | sh
```
## 官方脚本安装

此安装方式是使用官方的脚本安装最新版本的docker,并使用了阿里云的源进行安装
源是直接写入`/etc/apt/sources.list.d/docker.list`文件中
```shell
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
```

## 普通用户运行docker命令

```
usermod -aG docker <用户名>
```

> 请记得注销并重新登录才能生效！

## 参照

* https://rancher.com/docs/rke/v0.1.x/en/os/
* https://rancher.com/docs/rancher/v1.6/en/hosts/#supported-docker-versions