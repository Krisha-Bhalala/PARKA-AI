import SwiftUI
import Charts
import CoreHaptics

//Chart Configuration
struct ChartConfiguration {
    let title: String
    let unit: String
    let color: Color
    let gradient: Gradient
}

//Trend Indicator
enum TrendStatus: String {
    case improving = "Improving"
    case stable = "Stable"
    case worsening = "Needs Attention"
}

//Simple Data Display View
struct SimpleDataDisplayView: View {
    @StateObject private var healthDataManager = HealthDataManager()
    @State private var hapticEngine: CHHapticEngine?
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    @State private var endDate: Date = Date()
    @State private var showDatePicker: Bool = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var selectedMetric: HealthMetric = .heartRate
    @State private var showAuthorizationAlert: Bool = false
    @State private var isAuthorized: Bool = false
    @State private var showAuthorizationAlert: Bool = false
    @State private var isAuthorized: Bool = false

    var body: some View {
        ZStack {
            // Gradient background for futuristic look
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#E3EAF5"), Color(hex: "#BFD1F0")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            HStack(spacing: 4) {
                Circle()
                .fill(isAuthorized ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                Text(healthDataManager.authorizationStatus)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.gray)
            }

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Health Analytics")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.black)

                    Spacer()

                    // Authorization Status Indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isAuthorized ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(healthDataManager.authorizationStatus)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .accessibilityLabel("Health Analytics")


                if !isAuthorized && healthDataManager.authorizationStatus == "Not Requested" {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#FF3B30"))

                        Text("Connect to Apple Health")
                            .font(.system(size: 18, weight: .bold, design: .rounded))

                        Text("Allow access to your health data to track Parkinson's symptoms")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button(action: {
                            requestHealthKitAuthorization()
                        }) {
                            Text("Grant Access")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(LinearGradient(gradient: Gradient(colors: [Color(hex: "#007AFF"), Color(hex: "#005BB5")]), startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                        }
                        .padding(.horizontal, 32)
                    }
                    .padding(.vertical, 32)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                }

                // Main content (only show if authorized)
                if isAuthorized {
                    // Parameter Selector (Left-to-Right Scroll)
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(HealthMetric.allCases) { metric in
                                    ParameterCardView(
                                        metric: metric,
                                        isSelected: selectedMetric == metric,
                                        action: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                selectedMetric = metric
                                                playHaptic()
                                            }
                                            print("Selected \(metric.displayName) with \(healthDataManager.getDataForMetric(metric).count) data points")
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .frame(height: 120)
                        .accessibilityLabel("Parameter selector")
                        .accessibilityHint("Scroll left to right to select a health metric")
                    }

                    // Date Range Picker
                    VStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showDatePicker.toggle()
                                buttonScale = 1.05
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        buttonScale = 1.0
                                    }
                                }
                            }
                            playHaptic()
                        }) {
                            Text(showDatePicker ? "Hide Date Range" : "Select Date Range")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(LinearGradient(gradient: Gradient(colors: [Color(hex: "#007AFF"), Color(hex: "#005BB5")]), startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                        }
                        .scaleEffect(buttonScale)
                        .padding(.horizontal, 16)
                        .accessibilityLabel(showDatePicker ? "Hide date range picker" : "Show date range picker")

                        if showDatePicker {
                            VStack(spacing: 10) {
                                DatePicker(
                                    "Start Date",
                                    selection: $startDate,
                                    in: ...endDate,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.compact)
                                .padding(.horizontal, 16)
                                .accentColor(Color(hex: "#007AFF"))
                                .accessibilityLabel("Select start date for health data")

                                DatePicker(
                                    "End Date",
                                    selection: $endDate,
                                    in: startDate...Date(),
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.compact)
                                .padding(.horizontal, 16)
                                .accentColor(Color(hex: "#007AFF"))
                                .accessibilityLabel("Select end date for health data")

                                Button(action: {
                                    healthDataManager.refreshDataWithDateRange(startDate: startDate, endDate: endDate)
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showDatePicker = false
                                    }
                                    playHaptic()
                                    print("Date range applied: \(startDate.formatted()) to \(endDate.formatted())")
                                }) {
                                    Text("Apply Date Range")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(Color(hex: "#007AFF"))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                                }
                                .padding(.horizontal, 16)
                                .accessibilityLabel("Apply selected date range")
                            }
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                            .padding(.horizontal, 16)
                        }
                    }

                    // Main Content (Vertical Scroll)
                    if healthDataManager.isLoading {
                        ProgressView("Loading Apple Health data...")
                            .font(.system(size: 14))
                            .progressViewStyle(.circular)
                            .padding()
                            .accessibilityLabel("Loading health data")
                    } else if let error = healthDataManager.errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.orange)

                            Text(error)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Button(action: {
                                healthDataManager.refreshData()
                            }) {
                                Text("Retry")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 24)
                                    .background(Color(hex: "#007AFF"))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                        .accessibilityLabel("Error: \(error)")
                    } else {
                        ScrollView {
                            MetricSectionView(
                                metric: selectedMetric,
                                dataPoints: healthDataManager.getDataForMetric(selectedMetric),
                                hapticEngine: .constant(healthDataManager.hapticEngine)
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }

                Spacer(minLength: 16)
            }
        }
        .preferredColorScheme(.light)

        .onAppear {
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine failed: \(error)")
        }

        // Request authorization first
        if healthDataManager.authorizationStatus == "Not Requested" {
            requestHealthKitAuthorization()
        } else if healthDataManager.authorizationStatus == "Authorized" {
            isAuthorized = true
            healthDataManager.loadRealData()
        }
        }

        .alert("Health Access Required", isPresented: $showAuthorizationAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable Health data access in Settings to use this app.")
        }
    }

    private func requestHealthKitAuthorization() {
        healthDataManager.requestAuthorization { success in
            DispatchQueue.main.async {
                isAuthorized = success
                if success {
                    healthDataManager.loadRealData()
                } else {
                    showAuthorizationAlert = true
                }
            }
        }
    }

    private func requestHealthKitAuthorization() {
    healthDataManager.requestAuthorization { success in
        DispatchQueue.main.async {
            isAuthorized = success
            if success {
                healthDataManager.loadRealData()
            } else {
                showAuthorizationAlert = true
            }
        }
    }

    private func playHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let haptic = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        let pattern = try? CHHapticPattern(events: [haptic], parameters: [])
        let player = try? engine.makePlayer(with: pattern!)
        try? player?.start(atTime: 0)
    }
}

//Parameter Card View
struct ParameterCardView: View {
    let metric: HealthMetric
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: metric.icon)
                    .foregroundColor(getColor(for: metric))
                    .font(.system(size: 20))
                    .accessibilityHidden(true)

                Text(metric.displayName)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(getColor(for: metric))
                        .font(.system(size: 16))
                        .accessibilityHidden(true)
                }
            }
            .padding(12)
            .frame(width: 90, height: 100)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isSelected ? [Color.white, Color.white.opacity(0.9)] : [Color.white.opacity(0.7), Color.white.opacity(0.6)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(isSelected ? 0.2 : 0.1), radius: 5, x: 0, y: 3)
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(metric.displayName) parameter")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to view \(metric.displayName) data")
    }

    private func getColor(for metric: HealthMetric) -> Color {
        switch metric {
        case .heartRate: return Color(hex: "#FF3B30")
        case .tremor: return Color(hex: "#FF9500")
        case .walkingSpeed: return Color(hex: "#007AFF")
        case .balance: return Color(hex: "#34C759")
        case .walkingAsymmetry: return Color(hex: "#AF52DE")
        case .sleepDuration: return Color(hex: "#5856D6")
        case .remSleep: return Color(hex: "#00C7BE")
        case .respiratoryRate: return Color(hex: "#FF2D55")
        }
    }
}

//Metric Section View
struct MetricSectionView: View {
    let metric: HealthMetric
    let dataPoints: [HealthDataPoint]
    let hapticEngine: Binding<CHHapticEngine?>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: metric.icon)
                    .foregroundColor(getColor(for: metric))
                    .font(.system(size: 20))
                    .accessibilityHidden(true)

                Text(metric.displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)

                Spacer()

                if !dataPoints.isEmpty {
                    Image(systemName: getTrendIcon(for: metric))
                        .foregroundColor(getTrendColor(for: metric))
                        .font(.system(size: 18))
                        .accessibilityLabel("Trend: \(getTrendStatus(for: metric).rawValue)")
                }
            }

            // Chart
            MetricChartView(
                metric: metric,
                dataPoints: dataPoints,
                hapticEngine: hapticEngine
            )

            // Details
            MetricDetailsView(metric: metric, dataPoints: dataPoints)

            // Latest and Normal Range
            if !dataPoints.isEmpty {
                HStack {
                    Text("Latest: \(dataPoints.last?.formattedValue ?? "N/A")")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)

                    Spacer()

                    Text("Normal: \(String(format: "%.1f", metric.normalRange.lowerBound))–\(String(format: "%.1f", metric.normalRange.upperBound)) \(getChartConfiguration(for: metric).unit)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color.white.opacity(0.95)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.displayName) section with chart and details")
    }

    private func getColor(for metric: HealthMetric) -> Color {
        switch metric {
        case .heartRate: return Color(hex: "#FF3B30")
        case .tremor: return Color(hex: "#FF9500")
        case .walkingSpeed: return Color(hex: "#007AFF")
        case .balance: return Color(hex: "#34C759")
        case .walkingAsymmetry: return Color(hex: "#AF52DE")
        case .sleepDuration: return Color(hex: "#5856D6")
        case .remSleep: return Color(hex: "#00C7BE")
        case .respiratoryRate: return Color(hex: "#FF2D55")
        }
    }

    private func getTrendStatus(for metric: HealthMetric) -> TrendStatus {
        let data = dataPoints.sorted { $0.date < $1.date }
        guard data.count >= 2 else { return .stable }

        let recent = data.suffix(2).map { $0.value }
        let delta = recent.last! - recent.first!

        switch metric {
        case .heartRate, .respiratoryRate, .walkingAsymmetry, .tremor:
            return delta > 0 ? .worsening : (delta < 0 ? .improving : .stable)
        case .walkingSpeed, .balance, .sleepDuration, .remSleep:
            return delta > 0 ? .improving : (delta < 0 ? .worsening : .stable)
        }
    }

    private func getTrendIcon(for metric: HealthMetric) -> String {
        switch getTrendStatus(for: metric) {
        case .improving: return "arrow.up.circle.fill"
        case .stable: return "circle.fill"
        case .worsening: return "arrow.down.circle.fill"
        }
    }

    private func getTrendColor(for metric: HealthMetric) -> Color {
        switch getTrendStatus(for: metric) {
        case .improving: return Color(hex: "#34C759")
        case .stable: return Color(hex: "#007AFF")
        case .worsening: return Color(hex: "#FF9500")
        }
    }

    private func getChartConfiguration(for metric: HealthMetric) -> ChartConfiguration {
        switch metric {
        case .heartRate:
            return ChartConfiguration(
                title: "Heart Rate",
                unit: "bpm",
                color: Color(hex: "#FF3B30"),
                gradient: Gradient(colors: [Color(hex: "#FF3B30"), Color(hex: "#FF3B30").opacity(0.3)])
            )
        case .tremor:
            return ChartConfiguration(
                title: "Tremor",
                unit: "intensity",
                color: Color(hex: "#FF9500"),
                gradient: Gradient(colors: [Color(hex: "#FF9500"), Color(hex: "#FF9500").opacity(0.3)])
            )
        case .walkingSpeed:
            return ChartConfiguration(
                title: "Walking Speed",
                unit: "m/s",
                color: Color(hex: "#007AFF"),
                gradient: Gradient(colors: [Color(hex: "#007AFF"), Color(hex: "#007AFF").opacity(0.3)])
            )
        case .balance:
            return ChartConfiguration(
                title: "Balance",
                unit: "score",
                color: Color(hex: "#34C759"),
                gradient: Gradient(colors: [Color(hex: "#34C759"), Color(hex: "#34C759").opacity(0.3)])
            )
        case .walkingAsymmetry:
            return ChartConfiguration(
                title: "Walking Asymmetry",
                unit: "%",
                color: Color(hex: "#AF52DE"),
                gradient: Gradient(colors: [Color(hex: "#AF52DE"), Color(hex: "#AF52DE").opacity(0.3)])
            )
        case .sleepDuration:
            return ChartConfiguration(
                title: "Sleep Duration",
                unit: "hours",
                color: Color(hex: "#5856D6"),
                gradient: Gradient(colors: [Color(hex: "#5856D6"), Color(hex: "#5856D6").opacity(0.3)])
            )
        case .remSleep:
            return ChartConfiguration(
                title: "REM Sleep",
                unit: "hours",
                color: Color(hex: "#00C7BE"),
                gradient: Gradient(colors: [Color(hex: "#00C7BE"), Color(hex: "#00C7BE").opacity(0.3)])
            )
        case .respiratoryRate:
            return ChartConfiguration(
                title: "Respiratory Rate",
                unit: "breaths/min",
                color: Color(hex: "#FF2D55"),
                gradient: Gradient(colors: [Color(hex: "#FF2D55"), Color(hex: "#FF2D55").opacity(0.3)])
            )
        }
    }
}

// Metric Chart View
struct MetricChartView: View {
    let metric: HealthMetric
    let dataPoints: [HealthDataPoint]
    let hapticEngine: Binding<CHHapticEngine?>
    @State private var animationProgress: CGFloat = 0
    @State private var selectedDataPoint: HealthDataPoint?

    var body: some View {
        GeometryReader { geometry in
            if dataPoints.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))

                    Text("No data available")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)

                    Text("Make sure your Apple Watch is syncing data")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: 200, alignment: .center)
                .background(Color.white.opacity(0.95))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                .accessibilityLabel("No chart data for \(metric.displayName)")
            } else {
                ZStack {
                    Chart {
                        RectangleMark(
                            xStart: .value("Date", dataPoints.first!.date, unit: .day),
                            xEnd: .value("Date", dataPoints.last!.date, unit: .day),
                            yStart: .value("Normal Range", metric.normalRange.lowerBound),
                            yEnd: .value("Normal Range", metric.normalRange.upperBound)
                        )
                        .foregroundStyle(Color(.systemGray5).opacity(0.3))
                        .accessibilityLabel("Normal range for \(metric.displayName)")

                        ForEach(dataPoints) { dataPoint in
                            LineMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value(getChartConfiguration(for: metric).unit, dataPoint.value)
                            )
                            .foregroundStyle(getChartConfiguration(for: metric).color)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                            .opacity(animationProgress)
                        }

                        ForEach(dataPoints) { dataPoint in
                            PointMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value(getChartConfiguration(for: metric).unit, dataPoint.value)
                            )
                            .foregroundStyle(getChartConfiguration(for: metric).color)
                            .symbolSize(selectedDataPoint == dataPoint ? 80 : 50)
                            .annotation(position: .overlay, alignment: .center, spacing: 0) {
                                if selectedDataPoint == dataPoint {
                                    Circle()
                                        .fill(getChartConfiguration(for: metric).color.opacity(0.3))
                                        .frame(width: 16, height: 16)
                                        .scaleEffect(1.2)
                                        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: selectedDataPoint)
                                }
                            }
                            .opacity(animationProgress)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .chartYScale(domain: getYScaleRange(for: metric))
                    .chartXScale(domain: .automatic(includesZero: false))
                    .chartXAxis {
                        AxisMarks(preset: .aligned, position: .bottom) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                            AxisValueLabel()
                                .foregroundStyle(.gray)
                                .font(.system(size: 10, design: .rounded))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(preset: .aligned, position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                            AxisValueLabel()
                                .foregroundStyle(.gray)
                                .font(.system(size: 10, design: .rounded))
                        }
                    }
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                    .accessibilityLabel("\(metric.displayName) chart")
                    .accessibilityValue("Shows \(dataPoints.count) data points for \(metric.displayName)")
                    .onTapGesture { location in
                        let xPosition = location.x
                        let xRange = geometry.size.width
                        let index = min(Int((xPosition / xRange) * CGFloat(dataPoints.count)), dataPoints.count - 1)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedDataPoint = (selectedDataPoint == dataPoints[index]) ? nil : dataPoints[index]
                            if let engine = hapticEngine.wrappedValue {
                                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
                                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                                let haptic = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
                                let pattern = try? CHHapticPattern(events: [haptic], parameters: [])
                                let player = try? engine.makePlayer(with: pattern!)
                                try? player?.start(atTime: 0)
                            }
                        }
                        print("Tapped chart for \(metric.displayName) at index \(index)")
                    }

                    if let selectedPoint = selectedDataPoint {
                        GeometryReader { proxy in
                            let xPosition = proxy.frame(in: .local).midX * CGFloat(dataPoints.firstIndex(of: selectedPoint)! + 1) / CGFloat(dataPoints.count)
                            let yPosition = proxy.size.height * (1 - (CGFloat(selectedPoint.value - getYScaleRange(for: metric).lowerBound) / CGFloat(getYScaleRange(for: metric).upperBound - getYScaleRange(for: metric).lowerBound)))
                            VStack(alignment: .center, spacing: 4) {
                                Text("\(selectedPoint.formattedValue) \(getChartConfiguration(for: metric).unit)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(selectedPoint.formattedDate)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                Text(getPointContext(value: selectedPoint.value))
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(6)
