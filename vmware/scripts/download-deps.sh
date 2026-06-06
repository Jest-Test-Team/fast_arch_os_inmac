#!/usr/bin/env bash
# =============================================================================
# download-deps.sh — 下載並驗證 VMware Fusion 安裝所需的前置檔案
#
# 在 Mac 上執行（不是在 VM 內）：
#   bash vmware/scripts/download-deps.sh
#
# 功能：
#   1. 下載 Alpine Linux virt aarch64 ISO（如未存在）
#   2. 驗證 SHA256 checksum
#   3. 顯示 VMware Fusion 13.6.4 下載指引
# =============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# 版本常數（更新版本時只改此處）
# --------------------------------------------------------------------------
ALPINE_VERSION="3.23.4"
ALPINE_ISO="alpine-virt-${ALPINE_VERSION}-aarch64.iso"
ALPINE_SHA256="alpine-virt-${ALPINE_VERSION}-aarch64.iso.sha256"
ALPINE_BASE_URL="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64"

VMWARE_VERSION="13.6.4"
VMWARE_BUILD="533271"
VMWARE_URL="https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware+Fusion"

DOWNLOAD_DIR="$(dirname "$0")/../../downloads"

# --------------------------------------------------------------------------
# 顏色輸出
# --------------------------------------------------------------------------
info()    { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
success() { printf '\033[1;32m[OK]\033[0m   %s\n' "$*"; }
warn()    { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()     { printf '\033[1;31m[ERR]\033[0m  %s\n' "$*"; exit 1; }

# --------------------------------------------------------------------------
# 確認在 macOS 上執行
# --------------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "此腳本僅適用於 macOS（用於下載安裝媒介）"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  VMware Fusion + Arch Linux ARM — 前置檔案下載工具  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# --------------------------------------------------------------------------
# 建立下載目錄
# --------------------------------------------------------------------------
mkdir -p "$DOWNLOAD_DIR"
info "下載目錄：$DOWNLOAD_DIR"
echo ""

# ==========================================================================
# 步驟 1：Alpine Linux virt ISO
# ==========================================================================
info "=== Alpine Linux ${ALPINE_VERSION} virt aarch64 ISO ==="

ISO_PATH="${DOWNLOAD_DIR}/${ALPINE_ISO}"
SHA_PATH="${DOWNLOAD_DIR}/${ALPINE_SHA256}"

if [ -f "$ISO_PATH" ]; then
  warn "ISO 已存在：$ISO_PATH，跳過下載"
else
  info "下載 ISO（90 MB）..."
  curl -L --progress-bar \
    -o "$ISO_PATH" \
    "${ALPINE_BASE_URL}/${ALPINE_ISO}"
  success "ISO 下載完成"
fi

# 下載並驗證 SHA256
info "下載 SHA256 checksum..."
curl -sL -o "$SHA_PATH" "${ALPINE_BASE_URL}/${ALPINE_SHA256}"

info "驗證 SHA256..."
EXPECTED_SHA=$(awk '{print $1}' "$SHA_PATH")

if command -v shasum &>/dev/null; then
  ACTUAL_SHA=$(shasum -a 256 "$ISO_PATH" | awk '{print $1}')
else
  ACTUAL_SHA=$(sha256sum "$ISO_PATH" | awk '{print $1}')
fi

if [ "$EXPECTED_SHA" = "$ACTUAL_SHA" ]; then
  success "SHA256 驗證通過：$ACTUAL_SHA"
else
  die "SHA256 驗證失敗！\n  期望：$EXPECTED_SHA\n  實際：$ACTUAL_SHA\n  請重新下載"
fi

echo ""

# ==========================================================================
# 步驟 2：VMware Fusion 下載指引
# ==========================================================================
info "=== VMware Fusion ${VMWARE_VERSION} (Build ${VMWARE_BUILD}) ==="
echo ""
echo "  VMware Fusion 需透過 Broadcom 帳號登入後下載，無法自動下載。"
echo "  請手動前往以下步驟："
echo ""
echo "  1. 開啟瀏覽器，前往："
echo "     ${VMWARE_URL}"
echo ""
echo "  2. 登入（或免費註冊）Broadcom 帳號"
echo ""
echo "  3. 在下載頁面選擇："
echo "     Release: 13.6.4"
echo "     Build:   ${VMWARE_BUILD}"
echo "     檔案:    VMware-Fusion-${VMWARE_VERSION}-${VMWARE_BUILD}-universal.dmg"
echo ""
echo "  4. 下載後雙擊 .dmg 安裝"
echo ""

# 確認 VMware Fusion 是否已安裝
if [ -d "/Applications/VMware Fusion.app" ]; then
  INSTALLED_VER=$(/Applications/VMware\ Fusion.app/Contents/Library/vmware-vmx --version 2>/dev/null | head -1 || echo "無法取得版本")
  success "VMware Fusion 已安裝：$INSTALLED_VER"
else
  warn "VMware Fusion 尚未安裝"
fi

echo ""

# ==========================================================================
# 步驟 3：顯示後續操作摘要
# ==========================================================================
echo "╔══════════════════════════════════════════════════════╗"
echo "║  下載完成！後續步驟                                  ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  %-52s ║\n" "Alpine ISO 位置："
printf "║    %-50s ║\n" "$(basename "$ISO_PATH")"
printf "║  %-52s ║\n" ""
printf "║  %-52s ║\n" "接下來："
printf "║  %-52s ║\n" "  1. 確認 VMware Fusion 13.6.4 已安裝"
printf "║  %-52s ║\n" "  2. 建立新 VM（Other Linux 6.x 64-bit ARM）"
printf "║  %-52s ║\n" "  3. CD/DVD 選擇上方 ISO 路徑"
printf "║  %-52s ║\n" "  4. 開機後執行 arch-chroot-install.sh"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
info "詳細步驟見：vmware/README.md"
echo ""
