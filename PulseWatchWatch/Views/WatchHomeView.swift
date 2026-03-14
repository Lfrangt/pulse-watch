import SwiftUI

/// Watch face — glance and go. Minimal, warm, no clutter.
struct WatchHomeView: View {
    
    @State private var score: Int = 72
    @State private var headline: String = "状态良好"
    @State private var insight: String = "适合训练"
    @State private var heartRate: Int = 68
    @State private var appeared = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Score ring — the hero element
                ZStack {
                    // Track
                    Circle()
                        .stroke(Color(hex: "2A2A2A"), lineWidth: 5)
                    
                    // Progress
                    Circle()
                        .trim(from: 0, to: appeared ? CGFloat(score) / 100 : 0)
                        .stroke(
                            statusColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: appeared)
                    
                    // Score
                    VStack(spacing: 2) {
                        Text("\(score)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "F5F0EB"))
                        
                        Text(headline)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(statusColor)
                    }
                }
                .frame(width: 120, height: 120)
                .padding(.top, 8)
                
                // Insight
                Text(insight)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color(hex: "8A8580"))
                    .multilineTextAlignment(.center)
                
                // Quick metrics
                HStack(spacing: 16) {
                    WatchMetric(icon: "heart.fill", value: "\(heartRate)", color: Color(hex: "C75C5C"))
                    WatchMetric(icon: "figure.walk", value: "6.4k", color: Color(hex: "7FB069"))
                }
                .padding(.top, 4)
            }
        }
        .containerBackground(Color(hex: "0F0F0F").gradient, for: .navigation)
        .onAppear {
            withAnimation { appeared = true }
        }
    }
    
    private var statusColor: Color {
        switch score {
        case 0..<40: return Color(hex: "C75C5C")
        case 40..<70: return Color(hex: "D4A056")
        default: return Color(hex: "7FB069")
        }
    }
}

struct WatchMetric: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "F5F0EB"))
        }
    }
}

#Preview {
    WatchHomeView()
}
