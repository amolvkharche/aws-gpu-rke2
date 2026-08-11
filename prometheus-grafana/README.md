#### Install promotheus and grafana
Add the repository and create namespace
```
helm repo add prometheus-community  https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
```
Now apply values.yaml file 
Then install:
```
helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --values prometheus-grafana-values.yaml
```
Check pods, You should eventually see Grafana and Prometheus running:
```
kubectl get pods -n monitoring

grafana-xxxxxxxxxx                         3/3     Running
monitoring-kube-prometheus-stack-prometheus-0   2/2     Running
monitoring-kube-prometheus-stack-operator-...   1/1     Running
```
