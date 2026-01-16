#!/usr/bin/env bash
set -euo pipefail

# ============================
# Configuration
# ============================
PROJECT_ID="durable-verve-478111-a5"
REGION="europe-west6"
ZONE="europe-west6-a"
CLUSTER_NAME="prodigy-cluster"

echo "Setting GCP project"
gcloud config set project "$PROJECT_ID"

echo "Setting default region"
gcloud config set compute/region "$REGION"

echo "Setting default zone"
gcloud config set compute/zone "$ZONE"

echo "Deleting GKE cluster: $CLUSTER_NAME"
gcloud container clusters delete "$CLUSTER_NAME" \
  --zone "$ZONE" \
  --quiet

echo "Cluster '$CLUSTER_NAME' successfully deleted"
