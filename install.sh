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

echo "🚀 Starting i3wm Ultimate Setup..."

# ==========================================
# 1. パッケージマネージャーの判別とインストール
# ==========================================
if command -v apt &> /dev/null; then
    echo "📦 Detected Debian/Ubuntu (apt). Installing packages..."
    sudo apt update
    sudo apt install -y i3 rofi picom feh brightnessctl pavucontrol pulseaudio-utils curl x11-xserver-utils libnotify-bin
elif command -v pacman &> /dev/null; then
    echo "📦 Detected Arch Linux (pacman). Installing packages..."
    sudo pacman -Syu --noconfirm i3-wm rofi picom feh brightnessctl pavucontrol pulseaudio curl xorg-setxkbmap libnotify
elif command -v dnf &> /dev/null; then
    echo "📦 Detected Fedora/RHEL (dnf). Installing packages..."
    sudo dnf install -y i3 rofi picom feh brightnessctl pavucontrol pulseaudio-utils curl setxkbmap libnotify
else
    echo "⚠️ Unsupported package manager. Please install dependencies manually."
fi

# ==========================================
# 2. i3 ディレクトリの準備とバックアップ
# ==========================================
I3_DIR="$HOME/.config/i3"
mkdir -p "$I3_DIR"

if [ -f "$I3_DIR/config" ]; then
    BACKUP_NAME="config.backup.$(date +%Y%m%d_%H%M%S)"
    echo "💾 Backing up existing i3 config to ${BACKUP_NAME}..."
    mv "$I3_DIR/config" "$I3_DIR/${BACKUP_NAME}"
fi

# ==========================================
# 3. GitHubから最新の設定ファイルをダウンロード
# ==========================================
echo "⬇️ Downloading ultimate i3 config from GitHub..."
curl -fsSL "${RAW_URL}/config" -o "$I3_DIR/config"

echo "⬇️ Downloading i3 cheat sheet..."
curl -fsSL "${RAW_URL}/i3-cheatsheet.html" -o "$I3_DIR/i3-cheatsheet.html"

echo "⬇️ Downloading update script..."
curl -fsSL "${RAW_URL}/update.sh" -o "$I3_DIR/update.sh"
chmod +x "$I3_DIR/update.sh"

echo "⬇️ Downloading keyboard setup script..."
curl -fsSL "${RAW_URL}/i3-keyboard-setup.sh" -o "$I3_DIR/i3-keyboard-setup.sh"
chmod +x "$I3_DIR/i3-keyboard-setup.sh"

# コマンドとしてどこからでも呼び出せるように ~/.local/bin にシンボリックリンクを作成
LOCAL_BIN="$HOME/.local/bin"
if [ -d "$LOCAL_BIN" ] || mkdir -p "$LOCAL_BIN" 2>/dev/null; then
    ln -sf "$I3_DIR/update.sh" "$LOCAL_BIN/i3-config-update" 2>/dev/null || true
    ln -sf "$I3_DIR/i3-keyboard-setup.sh" "$LOCAL_BIN/i3-keyboard-setup" 2>/dev/null || true
fi

# ==========================================
# 4. 完了処理
# ==========================================
echo "✅ Setup Complete!"
echo "💡 今後、設定を最新にアップデートしたい場合は以下の方法が使えます:"
echo "   ・ショートカット: Super + Shift + u"
echo "   ・コマンド: i3-config-update または ~/.config/i3/update.sh"
echo "   ・ワンライナー: curl -fsSL ${RAW_URL}/update.sh | bash"

# i3が既に起動している場合は、設定を再読み込みする
if command -v i3-msg &> /dev/null && pgrep -x i3 > /dev/null; then
    echo "🔄 Reloading i3 to apply changes..."
    i3-msg reload
else
    echo "🎉 Please log out and log back in, selecting i3 as your window manager."
fi