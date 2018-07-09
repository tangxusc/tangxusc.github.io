### drone CI的安装(docker版本)

因原生的安装使用的是docker-compose进行安装,在此我使用docker进行安装
* drone 版本:0.8

1. 服务端运行脚本:
```
docker run -d -p 8000:8000 -v /var/lib/drone:/var/lib/drone/ -e DRONE_OPEN=true -e DRONE_HOST=<访问地址和端口> -e DRONE_GITHUB=true -e DRONE_GITHUB_CLIENT=<DRONE_GITHUB_CLIENT> -e DRONE_GITHUB_SECRET=<DRONE_GITHUB_SECRET> -e DRONE_SECRET=<自定义一个秘钥> --name drone drone/drone:0.8
```

例如:
```
docker run -d -p 8000:8000 -v /var/lib/drone:/var/lib/drone/ -e DRONE_OPEN=true -e DRONE_HOST=http://10.130.0.159:8000 -e DRONE_GITLAB=true -e DRONE_GITLAB_URL=https://gitlab.com -e DRONE_GITLAB_CLIENT=abba054e85d -e DRONE_GITLAB_SECRET=42149d10544dd -e DRONE_SECRET=abcd123456 --name drone drone/drone:0.8
```

2. 代理运行脚本:
docker run -d -v /var/run/docker.sock:/var/run/docker.sock -e DRONE_SERVER=<服务器地址和端口> -e DRONE_SECRET=<自定义的秘钥> drone/drone:0.8 agent