### RKE安装kubernetes集群
### 准备工作
* 1,将普通用户加入到Docker组
```
sudo usermod -aG docker 用户名
```
* 2,关闭防火墙
```
sudo ufw disable
```
* 3.0 安装openssh-server(如果已经安装,可省略)
```
#centos
yum install openssh-server
#ubuntu
apt-get install openssh-server
```
* 3,建立ssh单向通道
```
ssh-keygen  #三次回车，生成ssh公钥和私钥文件
ssh-copy-id <节点用户名>@<节点IP>
例如: ssh-copy-id demo@1.2.3.4
```
* 4,验证ssh
```
ssh 192.168.3.162
exit
```
* 5,禁用selinux(CentOS7)
```
vi /etc/sysconfig/selinux
设置SELINUX=disabled
```
* 6,禁用swap
```
vi /etc/fstab
swap那句话注释掉,重启
```
### 安装步骤
* 1,从github rke的仓库中下载rke文件
```
https://github.com/rancher/rke/releases/
```
* 2,在rke同级文件夹下创建cluster.yml
```
nodes:
  - address: 节点IP(例如:1.2.3.4)
    user: 节点用户名(例如:demo)
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
### 参照
* [rke](https://rancher.com/docs/rke/v0.1.x/en/installation/os/)
### 已知的问题
* 在单节点下(未测试多节点),k8s POD中的容器无法ping通dns,无法访问外部网络,不知道是何原因.