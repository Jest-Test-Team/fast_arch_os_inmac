# =============================================================================
# Dockerfile — Arch Linux ARM (aarch64) for Mac M1
# 基礎映像：archlinux/archlinux:base-devel（官方，支援 linux/arm64）
#
# 建構方式：
#   docker buildx build --platform linux/arm64 -t fast-arch .
#   (或透過 docker-compose.yml / Makefile)
# =============================================================================

FROM archlinux/archlinux:base-devel

# 宣告建構時可覆寫的變數
ARG USERNAME=arch
ARG USER_UID=1000
ARG USER_GID=1000
ARG TZ=Asia/Taipei

# 設定環境變數
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=${TZ} \
    TERM=xterm-256color \
    EDITOR=vim

# =============================================================================
# 1. 初始化 pacman keyring
#    (archlinux 容器映像需要在首次使用前初始化 keyring)
# =============================================================================
RUN pacman-key --init && \
    pacman-key --populate archlinux

# =============================================================================
# 2. 更新系統並安裝基礎套件
# =============================================================================
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed \
        # Shell 與終端工具
        zsh \
        zsh-completions \
        zsh-syntax-highlighting \
        zsh-autosuggestions \
        # 文字編輯
        vim \
        neovim \
        # 版本控制
        git \
        # 網路工具
        curl \
        wget \
        openssh \
        # 開發工具
        make \
        cmake \
        gcc \
        python \
        python-pip \
        go \
        nodejs \
        npm \
        # 系統工具
        htop \
        tree \
        ripgrep \
        fd \
        jq \
        unzip \
        man-db \
        man-pages \
        # locale 生成
        glibc \
    && pacman -Sc --noconfirm

# =============================================================================
# 3. 設定 locale 與時區
# =============================================================================
RUN sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && \
    sed -i 's/^#zh_TW.UTF-8/zh_TW.UTF-8/' /etc/locale.gen && \
    locale-gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime

# =============================================================================
# 4. 建立非 root 使用者，加入 wheel 群組
# =============================================================================
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd \
        --uid ${USER_UID} \
        --gid ${USER_GID} \
        --groups wheel,audio,video \
        --create-home \
        --shell /bin/zsh \
        ${USERNAME} && \
    # 允許 wheel 群組使用 sudo（容器內開發用）
    echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers.d/wheel && \
    chmod 440 /etc/sudoers.d/wheel

# =============================================================================
# 5. 安裝 yay (AUR helper)，以一般使用者身份建構
# =============================================================================
RUN pacman -S --noconfirm --needed git base-devel && \
    # 切換到使用者目錄執行 makepkg（yay 不允許 root 建構）
    su - ${USERNAME} -c " \
        git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && \
        cd /tmp/yay-bin && \
        makepkg -si --noconfirm \
    " && \
    rm -rf /tmp/yay-bin

# =============================================================================
# 6. 設定 zsh（使用者與 root）
# =============================================================================
# 使用者的 zsh 設定
COPY --chown=${USERNAME}:${USERNAME} scripts/zshrc-template /home/${USERNAME}/.zshrc

# root 的 zsh 設定（相同骨架）
RUN cp /home/${USERNAME}/.zshrc /root/.zshrc

# =============================================================================
# 7. 複製啟動腳本
# =============================================================================
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# =============================================================================
# 8. 設定工作目錄與使用者
# =============================================================================
WORKDIR /workspace

# 預設以一般使用者身份執行
USER ${USERNAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
