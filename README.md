# i3-config 🚀

究極に使いやすく、見た目もシンプルでモダンな **i3 Window Manager (i3wm)** の設定ファイルです。  
Debian/Ubuntu, Arch Linux, Fedora 向けの自動セットアップスクリプトが付属しています。

---

## 🌟 特徴

- **直感的なキーバインド**: Super (Mod4 / Windows) キーをプレフィックスとし、Vimスタイル (`h`, `j`, `k`, `l`) でフォーカス・ウィンドウ移動が可能
- **洗練された見た目**: タイトルバーを非表示にし、Gaps (ウィンドウ間の余白) や透明化・影効果 (`picom`) を導入
- **使いやすいランチャー**: `rofi` による高速かつ検索しやすいアプリランチャー
- **マルチメディア対応**: 音量調整・輝度調整・スクリーンショットなどの各種ショートカット対応
- **安全なインストール**: 既存の設定ファイルを自動でバックアップ (`config.backup.YYYYMMDD_HHMMSS`)
- **チートシート付属**: 設定キーバインドをブラウザで確認できる `i3-cheatsheet.html` を同梱

---

## 📦 依存パッケージ

セットアップスクリプトを実行すると、お使いのディストリビューションに応じて以下のパッケージが自動インストールされます。

- **i3** / **i3-wm**: ウィンドウマネージャー本体
- **rofi**: アプリケーションランチャー
- **picom**: コンポジタ (透明化・フェード効果など)
- **feh**: 壁紙設定ツール
- **brightnessctl**: 画面輝度調整
- **pavucontrol** / **pulseaudio-utils**: オーディオ管理
- **curl**: スクリプト実行用

---

## 🛠️ インストール方法

### 方法 1: ワンライナーで自動インストール（推奨）

ターミナルで以下のコマンドを実行するだけで、依存関係のインストール、既存設定のバックアップ、および新しい設定の適用がすべて自動で行われます。

```bash
curl -fsSL https://raw.githubusercontent.com/qlonix/i3-config/main/install.sh | bash
```

### 方法 2: 手動でリポジトリをクローンしてインストール

```bash
# リポジトリのクローン
git clone https://github.com/qlonix/i3-config.git
cd i3-config

# インストールスクリプトの実行
chmod +x install.sh
./install.sh
```

---

## 🔄 設定ファイルのアップデート方法

GitHub上でリポジトリが更新された際、以下のいずれかの方法で手元の環境を簡単にアップデートできます。

### 方法 1: ショートカットキーで更新（推奨）
i3起動中に `Super + Shift + u` を押すだけで、GitHubから最新設定を取得して自動で再読み込み（リロード）されます。

### 方法 2: コマンドラインから更新
ターミナルから以下のいずれかのコマンドを実行します：

```bash
# i3-config-update コマンド（~/.local/bin にパスが通っている場合）
i3-config-update

# またはスクリプトを直接実行
~/.config/i3/update.sh
```

### 方法 3: ワンライナーで更新
リポジトリを手元に保持していない場合でも、ワンライナーで最新化が可能です。

```bash
curl -fsSL https://raw.githubusercontent.com/qlonix/i3-config/main/update.sh | bash
```

---

## 📂 ファイル構成

| ファイル名 | 説明 |
| :--- | :--- |
| `config` | i3wm のメイン設定ファイル (`~/.config/i3/config` へ配置) |
| `install.sh` | 依存関係のインストールおよび設定配置を行う自動スクリプト |
| `update.sh` | GitHub上の最新設定を取得・適用しi3をリロードするアップデートスクリプト |
| `i3-cheatsheet.html` | キーバインドを一覧確認できるHTMLチートシート |
| `.agent/RULES.md` | 本プロジェクトの開発・コーディングルール |

---

## ⌨️ 主なショートカット一覧

| ショートカット | 機能 |
| :--- | :--- |
| `Super + Enter` | ターミナル起動 |
| `Super + d` | アプリケーションランチャー (`rofi`) 起動 |
| `Super + Shift + q` | フォーカス中のウィンドウを閉じる |
| `Super + h/j/k/l` | ウィンドウのフォーカス移動 |
| `Super + Shift + h/j/k/l` | ウィンドウの移動 |
| `Super + Shift + c` | i3設定ファイルの再読み込み |
| `Super + Shift + r` | i3の再起動 |
| `Super + Shift + u` | GitHubから最新設定を取得してアップデート |

---

## 📝 備考

- 設定を反映するために、インストール完了後はログアウトして再ログイン（または `Super + Shift + r` でi3を再起動）してください。
