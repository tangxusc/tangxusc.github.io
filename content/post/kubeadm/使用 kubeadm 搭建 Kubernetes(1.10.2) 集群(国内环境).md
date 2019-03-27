---
title: "使用 kubeadm 搭建 Kubernetes(1.10.2) 集群（国内环境）"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- kubeadm
- k8s
tags:
- kubeadm
- k8s
- install
keywords:
- kubeadm
- k8s
- install
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://www.cnblogs.com/RainingNight/p/using-kubeadm-to-create-a-cluster.html

# 使用 kubeadm 搭建 Kubernetes(1.10.2) 集群（国内环境）

[TOC]


## 目标

*   在您的机器上建立一个安全的 Kubernetes 集群。
*   在集群里安装网络插件，以便应用之间可以相互通讯。
*   在集群上运行一个简单的微服务。

## 准备

### 主机

*   一台或多台运行 Ubuntu 16.04 + 的主机。
*   最好选至少有 2 GB 内存的双核主机。
*   集群中完整的网络连接，公网或者私网都可以。

### 软件

#### 安装 Docker

```
sudo apt-get update
sudo apt-get install -y docker.io
```

Kubunetes 建议使用老版本的`docker.io`，如果需要使用最新版的`docker-ce`，可参考上一篇博客：[Docker 初体验](http://www.cnblogs.com/RainingNight/p/first-docker-note.html#安装)。

#### 禁用 swap 文件

然后需要禁用 swap 文件，这是 Kubernetes 的强制步骤。实现它很简单，编辑`/etc/fstab`文件，注释掉引用`swap`的行，保存并重启后输入`sudo swapoff -a`即可。

> 对于禁用`swap`内存，你可能会有点不解，具体原因可以查看 Github 上的 Issue：[Kubelet/Kubernetes should work with Swap Enabled](https://github.com/kubernetes/kubernetes/issues/53533)。

## 步骤

### (1/4) 安装 kubeadm, kubelet and kubectl

*   kubeadm: 引导启动 k8s 集群的命令工具。
*   kubelet: 在群集中的所有计算机上运行的组件, 并用来执行如启动 pods 和 containers 等操作。
*   kubectl: 用于操作运行中的集群的命令行工具。

```
sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://tangxusc.github.io/blog/post/kubeadm/apt-key.gpg | sudo apt-key add -

sudo cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://mirrors.ustc.edu.cn/kubernetes/apt/ kubernetes-xenial main
EOF

sudo apt-get update
sudo apt-get install -y kubelet=1.10.2-00 kubeadm=1.10.2-00 kubectl=1.10.2-00
```

> apt-key 下载地址使用了国内镜像，官方地址为：[https://packages.cloud.google.com/apt/doc/apt-key.gpg](https://packages.cloud.google.com/apt/doc/apt-key.gpg)。
> apt 安装包地址使用了中科大的镜像，官方地址为：[http://apt.kubernetes.io/](http://apt.kubernetes.io/)。

### (2/4) 初始化 master 节点

由于网络原因，我们需要提前拉取 k8s 初始化需要用到的 Images，并添加对应的`k8s.gcr.io`标签:

```
## 拉取镜像
docker pull reg.qiniu.com/k8s/kube-apiserver-amd64:v1.10.2
docker pull reg.qiniu.com/k8s/kube-controller-manager-amd64:v1.10.2
docker pull reg.qiniu.com/k8s/kube-scheduler-amd64:v1.10.2
docker pull reg.qiniu.com/k8s/kube-proxy-amd64:v1.10.2
docker pull reg.qiniu.com/k8s/etcd-amd64:3.1.12
docker pull reg.qiniu.com/k8s/pause-amd64:3.1

## 添加Tag
docker tag reg.qiniu.com/k8s/kube-apiserver-amd64:v1.10.2 k8s.gcr.io/kube-apiserver-amd64:v1.10.2
docker tag reg.qiniu.com/k8s/kube-scheduler-amd64:v1.10.2 k8s.gcr.io/kube-scheduler-amd64:v1.10.2
docker tag reg.qiniu.com/k8s/kube-controller-manager-amd64:v1.10.2 k8s.gcr.io/kube-controller-manager-amd64:v1.10.2
docker tag reg.qiniu.com/k8s/kube-proxy-amd64:v1.10.2 k8s.gcr.io/kube-proxy-amd64:v1.10.2
docker tag reg.qiniu.com/k8s/etcd-amd64:3.1.12 k8s.gcr.io/etcd-amd64:3.1.12
docker tag reg.qiniu.com/k8s/pause-amd64:3.1 k8s.gcr.io/pause-amd64:3.1

## 在Kubernetes 1.10 中，增加了CoreDNS，如果使用CoreDNS(默认关闭)，则不需要下面三个镜像。
docker pull reg.qiniu.com/k8s/k8s-dns-sidecar-amd64:1.14.10
docker pull reg.qiniu.com/k8s/k8s-dns-kube-dns-amd64:1.14.10
docker pull reg.qiniu.com/k8s/k8s-dns-dnsmasq-nanny-amd64:1.14.10

docker tag reg.qiniu.com/k8s/k8s-dns-sidecar-amd64:1.14.10 k8s.gcr.io/k8s-dns-sidecar-amd64:1.14.10
docker tag reg.qiniu.com/k8s/k8s-dns-kube-dns-amd64:1.14.10 k8s.gcr.io/k8s-dns-kube-dns-amd64:1.14.10
docker tag reg.qiniu.com/k8s/k8s-dns-dnsmasq-nanny-amd64:1.14.10 k8s.gcr.io/k8s-dns-dnsmasq-nanny-amd64:1.14.10
```

> 据说 kubeadm 可以自定义镜像 Registry，但我并没有找到选项。

#### **注意事项**

* 请注意:在此时请使用 `kubectl get all --all-namespaces`来关注各容器运行情况,默认情况下应该除了DNS容器,其他均会到running状态,如果未能在此状态,请检查pod运行状态
* 错误情况1: pod一直未pedding状态(或者block状态),使用`kubectl describe pod名字` 查看后发现 `pod with UID "xxx"  specified privileged container, but is disallowed`,请依次检查中
```
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS --allow_privileged
```
这命令中是否加入了--allow_privileged 和 `/etc/kubernetes/manifests/kube-apiserver.yaml` apiServer是否启用了 `--allow-privileged=true` 参照 [kubelet privileged](https://github.com/kubernetes/kubernetes/issues/6530)

Master 节点就是运行着控制组件的机器，包括 etcd(集群数据库) 和 API 服务 (kubectl CLI 通讯服务)。
初始化 master 节点, 只需随便在一台装过 kubeadm 的机器上运行如下命令:

```
sudo kubeadm init --kubernetes-version=v1.10.2 --feature-gates=CoreDNS=true --pod-network-cidr=192.168.0.0/16
```

init 常用主要参数：

*   --kubernetes-version: 指定 Kubenetes 版本，如果不指定该参数，会从 google 网站下载最新的版本信息。

*   --pod-network-cidr: 指定 pod 网络的 IP 地址范围，它的值取决于你在下一步选择的哪个网络网络插件，比如我在本文中使用的是 Calico 网络，需要指定为`192.168.0.0/16`。

*   --apiserver-advertise-address: 指定 master 服务发布的 Ip 地址，如果不指定，则会自动检测网络接口，通常是内网 IP。

*   --feature-gates=CoreDNS: 是否使用 CoreDNS，值为 true/false，CoreDNS 插件在 1.10 中提升到了 Beta 阶段，最终会成为 Kubernetes 的缺省选项。

关于 kubeadm 更详细的的介绍请参考 [kubeadm 官方文档](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/)。

最终输出如下：

```shell
raining@raining-ubuntu:~$ sudo kubeadm init --kubernetes-version=v1.10.2 --feature-gates=CoreDNS=true --pod-network-cidr=192.168.0.0/16
[sudo] password for raining: 
[init] Using Kubernetes version: v1.10.2
[init] Using Authorization modes: [Node RBAC]
[preflight] Running pre-flight checks.
    [WARNING SystemVerification]: docker version is greater than the most recently validated version. Docker version: 17.12.1-ce. Max validated version: 17.03
    [WARNING Service-Docker]: docker service is not enabled, please run 'systemctl enable docker.service'
    [WARNING FileExisting-crictl]: crictl not found in system path
Suggestion: go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
[preflight] Starting the kubelet service
[certificates] Generated ca certificate and key.
[certificates] Generated apiserver certificate and key.
[certificates] apiserver serving cert is signed for DNS names [raining-ubuntu kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 192.168.0.8]
[certificates] Generated apiserver-kubelet-client certificate and key.
[certificates] Generated etcd/ca certificate and key.
[certificates] Generated etcd/server certificate and key.
[certificates] etcd/server serving cert is signed for DNS names [localhost] and IPs [127.0.0.1]
[certificates] Generated etcd/peer certificate and key.
[certificates] etcd/peer serving cert is signed for DNS names [raining-ubuntu] and IPs [192.168.0.8]
[certificates] Generated etcd/healthcheck-client certificate and key.
[certificates] Generated apiserver-etcd-client certificate and key.
[certificates] Generated sa key and public key.
[certificates] Generated front-proxy-ca certificate and key.
[certificates] Generated front-proxy-client certificate and key.
[certificates] Valid certificates and keys now exist in "/etc/kubernetes/pki"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/admin.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/kubelet.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/controller-manager.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/scheduler.conf"
[controlplane] Wrote Static Pod manifest for component kube-apiserver to "/etc/kubernetes/manifests/kube-apiserver.yaml"
[controlplane] Wrote Static Pod manifest for component kube-controller-manager to "/etc/kubernetes/manifests/kube-controller-manager.yaml"
[controlplane] Wrote Static Pod manifest for component kube-scheduler to "/etc/kubernetes/manifests/kube-scheduler.yaml"
[etcd] Wrote Static Pod manifest for a local etcd instance to "/etc/kubernetes/manifests/etcd.yaml"
[init] Waiting for the kubelet to boot up the control plane as Static Pods from directory "/etc/kubernetes/manifests".
[init] This might take a minute or longer if the control plane images have to be pulled.
[apiclient] All control plane components are healthy after 39.501722 seconds
[uploadconfig] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[markmaster] Will mark node raining-ubuntu as master by adding a label and a taint
[markmaster] Master raining-ubuntu tainted and labelled with key/value: node-role.kubernetes.io/master=""
[bootstraptoken] Using token: vtyk9m.g4afak37myq3rsdi
[bootstraptoken] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstraptoken] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstraptoken] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstraptoken] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join 192.168.0.8:6443 --token vtyk9m.g4afak37myq3rsdi --discovery-token-ca-cert-hash sha256:19246ce11ba3fc633fe0b21f2f8aaaebd7df9103ae47138dc0dd615f61a32d99
```

如果想在非 root 用户下使用`kubectl`，可以执行如下命令 (也是`kubeadm init`输出的一部分)：

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

kubeadm init 输出的 token 用于 master 和加入节点间的身份认证，token 是机密的，需要保证它的安全，因为拥有此标记的人都可以随意向集群中添加节点。你也可以使用`kubeadm`命令列出，创建，删除 Token，有关详细信息, 请参阅[官方引用文档](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-token)。

我们在浏览器中输入`https://<master-ip>:6443`来验证一下是否部署成功，返回如下：

```
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {

  },
  "status": "Failure",
  "message": "forbidden: User \"system:anonymous\" cannot get path \"/\"",
  "reason": "Forbidden",
  "details": {

  },
  "code": 403
}
```

### (3/4) 安装网络插件

安装一个网络插件是必须的，因为你的 pods 之间需要彼此通信。

网络部署必须是优先于任何应用的部署，如`kube-dns`(本文中使用的是`coredns`) 在网络部署成功之前是无法使用的。kubeadm 只支持容器网络接口（CNI）的网络类型（不支持 kubenet）。

比较常见的 network addon 有：Calico, Canal, Flannel, Kube-router, Romana, Weave Net 等。详细的网络列表可参考[插件页面](https://kubernetes.io/docs/concepts/cluster-administration/addons/)。

使用下列命令来安装网络插件:

```
kubectl apply -f <add-on.yaml>
```

在本文中，我使用的是 **Calico** 网络，安装如下：

```
#下载镜像
docker pull calico/typha:v0.7.4
docker pull calico/node:v3.1.3
docker pull calico/cni:v3.1.3
#tag转换
docker tag calico/typha:v0.7.4 quay.io/calico/typha:v0.7.4
docker tag calico/node:v3.1.3 quay.io/calico/node:v3.1.3
docker tag calico/cni:v3.1.3 quay.io/calico/cni:v3.1.3
#创建
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
```

> 为了 Calico 可以正常运行，必须在执行 kubeadm init 时使用 `--pod-network-cidr=192.168.0.0/16`。

更详细的可以查看 Calico 官方文档：[kubeadm quickstart](https://docs.projectcalico.org/v3.1/getting-started/kubernetes)。

网络插件安装完成后，可以通过检查`coredns pod`的运行状态来判断网络插件是否正常运行：

```
kubectl get pods --all-namespaces

# 输出
NAMESPACE     NAME                                      READY     STATUS    RESTARTS   AGE
kube-system   calico-etcd-zxmvh                         1/1       Running   0          4m
kube-system   calico-kube-controllers-f9d6c4cb6-42w9j   1/1       Running   0          4m
kube-system   calico-node-jq5qb                         2/2       Running   0          4m
kube-system   coredns-7997f8864c-kfswc                  1/1       Running   0          1h
kube-system   coredns-7997f8864c-ttvj2                  1/1       Running   0          1h
kube-system   etcd-raining-ubuntu                       1/1       Running   0          1h
kube-system   kube-apiserver-raining-ubuntu             1/1       Running   0          1h
kube-system   kube-controller-manager-raining-ubuntu    1/1       Running   0          1h
kube-system   kube-proxy-vrjlq                          1/1       Running   0          1h
kube-system   kube-scheduler-raining-ubuntu             1/1       Running   0          1h
```

等待`coredns pod`的状态变成 **Running**，就可以继续添加从节点了。

#### 隔离主节点

默认情况下，出于安全的考虑，并不会在主节点上运行 pod，如果你想在主节点上运行 pod，比如：运行一个单机版的 kubernetes 集群时，可运行下面的命令：

```
kubectl taint nodes --all node-role.kubernetes.io/master-
```

输出类似这样：

```
node "test-01" untainted
taint key="dedicated" and effect="" not found.
taint key="dedicated" and effect="" not found.
```

这将移除所有节点的`node-role.kubernetes.io/master`标志，包括主节点，Scheduler 便可以在任何节点上安排运行 pod 了。

### (4/4) 加入其他节点

节点就是你的负载（容器和 pod 等等）运行的地方，往集群里添加节点，只需要在每台机器上执行下列几步：

*   SSH 登录机器
*   切换到 root (比如 sudo su -)
*   执行 _kubeadm init_ 输出的那句命令: `kubeadm join --token <token> <master-ip>:<master-port> --discovery-token-ca-cert-hash sha256:<hash>`

执行后输出类似这样:

```
raining@ubuntu1:~$ sudo kubeadm join 192.168.0.8:6443 --token vtyk9m.g4afak37myq3rsdi --discovery-token-ca-cert-hash sha256:19246ce11ba3fc633fe0b21f2f8aaaebd7df9103ae47138dc0dd615f61a32d99
[preflight] Running pre-flight checks.
    [WARNING SystemVerification]: docker version is greater than the most recently validated version. Docker version: 17.12.1-ce. Max validated version: 17.03
    [WARNING Service-Docker]: docker service is not enabled, please run 'systemctl enable docker.service'
    [WARNING FileExisting-crictl]: crictl not found in system path
Suggestion: go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
[preflight] Starting the kubelet service
[discovery] Trying to connect to API Server "192.168.0.8:6443"
[discovery] Created cluster-info discovery client, requesting info from "https://192.168.0.8:6443"
[discovery] Requesting info from "https://192.168.0.8:6443" again to validate TLS against the pinned public key
[discovery] Cluster info signature and contents are valid and TLS certificate validates against pinned roots, will use API Server "192.168.0.8:6443"
[discovery] Successfully established connection with API Server "192.168.0.8:6443"

This node has joined the cluster:
* Certificate signing request was sent to master and a response
  was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the master to see this node join the cluster.
```

几秒后，你在主节点上运行`kubectl get nodes`就可以看到新加的机器了：

```
NAME             STATUS    ROLES     AGE       VERSION
raining-ubuntu   Ready     master    1h        v1.10.2
ubuntu1          Ready     <none>    2m        v1.10.2
```

### (可选) 在非主节点上管理集群

为了可以在其他电脑上使用 kubectl 来管理你的集群，可以从主节点上复制管理员 的 kubeconfig 文件到你的电脑上：

```
scp root@<master ip>:/etc/kubernetes/admin.conf .
kubectl --kubeconfig ./admin.conf get nodes
```

### (可选) 映射 API 服务到本地

如果你想从集群外部连接到 API 服务，可以使用工具`kubectl proxy`:

```
scp root@<master ip>:/etc/kubernetes/admin.conf .
kubectl --kubeconfig ./admin.conf proxy
```

这样就可以在本地这样 `http://localhost:8001/api/v1` 访问到 API 服务了。

### (可选) 部署一个微服务

现在可以测试你新搭建的集群了，Sock Shop 就是一个微服务的样本，它体现了在 Kubernetes 里如何运行和连接一系列的服务。想了解更多关于微服务的内容，请查看 [GitHub README](https://github.com/microservices-demo/microservices-demo)。

```
kubectl create namespace sock-shop
kubectl apply -n sock-shop -f "https://github.com/microservices-demo/microservices-demo/blob/master/deploy/kubernetes/complete-demo.yaml?raw=true"
```

可以通过以下命令来查看前端服务是否有开放对应的端口：

```
kubectl -n sock-shop get svc front-end
```

输出类似:

```
NAME        TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
front-end   NodePort   10.107.207.35   <none>        80:30001/TCP   31s
```

可能需要几分钟时间来下载和启用所有的容器，通过`kubectl get pods -n sock-shop`来获取服务的状态。

输出如下：

```
raining@raining-ubuntu:~$ kubectl get pods -n sock-shop
NAME                            READY     STATUS    RESTARTS   AGE
carts-6cd457d86c-wdbsg          1/1       Running   0          1m
carts-db-784446fdd6-9gsrs       1/1       Running   0          1m
catalogue-779cd58f9b-nf6n4      1/1       Running   0          1m
catalogue-db-6794f65f5d-kwc2x   1/1       Running   0          1m
front-end-679d7bcb77-4hbjq      1/1       Running   0          1m
orders-755bd9f786-gbspz         1/1       Running   0          1m
orders-db-84bb8f48d6-98wsm      1/1       Running   0          1m
payment-674658f686-xc7gk        1/1       Running   0          1m
queue-master-5f98bbd67-xgqr6    1/1       Running   0          1m
rabbitmq-86d44dd846-nf2g6       1/1       Running   0          1m
shipping-79786fb956-bs7jn       1/1       Running   0          1m
user-6995984547-nvqw4           1/1       Running   0          1m
user-db-fc7b47fb9-zcf5r         1/1       Running   0          1m
```

然后在你的浏览器里访问集群节点的 IP 和对应的端口，比如`http://<master_ip>/<cluster-ip>:<port>`。 在这个例子里，可能是 30001，但是它可能跟你的不一样。如果有防火墙的话，确保在你访问之前开放了对应的端口。

![](https://images2018.cnblogs.com/blog/347047/201805/347047-20180502084227253-1773772236.png)

> 需要注意的是，如果在多节点部署时，要使用节点的 IP 进行访问，而不是 Master 服务器的 IP。

最后，卸载 _socks shop_, 只需要在主节点上运行:

```
kubectl delete namespace sock-shop
```

## 卸载集群

想要撤销 kubeadm 做的事，首先要[排除节点](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#drain)，并确保在关闭节点之前要清空节点。

在主节点上运行：

```
kubectl drain <node name> --delete-local-data --force --ignore-daemonsets
kubectl delete node <node name>
```

然后在需要移除的节点上，重置 kubeadm 的安装状态：

```
kubeadm reset
```

如果你想重新配置集群，只需运行`kubeadm init`或者`kubeadm join`并使用所需的参数即可。

## 参考资料

*   [install-kubeadm](https://kubernetes.io/docs/setup/independent/install-kubeadm/)
*   [google-containers](https://console.cloud.google.com/gcr/images/google-containers)
