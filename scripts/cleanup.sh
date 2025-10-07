#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                    CLEANUP WARNING                                 ║${NC}"
echo -e "${RED}║  This will DELETE ALL RESOURCES and DATA permanently!             ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

read -p "Are you ABSOLUTELY sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo -e "${YELLOW}Cleaning up resources...${NC}"

# Delete Kubernetes resources
echo "Deleting Kubernetes resources..."
kubectl delete namespace n8n --ignore-not-found=true

# Uninstall AWS Load Balancer Controller
echo "Uninstalling AWS Load Balancer Controller..."
helm uninstall aws-load-balancer-controller -n kube-system --ignore-not-found

# Wait for load balancers to be deleted
echo "Waiting for AWS resources to be cleaned up (this may take a few minutes)..."
sleep 30

# Destroy Terraform infrastructure
echo "Destroying Terraform infrastructure..."
cd terraform
terraform destroy -auto-approve

echo -e "${YELLOW}Cleanup complete!${NC}"

