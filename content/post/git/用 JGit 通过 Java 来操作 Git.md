---
title: "用 JGit 通过 Java 来操作 Git"
date: 2019-03-20T14:15:59+08:00
draft: false
---


> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 http://qinghua.github.io/jgit/ 

**文章目录**

1.  [1\. 概念](#概念)
2.  [2\. 准备环境](#准备环境)
3.  [3\. 动手](#动手)
    1.  [3.1\. 获取仓库](#获取仓库)
    2.  [3.2\. 常用操作](#常用操作)
    3.  [3.3\. 其它对象](#其它对象)
4.  [4\. 参考资料](#参考资料)

[JGit](https://eclipse.org/jgit/) 是一个由 [Eclipse 基金会](https://www.eclipse.org/org/)开发、用于操作 git 的纯 Java 库。它本身也是 Eclispe 的一部分，实际上 Eclipse 的插件 [EGit](http://www.eclipse.org/egit/) 便是基于 JGit 的。如果你像我这样有使用代码来操作 git 的需求，那就准备好拥抱 JGit 吧。目前来看别的竞品没它靠谱。

## 概念

从用户指南的[概念](http://wiki.eclipse.org/JGit/User_Guide#Concepts)一节中可以看到，JGit 的基本概念如下：

*   Git 对象（Git Objects）：就是 git 的对象。它们在 git 中用 SHA-1 来表示。在 JGit 中用`AnyObjectId`和`ObjectId`表示。而它又包含了四种类型：
    1.  二进制大对象（blob）：文件数据
    2.  树（tree）：指向其它的 tree 和 blob
    3.  提交（commit）：指向某一棵 tree
    4.  标签（tag）：把一个 commit 标记为一个标签
*   引用（Ref）：对某一个 git 对象的引用。
*   仓库（Repository）：顾名思义，就是用于存储所有 git 对象和 Ref 的仓库。
*   RevWalk：该类用于从 commit 的关系图（graph）中遍历 commit。晦涩难懂？看到范例就清楚了。
*   RevCommit：表示一个 git 的 commit
*   RevTag：表示一个 git 的 tag
*   RevTree：表示一个 git 的 tree
*   TreeWalk：类似 RevWalk，但是用于遍历一棵 tree

## 准备环境

让我们从一个最典型的用例开始吧。首先在`/tmp/jgit/repo`中创建一个 git 仓库：
```
mkdir -p /tmp/jgit/repocd /tmp/jgit/repogit init --bare
```
再创建一个 clone 该仓库的客户端：
```
cd /tmp/jgit/git clone repo clientcd client
```
输入`git status`应该能够看到 **Initial commit**，这样环境就没有问题了。然后提交一个文件，给仓库里来点库存：
```
echo hello > hello.txtgit add hello.txtgit commit -m "hello"
git push
```
## 动手

### 获取仓库

动手时间。新建 Maven 工程，往 pom.xml 中增加 dependency，最后的 pom.xml 看起来就像这样：
```
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>org.ggg.jgit</groupId>
    <artifactId>helloJgit</artifactId>
    <version>1.0-SNAPSHOT</version>
    <dependencies>
        <dependency>
            <groupId>org.eclipse.jgit</groupId>
            <artifactId>org.eclipse.jgit</artifactId>
            <version>4.8.0.201706111038-r</version>
        </dependency>
    </dependencies>
</project>
```
让我们先尝试 clone 一下这个仓库。因为 client 分为已经存在以及重新 clone 的两种，所以我们在 src/main/java 中新增一个`RepositoryProvider`接口，用两种不同实现以示区分：
```
public interface RepositoryProvider {
    Repository get() throws Exception;
}
```
并实现之：
```
public class RepositoryProviderCloneImpl implements RepositoryProvider {
    private String repoPath;
    private String clientPath;
    public RepositoryProviderCloneImpl(String repoPath, String clientPath) {
        this.repoPath = repoPath;
        this.clientPath = clientPath;
        
            }
    @Override
    public Repository get() throws Exception {
        File client = new File(clientPath);
        client.mkdir();
        try (Git result = Git.cloneRepository()
                .setURI(repoPath)
                .setDirectory(client)
                .call()) {
            return result.getRepository();
        }    
   }
}
```
新增一个`HelloJGit`主程序类：
```
public class HelloJGit {
    private static RepositoryProvider repoProvider = new RepositoryProviderCloneImpl("/tmp/jgit/repo", "/tmp/jgit/clientJava");
    public static void main(String[] args) throws Exception {
        try (Git git = new Git(repoProvider.get())) {
            git.pull().call();
            
        }
    }
}
```
直接运行`HelloJGit`的`main`函数，`ls /tmp/jgit/`应该就能看到新 clone 出来的`clientJava`文件夹了。
```
cd /tmp/jgit/clientJavalsgit status
```
我们当然不希望总是在使用的时候才重新 clone 一个仓库，因为当仓库很大的时候可能会非常耗时。让我们在`client`中再提交一个 commit：
```
echo hello2 > hello2.txtgit add hello2.txtgit commit -m "hello again"git push
```
然后尝试直接从刚刚 clone 下来的 clientJava 中创建 Repository：
```
public class RepositoryProviderExistingClientImpl implements RepositoryProvider {
    private String clientPath;
    public RepositoryProviderExistingClientImpl(String clientPath) {
        this.clientPath = clientPath;
    }
    @Override
    public Repository get() throws Exception {
        try (Repository repo = new FileRepository(clientPath)) {
            return repo;
        }
    }
}
```
然后把`HelloJGit`的`repoProvider`实例替换为`RepositoryProviderExistingClientImpl`：
```
private static RepositoryProvider repoProvider = new RepositoryProviderExistingClientImpl("/tmp/jgit/clientJava/.git");
```
注意这次的路径中需要加上`.git`才行。再次运行`HelloJGit`的`main`函数，便可以通过`ls /tmp/jgit/clientJava`看到新提交的`hello2.txt`文件了。

### 常用操作

接下来尝试`git add`、`git commit`和`git push`这几个最常用的命令。让我们往`clientJava`中添加一个`hello3.txt`文件并提交。如下修改`HelloJGit`：
```
public static void main(String[] args) throws Exception {
    try (Repository repo = repoProvider.get();
         Git git = new Git(repo)) {
        createFileFromGitRoot(repo, "hello3.txt", "hello3");
        git.add()
                .addFilepattern("hello3.txt")
                .call();
        git.commit()
                .setMessage("hello3")
                .call();
        git.push()
                .call();
    }
}
private static void createFileFromGitRoot(Repository repo, String filename, String content) throws FileNotFoundException {                    
    File hello3 = new File(repo.getDirectory().getParent(), filename);
    try (PrintWriter out = new PrintWriter(hello3)) {
        out.println(content);
    }
}
```

虽然操作多了，但是有了`Repository`和`Git`对象之后，看起来它们的实现都非常直观。运行`main`函数之后，可以到`client`文件夹中校验一下：
```
cd /tmp/jgit/clientgit pullcat hello3.txtgit log
```

在我的机器上运行`git log`，可以得到：**commit 7841b8b80a77918f2ec45bcedb934e2723b16b5c (HEAD -> master, origin/master)**，以及另外两个 commit。有兴趣的读者们可以自行尝试其它的 git 命令。

### 其它对象

虽然上面两小节的内容对于普通需求来说已经大致上够用了，但是在[概念一节](/jgit/#概念)中介绍到的其它概念，如 Git 对象、引用等还没有出场呢。我们再新建一个`WalkJGit`的类，在`main`函数中编写如下代码：
```
try (Repository repo = repoProvider.get()) {
    Ref ref = repo.getAllRefs().get(Constants.HEAD);
    ObjectId objectId = ref.getObjectId();
    System.out.println(objectId);
}
```
这回，`Ref`和`ObjectId`都出现了。在我的机器上，运行以上程序打印出来了 **AnyObjectId[7841b8b80a77918f2ec45bcedb934e2723b16b5c]**。我们可以看到，取得`HEAD`的`Ref`，其`ObjectId`其实就是在`client`文件夹中运行`git log`之后结果。除了`HEAD`以外，`repo.getAllRefs()`返回的`Map`实例中还有`refs/heads/master`和`refs/remotes/origin/master`，在目前的情况下，它们的`ObjectId`完全相同。那么如何获取其它的 commit 呢？那就是`RevWalk`出场的时候。把`main`函数中的内容替换为如下代码：
```
try (Repository repo = repoProvider.get()) {
    Ref ref = repo.getAllRefs().get(Constants.HEAD);
    try (RevWalk revWalk = new RevWalk(repo)) {
        RevCommit lastCommit = revWalk.parseCommit(ref.getObjectId());
        revWalk.markStart(lastCommit);
        revWalk.forEach(System.out::println);
    }
}
```
可以看到`RevWalk`本身是实现了`Iterable`接口的。通过对该对象进行循环，就可以获取所有的 commit 的`RevCommit`对象。可以到`client`文件夹确认一下，这些 SHA-1 字符串应该跟刚才`git log`命令的结果相同。`RevCommit`对象本身含有这个 commit 的所有信息，所以可以如下打印出来：
```
revWalk.forEach(c -> {
    System.out.println("commit " + c.getName());
    System.out.printf("Author: %s <%s>\n", c.getAuthorIdent().getName(), c.getAuthorIdent().getEmailAddress());
    System.out.println("Date: " + LocalDateTime.ofEpochSecond(c.getCommitTime(), 0, ZoneOffset.UTC));
    System.out.println("\t" + c.getShortMessage() + "\n");});
```
这样看起来是不是很有`git log`的感觉呢？需要注意的是，`RevWalk`线程不安全，并且像`Stream`那样，只能使用一次。[如果想要再来一次](https://github.com/eclipse/jgit/blob/master/org.eclipse.jgit/src/org/eclipse/jgit/revwalk/RevWalk.java#L77)，就需要重新创建`RevWalk`对象或是调用其`reset`方法（还得重新`markStart`！）。

要想看到每个 commit 中有什么内容，那就需要用到`TreeWalk`了，它的思路和`RevWalk`类似。尝试如下代码：
```
for (RevCommit commit : revWalk) {
    System.out.println("\ncommit: " + commit.getName());
    try (TreeWalk treeWalk = new TreeWalk(repo)) {
        treeWalk.addTree(commit.getTree());
        treeWalk.setRecursive(true);
        while (treeWalk.next()) {
            System.out.println("filename: " + treeWalk.getPathString());
            ObjectId objectId = treeWalk.getObjectId(0);
            ObjectLoader loader = repo.open(objectId);
            loader.copyTo(System.out);
        }
    }
}
```
这样便可以显示仓库在每个 commit 时候的状态了。如果需要 diff，那么还将需要用到`DiffEntry`等类，本文就不再赘述了，有兴趣的读者可以参考[这个类](https://github.com/centic9/jgit-cookbook/blob/master/src/main/java/org/dstadler/jgit/porcelain/ShowChangedFilesBetweenCommits.java)。

最后将环境还原：
```
rm -rf /tmp/jgit
```
## 参考资料

[这个代码库](https://github.com/centic9/jgit-cookbook)里有很全面的、基本可以直接用于生产环境的范例。
[JGit 的源码](https://github.com/eclipse/jgit)和[用户指南](http://wiki.eclipse.org/JGit/User_Guide)。