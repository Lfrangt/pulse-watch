import SwiftUI
import Charts

// MARK: - Interactive Chart Overlay
// Apple Health-style tap/drag selection for Swift Charts
// Adds floating tooltip, vertical indicator line, and haptic feedback

struct InteractiveChartOverlay<T, Label: View, Sublabel: View>: ViewModifier {

    let data: [T]
    let xValue: KeyPath<T, Date>
    let yValue: KeyPath<T, Double>
    let accentColor: Color
    @ViewBuilder let label: (T) -> Label
    @ViewBuilder let sublabel: (T) -> Sublabel

    @State private var selectedIndex: Int?
    @State private var isVisible = false
    @State private var hideTask: Task<Void, Never>?

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    func body(content: Content) -> some View {
        content
            .chartOverlay { proxy in
                GeometryReader { geo in
                    let plotFrame = proxy.plotFrame.map { geo[$0] }
                    if let plotFrame {
                        // Gesture layer
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        handleDrag(at: value.location, proxy: proxy, plotFrame: plotFrame)
                                    }
                                    .onEnded { _ in
                                        scheduleHide()
                                    }
                            )

                        // Vertical indicator line
                        if let idx = selectedIndex, idx < data.count, isVisible {
                            let point = data[idx]
                            if let xPos = proxy.position(forX: point[keyPath: xValue]) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(width: 0.5)
                                    .position(x: xPos, y: plotFrame.midY)
                                    .frame(height: plotFrame.height)
                                    .transition(.opacity)
                            }
                        }

                        // Selected point highlight
                        if let idx = selectedIndex, idx < data.count, isVisible {
                            let point = data[idx]
                            if let xPos = proxy.position(forX: point[keyPath: xValue]),
                               let yPos = proxy.position(forY: point[keyPath: yValue]) {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(1.3)
                                    .shadow(color: accentColor.opacity(0.5), radius: 6)
                                    .position(x: xPos, y: yPos)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let idx = selectedIndex, idx < data.count, isVisible {
                    tooltipView(for: data[idx])
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
                        .padding(.top, 2)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isVisible ? selectedIndex : nil)
    }

    // MARK: - Tooltip

    @ViewBuilder
    private func tooltipView(for point: T) -> some View {
        VStack(spacing: 2) {
            label(point)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            sublabel(point)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Gesture Handling

    private func handleDrag(at location: CGPoint, proxy: ChartProxy, plotFrame: CGRect) {
        guard !data.isEmpty else { return }

        // Cancel any pending hide
        hideTask?.cancel()
        hideTask = nil

        // Convert x position to date
        let localX = location.x - plotFrame.minX
        guard let dragDate: Date = proxy.value(atX: localX) else { return }

        // Find nearest data point
        let nearest = data.enumerated().min(by: { a, b in
            abs(a.element[keyPath: xValue].timeIntervalSince(dragDate))
            < abs(b.element[keyPath: xValue].timeIntervalSince(dragDate))
        })

        guard let nearest else { return }
        let newIndex = nearest.offset

        // Haptic on index change only
        if newIndex != selectedIndex {
            haptic.impactOccurred()
        }

        selectedIndex = newIndex

        if !isVisible {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    isVisible = false
                    selectedIndex = nil
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {

    /// Add Apple Health-style interactive selection to a Chart.
    ///
    /// Usage:
    /// ```swift
    /// Chart { ... }
    ///     .interactiveOverlay(
    ///         data: trendPoints,
    ///         xValue: \.date,
    ///         yValue: \.value,
    ///         label: { point in Text("\(Int(point.value)) bpm") },
    ///         sublabel: { point in Text(point.date.formatted(.dateTime.weekday(.abbreviated))) }
    ///     )
    /// ```
    func interactiveOverlay<T, Label: View, Sublabel: View>(
        data: [T],
        xValue: KeyPath<T, Date>,
        yValue: KeyPath<T, Double>,
        accentColor: Color = PulseTheme.accentTeal,
        @ViewBuilder label: @escaping (T) -> Label,
        @ViewBuilder sublabel: @escaping (T) -> Sublabel
    ) -> some View {
        modifier(InteractiveChartOverlay(
            data: data,
            xValue: xValue,
            yValue: yValue,
            accentColor: accentColor,
            label: label,
            sublabel: sublabel
        ))
    }
}
