#!/usr/bin/env python3
"""
Generate App Store marketing screenshots from raw simulator screenshots.

Usage:
    python3 scripts/generate_store_screenshots.py

Reads raw screenshots from fastlane/screenshots/{locale}/raw/
Outputs marketing screenshots to fastlane/screenshots/{locale}/
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
import math

# === Config ===
OUTPUT_WIDTH = 1290
OUTPUT_HEIGHT = 2796
DEVICE_CORNER_RADIUS = 60
PHONE_MARGIN_BOTTOM = -350  # Phone bleeds off bottom edge
PHONE_MARGIN_SIDE = 30

# Brand colors
ACCENT_TEAL = (0, 210, 211)  # Pulse Watch teal accent
BG_DARK = (10, 10, 20)
BG_GRADIENT_TOP = (15, 20, 45)
BG_GRADIENT_BOTTOM = (3, 5, 15)

SCREENSHOTS = [
    {
        "raw": "01_Dashboard.png",
        "out": "01_Dashboard_Marketing.png",
        "en_title": "Your Daily\nHealth Score",
        "en_sub": "AI-powered insights at a glance",
        "zh_title": "你的每日\n健康评分",
        "zh_sub": "AI 驱动，一眼掌握健康全貌",
    },
    {
        "raw": "02_Trends.png",
        "out": "02_Trends_Marketing.png",
        "en_title": "7-Day Trends\nat a Glance",
        "en_sub": "Heart rate · HRV · Sleep — all tracked",
        "zh_title": "一周趋势\n一目了然",
        "zh_sub": "心率 · HRV · 睡眠 全程追踪",
    },
    {
        "raw": "03_Workout.png",
        "out": "03_Workout_Marketing.png",
        "en_title": "Every Workout\nSaved",
        "en_sub": "Auto-synced from Apple Watch",
        "zh_title": "每次训练\n都被记录",
        "zh_sub": "Apple Watch 自动同步",
    },
    {
        "raw": "04_Alerts.png",
        "out": "04_Alerts_Marketing.png",
        "en_title": "Smart Heart\nRate Alerts",
        "en_sub": "Know when something's off",
        "zh_title": "智能心率\n异常提醒",
        "zh_sub": "异常第一时间通知你",
    },
    {
        "raw": "05_Privacy.png",
        "out": "05_Privacy_Marketing.png",
        "en_title": "Privacy First.\nNo Subscriptions.",
        "en_sub": "Your data stays on your device",
        "zh_title": "隐私至上\n一次买断",
        "zh_sub": "数据只存在你的设备上",
    },
]

def round_corners(img, radius):
    """Apply rounded corners to an image."""
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), img.size], radius=radius, fill=255)
    result = img.copy()
    result.putalpha(mask)
    return result

def draw_gradient_bg(width, height):
    """Create a rich dark gradient background with subtle color accents."""
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)
    
    for y in range(height):
        t = y / height
        # Main dark gradient with subtle blue/purple shift
        r = int(BG_GRADIENT_TOP[0] * (1 - t) + BG_GRADIENT_BOTTOM[0] * t)
        g = int(BG_GRADIENT_TOP[1] * (1 - t) + BG_GRADIENT_BOTTOM[1] * t)
        b = int(BG_GRADIENT_TOP[2] * (1 - t) + BG_GRADIENT_BOTTOM[2] * t)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    
    # Add subtle radial glow at top center (teal accent)
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = width // 2, int(height * 0.50)
    max_r = int(width * 1.5)
    for radius in range(max_r, 0, -5):
        alpha = int(60 * (1 - radius / max_r) ** 1.3)
        glow_draw.ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            fill=(ACCENT_TEAL[0], ACCENT_TEAL[1], ACCENT_TEAL[2], alpha)
        )
    
    img = img.convert("RGBA")
    img = Image.alpha_composite(img, glow)
    return img.convert("RGB")

def draw_device_frame(screenshot, corner_radius=50):
    """Create a device frame with shadow around the screenshot."""
    padding = 8
    shadow_size = 30
    total_pad = padding + shadow_size
    frame_w = screenshot.width + total_pad * 2
    frame_h = screenshot.height + total_pad * 2
    
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    
    # Shadow layer (soft glow)
    shadow = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        [(shadow_size - 5, shadow_size - 5), 
         (frame_w - shadow_size + 5, frame_h - shadow_size + 5)],
        radius=corner_radius + padding + 5,
        fill=(0, 180, 180, 50)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=25))
    frame = Image.alpha_composite(frame, shadow)
    
    # Thin bezel border
    border_mask = Image.new("L", (frame_w, frame_h), 0)
    border_draw = ImageDraw.Draw(border_mask)
    border_draw.rounded_rectangle(
        [(total_pad - padding, total_pad - padding), 
         (frame_w - total_pad + padding, frame_h - total_pad + padding)],
        radius=corner_radius + padding,
        fill=255
    )
    border_layer = Image.new("RGBA", (frame_w, frame_h), (50, 55, 70, 180))
    border_layer.putalpha(border_mask)
    frame = Image.alpha_composite(frame, border_layer)
    
    # Inner screenshot with rounded corners
    rounded = round_corners(screenshot.convert("RGBA"), corner_radius)
    frame.paste(rounded, (total_pad, total_pad), rounded)
    
    return frame

def load_fonts(is_chinese=False):
    """Load appropriate fonts."""
    if is_chinese:
        # Try common Chinese fonts on macOS
        zh_fonts = [
            "/System/Library/Fonts/STHeiti Medium.ttc",
            "/System/Library/Fonts/PingFang.ttc",
            "/Library/Fonts/Arial Unicode.ttf",
        ]
        for fp in zh_fonts:
            if os.path.exists(fp):
                try:
                    title_font = ImageFont.truetype(fp, 110)
                    sub_font = ImageFont.truetype(fp, 42)
                    return title_font, sub_font
                except:
                    continue
    
    # English / fallback
    en_fonts = [
        "/System/Library/Fonts/SFCompact.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
    ]
    for fp in en_fonts:
        if os.path.exists(fp):
            try:
                title_font = ImageFont.truetype(fp, 110)
                sub_font = ImageFont.truetype(fp, 42)
                return title_font, sub_font
            except:
                continue
    
    # Last resort
    title_font = ImageFont.load_default()
    sub_font = ImageFont.load_default()
    return title_font, sub_font

def generate_screenshot(raw_path, output_path, title, subtitle, is_chinese=False):
    """Generate a single marketing screenshot."""
    # Load raw screenshot
    raw = Image.open(raw_path).convert("RGB")
    
    # Create background
    bg = draw_gradient_bg(OUTPUT_WIDTH, OUTPUT_HEIGHT)
    bg = bg.convert("RGBA")
    
    # Scale raw screenshot to fit with margins
    phone_width = OUTPUT_WIDTH - PHONE_MARGIN_SIDE * 2
    scale = phone_width / raw.width
    phone_height = int(raw.height * scale)
    raw_scaled = raw.resize((phone_width, phone_height), Image.LANCZOS)
    
    # Create device frame
    framed = draw_device_frame(raw_scaled)
    
    # Position: phone at bottom, text at top
    phone_y = OUTPUT_HEIGHT - framed.height - PHONE_MARGIN_BOTTOM
    phone_x = (OUTPUT_WIDTH - framed.width) // 2
    
    # Ensure phone doesn't overlap text area too much
    min_phone_y = 480  # Leave room for title
    if phone_y < min_phone_y:
        # Scale down more if needed
        available_h = OUTPUT_HEIGHT - PHONE_MARGIN_BOTTOM - min_phone_y
        new_scale = available_h / (raw.height + 24)  # 24 for frame padding
        new_w = int(raw.width * new_scale)
        new_h = int(raw.height * new_scale)
        raw_scaled = raw.resize((new_w, new_h), Image.LANCZOS)
        framed = draw_device_frame(raw_scaled)
        phone_y = min_phone_y
        phone_x = (OUTPUT_WIDTH - framed.width) // 2
    
    bg.paste(framed, (phone_x, phone_y), framed)
    
    # Draw text
    title_font, sub_font = load_fonts(is_chinese)
    draw = ImageDraw.Draw(bg)
    
    # Title - centered, white, bold
    title_y = 180
    for i, line in enumerate(title.split("\n")):
        bbox = draw.textbbox((0, 0), line, font=title_font)
        tw = bbox[2] - bbox[0]
        tx = (OUTPUT_WIDTH - tw) // 2
        ty = title_y + i * 130
        draw.text((tx, ty), line, fill=(255, 255, 255), font=title_font)
    
    # Subtitle - centered, teal accent
    sub_y = title_y + len(title.split("\n")) * 130 + 30
    bbox = draw.textbbox((0, 0), subtitle, font=sub_font)
    sw = bbox[2] - bbox[0]
    sx = (OUTPUT_WIDTH - sw) // 2
    draw.text((sx, sub_y), subtitle, fill=ACCENT_TEAL, font=sub_font)
    
    # Save
    bg.convert("RGB").save(output_path, "PNG", quality=95)
    print(f"  ✅ {os.path.basename(output_path)}")

def main():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    for locale, title_key, sub_key, is_zh in [
        ("en-US", "en_title", "en_sub", False),
        ("zh-Hans", "zh_title", "zh_sub", True),
    ]:
        raw_dir = os.path.join(project_root, "fastlane", "screenshots", locale, "raw")
        out_dir = os.path.join(project_root, "fastlane", "screenshots", locale)
        
        if not os.path.exists(raw_dir):
            print(f"⚠️  No raw dir for {locale}: {raw_dir}")
            # Try to use en-US raw as fallback
            raw_dir = os.path.join(project_root, "fastlane", "screenshots", "en-US", "raw")
            if not os.path.exists(raw_dir):
                print(f"  ❌ No raw screenshots found, skipping {locale}")
                continue
        
        os.makedirs(out_dir, exist_ok=True)
        print(f"\n📱 Generating {locale} screenshots...")
        
        for ss in SCREENSHOTS:
            raw_path = os.path.join(raw_dir, ss["raw"])
            out_path = os.path.join(out_dir, ss["out"])
            
            if not os.path.exists(raw_path):
                print(f"  ⚠️  Missing: {ss['raw']}, skipping")
                continue
            
            generate_screenshot(
                raw_path,
                out_path,
                ss[title_key],
                ss[sub_key],
                is_chinese=is_zh,
            )
    
    print("\n🎉 All marketing screenshots generated!")
    print(f"   Output: fastlane/screenshots/en-US/ & zh-Hans/")

if __name__ == "__main__":
    main()
