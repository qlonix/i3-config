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
ARCHIVE_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}/archive/refs/heads/${BRANCH}.tar.gz"
I3_DIR="$HOME/.config/i3"

echo "🔄 Updating i3wm configuration..."

# 実行元のディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

# ==========================================
# 1. セルフアップデート機構
# 古い update.sh が実行された場合でも、まず自身をGitHubから最新化して再実行します
# ==========================================
if [ "$UPDATER_REEXEC" != "1" ]; then
    export UPDATER_REEXEC=1
    
    if [ -d "$SCRIPT_DIR/.git" ]; then
        echo "📦 Git repository detected at ${SCRIPT_DIR}. Pulling latest changes..."
        git -C "$SCRIPT_DIR" pull origin "$BRANCH"
        exec bash "$SCRIPT_DIR/update.sh" "$@"
    elif [ -d "$I3_DIR/.git" ]; then
        echo "📦 Git repository detected at ${I3_DIR}. Pulling latest changes..."
        git -C "$I3_DIR" pull origin "$BRANCH"
        exec bash "$I3_DIR/update.sh" "$@"
    else
        echo "⬇️ Self-updating update.sh from GitHub..."
        mkdir -p "$I3_DIR"
        TEMP_UPDATER=$(mktemp)
        if curl -fsSL "${RAW_URL}/update.sh" -o "$TEMP_UPDATER"; then
            chmod +x "$TEMP_UPDATER"
            cp "$TEMP_UPDATER" "$I3_DIR/update.sh"
            rm -f "$TEMP_UPDATER"
            echo "🚀 Re-executing updated updater script..."
            exec bash "$I3_DIR/update.sh" "$@"
        fi
    fi
fi

# ==========================================
# 2. リポジトリ全体のアーカイブ同期
# 個別ファイル名指定ではなく、GitHubの全ファイルアーカイブ(tar.gz)を展開して完全同期します
# ==========================================
if [ ! -d "$SCRIPT_DIR/.git" ] && [ ! -d "$I3_DIR/.git" ]; then
    echo "📦 Downloading latest repository archive from GitHub..."
    mkdir -p "$I3_DIR"
    
    if [ -f "$I3_DIR/config" ]; then
        BACKUP_NAME="config.backup.$(date +%Y%m%d_%H%M%S)"
        echo "💾 Backing up current i3 config to ${BACKUP_NAME}..."
        cp "$I3_DIR/config" "$I3_DIR/${BACKUP_NAME}"
    fi

    TEMP_TAR=$(mktemp 2>/dev/null || echo "/tmp/i3_archive.tar.gz")
    curl -fsSL "$ARCHIVE_URL" -o "$TEMP_TAR"
    tar -xzf "$TEMP_TAR" --strip-components=1 -C "$I3_DIR"
    rm -f "$TEMP_TAR"
elif [ -d "$SCRIPT_DIR/.git" ] && [ "$SCRIPT_DIR" != "$I3_DIR" ]; then
    mkdir -p "$I3_DIR"
    cp -r "$SCRIPT_DIR"/* "$I3_DIR"/ 2>/dev/null || true
fi

# ==========================================
# 3. 権限設定およびコマンド（シンボリックリンク）登録
# ==========================================
chmod +x "$I3_DIR"/*.sh 2>/dev/null || true

LOCAL_BIN="$HOME/.local/bin"
if [ -d "$LOCAL_BIN" ] || mkdir -p "$LOCAL_BIN" 2>/dev/null; then
    ln -sf "$I3_DIR/update.sh" "$LOCAL_BIN/i3-config-update" 2>/dev/null || true
    ln -sf "$I3_DIR/i3-keyboard-setup.sh" "$LOCAL_BIN/i3-keyboard-setup" 2>/dev/null || true
    ln -sf "$I3_DIR/i3-cheatsheet.sh" "$LOCAL_BIN/i3-cheatsheet" 2>/dev/null || true
fi

echo "✅ Update Complete!"

# ==========================================
# 4. i3 の再起動 (新しい設定とスクリプトを適用)
# ==========================================
if command -v i3-msg &> /dev/null && pgrep -x i3 > /dev/null; then
    echo "🔄 Restarting i3 to apply changes..."
    i3-msg restart
fi
