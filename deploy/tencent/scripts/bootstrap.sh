#!/usr/bin/env bash
# 服务器一次性初始化脚本
# 用法：在腾讯云主机上以 runner 运行用户 执行一次：
#   sudo bash deploy/tencent/scripts/bootstrap.sh
#
# 作用：
#   - 创建 /opt/litellm 部署目录并把属主给当前用户
#   - 校验 Docker / Compose 可用
#   - 从 .env.example 复制初始 .env（之后需要手工填秘钥）

set -euo pipefail

DEPLOY_DIR="${LITELLM_DEPLOY_DIR:-/opt/litellm}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_TENCENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 目标用户：优先 SUDO_USER（sudo 执行时），否则当前 user
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_GROUP="$(id -gn "${TARGET_USER}")"

echo "==> 创建部署目录 ${DEPLOY_DIR}（属主: ${TARGET_USER}:${TARGET_GROUP}）"
mkdir -p "${DEPLOY_DIR}"
chown -R "${TARGET_USER}:${TARGET_GROUP}" "${DEPLOY_DIR}"

echo "==> 校验 Docker"
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: 未检测到 docker，请先安装 Docker Engine" >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: 未检测到 docker compose 插件" >&2
  exit 1
fi

echo "==> 确保当前用户在 docker 组（免 sudo 运行 docker）"
if ! id -nG "${TARGET_USER}" | grep -qw docker; then
  if getent group docker >/dev/null; then
    usermod -aG docker "${TARGET_USER}"
    echo "   已将 ${TARGET_USER} 加入 docker 组，需重新登录生效"
  fi
fi

if [[ ! -f "${DEPLOY_DIR}/.env" ]]; then
  echo "==> 初始化 ${DEPLOY_DIR}/.env（来自模板）"
  install -m 0600 -o "${TARGET_USER}" -g "${TARGET_GROUP}" \
    "${REPO_TENCENT_DIR}/.env.example" "${DEPLOY_DIR}/.env"
  echo ""
  echo "!! 下一步：编辑 ${DEPLOY_DIR}/.env，填入真实 DEEPSEEK_API_KEY / 各类密钥"
  echo "   vim ${DEPLOY_DIR}/.env"
  echo ""
else
  echo "==> 检测到已存在的 ${DEPLOY_DIR}/.env，跳过覆盖"
fi

echo "==> bootstrap 完成"
