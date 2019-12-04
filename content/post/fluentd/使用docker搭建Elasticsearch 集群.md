---
title: "使用docker搭建Elasticsearch集群"
date: 2019-12-04T14:15:59+08:00
draft: false
categories:
- es
tags:
- es
keywords:
- es
---

本文将使用docker搭建两个节点的Elasticsearch集群,并使用kibana做数据展示.

<!--more-->
# 参数介绍

Elasticsearch集群中的重要参数如下:
* `path.data`  and `path.logs`
* `cluster.name`
* `node.name`
* `bootstrap.memory_lock`
* `network.host`
* `discovery.zen.ping.unicast.hosts`
* `discovery.zen.minimum_master_nodes`
* `discovery.seed_hosts`
* `cluster.initial_master_nodes`
* `http.port ` and `transport.tcp.port`

## path.data and path.logs

在生产中使用，肯定要更改数据和日志文件夹的位置：

```yaml
path:
  logs: /var/log/elasticsearch
  data: /var/data/elasticsearch
```

 path.data  选项可以同时指定多个路径，所有的路径都会被用来存储数据（但所有属于同一个分片的文件，都会全部保存到同一个数据路径）

```yaml
path:
  data:
    - /mnt/elasticsearch_1
    - /mnt/elasticsearch_2
    - /mnt/elasticsearch_3
```

## cluster.name

某个节点只有和集群下的其他节点共享它的 cluster.name  才能加入一个集群。默认是 elasticsearch，但是应该修改为更恰当的，用于描述集群目的的名称。

```yaml
cluster.name: logging-prod
```

一定要确保不要在不同的环境中使用相同的集群名称。否则，节点可能会加入错误的集群中。

## cluster.name

默认情况下，Elasticsearch 将使用随机生成的 uuid 的前 7 个字符作为节点 id，请注意，节点 ID 是持久化的，并且在节点重新启动时不会更改，因此默认节点名称也不会更改。

推荐为节点配置更有意义的名称。

```yaml
node.name: prod-data-2
```

也可以使用服务器的 HOSTNAME  作为节点的名称。

```yaml
node.name: ${HOSTNAME}
```

## bootstrap.memory_lock

由于当 jvm 开始 swapping 时 es 的效率会降低，所以要保证它不 swap，这对节点健康极其重要。实现这一目标的一种方法是将 bootstrap.memory_lock 设置为`true`。

要使此设置有效，首先需要配置其他系统设置。有关如何正确设置内存锁定的更多详细信息，请参阅[启用`bootstrap.memory_lock`](https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-configuration-memory.html#mlockall "启用bootstrap.memory_lock")。

## network.host

默认情况下，Elasticsearch 仅仅绑定回环地址，比如`127.0.0.1` 和`[::1] `。这足以在服务器上运行单个开发节点。

事实上，一台机器上可以启动多个节点。这可对于测试 Elasticsearch 集群的能力很有用，但不推荐用于生产。

为了与其他服务器上的节点进行通信并形成集群，你的节点将需要绑定到非环回地址。虽然这里有很多[网络相关的配置](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-network.html)，但通常只需要配置一下 network.host 

```yaml
network.host: 192.168.1.10
```

 network.host 设置一些特殊值也是可以的，比如 _local_, _site_, _global_ ，ip4,ip6。更多详情请参考 [“Special values for `network.host`](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-network.html#network-interface-values "Special values for network.hostedit")”.

一旦自定义设置了 network.host ，Elasticsearch 会假定你正在从开发模式转移到生产模式，并将许多系统启动检查从警告升级到异常。有关详细信息，请参阅 [“](https://www.elastic.co/guide/en/elasticsearch/reference/current/system-config.html#dev-vs-prod "开发模式与生产模式")[Development mode vs production mode](https://www.elastic.co/guide/en/elasticsearch/reference/current/system-config.html#dev-vs-prod "Development mode vs production modeedit")”。

## discovery.zen.ping.unicast.hosts

开箱即用，没有任何网络配置情况下，Elasticsearch 将绑定到可用的回环地址，并会扫描端口 9300 至 9305 以尝试连接到同一服务器上运行的其他节点。这提供了一个自动集群体验，而无需执行任何配置。

如果想和其他服务器的节点形成一个集群，你必须提供集群中其它节点的列表。可以通过以下方式指定：

``` yaml
discovery.zen.ping.unicast.hosts:
   - 192.168.1.10:9300
   - 192.168.1.11 
   - seeds.mydomain.com 
```

如果没有指定端口，将默认为 transport.profiles.default.port 并回退 transport.tcp.port 。

如果输入的是主机名，被解析成多个地址，将会尝试连接所有地址。

## discovery.zen.minimum_master_nodes

为了防止数据丢失， discovery.zen.minimum_master_nodes 配置至关重要， 以便每个候选主节点知道为了形成集群而必须可见的_最少数量的候选主节点_。

没有这种设置，遇到网络故障的群集有可能将群集分成两个独立的群集（脑裂）， 这将导致数据丢失。更详细的解释在 [“](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html#split-brain "避免使用minimum_master_nodesedit分裂脑")[Avoiding split brain with `minimum_master_nodes`](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html#split-brain "Avoiding split brain with minimum_master_nodesedit") ” 中提供。

为了避免脑裂，候选主节点的数量应该设置为：

``` shell
(master_eligible_nodes / 2) + 1
```

换句话说，如果现在有 3 个节点，最小候选主节点数应该是`（3/2)+1=2`:

``` shell
discovery.zen.minimum_master_nodes: 2
```

## discovery.seed_hosts

默认情况下，集群形成模块提供了两个种子主机提供程序来配置种子节点列表：

- 基于设置
- 基于文件

的种子主机提供程序。

它可以通过[发现插件](https://www.elastic.co/guide/en/elasticsearch/plugins/7.5/discovery.html)扩展为支持云环境和其他形式的种子宿主提供程序。

使用该`discovery.seed_providers` 设置配置种子主机提供程序，该设置默认为基于*设置*的主机提供程序。

此设置接受不同提供程序的列表，使您可以使用多种方法来查找集群的种子主机。

每个种子主机提供程序都会产生种子节点的IP地址或主机名。

如果返回任何主机名，则使用DNS查找将其解析为IP地址。如果主机名解析为多个IP地址，则Elasticsearch会尝试在所有这些地址处找到一个种子节点。

如果主机提供商在此之前未显式提供节点的TCP端口，它将隐式使用`transport.profiles.default.port`或或 `transport.port`if `transport.profiles.default.port`设置的端口范围内的第一个端口。

并发查找的数量由`discovery.seed_resolver.max_concurrent_resolvers`默认值控制 `10`，每次查找的超时由`discovery.seed_resolver.timeout` 默认值控制`5s`。

请注意，DNS查找受[JVM DNS缓存的](https://www.elastic.co/guide/en/elasticsearch/reference/7.5/networkaddress-cache-ttl.html)约束 。

```yaml
discovery.seed_hosts:
   - 192.168.1.10:9300
   - 192.168.1.11 
   - seeds.mydomain.com 
```

## cluster.initial_master_nodes

可作为master节点初始的节点名称,在es初始化时,可以选举为master的node名称

```yaml
cluster.initial_master_nodes:
  - "node1"
  - "node2"
  - "node3"
```

## http.port and transport.tcp.port

`http.port`设置当前节点占用的端口号，默认9200

`transport.tcp.port`设置集群节点发现的端口

# 启动示例

在此启动一个示例的集群,集群中有两个节点(`es1,es2`)

并启动一个kibana连接集群

## 准备 

修改`/etc/sysctl.conf`,在文件末尾加入:

```shell
vm.max_map_count=262144
```

## 启动集群

```shell
docker run -d --name es --net es -p 9200:9200 -p 9300:9300 -e "cluster.name=docker-cluster" --hostname "es1" -e "cluster.initial_master_nodes="es1"  elasticsearch:7.4.2

docker run -d --name es2 --net es --link es:es1 -e "cluster.name=docker-cluster" --hostname "es2" -e "discovery.zen.ping.unicast.hosts=es1"  elasticsearch:7.4.2

docker run -d --name kibana --link es:elasticsearch --net es -p 5601:5601 kibana:7.4.2
```

## 注意

**因为启动了kibana,所以不需要再安装`head` 等插件了.**



## 参照

[https://github.com/13428282016/elasticsearch-CN/wiki/es-setup--elasticsearch](https://github.com/13428282016/elasticsearch-CN/wiki/es-setup--elasticsearch)

[ElasticSearch 入门 第二篇：集群配置](http://www.cnblogs.com/ljhdo/p/4959412.html)

[discovery](https://www.elastic.co/guide/en/elasticsearch/reference/7.5/modules-discovery-hosts-providers.html)