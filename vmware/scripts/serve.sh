#!/usr/bin/env bash
# =============================================================================
# serve.sh — 在 Mac 端啟動 HTTP server，將安裝腳本傳遞給 Alpine VM
#
# 在 Mac 上執行（不是在 VM 內）：
#   bash vmware/scripts/serve.sh
#
# 此腳本會：
#   1. 自動偵測 VMware NAT 網路的 Mac IP (vmnet8 / vmnet1)
#   2. 啟動 Python HTTP server 服務整個專案目錄
#   3. 印出在 Alpine VM 內應輸入的完整指令
# =============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# 設定
# --------------------------------------------------------------------------
PORT=8888
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

info()    { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
success() { printf '\033[1;32m[OK]\033[0m   %s\n' "$*"; }
warn()    { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()     { printf '\033[1;31m[ERR]\033[0m  %s\n' "$*"; exit 1; }

# --------------------------------------------------------------------------
# 確認在 macOS 上執行
# --------------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "此腳本只能在 Mac 上執行"
command -v python3 >/dev/null 2>&1 || die "找不到 python3，請安裝 Homebrew python"

# --------------------------------------------------------------------------
# 自動偵測 VMware NAT IP
# --------------------------------------------------------------------------
info "偵測 VMware NAT 網路介面..."

HOST_IP=""
for iface in vmnet8 vmnet1 vmnet2; do
  IP=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
  if [ -n "$IP" ]; then
    HOST_IP="$IP"
    info "找到 VMware 介面 $iface → $IP"
    break
  fi
done

if [ -z "$HOST_IP" ]; then
  warn "找不到 vmnet 介面，嘗試用 en0 (Wi-Fi)..."
  HOST_IP=$(ipconfig getifaddr en0 2>/dev/null || true)
  [ -n "$HOST_IP" ] || die "無法取得任何 IP。請確認 VMware Fusion 已開啟，或手動設定 HOST_IP=<IP> 後重跑"
  warn "使用 en0 IP $HOST_IP（需確認 VM 網路模式為 Bridged）"
fi

success "Mac IP：$HOST_IP:$PORT"

# --------------------------------------------------------------------------
# 確認 post-install.sh 存在
# --------------------------------------------------------------------------
[ -f "$SCRIPT_DIR/vmware/scripts/arch-chroot-install.sh" ] || \
  die "找不到 arch-chroot-install.sh，請在專案根目錄執行：bash vmware/scripts/serve.sh"
[ -f "$SCRIPT_DIR/vmware/scripts/post-install.sh" ] || \
  die "找不到 post-install.sh"

# --------------------------------------------------------------------------
# 印出 Alpine VM 應執行的指令
# --------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  在 Alpine VM 的 shell（localhost:~#）貼上以下指令                  ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║                                                                      ║"
printf "║  BASE=http://%s:%s/vmware/scripts\n" "$HOST_IP" "$PORT"
echo "║                                                                      ║"
echo "║  wget -O /tmp/arch-install.sh  \$BASE/arch-chroot-install.sh         ║"
echo "║  wget -O /tmp/post-install.sh  \$BASE/post-install.sh                ║"
echo "║  chmod +x /tmp/arch-install.sh /tmp/post-install.sh                 ║"
echo "║                                                                      ║"
echo "║  # VMware NVMe 磁碟使用 nvme0n1，一般 SATA 使用 sda                ║"
echo "║  sh /tmp/arch-install.sh --disk /dev/nvme0n1                        ║"
echo "║                                                                      ║"
echo "║  # 若不確定磁碟代號，先執行：lsblk                                  ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# --------------------------------------------------------------------------
# 啟動 HTTP server（阻塞，Ctrl+C 停止）
# --------------------------------------------------------------------------
info "啟動 HTTP server → http://$HOST_IP:$PORT/"
info "等待 Alpine VM 下載中...（Ctrl+C 停止）"
echo ""

cd "$SCRIPT_DIR"
python3 -m http.server "$PORT" --bind 0.0.0.0
