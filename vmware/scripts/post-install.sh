#!/usr/bin/env bash
# =============================================================================
# post-install.sh
# 在 Arch Linux ARM chroot 環境內執行，完成系統初始設定
#
# 由 arch-chroot-install.sh 自動呼叫，也可單獨在 chroot 環境手動執行：
#   arch-chroot /mnt bash /tmp/post-install.sh
#
# 環境變數（由 arch-chroot-install.sh 透過 /tmp/install-config.sh 提供）：
#   HOSTNAME, DEFAULT_USER, EFI_PART, ROOT_PART
# =============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# 載入安裝設定（由主安裝腳本寫入）
# --------------------------------------------------------------------------
if [ -f /tmp/install-config.sh ]; then
  # shellcheck source=/dev/null
  source /tmp/install-config.sh
else
  # 互動式執行時的預設值
  HOSTNAME="${HOSTNAME:-archvm}"
  DEFAULT_USER="${DEFAULT_USER:-arch}"
  EFI_PART="${EFI_PART:-/dev/sda1}"
  ROOT_PART="${ROOT_PART:-/dev/sda2}"
fi

info()    { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
success() { printf '\033[1;32m[OK]\033[0m   %s\n' "$*"; }
warn()    { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }

# ==========================================================================
# 1. 初始化 pacman keyring
# ==========================================================================
info "初始化 pacman keyring..."
pacman-key --init
pacman-key --populate archlinuxarm
success "keyring 初始化完成"

# ==========================================================================
# 2. 更新系統與安裝基礎套件
# ==========================================================================
info "更新系統套件..."
pacman -Syu --noconfirm

info "安裝基礎工具..."
pacman -S --noconfirm --needed \
  base \
  base-devel \
  linux-aarch64 \
  linux-firmware \
  grub \
  efibootmgr \
  networkmanager \
  openssh \
  git \
  vim \
  zsh \
  sudo \
  wget \
  curl \
  htop \
  man-db \
  man-pages \
  open-vm-tools \
  xf86-input-vmmouse

success "基礎套件安裝完成"

# ==========================================================================
# 3. 時區與 Locale 設定
# ==========================================================================
info "設定時區 Asia/Taipei..."
ln -sf /usr/share/zoneinfo/Asia/Taipei /etc/localtime
hwclock --systohc

info "設定 locale..."
# 啟用 en_US.UTF-8 與 zh_TW.UTF-8
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/^#zh_TW.UTF-8/zh_TW.UTF-8/' /etc/locale.gen
locale-gen

cat > /etc/locale.conf << 'EOF'
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF

success "Locale 設定完成"

# ==========================================================================
# 4. Hostname 設定
# ==========================================================================
info "設定 hostname：$HOSTNAME..."
echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain  ${HOSTNAME}
EOF

success "Hostname 設定完成"

# ==========================================================================
# 5. 網路服務
# ==========================================================================
info "啟用 NetworkManager..."
systemctl enable NetworkManager
systemctl enable sshd

success "網路服務已設定開機啟動"

# ==========================================================================
# 6. 建立一般使用者
# ==========================================================================
info "建立使用者：$DEFAULT_USER..."
if ! id "$DEFAULT_USER" &>/dev/null; then
  useradd -m -G wheel,audio,video,storage,optical -s /bin/zsh "$DEFAULT_USER"
fi

# 設定 sudo（wheel 群組無密碼）
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

success "使用者 $DEFAULT_USER 建立完成"

# ==========================================================================
# 7. 設定密碼
# ==========================================================================
info "設定 root 密碼..."
echo "root:root" | chpasswd
warn "root 密碼已設為預設值 'root'，請首次登入後立即修改：passwd root"

info "設定 $DEFAULT_USER 密碼..."
echo "${DEFAULT_USER}:${DEFAULT_USER}" | chpasswd
warn "${DEFAULT_USER} 密碼已設為預設值 '$DEFAULT_USER'，請首次登入後立即修改"

# ==========================================================================
# 8. fstab 生成
# ==========================================================================
info "生成 /etc/fstab..."
# 使用 UUID 確保磁碟代號變更時仍可開機
EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")

cat > /etc/fstab << EOF
# <device>                               <dir>       <type>  <options>       <dump>  <fsck>
UUID=${ROOT_UUID}                        /           ext4    defaults        0       1
UUID=${EFI_UUID}                         /boot/efi   vfat    umask=0077      0       2
tmpfs                                    /tmp        tmpfs   defaults,noatime 0      0
EOF

success "/etc/fstab 生成完成"

# ==========================================================================
# 9. 安裝 GRUB bootloader（arm64-efi）
# ==========================================================================
info "安裝 GRUB bootloader (arm64-efi)..."
grub-install \
  --target=arm64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=ARCH \
  --recheck

info "生成 GRUB 設定..."
grub-mkconfig -o /boot/grub/grub.cfg

success "GRUB 安裝完成"

# ==========================================================================
# 10. VMware Tools 設定
# ==========================================================================
info "啟用 VMware open-vm-tools..."
systemctl enable vmtoolsd
systemctl enable vmware-vmblock-fuse

# 建立 vmhgfs 掛載點（用於 VMware 共享資料夾）
mkdir -p /mnt/hgfs

cat >> /etc/fstab << 'EOF'

# VMware 共享資料夾（需要 open-vm-tools）
.host:/  /mnt/hgfs  fuse.vmhgfs-fuse  defaults,allow_other,uid=1000  0  0
EOF

success "VMware Tools 設定完成"

# ==========================================================================
# 11. zsh 設定（oh-my-zsh 骨架）
# ==========================================================================
info "設定 zsh 預設 shell..."
chsh -s /bin/zsh root
chsh -s /bin/zsh "$DEFAULT_USER"

# 為 root 建立基本 .zshrc
cat > /root/.zshrc << 'EOF'
# Basic zsh config
export LANG=en_US.UTF-8
export EDITOR=vim
PROMPT='%F{red}%n@%m%f %F{cyan}%~%f %# '
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias pacup='sudo pacman -Syu'
alias pacin='sudo pacman -S'
alias pacse='pacman -Ss'
EOF

# 為一般使用者建立相同設定
cp /root/.zshrc "/home/${DEFAULT_USER}/.zshrc"
chown "${DEFAULT_USER}:${DEFAULT_USER}" "/home/${DEFAULT_USER}/.zshrc"

success "zsh 設定完成"

# ==========================================================================
# 12. 清理暫存檔
# ==========================================================================
info "清理暫存檔..."
pacman -Sc --noconfirm
rm -f /tmp/install-config.sh /tmp/post-install.sh

# ==========================================================================
# 完成
# ==========================================================================
success "======================================"
success " chroot 後系統設定完成！"
success "======================================"
echo
info "已完成設定："
info "  ✓ pacman keyring 初始化"
info "  ✓ 系統更新 + 基礎套件安裝"
info "  ✓ 時區 (Asia/Taipei) + locale (zh_TW.UTF-8)"
info "  ✓ Hostname: $HOSTNAME"
info "  ✓ NetworkManager + sshd 開機啟動"
info "  ✓ 使用者 $DEFAULT_USER (wheel 群組)"
info "  ✓ GRUB arm64-efi bootloader"
info "  ✓ open-vm-tools + vmhgfs 共享資料夾"
info "  ✓ zsh 預設 shell"
echo
warn "安全提醒：請首次登入後立即修改密碼！"
warn "  root：passwd root"
warn "  $DEFAULT_USER：passwd $DEFAULT_USER"
echo
