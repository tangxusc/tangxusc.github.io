> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://segmentfault.com/a/1190000015592863

# 背景

前阵子老美的 Audit 要求各个开发组截图各自 repository 的 Sonar Analysis Report，我跑去 Sonarqube 一看。。。好家伙！全是红灯，简直惨不忍睹

![](https://segmentfault.com/img/bVbdAmb?w=1310&h=1204)

当然这其中有历史问题，因为我们是半路接管的欧美 team 的 code，很多 issue 都是 old code 所遗留的。

![](https://segmentfault.com/img/bVbdAmA?w=500&h=327)

不逃避责任，其中也有一部分是我们后续提交的新代码造成的，通过项目 2 年来的日积月累，issue 多的有点积重难返，sonarqube 虽然在每次 jenkins build 都会生成 report，但是我们却没有把它作为 build 成功失败的一个硬指标。只要 build 成功通过 QA 测试就好了嘛！管他娘的 sonar quality gate

# 结果

为了出一份体面漂亮的 report 给 audit，我不得不快马加鞭的 checkout -b quick_fix_sonar_issues, 花了一整天的功夫把 block 和 critical 的 issue 降到了阈值以下。

**临阵磨枪的我体会到了以下 3 个痛点**

1.  有些 Sonar 能检测出来的 issue，确实能规避一些产品上的潜在 bug
2.  有些同事在 code 中犯的错误真的很低级，但是人工 code review 中很难被发现，不是我的锅，我现在却在为同事擦屁股。
3.  虽然快速 fix 了 issue，但是 code 的 owner 并不是我，我有可能为了迎合 sonar 的 rule 而产生了潜在的新的 issue，而和 owner 去一一 check 又增加了很多沟通成本，另外 owner 很有可能已经离职了

# 思考

囧则思变！如何改进我们的开发流程？在代码开发阶段就能让 Sonar 分析出问题？强制 owner 必须解决完 issue 才能提交代码？
嗯！是时候对目前存在弊端的开发流程进行改进了！

### 老的开发流程

先介绍下目前的基础设施：

*   通过 GitHub 来管理 source
*   通过 Github Pull Request 来实现 Code Review（以前用 gerrit 但是我以 UI 太丑为由号召开发们拒绝使用）
*   通过 Jenkins 来实现持续集成
*   通过 Sonarqube 来实现代码分析（形同虚设）

老的流程：

1.  当一个新 feature 来临时
2.  owner 从 master（受保护的）分支 checkout 一个 feature_dev_branch 做开发
3.  开发完成后，提交 pull request（PR）请求合并到 master
4.  技术 leader 对 PR 进行 code review 并 approve 后，feature_dev_branch 合并到 master。
5.  Merge 触发触发 Jenkins 自动 build，Jenkins 触发 Sonarqube scan 产生 report（仅仅生成 report）
6.  Build 成功则进行 package 的 deploy 以及后续 Automation Testing 等流程
7.  交付 QA 测试

### 改进后的开发流程：

1.  当一个新 feature 来临时
2.  owner 从 master （受保护的）分支 checkout 一个 feature_dev_branch 做开发
3.  开发完成后，提交 pull request（PR）请求合并到 master
4.  **PR 自动触发 Jenkins，Jenkins 触发 Sonar 分析本次提交的 new code**
5.  **Sonar 将 report 和 issue 以 comments 的方式写到 Github PR 里，并作为硬性的 check point**
6.  **Owner 对 PR 进行反复 commit 直至通过 Sonar 的分析**
7.  技术 leader 对 PR 进行 code review 并 approve 后，feature_dev_branch 合并到 master。
8.  Merge 触发触发 Jenkins 自动 build，Jenkins 触发 Sonarqube scan 产生 report（仅仅生成 report）
9.  Build 成功则进行 package 的 deploy 以及后续 Automation Testing 等流程
10.  交付 QA 测试

加了 3 步，使得 new code 通过 sonar 检测成为一个硬性指标，把 issue 扼杀在萌芽中，把锅甩在最前面

![](https://segmentfault.com/img/bVbdAtz?w=1564&h=1276)

![](https://segmentfault.com/img/bVbdAtq?w=1552&h=1272)

![](https://segmentfault.com/img/bVbdAzt?w=1706&h=822)

# 哇！！！太 Cool 了！

## 跟我一步步完成 Jenkins 和 Sonar 的配置

什么？你竟然不知道 Jenkins 是个啥？！那你操个哪门子的心去优化开发流程，好好搬你的砖，写你的 bug！
咳咳！建议你转发本文给负责 devops 的同事，请他吃饭让他帮忙配置

#### Jenkins 需要一个 plugin，叫做 github pull request builder

它的作用是生成在 Jenkins 和 Github 之间生成 webhook，似的 PR 可以自动触发 Jenkins 的 Build

![](https://segmentfault.com/img/bVbdAuI?w=2090&h=380)

#### 稍微配置下这个插件，画红线的地方很重要

![](https://segmentfault.com/img/bVbdAvu?w=2594&h=1184)

#### Jenkins 还需要一个 plugin，叫做 SonarQube Scanner

它的作用是让 Jenkins 去触发 Sonar 的分析

![](https://segmentfault.com/img/bVbdAwl?w=2436&h=556)

#### 稍微配置下这个插件，画红线的地方很重要

没听说的 Sonar？没有现成的 Sonar Server? 额，继续请 devops 吃饭吧...

![](https://segmentfault.com/img/bVbdAxr?w=1920&h=868)

![](https://segmentfault.com/img/bVbdAw5?w=1846&h=1114)

#### Sonarqube 里（注意是 Sonarqube 里，不是 Jenkins 里）也需要安装一个 plugin，名字叫 Github

它的作用是 当 Sonar 检测完毕后，把生成的 report 和 issue 的分析以 comments 的方式写回到 Github 的 PR 中

![](https://segmentfault.com/img/bVbdAxG?w=2796&h=608)

#### 稍微配置下这个插件，画红线的地方很重要

![](https://segmentfault.com/img/bVbdAxN?w=1546&h=934)

#### 接下去就是配置 Jenkins 的 project 了

废话不多，只贴关键配置，红线部分很重要

![](https://segmentfault.com/img/bVbdAxR?w=1850&h=1014)

![](https://segmentfault.com/img/bVbdAyl?w=1852&h=940)

Advanced 里可以勾上这一条（虽然是 Dangerous），因为我们 Github 是企业版，所以能提 PR 的人是有权限控制的，如果是用官网的 github 管理代码请慎用这个选项，建议使用黑白名单来控制触发的条件。
![](https://segmentfault.com/img/bVbdAyo?w=1142&h=70)

以下是 Sonar 的配置，很重要，注意 analysis mode 只能选择 preview，preview mode 不会真正的在 Sonar 上生成 report 哦。

![](https://segmentfault.com/img/bVbdAzd?w=2118&h=978)

# 写在最后

Jenkins 的安装，Sonar 的安装啥的，教程我就不放 link 了，这种大路教程一搜一大堆（我个人建议你用 docker 安装）
作为一个开发，我觉得这些基本的，能提升工作效率的工具还是要掌握一下的，并不是说只有 devops 才会用到这些工具，谁不喜欢偷懒呢，这些都是偷懒的好帮手。

截止发稿时，这个流程还存在一些些小 bug，比如 preview mode 的 sonar 分析不能跟 sonar 中 quality gate 进行结合，sonar js 不能分析 parse 有问题的 js 文件等等，还显得不够完美，我们也在通过其它的 workaround 来 100% 实现理想中的开发流程，如果你有好的建议欢迎留言。