---
title: "jgit获取git仓库中的部分文件"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- java
tags:
- java
- jgit
keywords:
- java
- jgit
---

jgit在获取文件时,只能获取仓库中的全部文件,本文提供一种方法,使用jgit获取仓库中的部分文件.

适用场景:

- 用户提交git仓库地址,文件地址,需要读取仓库中的远程文件
<!--more-->

## 原理

在git的命令行中,存在一个ls-remote命令,显示远程存储库中可用的引用以及关联的提交ID

```shell
tangxu@tangxu-pc:$ git ls-remote
From https://gitee.com/tanx/cavy-platform.git
befcac9af04c7822aed0a7f7604d4b9248de3c61	HEAD
befcac9af04c7822aed0a7f7604d4b9248de3c61	refs/heads/master
```

jgit中存在一个**CheckoutCommand**对象,对象中包含方法

```java
public CheckoutCommand setStartPoint(String startPoint) {//startPoint则为引用id
        this.checkCallable();
        this.startPoint = startPoint;
        this.startCommit = null;
        this.checkOptions();
        return this;
    }
```

和**addPath**方法

```java
public CheckoutCommand addPath(String path) {//path为文件路径
        this.checkCallable();
        this.paths.add(path);
        return this;
    }
```

## 具体实现

话不多述,我们直接上代码:

```java
//url 远程仓库url地址,以.git结尾
//branch 分支名称
private String getRefHash(String url,String branch) throws GitAPIException {
    Collection<Ref> call = Git.lsRemoteRepository().setRemote(url).call();
    for (Ref ref : call) {
        String[] split = ref.getName().split("/");
        String s = split[split.length - 1];
        if (branch.equalsIgnoreCase(s)) {
            return ref.getObjectId().getName();
        }
    }
    throw new RuntimeException("未找到分支:" + branch);
}

//url 远程仓库地址
//branch 分支名称
//username 账号
//password 密码
//hash 上一个方法获取到的hash
//directory 本地文件存放路径
//filePath 远程文件路径
private void cloneRepositoryFile(String url,String branch,String username,String password,String hash, File directory,String filePath) throws GitAPIException {
    CloneCommand cloneCommand = Git.cloneRepository()
            .setURI(url)
            .setBranch(branch)
            .setDirectory(directory)
            .setNoCheckout(true);
    //账号密码如果为空,那么不设置
    if (!StringUtils.isEmpty(username) && !StringUtils.isEmpty(password)) {
        cloneCommand.setCredentialsProvider(new UsernamePasswordCredentialsProvider(username, password));
    }
    Git call = cloneCommand.call();
    call.checkout()
            .setStartPoint(hash)
            .addPath(filePath).call();
    call.getRepository().close();
}
```

