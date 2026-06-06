# =============================================================================
# Dockerfile — Arch Linux ARM (aarch64) for Mac M1
# 基礎映像：archlinux/archlinux:base-devel（官方，支援 linux/arm64）
#
# 建構方式：
#   cd docker/
#   docker compose build        (透過 Makefile: make build)
#   docker compose up -d        (透過 Makefile: make up)
#   docker compose exec arch zsh (透過 Makefile: make shell)
# =============================================================================

FROM archlinux/archlinux:base-devel

ARG USERNAME=arch
ARG USER_UID=1000
ARG USER_GID=1000
ARG TZ=Asia/Taipei

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=${TZ} \
    TERM=xterm-256color \
    EDITOR=vim

# =============================================================================
# 1. 初始化 pacman keyring
# =============================================================================
RUN pacman-key --init && \
    pacman-key --populate archlinux

# =============================================================================
# 2. 更新系統
# =============================================================================
RUN pacman -Syu --noconfirm

# =============================================================================
# 3. 安裝基礎套件
#    注意：不可在 pacman -S 的多行參數中插入 # 行內註解，
#          shell 會將 # 後的內容（含續行 \）視為整行註解，
#          導致後續套件全部被忽略。
# =============================================================================
RUN pacman -S --noconfirm --needed \
        zsh zsh-completions zsh-syntax-highlighting zsh-autosuggestions \
        vim neovim \
        git \
        curl wget openssh \
        make cmake gcc \
        python python-pip \
        go \
        nodejs npm \
        htop tree ripgrep fd jq unzip \
        man-db man-pages \
        glibc \
    && pacman -Sc --noconfirm

# =============================================================================
# 4. 設定 locale 與時區
# =============================================================================
RUN sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && \
    sed -i 's/^#zh_TW.UTF-8/zh_TW.UTF-8/' /etc/locale.gen && \
    locale-gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime

# =============================================================================
# 5. 建立非 root 使用者，加入 wheel 群組
# =============================================================================
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd \
        --uid ${USER_UID} \
        --gid ${USER_GID} \
        --groups wheel,audio,video \
        --create-home \
        --shell /bin/zsh \
        ${USERNAME} && \
    echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel && \
    chmod 440 /etc/sudoers.d/wheel

# =============================================================================
# 6. 安裝 yay (AUR helper)，以一般使用者身份建構
#    makepkg 不允許 root 執行，需切換至 ${USERNAME}
# =============================================================================
RUN su - ${USERNAME} -c \
        "git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && \
         cd /tmp/yay-bin && \
         makepkg -si --noconfirm" && \
    rm -rf /tmp/yay-bin

# =============================================================================
# 7. 設定 zsh
# =============================================================================
COPY --chown=${USERNAME}:${USERNAME} scripts/zshrc-template /home/${USERNAME}/.zshrc
RUN cp /home/${USERNAME}/.zshrc /root/.zshrc

# =============================================================================
# 8. 複製啟動腳本
# =============================================================================
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/bootstrap.sh  /usr/local/bin/bootstrap.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/bootstrap.sh

# =============================================================================
# 9. 工作目錄與使用者
# =============================================================================
WORKDIR /workspace

USER ${USERNAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
