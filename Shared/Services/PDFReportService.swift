import UIKit
import SwiftData

/// PDF 健康报告生成服务 — 使用 UIGraphicsPDFRenderer 生成多页月度报告
@MainActor
final class PDFReportService {

    static let shared = PDFReportService()
    private init() {}

    // MARK: - 公开接口

    func generateMonthlyPDF(
        summaries: [DailySummary],
        workouts: [WorkoutHistoryEntry],
        strengthRecords: [StrengthRecord]
    ) throws -> URL {
        let cal = Calendar.current
        let thisMonthStart = cal.safeDate(from: cal.dateComponents([.year, .month], from: .now))
        let lastMonthStart = cal.safeDate(byAdding: .month, value: -1, to: thisMonthStart)

        let monthSummaries = summaries
            .filter { $0.date >= lastMonthStart && $0.date < thisMonthStart }
            .sorted { $0.date < $1.date }
        let monthWorkouts = workouts
            .filter { $0.startDate >= lastMonthStart && $0.startDate < thisMonthStart }
            .sorted { $0.startDate < $1.startDate }
        let monthStrength = strengthRecords
            .filter { $0.date >= lastMonthStart && $0.date < thisMonthStart }
            .sorted { $0.date < $1.date }

        let fmt = DateFormatter()
        fmt.dateFormat = String(localized: "yyyy-MM")
        let monthLabel = fmt.string(from: lastMonthStart)

        // A4 尺寸 (points)
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = pdfRenderer.pdfData { context in
            // === PAGE 1: Cover + Overview ===
            context.beginPage()
            var y: CGFloat = margin

            // 品牌
            y = drawText("PULSE", x: margin, y: y, width: contentWidth,
                         font: .systemFont(ofSize: 12, weight: .bold),
                         color: UIColor(red: 0, green: 0.96, blue: 1, alpha: 1),
                         alignment: .center)
            y += 8

            // 月份标题
            y = drawText(String(format: String(localized: "%@ Health Report"), monthLabel), x: margin, y: y, width: contentWidth,
                         font: .systemFont(ofSize: 24, weight: .bold),
                         color: .black, alignment: .center)
            y += 4

            y = drawText("Monthly Health Report", x: margin, y: y, width: contentWidth,
                         font: .systemFont(ofSize: 12, weight: .regular),
                         color: .gray, alignment: .center)
            y += 24

            // 分隔线
            y = drawLine(x: margin, y: y, width: contentWidth)
            y += 16

            // 核心指标概览
            y = drawText(String(localized: "Key Metrics Overview"), x: margin, y: y, width: contentWidth,
                         font: .systemFont(ofSize: 16, weight: .semibold),
                         color: .black, alignment: .left)
            y += 12

            let scores = monthSummaries.compactMap(\.dailyScore)
            let avgScore = scores.isEmpty ? "—" : "\(scores.reduce(0, +) / scores.count)"
            let avgHRV = monthSummaries.compactMap(\.averageHRV)
            let avgHRVStr = avgHRV.isEmpty ? "—" : String(format: "%.0f ms", avgHRV.reduce(0, +) / Double(avgHRV.count))
            let avgRHR = monthSummaries.compactMap(\.restingHeartRate)
            let avgRHRStr = avgRHR.isEmpty ? "—" : String(format: "%.0f bpm", avgRHR.reduce(0, +) / Double(avgRHR.count))
            let sleepVals = monthSummaries.compactMap(\.sleepDurationMinutes).map { Double($0) / 60.0 }
            let avgSleep = sleepVals.isEmpty ? "—" : String(format: "%.1fh", sleepVals.reduce(0, +) / Double(sleepVals.count))
            let totalSteps = monthSummaries.compactMap(\.totalSteps).reduce(0, +)

            let metrics: [(String, String)] = [
                (String(localized: "Average Score"), avgScore),
                (String(localized: "Average HRV"), avgHRVStr),
                (String(localized: "Average RHR"), avgRHRStr),
                (String(localized: "Average Sleep"), avgSleep),
                (String(localized: "Total Steps"), "\(totalSteps.formatted())"),
                (String(localized: "Workouts"), "\(monthWorkouts.count)"),
                (String(localized: "Days of Data"), "\(monthSummaries.count)"),
            ]

            for (label, value) in metrics {
                y = drawMetricRow(label: label, value: value, x: margin, y: y, width: contentWidth)
            }

            y += 16
            y = drawLine(x: margin, y: y, width: contentWidth)
            y += 16

            // 每日评分列表
            y = drawText(String(localized: "Daily Score Records"), x: margin, y: y, width: contentWidth,
                         font: .systemFont(ofSize: 16, weight: .semibold),
                         color: .black, alignment: .left)
            y += 12

            // 表头
            y = drawTableHeader(x: margin, y: y, width: contentWidth)

            for summary in monthSummaries {
                if y > pageHeight - margin - 30 {
                    context.beginPage()
                    y = margin
                    y = drawTableHeader(x: margin, y: y, width: contentWidth)
                }
                y = drawSummaryRow(summary, x: margin, y: y, width: contentWidth)
            }

            // === PAGE 2+: Workouts ===
            if !monthWorkouts.isEmpty {
                context.beginPage()
                y = margin

                y = drawText(String(localized: "Workout Records"), x: margin, y: y, width: contentWidth,
                             font: .systemFont(ofSize: 16, weight: .semibold),
                             color: .black, alignment: .left)
                y += 12

                for workout in monthWorkouts {
                    if y > pageHeight - margin - 40 {
                        context.beginPage()
                        y = margin
                    }
                    y = drawWorkoutRow(workout, x: margin, y: y, width: contentWidth)
                }
            }

            // === Strength Records ===
            if !monthStrength.isEmpty {
                if y > pageHeight - margin - 80 {
                    context.beginPage()
                    y = margin
                }

                y += 16
                y = drawLine(x: margin, y: y, width: contentWidth)
                y += 16

                y = drawText(String(localized: "Strength Training Records"), x: margin, y: y, width: contentWidth,
                             font: .systemFont(ofSize: 16, weight: .semibold),
                             color: .black, alignment: .left)
                y += 12

                for record in monthStrength {
                    if y > pageHeight - margin - 30 {
                        context.beginPage()
                        y = margin
                    }
                    y = drawStrengthRow(record, x: margin, y: y, width: contentWidth)
                }
            }

            // Footer on last page
            let footerY = pageHeight - margin
            drawText("Generated by Pulse · \(Date.now.formatted(.dateTime.year().month().day()))",
                     x: margin, y: footerY, width: contentWidth,
                     font: .systemFont(ofSize: 9, weight: .regular),
                     color: .lightGray, alignment: .center)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pulse-monthly-report.pdf")
        try data.write(to: url)
        return url
    }

    // MARK: - Drawing Helpers

    @discardableResult
    private func drawText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
                          font: UIFont, color: UIColor, alignment: NSTextAlignment) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]

        let rect = CGRect(x: x, y: y, width: width, height: 200)
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let boundingRect = attrStr.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                 options: [.usesLineFragmentOrigin], context: nil)
        attrStr.draw(in: rect)
        return y + ceil(boundingRect.height)
    }

    private func drawLine(x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        return y + 1
    }

    private func drawMetricRow(label: String, value: String, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.black
        ]

        NSAttributedString(string: label, attributes: labelAttrs)
            .draw(in: CGRect(x: x, y: y, width: width * 0.6, height: 20))
        NSAttributedString(string: value, attributes: valueAttrs)
            .draw(in: CGRect(x: x + width * 0.6, y: y, width: width * 0.4, height: 20))

        return y + 22
    }

    private func drawTableHeader(x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let headers = [
            String(localized: "Date"),
            String(localized: "Score"),
            String(localized: "HR"),
            "HRV",
            String(localized: "Sleep"),
            String(localized: "Steps")
        ]
        let colWidths: [CGFloat] = [0.18, 0.12, 0.15, 0.15, 0.15, 0.25]
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.darkGray
        ]

        var colX = x
        for (i, header) in headers.enumerated() {
            NSAttributedString(string: header, attributes: attrs)
                .draw(in: CGRect(x: colX, y: y, width: width * colWidths[i], height: 16))
            colX += width * colWidths[i]
        }

        return y + 18
    }

    private func drawSummaryRow(_ s: DailySummary, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let colWidths: [CGFloat] = [0.18, 0.12, 0.15, 0.15, 0.15, 0.25]
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"

        var values: [String] = []
        values.append(fmt.string(from: s.date))
        values.append(s.dailyScore.map { "\($0)" } ?? "—")
        values.append(s.restingHeartRate.map { String(format: "%.0f", $0) } ?? "—")
        values.append(s.averageHRV.map { String(format: "%.0f", $0) } ?? "—")
        values.append(s.sleepDurationMinutes.map { String(format: "%.1fh", Double($0) / 60.0) } ?? "—")
        values.append(s.totalSteps.map { "\($0)" } ?? "—")

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.black
        ]

        var colX = x
        for (i, value) in values.enumerated() {
            NSAttributedString(string: value, attributes: attrs)
                .draw(in: CGRect(x: colX, y: y, width: width * colWidths[i], height: 14))
            colX += width * colWidths[i]
        }

        return y + 16
    }

    private func drawWorkoutRow(_ w: WorkoutHistoryEntry, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d HH:mm"

        let line1 = "\(fmt.string(from: w.startDate))  \(w.activityName)  \(w.durationMinutes)min"
        let line2Parts = [
            w.totalCalories.map { String(format: "%.0f kcal", $0) },
            w.averageHeartRate.map { String(format: "Avg HR %.0f", $0) },
            w.totalDistance.map { String(format: "%.1f km", $0 / 1000) }
        ].compactMap { $0 }.joined(separator: "  ·  ")

        var currentY = drawText(line1, x: x, y: y, width: width,
                                font: .systemFont(ofSize: 10, weight: .medium),
                                color: .black, alignment: .left)

        if !line2Parts.isEmpty {
            currentY = drawText(line2Parts, x: x, y: currentY, width: width,
                                font: .systemFont(ofSize: 9, weight: .regular),
                                color: .gray, alignment: .left)
        }

        return currentY + 6
    }

    private func drawStrengthRow(_ r: StrengthRecord, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"

        let line = "\(fmt.string(from: r.date))  \(r.liftType.capitalized)  \(String(format: "%.1f", r.weightKg))kg × \(r.sets)×\(r.reps)  1RM: \(String(format: "%.1f", r.estimated1RM))kg\(r.isPersonalRecord ? " 🏆" : "")"

        return drawText(line, x: x, y: y, width: width,
                        font: .systemFont(ofSize: 10, weight: .regular),
                        color: .black, alignment: .left) + 4
    }
}
