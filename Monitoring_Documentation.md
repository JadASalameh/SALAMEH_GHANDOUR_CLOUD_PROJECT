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

### 2.1. Node-Level Metrics
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
 
### 2.2. Pod- and Microservice-Level Metrics
- Pod- and microservice-level metrics provide visibility into how individual application components consume resources.
  
- The following metrics are collected at this level:

  - **CPU usage** per pod and per microservice

  - **Memory consumption** per pod and per microservice

  - **Resource distribution** across replicas of the same microservice (If replicas do exist).


These metrics allow attribution of resource usage to specific application components, detection of uneven load distribution across pods and correlation between application behavior and infrastructure-level pressure








