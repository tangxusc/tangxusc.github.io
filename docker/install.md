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
https://rancher.com/docs/rke/v0.1.x/en/os/
https://rancher.com/docs/rancher/v1.6/en/hosts/#supported-docker-versions