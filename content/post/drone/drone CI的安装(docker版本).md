---
title: "drone CI的安装(docker版本)"
date: 2019-03-20T14:15:59+08:00
draft: false
---

### drone CI的安装(docker版本)

因原生的安装使用的是docker-compose进行安装,在此我使用docker进行安装
* drone 版本:0.8.4
* 强烈不推荐现在使用drone,现在感觉非常不可靠(按照文档运行各种错误)

1. 服务端运行脚本:
```
docker run -d -p 8000:8000 -v /var/lib/drone:/var/lib/drone/ -e DRONE_OPEN=true -e DRONE_HOST=<访问地址和端口> -e DRONE_GITHUB=true -e DRONE_GITHUB_CLIENT=<DRONE_GITHUB_CLIENT> -e DRONE_GITHUB_SECRET=<DRONE_GITHUB_SECRET> -e DRONE_SECRET=<自定义一个秘钥> --name drone drone/drone:0.8.4
```

例如:
```
docker run -d -p 8000:8000 -v /var/lib/drone:/var/lib/drone/ -e DRONE_OPEN=true -e DRONE_HOST=http://10.130.0.159:8000 -e DRONE_GITLAB=true -e DRONE_GITLAB_URL=https://gitlab.com -e DRONE_GITLAB_CLIENT=abba054b74a664f8226a7a99ccbc67f1140739465a4c1b0e85d -e DRONE_GITLAB_SECRET=42149d15d0e1636de99f6bc22c7d18e9f1825dcf49f0b0544dd -e DRONE_SECRET=abcd123456 --name drone drone/drone:0.8.4
```

2. 代理运行脚本:
```
docker run -d -v /var/run/docker.sock:/var/run/docker.sock -e DRONE_SERVER=<服务器地址和端口> -e DRONE_SECRET=<自定义的秘钥> --link drone:drone --name drone-agent drone/agent:0.8.4
```
例如:
```
docker run -d -v /var/run/docker.sock:/var/run/docker.sock -e DRONE_SERVER=drone:8000 -e DRONE_SECRET=abcd123456 --link drone:drone --name drone-agent drone/agent:0.8.4
```