#!/bin/bash
set -e

# ──────────────────────────────────────────
# 설정 변수 — 환경에 맞게 수정하세요
# ──────────────────────────────────────────
REGISTRY_PATH="apps"
IMAGE_NAME="ms-teams-alarm"
TAG="v26.04.03-1" 

NEXUS_IP="<BUILD_NODE_IP>"        # build 노드 IP (192.168.50.x)
NEXUS_PORT="8082"                 # Nexus Docker hosted 레지스트리 포트

REGISTRIES=(
  "${NEXUS_IP}:${NEXUS_PORT}/${REGISTRY_PATH}"
)

BASE_IMAGE="${IMAGE_NAME}:${TAG}"

# ──────────────────────────────────────────
# 빌드
# ──────────────────────────────────────────
echo "▶ 이미지 빌드: ${BASE_IMAGE}"
docker build \
  -f docker/Dockerfile \
  -t "${BASE_IMAGE}" \
  .

echo "✓ 빌드 완료"

# ──────────────────────────────────────────
# Push (모든 레지스트리)
# ──────────────────────────────────────────
for REGISTRY in "${REGISTRIES[@]}"; do
  FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"
  
  echo "▶ 태그 지정: ${FULL_IMAGE}"
  docker tag "${BASE_IMAGE}" "${FULL_IMAGE}"
  
  echo "▶ 이미지 Push: ${FULL_IMAGE}"
  docker push "${FULL_IMAGE}"
  
  echo "✓ Push 완료: ${FULL_IMAGE}"
done
