---
title: "sonarqube使用指南"
date: 2019-03-20T14:15:59+08:00
draft: false
---

# sonarqube使用指南

## 简介

​	Sonar是一个用于代码质量管理的开源平台，用于管理源代码的质量，可以从多个维度检测代码质量通过插件形式，可以支持包括java,C#,C/C++,PL/SQL,Cobol,JavaScrip,Groovy等等二十几种编程语言的代码质量管理与检测

### 糟糕的复杂度分布
​	文件、类、方法等，如果复杂度过高将难以改变，这会使得开发人员难以理解它们，且如果没有自动化的单元测试，对于程序中的任何组件的改变都将可能导致需要全面的回归测试
### 重复
​	显然程序中包含大量复制粘贴的代码是质量低下的 sonar可以展示源码中重复严重的地方
### 缺乏单元测试
 	sonar可以很方便地统计并展示单元测试覆盖率
### 没有代码标准
​	sonar可以通过PMD,CheckStyle,Findbugs等等代码规则检测工具规范代码编写
### 没有足够的或者过多的注释
​	没有注释将使代码可读性变差，特别是当不可避免地出现人员变动时，程序的可读性将大幅下降  而过多的注释又会使得开发人员将精力过多地花费在阅读注释上，亦违背初衷
### 潜在的bug
​	sonar可以通过PMD,CheckStyle,Findbugs等等代码规则检测工具检测出潜在的bug
### 糟糕的设计
  	通过sonar可以找出循环，展示包与包、类与类之间的相互依赖关系
  	可以检测自定义的架构规则
  	通过sonar可以管理第三方的jar包
  	可以利用LCOM4检测单个任务规则的应用情况
  	检测耦合

## 安装

`pg.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  labels:
    app: postgres
spec:
  replicas: 1
  template:
    metadata:
      name: postgres
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:10
        imagePullPolicy: IfNotPresent
        ports:
          - containerPort: 5432
        env:
          - name: POSTGRES_USER
            value: sonar
          - name: POSTGRES_PASSWORD
            value: sonar
        volumeMounts:
          - mountPath: /var/lib/postgresql/data
            name: postgres-data
      restartPolicy: Always
      volumes:
        - name: postgres-data
          emptyDir: {}
  selector:
    matchLabels:
      app: postgres
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
```

`sonar.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonar
  labels:
    app: sonar
spec:
  replicas: 1
  template:
    metadata:
      name: sonar
      labels:
        app: sonar
    spec:
      containers:
      - name: sonar
        image: sonarqube:latest
        imagePullPolicy: IfNotPresent
        ports:
          - containerPort: 9000
        env:
          - name: SONARQUBE_JDBC_USERNAME
            value: sonar
          - name: SONARQUBE_JDBC_PASSWORD
            value: sonar
          - name: SONARQUBE_JDBC_URL
            value: jdbc:postgresql://postgres:5432/sonar
      restartPolicy: Always
  selector:
    matchLabels:
      app: sonar
---
apiVersion: v1
kind: Service
metadata:
  name: sonar
spec:
  selector:
    app: sonar
  ports:
  - port: 9000
  type: NodePort
```

## 使用方式(java项目)

在项目根目录下创建: `sonar-project.properties`

```java
sonar.projectKey=product-service
sonar.projectName=product-service
sonar.projectVersion=v1
sonar.sources=./jwell-product-service-provider/,./jwell-product-service-api/
```

如果是多模块项目,则使用此模式:

```java
sonar.projectKey=product-service
sonar.projectName=product-service
sonar.projectVersion=v1
sonar.modules=provider

java-module.sonar.projectName=provider
java-module.sonar.language=java
java-module.sonar.sources=./jwell-product-service-provider/
java-module.sonar.projectBaseDir=src
sonar.binaries=classes
```



在项目的pom.xml文件夹下运行

```shell
mvn sonar:sonar \
  -Dsonar.host.url=http://10.0.60.28:32620 \
  -Dsonar.login=bfc62d2312cf6dab1672c62d0ec3314ef2481cbd \
  -Dsonar.java.binaries=target/sonar
```

## 查看分析结果

使用浏览器打开 `http://10.0.60.28:32620`



## 管理sonarqube-server

```shell
账号:admin
密码:admin
```



