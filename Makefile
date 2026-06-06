# =============================================================================
# Makefile — Arch Linux ARM Docker 環境快捷指令
# 適用：Mac M1 (ARM64) + Docker Desktop (Apple Silicon)
# =============================================================================

.DEFAULT_GOAL := help
SHELL         := /bin/zsh

# 專案設定
IMAGE_NAME    := fast-arch
CONTAINER_NAME := arch-dev
COMPOSE_FILE  := docker/docker-compose.yml

# 顏色
BOLD   := \033[1m
RESET  := \033[0m
GREEN  := \033[1;32m
CYAN   := \033[1;36m
YELLOW := \033[1;33m

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
