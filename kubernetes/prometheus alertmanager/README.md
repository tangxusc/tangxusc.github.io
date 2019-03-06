# prometheus和alertmanager监控并发送邮件

## prometheus

### 简介

prometheus是时序的监控系统,通常使用prometheus是将prometheus当做采集存储中间件来使用,配合grafana做图表展示,配合alertmanager做自定义告警.

prometheus的每个样本的大小为1-2个字节,要评估服务器的容量,可以使用以下公式:

```shell
needed_disk_space = retention_time_seconds * ingested_samples_per_second * bytes_per_sample
需要的硬盘空间 = 数据保留时间(s) * 每秒采集的样本 * 样本大小
```

### 数据类型

在系统中所有的数据都以指标的方式来标示,指标包含label,指标格式如下:

```shell
<metric name>{<label name>=<label value>, ...}
##例如
api_http_requests_total{method="POST", handler="/messages"}
```

在系统中,所有指标都在采集时得到其数据类型和描述,通常如下:

```shell
$ curl localhost:9090/metrics
# HELP go_gc_duration_seconds A summary of the GC invocation durations.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 2.9632e-05
go_gc_duration_seconds{quantile="0.25"} 4.7174e-05
go_gc_duration_seconds{quantile="0.5"} 5.8693e-05
go_gc_duration_seconds{quantile="0.75"} 9.4042e-05
go_gc_duration_seconds{quantile="1"} 0.021392614
go_gc_duration_seconds_sum 0.056610034
go_gc_duration_seconds_count 70
# HELP go_goroutines Number of goroutines that currently exist.
# TYPE go_goroutines gauge
go_goroutines 38
```

格式为:

```shell
HELP <指标名称> <描述>
TYPE <指标名称> <数据类型>
```

prometheus支持以下4种指标类型


1. Counter 计数器

   只增加不减少,建议以total为后缀

2. Gauge

   仪表盘指标,可增加,可减少,反应当前系统状态,例如内存当前使用多少

3. Histogram 

   直方图,反应数据分布,在服务器计算,内涵:

   区间计数器 <basename>_bucket{le="xxx"}_

   总和计数器 <basename>_sum

   总事件数量计数器 <basename>_count

4. Summary

   摘要统计,在客户端计算,内涵:

   数据区间统计 <basename>{quantile="<φ>"}

   总数统计 <basename>_sum

   总事件数量统计 <basename>_count

### 工作和实例

在prometheus中,可以抓取的端点称为实例,抓起的这个job称为作业,例如:

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
```

此配置标示 有一个作业,名称为 prometheus,有一个目标实例 localhost:9090(其实也就是自身)

在配置了实例后,prometheus会为实例自动生成4个指标:

```shell
# 1 标示成功抓取,0标示失败
up{job="<job-name>", instance="<instance-id>"}

# 每次抓取执行的时间
scrape_duration_seconds{job="<job-name>", instance="<instance-id>"}

#relabeling后剩余的标签
scrape_samples_post_metric_relabeling{job="<job-name>", instance="<instance-id>"}

#实例暴露的样本数量
scrape_samples_scraped{job="<job-name>", instance="<instance-id>"}
```

### PromQL

指标分为4种,分别为:

- 即时向量 例如:`up,标示当前状态`
- 范围向量 例如: `up{}[2m],标示2分钟内的up的值`
- 标量  例如:  `1,2,3`
- string 例如: `"abc"`

PromQL分为三个总要的组成部分:

- 操作符

  - 数学运算 

    `+ , - , * , / ,% ,^ `

  - 布尔运算

    `== , != , > , < , >= , <= `

  - bool修饰符

    `http_requests_total > bool 1000`

  - 集合运算

    `and , or , unless `

  - 匹配模式

    ```
    <vector expr> <bin-op> ignoring(<label list>) <vector expr>
    <vector expr> <bin-op> on(<label list>) <vector expr>
    ```

  - 多对多

    ```shell
    <vector expr> <bin-op> ignoring(<label list>) group_left(<label list>) <vector expr>
    <vector expr> <bin-op> ignoring(<label list>) group_right(<label list>) <vector expr>
    <vector expr> <bin-op> on(<label list>) group_left(<label list>) <vector expr>
    <vector expr> <bin-op> on(<label list>) group_right(<label list>) <vector expr>
    
    method_code:http_errors:rate5m / ignoring(code) group_left method:http_requests:rate5m
    ```

- 聚合操作

  聚合操作主要是聚合函数的使用,操作的语法如下:

  ```shell
  <aggr-op>([parameter,] <vector expression>) [without|by (<label list>)]
  #例如
  sum(http_requests_total) without (instance)
  ```

  其中without标示: 从计算结果中删除标签

  by 则标示,只保留列出的标签

  聚合操作的目的是为了聚合所有标签的维度,排除一些维度

- 内置函数

  这个就很多了,需要自行探索 [函数参考](https://prometheus.io/docs/prometheus/latest/querying/functions/)

### 下载和安装

下载地址为:  [prometheus 下载](https://prometheus.io/download/) , 解压后就可以得到prometheus的二进制文件,解压后的目录如下:

```shell
.
├── console_libraries
│   ├── menu.lib
│   └── prom.lib
├── consoles
│   ├── index.html.example
│   ├── node-cpu.html
│   ├── node-disk.html
│   ├── node.html
│   ├── node-overview.html
│   ├── prometheus.html
│   └── prometheus-overview.html
├── LICENSE
├── NOTICE
├── prometheus #prometheus运行的二进制文件
├── prometheus.yml #prometheus的最小配置文件
└── promtool #配置检查工具
```

查看`prometheus.yml`,其中已经配置了prometheus自身的监控

```yaml
# my global config
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
#       - localhost:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
   - "first_rule.yml"
   - "alert_rule.yaml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
    - targets: ['localhost:9090']
```

详细的配置文件格式,请参考: [prometheus配置](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)

在配置中,我们看到有一个作业,有一个采集实例,localhost:9090,默认的路径为/metrics

### 启动和测试

在我们修改配置文件后,不建议直接放在服务器中启动进行验证,而是采用自带的`promtool` 对配置进行验证后再放到具体的server上启动服务,这样可以减少我们消耗在修改文件和启动后验证的时间.

```shell
$ ./promtool check config prometheus.yml 
Checking prometheus.yml
  SUCCESS: 2 rule files found
Checking first_rule.yml
  SUCCESS: 1 rules found
Checking alert_rule.yaml
  SUCCESS: 1 rules found
```

在我们运行后,会递归的检查我们的配置文件中的错误,包括引用的rule和template,检查后会打印出概要结果.

在检查配置文件么有问题后,现在我们来启动我们的服务.

```shell
$ ./prometheus --config.file=prometheus.yml --storage.tsdb.path=/home/tangxu/server/prometheus-2.7.2.linux-amd64/data/ --web.enable-lifecycle
```

其中 

`--web.enable-lifecycle`标示启用`/-/reload`端点用于重新加载配置文件 

> reload 需要使用post提交

`--config.file` 指定配置文件位置

`--storage.tsdb.path`指定tsdb存储路径(tsdb为prometheus存储库)

其他参数使用`./prometheus --help` 可以查看.

### 使用

简单介绍几个api,便于使用.

`localhost:9090` 首页 (会自动导航到`/graph`)

`localhost:9090/api/v1/query?query=up{}[2m]` 使用查询,获取json结果

`localhost:9090/alerts` 显示警告rules

### 定义告警rules

在目录下新建文件 `alert_rule.yaml`

```yaml
groups:
  - name: "test-alert"
    rules:
    - alert: downInstance
      expr: up == 1 #触发告警的表达式
      for: 5m #标示持续5分钟后 发送警报
      labels:
        nodeDown: true
      annotations: #可以使用golang的模板
        test: "{{$value}},{{$labels.nodeDown}},{{$labels.instance}}"
```

> 详细语法可参考: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/

在 `prometheus.yml`中添加警告rule

```yaml
global:
  scrape_interval:     15s
  evaluation_interval: 15s
alerting:
  alertmanagers:
  - static_configs:
    - targets:
#       - localhost:9093
# 在此添加...
rule_files:
   - "alert_rule.yaml"
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
```

编辑好配置文件后,使用post reload重新加载文件

```shell
$ curl -X POST localhost:9090/-/reload
```

完成后就可以在`/alert`上看到alert规则了,再等待一点时间就可以看到alert上会有警报产生

警报产生后是` pending`状态,需要等待5m后才会转换为`firing`状态,标示已发送

> 这里for 持续时间是排除敏感范围

## alertmanager

alertmanager是prometheus的体系中专门用来进行警告发送处理的组件.

通常高可用方式是填写3个以上的alertmanager地址,并且alertmanager部署时,使用互相注册的方式,具体如下:

```shell
./alertmanager --cluster.listen-address=172.18.23.253:9094 --cluster.peer=172.18.23.253:9094 --cluster.peer=172.18.23.252:9094 --cluster.peer=172.18.23.251:9094 --config.file=alertmanager.yml
```

在alertmanager中:

`9093`: 服务地址	`9094`: 集群通信地址

### 工具

alertmanager也提供了验证配置的工具`amtool`,用法于`promtool`基本一致,例如:

```shell
./amtool check-config alertmanager-2.yml 
```



定义告警和通知

alertmanager使用类似prometheus的配置来定义,一个典型的示例如下:

```yaml
global:
  #声明警告被解决的时间,如果警报没有再次发送
  resolve_timeout: 5m 
  #smtp配置
  smtp_from: "562050688@qq.com"
  smtp_smarthost: "smtp.qq.com:587"
  smtp_auth_username: "562050688@qq.com"
  smtp_auth_password: "你来打我"

#路由是根据顶级路由从上之下路由,可以通过match和match_re进行匹配
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email'
#  routers:
#   - receiver: 'sub1'
receivers:
- name: 'email'
  email_configs:
    - to: "562050688@qq.com"
#当目标标签匹配severity: 'warning'并且,源标签匹配severity: 'critical',并且'alertname', 'dev', 'instance'三个标签的值相等时,抑制警告发送
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
```

> 详细的配置请参考: https://prometheus.io/docs/alerting/configuration/

### 启动alertmanager,并接收警告

```shell
$ ./alertmanager --config.file=alertmanager.yml --log.level=debug
```

alertmanager运行在9093端口

在alertmanager的web端中可以配置silences(沉默)

等待一会就可以在邮件系统中看到自己配置的警告了.

![](alertmanager-alert.png)





