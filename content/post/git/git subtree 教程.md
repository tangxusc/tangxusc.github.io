---
title: "git subtree 教程"
date: 2019-03-20T14:15:59+08:00
draft: false
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://segmentfault.com/a/1190000012002151

关于子仓库或者说是仓库共用，git 官方推荐的工具是 git subtree。 我自己也用了一段时间的 git subtree，感觉比 git submodule 好用，但是也有一些缺点，在可接受的范围内。
所以对于仓库共用，在 git subtree 与 git submodule 之中选择的话，我推荐 git subtree。

# git subtree 是什么？为什么使用 git subtree

git subtree 可以实现一个仓库作为其他仓库的子仓库。
![](https://segmentfault.com/img/remote/1460000012002154?w=1134&h=495)

使用 git subtree 有以下几个原因：

*   旧版本的 git 也支持 (最老版本可以到 v1.5.2).

*   git subtree 与 git submodule 不同，它不增加任何像`.gitmodule`这样的新的元数据文件.

*   git subtree 对于项目中的其他成员透明，意味着可以不知道 git subtree 的存在.

当然，git subtree 也有它的缺点，但是这些缺点还在可以接受的范围内：

*   必须学习新的指令 (如：git subtree).

*   子仓库的更新与推送指令相对复杂。

# git subtree 的使用

git subtree 的主要命令有：

```
git subtree add   --prefix=<prefix> <commit>
git subtree add   --prefix=<prefix> <repository> <ref>
git subtree pull  --prefix=<prefix> <repository> <ref>
git subtree push  --prefix=<prefix> <repository> <ref>
git subtree merge --prefix=<prefix> <commit>
git subtree split --prefix=<prefix> [OPTIONS] [<commit>]
```

## 准备

我们先准备一个仓库叫 photoshop，一个仓库叫 libpng，然后我们希望把 libpng 作为 photoshop 的子仓库。
photoshop 的路径为`https://github.com/test/photoshop.git`，仓库里的文件有：

```
photoshop
    |
    |-- photoshop.c
    |-- photoshop.h
    |-- main.c
    \-- README.md
```

libPNG 的路径为`https://github.com/test/libpng.git`，仓库里的文件有：

```
libpng
    |
    |-- libpng.c
    |-- libpng.h
    \-- README.md
```

以下操作均位于父仓库的根目录中。

## 在父仓库中新增子仓库

我们执行以下命令把 libpng 添加到 photoshop 中：

```
git subtree add --prefix=sub/libpng https://github.com/test/libpng.git master --squash
```

(`--squash`参数表示不拉取历史信息，而只生成一条 commit 信息。)

执行`git status`可以看到提示新增两条 commit：
![](https://segmentfault.com/img/remote/1460000012002155?w=471&h=68)

`git log`查看详细修改：
![](https://segmentfault.com/img/remote/1460000012002156?w=561&h=191)

执行`git push`把修改推送到远端 photoshop 仓库，现在本地仓库与远端仓库的目录结构为：

```
photoshop
    |
    |-- sub/
    |   |
    |   \--libpng/
    |       |
    |       |-- libpng.c
    |       |-- libpng.h
    |       \-- README.md
    |
    |-- photoshop.c
    |-- photoshop.h
    |-- main.c
    \-- README.md
```

注意，现在的 photoshop 仓库对于其他项目人员来说，可以不需要知道 libpng 是一个子仓库。什么意思呢？
当你`git clone`或者`git pull`的时候，你拉取到的是整个 photoshop(包括 libpng 在内，libpng 就相当于 photoshop 里的一个普通目录)；当你修改了 libpng 里的内容后执行`git push`，你将会把修改 push 到 photoshop 上。
也就是说 photoshop 仓库下的 libpng 与其他文件无异。

## 从源仓库拉取更新

如果源 libpng 仓库更新了，photoshop 里的 libpng 如何拉取更新？使用`git subtree pull`，例如：

```
git subtree pull --prefix=sub/libpng https://github.com/test/libpng.git master --squash
```

## 推送修改到源仓库

如果在 photoshop 仓库里修改了 libpng，然后想把这个修改推送到源 libpng 仓库呢？使用`git subtree push`，例如：

```
git subtree push --prefix=sub/libpng https://github.com/test/libpng.git master
```

## 简化 git subtree 命令

我们已经知道了 git subtree 的命令的基本用法，但是上述几个命令还是显得有点复杂，特别是子仓库的源仓库地址，特别不方便记忆。
这里我们把子仓库的地址作为一个 remote，方便记忆：

```
git remote add -f libpng https://github.com/test/libpng.git
```

然后可以这样来使用 git subtree 命令：

```
git subtree add --prefix=sub/libpng libpng master --squash
git subtree pull --prefix=sub/libpng libpng master --squash
git subtree push --prefix=sub/libpng libpng master
```

# 更多

*   [git 学习汇总](http://blog.wangjinle.com/posts/fd56adc47e2516b6.html)

*   [Git subtree: the alternative to Git submodule](https://www.atlassian.com/blog/git/alternatives-to-git-submodule-git-subtree)

*   [The power of Git subtree](https://legacy-developer.atlassian.com/blog/2015/05/the-power-of-git-subtree/)