---
title: "code-generator使用"
date: 2019-05-17T11:13:08+08:00
categories:
- k8s
- client
tags:
- k8s
- client-go
- code-generator
keywords:
- client-go
- client
- code-generator
#thumbnailImage: //example.com/image.jpg
---

client-go为我们提供了kubernetes原生资源的informer和clientset等等的访问,那么自定义资源如何操作呢? 本文将为你介绍..

<!--more-->

## code-generator

在使用kubernetes的过程中,使用到一定阶段不可避免的就是使用第三方资源,那么如果操作第三方资源就成了一个问题,虽然有client-go的方式操作,但是此方式只提供了rest api和 dynamic client来操作第三方资源,需要自己实现反序列化等功能.

那么我们不禁想问: 有没有一个更好的方法来做呢?

在kubernetes的源码中我们经常可以看到code-generator的身影,没错, 这工具就是来做这样一个事情的:

code-generator提供了以下工具为kubernetes中的资源生成代码:

`deepcopy-gen`: 生成深度拷贝方法,避免性能开销

`client-gen`:为资源生成标准的操作方法(get,list,create,update,patch,delete,deleteCollection,watch)

`informer-gen`: 生成informer,提供事件机制来相应kubernetes的event

`lister-gen`: 为get和list方法提供只读缓存层

其中informer和listers是构建controller的基础,kubebuilder也是基于informer的机制生成的代码.

code-generator还专门整合了这些gen,形成了[generate-groups.sh](https://github.com/kubernetes/code-generator/blob/master/generate-groups.sh)和[generate-internal-groups.sh](https://github.com/kubernetes/code-generator/blob/master/generate-internal-groups.sh)这两个脚本.

接下来我们就一起来使用这些脚本生成我们的自定义crd资源的代码.

## 演示

### 1,初始化项目

项目使用go.mod管理,所以在初始化项目的同时,我们需要初始化依赖库

```shell
#创建目录
$ mkdir code-generator-test && cd code-generator-test
#初始化项目
$ go mod init code-generator-test
# 获取依赖
$ go get k8s.io/apimachinery@v0.0.0-20190425132440-17f84483f500
$ go get k8s.io/client-go@v0.0.0-20190425172711-65184652c889
$ go get k8s.io/code-generator@v0.0.0-20190419212335-ff26e7842f9d
```

### 2,初始化crd资源类型

在初始化了项目后,需要建立好自己的crd struct,然后使用code-generator生成我们的代码.

```shell
$ mkdir -p api/samplecontroller/v1alpha1 && cd api/samplecontroller/v1alpha1
```

> 此处我们的自定义资源的group为`samplecontroller`,版本为`v1alpha1`

在文件夹中新建:

`doc.go`

```go
// +k8s:deepcopy-gen=package
// +groupName=samplecontroller.k8s.io

// v1alpha1版本的api包
package v1alpha1
```

`types.go`

```go
package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Foo is a specification for a Foo resource
type Foo struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   FooSpec   `json:"spec"`
	Status FooStatus `json:"status"`
}

// FooSpec is the spec for a Foo resource
type FooSpec struct {
	DeploymentName string `json:"deploymentName"`
	Replicas       *int32 `json:"replicas"`
}

// FooStatus is the status for a Foo resource
type FooStatus struct {
	AvailableReplicas int32 `json:"availableReplicas"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// FooList is a list of Foo resources
type FooList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata"`

	Items []Foo `json:"items"`
}

```

### 3,创建生成脚本

有了crd的定义后,我们需要准备我们的构建脚本和对依赖进行一定的修改.

```shell
$ mkdir hack && cd hack
```

建立`tools.go`来依赖`code-generator`,因为在没有代码使用code-generator时,go module 默认不会为我们依赖此包.

```go
// +build tools

/*
Copyright 2019 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// This package imports things required by build scripts, to force `go mod` to see them as dependencies
package tools

import _ "k8s.io/code-generator"
```

同时 编写我们的构建脚本:

`update-codegen.sh`

```shell
#!/usr/bin/env bash

# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

# generate the code with:
# --output-base    because this script should also be able to run inside the vendor dir of
#                  k8s.io/kubernetes. The output-base is needed for the generators to output into the vendor dir
#                  instead of the $GOPATH directly. For normal projects this can be dropped.
../vendor/k8s.io/code-generator/generate-groups.sh \
  "deepcopy,client,informer,lister" \
  code-generator-test/generated \
  code-generator-test/api \
  samplecontroller:v1alpha1 \
  --go-header-file $(pwd)/boilerplate.go.txt \
  --output-base $(pwd)/../../
```

可以看到`generate-groups.sh`其中有几个参数,使用命令可以看到如下:

```shell
Usage: generate-groups.sh <generators> <output-package> <apis-package> <groups-versions> ...

  <generators>        the generators comma separated to run (deepcopy,defaulter,client,lister,informer) or "all".
  <output-package>    the output package name (e.g. github.com/example/project/pkg/generated).
  <apis-package>      the external types dir (e.g. github.com/example/api or github.com/example/project/pkg/apis).
  <groups-versions>   the groups and their versions in the format "groupA:v1,v2 groupB:v1 groupC:v2", relative
                      to <api-package>.
  ...                 arbitrary flags passed to all generator binaries.


Examples:
  generate-groups.sh all             github.com/example/project/pkg/client github.com/example/project/pkg/apis "foo:v1 bar:v1alpha1,v1beta1"
  generate-groups.sh deepcopy,client github.com/example/project/pkg/client github.com/example/project/pkg/apis "foo:v1 bar:v1alpha1,v1beta1"
```

在构建api时,我们还提供了文件头,所以我们在此也创建文件头:

`boilerplate.go.txt`

```txt
/*
Copyright The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
```

当然,这个文件的头是可以定制的.

### 4,生成api

当我们做好这些准备工作后就可以开始生成我们的crd资源的clientset等api了.

```shell
# 生成vendor文件夹
$ go mod vendor
# 进入项目根目录,为vendor中的code-generator赋予权限
$ chmod -R 777 vendor
# 调用脚本生成代码
$ cd hack && ./update-codegen.sh
Generating deepcopy funcs
Generating clientset for samplecontroller:v1alpha1 at code-generator-test/generated/clientset
Generating listers for samplecontroller:v1alpha1 at code-generator-test/generated/listers
Generating informers for samplecontroller:v1alpha1 at code-generator-test/generated/informers

#此时目录变为如下情况
$cd ../ && tree -L 3
.
├── api
│   └── samplecontroller
│       └── v1alpha1
├── generated
│   ├── clientset
│   │   └── versioned
│   ├── informers
│   │   └── externalversions
│   └── listers
│       └── samplecontroller
├── go.mod
├── go.sum
├── hack
│   ├── boilerplate.go.txt
│   ├── tools.go
│   └── update-codegen.sh
```

仔细观察,发现`code-generator-test/api/samplecontroller/v1alpha1`下多出了一个`zz_generated.deepcopy.go`的文件,在`generated`文件夹下生成了`clientset`和`informers`和`listers`三个文件夹

### 5,使用

在生成了客户端代码后,我们还是需要手动的注册这个crd资源,才能正真使用这个client,不然在编译时会出现如下错误

```shell
# code-generator-test/generated/clientset/versioned/scheme
generated/clientset/versioned/scheme/register.go:35:2: undefined: v1alpha1.AddToScheme
# code-generator-test/generated/listers/samplecontroller/v1alpha1
generated/listers/samplecontroller/v1alpha1/foo.go:92:34: undefined: v1alpha1.Resource
```

由编译的错误提示,可以看到,需要提供`v1alpha1.AddToScheme`和`v1alpha1.Resource`这两个变量供client注册.

所以我们还需要在`v1alpha1`下新建一个`register.go`文件,内容如下:

```go
/*
Copyright 2017 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

// SchemeGroupVersion is group version used to register these objects
// 注册自己的自定义资源
var SchemeGroupVersion = schema.GroupVersion{Group: "samplecontroller.k8s.io", Version: "v1alpha1"}

// Kind takes an unqualified kind and returns back a Group qualified GroupKind
func Kind(kind string) schema.GroupKind {
	return SchemeGroupVersion.WithKind(kind).GroupKind()
}

// Resource takes an unqualified resource and returns a Group qualified GroupResource
func Resource(resource string) schema.GroupResource {
	return SchemeGroupVersion.WithResource(resource).GroupResource()
}

var (
	SchemeBuilder = runtime.NewSchemeBuilder(addKnownTypes)
	AddToScheme   = SchemeBuilder.AddToScheme
)

// Adds the list of known types to Scheme.
func addKnownTypes(scheme *runtime.Scheme) error {
	//注意,添加了foo/foolist 两个资源到scheme
	scheme.AddKnownTypes(SchemeGroupVersion,
		&Foo{},
		&FooList{},
	)
	metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
	return nil
}
```

其中需要修改的地方我都用中文注释出来了.

### 6,测试

在完成以上的工作后,我们可以写一个测试函数来测试,示例代码如下:

```go
package main

import (
	"code-generator-test/generated/clientset/versioned"
	"code-generator-test/generated/clientset/versioned/typed/samplecontroller/v1alpha1"
	"code-generator-test/generated/informers/externalversions"
	"fmt"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/tools/clientcmd"
	"testing"
	"time"
)

func TestClient(t *testing.T) {
    config, e := clientcmd.BuildConfigFromFlags("10.30.21.238:6443", "/home/tangxu/.kube/config")
	if e != nil {
		panic(e.Error())
	}
    //注意,这里使用的是v1alpha1这个包
	client, e := v1alpha1.NewForConfig(config)
	if e != nil {
		panic(e.Error())
	}
	fooList, e := client.Foos("test").List(metav1.ListOptions{})
	fmt.Println(fooList, e)

    //注意 这里的versioned包
	clientset, e := versioned.NewForConfig(config)
	factory := externalversions.NewSharedInformerFactory(clientset, 30*time.Second)
	foo, e := factory.Samplecontroller().V1alpha1().Foos().Lister().Foos("test").Get("test")
	if e != nil {
		panic(e.Error())
	}
	fmt.Println(foo, e)
}
```

通过上面的示例,我们就可以看到我们的clientset和informer使用方式和原生的kubernetes的资源使用方式一模一样了.

## tag

在实际的操作了一个生成crd的client之后,是不是觉得crd整体的生成下来还是相对简单的.

不过在我们使用的时候不知道是否有关注到这样一个细节,在我们的源代码中出现了很多

`doc.go`

```go
// +k8s:deepcopy-gen=package,register
// +groupName=samplecontroller.k8s.io
```

`types.go`

```go
// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
```

出现了这样的tag,这些tag到底是什么意思呢,有什么作用呢?

### 分类

其实code-generator将tag分为了两种,

`Global tags`: 全局的tag,放在具体版本的doc.go文件中

`Local tags`: 本地的tag,放在types.go文件中的具体的struct上.

tag的使用语法为:

```go
// +tag-name 
或
// +tag-name=value
```

并且 这些注释块必须分开,**这也是源代码中 注释存在分割的原因.** 接下来,详细了解一下这两个文件中的注释吧..

### Global 

全局的tag是写在doc.go中的,典型的内容如下:

```go
// +k8s:deepcopy-gen=package


// Package v1 is the v1 version of the API.
// +groupName=example.com
package v1
```

> 注意: 空行不能省

`+k8s:deepcopy-gen=`: 它告诉deepcopy默认为该包中的每一个类型创建deepcopy方法

如果不需要深度复制,可以选择关闭此功能`// +k8s:deepcopy-gen=false`

如果不启用包级别的深度复制,那么就需要在每个类型上加入深度复制`// +k8s:deepcopy-gen=true`

`+groupName`: 定义group的名称,注意别弄错了.

> 注意 这里是 **+k8s:deepcopy-gen=**,最后是 **=** ,和local中的区别开来.

### local

本地的tag直接写在类型上,典型的内容如下:

```go
// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Foo is a specification for a Foo resource
type Foo struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   FooSpec   `json:"spec"`
	Status FooStatus `json:"status"`
}
```

可以看到local支持两种tag

`+genclient`: 此标签是告诉client-gen,为此类型创建clientset,但也有以下几种用法.

**1,**对于集群范围内的资源(没有namespace限制的),需要使用`// +genclient:nonNamespaced`,生成的clientset中的namespace()方法就不再需要传入参数

**2,**使用子资源分离的,例如/status分离的,则需要使用`+genclient:noStatus`,来避免更新到status资源(当然代码的struct中也没有status)

**3,**对于其他的值,这里不做过多的解释,请参照

```go
// +genclient:noVerbs
// +genclient:onlyVerbs=create,delete
// +genclient:skipVerbs=get,list,create,update,patch,delete,deleteCollection,watch
// +genclient:method=Create,verb=create,result=k8s.io/apimachinery/pkg/apis/meta/v1.Status
```

`+k8s:deepcopy-gen:interfaces=`: 为struct生成实现 `tag值`的DeepCopyXxx方法

例如:`// +k8s:deepcopy-gen:interfaces=example.com/pkg/apis/example.SomeInterface`

将生成 `DeepCopySomeInterface() SomeInterface`方法



## 参照

[Kubernetes Deep Dive: Code Generation for CustomResources](https://blog.openshift.com/kubernetes-deep-dive-code-generation-customresources/)

[code-generator](https://github.com/kubernetes/code-generator)

[示例工程代码](https://github.com/tangxusc/code-generator-demo)

[sample controller](https://github.com/kubernetes/sample-controller)

