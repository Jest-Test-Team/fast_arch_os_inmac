# =============================================================================
# Makefile — Arch Linux ARM 雙路徑工具指令
# Path 1: VMware Fusion | Path 2: Docker
# 適用：Mac M1 (ARM64)
# =============================================================================

.DEFAULT_GOAL := help
SHELL         := /bin/zsh

# 專案設定
IMAGE_NAME     := fast-arch
CONTAINER_NAME := arch-dev
COMPOSE_FILE   := docker/docker-compose.yml

# 顏色
BOLD   := \033[1m
RESET  := \033[0m
GREEN  := \033[1;32m
CYAN   := \033[1;36m
YELLOW := \033[1;33m
MAGENTA := \033[1;35m

# --------------------------------------------------------------------------
# 說明
# --------------------------------------------------------------------------
.PHONY: help
help: ## 顯示所有可用指令
	@echo "$(BOLD)Arch Linux ARM on Mac M1 — 雙路徑工具$(RESET)"
	@echo ""
	@echo "$(MAGENTA)=== VMware Fusion 路徑 ===$(RESET)"
	@grep -E '^vmware[a-zA-Z_-]*:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)=== Docker 路徑 ===$(RESET)"
	@grep -E '^(build|up|down|shell|root|exec|update|install|logs|status|inspect|clean|prune|check|arch)[a-zA-Z_-]*:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# ==========================================================================
# VMware Fusion 路徑
# ==========================================================================

.PHONY: vmware-serve
vmware-serve: ## [VMware] 啟動 HTTP server，顯示 Alpine VM wget 指令
	@echo "$(BOLD)[vmware-serve]$(RESET) 啟動 HTTP server..."
	bash vmware/scripts/serve.sh

.PHONY: vmware-download
vmware-download: ## [VMware] 下載 Alpine ISO 並顯示 VMware Fusion 安裝指引
	@echo "$(BOLD)[vmware-download]$(RESET) 下載前置檔案..."
	bash vmware/scripts/download-deps.sh

.PHONY: vmware-help
vmware-help: ## [VMware] 顯示 VMware 安裝步驟摘要
	@echo "$(BOLD)VMware Fusion 安裝步驟$(RESET)"
	@echo ""
	@echo "  1. $(GREEN)make vmware-download$(RESET)  → 下載 Alpine virt ISO (alpine-virt-3.23.4-aarch64.iso)"
	@echo "  2. 手動安裝 VMware Fusion 13.6.4 (Build 533271)"
	@echo "     https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware+Fusion"
	@echo "  3. 建立 VM：Other Linux 6.x 64-bit ARM, UEFI, ≥30 GB, ≥2 GB RAM"
	@echo "  4. 掛載 downloads/alpine-virt-3.23.4-aarch64.iso 開機"
	@echo "  5. $(GREEN)make vmware-serve$(RESET)     → 取得 Alpine VM 應輸入的 wget 指令"
	@echo "  6. 在 Alpine VM 內執行安裝腳本"
	@echo "  詳見：vmware/README.md"
	@echo ""

# ==========================================================================
# Docker 路徑
# ==========================================================================

# --------------------------------------------------------------------------
# 映像建構
# --------------------------------------------------------------------------
.PHONY: build
build: ## [Docker] 建構 ARM64 Arch Linux 映像（首次約 10 分鐘）
	@echo "$(BOLD)[build]$(RESET) 建構映像 $(IMAGE_NAME)..."
	docker compose -f $(COMPOSE_FILE) build --no-cache

.PHONY: build-fast
build-fast: ## [Docker] 快速重建（使用 layer cache）
	@echo "$(BOLD)[build-fast]$(RESET) 快速重建..."
	docker compose -f $(COMPOSE_FILE) build

# --------------------------------------------------------------------------
# 容器生命週期
# --------------------------------------------------------------------------
.PHONY: up
up: ## [Docker] 背景啟動 Arch 容器
	@echo "$(BOLD)[up]$(RESET) 啟動容器..."
	docker compose -f $(COMPOSE_FILE) up -d

.PHONY: down
down: ## [Docker] 停止並移除容器（保留 volume）
	docker compose -f $(COMPOSE_FILE) down

.PHONY: restart
restart: down up ## [Docker] 重新啟動容器

.PHONY: stop
stop: ## [Docker] 停止容器（不移除）
	docker compose -f $(COMPOSE_FILE) stop

# --------------------------------------------------------------------------
# 互動操作
# --------------------------------------------------------------------------
.PHONY: shell
shell: ## [Docker] 進入互動式 Arch Linux shell
	@docker compose -f $(COMPOSE_FILE) up -d --quiet-pull 2>/dev/null || true
	@echo "$(BOLD)[shell]$(RESET) 進入 Arch Linux 環境... (exit 離開)"
	docker compose -f $(COMPOSE_FILE) exec arch zsh || \
	docker compose -f $(COMPOSE_FILE) exec arch bash

.PHONY: root
root: ## [Docker] 以 root 身份進入容器
	@docker compose -f $(COMPOSE_FILE) up -d --quiet-pull 2>/dev/null || true
	docker compose -f $(COMPOSE_FILE) exec -u root arch zsh || \
	docker compose -f $(COMPOSE_FILE) exec -u root arch bash

.PHONY: exec
exec: ## [Docker] 執行單一指令，例如：make exec CMD="pacman -Syu"
	@if [ -z "$(CMD)" ]; then echo "$(YELLOW)用法：make exec CMD=\"<指令>\"$(RESET)"; exit 1; fi
	docker compose -f $(COMPOSE_FILE) exec arch bash -c "$(CMD)"

# --------------------------------------------------------------------------
# 套件管理
# --------------------------------------------------------------------------
.PHONY: update
update: ## [Docker] 更新容器內所有套件
	docker compose -f $(COMPOSE_FILE) exec arch sudo pacman -Syu --noconfirm

.PHONY: install
install: ## [Docker] 安裝套件，例如：make install PKG="neovim tmux"
	@if [ -z "$(PKG)" ]; then echo "$(YELLOW)用法：make install PKG=\"<套件名>\"$(RESET)"; exit 1; fi
	docker compose -f $(COMPOSE_FILE) exec arch sudo pacman -S --noconfirm $(PKG)

# --------------------------------------------------------------------------
# 日誌與狀態
# --------------------------------------------------------------------------
.PHONY: logs
logs: ## [Docker] 查看容器輸出
	docker compose -f $(COMPOSE_FILE) logs -f arch

.PHONY: status
status: ## [Docker] 查看容器與映像狀態
	@echo "$(BOLD)容器狀態$(RESET)"
	@docker compose -f $(COMPOSE_FILE) ps 2>/dev/null || echo "  (尚未啟動)"
	@echo ""
	@echo "$(BOLD)映像資訊$(RESET)"
	@docker images $(IMAGE_NAME) 2>/dev/null || echo "  (映像尚未建構)"

.PHONY: inspect
inspect: ## [Docker] 查看容器詳細資訊
	@docker inspect $(CONTAINER_NAME) 2>/dev/null | \
	  python3 -c "import sys,json; d=json.load(sys.stdin)[0]; \
	    print('State:', d['State']['Status']); \
	    [print('Mount:', m['Source'], '->', m['Destination']) for m in d['Mounts']]" || \
	  echo "容器未運行，請先執行 make up"

# --------------------------------------------------------------------------
# 清理
# --------------------------------------------------------------------------
.PHONY: clean
clean: down ## [Docker] 移除容器（保留 volume）
	@echo "$(BOLD)[clean]$(RESET) 容器已移除"

.PHONY: clean-all
clean-all: ## [Docker] 移除容器、映像與所有 volume（完全清除）
	@echo "$(YELLOW)[clean-all]$(RESET) 移除所有相關資源..."
	docker compose -f $(COMPOSE_FILE) down -v --rmi all 2>/dev/null || true

.PHONY: prune
prune: ## [Docker] 清理 Docker 系統快取
	docker system prune -f
	docker volume prune -f

# --------------------------------------------------------------------------
# 環境檢查
# --------------------------------------------------------------------------
.PHONY: check-docker
check-docker: ## [Docker] 確認 Docker Desktop 已啟動並支援 ARM64
	@echo "$(BOLD)Docker 環境檢查$(RESET)"
	@docker version --format '  Engine: {{.Server.Version}}' 2>/dev/null || \
	  (echo "$(YELLOW)  Docker Desktop 未啟動$(RESET)"; exit 1)
	@docker buildx ls | grep -q "linux/arm64" && \
	  echo "  ARM64：$(GREEN)支援$(RESET)" || \
	  echo "  ARM64：$(YELLOW)未偵測，請確認為 Apple Silicon 版本$(RESET)"
	@echo "  Platform：$$(docker version --format '{{.Server.Os}}/{{.Server.Arch}}')"

.PHONY: arch-info
arch-info: ## [Docker] 顯示容器內系統資訊
	@docker compose -f $(COMPOSE_FILE) exec arch bash -c \
	  "echo '架構：' && uname -m && \
	   echo 'OS  ：' && grep PRETTY /etc/os-release | cut -d= -f2 && \
	   echo 'Kernel：' && uname -r && \
	   echo '記憶體：' && free -h | awk '/^Mem/{print \$$2 \" total / \" \$$7 \" avail\"}' && \
	   echo '磁碟  ：' && df -h / | awk 'NR==2{print \$$3 \" used / \" \$$2 \" total\"}'"


# --------------------------------------------------------------------------
# 說明
# --------------------------------------------------------------------------
.PHONY: help
help: ## 顯示所有可用指令
	@echo "$(BOLD)Arch Linux ARM — Docker 環境$(RESET)"
	@echo "$(CYAN)適用：Mac M1 (ARM64) + Docker Desktop$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# --------------------------------------------------------------------------
# 映像建構
# --------------------------------------------------------------------------
.PHONY: build
build: ## 建構 ARM64 Arch Linux Docker 映像
	@echo "$(BOLD)[build]$(RESET) 建構映像 $(IMAGE_NAME)..."
	docker compose -f $(COMPOSE_FILE) build --no-cache

.PHONY: build-fast
build-fast: ## 快速重建（使用 cache）
	@echo "$(BOLD)[build-fast]$(RESET) 快速重建..."
	docker compose -f $(COMPOSE_FILE) build

# --------------------------------------------------------------------------
# 容器生命週期
# --------------------------------------------------------------------------
.PHONY: up
up: ## 背景啟動 Arch 容器
	@echo "$(BOLD)[up]$(RESET) 啟動容器..."
	docker compose -f $(COMPOSE_FILE) up -d

.PHONY: down
down: ## 停止並移除容器（保留 volume）
	@echo "$(BOLD)[down]$(RESET) 停止容器..."
	docker compose -f $(COMPOSE_FILE) down

.PHONY: restart
restart: down up ## 重新啟動容器

.PHONY: stop
stop: ## 停止容器（不移除）
	docker compose -f $(COMPOSE_FILE) stop

# --------------------------------------------------------------------------
# 互動操作
# --------------------------------------------------------------------------
.PHONY: shell
shell: ## 進入互動式 Arch Linux shell（自動啟動容器）
	@docker compose -f $(COMPOSE_FILE) up -d --quiet-pull 2>/dev/null || true
	@echo "$(BOLD)[shell]$(RESET) 進入 Arch Linux 環境... (輸入 exit 離開)"
	docker compose -f $(COMPOSE_FILE) exec arch zsh || \
	docker compose -f $(COMPOSE_FILE) exec arch bash

.PHONY: root
root: ## 以 root 身份進入容器
	@docker compose -f $(COMPOSE_FILE) up -d --quiet-pull 2>/dev/null || true
	docker compose -f $(COMPOSE_FILE) exec -u root arch zsh || \
	docker compose -f $(COMPOSE_FILE) exec -u root arch bash

.PHONY: exec
exec: ## 在容器內執行單一指令，例如：make exec CMD="pacman -Syu"
	@if [ -z "$(CMD)" ]; then echo "$(YELLOW)用法：make exec CMD=\"<指令>\"$(RESET)"; exit 1; fi
	docker compose -f $(COMPOSE_FILE) exec arch bash -c "$(CMD)"

# --------------------------------------------------------------------------
# 套件管理
# --------------------------------------------------------------------------
.PHONY: update
update: ## 更新容器內所有套件
	docker compose -f $(COMPOSE_FILE) exec arch pacman -Syu --noconfirm

.PHONY: install
install: ## 安裝套件，例如：make install PKG="neovim tmux"
	@if [ -z "$(PKG)" ]; then echo "$(YELLOW)用法：make install PKG=\"<套件名>\"$(RESET)"; exit 1; fi
	docker compose -f $(COMPOSE_FILE) exec arch pacman -S --noconfirm $(PKG)

# --------------------------------------------------------------------------
# 日誌與狀態
# --------------------------------------------------------------------------
.PHONY: logs
logs: ## 查看容器輸出
	docker compose -f $(COMPOSE_FILE) logs -f arch

.PHONY: status
status: ## 查看容器狀態
	@echo "$(BOLD)容器狀態$(RESET)"
	docker compose -f $(COMPOSE_FILE) ps
	@echo ""
	@echo "$(BOLD)映像資訊$(RESET)"
	@docker images $(IMAGE_NAME) 2>/dev/null || echo "  (映像尚未建構)"

.PHONY: inspect
inspect: ## 查看容器詳細資訊
	docker inspect $(CONTAINER_NAME) 2>/dev/null | jq '.[0].State, .[0].Mounts' || \
	  echo "容器未運行，請先執行 make up"

# --------------------------------------------------------------------------
# 清理
# --------------------------------------------------------------------------
.PHONY: clean
clean: down ## 移除容器（保留 volume）
	@echo "$(BOLD)[clean]$(RESET) 移除容器..."

.PHONY: clean-all
clean-all: ## 移除容器、映像與 volume（完全清除）
	@echo "$(YELLOW)[clean-all]$(RESET) 移除所有相關資源..."
	docker compose -f $(COMPOSE_FILE) down -v --rmi all 2>/dev/null || true
	docker volume prune -f 2>/dev/null || true

.PHONY: prune
prune: ## 清理 Docker 系統（移除未使用的映像/容器/volume）
	docker system prune -f
	docker volume prune -f

# --------------------------------------------------------------------------
# 工具
# --------------------------------------------------------------------------
.PHONY: check-docker
check-docker: ## 確認 Docker Desktop 已啟動並支援 ARM64
	@echo "$(BOLD)Docker 環境檢查$(RESET)"
	@docker version --format '  Docker Engine: {{.Server.Version}}' 2>/dev/null || \
	  (echo "$(YELLOW)  Docker Desktop 未啟動，請先開啟 Docker Desktop$(RESET)"; exit 1)
	@docker buildx ls | grep -q "linux/arm64" && \
	  echo "  ARM64 支援：$(GREEN)✓$(RESET)" || \
	  echo "  ARM64 支援：$(YELLOW)未偵測到，請確認 Docker Desktop 為 Apple Silicon 版本$(RESET)"

.PHONY: arch-info
arch-info: ## 顯示容器內的系統資訊
	@docker compose -f $(COMPOSE_FILE) exec arch bash -c \
	  "echo '=== 架構 ===' && uname -m && \
	   echo '=== OS ===' && cat /etc/os-release | grep PRETTY && \
	   echo '=== Kernel ===' && uname -r && \
	   echo '=== 記憶體 ===' && free -h && \
	   echo '=== 磁碟 ===' && df -h /"
