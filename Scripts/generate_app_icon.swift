#!/usr/bin/env swift
// 使用 CoreGraphics 生成 1024x1024 App Icon PNG
// 运行：swift Scripts/generate_app_icon.swift

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let width = size
let height = size

// 创建 CGContext
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("❌ 无法创建 CGContext")
    exit(1)
}

let s = CGFloat(size)

// --- 1. 暖色渐变背景 ---
let gradientColors = [
    CGColor(red: 0.788, green: 0.663, blue: 0.431, alpha: 1.0),  // #C9A96E amber gold
    CGColor(red: 0.722, green: 0.537, blue: 0.290, alpha: 1.0),  // #B8894A deep gold
    CGColor(red: 0.627, green: 0.388, blue: 0.227, alpha: 1.0),  // #A0633A transition
    CGColor(red: 0.545, green: 0.290, blue: 0.227, alpha: 1.0),  // #8B4A3A terracotta
] as CFArray

let locations: [CGFloat] = [0.0, 0.35, 0.65, 1.0]

if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) {
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: s),    // CoreGraphics 坐标系 Y 轴翻转
        end: CGPoint(x: s, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

// --- 2. 内部高光（径向渐变） ---
let glowColors = [
    CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18),
    CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.02),
    CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0),
] as CFArray

let glowLocations: [CGFloat] = [0.0, 0.5, 1.0]

if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: glowLocations) {
    context.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: s * 0.35, y: s * 0.7),  // Y 翻转
        startRadius: s * 0.05,
        endCenter: CGPoint(x: s * 0.35, y: s * 0.7),
        endRadius: s * 0.55,
        options: [.drawsBeforeStartLocation]
    )
}

// --- 3. 圆形轮廓 ---
let center = CGPoint(x: s / 2, y: s / 2)
let ringRadius = s * 0.30
let ringLineWidth = s * 0.022

context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
context.setLineWidth(ringLineWidth)
context.addArc(center: center, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
context.strokePath()

// --- 4. 心跳脉搏线 ---
let midY = center.y
let leftX = center.x - ringRadius * 0.85
let rightX = center.x + ringRadius * 0.85
let pulseLineWidth = s * 0.025

context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
context.setLineWidth(pulseLineWidth)
context.setLineCap(.round)
context.setLineJoin(.round)

context.move(to: CGPoint(x: leftX, y: midY))

// 平稳段
let seg1 = leftX + (rightX - leftX) * 0.25
context.addLine(to: CGPoint(x: seg1, y: midY))

// 小P波
let seg2 = leftX + (rightX - leftX) * 0.32
context.addLine(to: CGPoint(x: seg2, y: midY + s * 0.035))  // Y 翻转

// 回到基线
let seg3 = leftX + (rightX - leftX) * 0.37
context.addLine(to: CGPoint(x: seg3, y: midY))

// QRS —  Q波小下沉
let seg4 = leftX + (rightX - leftX) * 0.43
context.addLine(to: CGPoint(x: seg4, y: midY - s * 0.025))  // Y 翻转

// R波大尖峰
let seg5 = leftX + (rightX - leftX) * 0.50
context.addLine(to: CGPoint(x: seg5, y: midY + s * 0.14))  // Y 翻转

// S波下沉
let seg6 = leftX + (rightX - leftX) * 0.57
context.addLine(to: CGPoint(x: seg6, y: midY - s * 0.06))  // Y 翻转

// 回到基线
let seg7 = leftX + (rightX - leftX) * 0.63
context.addLine(to: CGPoint(x: seg7, y: midY))

// T波
let seg8 = leftX + (rightX - leftX) * 0.72
context.addQuadCurve(
    to: CGPoint(x: seg8, y: midY),
    control: CGPoint(x: leftX + (rightX - leftX) * 0.675, y: midY + s * 0.04)  // Y 翻转
)

// 末尾平稳段
context.addLine(to: CGPoint(x: rightX, y: midY))
context.strokePath()

// --- 5. 暗角 ---
let vignetteColors = [
    CGColor(red: 0, green: 0, blue: 0, alpha: 0.0),
    CGColor(red: 0, green: 0, blue: 0, alpha: 0.15),
] as CFArray

let vignetteLocations: [CGFloat] = [0.0, 1.0]

if let vignetteGradient = CGGradient(colorsSpace: colorSpace, colors: vignetteColors, locations: vignetteLocations) {
    context.drawRadialGradient(
        vignetteGradient,
        startCenter: center,
        startRadius: s * 0.35,
        endCenter: center,
        endRadius: s * 0.75,
        options: [.drawsAfterEndLocation]
    )
}

// --- 导出 PNG ---
guard let image = context.makeImage() else {
    print("❌ 无法生成图像")
    exit(1)
}

let basePath = FileManager.default.currentDirectoryPath

// 写入 iOS AppIcon
let iosPath = "\(basePath)/PulseWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png" as CFString
guard let iosDest = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: iosPath as String) as CFURL,
    "public.png" as CFString,
    1, nil
) else {
    print("❌ 无法创建 iOS 输出文件")
    exit(1)
}
CGImageDestinationAddImage(iosDest, image, nil)
CGImageDestinationFinalize(iosDest)

// 写入 watchOS AppIcon
let watchPath = "\(basePath)/PulseWatchWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png" as CFString
guard let watchDest = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: watchPath as String) as CFURL,
    "public.png" as CFString,
    1, nil
) else {
    print("❌ 无法创建 watchOS 输出文件")
    exit(1)
}
CGImageDestinationAddImage(watchDest, image, nil)
CGImageDestinationFinalize(watchDest)

print("✅ App Icon 已生成（1024x1024）")
print("   → PulseWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
print("   → PulseWatchWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
