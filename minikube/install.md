为了方便大家开发和体验Kubernetes，社区提供了可以在本地部署的Minikube。由于网络访问原因，很多朋友无法使用minikube进行实验。为此我们提供了一个修改版的Minikube，可以从阿里云的镜像地址来获取所需Docker镜像和配置。

注：
本文已更新到 Minikube v0.28.0/Kubernetes v1.10.0
如需更新minikube，需要更新 minikube 安装包

minikube delete 删除现有虚机，删除 ~/.minikube 目录缓存的文件
重新创建 minikube 环境
Docker社区版也为Mac/Windows用户提供了Kubernetes开发环境的支持 https://yq.aliyun.com/articles/508460，大家也可以试用
配置
先决条件
安装 kubectl
Minikube在不同操作系统上支持不同的驱动

macOS

xhyve driver, VirtualBox 或 VMware Fusion
Linux

VirtualBox 或 KVM
NOTE: Minikube 也支持 --vm-driver=none 选项来在本机运行 Kubernetes 组件，这时候需要本机安装了 Docker。在使用 0.27版本之前的 none 驱动时，在执行 minikube delete 命令时，会移除 /data 目录，请注意，问题说明；另外 none 驱动会运行一个不安全的API Server，会导致安全隐患，不建议在个人工作环境安装。
Windows

VirtualBox 或 Hyper-V - 请参考下文
注：

由于minikube复用了docker-machine，在其软件包中已经支持了相应的VirtualBox, VMware Fusion驱动
VT-x/AMD-v 虚拟化必须在 BIOS 中开启
在Windows环境下，如果开启了Hyper-V，不支持VirtualBox方式
Kubernetes 1.10 release
我们提供了最新的Minikube修改版的文件，可以直接下载使用

Mac OSX

`curl -Lo minikube http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.28.0/minikube-darwin-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
Linux`

`curl -Lo minikube http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.28.0/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
Windows`

下载 minikube-windows-amd64.exe 文件，并重命名为 minikube.exe

Kubernetes 1.9 release
Mac OSX

curl -Lo minikube http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.25.2/minikube-darwin-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
Linux

curl -Lo minikube http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.25.2/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
Windows

下载 minikube-windows-amd64.exe 文件，并重命名为 minikube.exe

自己构建
也可以从Github上获取相应的项目自行构建。

注：需要本地已经安装配置好 Golang 开发环境和Docker引擎

git clone https://github.com/AliyunContainerService/minikube
cd minikube
git checkout aliyun-v0.25.0
make
sudo cp out/minikube /usr/local/bin/
启动
缺省Minikube使用VirtualBox驱动来创建Kubernetes本地环境

minikube start --registry-mirror=https://registry.docker-cn.com
打开Kubernetes控制台

minikube dashboard
image

对于使用Hyper-V环境的用户，首先应该打开Hyper-V管理器创建一个外部虚拟交换机，

create

hyper_v

之后，我们可以用如下命令来创建基于Hyper-V的Kubernetes测试环境

.\minikube.exe start --registry-mirror=https://registry.docker-cn.com --vm-driver="hyperv" --memory=4096 --hyperv-virtual-switch="MinikubeSwitch"
注：需要管理员权限来创建Hyper-V虚拟机

使用Minikube
Minikube利用本地虚拟机环境部署Kubernetes，其基本架构如下图所示。
4

用户使用Minikube CLI管理虚拟机上的Kubernetes环境，比如：启动，停止，删除，获取状态等。一旦Minikube虚拟机启动，用户就可以使用熟悉的Kubectl CLI在Kubernetes集群上执行操作。

好了，开始探索Kubernetes的世界吧！:-)