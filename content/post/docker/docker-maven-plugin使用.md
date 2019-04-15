---
title: "docker maven plugin使用"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- docker
tags:
- docker
- maven
keywords:
- docker
- maven
---

随着容器化的进行，测试环境和线上环境开始尝试容器化发布。因此需要将现有的maven工程进行容器化，容器化的好处不言而喻，但是针对原先没有解耦的应用（容器配置和代码耦合在一起），制作镜像还是有些成本的。本文主要记录对于webx和springboot应用的镜像制作。

<!--more-->
## springboot镜像制作
springboot制作官方有[介绍][1]，最主要的就是在pom.xml中增加docker maven plugin，然后配置读取最终生成的jar即可。

```xml
<plugin>
    <groupId>com.spotify</groupId>
    <artifactId>docker-maven-plugin</artifactId>
    <configuration>
        <imageName>aegis-package-switch:1.0</imageName>
        <dockerDirectory>${project.basedir}/docker</dockerDirectory>
        <resources>
            <resource>
                <targetPath>/</targetPath>
                <directory>bin</directory>
                <include>run.sh</include>
            </resource>
            <resource>
                <targetPath>/</targetPath>
                <directory>${project.build.directory}</directory>
                <include>${project.build.finalName}.jar</include>
            </resource>
        </resources>
    </configuration>
</plugin>
```
docker-maven-plugin主要配置有：

 - 镜像名称
 - dockerfile文件
 - 需要添加到镜像中的资源

docker-maven-plugin插件本身可以通过xml配置设置类似dockerfile中的简单操作（如添加文件等），但是为了统一和可读性，还是建议统一使用dockerfile。上面的示例中dockerfile位于项目目录的docker子目录中，目录结构类似：
```shell
.
├── bin
│   └── run.sh
├── docker
│   └── Dockerfile
├── pom.xml
├── src
│   ├── main
│   └── test
```
resources标签中包含需要添加到镜像中的文件，实际执行时插件会将它们复制到target/docker目录中，供dockerfile使用，否则dockerfile中将无法引用到文件。

然后就是最重要的dockerfile，springboot应用启动比较方便，依赖也很少，只要使用包含java的基础镜像即可。
```shell
FROM j8:1.0
RUN mkdir /work
WORKDIR /work
ADD run.sh /work/run.sh
ADD package.switch-1.0-SNAPSHOT.jar app.jar
CMD ["/bin/bash","./run.sh"]
```

dockerfile中需要添加的文件，只要在插件中配置resource后，直接使用即可。这里的启动脚本也可以省略，直接java -jar即可。

## webx应用镜像制作

webx应用在插件配置上完全相同，主要是因为没有解耦，dockerfile会相对比较复杂。
```shell
FROM jetty-j7-httpd:1.0
RUN useradd -m admin
RUN mkdir -p /home/admin/output/logs && mkdir /home/admin/web-deploy && mkdir /home/admin/agent-deploy
ADD gaea.env.deploy.tar.gz /home/admin/web-deploy
RUN AGENT_VERSION=`cat /home/admin/web-deploy/conf/agent.version` && mkdir /home/admin/agent-deploy/$AGENT_VERSION \
    && cp /home/admin/web-deploy/agent/gaea.env.agent.zip /home/admin/agent-deploy/$AGENT_VERSION/
RUN chown -R admin:admin /home/admin
WORKDIR /home/admin/web-deploy/bin
USER admin
EXPOSE 8080
CMD ["./startws.sh", "-d"]
```
注意，在打包前需要确保打出来的包已经通过auto-config插件完成autoconfig操作。默认pom中的asscembly插件会将最终的包打包成tgz包，因此直接ADD到镜像中即可，docker制作镜像的时候，ADD指令会自动将压缩包解压缩（这里有个小问题，ADD指令不会解压缩zip包，如果使用ZIP包，需要使用unzip命令解压缩）。

另外一个需要注意的问题就是启动脚本。之前应用的启动脚本将java容器（如tomcat、jetty等）启动后，就会自动退出。但是docker容器启动时，第一个执行的进程PID为1，如果该进程退出，会导致整个容器退出。因此这里在原先的脚本中增加了一个-d参数，配置脚本修改成如果有-d参数，则一直循环等待（sleep）。
```shell
if [[ $1 == "-d" ]]; then
  while true; do sleep 1000; done
fi
```

## 整合git插件

上面的docker插件配置会有一个问题，每次提交的镜像版本都相同。这样可能会导致两个问题：

推送到hub之后版本相同，可能会覆盖之前的版本，导致回滚困难;
无法追踪当前镜像的代码版本
为了解决上面两个问题，可以在pom中增加git-commit-id-plugin，获取当前版本号，并且将版本号添加到镜像版本中。
```xml
<plugin>
    <groupId>pl.project13.maven</groupId>
    <artifactId>git-commit-id-plugin</artifactId>
    <version>2.2.0</version>
    <executions>
        <execution>
            <goals>
                <goal>revision</goal>
            </goals>
        </execution>
    </executions>
    <configuration>
        <dateFormatTimeZone>${user.timezone}</dateFormatTimeZone>
        <verbose>true</verbose>
    </configuration>
</plugin>
<plugin>
	<groupId>com.spotify</groupId>
	<artifactId>docker-maven-plugin</artifactId>
	<configuration>
		<imageName>master:1.0.0-${git.commit.id.abbrev}</imageName>
        <dockerDirectory>${project.basedir}/docker</dockerDirectory>
		<resources>
			<resource>
				<targetPath>/</targetPath>
				<directory>${project.parent.build.directory}</directory>
                <include>${project.artifactId}.tar.gz</include>
            </resource>
        </resources>
    </configuration>
</plugin>
```
在配置了git-commit-id-plugin之后，镜像名字可以直接使用git.commit.id.abbrev变量。该变量会取git commit id中的前n位（默认是7位），这样可以确保大版本不变的时候，每个镜像的小版本都不相同。这里会有个问题，git commit id是sha的哈希值，没有可读性，也无法知道commit的顺序。如果用于发布，建议和git tag关联，通过git-commit-id-plugin插件获取当前tag作为版本后缀。

## 推送和私有hub

由于内部有多个不同的私有hub，而docker又需要将hub地址放到镜像名称中，如果需要将一个镜像推送到不同的hub，需要动态修改插件的配置。这里可以使用maven的变量机制。首先我们在顶级pom中定义一个变量docker.repo，可以在其中设置一个默认值，然后插件中使用该变量：
```xml
<properties>
    <docker.repo>a.b.com:5000</docker.repo>
</properties>
...
<plugin>
    <groupId>com.spotify</groupId>
    <artifactId>docker-maven-plugin</artifactId>
    <configuration>
        <imageName>master:1.0-${git.commit.id.abbrev}</imageName>
        <dockerDirectory>${project.basedir}/docker</dockerDirectory>
        <resources>
            <resource>
                <targetPath>/</targetPath>
                <directory>bin</directory>
                <include>run.sh</include>
            </resource>
            <resource>
                <targetPath>/</targetPath>
                <directory>${project.build.directory}</directory>
                <include>${project.build.finalName}.jar</include>
            </resource>
        </resources>
    </configuration>
    <executions>
        <execution>
            <phase>package</phase>
            <goals>
                <goal>build</goal>
            </goals>
        </execution>
        <execution>
            <id>tag-image</id>
            <phase>package</phase>
            <goals>
                <goal>tag</goal>
            </goals>
            <configuration>
                <image>master:1.0-${git.commit.id.abbrev}</image>
                <newName>${docker.repo}/master:1.0-${git.commit.id.abbrev}</newName>
                <forceTags>true</forceTags>
            </configuration>
        </execution>
        <execution>
            <id>push-image</id>
            <phase>install</phase>
            <goals>
                <goal>push</goal>
            </goals>
            <configuration>
                <imageName>${docker.repo}/master:1.0-${git.commit.id.abbrev}</imageName>
            </configuration>
        </execution>
    </executions>
</plugin>
```
这里配置比较长，主要分为两个部分，首先是将制作镜像（build）、添加tag、推送镜像（push）三个操作分别挂到maven的package和install两个步骤中。

build不再赘述，tag就是用来从刚才的镜像设置一个独立的标签，使用该功能，就可以实现镜像“重命名”工作。新的镜像名字需要包含hub地址，既使用上面定义的docker.repo变量。注意如果本地已经存在tag后的镜像名称，必须加上<forceTags>true</forceTags>标签，使其忽略这个错误强制进行tag操作。

推送操作绑定在install goal中。该插件的官方示例中，推送到仓库被绑定到了deploy goal中，但是由于我们不希望将web工程的包deploy到maven的仓库，所以绑定到install上。

如果需要切换仓库，只需要在执行maven操作的时候指定docker.repo值即可覆盖当前的值：
```shell
install -DskipTests -Ddocker.repo=a.c.com:5000
```
[1]: https://spring.io/guides/gs/spring-boot-docker/
