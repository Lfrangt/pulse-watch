# Pulse — DESIGN.md

> 这份文档是 Pulse UI 的"宪法"。任何视觉、布局、交互决策必须可以追溯到这里的某一条。
> 任何与本文件冲突的实现，**改实现，不改本文件**。除非显式批准并 bump 版本号。

**Version**: 1.0 · 2026-05-05
**Source of truth for**: iPhone app · Watch app · Widget · Complication
**Audience**: 工程实现（Swift / SwiftUI）· 后续设计迭代

---

## 0. 设计立场（One-liner）

> **Pulse 看起来像一台精密仪表，而不是一个健康仪表盘。因为我们卖的是"今天该怎么练"的判断，不是"我今天数据多好看"的展示。**

每个屏幕都必须能回答一句话："这屏在帮用户决定什么？" 答不出来的元素一律删除。

## 1. 视觉气质（Mood）

5 个形容词，按权重排：

1. **Editorial（编辑式）** — 有层级、有节奏、像一份认真排版的科学期刊
2. **Instrumental（仪表化）** — 数据是测量结果，不是装饰；刻度、数字、单位讲究
3. **Restrained（克制）** — 一个强调色，无渐变，无阴影炫技，无 emoji
4. **Bilingual-native（双语原生）** — 中文不是英文翻译，是平等的 primary 语言
5. **Wrist-first（先手腕）** — Watch / Widget / Complication 不是 iPhone 的精简版

**Pulse 看起来不像**：渐变彩虹环、卡通插画、emoji 反应、Material Design、玻璃拟物（除 iOS 系统 chrome 外）。

---

## 2. 配色（Color Tokens）

### 2.1 双模式

每个 token 都有 `light` / `dark` 两个值。**不允许**直接写颜色字面量；必须通过 token。

```ts
// tokens.color
{
  bg:        light: '#F5F4EF'   dark: '#0B0C0A'   // 主背景
  bgElev:    light: '#FFFFFF'   dark: '#141513'   // 卡片 / 浮起面
  bgSunk:    light: '#EDEBE3'   dark: '#070806'   // 凹陷区域
  line:      light: rgba(20,22,18,0.10)   dark: rgba(255,255,255,0.10)
  lineSoft:  light: rgba(20,22,18,0.06)   dark: rgba(255,255,255,0.05)
  ink:       light: '#14140F'   dark: '#F2F1EC'   // 主文字
  inkMid:    light: rgba(...,0.62)        dark: rgba(...,0.62)  // 次要文字
  inkDim:    light: rgba(...,0.38)        dark: rgba(...,0.34)  // 三级文字 / 元数据
  accent:    light: '#C8FF3D'   dark: '#D2FF3D'   // 唯一强调色（lime）
  accentInk: '#0E1A00' (恒定)                       // accent 上的文字色
  good:      light: '#2F7A3D'   dark: '#7BD68A'
  warn:      light: '#B6571B'   dark: '#E89A55'
  bad:       light: '#A11D1D'   dark: '#E76E6E'
  chipBg:    light: rgba(...,0.05)        dark: rgba(...,0.06)
}
```

### 2.2 配色规则（Hard Rules）

- **强调色只有一个**：lime (`accent`)。score > 阈值、active state、关键 CTA、Watch 复杂功能上。**不允许**第二种饱和色作装饰。
- **状态色（good / warn / bad）只用于语义**：anomaly、PR、超阈值。不用作"漂亮"。
- **背景色不渐变**。任何 `linear-gradient` / `radial-gradient` 必须有特殊理由（目前唯一允许：tab bar 底部的 fade-to-bg 用于 scroll mask）。
- **outdoor 强光场景**：Watch face 上文字必须 ≥ `#F2F1EC` on `#000`，对比度 ≥ 16:1。
- **dark 模式不是反色**：背景是 `#0B0C0A` 不是纯黑；文字是 `#F2F1EC` 不是纯白。

---

## 3. 字体系统（Typography）

### 3.1 字体族（3 个，不增不减）

```ts
fonts.display  : 'Inter'        // 数字 + 英文标题 / body
fonts.cjk      : 'Noto Sans SC' // 中文（fallback for 'Inter')
fonts.mono     : 'JetBrains Mono' // 标签 / 元数据 / 时间码 / 单位
```

**规则**：
- 中文环境下，`Inter` 自动 fallback 到 `Noto Sans SC`，CJK 字符用 SC，混排时英文仍用 Inter。
- **mono 字体只用于 LABEL 类**：metric label、单位、时间戳、日期、状态码。**不**用于 body 或标题。
- 不使用 SF Pro 之外的 Apple 字体；不使用 Helvetica；不使用 Roboto；不使用衬线字体。

### 3.2 字号阶（Scale）

iPhone（pt）：

```
display-1 : 96  weight 250  letter-spacing -0.04em  tabular-nums  (score 主数字)
display-2 : 72  weight 300  letter-spacing -0.03em  tabular-nums  (live workout 计时器)
display-3 : 48  weight 300  letter-spacing -0.02em  tabular-nums
title-1   : 28  weight 400  letter-spacing -0.6px                  (vital 数字)
title-2   : 22  weight 400  letter-spacing -0.4px                  (页面标题)
body-l    : 17  weight 450
body      : 15  weight 450
body-s    : 13  weight 450
caption   : 12  weight 400
mono-l    : 12  mono     letter-spacing 0.5
mono      : 10  mono     letter-spacing 0.8 UPPERCASE
mono-s    :  9  mono     letter-spacing 0.6 UPPERCASE
```

Watch（pt）：

```
watch-score: 70  weight 250  letter-spacing -2.5  tabular-nums
watch-label: 9   mono        letter-spacing 0.8 UPPERCASE
watch-vital: 8.5 mono        letter-spacing 0.4
```

Widget（pt）：

```
widget-s-score: 56  weight 250
widget-m-score: 48  weight 250
widget-l-score: 64  weight 250
widget-label  : 10  mono UPPERCASE
```

### 3.3 数字规则

- 所有"测量值"数字必须 `font-variant-numeric: tabular-nums` + `font-feature-settings: 'tnum', 'ss01'`。
- 单位不和数字混排同字号；单位用 `mono` 字体，约为数字字号的 18-22%，对齐 baseline。
- 小数点用 `.` 不用 `·`。

### 3.4 双语规则

- 任何屏幕的中文版必须先于英文版做 truncation 检查 — 中文密度更高。
- 中英混排时不强制空格（用 `letter-spacing` 调整代替）。
- 中文不允许使用 `letter-spacing` 大于 0.04em（避免分崩）。
- 标签 mono 字体在中文环境也用 mono — 中文 label 走 SC，仍 UPPERCASE 不适用，改为去 letter-spacing、去 uppercase。

---

## 4. 间距 / 圆角 / 描边阶梯

### 4.1 Spacing（pt）

```
4 · 8 · 12 · 14 · 18 · 22 · 26 · 32 · 40
```

**规则**：
- 屏幕边距：`22pt` 左右（iPhone）；`14pt`（Watch）；`12pt`（Widget）。
- 卡片内边距：`14–18pt`。
- 卡片间间距：`8pt`（紧凑网格）/ `26pt`（语义分组之间）。
- section header 与下方内容：`12pt`。
- 不允许半值（不要 `13` `17`，用 `12` `18`）。

### 4.2 圆角（Radius，pt）

```
2  : 内嵌色块 / chip 内的图标
8  : 小 chip
14 : 内卡片 / button
18 : 主卡片 / 屏幕大块
38 : Watch 设备外框
999: pill / 状态徽章
```

不使用 4 / 6 / 10 / 12 / 16 / 20 / 24。

### 4.3 描边（Stroke）

- 所有描边 `0.5px`，颜色 `line` 或 `lineSoft`。
- **不**使用实心 1px 描边作装饰。
- 数据图表线条：`1.25–1.5px`，`stroke-linecap: round`。
- 刻度（tick）：major `1.25px`，minor `0.75px`。

---

## 5. Iconography

### 5.1 立场

**默认不用图标。** 图标必须为信息让路。如果一个 label 用文字能说清，**不要**配图标。

### 5.2 允许的图形原语

- 圆点（status indicator）：8pt，`accent` / `good` / `warn` / `bad`
- 三角箭头（trend arrow）：9×9pt，向上=good、向下=bad（per-metric 校准，不是机械上=好）
- "→" 和 "←"（导航）：mono 字体绘制，不用 SVG icon
- 圆环（dial）刻度
- 心率区间弧
- 睡眠 stage 条带

### 5.3 禁止

- emoji（非品牌一部分）
- 拟物线条图标（dumbbell、heart shape 等）— **必须用语言代替**："Pull" 不画哑铃
- 彩色图标
- 大于 24pt 的图标（替代方案：用大号数字或大号文字）

---

## 6. Motion

### 6.1 总原则

> **静态优先，动态为生理信号让步。**

### 6.2 什么时候动

| 触发 | 动画 | 时长 | Easing |
|---|---|---|---|
| 分数变化 | 数字滚动 + dial arc easing | 600ms | cubic-bezier(0.4, 0, 0.2, 1) |
| HR 心率脉冲 | accent 圆点呼吸（仅 live workout） | 真实 BPM | linear |
| Tab 切换 | 横向滑入 8pt | 220ms | ease-out |
| Sheet 弹出 | 标准 iOS spring | 系统默认 | — |
| Anomaly 警报 | warn 边框 0.5→1.5→0.5 闪烁 1 次 | 500ms | ease-in-out |
| Streak 增加 | accent chip scale 1.0→1.08→1.0 | 400ms | spring |

### 6.3 什么时候不动

- 滚动列表行内：**不要**淡入。列表是数据，不是 UI 表演。
- 屏幕加载：**不要** skeleton 动画；用静态占位符 + mono 字体的 "loading…"。
- 卡片 hover：iOS 上不存在 hover；不要写。
- 数字增长不超过 1 unit 时不滚动（视觉噪音）。

### 6.4 Reduce Motion

任何动画在 `accessibilityReduceMotionEnabled == true` 时降级为瞬时切换；HR 脉冲降级为静态填充圆点。

---

## 7. 组件原语（Component Primitives）

> 不预设是 "card" 还是 "list"。先想"信息单元"。

### 7.1 `<Metric>`
**职责**：呈现一个测量值。
**结构**：mono label · tabular 大数字 · mono 单位 · 可选 trend 箭头 · 可选 sub-line
**变体**：inline / chip / detail-hero / watch-glance / widget

### 7.2 `<Dial>`
**职责**：0–100 类分数的视觉化。
**结构**：60 tick marks（5 主 / 5 次）· accent arc 表示百分比 · 中央数字
**变体**：iPhone 240pt · Watch 不用（手腕直接显数字）

### 7.3 `<Insight>`
**职责**：一句话告诉用户该怎么办。
**结构**：mono small label · 中等字号一句话 · 可选 chip CTA
**规则**：必须是动词开头（"Train hard" / "Recover" / "Sleep more"），不能是数字。

### 7.4 `<TrendChart>`
**职责**：多日趋势。
**结构**：横向 path · 末端高亮点 · 虚线基线 · mono 字体首末日期
**禁**：图例、网格、柱状双色、3D。

### 7.5 `<SleepBand>`
**职责**：一夜睡眠 stage 时间轴。
**结构**：4 行（awake/REM/core/deep）每段对齐到对应行的 y。
**色**：deep=`ink`, core=`inkMid`, REM=`accent`, awake=`inkDim`。

### 7.6 `<HRZoneRing>`
**职责**：5 区间 + 当前 HR 指针。
**结构**：5 弧段 + 1 跟踪点 + 中央 HR 数字。
**色**：Z1 lineSoft / Z2 inkDim / Z3 accent / Z4 warn / Z5 bad。

### 7.7 `<Timeline>`
**职责**：一天/一周事件流。
**结构**：左 8pt 圆点（impact 颜色）+ 标题 + 时间码（mono）+ 详情。
**禁**：图标、缩略图、卡片化每行。

### 7.8 `<SectionHead>`
**职责**：屏幕分块。
**结构**：mono `01` 编号 · 标题 · 可选 sub · 可选 right-aligned action。
**编号**：每屏从 `01` 开始递增；跨屏不延续。

### 7.9 `<Card>`
**职责**：信息分组容器。
**结构**：`bgElev` · radius 18 · 0.5px line · 14–18pt padding。
**禁**：阴影（除非用作 z-index 提示，例如 sheet）。

### 7.10 `<Chip>`
**职责**：状态徽章 / quick prompt。
**结构**：pill · `chipBg` 或 `accent` · mono 字体 · 10pt。

---

## 8. Information Architecture（与 spec §3 模块映射）

### 8.1 iPhone IA

```
Today      — A2 score · A3 brief · A4 vitals (top 6) · B1 suggestion · A8 timeline
History    — B8 list · B4 strength · B5 strain · B6 achievements · C2 calendar
Coach      — D1 status · D2 conversation
Reports    — C5 weekly · C6 monthly · C7 streaks · C8 goals · C3 anomalies · C4 correlations · A7 health age · C9 body comp
Settings (≡ in topbar) — F1–F8
```

详细映射表见 `Pulse.html` 中各 screen 注释。每个 §3 模块**必须**映射到上述某个位置；目前 v1 范围内无悬空模块。

### 8.2 Watch 导航

- 主屏：score + 1 行 insight + HR + HRV + sleep（`E1`）
- 上滑：start workout（`B2`）
- 下滑：今日 timeline（`A8`）
- 长按：训练建议（`B1`）

### 8.3 Widget × 3 + Complication × 2

- Small：score + status label
- Medium：score + 3 vitals (HR / HRV / sleep)
- Large：score + insight + sleep + steps + suggested workout
- Complication circular：score
- Complication rectangular：score + label

---

## 9. Failure States（必须设计的状态）

每个屏幕必须有以下 5 状态：

1. **No data yet**（首日，HealthKit 已授权但无数据）：mono 字体 "AWAITING DATA · 0 / 4 vitals"
2. **No HealthKit auth**：单一 CTA + 解释（不是错误页）
3. **OpenClaw disconnected**（仅 Coach）：`good` 圆点变 `inkDim`，状态条显示 "offline · 12 queued"
4. **Demo mode active**：所有屏幕顶部 `chip` "DEMO DATA" 持续显示
5. **No paired Watch**（仅 Watch-related entry）：替代文案，不阻塞主功能

---

## 10. Hard Constraints（不可违反）

1. **Glance tier (§2.1) 零交互可见** — 启动后第一帧 / Watch face / Widget 上必须呈现。
2. **算法不可改** — §5.1–5.10 公式、阈值、HR zone 边界一字不改。
3. **双语权重相等** — 任何 PR/changeset 必须同时通过 zh-Hans + en 截图审查。
4. **Action over information** — 每屏第一眼必须呈现 1 句动词开头的 insight。
5. **三个 surface 同等重要** — Watch / Widget / Complication 不允许说"after iOS"。
6. **三种字体** — Inter · Noto Sans SC · JetBrains Mono。第四种字体需要 design lead 批准。
7. **一个强调色** — lime accent。第二饱和色禁止。
8. **不画拟物图标** — dumbbell / heart / muscle 一律用文字。

---

## 11. Open Questions（设计 lead 需要回答）

转给 Claude Code 时这些应该是 PR 评论里的 blocker：

1. Anomaly 警报的紧迫感分级：所有 anomaly 都用 `warn` 还是 critical（Low SpO₂ < 92%）升级到 `bad`？
2. Streak 在 Watch 上是否始终显示，还是只有 milestone 当天？
3. 户外强光场景是否要单独的 "outdoor mode" tweak（强对比黑底大字）？
4. Live workout 末尾的复盘屏幕：跟随系统主题还是强制 dark（手腕场景）？
5. Widget large 在数据稀疏（首周）时的降级方案？

---

**End of DESIGN.md · v1.0**
