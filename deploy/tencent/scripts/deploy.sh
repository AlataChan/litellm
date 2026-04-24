#!/usr/bin/env bash
# 部署脚本（由 GitHub self-hosted runner 触发）
# 约束：
#   - 必须已执行过 bootstrap.sh，且 /opt/litellm/.env 已填好秘钥
#   - 运行用户对 /opt/litellm 有读写权限，且已在 docker 组
#
# 做的事：
#   1. 把仓库里的 config.yaml 和 docker-compose.prod.yml 同步到 /opt/litellm/
#   2. docker compose pull 拉最新镜像
#   3. docker compose up -d 重启服务
#   4. 轮询 /health/liveliness，60 秒内拉不起来则打印日志并返回非零

set -euo pipefail

DEPLOY_DIR="${LITELLM_DEPLOY_DIR:-/opt/litellm}"
REPO_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SRC="${REPO_DIR}/deploy/tencent"
HEALTH_URL="${LITELLM_HEALTH_URL:-http://127.0.0.1:4000/health/liveliness}"

echo "==> 部署目录: ${DEPLOY_DIR}"
echo "==> 源目录:   ${SRC}"

if [[ ! -d "${DEPLOY_DIR}" ]]; then
  echo "ERROR: ${DEPLOY_DIR} 不存在，请先在服务器上执行 bootstrap.sh" >&2
  exit 1
fi
if [[ ! -f "${DEPLOY_DIR}/.env" ]]; then
  echo "ERROR: ${DEPLOY_DIR}/.env 不存在，请从 .env.example 创建并填值" >&2
  exit 1
fi

echo "==> 同步 docker-compose.yml / config.yaml"
install -m 0644 "${SRC}/docker-compose.prod.yml" "${DEPLOY_DIR}/docker-compose.yml"
install -m 0644 "${SRC}/litellm.config.yaml"     "${DEPLOY_DIR}/config.yaml"

cd "${DEPLOY_DIR}"

echo "==> 拉取最新镜像"
docker compose pull

echo "==> 启动/更新服务"
docker compose up -d --remove-orphans

echo "==> 等待健康检查（${HEALTH_URL}）"
for i in $(seq 1 30); do
  if curl -fsS "${HEALTH_URL}" >/dev/null 2>&1; then
    echo "==> 健康检查通过（第 ${i} 次尝试）"
    docker compose ps
    exit 0
  fi
  sleep 2
done

echo "==> 60 秒内健康检查失败，打印容器日志便于排查"
docker compose ps || true
docker compose logs --tail=200 litellm || true
exit 1
