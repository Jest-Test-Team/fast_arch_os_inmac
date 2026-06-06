# fast_arch_os_inmac

在 **Mac M1 (ARM64)** 上建立完整 Arch Linux 環境的兩條路徑。

## 路徑總覽

| | Path 1 — VMware Fusion | Path 2 — Docker |
|---|---|---|
| 隔離程度 | 完整 VM 隔離 | 核心共享 (Mac kernel) |
| systemd | 完整支援 | 受限 |
| 桌面 GUI | 支援 | 不支援 |
| 啟動速度 | 30–60 秒 | 秒級 |
| 磁碟佔用 | ~10–30 GB | ~2 GB |
| 適合場景 | 完整 OS 體驗、系統級測試 | CLI 開發工具、快速迭代 |

---

## 前置需求

### 共同需求
- Mac M1 / M2 / M3（ARM64 架構）
- 至少 8 GB 可用記憶體，30 GB 可用磁碟空間

### Path 1 — VMware Fusion

**VMware Fusion 版本選擇：**

| 版本 | Build | 建議 |
|---|---|---|
| **13.6.4** | **533271** | **推薦** — M1/M2/M3 ARM64 VM 支援最穩定 |
| 25H2 / 26H1 | — | 可用，但社群資源較少 |
| 13.5.2 以下 | — | 不建議，ARM64 相容性問題 |

- 下載：[Broadcom VMware Fusion 13.6.4 (Build 533271)](https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware+Fusion)，選 **Release 13.6.4**，免費個人授權

**Alpine Linux ISO 選擇：**

| 類型 | 檔名 | 適合 VMware？ |
|---|---|---|
| **alpine-virt-\*** | **alpine-virt-3.23.4-aarch64.iso** | **是（首選）** — 專為 VM 最佳化，90 MB |
| alpine-standard-\* | alpine-standard-3.23.4-aarch64.iso | 可用，但 373 MB |
| alpine-minirootfs-\* | *.tar.gz | 否，非可開機 ISO |
| alpine-rpi-\* | *.img | 否，Raspberry Pi 專用 |
| alpine-uboot-\* | *.tar.gz | 否，嵌入式裝置用 |
| alpine-netboot-\* | *.tar.gz | 否，需 PXE 環境 |

- 下載：[alpine-virt-3.23.4-aarch64.iso](https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/alpine-virt-3.23.4-aarch64.iso)（90 MB，作為安裝媒介）

### Path 2 — Docker
- [Docker Desktop for Apple Silicon](https://www.docker.com/products/docker-desktop/)

---

## 目錄結構

```
fast_arch_os_inmac/
├── README.md               # 本文件
├── Makefile                # Docker 快捷指令
├── docker/
│   ├── Dockerfile          # ARM64 Arch Linux 映像
│   ├── docker-compose.yml  # 容器設定（含 volume）
│   └── scripts/
│       ├── entrypoint.sh   # 容器啟動腳本
│       └── bootstrap.sh    # 首次環境初始化
├── vmware/
│   ├── README.md           # VMware 詳細安裝步驟
│   └── scripts/
│       ├── arch-chroot-install.sh  # Arch ARM 自動安裝腳本
│       └── post-install.sh         # chroot 後系統設定
└── config/
    ├── pacman.conf         # pacman 設定（含 ARM mirror）
    ├── mirrorlist-arm      # Arch Linux ARM mirror 清單
    └── locale.gen          # locale 設定
```

---

## 快速開始

### Path 1 — VMware Fusion

詳見 [vmware/README.md](vmware/README.md)。

```bash
# 1. 安裝 VMware Fusion 13（免費個人版）
# 2. 下載 Alpine Linux aarch64 ISO
# 3. 建立 VM，掛載 ISO 開機
# 4. 在 Alpine live 環境內執行安裝腳本
wget -qO- https://raw.githubusercontent.com/your-repo/fast_arch_os_inmac/main/vmware/scripts/arch-chroot-install.sh | sh
```

### Path 2 — Docker

```bash
# 確認 Docker Desktop 已啟動（Apple Silicon 版）
make build    # 建構 ARM64 Arch Linux 映像（首次約 5–10 分鐘）
make shell    # 進入互動式 Arch Linux shell
```

---

## 常用指令

| 指令 | 說明 |
|---|---|
| `make build` | 建構 Docker 映像 |
| `make up` | 背景啟動容器 |
| `make shell` | 進入互動式 shell |
| `make exec CMD="pacman -Syu"` | 在容器內執行指令 |
| `make clean` | 移除容器與 volume |
| `make logs` | 查看容器輸出 |

---

## 注意事項

- 本專案所有腳本皆針對 **aarch64 (ARM64)** 架構，不適用 x86_64
- VMware 路徑使用 [Arch Linux ARM](https://archlinuxarm.org/) rootfs tarball
- Docker 路徑使用 `archlinux/archlinux:base-devel` 官方映像（支援 linux/arm64）
- Arch Linux 官方 ISO **不提供** ARM64 版本，故 VMware 路徑需透過 Alpine 作為安裝媒介
