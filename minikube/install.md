> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://yq.aliyun.com/articles/221687


为了方便大家开发和体验 Kubernetes，社区提供了可以在本地部署的 [Minikube](https://github.com/kubernetes/minikube)。由于网络访问原因，很多朋友无法使用 minikube 进行实验。为此我们提供了一个修改版的 Minikube，可以从阿里云的镜像地址来获取所需 Docker 镜像和配置。

注：

*   本文已更新到 Minikube v0.28.0/Kubernetes v1.10.0
*   如需更新 minikube，需要更新 minikube 安装包

    *   `minikube delete` 删除现有虚机，删除 `~/.minikube` 目录缓存的文件
    *   重新创建 minikube 环境
*   Docker 社区版也为 Mac/Windows 用户提供了 Kubernetes 开发环境的支持 [https://yq.aliyun.com/articles/508460](https://yq.aliyun.com/articles/508460)，大家也可以试用

### 配置

#### 先决条件

*   安装 [kubectl](https://kubernetes.io/docs/tasks/kubectl/install/)

Minikube 在不同操作系统上支持不同的驱动

*   macOS

    *   [xhyve driver](https://github.com/kubernetes/minikube/blob/master/docs/drivers.md#xhyve-driver), [VirtualBox](https://www.virtualbox.org/wiki/Downloads) 或 [VMware Fusion](https://www.vmware.com/products/fusion)
*   Linux

    *   [VirtualBox](https://www.virtualbox.org/wiki/Downloads?spm=a2c4e.11153940.blogcont221687.23.7dd57733IiifEu) 或 [KVM](https://github.com/kubernetes/minikube/blob/master/docs/drivers.md#kvm-driver)
    *   **NOTE:** Minikube 也支持 `--vm-driver=none` 选项来在本机运行 Kubernetes 组件，这时候需要本机安装了 Docker。在使用 0.27 版本之前的 none 驱动时，在执行 `minikube delete` 命令时，会移除 /data 目录，请注意，[问题说明](https://github.com/kubernetes/minikube/issues/2794)；另外 none 驱动会运行一个不安全的 API Server，会导致安全隐患，不建议在个人工作环境安装。
*   Windows

    *   [VirtualBox](https://www.virtualbox.org/wiki/Downloads) 或 [Hyper-V](https://github.com/kubernetes/minikube/blob/master/docs/drivers.md#hyperV-driver) - 请参考下文

注：

*   由于 minikube 复用了 docker-machine，在其软件包中已经支持了相应的 VirtualBox, VMware Fusion 驱动
*   VT-x/AMD-v 虚拟化必须在 BIOS 中开启
*   在 Windows 环境下，如果开启了 Hyper-V，不支持 VirtualBox 方式

#### Kubernetes 1.10 release

我们提供了最新的 Minikube 修改版的文件，可以直接下载使用

**Mac OSX**

```
curl -Lo minikube http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.28.0/minikube-darwin-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
```

**Linux**

```
curl -Lo minikube http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.28.0/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
```

**Windows**

下载 [minikube-windows-amd64.exe](http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.28.0/minikube-windows-amd64.exe) 文件，并重命名为 `minikube.exe`

#### Kubernetes 1.9 release

**Mac OSX**

```
curl -Lo minikube http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.25.2/minikube-darwin-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
```

**Linux**

```
curl -Lo minikube http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.25.2/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
```

**Windows**

下载 [minikube-windows-amd64.exe](http://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v0.25.2/minikube-windows-amd64.exe) 文件，并重命名为 `minikube.exe`

#### 自己构建

也可以从 Github 上获取相应的项目自行构建。

注：需要本地已经安装配置好 Golang 开发环境和 Docker 引擎

```
git clone https://github.com/AliyunContainerService/minikube
cd minikube
git checkout aliyun-v0.25.0
make
sudo cp out/minikube /usr/local/bin/
```

### 启动

缺省 Minikube 使用 VirtualBox 驱动来创建 Kubernetes 本地环境

```
minikube start --registry-mirror=https://registry.docker-cn.com
```

打开 Kubernetes 控制台

```
minikube dashboard
```

![](https://yqfile.alicdn.com/45690620c348d7be4a804880e3b7046f19e74c29.png)

对于使用 Hyper-V 环境的用户，首先应该打开 Hyper-V 管理器创建一个外部虚拟交换机，

![](https://yqfile.alicdn.com/d165308ee88baf4adbe46c09b6d2596dea7bdfef.png)

![](https://yqfile.alicdn.com/208a65dae18028cab8e9782803c7784ad110e0a6.png)

之后，我们可以用如下命令来创建基于 Hyper-V 的 Kubernetes 测试环境

```
.\minikube.exe start --registry-mirror=https://registry.docker-cn.com --vm-driver="hyperv" --memory=4096 --hyperv-virtual-switch="MinikubeSwitch"
```

注：需要管理员权限来创建 Hyper-V 虚拟机

## 使用 Minikube

Minikube 利用本地虚拟机环境部署 Kubernetes，其基本架构如下图所示。
[![](https://yqfile.alicdn.com/c03a43e0731ca579d1844fb44269fd2fd257bfb3.jpeg)](javascript:;)

用户使用 Minikube CLI 管理虚拟机上的 Kubernetes 环境，比如：启动，停止，删除，获取状态等。一旦 Minikube 虚拟机启动，用户就可以使用熟悉的 Kubectl CLI 在 Kubernetes 集群上执行操作。

好了，开始探索 Kubernetes 的世界吧！:-)