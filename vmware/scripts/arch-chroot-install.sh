#!/usr/bin/env sh
# =============================================================================
# arch-chroot-install.sh
# 在 Alpine Linux ARM64 live 環境內執行，自動安裝 Arch Linux ARM 到虛擬磁碟
#
# 使用方式（在 Alpine VM shell 內以 root 執行）：
#   sh arch-chroot-install.sh [--disk auto|/dev/nvme0n1|/dev/sda] \
#                             [--hostname archvm] [--user arch]
#
# 從 Mac 取得此腳本：
#   bash vmware/scripts/serve.sh   (在 Mac 端執行，取得 wget 指令)
#
# 注意：
#   - 必須在 Alpine Linux aarch64 live 環境中以 root 執行，不可在 Mac 上執行
#   - 目標磁碟的所有資料將被清除，請確認磁碟代號正確（用 lsblk 查詢）
#   - VMware NVMe 磁碟通常為 /dev/nvme0n1，SATA 為 /dev/sda
#   - 需要網路連線（下載 Arch Linux ARM rootfs，約 500 MB）
# =============================================================================

set -e

# --------------------------------------------------------------------------
# 預設參數
# --------------------------------------------------------------------------
TARGET_DISK="auto"
HOSTNAME="archvm"
DEFAULT_USER="arch"
ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
MOUNT_POINT="/mnt"
POST_INSTALL_URL=""

# --------------------------------------------------------------------------
# 解析命令列參數
# --------------------------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --disk)         TARGET_DISK="$2";        shift 2 ;;
    --hostname)     HOSTNAME="$2";           shift 2 ;;
    --user)         DEFAULT_USER="$2";       shift 2 ;;
    --post-url)     POST_INSTALL_URL="$2";   shift 2 ;;
    *) echo "未知參數：$1  (有效參數: --disk --hostname --user --post-url)"; exit 1 ;;
  esac
done

# --------------------------------------------------------------------------
# 顏色輸出輔助函式
# --------------------------------------------------------------------------
info()    { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
success() { printf '\033[1;32m[OK]\033[0m   %s\n' "$*"; }
warn()    { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()     { printf '\033[1;31m[ERR]\033[0m  %s\n' "$*"; exit 1; }

# --------------------------------------------------------------------------
# 防呆：禁止在 macOS 上執行
# --------------------------------------------------------------------------
if [ "$(uname -s)" = "Darwin" ]; then
  die "此腳本必須在 Alpine Linux VM 內部以 root 執行，不可在 Mac 上執行。
  請先執行：bash vmware/scripts/serve.sh
  然後在 Alpine VM shell 內依照指示下載並執行此腳本。"
fi

# --------------------------------------------------------------------------
# 前置檢查
# --------------------------------------------------------------------------
info "=== Arch Linux ARM 自動安裝腳本 (aarch64 / VMware Fusion) ==="
echo

[ "$(id -u)" -eq 0 ] || die "必須以 root 執行此腳本（Alpine live 預設即為 root）"

# --------------------------------------------------------------------------
# 自動偵測磁碟
# --------------------------------------------------------------------------
if [ "$TARGET_DISK" = "auto" ]; then
  info "自動偵測虛擬磁碟..."
  for candidate in /dev/nvme0n1 /dev/vda /dev/sda /dev/hda; do
    if [ -b "$candidate" ]; then
      TARGET_DISK="$candidate"
      success "偵測到磁碟：$TARGET_DISK"
      break
    fi
  done
  [ "$TARGET_DISK" = "auto" ] && die "找不到可用磁碟。請執行 lsblk 確認後加上 --disk /dev/<磁碟> 參數"
fi

[ -b "$TARGET_DISK" ] || die "磁碟 $TARGET_DISK 不存在。請執行 lsblk 確認正確磁碟代號"

info "目標磁碟：$TARGET_DISK  ($(lsblk -dno SIZE "$TARGET_DISK" 2>/dev/null || echo '?'))"
info "Hostname ：$HOSTNAME"
info "使用者   ：$DEFAULT_USER"
echo

# 磁碟大小警告（建議 ≥ 20 GB）
DISK_BYTES=$(lsblk -dno SIZE --bytes "$TARGET_DISK" 2>/dev/null || echo 0)
MIN_BYTES=21474836480  # 20 GB
if [ "$DISK_BYTES" -lt "$MIN_BYTES" ] 2>/dev/null; then
  warn "磁碟容量不足 20 GB（$(lsblk -dno SIZE "$TARGET_DISK")）"
  warn "建議在 VMware Fusion → VM Settings → Hard Disk 調整至 ≥ 30 GB"
  printf "確定要繼續？[y/N] "
  read -r CONFIRM
  [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ] || die "已取消。請先擴充磁碟後再執行"
fi

# --------------------------------------------------------------------------
# 確認網路
# --------------------------------------------------------------------------
info "檢查網路連線..."
ping -c 1 -W 5 archlinuxarm.org > /dev/null 2>&1 || \
  die "無法連線至 archlinuxarm.org。請確認：
  - Alpine VM 網路為 NAT 模式
  - 執行：udhcpc -i eth0 或 udhcpc -i ens160"
success "網路正常"

# --------------------------------------------------------------------------
# 安裝必要工具
# --------------------------------------------------------------------------
info "安裝必要工具 (parted, e2fsprogs, dosfstools, wget, tar)..."
apk add --quiet --no-progress parted e2fsprogs dosfstools wget tar 2>/dev/null || \
apk add --quiet parted e2fsprogs dosfstools wget tar
success "工具安裝完成"

# --------------------------------------------------------------------------
# 取得 post-install.sh
# --------------------------------------------------------------------------
POST_SCRIPT=""
# 優先：與本腳本同目錄
SELF_DIR="$(dirname "$0")"
if [ -f "$SELF_DIR/post-install.sh" ]; then
  POST_SCRIPT="$SELF_DIR/post-install.sh"
elif [ -f "/tmp/post-install.sh" ]; then
  POST_SCRIPT="/tmp/post-install.sh"
elif [ -n "$POST_INSTALL_URL" ]; then
  info "下載 post-install.sh 從 $POST_INSTALL_URL..."
  wget -q -O /tmp/post-install.sh "$POST_INSTALL_URL"
  POST_SCRIPT="/tmp/post-install.sh"
else
  die "找不到 post-install.sh。請確認：
  1. 與 arch-chroot-install.sh 同目錄有 post-install.sh，或
  2. /tmp/post-install.sh 存在（透過 wget 下載），或
  3. 加上 --post-url <URL> 參數"
fi
success "使用 post-install.sh：$POST_SCRIPT"

# --------------------------------------------------------------------------
# 磁碟分割（GPT：512 MB EFI + 剩餘 root）
# --------------------------------------------------------------------------
info "分割磁碟 $TARGET_DISK（所有現有資料將被清除）..."
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart EFI fat32 1MiB 513MiB
parted -s "$TARGET_DISK" set 1 esp on
parted -s "$TARGET_DISK" mkpart root ext4 513MiB 100%

sleep 1
partprobe "$TARGET_DISK" 2>/dev/null || true

# NVMe 磁碟分割區命名為 p1/p2，其他為 1/2
if echo "$TARGET_DISK" | grep -q "nvme"; then
  EFI_PART="${TARGET_DISK}p1"
  ROOT_PART="${TARGET_DISK}p2"
else
  EFI_PART="${TARGET_DISK}1"
  ROOT_PART="${TARGET_DISK}2"
fi

success "磁碟分割完成：EFI=$EFI_PART，Root=$ROOT_PART"

# --------------------------------------------------------------------------
# 格式化
# --------------------------------------------------------------------------
info "格式化分割區..."
mkfs.fat -F32 -n EFI "$EFI_PART"
mkfs.ext4 -L archroot -q "$ROOT_PART"
success "格式化完成"

# --------------------------------------------------------------------------
# 掛載
# --------------------------------------------------------------------------
info "掛載分割區..."
mount "$ROOT_PART" "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT/boot/efi"
mount "$EFI_PART" "$MOUNT_POINT/boot/efi"
success "掛載完成：$MOUNT_POINT"

# --------------------------------------------------------------------------
# 下載 Arch Linux ARM rootfs
# --------------------------------------------------------------------------
ROOTFS_FILE="/tmp/ArchLinuxARM-aarch64-latest.tar.gz"
if [ -f "$ROOTFS_FILE" ]; then
  warn "找到既有 rootfs：$ROOTFS_FILE，跳過下載"
else
  info "下載 Arch Linux ARM rootfs（約 500 MB，依網速需 5–15 分鐘）..."
  wget --show-progress -O "$ROOTFS_FILE" "$ROOTFS_URL" || \
    die "下載失敗。請確認網路連線或手動下載：$ROOTFS_URL"
fi
success "rootfs 準備完成"

# --------------------------------------------------------------------------
# 解壓 rootfs
# --------------------------------------------------------------------------
info "解壓 rootfs 至 $MOUNT_POINT（約需 2–5 分鐘）..."
tar -xzf "$ROOTFS_FILE" -C "$MOUNT_POINT" --numeric-owner
success "解壓完成"

# --------------------------------------------------------------------------
# 複製 post-install.sh 與設定到 chroot 環境
# --------------------------------------------------------------------------
info "準備 chroot 環境設定..."
cp "$POST_SCRIPT" "$MOUNT_POINT/tmp/post-install.sh"
chmod +x "$MOUNT_POINT/tmp/post-install.sh"

cat > "$MOUNT_POINT/tmp/install-config.sh" << EOF
HOSTNAME="$HOSTNAME"
DEFAULT_USER="$DEFAULT_USER"
EFI_PART="$EFI_PART"
ROOT_PART="$ROOT_PART"
EOF

# --------------------------------------------------------------------------
# 掛載偽檔案系統
# --------------------------------------------------------------------------
info "掛載偽檔案系統 (proc/sys/dev/run)..."
mount --bind /proc "$MOUNT_POINT/proc"
mount --bind /sys  "$MOUNT_POINT/sys"
mount --bind /dev  "$MOUNT_POINT/dev"
mount --bind /run  "$MOUNT_POINT/run"

if [ -d /sys/firmware/efi/efivars ]; then
  mount --bind /sys/firmware/efi/efivars "$MOUNT_POINT/sys/firmware/efi/efivars"
else
  warn "EFI vars 不可掛載（VMware BIOS 模式，GRUB 將以 i386-pc 模式安裝）"
fi

# --------------------------------------------------------------------------
# 進入 chroot 執行 post-install.sh
# --------------------------------------------------------------------------
info "進入 chroot 環境執行 post-install.sh..."
chroot "$MOUNT_POINT" /bin/bash /tmp/post-install.sh

# --------------------------------------------------------------------------
# 清理掛載點
# --------------------------------------------------------------------------
info "卸除掛載點..."
umount "$MOUNT_POINT/sys/firmware/efi/efivars" 2>/dev/null || true
umount "$MOUNT_POINT/run"  2>/dev/null || true
umount "$MOUNT_POINT/dev"  2>/dev/null || true
umount "$MOUNT_POINT/sys"  2>/dev/null || true
umount "$MOUNT_POINT/proc" 2>/dev/null || true
umount "$MOUNT_POINT/boot/efi" 2>/dev/null || true
umount "$MOUNT_POINT" 2>/dev/null || true

# --------------------------------------------------------------------------
# 完成
# --------------------------------------------------------------------------
echo
success "╔══════════════════════════════════════╗"
success "║  Arch Linux ARM 安裝完成！            ║"
success "╚══════════════════════════════════════╝"
echo
info "下一步："
info "  1. 輸入 poweroff 關閉 VM"
info "  2. VMware Fusion → VM Settings → CD/DVD → 取消勾選（移除 Alpine ISO）"
info "  3. 重新啟動 VM"
info "  4. 以 root（預設密碼：root）登入後立即執行：passwd root"
info "  5. 同樣修改 $DEFAULT_USER 密碼：passwd $DEFAULT_USER"
echo
