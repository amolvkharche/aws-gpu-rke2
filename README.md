## AWS RKE2 GPU Cluster with NVIDIA GPU Operator

Terraform setup to provision a Kubernetes cluster on AWS using **RKE2 (Rancher Kubernetes Engine 2)**, featuring full GPU acceleration via the **NVIDIA GPU Operator** and a self-hosted LLM inference stack (**Ollama + Open WebUI**).

### Architecture & Component Overview

* **Cloud Provider:** AWS (VPC, Public Subnets, Security Groups, Internet Gateway).
* **Control Plane Node:** Ubuntu 22.04 LTS running RKE2 Control Plane (`t3.medium`).
* **GPU Worker Node:** Ubuntu 22.04 LTS running RKE2 Agent on an AWS GPU instance (`g4dn.xlarge` with NVIDIA Tesla T4 15GB GPU).
* **Ingress Controller:** Built-in RKE2 Traefik Ingress Controller with dynamic `sslip.io` DNS routing.
* **GPU Stack:** NVIDIA GPU Operator (Helm) hooked into RKE2's internal `containerd` runtime socket (`/run/k3s/containerd/containerd.sock`) to manage driver compilation, container toolkit, device plugin, and DCGM metrics exporter.
* **AI Application Stack:** 
  * **Ollama:** Serves local LLM models (e.g., `llama3.2`) with persistent host storage and hardware acceleration.
  * **Open WebUI:** Provides a user-friendly, ChatGPT-like web interface accessible via Traefik Ingress.

### Repository Structure

```text
.
├── cloud-init
│   ├── agent.yaml
│   ├── server-join.yaml
│   └── server.yaml
├── data.tf
├── gpu_operator.tf
├── main.tf
├── manifests
│   ├── 01-ollama.yaml
│   └── 02-open-webui.yaml
├── outputs.tf
├── providers.tf
├── terraform.tfvars
├── variables.tf
└── vpc.tf
```

#### Prerequisites
Ensure you have the following tools installed and configured on your local machine:
1) Terraform
2) kubectl

#### Clone the Repository
```bash
git clone https://github.com/amolvkharche/aws-gpu-rke2.git
cd aws-gpu-rke2
```
Rename terraform.tfvars.example file replace AWS access and secret key

```bash
mv terraform.tfvars.example terraform.tfvars
```
Initialize Terraform and apply the configuration:
```bash
terraform init
terraform apply -auto-approve
```

#### Verifying GPU Functionality
```bash
# kubectl get pods -n gpu-operator 
NAME                                                          READY   STATUS      RESTARTS   AGE
gpu-feature-discovery-x7bhp                                   1/1     Running     0          7m6s
gpu-operator-785867df84-ng7w9                                 1/1     Running     0          7m31s
gpu-operator-node-feature-discovery-gc-8fb8d5d8d-jvh2x        1/1     Running     0          7m31s
gpu-operator-node-feature-discovery-master-5bbc6d887b-hx4vv   1/1     Running     0          7m31s
gpu-operator-node-feature-discovery-worker-6plsw              1/1     Running     0          7m31s
gpu-operator-node-feature-discovery-worker-hjj2q              1/1     Running     0          7m31s
gpu-operator-node-feature-discovery-worker-pr9jx              1/1     Running     0          7m31s
nvidia-container-toolkit-daemonset-j2xdp                      1/1     Running     0          7m6s
nvidia-cuda-validator-tnz44                                   0/1     Completed   0          83s
nvidia-dcgm-exporter-hvhg6                                    1/1     Running     0          7m6s
nvidia-device-plugin-daemonset-mz85g                          1/1     Running     0          7m6s
nvidia-driver-daemonset-lx7vl                                 1/1     Running     0          7m20s
nvidia-operator-validator-lbp7g                               1/1     Running     0          7m6s
```
Verify GPU Resource Allocation

```bash
kubectl describe nodes | grep -A 6 "Capacity:"
```

Deploy a sample Ollama app to consume GPU resources
```bash
kubectl apply -f manifests/01-ollama.yaml
kubectl apply -f manifests/02-open-webui.yaml
```
Download & Test an LLM (Llama 3.2)
Pull Model via CLI
```
kubectl exec -it deploy/ollama -- ollama pull llama3.2
```
Access ollama webUI with `http://chat.YOUR_SERVER_PUBLIC_IP.sslip.io`

Verify GPU Utilization you will see similar output

```
$ kubectl exec -n gpu-operator -it daemonset/nvidia-driver-daemonset -c nvidia-driver-ctr -- nvidia-smi

Mon Aug 10 05:00:54 2026       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.126.20             Driver Version: 580.126.20     CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  Tesla T4                       On  |   00000000:00:1E.0 Off |                    0 |
| N/A   43C    P0             29W /   70W |    2567MiB /  15360MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0   N/A  N/A           42912      C   /usr/lib/ollama/llama-server           2564MiB |
+-----------------------------------------------------------------------------------------+
```
### Destroying Infrastructure
```
terraform destroy -auto-approve
```
