#!/usr/bin/env python3
"""
i3wm Wallpaper & Lockscreen Helper
壁紙から画面解像度に合わせたロック画面用画像(リサイズ/ぼかし/ロック案内テキスト)を生成します。
"""

import sys
import os
import subprocess
from PIL import Image, ImageFilter, ImageDraw, ImageFont

def get_screen_resolution():
    """xrandr からプライマリまたは最初の画面解像度を取得"""
    try:
        output = subprocess.check_output(['xrandr', '--current'], universal_newlines=True)
        for line in output.splitlines():
            if ' connected' in line:
                for part in line.split():
                    if 'x' in part and '+' in part:
                        res = part.split('+')[0]
                        w, h = map(int, res.split('x'))
                        return w, h
    except Exception:
        pass
    return 1920, 1080

def create_lockscreen(image_path, output_path, style="blur", bg_color="#1E1E2E"):
    width, height = get_screen_resolution()

    # 画像の読み込みまたは単色画像の生成
    img = None
    if image_path and os.path.isfile(image_path):
        try:
            raw_img = Image.open(image_path).convert('RGB')
            # アスペクト比を維持して画面全体をカバー (Center Crop)
            img_w, img_h = raw_img.size
            scale = max(width / img_w, height / img_h)
            new_w, new_h = int(img_w * scale), int(img_h * scale)
            resized = raw_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
            
            left = (new_w - width) // 2
            top = (new_h - height) // 2
            img = resized.crop((left, top, left + width, top + height))
        except Exception as e:
            print(f"Warning: Failed to load image {image_path}: {e}")
            img = None

    if img is None:
        # 単色背景
        hex_color = bg_color.lstrip('#')
        if len(hex_color) == 6:
            r, g, b = tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
        else:
            r, g, b = (30, 30, 46)
        img = Image.new('RGB', (width, height), color=(r, g, b))

    # スタイル適用 (ぼかし)
    if style == "blur":
        img = img.filter(ImageFilter.GaussianBlur(radius=15))
        # ぼかしの上に少し暗めのオーバーレイを適用して文字とリングの視認性を向上
        overlay = Image.new('RGBA', (width, height), (0, 0, 0, 80))
        img = Image.alpha_composite(img.convert('RGBA'), overlay).convert('RGB')

    # ロック案内テキストの描画
    draw = ImageDraw.Draw(img)

    # フォントの探索
    font_candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    ]
    cjk_font_candidates = [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc",
        "/usr/share/fonts/truetype/takao-gothic/TakaoPGothic.ttf",
        "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf",
    ]

    title_font = None
    for f in font_candidates:
        if os.path.exists(f):
            try:
                title_font = ImageFont.truetype(f, 36)
                break
            except Exception:
                continue

    sub_font = None
    for f in cjk_font_candidates + font_candidates:
        if os.path.exists(f):
            try:
                sub_font = ImageFont.truetype(f, 18)
                break
            except Exception:
                continue

    if not title_font:
        title_font = ImageFont.load_default()
    if not sub_font:
        sub_font = ImageFont.load_default()

    # i3lockの丸いインジケータは中央に配置されるため、テキストは中央上部に配置
    center_x = width // 2
    text_y = height // 2 - 130
    subtext_y = height // 2 - 80

    title_text = "LOCKED"
    sub_text = "パスワードを入力してEnterキーを押してください"

    # テキスト幅とアイコン位置の計算
    text_bbox = draw.textbbox((0, 0), title_text, font=title_font)
    title_w = text_bbox[2] - text_bbox[0]
    icon_size = 26
    gap = 12
    total_w = icon_size + gap + title_w
    start_x = center_x - total_w // 2
    icon_cx = start_x + icon_size // 2
    title_x = start_x + icon_size + gap

    # テキストの背景に半透明プレートを描画 (視認性確保)
    plate_w = 480
    plate_h = 100
    plate_x0 = center_x - plate_w // 2
    plate_y0 = text_y - 32
    plate_x1 = center_x + plate_w // 2
    plate_y1 = plate_y0 + plate_h

    plate_overlay = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    plate_draw = ImageDraw.Draw(plate_overlay)
    plate_draw.rounded_rectangle(
        [plate_x0, plate_y0, plate_x1, plate_y1],
        radius=14,
        fill=(0, 0, 0, 140),
        outline=(255, 255, 255, 40),
        width=1
    )
    img = Image.alpha_composite(img.convert('RGBA'), plate_overlay).convert('RGB')
    draw = ImageDraw.Draw(img)

    # 南京錠アイコンのベクター描画 (フォント非依存で文字化けゼロ)
    body_w = icon_size
    body_h = int(icon_size * 0.72)
    body_x0 = icon_cx - body_w // 2
    body_y0 = text_y - body_h // 2 + 3
    body_x1 = body_x0 + body_w
    body_y1 = body_y0 + body_h

    arc_w = int(body_w * 0.65)
    arc_h = int(icon_size * 0.58)
    arc_x0 = icon_cx - arc_w // 2
    arc_y0 = body_y0 - arc_h + 3
    arc_x1 = arc_x0 + arc_w
    arc_y1 = body_y0 + int(arc_h * 0.4)

    white_color = (255, 255, 255)
    draw.arc([arc_x0, arc_y0, arc_x1, arc_y1], start=180, end=0, fill=white_color, width=3)
    draw.line([arc_x0, (arc_y0 + arc_y1) // 2, arc_x0, body_y0 + 2], fill=white_color, width=3)
    draw.line([arc_x1, (arc_y0 + arc_y1) // 2, arc_x1, body_y0 + 2], fill=white_color, width=3)
    draw.rounded_rectangle([body_x0, body_y0, body_x1, body_y1], radius=4, fill=white_color)

    # 鍵穴の描画
    hole_color = (30, 30, 46)
    draw.ellipse([icon_cx - 2, body_y0 + 4, icon_cx + 2, body_y0 + 8], fill=hole_color)
    draw.line([icon_cx, body_y0 + 6, icon_cx, body_y0 + 12], fill=hole_color, width=2)

    # テキスト描画
    draw.text((title_x, text_y), title_text, fill=white_color, anchor='lm', font=title_font)
    draw.text((center_x, subtext_y), sub_text, fill=(210, 215, 230), anchor='mm', font=sub_font)

    # 保存
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    img.save(output_path, 'PNG')
    print(f"✅ Lockscreen saved to {output_path} ({width}x{height})")

if __name__ == '__main__':
    img_path = sys.argv[1] if len(sys.argv) > 1 else ""
    out_path = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/.config/i3/lockscreen.png")
    style_arg = sys.argv[3] if len(sys.argv) > 3 else "blur"
    color_arg = sys.argv[4] if len(sys.argv) > 4 else "#1E1E2E"

    create_lockscreen(img_path, out_path, style_arg, color_arg)
