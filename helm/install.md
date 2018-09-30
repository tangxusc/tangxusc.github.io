###安装
```
helm init --upgrade -i registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.8.2 --stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
```
###卸载
```
helm reset 或helm reset -f(强制删除 k8s 集群上的 pod.)
```
###添加仓库
```
helm repo add fabric8 https://fabric8.io/helm
```
###搜索
```
helm search fabric8
```
###安装应用
```
helm install monocular/monocular -f custom-repos.yaml
```