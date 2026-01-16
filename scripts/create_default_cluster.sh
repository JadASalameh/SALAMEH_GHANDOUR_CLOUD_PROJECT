#!/usr/bin/env bash
set -euo pipefail

# ============================
# Configuration
# ============================
PROJECT_ID="durable-verve-478111-a5"
REGION="europe-west1"
ZONE="europe-west6-b"
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

