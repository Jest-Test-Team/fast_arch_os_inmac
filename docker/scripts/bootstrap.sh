#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — 容器首次啟動時的環境初始化
# 由 entrypoint.sh 在 ~/.arch-bootstrap-done 不存在時自動呼叫
#
# 負責：
#   - 設定 git 全域設定（若 .gitconfig 不存在）
#   - 建立常用目錄結構
#   - 安裝 oh-my-zsh（可選）
#   - 顯示歡迎訊息
# =============================================================================

set -euo pipefail

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  Arch Linux ARM — Docker 開發環境      ║"
echo "║  Mac M1 (ARM64) | fast_arch_os_inmac   ║"
echo "╚════════════════════════════════════════╝"
echo ""

# --------------------------------------------------------------------------
# 建立常用目錄
# --------------------------------------------------------------------------
mkdir -p \
  "${HOME}/go/src" \
  "${HOME}/go/bin" \
  "${HOME}/go/pkg" \
  "${HOME}/.local/bin" \
  "${HOME}/.config" \
  "${HOME}/projects"

echo "[bootstrap] 目錄結構建立完成"

# --------------------------------------------------------------------------
# 設定 git 全域設定（若尚未設定）
# --------------------------------------------------------------------------
if [ ! -f "${HOME}/.gitconfig" ]; then
  cat > "${HOME}/.gitconfig" << 'EOF'
[core]
    editor = vim
    autocrlf = input
    filemode = true
[color]
    ui = auto
[pull]
    rebase = false
[init]
    defaultBranch = main
[alias]
    st  = status
    co  = checkout
    br  = branch
    lg  = log --oneline --graph --decorate --all
    unstage = reset HEAD --
EOF
  echo "[bootstrap] git 設定完成（請執行 git config --global user.name/email 設定身份）"
fi

# --------------------------------------------------------------------------
# 顯示系統資訊
# --------------------------------------------------------------------------
echo ""
echo "=== 系統資訊 ==="
echo "  架構：$(uname -m)"
echo "  核心：$(uname -r)"
echo "  OS  ：$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
echo "  記憶：$(free -h | awk '/^Mem:/{print $2}') 總計 / $(free -h | awk '/^Mem:/{print $7}') 可用"
echo ""

# --------------------------------------------------------------------------
# 顯示快速說明
# --------------------------------------------------------------------------
cat << 'EOF'
=== 常用指令 ===
  pacman -Syu              更新所有套件
  pacman -S <pkg>          安裝套件
  pacman -Ss <keyword>     搜尋套件
  yay -S <aur-pkg>         從 AUR 安裝套件
  exit                     離開容器（容器繼續背景運行）

=== 工作目錄 ===
  /workspace               對應 Mac 上的專案根目錄

EOF
