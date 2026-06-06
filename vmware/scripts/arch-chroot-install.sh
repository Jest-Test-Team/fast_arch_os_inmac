#!/usr/bin/env sh
# =============================================================================
# arch-chroot-install.sh
# 在 Alpine Linux ARM64 live 環境內執行，自動安裝 Arch Linux ARM 到虛擬磁碟
#
# 使用方式：
#   sh arch-chroot-install.sh [--disk /dev/sda] [--hostname archvm] [--user arch]
#
# 注意：
#   - 必須在 Alpine Linux aarch64 live 環境中以 root 執行
#   - 目標磁碟的所有資料將被清除，請確認磁碟代號正確
#   - 需要網路連線（下載 Arch Linux ARM rootfs，約 500 MB）
# =============================================================================

set -e

# --------------------------------------------------------------------------
# 預設參數（可透過參數覆寫）
# --------------------------------------------------------------------------
TARGET_DISK="/dev/sda"
HOSTNAME="archvm"
DEFAULT_USER="arch"
ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOTFS_SHA="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz.md5"
MOUNT_POINT="/mnt"

# --------------------------------------------------------------------------
# 解析命令列參數
# --------------------------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --disk)      TARGET_DISK="$2";  shift 2 ;;
    --hostname)  HOSTNAME="$2";     shift 2 ;;
    --user)      DEFAULT_USER="$2"; shift 2 ;;
    *) echo "未知參數：$1"; exit 1 ;;
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
# 前置檢查
# --------------------------------------------------------------------------
info "=== Arch Linux ARM 自動安裝腳本 (aarch64 / VMware Fusion) ==="
info "目標磁碟：$TARGET_DISK"
info "Hostname：$HOSTNAME"
info "使用者：$DEFAULT_USER"
echo

[ "$(id -u)" -eq 0 ] || die "必須以 root 執行此腳本"
[ -b "$TARGET_DISK" ]  || die "磁碟 $TARGET_DISK 不存在，請確認後重試（如：--disk /dev/vda）"

# 確認網路可達
info "檢查網路連線..."
ping -c 1 -W 5 archlinuxarm.org > /dev/null 2>&1 || die "無法連線至 archlinuxarm.org，請確認網路設定"
success "網路正常"

# --------------------------------------------------------------------------
# 安裝必要工具（Alpine live 環境可能缺少 arch-chroot / parted）
# --------------------------------------------------------------------------
info "安裝必要工具..."
apk add --quiet parted e2fsprogs dosfstools wget tar arch-install-scripts 2>/dev/null || \
apk add --quiet parted e2fsprogs dosfstools wget tar

# --------------------------------------------------------------------------
# 磁碟分割（GPT：EFI 512 MB + root 剩餘全部）
# --------------------------------------------------------------------------
info "分割磁碟 $TARGET_DISK..."
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart EFI fat32 1MiB 513MiB
parted -s "$TARGET_DISK" set 1 esp on
parted -s "$TARGET_DISK" mkpart root ext4 513MiB 100%

# 等待核心更新分割表
sleep 1
partprobe "$TARGET_DISK" 2>/dev/null || true

# 判斷分割區命名（/dev/sda1 vs /dev/sda1 for nvme: /dev/nvme0n1p1）
if echo "$TARGET_DISK" | grep -q "nvme"; then
  EFI_PART="${TARGET_DISK}p1"
  ROOT_PART="${TARGET_DISK}p2"
else
  EFI_PART="${TARGET_DISK}1"
  ROOT_PART="${TARGET_DISK}2"
fi

success "磁碟分割完成：EFI=$EFI_PART，Root=$ROOT_PART"

# --------------------------------------------------------------------------
# 格式化分割區
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
info "下載 Arch Linux ARM rootfs（約 500 MB）..."
wget -q --show-progress -O "$ROOTFS_FILE" "$ROOTFS_URL" || \
  die "下載失敗，請檢查網路或 URL：$ROOTFS_URL"
success "下載完成：$ROOTFS_FILE"

# --------------------------------------------------------------------------
# 解壓 rootfs
# --------------------------------------------------------------------------
info "解壓 rootfs 至 $MOUNT_POINT（約需 2–5 分鐘）..."
tar -xzf "$ROOTFS_FILE" -C "$MOUNT_POINT" --numeric-owner
success "解壓完成"

# --------------------------------------------------------------------------
# 複製設定檔至 chroot 環境
# --------------------------------------------------------------------------
info "複製安裝腳本至 chroot 環境..."
cp "$(dirname "$0")/post-install.sh" "$MOUNT_POINT/tmp/post-install.sh"
chmod +x "$MOUNT_POINT/tmp/post-install.sh"

# 傳遞設定給 post-install.sh
cat > "$MOUNT_POINT/tmp/install-config.sh" << EOF
HOSTNAME="$HOSTNAME"
DEFAULT_USER="$DEFAULT_USER"
EFI_PART="$EFI_PART"
ROOT_PART="$ROOT_PART"
EOF

# --------------------------------------------------------------------------
# 掛載偽檔案系統（chroot 需要）
# --------------------------------------------------------------------------
info "掛載偽檔案系統..."
mount --bind /proc "$MOUNT_POINT/proc"
mount --bind /sys  "$MOUNT_POINT/sys"
mount --bind /dev  "$MOUNT_POINT/dev"
mount --bind /run  "$MOUNT_POINT/run"
# 掛載 EFI 韌體資訊（GRUB 需要）
[ -d /sys/firmware/efi/efivars ] && \
  mount --bind /sys/firmware/efi/efivars "$MOUNT_POINT/sys/firmware/efi/efivars" || \
  warn "EFI vars 不可用（VMware 環境可能正常）"

# --------------------------------------------------------------------------
# 進入 chroot 執行 post-install.sh
# --------------------------------------------------------------------------
info "進入 chroot 環境執行 post-install.sh..."
chroot "$MOUNT_POINT" /bin/bash /tmp/post-install.sh

# --------------------------------------------------------------------------
# 清理掛載點
# --------------------------------------------------------------------------
info "卸除掛載點..."
[ -d "$MOUNT_POINT/sys/firmware/efi/efivars" ] && \
  umount "$MOUNT_POINT/sys/firmware/efi/efivars" 2>/dev/null || true
umount "$MOUNT_POINT/run"
umount "$MOUNT_POINT/dev"
umount "$MOUNT_POINT/sys"
umount "$MOUNT_POINT/proc"
umount "$MOUNT_POINT/boot/efi"
umount "$MOUNT_POINT"

# --------------------------------------------------------------------------
# 完成
# --------------------------------------------------------------------------
success "======================================"
success " Arch Linux ARM 安裝完成！"
success "======================================"
echo
info "下一步："
info "  1. 在 VMware Fusion 設定中移除 Alpine ISO（CD/DVD → Disconnect）"
info "  2. 重新啟動 VM：poweroff，然後從 VMware Fusion 重新開機"
info "  3. 以 root（預設密碼：root）或 $DEFAULT_USER 登入"
info "  4. 立即修改 root 密碼：passwd root"
echo
