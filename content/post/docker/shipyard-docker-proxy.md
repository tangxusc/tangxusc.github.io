---
title: "使用shipyard proxy开启docker remote远程端口(2375)"
date: 2019-03-20T14:15:59+08:00
draft: false
---

### 使用shipyard proxy开启docker remote远程端口(2375)

#### 优势
* 不用重启docker
* 操作更为便捷
* 对于端口的定制更为方便
* 没有复杂的linux操作

#### * 注意shipyard已经没有维护了(但此镜像任然可以使用)
原理: shipyard/docker-proxy:latest 镜像可以在宿主机docker上运行一个容器,容器内挂载/var/run/docker.sock文件 将此文件暴露后,就开启了docker remote api

#### docker命令行运行
```
docker run -d -v /var/run/docker.sock:/var/run/docker.sock -p 2375:2375 --name shipyard-docker-proxy shipyard/docker-proxy:latest
```

#### rancher调度(v2)
```
version: '2'
services:
  proxy:
    image: shipyard/docker-proxy:latest
    stdin_open: true
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    tty: true
    ports:
    - 2375:2375/tcp
    labels:
      io.rancher.container.pull_image: always
```
