echo '开始安装 helm'
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.13.0-linux-amd64.tar.gz && tar -zxvf helm-v2.13.0-linux-amd64.tar.gz && export PATH=$PATH:$pwd/linux-amd64/
helm init --upgrade -i registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.13.0 --stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts --service-account=clusterrole-aggregation-controller
helm repo add rook-stable https://charts.rook.io/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

echo '开始安装 kubeapp'
helm install --name kubeapps --namespace kubeapps bitnami/kubeapps
kubectl create serviceaccount kubeapps-operator
kubectl create clusterrolebinding kubeapps-operator --clusterrole=cluster-admin --serviceaccount=default:kubeapps-operator
export kubeappsPWD=$( kubectl get secret $(kubectl get serviceaccount kubeapps-operator -o jsonpath='{.secrets[].name}') -o jsonpath='{.data.token}' | base64 --decode )

echo '开始安装 rook'
helm install --name rook-ceph-system --namespace rook-ceph-system rook-stable/rook-ceph --set hyperkube.repository=tangxusc/docker-image
kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init/rook-cluster.yaml
export rookcephPWD=$( kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o yaml | grep "password:" | awk '{print $2}' | base64 --decode )

echo '开始安装 efk'
kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init-cn/efk-elasticsearch.yaml
kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init-cn/efk-fluentd.yaml
kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init-cn/efk-kibana.yaml

echo '开始安装 prometheus'
helm install --name prometheus --namespace prometheus stable/prometheus --set alertmanager.persistentVolume.storageClass=rook-ceph-block --set kubeStateMetrics.enabled=false --set pushgateway.enabled=false --set server.persistentVolume.storageClass=rook-ceph-block

echo '开始安装 metrics'
helm install --name metrics --namespace metrics bitnami/metrics-server --set apiService.create=false

echo '开始安装 jaeger'
kubectl create namespace observability
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/crds/jaegertracing_v1_jaeger_crd.yaml
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/service_account.yaml
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role.yaml
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role_binding.yaml
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/operator.yaml

kubectl apply -f https://gitee.com/tanx/kubernetes-test/raw/master/kubernetes/init/jaeger-instance.yaml

echo '开始安装 dashboard'
helm install --name dashboard --namespace kube-system stable/kubernetes-dashboard --set image.repository=rancher/kubernetes-dashboard-amd64
export dashboardSecret=$( kubectl get serviceaccount clusterrole-aggregation-controller -n kube-system -o jsonpath='{.secrets[].name}' )
export dashboardPWD=$(kubectl get secret $dashboardSecret -o jsonpath='{.data.token}' -n kube-system)

echo 'dashboard 密码:'
echo $dashboardPWD

echo 'kubeapp 密码:'
echo $kubeappsPWD

echo 'rook 密码:'
echo $rookcephPWD