
import SwiftUI

//Color Extensions
extension Color {
    init(_ colorName: String) {
        switch colorName {
        case "systemRed":
            self = Color(.systemRed)
        case "systemBlue":
            self = Color(.systemBlue)
        case "systemGreen":
            self = Color(.systemGreen)
        case "systemOrange":
            self = Color(.systemOrange)
        case "systemTeal":
            self = Color(.systemTeal)
        case "systemIndigo":
            self = Color(.systemIndigo)
        case "systemPurple":
            self = Color(.systemPurple)
        case "systemPink":
            self = Color(.systemPink)
        case "systemYellow":
            self = Color(.systemYellow)
        case "systemGray":
            self = Color(.systemGray)
        default:
            self = Color(.systemBlue)
        }
    }
}

//View Extensions
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
    }

    func statCardStyle() -> some View {
        self
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
    }
}

//Date Extensions
extension Date {
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    func timeFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    func relativeDateString() -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: self, to: now)
            if let days = components.day, days < 7 {
                return "\(days) days ago"
            } else {
                return formatted(style: .short)
            }
        }
    }
}

//Array Extensions
extension Array where Element == HealthDataPoint {
    var averageValue: Double {
        guard !isEmpty else { return 0 }
        return map { $0.value }.reduce(0, +) / Double(count)
    }

    var minValue: Double {
        return map { $0.value }.min() ?? 0
    }

    var maxValue: Double {
        return map { $0.value }.max() ?? 0
    }

    var latestReading: HealthDataPoint? {
        return self.max { $0.date < $1.date }
    }

    func readings(for days: Int) -> [HealthDataPoint] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return filter { $0.date >= cutoffDate }
    }
}

//Double Extensions
extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }

    func formatted(decimalPlaces: Int = 1) -> String {
        return String(format: "%.\(decimalPlaces)f", self)
    }
}

//Custom Modifiers
struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.3), Color.clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(x: isAnimating ? 1 : 0, anchor: .leading)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func pulse() -> some View {
        modifier(PulseAnimation())
    }

    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}
