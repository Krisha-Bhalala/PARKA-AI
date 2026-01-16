import SwiftUI

private let primaryGreen = Color(red: 0.20, green: 0.70, blue: 0.35)
private let accentGreen = Color(red: 0.15, green: 0.60, blue: 0.30)

struct HealthHistoryView: View {
    @ObservedObject private var logStore = MedicationLogStore.shared
    let selectedTab: TabType

    enum TabType { case mood, medication }

    // Modern, neutral color palette
    private let offWhite = Color(red: 0.95, green: 0.95, blue: 0.97)
    private let deepIndigo = Color(red: 0.15, green: 0.2, blue: 0.4)
    private let whiteCard = Color.white
    private let alertRed = Color(red: 0.9, green: 0.4, blue: 0.4)
    private let successGreen = Color(red: 0.2, green: 0.7, blue: 0.4)
    private let textBlack = Color.black

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [offWhite, offWhite.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Text(selectedTab == .mood ? "Mood History" : "Medication History")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(textBlack)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)

                ScrollView {
                    VStack(spacing: 16) {
                        if selectedTab == .mood {
                            if logStore.moodLogs.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(logStore.moodLogs.sorted(by: { $0.date > $1.date })) { log in
                                    moodCard(log: log)
                                }
                            }
                        } else {
                            if logStore.getTodaysEntries().isEmpty {
                                emptyStateView
                            } else {
                                ForEach(logStore.getTodaysEntries().sorted(by: { $0.scheduledDateTime < $1.scheduledDateTime })) { entry in
                                    medicationCard(entry: entry)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Generate entries for scheduled medications when view appears
            logStore.generateDailyMedicationEntries()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("Nothing here yet!")
                .font(.title3)
                .foregroundColor(textBlack)
            Text("Add scheduled medications to see daily tracking entries here.")
                .font(.body)
                .foregroundColor(textBlack.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private func moodCard(log: MoodLog) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.mood)
                    .font(.headline)
                    .foregroundColor(textBlack)

                Text(log.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(textBlack.opacity(0.6))
            }

            Spacer()

            Button(action: { deleteMoodLog(log) }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18))
                    .foregroundColor(alertRed)
            }
        }
        .padding(16)
        .background(whiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
    }

    private func medicationCard(entry: MedicationEntry) -> some View {
        HStack(spacing: 16) {
            // Checkbox for medication status
            Button(action: { toggleMedicationStatus(entry) }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(getCheckboxColor(for: entry.taken), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(entry.taken == true ? successGreen.opacity(0.1) : Color.clear)
                        )
                    
                    if entry.taken == true {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(successGreen)
                    } else if entry.taken == false {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(alertRed)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.medicationName)
                    .font(.headline)
                    .foregroundColor(textBlack)

                // Scheduled date and time
                VStack(alignment: .leading, spacing: 2) {
                    Text("at \(entry.scheduledDateTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(textBlack.opacity(0.7))
                    
                    // Status
                    HStack(spacing: 8) {
                        Circle()
                            .frame(width: 4, height: 4)
                            .foregroundColor(textBlack.opacity(0.4))
                        
                        Text(getStatusText(for: entry.taken))
                            .foregroundColor(getStatusColor(for: entry.taken))
                    }
                    .font(.subheadline)
                }
            }

            Spacer()

            // Show if entry is overdue
            if entry.isOverdue && entry.taken != true {
                VStack {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 16))
                        .foregroundColor(alertRed)
                    Text("Overdue")
                        .font(.caption2)
                        .foregroundColor(alertRed)
                }
            }
        }
        .padding(16)
        .background(whiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
    
    private func getCheckboxColor(for taken: Bool?) -> Color {
        switch taken {
        case .some(true):
            return successGreen
        case .some(false):
            return alertRed
        case .none:
            return textBlack.opacity(0.3)
        }
    }
    
    private func getStatusText(for taken: Bool?) -> String {
        switch taken {
        case .some(true):
            return "Taken"
        case .some(false):
            return "Missed"
        case .none:
            return "Pending"
        }
    }
    
    private func getStatusColor(for taken: Bool?) -> Color {
        switch taken {
        case .some(true):
            return successGreen
        case .some(false):
            return alertRed
        case .none:
            return textBlack.opacity(0.5)
        }
    }

    private func toggleMedicationStatus(_ entry: MedicationEntry) {
        withAnimation(.easeInOut(duration: 0.2)) {
            logStore.updateMedicationEntryStatus(entryId: entry.id)
        }
    }

    private func deleteMoodLog(_ log: MoodLog) {
        withAnimation(.easeInOut(duration: 0.3)) {
            logStore.moodLogs.removeAll { $0.id == log.id }
        }
    }
}

// MARK: - Data Models
struct Medication: Identifiable {
    let id = UUID()
    let name: String
    let scheduledTime: Date // Time when medication should be taken daily
    var isActive: Bool = true // Whether this medication is currently being tracked
}

struct MedicationEntry: Identifiable {
    let id = UUID()
    let medicationId: UUID
    let medicationName: String
    let scheduledDateTime: Date // Specific date and time for this entry
    var taken: Bool? // nil = pending, true = taken, false = missed
    
    var isOverdue: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(scheduledDateTime) && scheduledDateTime < Date() && taken != true
    }
}

struct MoodLog: Identifiable {
    let id = UUID()
    let mood: String
    let date: Date
}

class MedicationLogStore: ObservableObject {
    static let shared = MedicationLogStore()
    @Published var scheduledMedications: [Medication] = []
    @Published var medicationEntries: [MedicationEntry] = []
    @Published var moodLogs: [MoodLog] = []
    
    private init() {
        // Generate entries when store is initialized
        generateDailyMedicationEntries()
    }

    // Add a new scheduled medication
    func addScheduledMedication(name: String, scheduledTime: Date) {
        let medication = Medication(name: name, scheduledTime: scheduledTime)
        scheduledMedications.append(medication)
        generateDailyMedicationEntries()
    }
    
    // Generate daily entries for scheduled medications - only today
    func generateDailyMedicationEntries() {
        let calendar = Calendar.current
        let today = Date()
        
        // Remove yesterday's entries to keep the list clean
        removeYesterdaysEntries()
        
        // Generate entries for today only
        for medication in scheduledMedications where medication.isActive {
            // Only generate entries if the medication start date is today or before
            if calendar.startOfDay(for: medication.scheduledTime) <= calendar.startOfDay(for: today) {
                // Create scheduled date and time for this medication
                let scheduledComponents = calendar.dateComponents([.hour, .minute], from: medication.scheduledTime)
                let targetComponents = calendar.dateComponents([.year, .month, .day], from: today)
                
                var combinedComponents = DateComponents()
                combinedComponents.year = targetComponents.year
                combinedComponents.month = targetComponents.month
                combinedComponents.day = targetComponents.day
                combinedComponents.hour = scheduledComponents.hour
                combinedComponents.minute = scheduledComponents.minute
                
                guard let scheduledDateTime = calendar.date(from: combinedComponents) else { continue }
                
                // Check if entry already exists for this medication and date
                let entryExists = medicationEntries.contains { entry in
                    entry.medicationId == medication.id &&
                    calendar.isDate(entry.scheduledDateTime, inSameDayAs: scheduledDateTime)
                }
                
                if !entryExists {
                    let newEntry = MedicationEntry(
                        medicationId: medication.id,
                        medicationName: medication.name,
                        scheduledDateTime: scheduledDateTime,
                        taken: nil
                    )
                    medicationEntries.append(newEntry)
                }
            }
        }
    }
    
    // Remove yesterday's entries to keep the list focused
    private func removeYesterdaysEntries() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        medicationEntries.removeAll { entry in
            calendar.isDate(entry.scheduledDateTime, inSameDayAs: yesterday) ||
            entry.scheduledDateTime < calendar.startOfDay(for: yesterday)
        }
    }
    
    // Get today's medication entries only
    func getTodaysEntries() -> [MedicationEntry] {
        let calendar = Calendar.current
        let today = Date()
        
        return medicationEntries.filter { entry in
            calendar.isDate(entry.scheduledDateTime, inSameDayAs: today)
        }
    }
    
    // Update medication entry status
    func updateMedicationEntryStatus(entryId: UUID) {
        if let index = medicationEntries.firstIndex(where: { $0.id == entryId }) {
            switch medicationEntries[index].taken {
            case .none:
                medicationEntries[index].taken = true
            case .some(true):
                medicationEntries[index].taken = false
            case .some(false):
                medicationEntries[index].taken = true
            }
        }
    }
    
    // Remove a scheduled medication and all its entries
    func removeScheduledMedication(medicationId: UUID) {
        scheduledMedications.removeAll { $0.id == medicationId }
        medicationEntries.removeAll { $0.medicationId == medicationId }
    }

    func addMoodLog(mood: String, date: Date) {
        let newLog = MoodLog(
            mood: mood,
            date: date
        )
        moodLogs.append(newLog)
    }
}
