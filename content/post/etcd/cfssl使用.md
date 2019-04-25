---
title: "使用Cfssl生成etcd证书(pem)"
date: 2019-04-25T13:56:22+08:00
categories:
- k8s
tags:
- cfssl
keywords:
- cfssl
#thumbnailImage: //example.com/image.jpg
---

CFSSL是CloudFlare开源的一款PKI/TLS工具,CFSSL包含一个`命令行工具`和一个用于`签名`，验证并且捆绑TLS证书的`HTTP API服务`,使用Go语言编写.

github: https://github.com/cloudflare/cfssl

下载地址: https://pkg.cfssl.org/

<!--more-->

在使用etcd,kubernetes等组件的过程中会大量接触到证书的生成和使用,本文将详细说明创建etcd的证书

## 安装

```shell
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 
wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
chmod +x cfssl*
```

## 获取默认配置

```shell
cfssl print-defaults config > ca-config.json
cfssl print-defaults csr > ca-csr.json
```

`ca-config.json`文件内容如下:

```json
{
    "signing": {
        "default": {
            "expiry": "168h"
        },
        "profiles": {
            "www": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            }
        }
    }
}
```

`ca-csr.json`内容如下:

```json
{
    "CN": "example.net",
    "hosts": [
        "example.net",
        "www.example.net"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
```

## 生成ca证书

将`ca-config.json`内容修改为:

```json
{
    "signing":{
        "default":{
            "expiry":"876000h"
        },
        "profiles":{
            "etcd":{
                "usages":[
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ],
                "expiry":"876000h"
            }
        }
    }
}
```

修改`ca-csr.json`文件内容为:

```json
{
  "CN": "CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "shenzhen",
      "L": "shenzhen",
      "O": "etcd",
      "OU": "System"
    }
  ]
}
```

> "CN"：Common Name，etcd 从证书中提取该字段作为请求的用户名 (User Name)；浏览器使用该字段验证网站是否合法；
> "O"：Organization，etcd 从证书中提取该字段作为请求用户所属的组 (Group)；

> 注意,**在k8s中**: 这两个参数在后面的kubernetes启用RBAC模式中很重要，因为需要设置kubelet、admin等角色权限，那么在配置证书的时候就必须配置对了，具体后面在部署kubernetes的时候会进行讲解。

修改好配置文件后,接下来就可以生成ca证书了

```shell
$ cfssl gencert -initca ca-csr.json | cfssljson -bare ca
2019/04/25 15:02:45 [INFO] generating a new CA key and certificate from CSR
2019/04/25 15:02:45 [INFO] generate received request
2019/04/25 15:02:45 [INFO] received CSR
2019/04/25 15:02:45 [INFO] generating key: rsa-2048
2019/04/25 15:02:46 [INFO] encoded CSR
2019/04/25 15:02:46 [INFO] signed certificate with serial number 391082240034344424489077238735720834723237930875
```

此时目录下会出现三个文件:

```shell
$ tree
├── ca-config.json #这是刚才的json
├── ca.csr
├── ca-csr.json    #这也是刚才申请证书的json
├── ca-key.pem
├── ca.pem
```

这样 我们就生成了:

- 根证书文件: `ca.pem`
- 根证书私钥: `ca-key.pem`
- 根证书申请文件: `ca.csr`  (csr是不是client ssl request?)

## 签发证书

创建`etct-csr.json`,内容为:

```json
{
  "CN": "etcd",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "hosts": [
    "example.net",	#此处为etcd地址,可以多个
    "www.example.net"
  ],
  "names": [
    {
      "C": "CN",
      "ST": "shenzhen",
      "L": "shenzhen",
      "O": "etcd",
      "OU": "System"
    }
  ]
}
```

使用之前的ca证书签发etcd证书:

```shell
$ cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=etcd etcd-csr.json | cfssljson -bare etcd

2019/04/25 15:29:57 [INFO] generate received request
2019/04/25 15:29:57 [INFO] received CSR
2019/04/25 15:29:57 [INFO] generating key: rsa-2048
2019/04/25 15:29:57 [INFO] encoded CSR
2019/04/25 15:29:57 [INFO] signed certificate with serial number 298100304200846379445095267906256802955283756560
2019/04/25 15:29:57 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
```

此时目录下会多几个文件:

```shell
$ tree -L 1
├── etcd.csr
├── etcd-csr.json
├── etcd-key.pem
├── etcd.pem
```

至此,etcd的证书生成完成.

## 启动etcd

```shell
./etcd
--name etcd1 \
  --cert-file=/etcd.pem \
  --key-file=/etcd-key.pem \
  --peer-cert-file=/etcd.pem \
  --peer-key-file=/etcd-key.pem \
  --trusted-ca-file=/ca.pem \
  --peer-trusted-ca-file=/ca.pem \
  --initial-advertise-peer-urls http://127.0.0.1:2380 \
  --listen-peer-urls http://127.0.0.1:2380 \
  --listen-client-urls http://127.0.0.1:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://127.0.0.1:2379 \
  --initial-cluster-token etcd-cluster-token \
  --initial-cluster etcd1=https://172.16.5.81:2380,infra2=https://172.16.5.86:2380,infra3=https://172.16.5.87:2380 \
  --initial-cluster-state new \
  --data-dir=/etcd-data
```

