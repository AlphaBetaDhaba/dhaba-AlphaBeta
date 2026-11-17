#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
: "${TEAM:?Set TEAM}"

SERVICES="web menu-api orders-api kitchen-worker stats-api postgres redis ops-monitor"

POLICY='{"rules":[{"rulePriority":1,"description":"keep newest 20","selection":{"tagStatus":"any","countType":"imageCountMoreThan","countNumber":20},"action":{"type":"expire"}}]}'

for svc in $SERVICES; do
  repo="dhaba-${TEAM}/${svc}"

  if aws ecr describe-repositories --repository-names "$repo" \
       --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "$repo already exists"
  else
    aws ecr create-repository --repository-name "$repo" \
      --image-scanning-configuration scanOnPush=true \
      --region "$AWS_REGION" >/dev/null
    echo "$repo created"
  fi

  # Safe to run many times: it just sets the same rule again
  aws ecr put-lifecycle-policy --repository-name "$repo" \
    --lifecycle-policy-text "$POLICY" \
    --region "$AWS_REGION" >/dev/null
done
