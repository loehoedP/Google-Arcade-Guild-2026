#!/bin/bash
set -e

# ==============================================================================
# Environment & Project Setup
# ==============================================================================
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
export ZONE=$(gcloud compute instances list --filter="name=private-instance" --format="value(zone)" | awk -F'/' '{print $NF}')
export REGION=${ZONE%-*}

echo "Project: $PROJECT_ID ($PROJECT_NUMBER) | Region: $REGION | Zone: $ZONE"

# ==============================================================================
# TASK 1: Migrate Legacy VPC Firewall Rules to a Global Policy
# ==============================================================================
gcloud compute network-firewall-policies create unified-fw-policy \
  --global \
  --description="Centralized global firewall policy for unified-vpc"

gcloud beta compute firewall-rules migrate \
  --source-network=unified-vpc \
  --target-firewall-policy=unified-fw-policy \
  --force

export NETWORK_ID=$(gcloud compute networks describe unified-vpc --format="value(id)")
export NETWORK_SELF_LINK_ID="https://www.googleapis.com/compute/v1/projects/${PROJECT_NUMBER}/global/networks/${NETWORK_ID}"

gcloud resource-manager tags keys create unified-fw-tag \
  --parent="projects/$PROJECT_ID" \
  --purpose=GCE_FIREWALL \
  --purpose-data="network=$NETWORK_SELF_LINK_ID" \
  --description="Secure IAM tag for unified-vpc firewall policy"

export TAG_KEY_NAME=$(gcloud resource-manager tags keys list \
  --parent="projects/$PROJECT_ID" \
  --filter="shortName=unified-fw-tag" \
  --format="value(name)")

gcloud resource-manager tags values create web \
  --parent="$TAG_KEY_NAME" \
  --description="Web server instances"

gcloud resource-manager tags values create ssh \
  --parent="$TAG_KEY_NAME" \
  --description="SSH-accessible instances"

export TAG_VALUE_WEB=$(gcloud resource-manager tags values list \
  --parent="$TAG_KEY_NAME" \
  --filter="shortName=web" \
  --format="value(name)")

export TAG_VALUE_SSH=$(gcloud resource-manager tags values list \
  --parent="$TAG_KEY_NAME" \
  --filter="shortName=ssh" \
  --format="value(name)")

gcloud compute network-firewall-policies rules create 1000 \
  --action=allow \
  --firewall-policy=unified-fw-policy \
  --global-firewall-policy \
  --direction=INGRESS \
  --description="Allow HTTP to web-tagged instances" \
  --src-ip-ranges=0.0.0.0/0 \
  --layer4-configs=tcp:80 \
  --target-secure-tags="$TAG_VALUE_WEB"

gcloud compute network-firewall-policies rules create 900 \
  --action=allow \
  --firewall-policy=unified-fw-policy \
  --global-firewall-policy \
  --direction=INGRESS \
  --description="Allow SSH via IAP to ssh-tagged instances" \
  --src-ip-ranges=35.235.240.0/20 \
  --layer4-configs=tcp:22 \
  --target-secure-tags="$TAG_VALUE_SSH"

gcloud compute network-firewall-policies rules create 800 \
  --action=allow \
  --firewall-policy=unified-fw-policy \
  --global-firewall-policy \
  --direction=INGRESS \
  --description="Allow IAP SSH to all instances" \
  --src-ip-ranges=35.235.240.0/20 \
  --layer4-configs=tcp:22

gcloud compute network-firewall-policies associations create \
  --firewall-policy=unified-fw-policy \
  --network=unified-vpc \
  --global-firewall-policy

gcloud compute networks update unified-vpc \
  --network-firewall-policy-enforcement-order=BEFORE_CLASSIC_FIREWALL

# Hapus aturan VPC ingress lama (menyisakan baseline egress bawaan)
gcloud compute firewall-rules delete \
  allow-iap-access \
  allow-internal-vpc \
  allow-ssh \
  allow-web \
  --quiet

# ==============================================================================
# TASK 2: Remediate Outbound Cloud NAT Resolution
# ==============================================================================
export PRIVATE_INSTANCE_SUBNET=$(gcloud compute instances describe private-instance \
  --zone="$ZONE" \
  --format="value(networkInterfaces[0].subnetwork)" | awk -F'/' '{print $NF}')

gcloud compute routers nats update unified-nat \
  --router=unified-router \
  --region="$REGION" \
  --nat-custom-subnet-ip-ranges="$PRIVATE_INSTANCE_SUBNET"

# ==============================================================================
# TASK 3: Contain Compromised Workload & Enable VPC Flow Logs
# ==============================================================================
export COMPROMISED_VM_TAG=$(gcloud compute instances describe compromised-vm \
  --zone="$ZONE" \
  --format="value(tags.items[0])")

if [ -z "$COMPROMISED_VM_TAG" ]; then
  gcloud compute instances add-tags compromised-vm --tags=compromised --zone="$ZONE"
  export COMPROMISED_VM_TAG="compromised"
fi

export BASTION_HOST=$(gcloud compute instances list --filter="name~bastion" --format="value(name)")
export BASTION_EXTERNAL_IP=$(gcloud compute instances describe "$BASTION_HOST" \
  --zone="$ZONE" \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

gcloud compute firewall-rules create containment-deny-http \
  --network=unified-vpc \
  --direction=INGRESS \
  --priority=500 \
  --action=DENY \
  --rules=tcp:80 \
  --source-ranges=0.0.0.0/0 \
  --target-tags="$COMPROMISED_VM_TAG" \
  --description="INCIDENT RESPONSE: Block all HTTP ingress to compromised workload"

gcloud compute firewall-rules create allow-forensics-ssh \
  --network=unified-vpc \
  --direction=INGRESS \
  --priority=400 \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges="$BASTION_EXTERNAL_IP/32" \
  --target-tags="$COMPROMISED_VM_TAG" \
  --description="INCIDENT RESPONSE: Allow SSH from bastion external IP only"

export APP_SUBNET=$(gcloud compute instances describe compromised-vm \
  --zone="$ZONE" \
  --format="value(networkInterfaces[0].subnetwork)" | awk -F'/' '{print $NF}')

gcloud compute networks subnets update "$APP_SUBNET" \
  --region="$REGION" \
  --enable-flow-logs \
  --logging-aggregation-interval=interval-5-sec \
  --logging-flow-sampling=1.0 \
  --logging-metadata=include-all

echo "=== GSP399 Challenge Lab Completed! ==="