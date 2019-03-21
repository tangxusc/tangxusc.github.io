---
title: "golang日志库"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- golang
- logrus
tags:
- golang
- logrus
keywords:
- golang
- logrus
---

# golang 日志库

golang 标准库的日志框架非常简单，仅仅提供了 print，panic 和 fatal 三个函数对于更精细的日志级别、日志[文件分割](https://www.baidu.com/s?wd=%E6%96%87%E4%BB%B6%E5%88%86%E5%89%B2&tn=24004469_oem_dg&rsv_dl=gh_pl_sl_csd)以及日志分发等方面并没有提供支持。所以催生了很多第三方的日志库，但是在 golang 的世界里，没有一个日志库像 slf4j 那样在 Java 中具有绝对统治地位。golang 中，流行的日志框架包括 logrus、zap、zerolog、seelog 等。
logrus 是目前 Github 上 star 数量最多的日志库，目前 (2018.08，下同)star 数量为 8119，fork 数为 1031。logrus 功能强大，性能高效，而且具有高度灵活性，提供了自定义插件的功能。很多开源项目，如 docker，prometheus 等，都是用了 logrus 来记录其日志。
zap 是 [Uber](https://www.baidu.com/s?wd=Uber&tn=24004469_oem_dg&rsv_dl=gh_pl_sl_csd) 推出的一个快速、结构化的分级日志库。具有强大的 ad-hoc 分析功能，并且具有灵活的仪表盘。zap 目前在 GitHub 上的 star 数量约为 4.3k。
seelog 提供了灵活的异步调度、格式化和过滤功能。目前在 GitHub 上也有约 1.1k。

# logrus 特性

logrus 具有以下特性：

*   完全兼容 golang 标准库日志模块：logrus 拥有六种日志级别：debug、info、warn、error、fatal 和 panic，这是 golang 标准库日志模块的 API 的超集。如果您的项目使用标准库日志模块，完全可以以最低的代价迁移到 logrus 上。
*   可扩展的 Hook 机制：允许使用者通过 hook 的方式将日志分发到任意地方，如本地文件系统、标准输出、logstash、elasticsearch 或者 mq 等，或者通过 hook 定义日志内容和格式等。
*   可选的日志输出格式：logrus 内置了两种日志格式，`JSONFormatter`和`TextFormatter`，如果这两个格式不满足需求，可以自己动手实现接口`Formatter`，来定义自己的日志格式。
*   Field 机制：logrus 鼓励通过 Field 机制进行精细化的、结构化的日志记录，而不是通过冗长的消息来记录日志。
*   logrus 是一个可插拔的、结构化的日志框架。

# logrus 的使用

## 第一个示例

最简单的使用 logrus 的示例如下：

```
package main

import (
  log "github.com/sirupsen/logrus"
)

func main() {
  log.WithFields(log.Fields{
    "animal": "walrus",
  }).Info("A walrus appears")
}
```

上面代码执行后，标准输出上输出如下：

```
time="2018-08-11T15:42:22+08:00" level=info msg="A walrus appears" animal=walrus
```

logrus 与 golang 标准库日志模块完全兼容，因此您可以使用`log“github.com/sirupsen/logrus”`替换所有日志导入。
logrus 可以通过简单的配置，来定义输出、格式或者日志级别等。

```
package main

import (
    "os"
    log "github.com/sirupsen/logrus"
)

func init() {
    // 设置日志格式为json格式
    log.SetFormatter(&log.JSONFormatter{})

    // 设置将日志输出到标准输出（默认的输出为stderr，标准错误）
    // 日志消息输出可以是任意的io.writer类型
    log.SetOutput(os.Stdout)

    // 设置日志级别为warn以上
    log.SetLevel(log.WarnLevel)
}

func main() {
    log.WithFields(log.Fields{
        "animal": "walrus",
        "size":   10,
    }).Info("A group of walrus emerges from the ocean")

    log.WithFields(log.Fields{
        "omg":    true,
        "number": 122,
    }).Warn("The group's number increased tremendously!")

    log.WithFields(log.Fields{
        "omg":    true,
        "number": 100,
    }).Fatal("The ice breaks!")
}
```

## Logger

logger 是一种相对高级的用法, 对于一个大型项目, 往往需要一个全局的 logrus 实例，即`logger`对象来记录项目所有的日志。如：

```
package main

import (
    "github.com/sirupsen/logrus"
    "os"
)

// logrus提供了New()函数来创建一个logrus的实例。
// 项目中，可以创建任意数量的logrus实例。
var log = logrus.New()

func main() {
    // 为当前logrus实例设置消息的输出，同样地，
    // 可以设置logrus实例的输出到任意io.writer
    log.Out = os.Stdout

    // 为当前logrus实例设置消息输出格式为json格式。
    // 同样地，也可以单独为某个logrus实例设置日志级别和hook，这里不详细叙述。
    log.Formatter = &logrus.JSONFormatter{}

    log.WithFields(logrus.Fields{
        "animal": "walrus",
        "size":   10,
    }).Info("A group of walrus emerges from the ocean")
}

```

## Fields

前一章提到过，logrus 不推荐使用冗长的消息来记录运行信息，它推荐使用`Fields`来进行精细化的、结构化的信息记录。
例如下面的记录日志的方式：

```shell
log.Fatalf("Failed to send event %s to topic %s with key %d", event, topic, key)
```

在logrus中不太提倡，logrus鼓励使用以下方式替代之：

```go
log.WithFields(log.Fields{
  "event": event,
  "topic": topic,
  "key": key,
}).Fatal("Failed to send event")
```

前面的`WithFields` API 可以规范使用者按照其提倡的方式记录日志。但是`WithFields`依然是可选的，因为某些场景下，使用者确实只需要记录仪一条简单的消息。

通常，在一个应用中、或者应用的一部分中，都有一些固定的`Field`。比如在处理用户 http 请求时，上下文中，所有的日志都会有`request_id`和`user_ip`。为了避免每次记录日志都要使用`log.WithFields(log.Fields{"request_id": request_id, "user_ip": user_ip})`，我们可以创建一个`logrus.Entry`实例，为这个实例设置默认`Fields`，在上下文中使用这个`logrus.Entry`实例记录日志即可。

```
requestLogger := log.WithFields(log.Fields{"request_id": request_id, "user_ip": user_ip})
requestLogger.Info("something happened on that request") # will log request_id and user_ip
requestLogger.Warn("something not great happened")
```

## Hook

logrus 最令人心动的功能就是其可扩展的 HOOK 机制了，通过在初始化时为 logrus 添加 hook，logrus 可以实现各种扩展功能。

### Hook 接口

logrus 的 hook 接口定义如下，其原理是每此写入日志时拦截，修改 logrus.Entry。

```
// logrus在记录Levels()返回的日志级别的消息时会触发HOOK，
// 按照Fire方法定义的内容修改logrus.Entry。
type Hook interface {
    Levels() []Level
    Fire(*Entry) error
}
```

一个简单自定义 hook 如下，`DefaultFieldHook`定义会在所有级别的日志消息中加入默认字段`app`。

```
type DefaultFieldHook struct {
}

func (hook *DefaultFieldHook) Fire(entry *log.Entry) error {
    entry.Data["appName"] = "MyAppName"
    return nil
}

func (hook *DefaultFieldHook) Levels() []log.Level {
    return log.AllLevels
}
```

hook 的使用也很简单，在初始化前调用`log.AddHook(hook)`添加相应的`hook`即可。

logrus 官方仅仅内置了 syslog 的 [hook](https://github.com/sirupsen/logrus/tree/master/hooks/syslog)。
此外，但 Github 也有很多第三方的 hook 可供使用，文末将提供一些第三方 HOOK 的连接。

# 问题与解决方案

尽管 logrus 有诸多优点，但是为了灵活性和可扩展性，官方也削减了很多实用的功能，例如：

*   没有提供行号和文件名的支持
*   输出到本地文件系统没有提供日志分割功能
*   官方没有提供输出到 ELK 等日志处理中心的功能

但是这些功能都可以通过自定义 hook 来实现。

## 记录文件名和行号

logrus 的一个很致命的问题就是没有提供文件名和行号，这在大型项目中通过日志定位问题时有诸多不便。Github 上的 logrus 的 issue#63：[Log filename and line number](https://github.com/sirupsen/logrus/issues/63) 创建于 2014 年，四年过去了仍是 open 状态~~~
网上给出的解决方案分位两类，一就是自己实现一个 hook；二就是通过装饰器包装`logrus.Entry`。两种方案网上都有很多代码，但是大多无法正常工作。但总体来说，解决问题的思路都是对的：通过标准库的`runtime`模块获取运行时信息，并从中提取文件名，行号和调用函数名。

标准库`runtime`模块的`Caller(skip int)`函数可以返回当前 goroutine 调用栈中的文件名，行号，函数信息等，参数 skip 表示表示返回的栈帧的层次，0 表示`runtime.Caller`的调用着。返回值包括响应栈帧层次的 pc(程序计数器)，文件名和行号信息。为了提高效率，我们先通过跟踪调用栈发现，从`runtime.Caller()`的调用者开始，到记录日志的生成代码之间，大概有 8 到 11 层左右，所有我们在 hook 中循环第 8 到 11 层调用栈应该可以找到日志记录的生产代码。
![](https://img-blog.csdn.net/20180814170801498?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dzbHlrNjA2/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
此外，`runtime.FuncForPC(pc uintptr) *Func`可以返回指定`pc`的函数信息。
所有我们要实现的 hook 也是基于以上原理，使用`runtime.Caller()`依次循环调用栈的第 7~11 层，过滤掉`sirupsen`包内容，那么第一个非`siupsenr`包就认为是我们的生产代码了，并返回`pc`以便通过`runtime.FuncForPC()`获取函数名称。然后将文件名、行号和函数名组装为`source`字段塞到`logrus.Entry`中即可。

```
time="2018-08-11T19:10:15+08:00" level=warning msg="postgres_exporter is ready for scraping on 0.0.0.0:9295..." source="postgres_exporter/main.go:60:main()"
time="2018-08-11T19:10:17+08:00" level=error msg="!!!msb info not found" source="postgres/postgres_query.go:63:QueryPostgresInfo()"
time="2018-08-11T19:10:17+08:00" level=error msg="get postgres instances info failed, scrape metrics failed, error:msb env not found" source="collector/exporter.go:71:Scrape()"
```

## 日志本地文件分割

logrus 本身不带日志本地文件分割功能，但是我们可以通过`file-rotatelogs`进行日志本地文件分割。 每次当我们写入日志的时候，logrus 都会调用`file-rotatelogs`来判断日志是否要进行切分。关于本地日志文件分割的例子网上很多，这里不再详细介绍，奉上代码：

```
import (
    "github.com/lestrrat-go/file-rotatelogs"
    "github.com/rifflock/lfshook"
    log "github.com/sirupsen/logrus"
    "time"
)

func newLfsHook(logLevel *string, maxRemainCnt uint) log.Hook {
    writer, err := rotatelogs.New(
        logName+".%Y%m%d%H",
        // WithLinkName为最新的日志建立软连接，以方便随着找到当前日志文件
        rotatelogs.WithLinkName(logName),

        // WithRotationTime设置日志分割的时间，这里设置为一小时分割一次
        rotatelogs.WithRotationTime(time.Hour),

        // WithMaxAge和WithRotationCount二者只能设置一个，
        // WithMaxAge设置文件清理前的最长保存时间，
        // WithRotationCount设置文件清理前最多保存的个数。
        //rotatelogs.WithMaxAge(time.Hour*24),
        rotatelogs.WithRotationCount(maxRemainCnt),
    )

    if err != nil {
        log.Errorf("config local file system for logger error: %v", err)
    }

    level, ok := logLevels[*logLevel]

    if ok {
        log.SetLevel(level)
    } else {
        log.SetLevel(log.WarnLevel)
    }

    lfsHook := lfshook.NewHook(lfshook.WriterMap{
        log.DebugLevel: writer,
        log.InfoLevel:  writer,
        log.WarnLevel:  writer,
        log.ErrorLevel: writer,
        log.FatalLevel: writer,
        log.PanicLevel: writer,
    }, &log.TextFormatter{DisableColors: true})

    return lfsHook
}
```

使用上述本地日志文件切割的效果如下：
![](https://img-blog.csdn.net/20180814170847468?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dzbHlrNjA2/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

## 将日志发送到 elasticsearch

将日志发送到 elasticsearch 是很多日志监控系统的选择，将 logrus 日志发送到 elasticsearch 的原理是在 hook 的每次 fire 调用时，使用 golang 的 es 客户端将日志信息写到 elasticsearch。elasticsearch 官方没有提供 golang 客户端，但是有很多第三方的 [go 语言](https://www.baidu.com/s?wd=go%E8%AF%AD%E8%A8%80&tn=24004469_oem_dg&rsv_dl=gh_pl_sl_csd)客户端可供使用，我们选择 [elastic](https://github.com/olivere/elastic)。elastic 提供了丰富的[文档](https://godoc.org/gopkg.in/olivere/elastic.v5)，以及 Java 中的流式接口，使用起来非常方便。

```
client, err := elastic.NewClient(elastic.SetURL("http://localhost:9200"))
    if err != nil {
        log.Panic(err)
    }

// Index a tweet (using JSON serialization)
tweet1 := Tweet{User: "olivere", Message: "Take Five", Retweets: 0}
put1, err := client.Index().
    Index("twitter").
    Type("tweet").
    Id("1").
    BodyJson(tweet1).
    Do(context.Background())
```

考虑到 logrus 的 Fields 机制，可以实现如下数据格式：

```
msg := struct {
    Host      string
    Timestamp string `json:"@timestamp"`
    Message   string
    Data      logrus.Fields
    Level     string
}
```

其中`Host`记录产生日志主机信息，在创建 hook 是指定。其他数据需要从`logrus.Entry`中取得。测试过程我们选择按照此原理实现的第三方 HOOK：[elogrus](https://github.com/sohlich/elogrus)。其使用如下：

```
import (
    "github.com/olivere/elastic"
    "gopkg.in/sohlich/elogrus"
)

func initLog() {
    client, err := elastic.NewClient(elastic.SetURL("http://localhost:9200"))
    if err != nil {
        log.Panic(err)
    }
    hook, err := elogrus.NewElasticHook(client, "localhost", log.DebugLevel, "mylog")
    if err != nil {
        log.Panic(err)
    }
    log.AddHook(hook)
}
```

从 Elasticsearch 查询得到日志存储，效果如下：

```
GET http://localhost:9200/mylog/_search

HTTP/1.1 200 OK
content-type: application/json; charset=UTF-8
transfer-encoding: chunked

{
  "took": 1,
  "timed_out": false,
  "_shards": {
    "total": 5,
    "successful": 5,
    "failed": 0
  },
  "hits": {
    "total": 2474,
    "max_score": 1.0,
    "hits": [
      {
        "_index": "mylog",
        "_type": "log",
        "_id": "AWUw13jWnMZReb-jHQup",
        "_score": 1.0,
        "_source": {
          "Host": "localhost",
          "@timestamp": "2018-08-13T01:12:32.212818666Z",
          "Message": "!!!msb info not found",
          "Data": {},
          "Level": "ERROR"
        }
      },
      {
        "_index": "mylog",
        "_type": "log",
        "_id": "AWUw13jgnMZReb-jHQuq",
        "_score": 1.0,
        "_source": {
          "Host": "localhost",
          "@timestamp": "2018-08-13T01:12:32.223103348Z",
          "Message": "get postgres instances info failed, scrape metrics failed, error:msb env not found",
          "Data": {
            "source": "collector/exporter.go:71:Scrape()"
          },
          "Level": "ERROR"
        }
      },
      //...
      {
        "_index": "mylog",
        "_type": "log",
        "_id": "AWUw2f1enMZReb-jHQu_",
        "_score": 1.0,
        "_source": {
          "Host": "localhost",
          "@timestamp": "2018-08-13T01:15:17.212546892Z",
          "Message": "!!!msb info not found",
          "Data": {
            "source": "collector/exporter.go:71:Scrape()"
          },
          "Level": "ERROR"
        }
      },
      {
        "_index": "mylog",
        "_type": "log",
        "_id": "AWUw2NhmnMZReb-jHQu1",
        "_score": 1.0,
        "_source": {
          "Host": "localhost",
          "@timestamp": "2018-08-13T01:14:02.21276903Z",
          "Message": "!!!msb info not found",
          "Data": {},
          "Level": "ERROR"
        }
      }
    ]
  }
}

Response code: 200 (OK); Time: 16ms; Content length: 3039 bytes
```

## 将日志发送到其他位置

将日志发送到日志中心也是 logrus 所提倡的，虽然没有提供官方支持，但是目前 Github 上有很多第三方 hook 可供使用：

*   [logrus_amqp](https://github.com/vladoatanasov/logrus_amqp)：Logrus hook for Activemq。
*   [logrus-logstash-hook](https://github.com/bshuster-repo/logrus-logstash-hook):Logstash hook for logrus。
*   [mgorus](https://github.com/weekface/mgorus):Mongodb Hooks for Logrus。
*   [logrus_influxdb](https://github.com/abramovic/logrus_influxdb):InfluxDB Hook for Logrus。
*   [logrus-redis-hook](https://github.com/rogierlommers/logrus-redis-hook):Hook for Logrus which enables logging to RELK stack (Redis, Elasticsearch, Logstash and Kibana)。

等等，上述第三方 hook 我这里没有具体验证，大家可以根据需要自行尝试。

## 其他注意事项

### Fatal 处理

和很多日志框架一样，logrus 的`Fatal`系列函数会执行`os.Exit(1)`。但是 logrus 提供可以注册一个或多个`fatal handler`函数的接口`logrus.RegisterExitHandler(handler func() {} )`，让 logrus 在执行`os.Exit(1)`之前进行相应的处理。`fatal handler`可以在系统异常时调用一些资源释放 api 等，让应用正确的关闭。

### 线程安全

默认情况下，logrus 的 api 都是线程安全的，其内部通过互斥锁来保护并发写。互斥锁工作于调用 hooks 或者写日志的时候，如果不需要锁，可以调用`logger.SetNoLock()`来关闭之。可以关闭 logrus 互斥锁的情形包括：

*   没有设置 hook，或者所有的 hook 都是线程安全的实现。
*   写日志到`logger.Out`已经是线程安全的了，如`logger.Out`已经被锁保护，或者写文件时，文件是以`O_APPEND`方式打开的，并且每次写操作都小于 4k。