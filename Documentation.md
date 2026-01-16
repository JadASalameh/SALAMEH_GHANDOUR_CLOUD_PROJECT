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
set -euo pipefail

# ============================
# Configuration
# ============================
PROJECT_ID="cloud-computing-478110"
REGION="europe-west6"
ZONE="europe-west6-a"
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

### 5.1. Motivation for Reconfiguration

- The analysis presented in the previous sections showed that the base configuration of the Online Boutique application could not be fully scheduled on the default GKE cluster due to insufficient allocatable CPU resources. In particular, some Pods remained in the `Pending state` because the cumulative CPU requests exceeded the capacity of the worker nodes
  
- To address this issue while preserving a clean and reproducible configuration workflow, the application was reconfigured using `Kustomize`, **`without`** modifying the original base manifests provided by Google.

### 5.2. Use of Kustomize Overlays

- Kustomize provides a structured way to customize Kubernetes manifests through the use of overlays, which allow environment-specific changes to be applied on top of a base configuration.
  
- An overlay was created to define a modified deployment configuration suitable for the available cluster resources. This approach ensures that:
   - the base configuration remains unchanged,
   -  modifications are explicitly documented,
   -  and the deployment process remains reproducible.
 - The overlay references the base configuration and applies a set of targeted changes, which are described in the following subsections.

### 5.3. Removal of the Load Generator from the Cluster

- The base configuration of the Online Boutique application includes a `loadgenerator service`, which is used to generate synthetic traffic for testing purposes. This service is not part of the core application logic and continuously consumes CPU resources.
  
-  Deploying the load generator within the same Kubernetes cluster as the application under test introduces unnecessary resource contention and interferes with the evaluation of the application’s behavior under realistic conditions. For this reason, the load generator was **`removed`** from the cluster as part of the reconfiguration.
  
- This removal was performed declaratively using a **`Kustomize component`** provided by the Online Boutique project.
   - This component defines a `patch` that removes the loadgenerator Deployment from the **`rendered manifests`**. 
   - Specifically, the component located in the `components/without-loadgenerator` directory was enabled in the overlay configuration
- By enabling this component in the overlay, the load generator is **`excluded`** from the final Kubernetes manifests generated by Kustomize.

### 5.4. Reduction of CPU Requests for Selected Services

- In addition to removing the load generator, CPU requests were reduced for`two` selected microservices in order to lower the total **`requested CPU`** and allow all remaining Pods to be scheduled.

- Reducing a CPU request means, under contention, the selected service may run slower. And so we have to answer this question: `Which services can tolerate being slower without breaking the user experience?` 

- The services chosen for this adjustment were:
   - **`emailservice`**: Slower execution only delays email delivery and does not block or affect the checkout process, making it suitable for reduced CPU requests.
   - **`recommendationservice`**: The recommendation service provides optional product suggestions and is not required for browsing or checkout. Degraded performance only impacts user experience quality, not core functionality, which makes it an appropriate candidate for reduced CPU requests.
   
- The CPU request values for these services were **`divided by two`** using targeted Kustomize patches. Only the requests were modified, while limits were left unchanged, in accordance with the analysis showing that scheduling decisions are based solely on resource requests.

- To apply these changes in a clean and reproducible manner, a dedicated overlay directory was created for the lab environment. This overlay contains a `kustomization.yaml` file along with two targeted patch files, `emailservice-cpu.yaml` and `recommendationservice-cpu.yaml`, which override the CPU request values for the corresponding services.
  
- The base configuration was left unchanged, and all modifications were defined declaratively through the overlay.

▶ The initial deployment was first removed , and the application was then redeployed using the overlay configuration, applying the reduced CPU requests and excluding the load generator as intended.

```bash
cd kustomize/overlays/lab/
kubectl apply -k .
```
### 5.5. Successful Scheduling of All Application Pods

▶ State of the cluster was inspected
```bash
kubectl get pods
```

<pre>
NAME                                     READY   STATUS    RESTARTS   AGE
adservice-b4856c769-9nstk                1/1     Running   0          30m
cartservice-5784f94fb6-lfggt             1/1     Running   0          30m
checkoutservice-56c5cffd57-2rrjw         1/1     Running   0          30m
currencyservice-66c885779c-x7tz7         1/1     Running   0          30m
emailservice-57c9dccfdf-khh89            1/1     Running   0          30m
frontend-5965c589c8-kcpnh                1/1     Running   0          30m
paymentservice-656fb48df5-s4bj5          1/1     Running   0          30m
productcatalogservice-5db55dcfbc-f6czc   1/1     Running   0          30m
recommendationservice-85cc576f9c-x4xdq   1/1     Running   0          30m
redis-cart-c4fc658fb-7bmlj               1/1     Running   0          30m
shippingservice-7fdc84f79-tx747          1/1     Running   0          30m
</pre>

This result confirms that the removal of the load generator and the adjustment of CPU requests were sufficient to bring the total requested CPU below the allocatable capacity of the cluster, allowing Kubernetes to successfully schedule all remaining application components.

## 6. Running and Deploying the Load Generator Using Infrastructure as Code

### 6.1 Motivation for Infrastructure-as-Code 

- In this project, we deploy the load generator **outside the Kubernetes cluster** to avoid consuming cluster resources and to produce realistic external traffic. While we could create and configure a VM on Google Cloud manually, this approach is:

   -   error-prone and hard to reproduce

   -   difficult to document precisely

   -   tedious to repeat for every experiment

   -   unsuitable for automation or systematic evaluation

- We use:

  - Terraform to provision the VM and firewall rule on GCP,

  - Ansible to configure the VM (Docker install) and run the load generator container,

  - Makefile to orchestrate the workflow with one command.

### 6.2 Directory structure
<pre>
  online-boutique-loadgen/ 
  ├── Makefile 
  ├── terraform/ 
  │ ├── main.tf 
  │ ├── variables.tf 
  │ ├── terraform.tfvars 
  │ └── outputs.tf 
  └── ansible/ 
  │ ├── ansible.cfg 
  │ ├── inventory.ini 
  │ ├── playbook.yml 
  │ └── stop-loadgen.yml
</pre>

- `ansible/inventory.ini` is generated dynamically from Terraform output, so it should not be committed.

- `~/.ssh/ansible_vm` and `~/.ssh/ansible_vm.pub` are the SSH keys used by Ansible to connect to the VM.

### 6.3 Terraform: what it provisions

Terraform is responsible for provisioning the cloud infrastructure:

#### 6.3.1 Resources created:

  - Compute Engine VM (Debian 12, type e2-medium)

  - Firewall rule allowing inbound:

    - `TCP/22` (SSH) for Ansible connectivity

    - `TCP/8089` (optional if you run Locust UI; headless mode does not require it)


#### 6.3.2 SSH key injection (critical)

  - Terraform injects the Ansible public key into the VM metadata so that the VM accepts SSH login without OS Login / gcloud SSH.

  - Conceptually:

    - we created a local key pair once: private key: ~/.ssh/ansible_vm and public key: ~/.ssh/ansible_vm.pub

    - Terraform injects the public key into the VM using instance metadata.

    - The VM boots and installs this key into authorized_keys for the configured user (commonly ansible).

    - Ansible then SSHes using ~/.ssh/ansible_vm.

#### 6.3.3 Terraform output used later

- Terraform outputs: `loadgen_external_ip` = the VM’s external IP address

- This output is used by the Makefile to generate the Ansible inventory automatically.



### 6.4 Ansible: what it configures and runs

Ansible is responsible for configuring the VM and running the containerized load generator.

#### 6.4.1 ansible/playbook.yml responsibilities

- The playbook performs these tasks on the VM:

  - Update apt cache

  - Install Docker
  
  - Enable and start Docker service
  
  - Pull the load generator image (e.g., jads7427/loadgenerator:lab)
  
  - Remove any previous container named loadgenerator
  
  - Run a new container in headless mode with: FRONTEND_ADDR set to the external IP of the Online Boutique frontend load balancer and optional USERS and RATE environment variables
  
- So as long as FRONTEND_ADDR is correct, the container will start generating traffic.

#### 6.4.2 ansible/stop-loadgen.yml

- This playbook removes the load generator container from the VM:

  - Stops it if running

  - Removes it if present



### 6.5. Makefile: orchestration and behavior

- The Makefile acts as the single entrypoint for running the whole pipeline.

#### 6.5.1 Targets overview

- `make all`
Full pipeline: provision VM + install Ansible deps + generate inventory + validate SSH + run load generator

- `make infra`
Only Terraform provisioning

- `make inventory`
Regenerates ansible/inventory.ini from Terraform output

- `make ansible-check`
Verifies Ansible can SSH into the VM

- `make loadgen`
Resolves frontend external IP and runs the Ansible playbook to start Locust in Docker

- `make stop-loadgen`
Stops and removes the load generator container

- `make destroy`
Destroys the VM + firewall via Terraform

- `make clean`
Removes generated inventory file



### 6.6. How to run 

#### 6.6.1 Prerequisites

- You have a running GKE cluster with `Online Boutique deployed`.

- You have a LoadBalancer service exposing the frontend: `frontend-external` must have an `EXTERNAL-IP`.

- You have Terraform installed.

- You have kubectl configured to talk to the cluster.

- Generate the SSH key once (only if not already present):
```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_vm -N ""
```

  
#### 6.6.2 One-command run

- From online-boutique-loadgen/: 
```bash
make all
```

#### 6.6.3 Stop load generator
```bash
make stop-loadgen
```

#### 6.6.4 Destroy infrastructure
```bash
make destroy
```


### 6.7. How to test that the load generator works

#### 6.7.1 Confirm container is running on the VM

- SSH to the VM:
```bash
ssh -i ~/.ssh/ansible_vm ansible@$(cd terraform && terraform output -raw loadgen_external_ip)
```

- Check container exists:

```bash
docker ps | grep loadgenerator
```

### 6.7.2 Confirm Locust is actually generating traffic (logs)

- On the VM:
```bash
docker logs --tail=50 loadgenerator
```

You should see the periodic Locust stats 

#### 6.7.3 Confirm GKE sees the traffic

- From Cloud Shell check that pods’ CPU usage increases under load: You should observe higher CPU utilization (especially frontend and some backend services) after load starts.
```bash
kubectl top pods
kubectl top nodes
```











