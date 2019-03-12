### 安装
```
helm init --upgrade -i registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.11.0 --stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts --service-account=clusterrole-aggregation-controller
```
### 卸载
```
helm reset 或helm reset -f(强制删除 k8s 集群上的 pod.)
```
### 添加仓库
```
helm repo add fabric8 https://fabric8.io/helm
helm repo update
helm repo list
```
### 搜索
```
helm search fabric8
```
### 安装应用
```
helm install monocular/monocular -f custom-repos.yaml
```

### 应用列表
```
helm list
```
### 删除应用
```
helm delete release名字
```