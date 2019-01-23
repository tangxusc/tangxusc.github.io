# 使用nfs作为k8s的PersistentVolume

在较小规模的生产和开发的过程中,对于k8s的某些应用可能我们需要提供存储的支持,在初期我们可能并不需要性能那么高,扩展性那么强的存储,那么这个时候nfs就成了我们的首选

本文将引导各位在服务器中部署nfs服务,并在k8s中使用nfs服务

## 准备

nfs server *1

k8s集群 *1

## NFS server配置

### 安装nfs,并启动

```shell
$ yum install -y nfs-utils
##关闭防火墙
$ systemctl disable firewalld
$ systemctl stop firewalld
##开启nfs自动启动
$ systemctl enable rpcbind.service
$ systemctl enable nfs-server.service
## 启动nfs
$ systemctl start rpcbind.service
$ systemctl start nfs-server.service
```

### 配置nfs

编辑文件`/etc/exports`设置nfs需要暴露的文件夹

```shell
$ vim /etc/exports
#添加 此处暴露的是/home/nfsdata目录
/home/nfsdata *(insecure,rw,sync,no_root_squash)
###修改暴露的目录的权限
$ chmod 777 -R /home/nfsdata
##重启nfs
$ systemctl restart nfs.service
```

### 验证

```shell
$ showmount -e 10.0.60.51
Export list for 10.0.60.51:
/home/nfsdata *
##打印暴露的目录,则为配置成功
```

### 配置释义

```shell
ro 该主机对该共享目录有只读权限
rw 该主机对该共享目录有读写权限
root_squash 客户机用root用户访问该共享文件夹时，将root用户映射成匿名用户
no_root_squash 客户机用root访问该共享文件夹时，不映射root用户
all_squash 客户机上的任何用户访问该共享目录时都映射成匿名用户
anonuid 将客户机上的用户映射成指定的本地用户ID的用户
anongid 将客户机上的用户映射成属于指定的本地用户组ID
sync 资料同步写入到内存与硬盘中
async 资料会先暂存于内存中，而非直接写入硬盘
insecure 允许从这台机器过来的非授权访问
```

好了,nfs服务器已经配置完毕,接下来我们使用k8s对nfs进行挂载

## k8s中使用nfs

创建一个namespace用来测试

```shell
$ kubectl create ns testpv
```

### 挂载nfs

`pv.yaml`

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
    name: pvtest
spec:
    capacity:
      storage: 5Gi
    accessModes:
      - ReadWriteMany
    persistentVolumeReclaimPolicy: Recycle
    nfs:
      path: /home/nfsdata	#nfs目录
      server: 10.0.60.51	#nfs服务器地址
```

此处需要注意:

nfs不支持动态的`StorageClass`

`PersistentVolume`是一个全局对象,所以是没有命名空间限制的

`PersistentVolume`可以手动创建,也可以使用`StorageClass`创建

`persistentVolumeReclaimPolicy`可选值有三个:

**Retain** : 当`PersistentVolumeClaim`删除时,`PersistentVolume`仍然存在,并且该卷被视为“已释放”,需要管理员手动删除

**Delete** : 删除将删除`PersistentVolume`及关联的数据

**Recycle** : 使用`rm -rf /thevolume/*`对`PersistentVolume`进行基本的删除

> **警告：**`Recycle`回收政策已弃用。相反，推荐的方法是使用动态配置。

`accessModes` 分为三种,分别为:

- ReadWriteOnce - 卷可以由单个节点以读写方式挂载
- ReadOnlyMany - 卷可以由许多节点以只读方式挂载
- ReadWriteMany - 卷可以由许多节点以读写方式挂载

### 创建pvc与pv绑定

`pvc.yaml`

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pvctest
  namespace: testpv
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
```

k8s将自动寻找合适的pv,并将pvc绑定至pv,并且 **这个绑定是一对一的,也就是说绑定后,其他pvc也就无法再使用这个pv了.**

### pv的生命周期

`available` --> `Bound` --> 当删除pvc时,根据回收策略决定接下来的动作

**Retain** : 保留pv,保留数据,等待管理员操作

**Delete** : 删除pv,删除数据

**Recycle** : 使用`rm -rf /thevolume/*`对`PersistentVolume`进行基本的数据删除, 回到available状态

### 使用deployment作为测试

`deployment.yaml`

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: test
  namespace: testpv
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: "test"
        version: "0.1"
    spec:
      containers:
      - name: test
        image: tomcat:8
        volumeMounts:
        - mountPath: "/test/data"
          name: testpv
        ports:
        - containerPort: 8080
      volumes:
      - name: testpv
        persistentVolumeClaim:
          claimName: pvctest
```

在这里我们使用了一个tomcat:8的容器来进行测试,在这里我们将目录挂载到了容器中的`/test/data`目录下

接下来,我们将文件输出到这个目录以进行测试

```shell
$ kubectl apply -f pv.yaml -f pvc.yaml -f deployment.yaml
persistentvolume/pvtest created
persistentvolumeclaim/pvctest created
deployment.extensions/test created
###接下来进入这个pod中
$ kubectl exec -n testpv -it test-745bcb9bd9-xrlbs -- bash
root@test-745bcb9bd9-xrlbs:/usr/local/tomcat# cd /test/data
root@test-745bcb9bd9-xrlbs:/test/data# ls
root@test-745bcb9bd9-xrlbs:/test/data# echo "test"> test.txt
root@test-745bcb9bd9-xrlbs:/test/data# ls
test.txt
###可以看到,我们在pod中建立了一个文件 test.txt
```

接下来 我们切换到 nfs的server上,查看文件是否被创建了

```shell
[root@node01 home]# cd /home/nfsdata/
[root@node01 nfsdata]# ls
test.txt
```

可以看到 在nfs中已经存在了这样一个文件了, 那么这个时候我们将我们的 deployment和 pvc删除后看看pv是什么样的情况呢?

```shell
###在这里我为了方便直接删除了namespace
$ kubectl delete ns/testpv
#再次查看pv的状态
$ kubectl get pv 
NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
pvtest   5Gi        RWX            Recycle          Available                                   46m
```

这里的status已经变成了`Available`,说明我们的回收策略已经生效了

再到 nfs server中查看

```shell
[root@node01 home]# cd /home/nfsdata/
[root@node01 nfsdata]# ls
#无任何输出
```

## 参照

[k8s官方说明persistent-volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

