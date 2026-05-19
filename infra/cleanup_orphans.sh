#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Set the AWS region
REGION="us-east-1"

echo "Starting cleanup of orphaned AWS resources in region: $REGION..."

# 1. Delete GitHub OIDC Provider (Global but passing region is fine)
echo "Checking for GitHub OIDC Provider..."
OIDC_ARN=$(aws iam list-open-id-connect-providers --region "$REGION" --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text)

if [ -n "$OIDC_ARN" ] && [ "$OIDC_ARN" != "None" ]; then
    echo "Deleting OIDC Provider: $OIDC_ARN"
    aws iam delete-open-id-connect-provider --region "$REGION" --open-id-connect-provider-arn "$OIDC_ARN"
    echo "OIDC Provider deleted."
else
    echo "GitHub OIDC Provider not found or already deleted."
fi

# 2. Delete ECR Repositories
echo -e "\nChecking for ECR Repositories..."
for REPO in "chat-svc" "chat-front"; do
    if aws ecr describe-repositories --region "$REGION" --repository-names "$REPO" >/dev/null 2>&1; then
        echo "Deleting ECR Repository: $REPO"
        # --force deletes the repository and all images inside it
        aws ecr delete-repository --region "$REGION" --repository-name "$REPO" --force >/dev/null
        echo "ECR Repository $REPO deleted."
    else
        echo "ECR Repository $REPO not found or already deleted."
    fi
done

# 3. Delete CloudWatch Log Group
LOG_GROUP="/aws/eks/solo-devops-eks/cluster"
echo -e "\nChecking for CloudWatch Log Group: $LOG_GROUP..."

# Check if log group exists
if aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "$LOG_GROUP" --query 'logGroups[*].logGroupName' --output text | grep -q -w "$LOG_GROUP"; then
    echo "Deleting CloudWatch Log Group: $LOG_GROUP"
    aws logs delete-log-group --region "$REGION" --log-group-name "$LOG_GROUP"
    echo "CloudWatch Log Group deleted."
else
    echo "CloudWatch Log Group $LOG_GROUP not found or already deleted."
fi

echo -e "\n Cleanup complete! You can now run 'terraform apply' to let Terraform manage these resources."
