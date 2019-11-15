---
title: "使用Go处理每分钟百万请求"
date: 2019-11-15T09:15:59+08:00
draft: false
categories:
- golang
tags:
- golang
keywords:
- golang
---

这篇文章在medium上很火，作者以实际案例来分析，讲得很好。 

我们经常听说使用Go的goroutine和channel很容易实现高并发，那是不是全部代码都放在goroutine中运行就可以实现高并发程序了呢？很显然并不是。

这篇文章将教大家如何一步一步写出一个简单的， 高并发的Go程序。

<!--more-->

## 正文 

我在几家不同的公司从事反垃圾邮件，防病毒和反恶意软件的工作超过15年，现在我知道这些系统最终会因为我们要每天处理大量数据而变得越来越复杂。 

目前，我是`smsjunk.com`的CEO和 `KnowBe4`的首席架构师，他们都是网络安全行业的公司。 

有趣的是，在过去的10年里，作为一名软件工程师，我参与过的所有Web后端开发大部分都是使用`RubyonRails`完成的。

不要误会我的意思，我喜欢 `RubyonRails`，我相信这是一个了不起的生态，但是过了一段时间，你开始以 `Ruby`的方式思考和设计系统，忘了如何高效和原本可以利用多线程、并行、快速执行和小的内存消耗来简化软件架构。多年来，我是一名`C/C++`，`Delphi`和 `C＃`开发人员，而且我刚开始意识到如何正确的使用工具进行工作可能会有多复杂。 

> 我对互联网中那些语言和框架战争并不太感兴趣，比如哪门语言更好，哪个框架更快。
>
> 我始终相信效率，生产力和代码可维护性主要取决于如何简单的构建解决方案。

## 问题 

在处理我们的匿名监测和分析系统时，我们的目标是能够处理来自数百万端点的大量POST请求。

Web处理程序将收到一个JSON文档，该文档可能包含需要写入 `AmazonS3`的多个有效内容的集合，以便我们的 `map-reduce`系统稍后对这些数据进行操作。 

传统上，我们会考虑创建一个工作层架构，利用诸如以下的技术栈：

- Sidekiq 
- Resque 
- DelayedJob 
- ElasticbeanstalkWorkerTier 
- RabbitMQ 
- ... 

并搭建2个不同的集群，一个用于web前端，一个用于worker，因此我们可以随意扩容机器来处理即将到来的请求。 

从一开始，我们的团队就知道我们可以在Go中这样做，因为在讨论阶段我们看到这可能是一个非常大流量的系统。

我一直在使用Go，大约快2年时间了，而且我们也使用Go开发了一些系统，但是没有一个系统的流量能够达到这个数量级。

我们首先创建了几个struct来定义我们通过POST调用接收到的Web请求，并将其上传到S3存储中。 

```go
type PayloadCollection struct {
	WindowsVersion string    `json:"version"`
	Token          string    `json:"token"`
	Payloads       []Payload `json:"data"`
}
type Payload struct {
	// [redacted]
}

func (p *Payload) UploadToS3() error {
	// the storageFolder method ensures that there are no name collision in
	// case we get same timestamp in the key name
	storage_path := fmt.Sprintf("%v/%v", p.storageFolder, time.Now().UnixNano())
	bucket := S3Bucket
	b := new(bytes.Buffer)
	encodeErr := json.NewEncoder().Encode(payload)
	if encodeErr != nil {
		return encodeErr
	}
	// Everything we post to the S3 bucket should be marked 'private' 
	var acl = s3.Private
	var contentType = "application/octet-stream"
	return bucket.PutReader(storage_path, b, int64(b.Len()), contentType, acl, s3.Options{})
}
```



## Naive的做法-硬核使用Goroutine 

最初，我们对POST处理程序进行了非常简单粗暴的实现，将每个请求直接放到新的goroutine中运行： 

```go
func payloadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
	return

	// Read the body into a string for json decoding
	var content = &PayloadCollection{}
	err := json.NewDecoder(io.LimitReader(r.Body, MaxLength)).Decode(&content)
	if err != nil {
		w.Header().Set("Content-Type", "application/json; charset=UTF-8")
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	// Go through each payload and queue items individually to be posted to S3
	for _, payload := range content.Payloads {
		go payload.UploadToS3() // <----- DON'T DO THIS 
	}
	w.WriteHeader(http.StatusOK)
}
```

对于一般的并发量，这其实是可行的，但这很快就证明不能适用于高并发场景。我们可能有更多的请求，当我们将第一个版本部署到生产环境时，我们开始看到的数量级并不是如此，我们低估了并发量。 

上述的方法有几个问题。没有办法控制正在工作的goroutine的数量。

而且，由于我们每分钟有100万个POST请求，所以系统很快就崩溃了。 

## 重来 

我们需要找到另一种的方法。

从一开始我们就开始讨论如何让请求处理程序的生命周期尽可能的短，并在后台产生处理。

当然，这是在 `RubyonRails`必须要做的事情，否则，不管你是使用`puma`，`unicorn`还是 `passenger`，你的所有的可用的web worker都将阻塞。 

那么我们就需要利用常见的解决方案来完成这项工作，比如`Resque`，`Sidekiq`， `SQS`等。

当然还有其他工具，因为有很多方法可以实现。 

因此，我们第二次改进是创建一个`buffer channel`，我们可以将一些作业请求扔进队列并将它们上传到S3，由于我们可以控制队列的最大长度，并且有足够的RAM来排队处理内存中的作业，因此我们认为只要在通道队列中缓冲作业就行了。

```Go
var Queue chan Payload

func init() { 
    Queue = make(chan Payload, MAX_QUEUE) 
}
func payloadHandler(w http.ResponseWriter, r *http.Request) {
	//... 
	// Go through each payload and queue items individually to be posted to S3 
	for _, payload := range content.Payloads {
		Queue <- payload
	}
	//...
}
```

然后，为了将任务从`buffer channel`中取出并处理它们，我们正在使用这样的方式: 

```go
func StartProcessor() {
	for {
		select { 
            case job := <-Queue:
				job.payload.UploadToS3() // <-- STILL NOT GOOD
		}
	}
}
```

说实话，我不知道我们在想什么，这肯定是一个难熬的夜晚。

这种方法并没有给我们带来什么提升，我们用一个缓冲的队列替换了有缺陷的并发，也只是推迟了问题的产生时间而已。我们的同步处理器每次只向S3上传一个有效载荷，由于传入请求的速率远远大于单个处理器上传到S3的能力，因此我们的`buffer channel`迅速达到极限，队列已经阻塞并且无法再往里边添加作业。 

我们只是简单的绕过了这个问题，最终导致我们的系统完全崩溃。在我们部署这个有缺陷的版本后，我们的延迟持续的升高。 
<img src="https://static.studygolang.com/190702/5c22028acf4be6e55b2a35dd9cbd2469.png"/>

## 更好的解决方案 

我们决定在Go channel上使用一个通用模式来创建一个 `2-tier(双重)channel`系统，一个用来处理排队的job，一个用来控制有多少worker在 `JobQueue`上并发工作。 

这个想法是将上传到S3的并行速度提高到一个可持续的速度，同时不会造成机器瘫痪，也不会引发S3的连接错误。 所以我们选择创建一个 `Job/Worker`模式。

对于那些熟悉Java，C＃等的人来说，可以将其视为Golang使用channel来实现`WorkerThread-Pool`的方式。 

```go
var (
	MaxWorker = os.Getenv("MAX_WORKERS")
	MaxQueue  = os.Getenv("MAX_QUEUE")
)

// Job represents the job to be run 
type Job struct {
	Payload Payload
}

// A buffered channel that we can send work requests on. 
var JobQueue chan Job

// Worker represents the worker that executes the job 
type Worker struct {
	WorkerPool chan chan Job
	JobChannel chan Job
	quit       chan bool
}

func NewWorker(workerPool chan chan Job) Worker {
	return Worker{
        WorkerPool: workerPool, 
        JobChannel: make(chan Job), 
        quit: make(chan bool)
    }
}

// Start method starts the run loop for the worker, listening for a quit channel in 
// case we need to stop it 
func (w Worker) Start() {
	go func() {
		for {
			// register the current worker into the worker queue.
			w.WorkerPool <- w.JobChannel
			select {
			case job := <-w.JobChannel:
				// we have received a work request.
				if err := job.Payload.UploadToS3();
					err != nil {
					log.Errorf("Error uploading to S3: %s", err.Error())
				}
			case <-w.quit:
				// we have received a signal to stop return 
			}
		}
	}()
}

// Stop signals the worker to stop listening for work requests. 
func (w Worker) Stop() {
	go func() { 
        w.quit <- true 
    }()
}

```

我们修改了我们的Web请求处理程序以创建具有有效负载的Job struct，并将其发送到 `JobQueueChannel`以供worker处理。 

```go
func payloadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	// Read the body into a string for json decoding
	var content = &PayloadCollection{}
	err := json.NewDecoder(io.LimitReader(r.Body, MaxLength)).Decode(&content)
	if err != nil {
		w.Header().Set("Content-Type", "application/json; charset=UTF-8")
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	// Go through each payload and queue items individually to be posted to S3
	for _, payload := range content.Payloads {
		// let's create a job with the payload
		work := Job{
            Payload: payload
        }
		// Push the work onto the queue.
		JobQueue <- work
	}
	w.WriteHeader(http.StatusOK)
}
```



在我们的Web服务器初始化期间，我们创建一个`Dispatcher`并调用`Run()`来创建worker池并开始监听`JobQueue`中出现的Job。

```go
dispatcher := NewDispatcher(MaxWorker) 
dispatcher.Run()
```

以下是我们调度程序实现的代码：

```go
type Dispatcher struct {
	// A pool of workers channels that are registered with the dispatcher
	WorkerPool chan chan Job
}

func NewDispatcher(maxWorkers int) *Dispatcher {
	pool := make(chan chan Job, maxWorkers)
	return &Dispatcher{
        WorkerPool: pool
    }
}

func (d *Dispatcher) Run() {
	// starting n number of workers
	for i := 0; i < d.maxWorkers; i++ {
		worker := NewWorker(d.pool)
		worker.Start()
	}
	go d.dispatch()
}

func (d *Dispatcher) dispatch() {
	for {
		select { 
            case job := <-JobQueue:
				// a job request has been received 
                go func(job Job) {
                    // try to obtain a worker job channel that is available. 
                    // this will block until a worker is idle 
                    jobChannel := <-d.WorkerPool
                    // dispatch the job to the worker job channel 
                    jobChannel <- job
                }(job) 
        }
	}
}
```

请注意，我们实例化了最大数量的worker，并将其保存到worker池中（就是上面的 `WorkerPoolChannel`）。

由于我们已经将Amazon Elasticbeanstalk用于Docker化的Go项目，并且我们始终尝试遵循12要素方法来配置生产中的系统，因此我们从环境变量中读取这些值，这样我们就可以快速调整这些值以控制工作队列的数量和最大规模，而不需要重新部署集群。 

```go
var ( 
    MaxWorker = os.Getenv("MAX_WORKERS") 
    MaxQueue = os.Getenv("MAX_QUEUE") 
)
```

在我们发布了这个版本之后，我们立即看到我们的所有的请求延迟都下降到了一个很低的数字，我们处理请求的效率大大提升。 
<img src="https://static.studygolang.com/190702/7d891bd25c872babfd530af1b670caff.png"/>

在我们的弹性负载均衡器完全热身之后的几分钟，我们看到我们的ElasticBeanstalk应用程序每分钟提供近100万次请求。通常在早晨的几个小时里，流量高峰会超过每分钟100万个请求。 

我们部署了新的代码，服务器的数量从100台减少到大约20台。 

<img src="https://static.studygolang.com/190702/0a660804ea2a88524082ff68ca5c5bed.png"/>
在恰当地配置了集群和自动缩放设置以后，我们在生成环境用4台EC2 c4就能完成工作了。

如果CPU在连续5分钟内超过90%，弹性自动缩放系统就自动扩容一个新的实例。 
<img src="https://static.studygolang.com/190702/a94635e6edf7e0ee3e27797ceb5067f4.png"/>

## 结论 

简单总是我的制胜法宝。

我们可以设计一个拥有多队列，多后台进程和难以部署的复杂系统，但是相反我们决定利用Elasticbeanstalk的自动缩放和高效简单的方式去并发，Go语言很好的提供了这些功能。 

经验告诉我们，用最合适的工具去完成工作。有时，当你的 `RubyonRails`系统需要实现一个非常强大的处理程序时，可以考虑在 `Ruby`生态系统之外寻找更简单且更强大的替代解决方案。

**作者：MarcioCastilho** **原文：https://medium.com/smsjunk/handling-1-million-requests-per-minute-with-golang-f70ac505fcaa** 