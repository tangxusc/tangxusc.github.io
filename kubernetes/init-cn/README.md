## 自动部署k8s基础应用

在k8s集群安装完成后,我们需要为集群安装很多初始应用,此处通过一个简易脚本方式安装以下应用:

- helm-tiller
- kubeapp
- rook
- rook-cluster
- elasticsearch-fluentd-kinaba
- prometheus
- metrics-server
- jaeger
- dashboard

该脚本使用如下:

```shell
curl https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init/init.sh | sh
```

对于国内用户,推荐使用`cn`脚本:

```shell
curl https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init-cn/init.sh | sh
```

## 脚本说明

### helm-tiller

```shell
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.13.0-linux-amd64.tar.gz && tar -zxvf helm-v2.13.0-linux-amd64.tar.gz && sudo cp linux-amd64/helm /usr/local/bin
helm init --upgrade -i registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.13.0 --stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts --service-account=clusterrole-aggregation-controller
helm repo add rook-stable https://charts.rook.io/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### kubeapp

```shell
helm install --name kubeapps --namespace kubeapps bitnami/kubeapps
kubectl create serviceaccount kubeapps-operator
kubectl create clusterrolebinding kubeapps-operator --clusterrole=cluster-admin --serviceaccount=default:kubeapps-operator
export kubeappsPWD=$( kubectl get secret $(kubectl get serviceaccount kubeapps-operator -o jsonpath='{.secrets[].name}') -o jsonpath='{.data.token}' | base64 --decode )

```

### rook

```shell
helm install --name rook-ceph-system --namespace rook-ceph-system rook-stable/rook-ceph --set hyperkube.repository=tangxusc/docker-image

sleep 3m

kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init/rook-cluster.yaml

sleep 3m

export rookcephPWD=$( kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o yaml | grep "password:" | awk '{print $2}' | base64 --decode )

```

在此需要注意的是,rook脚本停顿的时间很长,因为需要保证rook operator启动完成

> rook需要至少三个node

### elasticsearch-fluentd-kinaba

```shell
kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init-cn/efk-elasticsearch.yaml
kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init-cn/efk-fluentd.yaml
kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init-cn/efk-kibana.yaml
```

### prometheus

```shell
helm install --name prometheus --namespace prometheus stable/prometheus --set alertmanager.persistentVolume.storageClass=rook-ceph-block --set kubeStateMetrics.enabled=false --set pushgateway.enabled=false --set server.persistentVolume.storageClass=rook-ceph-block
```

### metrics

```shell
helm install --name metrics --namespace metrics bitnami/metrics-server --set apiService.create=true
```

### jaeger

```shell
kubectl create namespace observability
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/crds/jaegertracing_v1_jaeger_crd.yaml
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/service_account.yaml
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role.yaml
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role_binding.yaml
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/operator.yaml

kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init/jaeger-instance.yaml
```

### dashboard

```shell
helm install --name dashboard --namespace kube-system stable/kubernetes-dashboard --set image.repository=rancher/kubernetes-dashboard-amd64
export dashboardSecret=$( kubectl get serviceaccount clusterrole-aggregation-controller -n kube-system -o jsonpath='{.secrets[].name}' )
export dashboardPWD=$(kubectl get secret $dashboardSecret -o jsonpath='{.data.token}' -n kube-system)
```

### 输出密码

```shell
echo 'dashboard 密码:'
echo $dashboardPWD

echo 'kubeapp 密码:'
echo $kubeappsPWD

echo 'rook 密码:'
echo $rookcephPWD
```

