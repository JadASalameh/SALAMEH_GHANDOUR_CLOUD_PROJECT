# Monitoring the Application and the Infrastructure

## Purpose of This Document
This document describes the monitoring setup implemented for the Online Boutique application deployed on Google Kubernetes Engine (GKE).
The document explains:

  1. Monitoring Scope and Metrics.
  2. The architecture of the monitoring setup.
  3. The rationale behind each component.
  4. How to deploy the setup we developed.
  5. Baseline measurments.

**We assume everything is done on `google cloud shell`**

---

## 1. Monitoring Scope and Metrics.

The monitoring setup is designed to observe the system at **`two complementary`** levels: the infrastructure (`nodes`) and the application (`pods and microservices`), allowing clear attribution of performance behavior and avoid mistaking resource saturation with application-level inefficiencies.

### 1.1. Node-Level Metrics
- Node-level metrics describe resource consumption at the level of the worker node as a whole, including the host operating system, Kubernetes system components, and application workloads.
- The following node-level metrics are collected:
  
  - **CPU utilization** :  Percentage of total CPU capacity used per node.
  - **Memory utilization**: Fraction of total memory in use, derived from available and total memory.
  - **Disk I/O activity**:
    - Disk I/O saturation (percentage of time the disk is busy).
    - Disk throughput (read and write bytes per second).
  - **Network activity** :
    - Network throughput.
    - Network packet drops.
 
### 1.2. Pod- and Microservice-Level Metrics
- Pod- and microservice-level metrics provide visibility into how individual application components consume resources.
  
- The following metrics are collected at this level:

  - **CPU usage** per pod and per microservice

  - **Memory consumption** per pod and per microservice

  - **Resource distribution** across replicas of the same microservice (If replicas do exist).


These metrics allow attribution of resource usage to specific application components, detection of uneven load distribution across pods and correlation between application behavior and infrastructure-level pressure

---

## 2. Node-Level Monitoring Deployment Architecture

To collect node-level metrics, we deployed a dedicated monitoring architecture inside the Kubernetes cluster. 

This architecture is composed of three main components—Node Exporter, Prometheus, and Grafana—each serving a distinct role in the metric collection and visualization pipeline.

### 2.1. Node Exporter Deployment

- Node Exporter is a Prometheus exporter that exposes host-level metrics from the operating system, such as CPU usage, memory consumption, disk I/O, and network activity.

- To ensure complete coverage of the cluster, Node Exporter is deployed as a **`DaemonSet`**, which guarantees that `one instance` runs on each worker node. This design allows metrics to be collected directly from the host system on every node, independently of the application pods scheduled on it.

- Each Node Exporter instance exposes metrics over HTTP, which are later scraped by Prometheus.

### 2.2. Prometheus Deployment

- Prometheus is deployed inside the cluster as a central component responsible for scraping, storing, and querying metrics exposed by Node Exporter.

- Prometheus is configured to use `Kubernetes service discovery` to automatically detect `Node Exporter instances` running on each node,thus avoids hard-coded endpoints and allowing the monitoring system to adapt dynamically to changes in cluster size or topology.

- Prometheus plays a critical role by: Periodically scraping metrics from Node Exporter, Storing time-series data efficiently, and Providing a query language (PromQL) to aggregate and analyze metrics.

### 2.3. Grafana Deployment

- Grafana is deployed inside the cluster to provide `visualization and dashboarding` capabilities on top of the metrics collected by Prometheus.

- Grafana is configured to use Prometheus as its data source and allows metrics to be explored and visualized through interactive dashboards. For this project, we defined `custom dashboards` using a JSON specification.

### 2.4. Namespace Isolation and Repository Structure

- All monitoring components are deployed in the `monitoring` namespace to clearly separate monitoring infrastructure from application workloads reduce the risk of configuration and to simplify deployment and teardown procedures.

- The Kubernetes manifests, Grafana dashboard JSON files, and the Makefile used to deploy the monitoring stack are located in the following directory: `microservices-demo/monitoring`

- The exact commands and procedures required to deploy and access these components are described in a dedicated **`Deployment and Usage section`**.
