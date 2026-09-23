#!/bin/bash

# ==========================================
# i3wm 自動起動アプリケーション設定ツール (ncurses / dialog)
# ログイン時 (i3起動時) に自動起動するシステムデーモンや
# アプリケーションを視覚的なチェックボックスで選択・管理します
# ==========================================

CONF_DIR="$HOME/.config/i3"
AUTOSTART_CONF="$CONF_DIR/autostart.conf"

# プリセット定義:
# 形式: "ID|表示名|実行コマンド|存在判定バイナリ|デフォルトON/OFF"
PRESETS=(
    "picom|picom (コンポジタ: ウィンドウ透明化・影・チラつき防止)|picom -b|picom|off"
    "nm-applet|nm-applet (ネットワーク管理・Wi-Fi接続トレイアイコン)|nm-applet|nm-applet|on"
    "xfce4-power-manager|xfce4-power-manager (電源管理: バッテリー・スリープ)|xfce4-power-manager|xfce4-power-manager|on"
    "xsettingsd|xsettingsd (GTKテーマ・フォント設定同期デーモン)|xsettingsd|xsettingsd|on"
    "dunst|dunst (デスクトップ通知・OSDデーモン)|dunst|dunst|on"
    "ulauncher|Ulauncher (高機能アプリケーションランチャー)|ulauncher --hide-window|ulauncher|off"
    "flameshot|Flameshot (高機能スクリーンショット常駐)|flameshot|flameshot|off"
    "fcitx5|Fcitx5 (日本語入力システム IME)|fcitx5 -d|fcitx5|on"
    "fcitx|Fcitx (日本語入力システム IME)|fcitx -d|fcitx|off"
    "ibus|IBus (日本語入力システム IME)|ibus-daemon -drx|ibus-daemon|off"
    "blueman-applet|blueman-applet (Bluetooth接続管理トレイアイコン)|blueman-applet|blueman-applet|on"
    "redshift-gtk|Redshift (夜間ブルーライト軽減・色温度調整)|redshift-gtk|redshift-gtk|off"
    "caffeine|Caffeine (動画視聴・作業中の画面スリープ抑止)|caffeine|caffeine|off"
    "pasystray|pasystray (PulseAudio 音量コントロールトレイアイコン)|pasystray|pasystray|off"
    "volumeicon|volumeicon (軽量音量トレイアイコン)|volumeicon|volumeicon|off"
    "firefox|Firefox (Webブラウザ)|firefox|firefox|off"
    "google-chrome|Google Chrome (Webブラウザ)|google-chrome|google-chrome|off"
    "chromium|Chromium (Webブラウザ)|chromium|chromium|off"
    "brave|Brave Browser (Webブラウザ)|brave-browser|brave-browser|off"
    "thunderbird|Thunderbird (メールクライアント)|thunderbird|thunderbird|off"
    "discord|Discord (チャット・通話)|discord|discord|off"
    "slack|Slack (ビジネスチャット)|slack|slack|off"
    "telegram|Telegram Desktop (メッセンジャー)|telegram-desktop|telegram-desktop|off"
    "spotify|Spotify (音楽ストリーミング)|spotify|spotify|off"
    "code|Visual Studio Code (コードエディタ)|code|code|off"
)

# デフォルト設定ファイルの生成
init_default_config() {
    mkdir -p "$CONF_DIR"
    local enabled=()
    for item in "${PRESETS[@]}"; do
        IFS="|" read -r id name cmd bin def <<< "$item"
        # バイナリが存在し、デフォルトが on の場合
        if command -v "$bin" &>/dev/null && [ "$def" = "on" ]; then
            enabled+=("$cmd")
        fi
    done

    # 必須基本デーモン (存在すれば確実に追加)
    for basic in "nm-applet" "xsettingsd" "dunst"; do
        if command -v "$basic" &>/dev/null; then
            local found=0
            for e in "${enabled[@]}"; do
                [ "$e" = "$basic" ] && found=1 && break
            done
            [ $found -eq 0 ] && enabled+=("$basic")
        fi
    done

    cat <<EOF > "$AUTOSTART_CONF"
# ==========================================
# i3wm Autostart Applications Configuration
# このファイルは i3-autostart.sh により自動管理されます
# ==========================================

AUTOSTART_ENABLED=(
$(for e in "${enabled[@]}"; do echo "    \"$e\""; done)
)

CUSTOM_AUTOSTART=(
)
EOF
}

# 設定の読み込み
load_config() {
    if [ ! -f "$AUTOSTART_CONF" ]; then
        init_default_config
    fi
    AUTOSTART_ENABLED=()
    CUSTOM_AUTOSTART=()
    # shellcheck source=/dev/null
    . "$AUTOSTART_CONF" 2>/dev/null || true
}

# 設定の保存
save_config() {
    mkdir -p "$CONF_DIR"
    cat <<EOF > "$AUTOSTART_CONF"
# ==========================================
# i3wm Autostart Applications Configuration
# このファイルは i3-autostart.sh により自動管理されます
# ==========================================

AUTOSTART_ENABLED=(
$(for e in "${AUTOSTART_ENABLED[@]}"; do echo "    \"$e\""; done)
)

CUSTOM_AUTOSTART=(
$(for e in "${CUSTOM_AUTOSTART[@]}"; do echo "    \"$e\""; done)
)
EOF
}

# ==========================================
# apply モード: i3起動時・ログイン時に各アプリを安全に起動
# ==========================================
apply_autostart() {
    load_config

    # 1. プリセットアプリの起動 (二重起動防止チェック付き)
    for cmd in "${AUTOSTART_ENABLED[@]}"; do
        [ -z "$cmd" ] && continue
        local bin
        bin=$(echo "$cmd" | awk '{print $1}')
        if command -v "$bin" &>/dev/null; then
            if ! pgrep -x "$bin" >/dev/null 2>&1 && ! pgrep -f "$cmd" >/dev/null 2>&1; then
                eval "$cmd" >/dev/null 2>&1 &
            fi
        fi
    done

    # 2. カスタムコマンドの起動
    for cmd in "${CUSTOM_AUTOSTART[@]}"; do
        [ -z "$cmd" ] && continue
        local bin
        bin=$(echo "$cmd" | awk '{print $1}')
        if command -v "$bin" &>/dev/null || [ -x "$bin" ]; then
            if ! pgrep -f "$cmd" >/dev/null 2>&1; then
                eval "$cmd" >/dev/null 2>&1 &
            fi
        fi
    done
}

if [ "$1" = "apply" ]; then
    apply_autostart
    exit 0
fi

# ==========================================
# ncurses (dialog) UI 実装
# ==========================================

is_enabled() {
    local target_cmd="$1"
    for e in "${AUTOSTART_ENABLED[@]}"; do
        if [ "$e" = "$target_cmd" ]; then
            return 0
        fi
    done
    return 1
}

# 自動起動アプリ選択チェックリスト
menu_select_apps() {
    load_config

    local items=()
    local available_count=0

    for item in "${PRESETS[@]}"; do
        IFS="|" read -r id name cmd bin def <<< "$item"
        # システムにインストールされているもののみ表示
        if command -v "$bin" &>/dev/null; then
            available_count=$((available_count + 1))
            local status="off"
            if is_enabled "$cmd"; then
                status="on"
            fi
            items+=("$id" "$name" "$status")
        fi
    done

    if [ $available_count -eq 0 ]; then
        dialog --title "情報" --msgbox "利用可能なプリセットアプリケーションが見つかりませんでした。" 7 50
        return
    fi

    local selected_ids
    selected_ids=$(dialog --clear \
        --backtitle "i3wm Autostart Applications Manager" \
        --title "🚀 自動起動アプリケーションの選択" \
        --separate-output \
        --checklist "スペースキーで [X] 有効 / [ ] 無効 を切り替えてください。\nEnter キーで決定して保存します:" \
        22 75 14 \
        "${items[@]}" \
        2>&1 >/dev/tty)

    if [ $? -eq 0 ]; then
        # 選択されたアプリのコマンドを再構築
        local new_enabled=()
        while IFS= read -r sel_id; do
            [ -z "$sel_id" ] && continue
            for item in "${PRESETS[@]}"; do
                IFS="|" read -r id name cmd bin def <<< "$item"
                if [ "$id" = "$sel_id" ]; then
                    new_enabled+=("$cmd")
                    break
                fi
            done
        done <<< "$selected_ids"

        AUTOSTART_ENABLED=("${new_enabled[@]}")
        save_config

        dialog --title "設定完了" --msgbox "✅ 自動起動設定を保存しました！\n\n有効なアプリ数: ${#AUTOSTART_ENABLED[@]} 個\n次回のログイン/起動時から自動起動されます。" 9 55
        if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
            notify-send "🚀 自動起動設定" "設定を更新しました (${#AUTOSTART_ENABLED[@]} 個有効)"
        fi
    fi
}

# カスタムコマンドの追加
menu_add_custom() {
    load_config

    local new_cmd
    new_cmd=$(dialog --clear \
        --backtitle "i3wm Autostart Applications Manager" \
        --title "➕ カスタム起動コマンドの追加" \
        --inputbox "起動したいコマンドまたはスクリプトのパスを入力してください:\n(例: flatpak run com.spotify.Client, my-tool.sh --tray)" \
        11 65 \
        2>&1 >/dev/tty)

    if [ $? -eq 0 ] && [ -n "$new_cmd" ]; then
        CUSTOM_AUTOSTART+=("$new_cmd")
        save_config
        dialog --title "追加完了" --msgbox "✅ カスタムコマンドを追加しました:\n\n$new_cmd" 9 60
    fi
}

# カスタムコマンドの削除
menu_remove_custom() {
    load_config

    if [ ${#CUSTOM_AUTOSTART[@]} -eq 0 ]; then
        dialog --title "情報" --msgbox "登録されているカスタムコマンドはありません。" 7 45
        return
    fi

    local items=()
    local idx=1
    for c in "${CUSTOM_AUTOSTART[@]}"; do
        items+=("$idx" "$c")
        idx=$((idx + 1))
    done

    local chosen_idx
    chosen_idx=$(dialog --clear \
        --backtitle "i3wm Autostart Applications Manager" \
        --title "🗑️ カスタムコマンドの削除" \
        --menu "削除したいコマンドを選択してください:" \
        18 65 8 \
        "${items[@]}" \
        2>&1 >/dev/tty)

    if [ $? -eq 0 ] && [ -n "$chosen_idx" ]; then
        local remove_target="${CUSTOM_AUTOSTART[$((chosen_idx - 1))]}"
        local new_custom=()
        for i in "${!CUSTOM_AUTOSTART[@]}"; do
            if [ "$i" -ne "$((chosen_idx - 1))" ]; then
                new_custom+=("${CUSTOM_AUTOSTART[$i]}")
            fi
        done
        CUSTOM_AUTOSTART=("${new_custom[@]}")
        save_config
        dialog --title "削除完了" --msgbox "🗑️ コマンドを削除しました:\n\n$remove_target" 9 60
    fi
}

# 現在の自動起動一覧表示
menu_view_status() {
    load_config

    local msg="【プリセット自動起動 (${#AUTOSTART_ENABLED[@]} 件)】\n"
    if [ ${#AUTOSTART_ENABLED[@]} -eq 0 ]; then
        msg="${msg}  (なし)\n"
    else
        for c in "${AUTOSTART_ENABLED[@]}"; do
            local bin
            bin=$(echo "$c" | awk '{print $1}')
            local run_status="停止中"
            if pgrep -x "$bin" >/dev/null 2>&1 || pgrep -f "$c" >/dev/null 2>&1; then
                run_status="▶ 稼働中"
            fi
            msg="${msg}  • $c [$run_status]\n"
        done
    fi

    msg="${msg}\n【カスタム自動起動 (${#CUSTOM_AUTOSTART[@]} 件)】\n"
    if [ ${#CUSTOM_AUTOSTART[@]} -eq 0 ]; then
        msg="${msg}  (なし)\n"
    else
        for c in "${CUSTOM_AUTOSTART[@]}"; do
            local run_status="停止中"
            if pgrep -f "$c" >/dev/null 2>&1; then
                run_status="▶ 稼働中"
            fi
            msg="${msg}  • $c [$run_status]\n"
        done
    fi

    dialog --clear \
        --backtitle "i3wm Autostart Applications Manager" \
        --title "📋 現在の自動起動アプリケーション一覧" \
        --msgbox "$msg" 20 70
}

# テスト実行 (現在有効なアプリを即座に起動)
menu_test_run() {
    dialog --clear \
        --backtitle "i3wm Autostart Applications Manager" \
        --title "▶️ 自動起動のテスト実行" \
        --yesno "現在有効になっているアプリケーションを直ちに起動しますか？\n(既に起動しているアプリはスキップされます)" \
        8 65 \
        2>&1 >/dev/tty

    if [ $? -eq 0 ]; then
        apply_autostart
        dialog --title "実行完了" --msgbox "✅ 自動起動処理を実行しました。" 7 40
    fi
}

# メインメニュー
show_main_menu() {
    while true; do
        load_config
        local total_enabled=$((${#AUTOSTART_ENABLED[@]} + ${#CUSTOM_AUTOSTART[@]}))

        local choice
        choice=$(dialog --clear \
            --backtitle "i3wm Autostart Applications Manager" \
            --title "⚙️ i3 起動時アプリケーション設定" \
            --menu "ログイン時・i3起動時に自動起動するアプリを設定します (現在 $total_enabled 個有効):" \
            18 68 7 \
            "1" "🚀 自動起動アプリの選択 (チェックリスト)" \
            "2" "➕ カスタム起動コマンドの追加" \
            "3" "🗑️ カスタム起動コマンドの削除" \
            "4" "📋 現在の設定と稼働状況を確認" \
            "5" "▶️ 今すぐ自動起動をテスト実行" \
            "6" "↺ 初期推奨設定にリセット" \
            "0" "終了" \
            2>&1 >/dev/tty)

        local ret=$?
        [ $ret -ne 0 ] && break

        case "$choice" in
            1) menu_select_apps ;;
            2) menu_add_custom ;;
            3) menu_remove_custom ;;
            4) menu_view_status ;;
            5) menu_test_run ;;
            6)
                dialog --title "確認" --yesno "自動起動設定を初期推奨状態にリセットしますか？" 7 55 2>&1 >/dev/tty
                if [ $? -eq 0 ]; then
                    init_default_config
                    dialog --title "完了" --msgbox "初期推奨設定にリセットしました。" 7 40
                fi
                ;;
            0) break ;;
            *) break ;;
        esac
    done
    clear
}

# CLI フォールバック (dialog が無い場合)
show_cli_menu() {
    while true; do
        load_config
        echo "======================================"
        echo " ⚙️ i3 自動起動アプリケーション設定 (CLI)"
        echo "======================================"
        echo "1) 📋 現在の設定と稼働状況を確認"
        echo "2) ➕ カスタム起動コマンドの追加"
        echo "3) ▶️ 今すぐ自動起動をテスト実行"
        echo "4) ↺ 初期推奨設定にリセット"
        echo "0) 終了"
        echo "======================================"
        read -p "番号を選択 (0-4): " opt
        case "$opt" in
            1)
                echo "--- 有効なプリセット ---"
                for e in "${AUTOSTART_ENABLED[@]}"; do echo "  - $e"; done
                echo "--- カスタム ---"
                for e in "${CUSTOM_AUTOSTART[@]}"; do echo "  - $e"; done
                read -p "Enterキーで戻る..."
                ;;
            2)
                read -p "追加するコマンドを入力: " addc
                if [ -n "$addc" ]; then
                    CUSTOM_AUTOSTART+=("$addc")
                    save_config
                    echo "追加しました。"
                fi
                ;;
            3)
                apply_autostart
                echo "実行しました。"
                sleep 1
                ;;
            4)
                init_default_config
                echo "リセットしました。"
                sleep 1
                ;;
            0) break ;;
            *) echo "無効な入力です。"; sleep 1 ;;
        esac
    done
}

# dialog コマンドの有無で分岐
if command -v dialog &>/dev/null; then
    show_main_menu
else
    show_cli_menu
fi
