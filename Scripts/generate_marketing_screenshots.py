#!/usr/bin/env python3
"""
Pulse Watch — App Store Marketing Screenshot Generator v3.1

Professional marketing images:
- Dark gradient + radial glow backgrounds (unique per screenshot)
- Realistic Space Black iPhone frame: thick enough for realism, 
  side buttons, Dynamic Island, gradient bezel, strong shadow
- Device aggressively bleeds off bottom edge (400px+ cut off)
- Title area is compact — maximize visible app screen
- 1290x2796 output (iPhone 15 Pro Max / 6.7")

Usage: python3 Scripts/generate_marketing_screenshots.py
Requirements: pip3 install Pillow
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ── Paths ──────────────────────────────────────────────────────────────
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCREENSHOTS_DIR = os.path.join(PROJECT_ROOT, "fastlane", "screenshots")

# ── Canvas ─────────────────────────────────────────────────────────────
W, H = 1290, 2796

# ── Device Frame Geometry ──────────────────────────────────────────────
DEVICE_W = 980                  # Outer width of phone
DEVICE_BEZEL = 10               # Visible bezel thickness
DEVICE_CORNER_R = 56            # iPhone 15 Pro corner radius
DEVICE_SCREEN_R = 48            # Inner screen corners
DEVICE_TOP_Y = 440              # Where phone top-edge starts
DEVICE_BLEED = 500              # Device extends 500px below canvas — aggressive crop

# Dynamic Island
ISLAND_W = 150
ISLAND_H = 44
ISLAND_Y_OFFSET = 14

# Buttons (side of device)
BUTTON_WIDTH = 4
POWER_BTN_Y = 200               # Relative to device top
POWER_BTN_H = 90
VOL_UP_Y = 180
VOL_DOWN_Y = 290
VOL_BTN_H = 60
SILENT_Y = 130
SILENT_H = 30

# Shadow
SHADOW_BLUR = 45
SHADOW_ALPHA = 100
SHADOW_OFFSET_Y = 15

# ── Layout ─────────────────────────────────────────────────────────────
TITLE_Y = 50
SUBTITLE_GAP = 18

# ── Colors ─────────────────────────────────────────────────────────────
WHITE = (255, 255, 255)
LIGHT_GRAY = (185, 190, 205)
DEVICE_BODY = (30, 30, 32)       # Space Black titanium
DEVICE_EDGE_LIGHT = (65, 65, 70) # Top/left edge highlight
DEVICE_EDGE_DARK = (20, 20, 22)  # Bottom/right edge (shadow side)
BUTTON_COLOR = (50, 50, 54)

# Per-screenshot themes — each visually distinct
THEMES = {
    "01": {"accent": (0, 210, 185),  "glow": (0, 170, 150),  "bg_top": (6, 24, 38),  "bg_bot": (2, 6, 12)},
    "02": {"accent": (85, 105, 255), "glow": (65, 85, 225),  "bg_top": (12, 8, 50),  "bg_bot": (4, 3, 18)},
    "03": {"accent": (255, 145, 55), "glow": (225, 115, 35), "bg_top": (38, 16, 5),  "bg_bot": (14, 5, 2)},
    "04": {"accent": (255, 60, 85),  "glow": (225, 45, 70),  "bg_top": (38, 6, 16),  "bg_bot": (15, 2, 6)},
    "05": {"accent": (50, 220, 125), "glow": (40, 190, 100), "bg_top": (5, 30, 20),  "bg_bot": (2, 12, 8)},
}

# ── Fonts ──────────────────────────────────────────────────────────────
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REGULAR = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_CJK_BOLD = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_CJK_REGULAR = "/System/Library/Fonts/STHeiti Medium.ttc"
SF_BOLD = "/System/Library/Fonts/SFNS.ttf"
SF_REGULAR = "/System/Library/Fonts/SFNS.ttf"

def _font(path, size, fallback=None):
    for p in [path, fallback]:
        if p and os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except:
                pass
    return ImageFont.load_default()


# ── Screenshot Configs ─────────────────────────────────────────────────
EN = [
    {"raw": "01_Dashboard.png", "out": "01_Dashboard_Marketing.png", "theme": "01",
     "title": "Your Daily\nHealth Score", "sub": "AI-powered insights at a glance"},
    {"raw": "02_Trends.png", "out": "02_Trends_Marketing.png", "theme": "02",
     "title": "7-Day Trends\nat a Glance", "sub": "Heart rate · HRV · Sleep · Steps"},
    {"raw": "03_Workout.png", "out": "03_Workout_Marketing.png", "theme": "03",
     "title": "Every Workout\nSaved", "sub": "Auto-synced from Apple Watch"},
    {"raw": "04_Alerts.png", "out": "04_Alerts_Marketing.png", "theme": "04",
     "title": "Smart Heart\nRate Alerts", "sub": "Know when something's off"},
    {"raw": "05_Privacy.png", "out": "05_Privacy_Marketing.png", "theme": "05",
     "title": "Privacy First.\nNo Subscriptions.", "sub": "Pay once. Own forever."},
]

ZH = [
    {"raw": "01_Dashboard.png", "out": "01_Dashboard_Marketing.png", "theme": "01",
     "title": "你的每日\n健康评分", "sub": "AI 驱动的健康洞察", "lang": "zh"},
    {"raw": "02_Trends.png", "out": "02_Trends_Marketing.png", "theme": "02",
     "title": "一周趋势\n一目了然", "sub": "心率 · HRV · 睡眠 · 步数", "lang": "zh"},
    {"raw": "03_Workout.png", "out": "03_Workout_Marketing.png", "theme": "03",
     "title": "每次训练\n自动记录", "sub": "Apple Watch 自动同步", "lang": "zh"},
    {"raw": "04_Alerts.png", "out": "04_Alerts_Marketing.png", "theme": "04",
     "title": "智能心率\n异常提醒", "sub": "异常时刻 即时通知", "lang": "zh"},
    {"raw": "05_Privacy.png", "out": "05_Privacy_Marketing.png", "theme": "05",
     "title": "隐私至上\n没有订阅", "sub": "一次购买 永久拥有", "lang": "zh"},
]


def create_background(theme):
    """Dark gradient + dual radial glow for depth."""
    bg = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    draw = ImageDraw.Draw(bg)
    top, bot = theme["bg_top"], theme["bg_bot"]
    
    for y in range(H):
        t = y / H
        # Ease-in curve for smoother gradient
        t2 = t * t
        r = int(top[0] + (bot[0] - top[0]) * t2)
        g = int(top[1] + (bot[1] - top[1]) * t2)
        b = int(top[2] + (bot[2] - top[2]) * t2)
        draw.line([(0, y), (W, y)], fill=(r, g, b, 255))
    
    gc = theme["glow"]
    
    # Primary glow — behind upper phone area
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy, max_r = W // 2, DEVICE_TOP_Y + 300, 900
    for rv in range(max_r, 0, -4):
        frac = rv / max_r
        alpha = int(40 * (1 - frac) ** 1.6)
        gd.ellipse([cx-rv, cy-rv, cx+rv, cy+rv], fill=(*gc, alpha))
    bg = Image.alpha_composite(bg, glow)
    
    # Secondary glow — top-right for asymmetry
    glow2 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g2d = ImageDraw.Draw(glow2)
    cx2, cy2 = int(W * 0.75), int(H * 0.12)
    for rv in range(450, 0, -5):
        alpha = int(15 * (1 - rv/450) ** 2)
        g2d.ellipse([cx2-rv, cy2-rv, cx2+rv, cy2+rv], fill=(*gc, alpha))
    bg = Image.alpha_composite(bg, glow2)
    
    return bg


def create_device(screenshot_path):
    """
    Realistic iPhone 15 Pro frame with side buttons.
    Device bleeds off bottom canvas edge.
    """
    ss = Image.open(screenshot_path).convert("RGBA")
    
    dev_x0 = (W - DEVICE_W) // 2
    dev_x1 = dev_x0 + DEVICE_W
    dev_y0 = DEVICE_TOP_Y
    dev_y1 = H + DEVICE_BLEED  # well below canvas
    
    work_h = H + DEVICE_BLEED + 200
    
    # ── Shadow layer ──
    shadow = Image.new("RGBA", (W, work_h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        [dev_x0 + 3, dev_y0 + SHADOW_OFFSET_Y, dev_x1 + 3, dev_y1 + SHADOW_OFFSET_Y],
        radius=DEVICE_CORNER_R, fill=(0, 0, 0, SHADOW_ALPHA))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    
    # ── Device layer ──
    device = Image.new("RGBA", (W, work_h), (0, 0, 0, 0))
    dd = ImageDraw.Draw(device)
    
    # Side buttons (left side — volume + silent switch)
    btn_x = dev_x0 - BUTTON_WIDTH
    dd.rectangle([btn_x, dev_y0 + SILENT_Y, dev_x0, dev_y0 + SILENT_Y + SILENT_H],
                 fill=BUTTON_COLOR)
    dd.rectangle([btn_x, dev_y0 + VOL_UP_Y, dev_x0, dev_y0 + VOL_UP_Y + VOL_BTN_H],
                 fill=BUTTON_COLOR)
    dd.rectangle([btn_x, dev_y0 + VOL_DOWN_Y, dev_x0, dev_y0 + VOL_DOWN_Y + VOL_BTN_H],
                 fill=BUTTON_COLOR)
    
    # Right side — power button
    dd.rectangle([dev_x1, dev_y0 + POWER_BTN_Y, dev_x1 + BUTTON_WIDTH, dev_y0 + POWER_BTN_Y + POWER_BTN_H],
                 fill=BUTTON_COLOR)
    
    # Main body
    dd.rounded_rectangle([dev_x0, dev_y0, dev_x1, dev_y1],
                         radius=DEVICE_CORNER_R, fill=DEVICE_BODY)
    
    # Edge highlights — 2px border with gradient effect
    # Top + left = lighter, bottom + right = darker (light from top-left)
    dd.rounded_rectangle([dev_x0, dev_y0, dev_x1, dev_y1],
                         radius=DEVICE_CORNER_R, outline=DEVICE_EDGE_LIGHT, width=2)
    # Inner darker outline for depth
    dd.rounded_rectangle([dev_x0+2, dev_y0+2, dev_x1-2, dev_y1-2],
                         radius=DEVICE_CORNER_R-2, outline=DEVICE_EDGE_DARK, width=1)
    
    # ── Screen area ──
    scr_x0 = dev_x0 + DEVICE_BEZEL
    scr_y0 = dev_y0 + DEVICE_BEZEL
    scr_x1 = dev_x1 - DEVICE_BEZEL
    scr_y1 = dev_y1 - DEVICE_BEZEL
    scr_w = scr_x1 - scr_x0
    scr_h = scr_y1 - scr_y0
    
    # Scale screenshot to fill screen (top-aligned)
    ss_w, ss_h = ss.size
    scale = scr_w / ss_w  # Fit width exactly — height overflows into bleed area
    new_w = int(ss_w * scale)
    new_h = int(ss_h * scale)
    ss_resized = ss.resize((new_w, new_h), Image.LANCZOS)
    
    # Top-aligned crop
    crop_x = (new_w - scr_w) // 2
    ss_cropped = ss_resized.crop((crop_x, 0, crop_x + scr_w, scr_h))
    
    # Rounded mask
    mask = Image.new("L", (scr_w, scr_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, scr_w-1, scr_h-1], radius=DEVICE_SCREEN_R, fill=255)
    
    ss_masked = ss_cropped.copy()
    ss_masked.putalpha(mask)
    device.paste(ss_masked, (scr_x0, scr_y0), ss_masked)
    
    # Dynamic Island
    icx = W // 2
    iy = scr_y0 + ISLAND_Y_OFFSET
    dd.rounded_rectangle(
        [icx - ISLAND_W//2, iy, icx + ISLAND_W//2, iy + ISLAND_H],
        radius=ISLAND_H//2, fill=(0, 0, 0, 255))
    
    # Subtle screen reflection (thin white line at top)
    reflection = Image.new("RGBA", (W, work_h), (0, 0, 0, 0))
    rd = ImageDraw.Draw(reflection)
    rd.rounded_rectangle(
        [scr_x0+40, scr_y0, scr_x1-40, scr_y0+2],
        radius=1, fill=(255, 255, 255, 20))
    device = Image.alpha_composite(device, reflection)
    
    # Composite and crop to canvas
    result = Image.alpha_composite(shadow, device)
    return result.crop((0, 0, W, H))


def draw_text(img, config):
    """Title + subtitle centered above device."""
    draw = ImageDraw.Draw(img)
    lang = config.get("lang", "en")
    
    if lang == "zh":
        tf = _font(FONT_CJK_BOLD, 96, FONT_BOLD)
        sf = _font(FONT_CJK_REGULAR, 38, FONT_REGULAR)
    else:
        tf = _font(SF_BOLD, 96, FONT_BOLD)
        sf = _font(SF_REGULAR, 38, FONT_REGULAR)
    
    title = config["title"]
    subtitle = config.get("sub", "")
    lines = title.split("\n")
    line_h = 114
    total_title_h = len(lines) * line_h
    sub_h = 48 if subtitle else 0
    total_h = total_title_h + SUBTITLE_GAP + sub_h
    
    avail = DEVICE_TOP_Y - TITLE_Y
    sy = TITLE_Y + (avail - total_h) // 2
    
    for i, line in enumerate(lines):
        bb = draw.textbbox((0, 0), line, font=tf)
        tw = bb[2] - bb[0]
        draw.text(((W - tw) // 2, sy + i * line_h), line, fill=WHITE, font=tf)
    
    if subtitle:
        bb = draw.textbbox((0, 0), subtitle, font=sf)
        sw = bb[2] - bb[0]
        draw.text(((W - sw) // 2, sy + total_title_h + SUBTITLE_GAP),
                  subtitle, fill=LIGHT_GRAY, font=sf)


def generate(raw_dir, config, out_dir):
    """Generate one marketing screenshot."""
    raw = os.path.join(raw_dir, "raw", config["raw"])
    if not os.path.exists(raw):
        raw = os.path.join(raw_dir, config["raw"])
    if not os.path.exists(raw):
        print(f"  ⚠️  Missing: {config['raw']}")
        return False
    
    theme = THEMES[config["theme"]]
    bg = create_background(theme)
    device = create_device(raw)
    result = Image.alpha_composite(bg, device)
    draw_text(result, config)
    
    out = os.path.join(out_dir, config["out"])
    result.convert("RGB").save(out, "PNG", optimize=True)
    print(f"  ✅ {config['out']}")
    return True


def main():
    print("🎨 Pulse Watch Marketing Screenshots v3.1\n")
    print(f"   Canvas: {W}×{H} | Device: {DEVICE_W}px | Bleed: {DEVICE_BLEED}px")
    print()
    
    en_dir = os.path.join(SCREENSHOTS_DIR, "en-US")
    os.makedirs(en_dir, exist_ok=True)
    print("📱 English (en-US):")
    for c in EN:
        generate(en_dir, c, en_dir)
    
    zh_dir = os.path.join(SCREENSHOTS_DIR, "zh-Hans")
    os.makedirs(zh_dir, exist_ok=True)
    print("\n📱 中文 (zh-Hans):")
    for c in ZH:
        generate(zh_dir, c, zh_dir)
    
    print(f"\n✨ Done! → {SCREENSHOTS_DIR}/")


if __name__ == "__main__":
    main()
