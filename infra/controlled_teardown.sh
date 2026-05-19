#!/bin/bash
# Controlled Teardown Script for Cost Intensive EKS and VPC resources
# Keeps ECR (images) and ACM (SSL certs) intact to avoid daily setup friction.
set -e

echo "=================================================="
echo "Starting Controlled DevOps Platform Teardown"
echo "=================================================="

# 1. Clean up K8s ALBs and Ingresses
echo "Step 1: Deleting Kubernetes Ingress resources to release AWS ALBs..."
kubectl delete ingress -n production chat-ingress --ignore-not-found=true || true
kubectl delete ingress -n staging chat-ingress --ignore-not-found=true || true
kubectl delete ingress -n observability prometheus-grafana --ignore-not-found=true || true
kubectl delete ingress -n argocd argocd-server-ingress --ignore-not-found=true || true

# 2. Clean up Namespaces (which deletes PVCs and releases EBS volumes)
echo "Step 2: Deleting staging, production, observability, and argocd namespaces..."
kubectl delete namespace staging production observability argocd --ignore-not-found=true || true

# 3. Wait for AWS Controller Cleanup
echo "Step 3: Waiting 90 seconds for AWS Controllers to finalize resource deletion in AWS..."
sleep 90

# 4. Targeted Terraform Destroy
echo "Step 4: Destroying EKS, VPC, and ALB components..."
cd /home/abu/Documents/SoloDevops/infra
terraform destroy \
  -target=module.eks \
  -target=module.vpc \
  -target=module.load_balancer_controller_irsa_role \
  -target=module.lb_controller_role \
  -target=helm_release.aws_lb_controller \
  -target=aws_security_group_rule.ingress_load_balancer \
  -target=aws_security_group_rule.ingress_load_balancer_api \
  -auto-approve

echo "=================================================="
echo "Teardown Complete! ECR (Images) and ACM (SSL Certs) remain intact."
echo "Run './controlled_startup.sh' when you need to provision the cluster back up seamlessly in minutes!, Abubakar Cooked this 😂, youre welcome "
echo "=================================================="
