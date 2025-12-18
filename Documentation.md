## 1. Cloud Provider

This lab was conducted on **Google Cloud Platform (GCP)**, which served as the target execution environment. A **dedicated GCP project** was created specifically for the experiments.



## 2. Kubernetes Cluster Setup

The Kubernetes cluster was deployed using **Google Kubernetes Engine (GKE)** in **standard mode**.

The standard mode was deliberately chosen over **Autopilot mode** in order to retain **full control over cluster configuration**.

In contrast, **Autopilot mode** abstracts away node management and automatically provisions resources. While convenient, this abstraction hides the impact of misconfigured resource requests and limits the pedagogical value of experiments centered on resource management.



## 3. Cluster Configuration

### 3.1. Creating the cluster 

To ensure a consistent and repeatable setup, a shell script was used to automate the creation and configuration of the GKE cluster.
The script provisions a new Kubernetes cluster using default GKE settings.

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================
# Configuration
# ============================
PROJECT_ID="cloud-computing-478110"
REGION="europe-west1"
ZONE="europe-west1-b"
CLUSTER_NAME="prodigy-cluster"

echo "Setting GCP project"
gcloud config set project "$PROJECT_ID"

echo "Setting default region"
gcloud config set compute/region "$REGION"

echo "Setting default zone"
gcloud config set compute/zone "$ZONE"

echo "Creating GKE cluster: $CLUSTER_NAME"
gcloud container clusters create "$CLUSTER_NAME"

echo " Fetching cluster credentials"
gcloud container clusters get-credentials "$CLUSTER_NAME"

echo "Cluster nodes:"
kubectl get nodes
```
---

### 3.2. Cluster Environment Overview

▶ We start by running this command to get information about the `worker` nodes of this cluster: 
```bash
kubectl get nodes -o wide
```

<pre>
NAME                                             STATUS   ROLES    AGE     VERSION               INTERNAL-IP   EXTERNAL-IP     OS-IMAGE                             KERNEL-VERSION   CONTAINER-RUNTIME
gke-prodigy-cluster-default-pool-30fddad3-bf4k   Ready    &lt;none&gt;   8m40s   v1.33.5-gke.1308000   10.132.0.15   34.22.190.69    Container-Optimized OS from Google   6.6.105+         containerd://2.0.6
gke-prodigy-cluster-default-pool-30fddad3-bllw   Ready    &lt;none&gt;   8m39s   v1.33.5-gke.1308000   10.132.0.16   34.22.254.228   Container-Optimized OS from Google   6.6.105+         containerd://2.0.6
gke-prodigy-cluster-default-pool-30fddad3-m1br   Ready    &lt;none&gt;   8m40s   v1.33.5-gke.1308000   10.132.0.17   35.187.27.7     Container-Optimized OS from Google   6.6.105+         containerd://2.0.6
</pre>

   - The output shows the three `default worker` nodes automatically created during the GKE cluster initialization.

▶ We now run the command below to display the **`total`** hardware CPU and memory capacity of each node.
```bash
kubectl get nodes \
  -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory
```
<pre>
NAME                                             CPU   MEMORY
gke-prodigy-cluster-default-pool-30fddad3-bf4k   2     4015664Ki
gke-prodigy-cluster-default-pool-30fddad3-bllw   2     4015664Ki
gke-prodigy-cluster-default-pool-30fddad3-m1br   2     4015664Ki
</pre>

  - Each default worker node is provisioned with 2 vCPUs and approximately 4 GiB of memory, providing a uniform resource capacity across the cluster.

▶ We now run the command below to display the **`allocatable`** (schedulable) CPU and memory for each node.
```bash
kubectl get nodes \
-o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory
```
<pre>
NAME                                             CPU    MEMORY
gke-prodigy-cluster-default-pool-30fddad3-bf4k   940m   2869808Ki
gke-prodigy-cluster-default-pool-30fddad3-bllw   940m   2869808Ki
gke-prodigy-cluster-default-pool-30fddad3-m1br   940m   2869808Ki
</pre>

  - Although each node has 2 vCPUs and ~4 GiB of memory, only 940 mCPU and ~2.7 GiB are allocatable per node, with the remaining resources reserved by the system and Kubernetes components.

## 4. Initial Deployment Using the Base Configuration

### 4.1. Deploying the application with `Kustomize`

Google's `microservices-demo` repository already provided the **`Base configuration`** in the `kustomize` Folder.

The base configuration corresponds to the default Kubernetes manifests provided by Google for deploying the Online Boutique application. 
It defines all microservices composing the application, including auxiliary components such as the load generator, using predefined resource requests and limits. 
No changes were applied to this configuration during the initial deployment, allowing the cluster behavior to be observed under the original, unmodified setup.

▶ To deploy Google's Online Boutique microservice architecture application: 

```bash
cd microservices-demo/kustomize/
```
```bash
kubectl kustomize .
```
- The `kubectl kustomize .` command was executed to generate the final Kubernetes manifests derived from the base Kustomize configuration. This command allows the rendered configuration to be inspected before deployment.

```bash
kubectl apply -k .
```
- The application was then deployed using `kubectl apply -k` ., which applies the manifests generated by Kustomize to the Kubernetes cluster.
- After deployment, the state of the application was observed to assess whether all microservices were successfully scheduled on the cluster.
---
### 4.2. Observed Behavior

▶ We start by displaying the state of the pods: 
```bash
kubectl get pods
```
<pre>
NAME                                     READY   STATUS    RESTARTS   AGE
adservice-b4856c769-bbjpd                1/1     Running   0          106m
cartservice-5784f94fb6-pb7d6             1/1     Running   0          106m
checkoutservice-56c5cffd57-smpgs         1/1     Running   0          106m
currencyservice-66c885779c-4cq4p         1/1     Running   0          106m
emailservice-bc487bdb7-p56xh             1/1     Running   0          106m
frontend-5965c589c8-22xnx                1/1     Running   0          106m
loadgenerator-79fb484559-hhpqw           0/1     Pending   0          106m
paymentservice-656fb48df5-c75r2          1/1     Running   0          106m
productcatalogservice-5db55dcfbc-jggml   1/1     Running   0          106m
recommendationservice-7f8c5fcbff-tm7p5   1/1     Running   0          106m
redis-cart-c4fc658fb-nmgxj               1/1     Running   0          106m
shippingservice-7fdc84f79-8h4vp          0/1     Pending   0          106m
</pre>

- The output shows that most microservices were successfully started and reached the `Running` state.
- However, two Pods did not reach the Running state and remained in the `pending` status :
    -  loadgenerator service
    -  shipping service
- At this stage, the deployment did not fully succeed, since not all Pods were scheduled onto worker nodes. The presence of Pods in the Pending state indicates that Kubernetes was unable to place these Pods on any available node in the cluster.
- This observation motivated a deeper investigation of the scheduling behavior and resource constraints of the cluster, which is discussed in the following section.
---
### 4.3. Analysis of the Scheduling Failure
▶ We start by observing the state of the `ShippingService`:
```bash
kubectl describe pod shippingservice-7fdc84f79-8h4vp
```
<pre>
Events:
  Type     Reason             Age                      From                Message
  ----     ------             ----                     ----                -------
  Warning  FailedScheduling   5m23s (x34 over 170m)    default-scheduler   0/3 nodes are available: 3 Insufficient cpu. preemption: 0/3 nodes are available: 3 No preemption victims found for incoming pod.
  Normal   NotTriggerScaleUp  2m35s (x1022 over 175m)  cluster-autoscaler  Pod didn't trigger scale-up:
</pre>

- We observe a warning from the `default-scheduler` stating that the `ShippingService` could not be deployed. The two reasons being: 
    -  Kubernetes was unable to schedule the Pod on any of the available worker nodes due to insufficient allocatable CPU resources
    -  No existing Pods could be preempted to make room for the incoming Pod.
- We also observe from the `cluster-autoscaler` that the pod did not trigger a **`ScaleUp`**  .
    - This behavior is expected, as the cluster was created with a fixed size and autoscaling was not configured to add new nodes.

▶We further inspect the base configuration manifest of the `ShippingService` pod: 
```bash
cd kustomize/base/
cat shippingservice.yaml
```

<pre>
resources:
        requests:
            cpu: 100m
            memory: 64Mi
        limits:
            cpu: 200m
            memory: 128Mi
</pre>
- A **`CPU limit`** represents the maximum amount of CPU time a container is allowed to consume at `runtime` and is enforced by the Linux kernel through cgroup-based throttling
- A **`CPU request`** is the amount of CPU time a container declares so that Kubernetes can decide where the Pod can be scheduled and how CPU time should be fairly shared under contention; it represents a relative weight for CPU access, not a guaranteed continuous allocation.
- When Kubernetes decides whether it can deploy (schedule) a Pod onto a worker node, it considers resource `requests` only.
- kubernetes deploys a pod on a node if and only if this inequality is satisfied :
  <pre>
  (sum of CPU requests of running Pods)+ (CPU request of new Pod)≤(node allocatable CPU)
  </pre>
▶In this case, the `shippingservice` Pod requests `100 millicores` of CPU. Given the limited CPU capacity of the nodes and the cumulative CPU requests of the already running Pods, this condition could not be satisfied, resulting in the Pod remaining in the `Pending` state.

## 5. Reconfiguration of the Application Using Kustomize
