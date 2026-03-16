#!/usr/bin/env python3
"""
Generate App Store marketing screenshots v4 — Frameless style.
No device bezel. Screenshot floats with rounded corners + deep shadow.
This is the modern approach used by Oura, Linear, Bear, etc.
Cleaner, lets the UI speak for itself.
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

CANVAS_W, CANVAS_H = 1290, 2796

# Screenshot display config
SCREEN_W = 1080  # display width of the floating screenshot
SCREEN_CORNER = 55  # iOS-style rounded corners
SCREEN_X = (CANVAS_W - SCREEN_W) // 2
SCREEN_Y_TOP = 700  # top of screenshot; will bleed off bottom

# Colors
BG_BASE = (6, 6, 14)
TEXT_WHITE = (255, 255, 255)
TEXT_LIGHT = (220, 220, 235)  # brighter subtitle for readability

SCREENSHOTS_EN = [
    {
        "src": "01_Dashboard.png", "out": "01_Dashboard_Marketing.png",
        "headline": "Your Daily\nHealth Score",
        "subtitle": "AI-powered insights at a glance",
        "accent": (0, 220, 195),
        "bg_top": (6, 16, 22), "bg_bot": (3, 5, 10),
        "glow": (0, 100, 90),
    },
    {
        "src": "02_Trends.png", "out": "02_Trends_Marketing.png",
        "headline": "7-Day Trends\nat a Glance",
        "subtitle": "Heart rate · HRV · Sleep · Steps",
        "accent": (70, 140, 255),
        "bg_top": (8, 10, 28), "bg_bot": (3, 4, 12),
        "glow": (30, 55, 170),
    },
    {
        "src": "03_Workout.png", "out": "03_Workout_Marketing.png",
        "headline": "Every Workout\nTracked",
        "subtitle": "Auto-synced from Apple Watch",
        "accent": (255, 150, 50),
        "bg_top": (18, 12, 6), "bg_bot": (8, 4, 2),
        "glow": (130, 60, 10),
    },
    {
        "src": "04_Alerts.png", "out": "04_Alerts_Marketing.png",
        "headline": "Smart Heart\nRate Alerts",
        "subtitle": "Know when something's off",
        "accent": (255, 75, 75),
        "bg_top": (20, 6, 8), "bg_bot": (10, 3, 4),
        "glow": (140, 20, 25),
    },
    {
        "src": "05_Privacy.png", "out": "05_Privacy_Marketing.png",
        "headline": "Privacy First.\nNo Subscriptions.",
        "subtitle": "Pay once. Own forever.",
        "accent": (0, 220, 130),
        "bg_top": (6, 18, 14), "bg_bot": (2, 8, 6),
        "glow": (0, 110, 60),
    },
]

SCREENSHOTS_ZH = [
    {
        "src": "01_Dashboard.png", "out": "01_Dashboard_Marketing.png",
        "headline": "每日健康\n评分",
        "subtitle": "AI 驱动的健康洞察",
        "accent": (0, 220, 195),
        "bg_top": (6, 16, 22), "bg_bot": (3, 5, 10),
        "glow": (0, 100, 90),
    },
    {
        "src": "02_Trends.png", "out": "02_Trends_Marketing.png",
        "headline": "7 天趋势\n一目了然",
        "subtitle": "心率 · HRV · 睡眠 · 步数",
        "accent": (70, 140, 255),
        "bg_top": (8, 10, 28), "bg_bot": (3, 4, 12),
        "glow": (30, 55, 170),
    },
    {
        "src": "03_Workout.png", "out": "03_Workout_Marketing.png",
        "headline": "每次训练\n自动记录",
        "subtitle": "Apple Watch 自动同步",
        "accent": (255, 150, 50),
        "bg_top": (18, 12, 6), "bg_bot": (8, 4, 2),
        "glow": (130, 60, 10),
    },
    {
        "src": "04_Alerts.png", "out": "04_Alerts_Marketing.png",
        "headline": "智能心率\n异常提醒",
        "subtitle": "及时发现健康风险",
        "accent": (255, 75, 75),
        "bg_top": (20, 6, 8), "bg_bot": (10, 3, 4),
        "glow": (140, 20, 25),
    },
    {
        "src": "05_Privacy.png", "out": "05_Privacy_Marketing.png",
        "headline": "隐私至上\n买断制",
        "subtitle": "一次购买，永久拥有",
        "accent": (0, 220, 130),
        "bg_top": (6, 18, 14), "bg_bot": (2, 8, 6),
        "glow": (0, 110, 60),
    },
]


def find_font(names, size):
    paths = ["/System/Library/Fonts/", "/System/Library/Fonts/Supplemental/",
             "/Library/Fonts/", os.path.expanduser("~/Library/Fonts/")]
    for n in names:
        for b in paths:
            p = os.path.join(b, n)
            if os.path.exists(p):
                try:
                    return ImageFont.truetype(p, size)
                except:
                    pass
    return ImageFont.load_default()


def get_fonts(cjk=False):
    if cjk:
        b = ["PingFang.ttc", "STHeiti Medium.ttc"]
        r = ["PingFang.ttc"]
    else:
        b = ["SF-Pro-Display-Bold.otf", "Helvetica-Bold.ttc", "Arial Bold.ttf"]
        r = ["SF-Pro-Display-Regular.otf", "Helvetica.ttc", "Arial.ttf"]
    return find_font(b, 128), find_font(r, 46)


def draw_bg(canvas, top, bot, glow):
    draw = ImageDraw.Draw(canvas)
    for y in range(CANVAS_H):
        t = y / CANVAS_H
        draw.line([(0, y), (CANVAS_W, y)], fill=tuple(
            int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

    gl = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    cx, cy = CANVAS_W // 2, SCREEN_Y_TOP + 400
    for i in range(55):
        t = i / 55
        a = int(50 * (1 - t))
        rx = int(700 * (0.2 + 0.8 * t))
        ry = int(1000 * (0.2 + 0.8 * t))
        gd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry],
                    fill=(*glow, a))
    gl = gl.filter(ImageFilter.GaussianBlur(95))
    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), gl).convert("RGB"))


def draw_screenshot(canvas, src_path):
    """Float rounded-corner screenshot with deep shadow."""
    ss = Image.open(src_path).convert("RGBA")

    # Scale to display width
    scale = SCREEN_W / ss.width
    disp_h = int(ss.height * scale)
    ss = ss.resize((SCREEN_W, disp_h), Image.LANCZOS)

    # Create rounded-corner mask
    mask = Image.new("L", (SCREEN_W, disp_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, SCREEN_W - 1, disp_h - 1], radius=SCREEN_CORNER, fill=255)

    # Apply mask to screenshot
    ss_masked = Image.new("RGBA", (SCREEN_W, disp_h), (0, 0, 0, 0))
    ss_masked.paste(ss, mask=mask)

    # Deep shadow
    pad = 80
    shw = Image.new("RGBA", (SCREEN_W + pad * 2, disp_h + pad * 2), (0, 0, 0, 0))
    sh_mask = Image.new("L", (SCREEN_W + pad * 2, disp_h + pad * 2), 0)
    ImageDraw.Draw(sh_mask).rounded_rectangle(
        [pad // 2, pad // 2, SCREEN_W + pad * 3 // 2, disp_h + pad * 3 // 2],
        radius=SCREEN_CORNER + 10, fill=140)
    shw.putalpha(sh_mask)
    shw = shw.filter(ImageFilter.GaussianBlur(45))

    # Composite
    out = canvas.convert("RGBA")
    out.paste(shw, (SCREEN_X - pad, SCREEN_Y_TOP - pad // 3), shw)
    out.paste(ss_masked, (SCREEN_X, SCREEN_Y_TOP), ss_masked)

    # No border stroke — clean frameless look

    return out.convert("RGB")


def draw_text(canvas, headline, subtitle, accent, hf, sf):
    draw = ImageDraw.Draw(canvas)
    lines = headline.split("\n")
    ms = []
    for l in lines:
        bb = draw.textbbox((0, 0), l, font=hf)
        ms.append((bb[2] - bb[0], bb[3] - bb[1]))

    gap = 10
    th = sum(m[1] for m in ms) + gap * (len(lines) - 1)
    sbb = draw.textbbox((0, 0), subtitle, font=sf)
    sw, sh = sbb[2] - sbb[0], sbb[3] - sbb[1]

    block = th + 28 + sh + 32 + 4
    y0 = max(50, (SCREEN_Y_TOP - 30 - block) // 2)

    y = y0
    for i, l in enumerate(lines):
        w, h = ms[i]
        draw.text(((CANVAS_W - w) // 2, y), l, fill=TEXT_WHITE, font=hf)
        y += h + gap

    sy = y + 28
    draw.text(((CANVAS_W - sw) // 2, sy), subtitle, fill=TEXT_LIGHT, font=sf)

    bw = 48
    by = sy + sh + 32
    draw.rounded_rectangle(
        [(CANVAS_W - bw) // 2, by, (CANVAS_W + bw) // 2, by + 4],
        radius=2, fill=accent)


def gen(cfg, src_dir, out_dir, hf, sf):
    sp = os.path.join(src_dir, cfg["src"])
    op = os.path.join(out_dir, cfg["out"])
    if not os.path.exists(sp):
        print(f"  ⚠️  {sp}")
        return False

    c = Image.new("RGB", (CANVAS_W, CANVAS_H), BG_BASE)
    draw_bg(c, cfg["bg_top"], cfg["bg_bot"], cfg["glow"])
    c = draw_screenshot(c, sp)
    draw_text(c, cfg["headline"], cfg["subtitle"], cfg["accent"], hf, sf)
    c.save(op, "PNG", optimize=True)
    print(f"  ✅ {cfg['out']}")
    return True


def main():
    proj = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    en_h, en_s = get_fonts(False)
    zh_h, zh_s = get_fonts(True)
    print(f"EN: {en_h.getname()}, ZH: {zh_h.getname()}")

    en_d = os.path.join(proj, "fastlane", "screenshots", "en-US")
    print("\n📱 en-US:")
    for c in SCREENSHOTS_EN:
        gen(c, en_d, en_d, en_h, en_s)

    zh_d = os.path.join(proj, "fastlane", "screenshots", "zh-Hans")
    print("\n📱 zh-Hans:")
    for c in SCREENSHOTS_ZH:
        gen(c, zh_d, zh_d, zh_h, zh_s)

    print(f"\n🎉 {len(SCREENSHOTS_EN) + len(SCREENSHOTS_ZH)} screenshots done.")


if __name__ == "__main__":
    main()
