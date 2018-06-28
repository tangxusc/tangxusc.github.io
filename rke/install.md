### RKE安装kubernetes集群
### 准备工作
* 1,将普通用户加入到Docker组
```
sudo usermod -aG docker catty
sudo reboot
```
* 2,关闭防火墙
```
sudo ufw disable
```
* 3,建立ssh单向通道
```
ssh-keygen  #三次回车，生成ssh公钥和私钥文件
ssh-copy-id <节点用户名>@<节点IP>
```
* 4,验证ssh
```
ssh 192.168.3.162
```
### 安装步骤
* 1,从github rke的仓库中下载rke文件
* 2,在rke同级文件夹下创建cluster.yml
```
nodes:
  - address: 10.6.73.55
    user: tangxu
    role: [controlplane,worker,etcd]
#network:
#  plugin: flannel
#  options:
#    flannel_iface: enp3s0
```
* 3,授予执行权限
```
chmod 777 rke
```
* 4,执行安装
```
./rke up --config cluster.yml
```
### 已知的问题
* 在单节点下(未测试多节点),k8s POD中的容器无法ping通dns,无法访问外部网络,不知道是何原因.