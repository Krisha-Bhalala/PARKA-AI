import Foundation
import HealthKit
import CoreHaptics

enum HealthMetric: String, CaseIterable, Identifiable {
    case heartRate = "Heart Rate"
    case tremor = "Tremor"
    case walkingSpeed = "Walking Speed"
    case balance = "Balance"
    case walkingAsymmetry = "Walking Asymmetry"
    case sleepDuration = "Sleep Duration"
    case remSleep = "REM Sleep"
    case respiratoryRate = "Respiratory Rate"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .tremor: return "waveform.path"
        case .walkingSpeed: return "figure.walk"
        case .balance: return "scalemass"
        case .walkingAsymmetry: return "arrow.left.arrow.right"
        case .sleepDuration: return "bed.double"
        case .remSleep: return "moon.zzz"
        case .respiratoryRate: return "lungs"
        }
    }

    var infoText: String {
        switch self {
        case .heartRate:
            return "Tracks heart rate variability from Apple Watch, reflecting cardiovascular health."
        case .tremor:
            return "Monitors hand or body tremors using Apple Watch sensors, key for Parkinson's tracking."
        case .walkingSpeed:
            return "Measures walking speed via Apple Watch, indicating mobility changes."
        case .balance:
            return "Assesses steadiness using Apple Watch motion data, crucial for coordination."
        case .walkingAsymmetry:
            return "Evaluates gait evenness from Apple Watch, highlighting balance issues."
        case .sleepDuration:
            return "Tracks total sleep time from Apple Watch, vital for energy and mood."
        case .remSleep:
            return "Monitors REM sleep duration via Apple Watch, linked to cognitive health."
        case .respiratoryRate:
            return "Measures breathing rate from Apple Watch, reflecting respiratory health."
        }
    }

    var normalRange: ClosedRange<Double> {
        switch self {
        case .heartRate: return 60...80
        case .tremor: return 0...1
        case .walkingSpeed: return 1.0...1.2
        case .balance: return 80...90
        case .walkingAsymmetry: return 0...5
        case .sleepDuration: return 7...8
        case .remSleep: return 1.5...2
        case .respiratoryRate: return 12...16
        }
    }

    // Map each metric to its HealthKit type
    var healthKitType: HKQuantityType? {
        switch self {
        case .heartRate:
            return HKQuantityType.quantityType(forIdentifier: .heartRate)
        case .tremor:
            return HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)
        case .walkingSpeed:
            return HKQuantityType.quantityType(forIdentifier: .walkingSpeed)
        case .balance:
            return HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)
        case .walkingAsymmetry:
            return HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage)
        case .sleepDuration:
            return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case .remSleep:
            return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case .respiratoryRate:
            return HKQuantityType.quantityType(forIdentifier: .respiratoryRate)
        }
    }
}

struct HealthDataPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
    let metric: HealthMetric

    var formattedValue: String {
        switch metric {
        case .heartRate, .respiratoryRate, .balance:
            return String(format: "%.1f", value)
        case .tremor, .walkingSpeed, .sleepDuration, .remSleep:
            return String(format: "%.2f", value)
        case .walkingAsymmetry:
            return String(format: "%.1f%%", value)
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    static func ==(lhs: HealthDataPoint, rhs: HealthDataPoint) -> Bool {
        lhs.id == rhs.id
    }
}

class HealthDataManager: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var dataPoints: [HealthMetric: [HealthDataPoint]] = [:]
    @Published var authorizationStatus: String = "Not Requested"

    var hapticEngine: CHHapticEngine?
    private let healthStore = HKHealthStore()

    init() {
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine failed: \(error)")
        }
    }

    // Authorization

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            authorizationStatus = "Not Available"
            completion(false)
            return
        }

        // Define the health data types we want to read
        let typesToRead: Set<HKObjectType> = Set(HealthMetric.allCases.compactMap { metric -> HKObjectType? in
            if metric == .sleepDuration || metric == .remSleep {
                return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
            } else {
                return metric.healthKitType
            }
        })

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.authorizationStatus = "Authorized"
                    completion(true)
                } else {
                    self?.authorizationStatus = "Denied"
                    self?.errorMessage = error?.localizedDescription ?? "Authorization failed"
                    completion(false)
                }
            }
        }
    }

    // Data Loading

    func loadRealData() {
        loadRealDataWithDateRange(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            endDate: Date()
        )
    }

    func refreshDataWithDateRange(startDate: Date, endDate: Date) {
        loadRealDataWithDateRange(startDate: startDate, endDate: endDate)
    }

    func loadRealDataWithDateRange(startDate: Date, endDate: Date) {
        isLoading = true
        errorMessage = nil
        dataPoints = [:]

        let group = DispatchGroup()

        for metric in HealthMetric.allCases {
            group.enter()

            if metric == .sleepDuration || metric == .remSleep {
                fetchSleepData(for: metric, startDate: startDate, endDate: endDate) { [weak self] points in
                    DispatchQueue.main.async {
                        self?.dataPoints[metric] = points
                        group.leave()
                    }
                }
            } else {
                fetchQuantityData(for: metric, startDate: startDate, endDate: endDate) { [weak self] points in
                    DispatchQueue.main.async {
                        self?.dataPoints[metric] = points
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            if self?.dataPoints.isEmpty == true {
                self?.errorMessage = "No health data found for the selected date range. Make sure your Apple Watch is syncing data."
            }
        }
    }

    // Fetch Quantity Data (Heart Rate, Walking Speed, etc.)

    private func fetchQuantityData(for metric: HealthMetric, startDate: Date, endDate: Date, completion: @escaping ([HealthDataPoint]) -> Void) {
        guard let quantityType = metric.healthKitType as? HKQuantityType else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in

            guard let samples = samples as? [HKQuantitySample], error == nil else {
                print("Error fetching \(metric.displayName): \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            let points = self.aggregateByDay(samples: samples, metric: metric)
            completion(points)
        }

        healthStore.execute(query)
    }

    // Fetch Sleep Data

    private func fetchSleepData(for metric: HealthMetric, startDate: Date, endDate: Date, completion: @escaping ([HealthDataPoint]) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in

            guard let samples = samples as? [HKCategorySample], error == nil else {
                print("Error fetching sleep data: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            let points = self.processSleepSamples(samples: samples, metric: metric, startDate: startDate, endDate: endDate)
            completion(points)
        }

        healthStore.execute(query)
    }

    // Data Processing

    private func aggregateByDay(samples: [HKQuantitySample], metric: HealthMetric) -> [HealthDataPoint] {
        let calendar = Calendar.current
        var dailyData: [Date: [Double]] = [:]

        // Get the appropriate unit for each metric
        let unit: HKUnit
        switch metric {
        case .heartRate:
            unit = HKUnit.count().unitDivided(by: .minute())
        case .walkingSpeed:
            unit = HKUnit.meter().unitDivided(by: .second())
        case .walkingAsymmetry:
            unit = .percent()
        case .respiratoryRate:
            unit = HKUnit.count().unitDivided(by: .minute())
        case .tremor, .balance:
            unit = .percent()
        default:
            unit = .count()
        }

        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            let value = sample.quantity.doubleValue(for: unit)
            dailyData[day, default: []].append(value)
        }

        return dailyData.map { date, values in
            let avgValue = values.reduce(0, +) / Double(values.count)
            return HealthDataPoint(date: date, value: avgValue, metric: metric)
        }.sorted { $0.date < $1.date }
    }

    private func processSleepSamples(samples: [HKCategorySample], metric: HealthMetric, startDate: Date, endDate: Date) -> [HealthDataPoint] {
        let calendar = Calendar.current
        var dailyData: [Date: Double] = [:]

        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0 // Convert to hours

            if metric == .sleepDuration {
                // Total sleep duration (all sleep stages)
                if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    dailyData[day, default: 0] += duration
                }
            } else if metric == .remSleep {
                // REM sleep only
                if sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    dailyData[day, default: 0] += duration
                }
            }
        }

        return dailyData.map { date, value in
            HealthDataPoint(date: date, value: value, metric: metric)
        }.sorted { $0.date < $1.date }
    }

    //Helper Methods

    func refreshData() {
        loadRealData()
    }

    func getDataForMetric(_ metric: HealthMetric) -> [HealthDataPoint] {
        dataPoints[metric] ?? []
    }

    func hasTrackingStreak() -> Bool {
        dataPoints.count >= HealthMetric.allCases.count && dataPoints.allSatisfy { $0.value.count >= 7 }
    }
}
