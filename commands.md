# List of helpful commands

Sets the active Google Cloud project for all subsequent gcloud commands.

```bash
gcloud config set project <PROJECT_ID>
```

Lists all available Google Cloud regions.

```bash
gcloud compute regions list --format="value(name)"
```

Lists all available Google Cloud zones.

```bash
gcloud compute zones list --format="value(name)"
```

Shows the currently configured default compute region and zone.

```bash
gcloud config list compute
```

Sets the default compute region for gcloud commands.

```bash
gcloud config set compute/region europe-west1
```

Sets the default compute zone for gcloud commands.

```bash
gcloud config set compute/zone europe-west1-b
```

Creates a new GKE cluster named prodigy-cluster using default settings.

```bash
gcloud container clusters create prodigy-cluster
```

Configures kubectl to connect to the specified GKE cluster.

```bash
gcloud container clusters get-credentials prodigy-cluster
```

Displays basic information about the Kubernetes cluster and control plane.

```bash
kubectl cluster-info
```

Lists all nodes in the Kubernetes cluster.

```bash
kubectl get nodes
```

Lists all nodes with additional details such as IPs and Kubernetes version

```bash
kubectl get nodes -o wide
```

Shows detailed information about a specific node, including resources and labels

```bash
kubectl describe node <NODE_NAME>
```

Lists all namespaces in the Kubernetes cluster.

```bash

kubectl get namespaces
```

Displays the allocatable (schedulable) CPU and memory for each node.

```bash
kubectl get nodes \
-o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory
```

Displays the total hardware CPU and memory capacity of each node.

```bash
kubectl get nodes \
  -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory
```
