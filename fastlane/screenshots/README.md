# App Store Marketing Screenshots

WHOOP/Strava-style marketing screenshots with device frames and feature text overlays.

## Output

```
fastlane/screenshots/
├── en-US/          # English (5 images)
│   ├── 01_Dashboard.png   "Your Daily Health Score"
│   ├── 02_Trends.png      "7-Day Trends at a Glance"
│   ├── 03_Workout.png     "Every Workout Saved"
│   ├── 04_Alerts.png      "Smart Heart Rate Alerts"
│   └── 05_Privacy.png     "Privacy First. No Subscriptions."
├── zh-Hans/        # 中文 (5 images)
│   ├── 01_Dashboard.png   "每日健康评分"
│   ├── 02_Trends.png      "7天趋势一目了然"
│   ├── 03_Workout.png     "每次训练都被记录"
│   ├── 04_Alerts.png      "智能心率提醒"
│   └── 05_Privacy.png     "隐私至上 · 一次买断"
└── README.md
```

## Regenerate

```bash
python3 Scripts/generate_marketing_screenshots.py
```

Requirements: `pip3 install Pillow`

## Specs

- **Size:** 1290×2796 (iPhone 15 Pro Max / 6.7")
- **Style:** Dark gradient background + white headline + iPhone device frame + app screen
- **Dependencies:** Python 3, Pillow
- **No raw screenshots needed** — generates realistic mock app screens programmatically

## Customization

Edit `Scripts/generate_marketing_screenshots.py`:
- `SCREENSHOTS_EN` / `SCREENSHOTS_ZH` — titles and screen types
- `create_*_screen()` functions — individual screen content
- Colors: `ACCENT`, `BG_TOP`, `BG_BOTTOM` etc.
