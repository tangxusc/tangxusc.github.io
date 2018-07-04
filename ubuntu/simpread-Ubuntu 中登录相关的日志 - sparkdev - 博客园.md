> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://www.cnblogs.com/sparkdev/p/7694202.html

# [Ubuntu 中登录相关的日志](https://www.cnblogs.com/sparkdev/p/7694202.html)

登录相关的日志涉及到系统的安全，所以是系统管理中非常重要的一部分内容。本文试图对登录相关的日志做一个整理。

# /var/log/auth.log

这是一个文本文件，记录了所有和用户认证相关的日志。无论是我们通过 ssh 登录，还是通过 sudo 执行命令都会在 auth.log 中产生记录。执行

<pre>$ ssh nick@myserver</pre>

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019184236006-135946666.png)

上图显示日志记录了通过秘钥认证的方式登录主机并退出的过程。

再执行下面的命令试试：

<pre>$ sudo vim /etc/passwd</pre>

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019184325349-1758988378.png)

日志同样会详细的记录本次 sudo 操作的过程。从中我们可以看到是哪个用户通过 sudo 执行了什么命令！

# /var/run/utmp

这是一个二进制文件，所以不能直接通过文本编辑器查看其内容。
它记录当前登录的每个用户的信息。因此这个文件会随着用户登录和注销系统而不断变化，它只保留当时联机的用户记录，不会为用户保留永久的记录。系统中需要查询当前用户状态的程序，如 who、w、users 等就需要访问这个文件。

# /var/log/wtmp

这是一个二进制文件，所以不能直接通过文本编辑器查看其内容。
该日志文件永久记录每个用户登录、注销及系统的启动、停机的事件。因此随着系统正常运行时间的增加，该文件的大小也会越来越大，增加的速度取决于系统用户登录的次数。该日志文件可以用来查看用户的登录记录，last 命令就通过访问这个文件获得这些信息。

# /var/log/btmp

这是一个二进制文件，所以不能直接通过文本编辑器查看其内容。
这个文件记录的是所有失败的登录尝试，使用 last 命令及其 -f 选项可以查看这个文件的内容：

<pre>$ sudo last -f /var/log/btmp</pre>

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019184638896-356181046.png)

# /var/log/lastlog

这是一个二进制文件，所以不能直接通过文本编辑器查看其内容。
它会记录系统中所有用户最近一次登陆的信息。比如我们通过 ssh 登录时提示的此用户最后一次的登录时间，就是从这个文件中取出的：

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019184723693-1877670689.png)

其实这个文件的主要使用者是 lastlog 命令。

特别是 /var/run/utmp、/var/log/wtmp 和 /var/log/lastlog 这三个文件，它们都是日志系统中的关键文件，并且具有如下的逻辑联系：
当一个用户登录系统时，login 程序在 lastlog 文件中查看用户的 UID。如果该用户存在，就把该用户上次登录、注销的时间以及从哪个主机登录的信息写到标准输出中。然后 login 程序在 lastlog 中记录新的登录时间，并打开 utmp 文件添加用户本次的登录记录。接下来，login 程序打开 wtmp 文件并添加用户在 utmp 文件中的记录。当用户退出时会把更新的 utmp 文件中的记录添加到 wtmp 文件中，并从 utmp 文件中删除用户的记录。

我们可以看到除了 auth.log 文件，其它几个文件都是二进制文件，因而不能使用 less 之类的命令直接查看。下面我们来介绍和登录相关的一些命令，其实它们几乎都是通过查询这些日志文件来提供信息的。

# lastlog 命令

lastlog 命令用来显示系统中所有用户最近一次登陆的信息：

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019184908615-825712918.png)

图中显示的只是完整列表的一部分，**Never logged in** 表示该用户从来没有登陆过。如果要查看某个用户的最后登陆信息，可使用 -u 选项：

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019185056099-1399081424.png)

其实 lastlog 命令就是从 /var/log/lastlog 文件中取出的内容。

# last 命令

last 命令用来显示用户最近登录的信息。执行 last 命令，它会读取 /var/log/wtmp 文件的内容。并把该文件记录的用户登录历史全部显示出来：

<pre>$ last</pre>

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019185144693-420680731.png)

信息记录了谁在什么时间从哪里登录了服务器，登录了多长时间。需要注意的是系统中的 wtmp 日志文件经常会被轮转，所以有时你需要显式的指定 last 命令从哪个文件中读取信息：

<pre>$ last -f /var/log/wtmp.1</pre>

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019185213037-374406928.png)

如果我们想快速知道系统最后一次的重启时间，可以使用下面的命令：

<pre>$ last reboot</pre>

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019185242381-62203389.png)

# who 命令

who 命令通过查询 /var/run/utmp 文件来显式系统中当前登录的每个用户。默认的输出包括用户名、终端类型、登录日期及远程主机：

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019185319506-196798027.png)

# w 命令

如果能够查询到当前登录系统的用户都在干什么是不是一件令人很兴奋的事情呢！使用 w 命令就可以做到：

<pre>$ w</pre>

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019185352787-179540294.png)

我们可以看到用户 nick 同时登录了两个终端，在其中一个终端中执行了 w 命令，而在另一个终端中正通过 vim 编辑  /etc/passwd 文件！
其实 w 命令是先通过查询 utmp 文件获得当前登录的用户，然后显示每个用户和它所运行的进程信息。

# users 命令

users 命令用单独的一行打印出当前登录的用户，每个显示的用户名对应一个登录会话。如果一个用户有不止一个登录会话，那他的用户名将显示多次：

![](https://images2017.cnblogs.com/blog/952033/201710/952033-20171019185456177-339635231.png)

因为 nick 通过三个终端登录了主机，所以在同一行中名字出现了三次。

# 总结

本文整理了 Ubuntu 系统中常见的一些与登录相关的文件和命令。通过它们可以快速的查看当前用户的登录情况和所有用户登录登出的历史记录，并且可以查询到用户使用 root 权限执行的操作。这对我们维护系统的安全和用户的管理都非常有帮助。

作者：[sparkdev](http://www.cnblogs.com/sparkdev/) 出处：[http://www.cnblogs.com/sparkdev/](http://www.cnblogs.com/sparkdev/) 本文版权归作者和博客园共有，欢迎转载，但未经作者同意必须保留此段声明，且在文章页面明显位置给出原文连接，否则保留追究法律责任的权利。 分类: [Linux](http://www.cnblogs.com/sparkdev/category/834899.html) 标签: [ubuntu](http://www.cnblogs.com/sparkdev/tag/ubuntu/), [log](http://www.cnblogs.com/sparkdev/tag/log/) [好文要顶](javascript:void(0);) [关注我](javascript:void(0);) [收藏该文](javascript:void(0);) [![](https://common.cnblogs.com/images/icon_weibo_24.png)](javascript:void(0); "分享至新浪微博") [![](https://common.cnblogs.com/images/wechat.png)](javascript:void(0); "分享至微信") [![](https://pic.cnblogs.com/face/952033/20160916141655.png)](http://home.cnblogs.com/u/sparkdev/) [sparkdev](http://home.cnblogs.com/u/sparkdev/)
[关注 - 22](http://home.cnblogs.com/u/sparkdev/followees)
[粉丝 - 321](http://home.cnblogs.com/u/sparkdev/followers) 荣誉：[推荐博客](http://www.cnblogs.com/expert/) [+ 加关注](javascript:void(0);) 7 0 <script type="text/javascript">currentDiggType = 0;</script> [«](http://www.cnblogs.com/sparkdev/p/7666889.html) 上一篇：[Bash : test 命令](http://www.cnblogs.com/sparkdev/p/7666889.html "发布于2017-10-16 08:41")
[»](http://www.cnblogs.com/sparkdev/p/7725965.html) 下一篇：[Azure 基础：使用 powershell 创建虚拟机](http://www.cnblogs.com/sparkdev/p/7725965.html "发布于2017-10-26 11:35")
posted @ 2017-10-20 09:36 [sparkdev](http://www.cnblogs.com/sparkdev/) 阅读 (10278) 评论 (4) [编辑](https://i.cnblogs.com/EditPosts.aspx?postid=7694202) [收藏](#)