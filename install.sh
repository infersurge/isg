#!/usr/bin/env sh
# InferSurge ISG — 一键安装脚本
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/infersurge/isg/main/install.sh)"
# 用法: install.sh [版本号]   例: install.sh v0.1.0  (默认 latest)
set -eu

REPO="infersurge/isg"
BINARY="isg"
INSTALL_DIR="${ISG_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${1:-latest}"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- 检测平台 -------------------------------------------------------------
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
  Linux)   GOOS=linux ;;
  Darwin)  GOOS=darwin ;;
  MINGW*|MSYS*|CYGWIN*) die "Windows 请从 Releases 下载 isg-windows-amd64.exe，或用 PowerShell 脚本" ;;
  *) die "不支持的系统: $OS" ;;
esac
case "$ARCH" in
  x86_64|amd64) GOARCH=amd64 ;;
  aarch64|arm64) GOARCH=arm64 ;;
  *) die "不支持的架构: $ARCH" ;;
esac
ASSET="${BINARY}-${GOOS}-${GOARCH}"
[ "$GOOS" = "windows" ] && ASSET="${ASSET}.exe"

# --- 解析版本 -------------------------------------------------------------
if [ "$VERSION" = "latest" ]; then
  DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"
else
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"
fi

# --- 下载 -----------------------------------------------------------------
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

say "InferSurge ISG 安装器"
say "  平台: ${GOOS}/${GOARCH}"
say "  版本: ${VERSION}"
say "  安装到: ${INSTALL_DIR}"
say ""

command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 \
  || die "需要 curl 或 wget"

say "下载 ${ASSET} ..."
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/${BINARY}" \
    || die "下载失败: ${DOWNLOAD_URL}（该版本可能没有此平台的产物）"
else
  wget -qO "${TMP_DIR}/${BINARY}" "$DOWNLOAD_URL" \
    || die "下载失败: ${DOWNLOAD_URL}（该版本可能没有此平台的产物）"
fi

# --- 校验 -----------------------------------------------------------------
say "下载校验和 ..."
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${DOWNLOAD_URL}.sha256" -o "${TMP_DIR}/${BINARY}.sha256" 2>/dev/null || true
else
  wget -qO "${TMP_DIR}/${BINARY}.sha256" "${DOWNLOAD_URL}.sha256" 2>/dev/null || true
fi

if [ -f "${TMP_DIR}/${BINARY}.sha256" ]; then
  EXPECTED="$(awk '{print $1}' "${TMP_DIR}/${BINARY}.sha256")"
  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL="$(sha256sum "${TMP_DIR}/${BINARY}" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL="$(shasum -a 256 "${TMP_DIR}/${BINARY}" | awk '{print $1}')"
  else
    say "警告: 找不到 sha256sum/shasum，跳过校验"
    ACTUAL="$EXPECTED"
  fi
  [ "$EXPECTED" = "$ACTUAL" ] || die "校验和不匹配（可能下载被篡改或不完整），已放弃安装"
  say "  校验通过"
else
  say "  警告: 未找到 .sha256 文件，跳过校验"
fi

# --- 安装 -----------------------------------------------------------------
chmod +x "${TMP_DIR}/${BINARY}"
mkdir -p "$INSTALL_DIR"
mv "${TMP_DIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"

say ""
say "已安装到 ${INSTALL_DIR}/${BINARY}"

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *) say "提示: ${INSTALL_DIR} 不在 PATH 中，请加入:"; say "  export PATH=\"${INSTALL_DIR}:\$PATH\"" ;;
esac

say ""
say "验证: ${INSTALL_DIR}/${BINARY} version"
say "下一步: 在 https://app.infersurge.com 添加设备，取得一次性注册命令"
