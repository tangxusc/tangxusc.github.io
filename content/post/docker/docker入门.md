---
title: "docker入门"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- docker
tags:
- docker
keywords:
- docker
---

## Docker简介
Docker 最初是 dotCloud 公司创始人 Solomon Hykes 在法国期间发起的一个公司内部项目，它是基于 dotCloud 公司多年云服务技术的一次革新，并于 2013 年 3 月以 Apache 2.0 授权协议开源)，主要项目代码在 GitHub 上进行维护。Docker 项目后来还加入了 Linux 基金会，并成立推动开放容器联盟。

Docker 自开源后受到广泛的关注和讨论，至今其 GitHub 项目已经超过 3 万 6 千个星标和一万多个 fork。甚至由于 Docker 项目的火爆，在 2013 年底，dotCloud 公司决定改名为 Docker。Docker 最初是在 Ubuntu 12.04 上开发实现的；Red Hat 则从 RHEL 6.5 开始对 Docker 进行支持；Google 也在其 PaaS 产品中广泛应用 Docker。

Docker 使用 Google 公司推出的 Go 语言 进行开发实现，基于 Linux 内核的 cgroup，namespace，以及 AUFS 类的 Union FS 等技术，对进程进行封装隔离，属于操作系统层面的虚拟化技术。由于隔离的进程独立于宿主和其它的隔离的进程，因此也称其为容器。最初实现是基于 LXC，从 0.7 以后开始去除 LXC，转而使用自行开发的 libcontainer，从 1.11 开始，则进一步演进为使用 runC 和 containerd。

Docker 在容器的基础上，进行了进一步的封装，从文件系统、网络互联到进程隔离等等，极大的简化了容器的创建和维护。使得 Docker 技术比虚拟机技术更为轻便、快捷。

## 为什么要使用 Docker？
作为一种新兴的虚拟化方式，Docker 跟传统的虚拟化方式相比具有众多的优势。

#### 1. 更高效的利用系统资源

由于容器不需要进行硬件虚拟以及运行完整操作系统等额外开销，Docker 对系统资源的利用率更高。无论是应用执行速度、内存损耗或者文件存储速度，都要比传统虚拟机技术更高效。因此，相比虚拟机技术，一个相同配置的主机，往往可以运行更多数量的应用。

#### 2. 更快速的启动时间

传统的虚拟机技术启动应用服务往往需要数分钟，而 Docker 容器应用，由于直接运行于宿主内核，无需启动完整的操作系统，因此可以做到秒级、甚至毫秒级的启动时间。大大的节约了开发、测试、部署的时间。

#### 3. 一致的运行环境

开发过程中一个常见的问题是环境一致性问题。由于开发环境、测试环境、生产环境不一致，导致有些 bug 并未在开发过程中被发现。而 Docker 的镜像提供了除内核外完整的运行时环境，确保了应用运行环境一致性，从而不会再出现 “这段代码在我机器上没问题啊” 这类问题。

#### 4. 持续交付和部署

对开发和运维（DevOps）人员来说，最希望的就是一次创建或配置，可以在任意地方正常运行。

使用 Docker 可以通过定制应用镜像来实现持续集成、持续交付、部署。开发人员可以通过 Dockerfile 来进行镜像构建，并结合 持续集成(Continuous Integration) 系统进行集成测试，而运维人员则可以直接在生产环境中快速部署该镜像，甚至结合 持续部署(Continuous Delivery/Deployment) 系统进行自动部署。

而且使用 Dockerfile使镜像构建透明化，不仅仅开发团队可以理解应用运行环境，也方便运维团队理解应用运行所需条件，帮助更好的生产环境中部署该镜像。

#### 5. 更轻松的迁移

由于 Docker 确保了执行环境的一致性，使得应用的迁移更加容易。Docker 可以在很多平台上运行，无论是物理机、虚拟机、公有云、私有云，甚至是笔记本，其运行结果是一致的。因此用户可以很轻易的将在一个平台上运行的应用，迁移到另一个平台上，而不用担心运行环境的变化导致应用无法正常运行的情况。

#### 6. 更轻松的维护和扩展
Docker 使用的分层存储以及镜像的技术，使得应用重复部分的复用更为容易，也使得应用的维护更新更加简单，基于基础镜像进一步扩展镜像也变得非常简单。此外，Docker 团队同各个开源项目团队一起维护了一大批高质量的官方镜像，既可以直接在生产环境使用，又可以作为基础进一步定制，大大的降低了应用服务的镜像制作成本。
​    
## Docker三大组件
### 1. Docker 镜像
我们都知道，操作系统分为内核和用户空间。对于 Linux 而言，内核启动后，会挂载 root 文件系统为其提供用户空间支持。而 Docker 镜像（Image），就相当于是一个 root 文件系统。比如官方镜像 ubuntu:14.04 就包含了完整的一套 Ubuntu 14.04 最小系统的 root 文件系统。

Docker 镜像是一个特殊的文件系统，除了提供容器运行时所需的程序、库、资源、配置等文件外，还包含了一些为运行时准备的一些配置参数（如匿名卷、环境变量、用户等）。镜像不包含任何动态数据，其内容在构建之后也不会被改变。

因为镜像包含操作系统完整的 root 文件系统，其体积往往是庞大的，因此在 Docker 设计时，就充分利用 Union FS 的技术，将其设计为分层存储的架构。所以严格来说，镜像并非是像一个 ISO 那样的打包文件，镜像只是一个虚拟的概念，其实际体现并非由一个文件组成，而是由一组文件系统组成，或者说，由多层文件系统联合组成。

镜像构建时，会一层层构建，前一层是后一层的基础。每一层构建完就不会再发生改变，后一层上的任何改变只发生在自己这一层。比如，删除前一层文件的操作，实际不是真的删除前一层的文件，而是仅在当前层标记为该文件已删除。在最终容器运行的时候，虽然不会看到这个文件，但是实际上该文件会一直跟随镜像。因此，在构建镜像的时候，需要额外小心，每一层尽量只包含该层需要添加的东西，任何额外的东西应该在该层构建结束前清理掉。

分层存储的特征还使得镜像的复用、定制变的更为容易。甚至可以用之前构建好的镜像作为基础层，然后进一步添加新的层，以定制自己所需的内容，构建新的镜像。

关于镜像构建，将会在后续相关章节中做进一步的讲解。

### 2. Docker 容器
镜像（Image）和容器（Container）的关系，就像是面向对象程序设计中的类和实例一样，镜像是静态的定义，容器是镜像运行时的实体。容器可以被创建、启动、停止、删除、暂停等。

容器的实质是进程，但与直接在宿主执行的进程不同，容器进程运行于属于自己的独立的 命名空间。因此容器可以拥有自己的 root 文件系统、自己的网络配置、自己的进程空间，甚至自己的用户 ID 空间。容器内的进程是运行在一个隔离的环境里，使用起来，就好像是在一个独立于宿主的系统下操作一样。这种特性使得容器封装的应用比直接在宿主运行更加安全。也因为这种隔离的特性，很多人初学 Docker 时常常会把容器和虚拟机搞混。

前面讲过镜像使用的是分层存储，容器也是如此。每一个容器运行时，是以镜像为基础层，在其上创建一个当前容器的存储层，我们可以称这个为容器运行时读写而准备的存储层为容器存储层。

容器存储层的生存周期和容器一样，容器消亡时，容器存储层也随之消亡。因此，任何保存于容器存储层的信息都会随容器删除而丢失。

按照 Docker 最佳实践的要求，容器不应该向其存储层内写入任何数据，容器存储层要保持无状态化。所有的文件写入操作，都应该使用 数据卷（Volume）、或者绑定宿主目录，在这些位置的读写会跳过容器存储层，直接对宿主(或网络存储)发生读写，其性能和稳定性更高。

数据卷的生存周期独立于容器，容器消亡，数据卷不会消亡。因此，使用数据卷后，容器可以随意删除、重新 run，数据却不会丢失。

### 3. Docker Registry
镜像构建完成后，可以很容易的在当前宿主上运行，但是，如果需要在其它服务器上使用这个镜像，我们就需要一个集中的存储、分发镜像的服务，Docker Registry 就是这样的服务。

一个 Docker Registry中可以包含多个仓库（Repository）；每个仓库可以包含多个标签（Tag）；每个标签对应一个镜像。

通常，一个仓库会包含同一个软件不同版本的镜像，而标签就常用于对应该软件的各个版本。我们可以通过 <仓库名>:<标签> 的格式来指定具体是这个软件哪个版本的镜像。如果不给出标签，将以 latest 作为默认标签。

以 Ubuntu 镜像为例，ubuntu是仓库的名字，其内包含有不同的版本标签，如，14.04, 16.04。我们可以通过 ubuntu:14.04，或者 ubuntu:16.04 来具体指定所需哪个版本的镜像。如果忽略了标签，比如 ubuntu，那将视为 ubuntu:latest。

仓库名经常以 两段式路径形式出现，比如jwilder/nginx-proxy，前者往往意味着 Docker Registry多用户环境下的用户名，后者则往往是对应的软件名。但这并非绝对，取决于所使用的具体 Docker Registry 的软件或服务。

Docker Registry 公开服务

Docker Registry 公开服务是开放给用户使用、允许用户管理镜像的 Registry 服务。一般这类公开服务允许用户免费上传、下载公开的镜像，并可能提供收费服务供用户管理私有镜像。

最常使用的 Registry 公开服务是官方的 Docker Hub，这也是默认的 Registry，并拥有大量的高质量的官方镜像。除此以外，还有 CoreOS 的 Quay.io，CoreOS 相关的镜像存储在这里；Google 的 Google Container Registry，Kubernetes 的镜像使用的就是这个服务。

由于某些原因，在国内访问这些服务可能会比较慢。国内的一些云服务商提供了针对 Docker Hub 的镜像服务（Registry Mirror），这些镜像服务被称为加速器。常见的有 阿里云加速器、DaoCloud 加速器、灵雀云加速器等。使用加速器会直接从国内的地址下载 Docker Hub 的镜像，比直接从官方网站下载速度会提高很多。在后面的章节中会有进一步如何配置加速器的讲解。

国内也有一些云服务商提供类似于 Docker Hub 的公开服务。比如 时速云镜像仓库、网易云镜像服务、DaoCloud 镜像市场、阿里云镜像库等。

私有 Docker Registry

除了使用公开服务外，用户还可以在本地搭建私有 Docker Registry。Docker 官方提供了 Docker Registry 镜像，可以直接使用做为私有 Registry 服务。在后续的相关章节中，会有进一步的搭建私有 Registry 服务的讲解。

开源的 Docker Registry 镜像只提供了 Docker Registry API 的服务端实现，足以支持 docker 命令，不影响使用。但不包含图形界面，以及镜像维护、用户管理、访问控制等高级功能。在官方的商业化版本 Docker Trusted Registry 中，提供了这些高级功能。

除了官方的 Docker Registry 外，还有第三方软件实现了 Docker Registry API，甚至提供了用户界面以及一些高级功能。比如，VMWare Harbor 和 Sonatype Nexus。
​    
## 安装Docker
### 1. Ubuntu、Debian 系列安装 Docker
#### 1. 系统要求
​    Docker 支持以下版本的 Ubuntu 和 Debian 操作系统：
​    Ubuntu Xenial 16.04 (LTS)
​    Ubuntu Trusty 14.04 (LTS)
​    Ubuntu Precise 12.04 (LTS)
​    Debian testing stretch (64-bit)
​    Debian 8 Jessie (64-bit)
​    Debian 7 Wheezy (64-bit)（必须启用 backports)
#### 2. 使用脚本自动安装
Docker 官方为了简化安装流程，提供了一套安装脚本，Ubuntu 和 Debian 系统可以使用这套脚本安装：
```shell
curl -sSL https://get.docker.com/ | sh
```
#### 3. 阿里云的安装脚本
因为墙等原因,docker可能安装起来很慢,或者无法连接到docker官网,所以这里要使用国内的docker安装脚本来进行安装:
```shell
curl -sSL http://acs-public-mirror.oss-cn-hangzhou.aliyuncs.com/docker-engine/internet | sh -
```
#### 4. Daocloud安装脚本
```shell
curl -sSL https://get.daocloud.io/docker | sh
```
#### 5. 其他方式安装docker
其他方式安装docker请直接运行命令:
```shell
sudo apt-get install docker-engine  
```
### 2. CentOS 操作系统安装 Docker

#### 1. 系统要求
Docker 最低支持 CentOS 7。
#### 2. 安装脚本
Docker安装同样支持Ubuntu系列中的官方自动脚本安装,阿里云脚本安装,Daocloud脚本安装
#### 3. 其他方式安装
```shell
yum install docker-engine
```

### 3. **安装docker注意事项**
在安装docker前,建议先更新yum源再进行安装,因为yum源中的docker版本太旧了,在docker 1.12+以上的版本中引入了docker swarm/docker service/docker stack等,并且对docker remote api进行了变更,所以建议使用docker 1.12+以上的版本.

## 镜像加速器
#### 1. 申请加速器
国内访问 Docker Hub有时会遇到困难，此时可以配置镜像加速器。国内很多云服务商都提供了加速器服务，例如：

 - 阿里云加速器
 - DaoCloud 加速器
 - 灵雀云加速器

注册用户并且申请加速器，会获得如 https://xxxx.mirror.aliyuncs.com 这样的地址。我们需要将其配置给 Docker 引擎。
#### 2. 配置加速器
##### 1.Daocloud加速器
如果使用的是Daocloud的加速器,则直接复制Daocloud中提供的命令,例如:
```shell
curl -sSL https://get.daocloud.io/daotools/set_mirror.sh | sh -s http://084c78c9.m.daocloud.io
```
命令运行后,会自动在/etc/docker/daemon.json中加入
```json
{"registry-mirrors": ["http://084c78c9.m.daocloud.io"]}
```
**注意**
在使用daocloud的时候一定小心,先要保证/etc/docker/daemon.json文件中没有内容,再运行命令,如果文件中存在内容,在运行daocloud的命令后,docker无法重启,查找原因后发现,daocloud在执行时,并未判断文件是否有内容,导致直接在文件中进行内容添加,使此文件不符合json格式(其实就是在后面多加了一个大括号,估计程序员是零时工).

##### 2. 其他加速器配置
其他方式的加速器需要手动修改/etc/docker/daemon.json文件,具体为:
```json
{"registry-mirrors": ["加速器地址"]}
```

在配置完docker加速器后,重启docker服务(如不重启则无效):
```shell
#ubuntu:
service docker restart
#centos:
systemctl restart docker
```
## 镜像使用
### 1. 获取镜像

之前提到过，Docker Hub上有大量的高质量的镜像可以用，这里我们就说一下怎么获取这些镜像并运行。

从 Docker Registry 获取镜像的命令是 docker pull。其命令格式为：
```shell
docker pull [选项] [Docker Registry地址]<仓库名>:<标签>
```
具体的选项可以通过 docker pull --help 命令看到，这里我们说一下镜像名称的格式。

Docker Registry地址：地址的格式一般是 <域名/IP>[:端口号]。默认地址是 Docker Hub。
仓库名：如之前所说，这里的仓库名是两段式名称，既 <用户名>/<软件名>。对于 Docker Hub，如果不给出用户名，则默认为 library，也就是官方镜像。
比如：
```shell
$ docker pull ubuntu:14.04
14.04: Pulling from library/ubuntu
bf5d46315322: Pull complete
9f13e0ac480c: Pull complete
e8988b5b3097: Pull complete
40af181810e7: Pull complete
e6f7c7e5c03e: Pull complete
Digest: sha256:147913621d9cdea08853f6ba9116c2e27a3ceffecf3b492983ae97c3d643fbbe
Status: Downloaded newer image for ubuntu:14.04
```
上面的命令中没有给出 Docker Registry 地址，因此将会从 Docker Hub 获取镜像。而镜像名称是 ubuntu:14.04，因此将会获取官方镜像 library/ubuntu 仓库中标签为 14.04 的镜像。

从下载过程中可以看到我们之前提及的分层存储的概念，镜像是由多层存储所构成。下载也是一层层的去下载，并非单一文件。下载过程中给出了每一层的 ID 的前 12 位。并且下载结束后，给出该镜像完整的 sha256 的摘要，以确保下载一致性。

在实验上面命令的时候，你可能会发现，你所看到的层 ID 以及 sha256 的摘要和这里的不一样。这是因为官方镜像是一直在维护的，有任何新的 bug，或者版本更新，都会进行修复再以原来的标签发布，这样可以确保任何使用这个标签的用户可以获得更安全、更稳定的镜像。

*如果从 Docker Hub 下载镜像非常缓慢，可以参照后面的章节配置加速器。*

### 2. 运行镜像

有了镜像后，我们就可以以这个镜像为基础启动一个容器来运行。以上面的 ubuntu:14.04 为例，如果我们打算启动里面的 bash 并且进行交互式操作的话，可以执行下面的命令。
```shell
$ docker run -it --rm ubuntu:14.04 bash
root@e7009c6ce357:/# cat /etc/os-release
NAME="Ubuntu"
VERSION="14.04.5 LTS, Trusty Tahr"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 14.04.5 LTS"
VERSION_ID="14.04"
HOME_URL="http://www.ubuntu.com/"
SUPPORT_URL="http://help.ubuntu.com/"
BUG_REPORT_URL="http://bugs.launchpad.net/ubuntu/"
root@e7009c6ce357:/# exit
exit
```
docker run 就是运行容器的命令，具体格式我们会在后面的章节讲解，我们这里简要的说明一下上面用到的参数。

 - **-it**：这是两个参数，一个是 -i：交互式操作，一个是 -t 终端。我们这里打算进入 bash 执行一些命令并查看返回结果，因此我们需要交互式终端。
 - **--rm**：这个参数是说容器退出后随之将其删除。默认情况下，为了排障需求，退出的容器并不会立即删除，除非手动 docker rm。我们这里只是随便执行个命令，看看结果，不需要排障和保留结果，因此使用 --rm 可以避免浪费空间。
 - **ubuntu:14.04**：这是指用 ubuntu:14.04 镜像为基础来启动容器。
 - **bash**：放在镜像名后的是命令，这里我们希望有个交互式 Shell，因此用的是 bash。
进入容器后，我们可以在 Shell 下操作，执行任何所需的命令。这里，我们执行了 cat /etc/os-release，这是 Linux 常用的查看当前系统版本的命令，从返回的结果可以看到容器内是 Ubuntu 14.04.5 LTS 系统。

最后我们通过 exit 退出了这个容器。

### 3. 列出镜像
要想列出已经下载下来的镜像，可以使用 docker images 命令。
```shell
$ docker images
REPOSITORY           TAG                 IMAGE ID            CREATED             SIZE
redis                latest              5f515359c7f8        5 days ago          183 MB
nginx                latest              05a60462f8ba        5 days ago          181 MB
mongo                3.2                 fe9198c04d62        5 days ago          342 MB
<none>               <none>              00285df0df87        5 days ago          342 MB
ubuntu               16.04               f753707788c5        4 weeks ago         127 MB
ubuntu               latest              f753707788c5        4 weeks ago         127 MB
ubuntu               14.04               1e0c3dd64ccd        4 weeks ago         188 MB
```
列表包含了仓库名、标签、镜像 ID、创建时间以及所占用的空间。

其中仓库名、标签在之前的基础概念章节已经介绍过了。镜像 ID 则是镜像的唯一标识，一个镜像可以对应多个标签。因此，在上面的例子中，我们可以看到 ubuntu:16.04 和 ubuntu:latest 拥有相同的 ID，因为它们对应的是同一个镜像。

### 4. 使用 Dockerfile生成镜像
镜像的生成实际上就是定制每一层所添加的配置、文件。如果我们可以把每一层修改、安装、构建、操作的命令都写入一个脚本，用这个脚本来构建、定制镜像，那么之前提及的无法重复的问题、镜像构建透明性的问题、体积的问题就都会解决。这个脚本就是 Dockerfile。

Dockerfile 是一个文本文件，其内包含了一条条的指令(Instruction)，每一条指令构建一层，因此每一条指令的内容，就是描述该层应当如何构建。

还以之前定制 nginx 镜像为例，这次我们使用 Dockerfile 来定制。

在一个空白目录中，建立一个文本文件，并命名为 Dockerfile：
```shell
$ mkdir mynginx
$ cd mynginx
$ touch Dockerfile
```
其内容为：
```shell
FROM nginx
RUN echo '<h1>Hello, Docker!</h1>' > /usr/share/nginx/html/index.html
```
这个 Dockerfile 很简单，一共就两行。涉及到了两条指令，FROM 和 RUN。

> FROM 指定基础镜像

所谓定制镜像，那一定是以一个镜像为基础，在其上进行定制。就像我们之前运行了一个 nginx 镜像的容器，再进行修改一样，基础镜像是必须指定的。而 FROM 就是指定基础镜像，因此一个 Dockerfile 中 FROM 是必备的指令，并且必须是第一条指令。

在 Docker Hub (https://hub.docker.com/explore/) 上有非常多的高质量的官方镜像， 有可以直接拿来使用的服务类的镜像，如 nginx、redis、mongo、mysql、httpd、php、tomcat 等； 也有一些方便开发、构建、运行各种语言应用的镜像，如 node、openjdk、python、ruby、golang 等。 可以在其中寻找一个最符合我们最终目标的镜像为基础镜像进行定制。 如果没有找到对应服务的镜像，官方镜像中还提供了一些更为基础的操作系统镜像，如 ubuntu、debian、centos、fedora、alpine 等，这些操作系统的软件库为我们提供了更广阔的扩展空间。

> RUN 执行命令

RUN 指令是用来执行命令行命令的。由于命令行的强大能力，RUN 指令在定制镜像时是最常用的指令之一。其格式有两种：

 - **shell 格式**：RUN <命令>，就像直接在命令行中输入的命令一样。刚才写的 Dockrfile 中的 RUN 指令就是这种格式。
```shell
RUN echo '<h1>Hello, Docker!</h1>' > /usr/share/nginx/html/index.html
```
 - **exec 格式**：RUN ["可执行文件", "参数1", "参数2"]，这更像是函数调用中的格式。

### 5. 构建镜像
现在我们明白了这个 Dockerfile的内容，那么让我们来构建这个镜像。

在 Dockerfile 文件所在目录执行：
```shell
$ docker build -t nginx:v3 .
Sending build context to Docker daemon 2.048 kB
Step 1 : FROM nginx
 ---> e43d811ce2f4
Step 2 : RUN echo '<h1>Hello, Docker!</h1>' > /usr/share/nginx/html/index.html
 ---> Running in 9cdc27646c7b
 ---> 44aa4490ce2c
Removing intermediate container 9cdc27646c7b
Successfully built 44aa4490ce2c
```
从命令的输出结果中，我们可以清晰的看到镜像的构建过程。在 Step 2 中，如同我们之前所说的那样，RUN 指令启动了一个容器 9cdc27646c7b，执行了所要求的命令，并最后提交了这一层 44aa4490ce2c，随后删除了所用到的这个容器 9cdc27646c7b。

这里我们使用了 docker build 命令进行镜像构建。其格式为：
```shell
docker build [选项] <上下文路径/URL/->
```
在这里我们指定了最终镜像的名称 -t nginx:v3，构建成功后，我们可以像之前运行 nginx:v2 那样来运行这个镜像，其结果会和 nginx:v2 一样。
### 6. Dockerfile 指令
dockerfile中的指令是我们构建docker image使用的脚本,通过dockerfile指令我们可以构建出各种各样的docker images.

- **COPY** 复制文件到docker镜像中
```shell
COPY a.html /home/a.html
```
- **ADD** 复制文件到docker镜像中,如果是url将会下载,如果是gz/zip等文件将会自动解压
```shell
ADD tomcat.war /apache-tomcat/webapps/
```

- **CMD** 容器启动命令
```shell
CMD ["catalina.sh","run"]
```
- **ENTRYPOINT** 入口点
```shell
ENTRYPOINT ["catalina.sh", "run"]
```
- **ENV** 设置环境变量
```shell
ENV tomcat_home /apache-tomcat
```
- **VOLUME** 定义匿名卷
```shell
VOLUME /db/test
```
- **EXPOSE** 暴露端口
```shell
EXPOSE 8080 8001
```
- **WORKDIR** 指定工作目录
```shell
WORKDIR /apache-tomcat/webapps/
```
- **USER** 指定当前用户
```shell
USER root
```
- **HEALTHCHECK** 健康检查(1.12+以上新功能)
```shell
HEALTHCHECK --interval=5s --timeout=3s CMD curl -fs http://localhost/ || exit 1
```

> 注意:
> 1.在Dockerfile中如果命令太长想换行,则可以使用"\"连接两行
> 2.在构建镜像中一定注意设置时区 ``` RUN echo "Asia/Shanghai" > /etc/timezone ```
> 3.Dockerfile中每一行可以理解为一层,最大127层.
> 4.cmd和entrypoint的区别在于 cmd只是运行,而entrypoint则是把这个容器作为这个命令来运行

### 7. 删除镜像
在docker中删除镜像通过以下命令删除
```shell
docker rmi [选项] <镜像1> [<镜像2> ...]
```
其中，<镜像> 可以是 镜像短 ID、镜像长 ID、镜像名 或者 镜像摘要。
*注意:docker rm 命令是删除容器，不要混淆。*
如果需要批量删除镜像,则使用以下命令即可:
```shell
docker rmi $(docker images -q)
```
这样即可删除所有镜像.
对于无镜像名称(none)的镜像的删除
```shell
docker rmi $(docker images -q -f dangling=true)
```

## 容器操作
启动容器有两种方式，一种是基于镜像新建一个容器并启动，另外一个是将在终止状态（stopped）的容器重新启动。

因为 Docker 的容器实在太轻量级了，很多时候用户都是随时删除和新创建容器。
####1.新建并启动
所需要的命令主要为 docker run。

例如，下面的命令输出一个 “Hello World”，之后终止容器。
```shell
docker run ubuntu:14.04 /bin/echo 'Hello world'
Hello world
```
这跟在本地直接执行 /bin/echo 'hello world' 几乎感觉不出任何区别。

下面的命令则启动一个 bash 终端，允许用户进行交互。
```shell
docker run -t -i ubuntu:14.04 /bin/bash
root@af8bae53bdd3:/#
```
其中，-t 选项让Docker分配一个终端并绑定到容器的标准输入上， -i 则让容器的标准输入保持打开。

在交互模式下，用户可以通过所创建的终端来输入命令，例如
```shell
root@af8bae53bdd3:/# pwd
/
root@af8bae53bdd3:/# ls
bin boot dev etc home lib lib64 media mnt opt proc root run sbin srv sys tmp usr var
```
当利用 docker run 来创建容器时，Docker 在后台运行的标准操作包括：

- 检查本地是否存在指定的镜像，不存在就从公有仓库下载
- 利用镜像创建并启动一个容器
- 分配一个文件系统，并在只读的镜像层外面挂载一层可读写层
- 从宿主主机配置的网桥接口中桥接一个虚拟接口到容器中去
- 从地址池配置一个 ip 地址给容器
- 执行用户指定的应用程序
- 执行完毕后容器被终止

#### 2.启动已终止容器
可以利用 docker start 命令，直接将一个已经终止的容器启动运行。
```shell
docker start 123555666(容器id)
```
#### 3.以守护模式运行容器
更多的时候我们不是直接让容器运行一次就完成使命,我们期望容器一直为我们提供服务,这个时候我们期望容器在后台一直运行(类似于java的gc线程守护模式),可以使用以下命令运行docker容器:
```shell
docker run -itd tomcat:8
```
#### 4.终止容器
```shell
docker stop 容器id
```
#### 5.进入容器
在使用容器的过程中,在测试阶段由于不方便确定容器内某些环境,需要进入容器进行观察确定,这个时候我们则需要使用docker命令进入容器
在docker中有几种进入容器的方式,但其他几种方式均不友好,这里介绍其中一种友好的方式进入容器
```shell
docker exec -it tomcat:8 /bin/bash
```
#### 6.删除容器

可以使用 docker rm 来删除一个处于终止状态的容器。 例如
```shell
docker rm 容器名称
容器名称
```
如果要删除一个运行中的容器，可以添加 -f 参数。Docker 会发送 SIGKILL 信号给容器。

#### 7.清理所有处于终止状态的容器

用 docker ps -a 命令可以查看所有已经创建的包括终止状态的容器，如果数量太多要一个个删除可能会很麻烦，用 
```shell
docker rm $(docker ps -a -q) 
```
可以全部清理掉。

*注意：这个命令其实会试图删除所有的包括还在运行中的容器，不过就像上面提过的 docker rm 默认并不会删除运行中的容器。

## docker镜像仓库

仓库（Repository）是集中存放镜像的地方。
一个容易混淆的概念是注册服务器（Registry）。实际上注册服务器是管理仓库的具体服务器，每个服务器上可以有多个仓库，而每个仓库下面有多个镜像。从这方面来说，仓库可以被认为是一个具体的项目或目录。例如对于仓库地址 dl.dockerpool.com/ubuntu 来说，dl.dockerpool.com 是注册服务器地址，ubuntu 是仓库名。

**大部分时候，并不需要严格区分这两者的概念。**
#### 1.官方仓库
**官方仓库这里不做过多介绍,但是内部镜像等绝对不能push到官方仓库中,这样会暴露内部代码到外部**

#### 2.私有仓库

有时候使用 Docker Hub这样的公共仓库可能不方便，用户可以创建一个本地仓库供私人使用。

docker-registry 是官方提供的工具，可以用于构建私有的镜像仓库。
```shell
docker run -d -p 5000:5000 registry
```
这将使用官方的 registry 镜像来启动本地的私有仓库。

#### 3.在私有仓库上传、下载、搜索镜像

创建好私有仓库之后，就可以使用 docker tag 来标记一个镜像，然后推送它到仓库，别的机器上就可以下载下来了。例如私有仓库地址为 10.130.0.159:5000.

先在本机查看已有的镜像。
```shell
docker images
```
```shell
REPOSITORY                        TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
ubuntu                            latest              ba5877dc9bec        6 weeks ago         192.7 MB
```
使用docker tag 将 ba58 这个镜像标记为 10.130.0.159:5000/test（格式为 **docker tag IMAGE[:TAG] [REGISTRYHOST/][USERNAME/]NAME[:TAG]**）。
```shell
docker tag ba58 10.130.0.159:5000/test
```
```shell
root ~ # docker images
```
```shell
REPOSITORY                        TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
ubuntu                            14.04               ba5877dc9bec        6 weeks ago         192.7 MB
ubuntu                            latest              ba5877dc9bec        6 weeks ago         192.7 MB
10.130.0.159:5000/test            latest              ba5877dc9bec        6 weeks ago         192.7 MB
```
使用 docker push 上传标记的镜像。
```shell
$ sudo docker push 10.130.0.159:5000/test
The push refers to a repository [10.130.0.159:5000/test] (len: 1)
Sending image list
Pushing repository 10.130.0.159:5000/test (1 tags)
Image 511136ea3c5a already pushed, skipping
Image 9bad880da3d2 already pushed, skipping
Image 25f11f5fb0cb already pushed, skipping
Image ebc34468f71d already pushed, skipping
Image 2318d26665ef already pushed, skipping
Image ba5877dc9bec already pushed, skipping
Pushing tag for rev [ba5877dc9bec] on {http://10.130.0.159:5000/v2/repositories/test/tags/latest}
```
好了 现在可以在其他docker宿主机上更新下这个镜像了
```shell
docker pull 10.130.0.159:5000/test
```
#### 4.镜像上传配置
在docker 1.12+以上版本,docker和registry的连接默认为https连接,需要我们配置镜像仓库为https,但是很多时候在内网环境中我们不需要https环境,那么在默认情况下,我们执行 docker push将会出现以下错误:
```shell
Error: Invalid registry endpoint https://10.130.0.159:5000/v1/: Get https://10.130.0.159:5000/v1/_ping: dial tcp 10.130.0.159:5000: connection refused. 
```
此时需要在/etc/docker/daemon.json中配置信任的registry
```json
{"registry-mirrors": ["http://084c78c9.m.daocloud.io"],"insecure-registries":["172.17.0.8:5000","10.130.0.159:5000","镜像中心地址:端口"] }
```
## 开放docker remote api
docker remote api为docker对外提供的API接口,我们所使用的命令行命令内部也是使用此接口进行实现和docker server进行通讯.
要开放docker remote api需要修改/etc/default/docker文件
```shell
DOCKER_OPTS="-H unix:///var/run/docker.sock -H tcp://0.0.0.0:5555"
```
注意:
在项目开发阶段,请开发人员自行创建虚拟机装载docker,开启remote api进行docker build,不建议直接使用自动部署服务器的远程api端口


