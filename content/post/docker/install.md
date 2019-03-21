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

## docker安装(国内环境)
---
```
curl https://releases.rancher.com/install-docker/17.03.sh | sh
```
##### 普通用户运行docker命令
```
usermod -aG docker <用户名>
```

### 参照
* https://rancher.com/docs/rke/v0.1.x/en/os/
* https://rancher.com/docs/rancher/v1.6/en/hosts/#supported-docker-versions