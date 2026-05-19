#!/bin/bash
# Controlled Startup Script for DevOps Platform
# Provisions AWS Infrastructure and seamlessly restores all Kubernetes workloads via GitOps.
set -e

echo "=================================================="
echo "Starting Controlled DevOps Platform Startup"
echo "=================================================="

# 1. Provision AWS Infrastructure
echo "Step 1: Provisioning EKS and VPC via Terraform..."
cd /home/abu/Documents/SoloDevops/infra
terraform apply -auto-approve

# 2. Reconnect kubectl to the fresh cluster
echo "Step 2: Reconnecting kubectl to the new EKS cluster..."
aws eks update-kubeconfig --region us-east-1 --name solo-devops-eks

# 2.5. Create StorageClass
echo "Step 2.5: Creating native EKS Auto Mode default StorageClass..."
kubectl apply -f /home/abu/Documents/SoloDevops/infra/ebs-sc.yaml

# 3. Install ArgoCD
echo "Step 3: Installing ArgoCD into the cluster..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD server to be ready (this may take a few minutes)..."
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

# 4. Restore GitOps Applications
echo "Step 4: Restoring ArgoCD Repository Secret, Ingress, and Application definitions..."
kubectl apply -f ../k8-manifests/argocd/

# 5. Deploy Observability Stack
echo "Step 5: Deploying Prometheus, Grafana, and Loki stack..."
cd ../k8-manifests/observability
bash deploy-observability.sh

# 6. Dynamically Update Route 53 DNS
echo "Step 6: Waiting for AWS Application Load Balancers (ALBs) to initialize..."
sleep 45  # Give the ALB controller some time to reconcile and create the ALBs

for i in {1..30}; do
  STAGING_ALB=$(kubectl get ingress chat-ingress -n staging -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  PROD_ALB=$(kubectl get ingress chat-ingress -n production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  GRAFANA_ALB=$(kubectl get ingress prometheus-grafana -n observability -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  ARGOCD_ALB=$(kubectl get ingress argocd-server-ingress -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  
  if [ -n "$STAGING_ALB" ] && [ -n "$PROD_ALB" ] && [ -n "$GRAFANA_ALB" ] && [ -n "$ARGOCD_ALB" ]; then
    echo "All ALBs successfully created!"
    break
  fi
  echo "Waiting for ALB hostnames... ($i/30)"
  sleep 10
done

if [ -z "$STAGING_ALB" ] || [ -z "$PROD_ALB" ] || [ -z "$GRAFANA_ALB" ] || [ -z "$ARGOCD_ALB" ]; then
  echo "⚠️ Warning: One or more ALB hostnames could not be retrieved. Route 53 was not updated."
  echo "Staging: $STAGING_ALB"
  echo "Prod: $PROD_ALB"
  echo "Grafana: $GRAFANA_ALB"
  echo "ArgoCD: $ARGOCD_ALB"
else
  echo "🌐 Dynamically updating Route 53 DNS records with new ALBs..."
  cat <<EOF > /tmp/route53_dynamic.json
{
  "Comment": "Automatically updated DNS records from controlled startup script",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "staging.atiqabubakar.sbs.",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$STAGING_ALB"
          }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "*.atiqabubakar.sbs.",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$PROD_ALB"
          }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "grafana.atiqabubakar.sbs.",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$GRAFANA_ALB"
          }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "argocd.atiqabubakar.sbs.",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$ARGOCD_ALB"
          }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "atiqabubakar.sbs.",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z35SXDOTRQ7X7K",
          "DNSName": "$PROD_ALB",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF

  aws route53 change-resource-record-sets --hosted-zone-id Z08885711F2TBJ55R99H3 --change-batch file:///tmp/route53_dynamic.json
  echo "Route 53 DNS records successfully updated!"
fi

echo "=================================================="
echo "Startup Complete! ArgoCD is now automatically syncing your Staging and Production environments."
echo "=================================================="
