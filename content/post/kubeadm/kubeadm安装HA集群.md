---
title: "kubeadm安装HA集群"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- kubeadm
- k8s
tags:
- kubeadm
- k8s
- install
- HA
keywords:
- kubeadm
- k8s
- install
- HA
---

# kubeadm安装HA集群

鉴于使用二进制的方式安装较为复杂,且不太好处理证书的生成,分发等问题,并且对性能没有较高的要求,所以强烈推荐使用此模式,具体下来这个模式的好处为:

- 官方提供的工具,有官方的文档支持
- 安装贼简单,没有其他的依赖
- 扩展性强,有官方的一些扩展支持
- 集群全部以容器启动,所以没那么多你需要管理的service

## 准备

### 硬件

1. 一台或多台运行 Ubuntu 16.04 + 的主机(其他linux系统也行)
2. 集群中完整的网络连接，公网或者私网都可以

### 各节点环境

- #### docker

  使用加入器安装docker

  ```shell
  curl https://releases.rancher.com/install-docker/17.03.sh | sh
  ```

- #### 禁用swap

  然后需要禁用 swap 文件，这是 Kubernetes 的强制步骤。编辑`/etc/fstab`文件，注释掉引用`swap`的行，保存并重启后输入`sudo swapoff -a`即可

  ```shell
  vim /etc.fastab
  #注释调swap的行
  sudo swapoff -a
  ```

- #### 设置源

  ```shell
  sudo apt-get update && sudo apt-get install -y apt-transport-https
  curl -s https://gitee.com/tanx/kubernetes-test/raw/master/kubeadm/apt-key.gpg | sudo apt-key add -
  
  sudo cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
  deb http://mirrors.ustc.edu.cn/kubernetes/apt/ kubernetes-xenial main
  EOF
  ```

## 安装master

1. ### 安装kubelet,kubeadm,kubectl

   ```shell
   sudo apt-get update
   sudo apt-get install -y kubelet kubeadm kubectl
   ```

2. ### 编辑 kubeadm 配置文件

    `kubeadm-config.yaml`

    ```yaml
    apiVersion: kubeadm.k8s.io/v1beta1
    kind: ClusterConfiguration
    imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers
    kubernetesVersion: v1.13.1
    controlPlaneEndpoint: k8s-cluster.smile13.com:6443 #你的k8s的访问地址
    apiServer:
      certSANs:
        - k8s-cluster.smile13.com		##你的k8s的访问地址
    networking:
      serviceSubnet: 10.96.0.0/12
      podSubnet: 192.168.0.0/16
      dnsDomain: "cluster.local"
    ```

    完整的可以参考 `https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta1`

3. ### 提前拉取镜像(可选)

   ```shell
   kubeadm config images pull --config kubeadm-config.yaml 
   ```

4. ### 初始化master1

   ```shell
   [root@k8s01 ~]# kubeadm init --config kubeadm-config.yaml
   
   [init] Using Kubernetes version: v1.13.1
   [preflight] Running pre-flight checks
   [preflight] Pulling images required for setting up a Kubernetes cluster
   [preflight] This might take a minute or two, depending on the speed of your internet connection
   [preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
   [kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
   [kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
   [kubelet-start] Activating the kubelet service
   [certs] Using certificateDir folder "/etc/kubernetes/pki"
   [certs] Generating "ca" certificate and key
   [certs] Generating "apiserver" certificate and key
   [certs] apiserver serving cert is signed for DNS names [k8s01 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local k8s-cluster.smile13.com k8s-cluster.smile13.com] and IPs [10.96.0.1 192.168.158.131]
   [certs] Generating "apiserver-kubelet-client" certificate and key
   [certs] Generating "etcd/ca" certificate and key
   [certs] Generating "etcd/server" certificate and key
   [certs] etcd/server serving cert is signed for DNS names [k8s01 localhost] and IPs [192.168.158.131 127.0.0.1 ::1]
   [certs] Generating "etcd/peer" certificate and key
   [certs] etcd/peer serving cert is signed for DNS names [k8s01 localhost] and IPs [192.168.158.131 127.0.0.1 ::1]
   [certs] Generating "etcd/healthcheck-client" certificate and key
   [certs] Generating "apiserver-etcd-client" certificate and key
   [certs] Generating "front-proxy-ca" certificate and key
   [certs] Generating "front-proxy-client" certificate and key
   [certs] Generating "sa" key and public key
   [kubeconfig] Using kubeconfig folder "/etc/kubernetes"
   [kubeconfig] Writing "admin.conf" kubeconfig file
   [kubeconfig] Writing "kubelet.conf" kubeconfig file
   [kubeconfig] Writing "controller-manager.conf" kubeconfig file
   [kubeconfig] Writing "scheduler.conf" kubeconfig file
   [control-plane] Using manifest folder "/etc/kubernetes/manifests"
   [control-plane] Creating static Pod manifest for "kube-apiserver"
   [control-plane] Creating static Pod manifest for "kube-controller-manager"
   [control-plane] Creating static Pod manifest for "kube-scheduler"
   [etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
   [wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
   [apiclient] All control plane components are healthy after 28.003045 seconds
   [uploadconfig] storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
   [kubelet] Creating a ConfigMap "kubelet-config-1.13" in namespace kube-system with the configuration for the kubelets in the cluster
   [patchnode] Uploading the CRI Socket information "/var/run/dockershim.sock" to the Node API object "k8s01" as an annotation
   [mark-control-plane] Marking the node k8s01 as control-plane by adding the label "node-role.kubernetes.io/master=''"
   [mark-control-plane] Marking the node k8s01 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
   [bootstrap-token] Using token: t1yovr.ag1xbdhfgo36z8f7
   [bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
   [bootstraptoken] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
   [bootstraptoken] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
   [bootstraptoken] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
   [bootstraptoken] creating the "cluster-info" ConfigMap in the "kube-public" namespace
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
   
     kubeadm join k8s-cluster.smile13.com:6443 --token t1yovr.ag1xbdhfgo36z8f7 --discovery-token-ca-cert-hash sha256:ceaf1b9a9ef558ff8706331cb88e81c28d48528972cee2b92a8416364768e45d
   
   [root@k8s01 ~]# mkdir -p $HOME/.kube
   [root@k8s01 ~]# cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   [root@k8s01 ~]# chown $(id -u):$(id -g) $HOME/.kube/config
   ```

5. ### 查看集群状态

    ```shell
    [root@k8s01 ~]# kubectl get cs
    NAME                 STATUS    MESSAGE              ERROR
    controller-manager   Healthy   ok                   
    scheduler            Healthy   ok                   
    etcd-0               Healthy   {"health": "true"}   
    [root@k8s01 ~]# kubectl get nodes
    NAME    STATUS     ROLES    AGE     VERSION
    k8s01   NotReady   master   4m45s   v1.13.1
    ```

6. ### 安装网络插件

    ```shell
    kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
    
    kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
    ```

7. ### 复制安装文件到其他master

    ```shell
    [root@k8s01 k8s-install]# cd /etc/kubernetes && tar cvzf k8s-key.tgz pki/ca.* pki/sa.* pki/front-proxy-ca.* pki/etcd/ca.* admin.conf
    pki/ca.crt
    pki/ca.key
    pki/sa.key
    pki/sa.pub
    pki/front-proxy-ca.crt
    pki/front-proxy-ca.key
    pki/etcd/ca.crt
    pki/etcd/ca.key
    admin.conf
    [root@k8s01 kubernetes]# scp /etc/kubernetes/k8s-key.tgz k8s02:/etc/kubernetes/
    [root@k8s01 kubernetes]# scp /etc/kubernetes/k8s-key.tgz k8s03:/etc/kubernetes/
    
    ######到对应的master解压k8s-key.tgz包
    
    ######复制kubeadm-config.yaml到其他master（用于从阿里云下载镜像，也可以不复制，直接pull需要的镜像，这里我为了方便直接copy配置文件进行pull）
    [root@k8s01 ~]# scp  k8s-install/kubeadm-config.yaml k8s02:~
    kubeadm-config.yaml  
    [root@k8s01 ~]# scp  k8s-install/kubeadm-config.yaml k8s03:~
    kubeadm-config.yaml
    ```

### 原理

1. 在进行更改之前，运行一系列飞行前检查以验证系统状态。

2. 生成自签名CA（或使用现有CA），以便为群集中的每个组件设置标识。如果用户通过将其放入通过`--cert-dir` （`/etc/kubernetes/pki`默认情况下）配置的cert目录中提供了自己的CA证书和/或密钥，则会跳过此步骤。

3. 将kubeconfig文件写入kubelet `/etc/kubernetes/`，控制器管理器和调度程序以用于连接到API服务器，每个API服务器都有自己的标识，以及另一个用于管理命名的kubeconfig文件`admin.conf`。

4. 为API服务器，控制器管理器和调度程序生成静态Pod清单。如果未提供外部etcd，则会为etcd生成其他静态Pod清单。

## 安装其他master

### 拉取镜像

```shell
kubeadm config images pull --config kubeadm-config.yaml 
```

### 初始化master

```shell
kubeadm join k8s-cluster.smile13.com:6443 --token t1yovr.ag1xbdhfgo36z8f7 --discovery-token-ca-cert-hash sha256:ceaf1b9a9ef558ff8706331cb88e81c28d48528972cee2b92a8416364768e45d --experimental-control-plane
```

一定注意此处加入了新的参数**--experimental-control-plane** 

### 查看集群状态

```shell
[root@k8s01 ~]# kubectl get nodes
NAME    STATUS   ROLES    AGE     VERSION
k8s01   Ready    master   31m     v1.13.1
k8s02   Ready    master   4m51s   v1.13.1
```

