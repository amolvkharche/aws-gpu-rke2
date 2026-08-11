### Install promotheus and grafana
Add the repository and create namespace
```
helm repo add prometheus-community  https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
```
Now apply values.yaml file.
Then install:
```
helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --values prometheus-grafana/prometheus-grafana-values.yaml
```
Check pods, You should eventually see Grafana and Prometheus running:
```
kubectl get pods -n monitoring

grafana-xxxxxxxxxx                         3/3     Running
monitoring-kube-prometheus-stack-prometheus-0   2/2     Running
monitoring-kube-prometheus-stack-operator-...   1/1     Running
```

Replace your NODEIP with your actual IP.
Apply:
```
kubectl apply -f prometheus-grafana/grafana-ingress.yaml
```
check `kubectl get ingress -n monitoring`

If your node IP is `3.110.20.50` open: `http://grafana.3-110-20-50.sslip.io`
Default username is `admin` and password can be obtain from below command.
```
kubectl get secret \
  -n monitoring monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d

echo
```

ServiceMonitor yaml file already created for the NVIDIA DCGM exporter. Check labels and port of DCGM exporter service.
```
kubectl get svc nvidia-dcgm-exporter -n gpu-operator --show-labels
```
Apply serviceMonitor yaml file
```
kubectl apply -f prometheus-grafana/dcgm-servicemonitor.yaml
```
Check:
```
kubectl get servicemonitor -n monitoring
```
You should see:
```
NAME                    AGE
nvidia-dcgm-exporter    10s
```
Log in.

Go to Grafana -> Connections → Data sources
You should see: Prometheus -> Click it. The URL should look similar to:
```
http://monitoring-kube-prometheus-prometheus.monitoring.svc:9090
```
Grafana is running inside Kubernetes, so localhost would mean the Grafana container itself. Grafana must use the Kubernetes Service name to reach Prometheus.

If Prometheus is NOT then Go to: -> Connections → Data sources → Add new data source Select: Prometheus
For the URL, use:
```
http://monitoring-kube-prometheus-stack-prometheus.monitoring.svc:9090
```
Then Save & test.

Now import the GPU dashboard Go to: Dashboards → New → Import Enter: `24989` Click: Load

<img width="2534" height="1185" alt="image" src="https://github.com/user-attachments/assets/cb71ba86-3993-4c6f-ac22-562742bc373d" />

