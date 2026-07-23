#!/bin/bash

# エラーが発生したらスクリプトを停止する
set -e

# ==========================================
# ユーザー設定 (ここをご自身のGitHubに合わせて変更してください)
# ==========================================
GITHUB_USER="qlonix"
REPO_NAME="i3-config"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"
I3_DIR="$HOME/.config/i3"

echo "🔄 Updating i3wm configuration..."

# 実行元のディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

# Gitリポジトリ内で実行された場合、または ~/.config/i3 が Git リポジトリの場合
if [ -d "$SCRIPT_DIR/.git" ]; then
    echo "📦 Detected Git repository at ${SCRIPT_DIR}. Pulling latest changes..."
    cd "$SCRIPT_DIR"
    git pull origin "$BRANCH"
    
    if [ "$SCRIPT_DIR" != "$I3_DIR" ]; then
        mkdir -p "$I3_DIR"
        cp "$SCRIPT_DIR/config" "$I3_DIR/config"
        cp "$SCRIPT_DIR/i3-cheatsheet.html" "$I3_DIR/i3-cheatsheet.html"
        cp "$SCRIPT_DIR/update.sh" "$I3_DIR/update.sh"
        cp "$SCRIPT_DIR/i3-keyboard-setup.sh" "$I3_DIR/i3-keyboard-setup.sh"
        chmod +x "$I3_DIR/update.sh" "$I3_DIR/i3-keyboard-setup.sh"
    fi
elif [ -d "$I3_DIR/.git" ]; then
    echo "📦 Detected Git repository at ${I3_DIR}. Pulling latest changes..."
    cd "$I3_DIR"
    git pull origin "$BRANCH"
else
    echo "⬇️ Downloading latest config files from GitHub..."
    mkdir -p "$I3_DIR"
    
    if [ -f "$I3_DIR/config" ]; then
        BACKUP_NAME="config.backup.$(date +%Y%m%d_%H%M%S)"
        echo "💾 Backing up current i3 config to ${BACKUP_NAME}..."
        cp "$I3_DIR/config" "$I3_DIR/${BACKUP_NAME}"
    fi

    curl -fsSL "${RAW_URL}/config" -o "$I3_DIR/config"
    curl -fsSL "${RAW_URL}/i3-cheatsheet.html" -o "$I3_DIR/i3-cheatsheet.html"
    curl -fsSL "${RAW_URL}/update.sh" -o "$I3_DIR/update.sh"
    curl -fsSL "${RAW_URL}/i3-keyboard-setup.sh" -o "$I3_DIR/i3-keyboard-setup.sh"
    chmod +x "$I3_DIR/update.sh" "$I3_DIR/i3-keyboard-setup.sh"
fi

# コマンドとしてどこからでも呼び出せるように ~/.local/bin にシンボリックリンクを作成
LOCAL_BIN="$HOME/.local/bin"
if [ -d "$LOCAL_BIN" ] || mkdir -p "$LOCAL_BIN" 2>/dev/null; then
    ln -sf "$I3_DIR/update.sh" "$LOCAL_BIN/i3-config-update" 2>/dev/null || true
    ln -sf "$I3_DIR/i3-keyboard-setup.sh" "$LOCAL_BIN/i3-keyboard-setup" 2>/dev/null || true
fi

echo "✅ Update Complete!"

# i3が既に起動している場合は、設定を再読み込みする
if command -v i3-msg &> /dev/null && pgrep -x i3 > /dev/null; then
    echo "🔄 Reloading i3 to apply changes..."
    i3-msg reload
fi
