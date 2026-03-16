# App Store Screenshots

自动生成 App Store 提审截图。

## 设备要求

| 尺寸 | 设备 | 分辨率 |
|------|------|--------|
| 6.7" | iPhone 16 Pro Max | 1320 × 2868 |
| 6.7" | iPhone 16 Plus | 1290 × 2796 |

> App Store Connect 接受 6.7" 截图同时用于 6.7" 和 6.5" 展示尺寸。

## 快速生成

### 方法 1: 脚本（推荐）

```bash
chmod +x Scripts/run_screenshots.sh
./Scripts/run_screenshots.sh
```

截图保存在 `screenshots/` 目录下，按设备分文件夹：
- `screenshots/iPhone_16_Pro_Max/`
- `screenshots/iPhone_16_Plus/`

### 方法 2: Xcode 手动

1. 在 Xcode 中打开项目
2. 选择 `PulseWatch` scheme
3. 选择目标 Simulator（iPhone 16 Pro Max）
4. `Cmd+U` 运行测试
5. 在 Test Navigator 中右键 → "Jump to Report"
6. 展开测试方法，点击截图附件查看/导出

## 截图列表

| # | 名称 | 内容 |
|---|------|------|
| 01 | Dashboard | 评分大圆环 + 健康指标 |
| 02 | Dashboard_Trends | 7天趋势图 |
| 03 | Exercise | 训练记录页 |
| 04 | Trends | 历史趋势图 |
| 05 | Trends_Detail | 趋势详情/周报对比 |
| 06 | Settings | 设置页面 |

## UITests Target

`PulseWatchUITests` target 在 `project.yml` 中配置：
- 类型：`bundle.ui-testing`
- 依赖：`PulseWatch` app target
- 源码：`PulseWatchUITests/ScreenshotGenerator.swift`

如需重新生成项目：
```bash
xcodegen generate
```

## 注意事项

- 截图使用 **Demo Mode** 数据，不依赖真实 HealthKit
- 通过 launch arguments 自动启用演示模式和跳过 Onboarding
- 如需调整截图内容，编辑 `ScreenshotGenerator.swift`
- 需要 Xcode 16+ 和 iOS 18.5 Simulator runtime
