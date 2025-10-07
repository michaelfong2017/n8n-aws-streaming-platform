#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         n8n AWS Streaming Platform - Setup Script                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}Helm is required but not installed. Aborting.${NC}" >&2; exit 1; }

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Deploy infrastructure
echo -e "${YELLOW}Step 1: Deploying infrastructure with Terraform...${NC}"
cd terraform

terraform init
terraform plan -out=tfplan
echo ""
read -p "Review the plan above. Continue with deployment? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 1
fi

terraform apply tfplan
echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# Configure kubectl
echo -e "${YELLOW}Step 2: Configuring kubectl...${NC}"
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --region ap-southeast-1 --name $CLUSTER_NAME
kubectl get nodes
echo -e "${GREEN}✓ kubectl configured${NC}"
echo ""

# Install AWS Load Balancer Controller
echo -e "${YELLOW}Step 3: Installing AWS Load Balancer Controller...${NC}"
helm repo add eks https://aws.github.io/eks-charts
helm repo update

ALB_ROLE_ARN=$(terraform output -raw eks_alb_controller_role_arn)

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE_ARN

echo "Waiting for controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system
echo -e "${GREEN}✓ AWS Load Balancer Controller installed${NC}"
echo ""

# Deploy n8n with Helm
echo -e "${YELLOW}Step 4: Deploying n8n with Helm...${NC}"
cd ../kubernetes

# Add n8n Helm repository
helm repo add 8gears https://8gears.container-registry.com/chartrepo/library 2>/dev/null || true
helm repo update

# Get RDS credentials
RDS_ENDPOINT=$(cd ../terraform && terraform output -raw rds_endpoint)
RDS_HOST=${RDS_ENDPOINT%:*}
RDS_PASSWORD=$(aws secretsmanager get-secret-value \
  --region ap-southeast-1 \
  --secret-id $(cd ../terraform && terraform output -raw rds_password_secret_arn) \
  --query SecretString \
  --output text)
ENCRYPTION_KEY=$(openssl rand -base64 32)

# Create values file with credentials
cat > n8n-values-deploy.yaml <<EOF
config:
  database:
    type: postgresdb
    postgresdb:
      host: "${RDS_HOST}"
      port: 5432
      database: "n8n"
      user: "n8nadmin"
      password: "${RDS_PASSWORD}"
  generic:
    timezone: "Asia/Singapore"
  encryptionKey: "${ENCRYPTION_KEY}"

service:
  type: LoadBalancer
  port: 80
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"

autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 70

resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

persistence:
  enabled: false

securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
EOF

# Install n8n via Helm
helm install n8n 8gears/n8n \
  -n n8n \
  --create-namespace \
  -f n8n-values-deploy.yaml

echo "Waiting for n8n to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/n8n-n8n -n n8n 2>/dev/null || true
echo -e "${GREEN}✓ n8n deployed via Helm${NC}"
echo ""

# Get endpoints
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Setup Complete! 🎉                              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

cd ../terraform

echo -e "${YELLOW}OBS Streaming Configuration:${NC}"
echo "Server: $(terraform output -raw ivs_ingest_endpoint)"
echo "Stream Key: $(terraform output -raw ivs_stream_key)"
echo ""

echo -e "${YELLOW}Playback URL:${NC}"
echo "$(terraform output -raw ivs_playback_url)"
echo ""

echo -e "${YELLOW}n8n URL (may take 2-3 minutes for LB to provision):${NC}"
cd ../kubernetes
N8N_LB=$(kubectl get svc n8n-service -n n8n -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")
echo "http://${N8N_LB}"
echo ""

echo -e "${GREEN}Setup complete! Check the README.md for next steps.${NC}"

