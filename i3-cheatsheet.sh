#!/bin/bash

# ==========================================
# i3wm Ultimate Cheat Sheet (Terminal Version)
# ==========================================

# GUIショートカットなど非対話端末から呼ばれた場合の判定
HOLD_NEEDED=0
if [ "$1" = "--hold" ] || [ ! -t 1 ]; then
    HOLD_NEEDED=1
fi

# 端末以外(GUIキーバインドなど)から呼ばれた場合はターミナルを開き、待機モード(--hold)で再実行
if [ ! -t 1 ] && [ -n "$DISPLAY" ] && [ "$1" != "--hold" ]; then
    if command -v i3-sensible-terminal &> /dev/null; then
        exec i3-sensible-terminal -e "$0" --hold
    elif command -v x-terminal-emulator &> /dev/null; then
        exec x-terminal-emulator -e "$0" --hold
    fi
fi

BOLD="\033[1m"
RESET="\033[0m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
BLUE="\033[1;34m"
WHITE="\033[1;37m"
GRAY="\033[0;90m"

render_cheatsheet() {
    echo -e "${MAGENTA}${BOLD}====================================================${RESET}"
    echo -e "${MAGENTA}${BOLD}         🚀 i3wm Ultimate Keybindings Guide         ${RESET}"
    echo -e "${MAGENTA}${BOLD}====================================================${RESET}"
    echo -e "${GRAY}💡 基本プレフィックス: ${CYAN}${BOLD}Super (Windows キー)${RESET}\n"

    echo -e "${CYAN}${BOLD}🚀 基本操作 (Basics)${RESET}"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Enter" "ターミナル起動"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + d" "アプリランチャー (Rofi)"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Shift + q" "フォーカス中のウィンドウを閉じる"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Shift + c" "i3設定ファイルの再読み込み"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Shift + r" "i3wm の再起動 (Restart)"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Shift + u" "GitHubから最新設定へアップデート"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Ctrl + k" "キーボード設定 (Ctrl/Caps入替・配列)"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Shift + ?" "このチートシートを表示"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Shift + e" "i3wm 終了メニュー"
    echo ""

    echo -e "${GREEN}${BOLD}🪟 フォーカス & ウィンドウ移動 (Focus & Move)${RESET}"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + h / j / k / l" "左 / 下 / 上 / 右 へフォーカス移動 (Vim)"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + 矢印キー" "左 / 下 / 上 / 右 へフォーカス移動"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Shift + h/j/k/l" "ウィンドウを左/下/上/右へ移動"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Shift + 矢印キー" "ウィンドウを左/下/上/右へ移動"
    echo ""

    echo -e "${YELLOW}${BOLD}📐 レイアウト操作 (Layouts)${RESET}"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + b" "次の分割方向を「水平」に指定"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + v" "次の分割方向を「垂直」に指定"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + f" "フルスクリーン表示の切り替え"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + s" "スタックレイアウト (縦並び)"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + w" "タブレイアウト (横並び)"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + e" "タイリング分割モードの切り替え"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Shift + Space" "フローティング(浮きウィンドウ)切り替え"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Space" "タイル ↔ フローティング間のフォーカス移動"
    echo ""

    echo -e "${BLUE}${BOLD}🖥️ ワークスペース操作 (Workspaces)${RESET}"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + 1 ... 0" "ワークスペース 1 〜 10 へ移動"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Super + Shift + 1 ... 0" "ウィンドウをワークスペース 1 〜 10 へ移動"
    echo ""

    echo -e "${MAGENTA}${BOLD}🔊 システム / メディアキー (System)${RESET}"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Volume Up / Down" "音量調整 (+5% / -5%)"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Mute" "消音 (ミュート) 切り替え"
    printf "  ${YELLOW}%-28s${RESET} : ${WHITE}%s${RESET}\n" "Brightness Up / Down" "画面輝度調整 (+5% / -5%)"
    echo -e "${MAGENTA}${BOLD}====================================================${RESET}"
}

# 表示出力およびウィンドウ保持処理
if [ "$HOLD_NEEDED" = "1" ]; then
    if command -v less &> /dev/null; then
        render_cheatsheet | less -R
    else
        render_cheatsheet
        echo -e "\n${GRAY}💡 画面を閉じるには [Enter] キーを押してください...${RESET}"
        read -r
    fi
else
    render_cheatsheet
fi
