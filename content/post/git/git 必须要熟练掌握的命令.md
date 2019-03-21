---
title: "git 必须要熟练掌握的命令"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- git
tags:
- git
keywords:
- git
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://segmentfault.com/a/1190000013241889

因为结合了开发中可能遇到的场景，篇幅较长，不过我觉得很有助于你理解 git 的运作机制，而不是死记硬背命令。

HEAD 指针 始终指向的是当前分支的最新版本号，HEAD^, HEAD^^, ^ 的个数 n 或 HEAD~n，n 代表前 n 个版本号。

在项目中直接使用 linux rm 只会删除工作区的文件，git rm 同在删除工作区文件的同时删除 stage 中的，或使用 git rm --cached 只删除 stage 中的。

一些基本的操作

```
#全局配置
git config --global user.name "your username"
git config --global user.email youremail@email.com
git config --global color.ui true

#
mkdir git_proj & cd git_proj
git init
echo "# readme.md" >> README.md
git add README.md
git commit -m "readme commit"
# 添加远程仓库 并给它取个别名 origin
git remote add origin git@github.com:username/repositoryName.git
# 将本地仓库推送至 origin 的 master 分支并与此分支关联（-u 的作用，后期不必在使用）
git push -u origin master

# 从远程仓库 origin 的 master 分支获取最新源码并下载到 tmp 分支
git fetch origin master:tmp
# 比对 tmp 分支于 master 分支做了哪些改动
git diff master tmp
# 合并 tmp 分支到 master 分支
git merge tmp

# clone copy 一个完整的远端仓库到本地
git clone git@github.com:username/repositoryName.git

# pull 获取 origin 的 master 分支并直接和当前分支合并
# 所以可能会发生冲突
git pull origin master

```

## checkout

checkout 命令有两个主要作用：切换分支 和 回滚文件到当前的 stage 版本 或 repository 版本
1、切换分支

```
# 切换到 new_branch 分支
git checkout new_branch
# 创建并切换到 new_branch 分支
git checkout -b new_branch
```

2、回滚工作区的文件到最新 stage 版本 或 repository 版本，即从 stage 或 repository 中检出最新版本

```
# -- 是文件标示符 表名后面的参数为文件 避免产生切换 branch 的歧义
git checkout -- <filename>

```

回滚时会先检查 stage 中是否有对应的文件，如果没有才会使用 repository 中最新的版本。而当对某文件进行了多次修改和 add 操作后，使用 checkout 我们只能将文件回滚到最新一次的 add 的版本。
但在某些场景下我们可能想回滚到 repository 中的最新版本，怎么做呢？配合 reset 命令的可以很容易做到。
先给出命令：

```
git reset HEAD <filename> & git checkout -- <filename>

```

这样就可以将工作区的 filename 回滚到 repository 中的最新版本了。具体原理我们将在实例中详细的讲解。

## reset

git 的 reset 命令比较绕，需要耐心的理解。简单来说，reset 有三种重置级别，我们需要准确理解每个级别的作用。

soft：回退版本号。作用于 repository

mixed：回退版本号，重置 stage。作用于 repository 和 stage

hard ：回退版本号，重置 stage，重置工作区源码。作用于 repository，stage 和 workspace

我们简单展示下 repository 的版本号，我们以此为 demo 分别尝试三个级别的 reset

```
git log

version D (HEAD) <-- HEAD指针
version C (HEAD^)
version B (HEAD^^)
version A (HEAD~3)

```

命令格式：

```
git reset [--soft|--mixed|--hard] version_no <filename>

```

--soft：只是单纯的移动 repository 的 HEAD 指针 到制定版本号。stage 和工作区没有任何变化。

```
# 将 HEAD 指针回滚至上一版本 使用 git log 你会发现提交日志退回到了上一版本号
git reset --soft HEAD^
#版本号现状
version C <-- HEAD指针
version B
version A

```

* * *

--mixed：默认选项，移动 repository 的 HEAD 指针 到指定版本号，同时用此版本重置 stage 区，所以可能会让工作区的某些文件处于 unstage 状态（当工作区的文件与 repository 中的版本不一致时）。注意，这里是可以指定文件的。soft 本身和文件无关，hard 则是不能单独指定文件，只能全部重置。

```
# HEAD指针 还是指向 HEAD 
git reset HEAD^2 <filename>
#版本号现状
version B <-- HEAD指针
version A

```

HEAD 指针 指向 version B，并且 stage 已经被 version B 的文件重置，工作区则不受影响。

这里有个很实用的小技巧：

```
git reset version_no <filename> & git checkout -- <filename>

```

这两个命令组合在一起可以让工作区的指定文件回滚到 repository 中对应的 version_no 版本。
如果 version_no 是 HEAD 的话那就可以回滚文件到最新一次的提交。

* * *

--hard：谨慎使用！！！移动 repository 的 HEAD 指针 到指定版本号，同时用此版本重置 stage 区 和 工作区源码。这里要特别注意，工作区的源码也会被覆盖重置掉，你的修改会全部丢失。简单来说就是将代码彻底恢复到指定版本。hard 是没办法指定文件的，要么回滚，要么全回滚。

```
# HEAD指针 还是指向 HEAD 
git reset --hard HEAD^3
#版本号现状
version A <-- HEAD指针

```

此时，HEAD 指针 指向 version A，并且 stage 和 工作区的文件已经被 version A 的文件重置。整个项目的状态完全回到提交 version A 时按下回车键的那一刻。

## rm

git rm 不同于直接使用 rm，git rm 会删除工作区 和 stage 区的内容。注意：这里你没办法再使用 git checkout -- <filename> 来回滚操作了，因为工作区也没有 filename 文件了，没办法与 repository 做关联，只能使用 git reset HEAD <filename> 来重置 stage 中的此文件，然后 git checkout -- <filename>

```
git rm [--cached] [-r] [-f] <filename>

```

这里就提示一点，只想把 stage 中的文件删除掉让文件脱离 git 的管理，可以使用

```
git rm --cached <filename>

```

此时工作区的 filename 并不会被删除，但状态会被改为 untracked，同时 stage 会记录下 filename 的状态为删除，提交的话版本库将新增一个 filename 被删除掉的版本。
删除 stage 中的文件和使用 reset 命令 重置 stage 中的文件是有区别的，删除会让文件状态更改为 untracked，而重置会让文件状态更改为 unstage（如果工作区和 stage 文件内容不一致）。

小实例场景：

1、回滚工作区某文件到指定的 repository 版本

工作中，我们可能会针对某文件做多次修改和 add 到 stage 的操作，而后发现思路完全错了，需要重新设计开发。

比如文件 foo 的 A 版 我提交了一次后，又进行了 B 版 和 C 版 的两次修改并 add 到了 stage 区。第三次修改后 D 版 我发现一开始思路就错了，需要重新设计。那此时直接使用 git checkout -- foo 是拿不到最初的 A 版 的，因为 stage 区还存放着 foo 的 C 版。此时我们便可以使用 git reset HEAD foo 命令，repository 最新版本号中存放着 foo 的 A 版，命令会在不移动 HEAD 的前提下，使用 foo A 版 去重置 stage 区。命令执行后 stage 区的 foo 文件已经是 A 版 了。我们再使用 git checkout -- foo 便可以将工作区的 foo D 版 回滚至 A 版。即：

```

git reset HEAD foo & git checkout -- foo

```

HEAD 代表当前版本，所以 HEAD 指针 不会移动。同时 stage 区会被 repository 的当前版本的 filename 重置，也就说 stage 区 存放的 filename 与 repository 中相同了。此时我们再使用 git checkout -- <filename> 便可以回滚工作区的 filename 到 repository 的当前版本。其实就是利用 reset --mixed 会重置 stage 区，然后 checkout 会将 stage 区的文件检出到工作目录。当然，reset 很灵活，可以回滚任意指定的版本。

其实如果只是回滚至当前版本的话，还有个命令能实现相同的功能

```
git rm --cached <filename> & git checkout -- <filename>

```

git rm --cached <filename> 会将 stage 中的此文件删除，文件状态会变为 untracked，然后 checkout 时发现 stage 中木有此文件，故会去 repository 的当前版本中检出此文件。

## diff

git diff -- <filename> 工作区 比较 暂存区
git diff --cached -- <filename> 暂存区 比较 本地库当前版本
git diff HEAD~N -- <filename> 工作区 比较 本地库第 N 个版本
git diff HEAD HEAD^ -- <filename> HEAD 比较 HEAD^
git diff master tmp -- <filename> master 比较 tmp
git diff SHA1 SHA2 -- <filename> 比较两个历史版本之间的差异