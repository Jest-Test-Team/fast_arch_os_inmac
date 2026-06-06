# VMware Fusion — Arch Linux ARM on Mac M1

本文件說明如何在 Mac M1 上使用 VMware Fusion 13 安裝完整的 Arch Linux ARM (aarch64) 虛擬機。

---

## 前置需求

| 需求 | 版本 / 說明 |
|---|---|
| **VMware Fusion** | **13.6.4 (Build 533271)** — [Broadcom 下載頁](https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware+Fusion)，選 Release **13.6.4**，免費個人授權 |
| **Alpine Linux ISO** | **alpine-virt-3.23.4-aarch64.iso**（90 MB）— [直接下載](https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/alpine-virt-3.23.4-aarch64.iso)，`virt` 版專為虛擬機最佳化 |
| 磁碟空間 | 至少 30 GB 可用空間 |
| 記憶體 | 建議分配給 VM 至少 2 GB（4 GB 更佳） |

### 為何選 VMware Fusion 13.6.4？

- 目前 M1/M2/M3 上 ARM64 Linux VM 支援最穩定的版本
- `linux-aarch64` kernel 相容性最佳
- Arch Linux ARM 社群安裝指南以此版本為基礎
- 個人使用完全免費（需 Broadcom 帳號）

### 為何選 alpine-virt ISO？

| 類型 | 大小 | 說明 |
|---|---|---|
| **alpine-virt-3.23.4** | 90 MB | **推薦**：針對 VM/Hypervisor 最佳化，無多餘硬體驅動 |
| alpine-standard-3.23.4 | 373 MB | 完整版，包含多餘的實體機驅動 |
| alpine-minirootfs | 4 MB | 非 ISO，無法作為開機媒介 |
| alpine-rpi | 87 MB | Raspberry Pi 專用，VMware 不相容 |

---

## 步驟一：下載前置檔案

在 **Mac** 上執行（不是在 VM 內）：

```bash
bash vmware/scripts/download-deps.sh
```

腳本會自動：
- 下載 `alpine-virt-3.23.4-aarch64.iso`（90 MB）至 `downloads/` 目錄
- 驗證 SHA256 checksum
- 顯示 VMware Fusion 13.6.4 的手動下載指引（需 Broadcom 帳號）

> VMware Fusion 需手動登入 [Broadcom 下載頁](https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware+Fusion) 下載：選 **Release 13.6.4**（Build 533271）

---

## 步驟二：建立 VMware 虛擬機

1. 開啟 VMware Fusion → **File → New**
2. 選擇 **Create a custom virtual machine**
3. 作業系統選擇：**Linux → Other Linux 6.x kernel 64-bit ARM**
4. 韌體：**UEFI**
5. 建立新虛擬磁碟，大小 ≥ **30 GB**（建議 NVME 模式）
6. 完成後，進入 VM 設定：
   - **Processors & Memory**：CPU ≥ 2 核心，Memory ≥ 2048 MB
   - **CD/DVD**：勾選「Connect CD/DVD Drive」，選擇 `downloads/alpine-virt-3.23.4-aarch64.iso`
7. 啟動 VM，進入 Alpine Linux live 環境

---

## 步驟三：進入 Alpine live 環境

開機後以 `root`（無密碼）登入，確認網路：

```bash
# 確認網路通訊
ping -c 3 archlinuxarm.org

# 若無網路，手動設定 DHCP
udhcpc -i eth0
```

---

## 步驟三：執行自動安裝腳本

將 `arch-chroot-install.sh` 複製到 VM 內（或直接輸入），然後執行：

```bash
# 方法 A：從 VM 的共享資料夾複製（若已設定 shared folder）
# 方法 B：手動 wget（需要網路）
wget -O /tmp/arch-install.sh \
  https://raw.githubusercontent.com/YOUR_REPO/fast_arch_os_inmac/main/vmware/scripts/arch-chroot-install.sh

# 賦予執行權限並執行
chmod +x /tmp/arch-install.sh
sh /tmp/arch-install.sh
```

腳本將自動：
1. 分割磁碟（GPT：512 MB EFI + 剩餘 root）
2. 格式化並掛載分割區
3. 下載 Arch Linux ARM rootfs tarball
4. 解壓並 chroot 進行系統設定

> **預估時間**：依網路速度而定，約 10–20 分鐘

---

## 步驟四：chroot 後系統設定

`arch-chroot-install.sh` 執行完畢後，會自動呼叫 `post-install.sh`，設定：

| 項目 | 預設值 |
|---|---|
| Hostname | `archvm` |
| Locale | `zh_TW.UTF-8` + `en_US.UTF-8` |
| Timezone | `Asia/Taipei` |
| Root 密碼 | 安裝時提示輸入 |
| 一般使用者 | `arch`，加入 `wheel` 群組 |
| Bootloader | GRUB (arm64-efi) |
| VMware 工具 | `open-vm-tools` |

---

## 步驟五：首次開機

1. 安裝完成後，輸入 `poweroff` 關機
2. 在 VMware Fusion 設定中，**卸除 Alpine ISO**（CD/DVD → Disconnect）
3. 重新啟動 VM
4. 以 `root` 或 `arch` 使用者登入

```bash
# 啟動 VMware 工具（剪貼簿、共享資料夾）
systemctl enable --now vmtoolsd open-vm-tools

# 更新系統
pacman -Syu

# 確認架構
uname -m   # 應顯示 aarch64
```

---

## 可選：安裝桌面環境

### XFCE（輕量，推薦）

```bash
pacman -S xorg xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
systemctl enable lightdm
reboot
```

### GNOME

```bash
pacman -S gnome gnome-extra gdm
systemctl enable gdm
reboot
```

### Hyprland（Wayland，現代感）

```bash
pacman -S hyprland waybar wofi foot
# 詳見 https://wiki.archlinux.org/title/Hyprland
```

---

## VMware Fusion 進階設定

### 共享資料夾（Mac ↔ VM）

1. VMware Fusion → 右鍵 VM → **Settings → Sharing**
2. 開啟共享，新增 Mac 上的資料夾
3. 在 VM 內：

```bash
# 確認 vmhgfs-fuse 可用
pacman -S open-vm-tools
vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other

# 永久掛載（加入 /etc/fstab）
echo '.host:/ /mnt/hgfs fuse.vmhgfs-fuse defaults,allow_other 0 0' >> /etc/fstab
```

### 網路設定

| 模式 | 說明 |
|---|---|
| NAT（預設） | VM 透過 Mac 存取網際網路，外部無法直接連入 |
| Bridged | VM 取得與 Mac 同網段的 IP，適合 server 測試 |
| Host-only | 僅 Mac↔VM 通訊，適合隔離環境 |

### 建立快照

```
VMware Fusion → Virtual Machine → Take Snapshot
建議在以下時機建立快照：
  - 首次開機設定完成後
  - 安裝桌面環境前後
  - 進行系統實驗前
```

---

## 疑難排解

| 問題 | 解法 |
|---|---|
| 開機進入 GRUB rescue | 確認 `/boot/efi` 已正確掛載 EFI 分割區，重新執行 `grub-install` |
| 網路無法連線 | 執行 `systemctl enable --now NetworkManager` |
| pacman keyring 錯誤 | `pacman-key --init && pacman-key --populate archlinuxarm` |
| VMware Tools 無法啟動 | `pacman -S open-vm-tools && systemctl enable --now vmtoolsd` |
| 畫面解析度問題 | 安裝 `xf86-video-vmware`（X11）或調整 Wayland 設定 |

---

## 參考資源

- [Arch Linux ARM 官網](https://archlinuxarm.org/)
- [VMware Fusion 文件](https://docs.vmware.com/en/VMware-Fusion/index.html)
- [Arch Linux Wiki — Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
- [Arch Linux Wiki — VMware](https://wiki.archlinux.org/title/VMware)
