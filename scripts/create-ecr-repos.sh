set -euo pipefail

# AWS Region
AWS_REGION="${AWS_REGION:-us-east-1}"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Repositories
REPOSITORIES=(
    "dhaba/menu-api"
    "dhaba/orders-api"
    "dhaba/kitchen-worker"
    "dhaba/stats-api"
    "dhaba/web"
)

echo "======================================"
echo "Dhaba Orders - ECR Repository Setup"
echo "======================================"
echo "AWS Account: ${AWS_ACCOUNT_ID}"
echo "AWS Region:  ${AWS_REGION}"
echo ""

for REPO in "${REPOSITORIES[@]}"; do

    echo "Checking repository: ${REPO}"

    if aws ecr describe-repositories \
        --repository-names "${REPO}" \
        --region "${AWS_REGION}" \
        >/dev/null 2>&1; then

        echo "Repository already exists: ${REPO}"

    else

        echo "Creating repository: ${REPO}"

        aws ecr create-repository \
            --repository-name "${REPO}" \
            --region "${AWS_REGION}" \
            --image-scanning-configuration scanOnPush=true \
            --image-tag-mutability IMMUTABLE

        echo "Created: ${REPO}"

    fi

done

echo ""
echo "======================================"
echo "ECR repositories are ready!"
echo "======================================"

echo "Registry:"
echo "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo ""
echo "Repositories:"
for REPO in "${REPOSITORIES[@]}"; do
    echo "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO}"
done
