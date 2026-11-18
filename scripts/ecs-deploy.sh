#!/usr/bin/env bash
# =============================================================================
# Dhaba — Amazon ECS Deployment Script
# =============================================================================
# Usage:
#   chmod +x scripts/ecs-deploy.sh
#   AWS_ACCOUNT_ID=123456789012 AWS_REGION=us-east-1 IMAGE_TAG=latest \
#     ECS_CLUSTER=dhaba-cluster ./scripts/ecs-deploy.sh
#
# Prerequisites:
#   - AWS CLI v2 configured (aws configure / IAM role)
#   - Docker logged in to ECR  (run ecr-login step or --skip-build)
#   - ECS cluster, ALB target groups, and SSM parameters already exist
#
# SSM Parameters expected (create once):
#   /dhaba/DB_HOST        – RDS endpoint
#   /dhaba/DB_PASSWORD    – DB password
#   /dhaba/REDIS_ADDR     – host:port  (orders-api)
#   /dhaba/REDIS_HOST     – hostname   (kitchen-worker, stats-api)
#   /dhaba/APP_KEY        – Laravel app key (base64:...)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — override via environment variables
# ---------------------------------------------------------------------------
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID}"
AWS_REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
ECS_CLUSTER="${ECS_CLUSTER:-dhaba-cluster}"
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

SERVICES=(menu-api orders-api kitchen-worker stats-api web)

# ECS service names (must match what you created in the console / Terraform)
declare -A ECS_SERVICE_NAMES=(
  [menu-api]="dhaba-menu-api-svc"
  [orders-api]="dhaba-orders-api-svc"
  [kitchen-worker]="dhaba-kitchen-worker-svc"
  [stats-api]="dhaba-stats-api-svc"
  [web]="dhaba-web-svc"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

ecr_login() {
  log "Logging in to ECR …"
  aws ecr get-login-password --region "${AWS_REGION}" \
    | docker login --username AWS --password-stdin "${ECR_BASE}"
}

ensure_ecr_repo() {
  local name="dhaba/$1"
  aws ecr describe-repositories --repository-names "${name}" \
      --region "${AWS_REGION}" > /dev/null 2>&1 \
    || aws ecr create-repository --repository-name "${name}" \
         --region "${AWS_REGION}" --image-scanning-configuration scanOnPush=true \
    && log "Created ECR repo: ${name}"
}

build_and_push() {
  local svc="$1"
  local repo="${ECR_BASE}/dhaba/${svc}:${IMAGE_TAG}"
  log "Building ${svc} …"
  docker build -t "${repo}" "./${svc}"
  log "Pushing ${svc} → ${repo}"
  docker push "${repo}"
}

register_task_def() {
  local svc="$1"
  local family="dhaba-${svc}"
  local tmp_file="/tmp/dhaba-td-${svc}.json"

  log "Generating task definition for ${svc} …"

  # Pull the template from the JSON file and substitute placeholders
  python3 - <<PYEOF > "${tmp_file}"
import json, sys

with open("scripts/ecs-task-definitions.json") as f:
    all_defs = json.load(f)

svc = "${svc}"
td  = all_defs[svc]

# Substitute placeholders
raw = json.dumps(td)
raw = raw.replace("<AWS_ACCOUNT_ID>", "${AWS_ACCOUNT_ID}")
raw = raw.replace("<AWS_REGION>",    "${AWS_REGION}")
raw = raw.replace("<IMAGE_TAG>",     "${IMAGE_TAG}")

print(raw)
PYEOF

  log "Registering task definition: ${family}"
  TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json "file://${tmp_file}" \
    --region "${AWS_REGION}" \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)
  log "  → ${TASK_DEF_ARN}"
  echo "${TASK_DEF_ARN}"
}

create_log_group() {
  local svc="$1"
  local group="/ecs/dhaba/${svc}"
  aws logs create-log-group --log-group-name "${group}" \
      --region "${AWS_REGION}" 2>/dev/null \
    || true
  log "CloudWatch log group ready: ${group}"
}

update_ecs_service() {
  local svc="$1"
  local task_def_arn="$2"
  local ecs_svc="${ECS_SERVICE_NAMES[$svc]}"

  log "Updating ECS service ${ecs_svc} with new task definition …"
  aws ecs update-service \
    --cluster "${ECS_CLUSTER}" \
    --service  "${ecs_svc}" \
    --task-definition "${task_def_arn}" \
    --force-new-deployment \
    --region "${AWS_REGION}" \
    --output text --query "service.serviceName" > /dev/null
  log "  → deployment triggered for ${ecs_svc}"
}

wait_for_stability() {
  local svc="$1"
  local ecs_svc="${ECS_SERVICE_NAMES[$svc]}"
  log "Waiting for ${ecs_svc} to stabilise (this may take a few minutes) …"
  aws ecs wait services-stable \
    --cluster "${ECS_CLUSTER}" \
    --services "${ecs_svc}" \
    --region  "${AWS_REGION}"
  log "  ✓ ${ecs_svc} is stable"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
ecr_login

for svc in "${SERVICES[@]}"; do
  log "===== Processing: ${svc} ====="
  ensure_ecr_repo   "${svc}"
  create_log_group  "${svc}"
  build_and_push    "${svc}"
  TASK_ARN=$(register_task_def "${svc}")
  update_ecs_service "${svc}" "${TASK_ARN}"
done

log "All task definitions registered and deployments triggered."
log "Waiting for all services to stabilise …"

for svc in "${SERVICES[@]}"; do
  wait_for_stability "${svc}" &
done
wait

log "======================================"
log " Dhaba ECS deployment complete! ✓"
log "======================================"
