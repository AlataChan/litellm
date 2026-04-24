#!/usr/bin/env bash
# 回滚脚本：把 litellm 容器切回指定镜像 tag
# 用法：
#   bash deploy/tencent/scripts/rollback.sh <image-tag>
# 示例：
#   bash deploy/tencent/scripts/rollback.sh v1.76.0-stable
#
# 会在 docker-compose.yml 里把 litellm 服务的 image 覆盖为指定版本，然后重启

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "用法: $0 <image-tag>  （例如 v1.76.0-stable）" >&2
  exit 2
fi

TAG="$1"
DEPLOY_DIR="${LITELLM_DEPLOY_DIR:-/opt/litellm}"
IMAGE="ghcr.io/berriai/litellm-database:${TAG}"

cd "${DEPLOY_DIR}"

echo "==> 回滚到镜像: ${IMAGE}"

export LITELLM_IMAGE="${IMAGE}"
# 临时覆盖 image 字段，不改仓库文件
docker compose --compatibility \
  -f docker-compose.yml \
  run --rm --no-deps --entrypoint /bin/true litellm >/dev/null 2>&1 || true

# 用 override 方式重启 litellm 服务
cat > docker-compose.override.yml <<EOF
services:
  litellm:
    image: ${IMAGE}
EOF

docker compose pull litellm
docker compose up -d litellm

echo "==> 回滚完成，当前容器："
docker compose ps litellm
