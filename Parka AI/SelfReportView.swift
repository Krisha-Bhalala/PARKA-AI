import SwiftUI
import UserNotifications

struct SelfReportView: View {
    @ObservedObject private var logStore = MedicationLogStore.shared
    @State private var newMedicationName = ""
    @State private var newMedicationTime = Date()
    @State private var moodText = ""
    @State private var selectedMood: Int?
    @State private var showConfirmation = false
    @State private var streakCount = UserDefaults.standard.integer(forKey: "streakCount")
    @State private var activeTab: Tab = .mood
    @State private var showHistory = false
    @State private var pulseAnimation = false
    @State private var selectedMoodScale = 1.0
    @State private var confirmationMessage = ""
    @State private var showSuccessMessage = false
    @Environment(\.dismiss) private var dismiss
    
    enum Tab { case mood, medication }
    
    private let primaryGreen = Color(red: 0.20, green: 0.70, blue: 0.35)
    private let accentGreen = Color(red: 0.15, green: 0.60, blue: 0.30)
    private let lightGreen = Color(red: 0.95, green: 0.98, blue: 0.96)
    private let darkGreen = Color(red: 0.13, green: 0.54, blue: 0.25)
    
    private let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.99, blue: 0.99),
            Color(red: 0.97, green: 0.99, blue: 0.97)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let moodOptions = [
        (icon: "😊", name: "Excellent", color: Color(red: 0.20, green: 0.70, blue: 0.35)),
        (icon: "🙂", name: "Good", color: Color(red: 0.35, green: 0.75, blue: 0.50)),
        (icon: "😐", name: "Neutral", color: Color(red: 0.55, green: 0.65, blue: 0.60)),
        (icon: "😕", name: "Challenging", color: Color(red: 0.85, green: 0.60, blue: 0.30)),
        (icon: "😞", name: "Difficult", color: Color(red: 0.85, green: 0.45, blue: 0.40))
    ]
    
    private let successMessages = [
        "Progress recorded successfully",
        "Your consistency is building strength",
        "Well done on maintaining your routine",
        "Another step toward better health"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    headerView
                    streakDisplayView
                    tabSelector
                    Spacer()
                    ScrollView {
                        if activeTab == .mood {
                            moodTrackingContent
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        } else {
                            medicationTrackingContent
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showHistory) {
                HealthHistoryView(selectedTab: activeTab == .mood ? .mood : .medication)
            }
            .alert("Entry Saved", isPresented: $showConfirmation) {
                Button("Continue") {
                    showSuccessMessage = true
                    confirmationMessage = successMessages.randomElement() ?? ""
                }
            } message: {
                Text("Your health data has been recorded.")
            }
            .overlay(
                successMessageOverlay
            )
        }
        .onAppear {
            pulseAnimation.toggle()
            // Generate daily entries when view appears
            logStore.generateDailyMedicationEntries()
        }
    }
    
    private var successMessageOverlay: some View {
        VStack {
            if showSuccessMessage {
                Text(confirmationMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(primaryGreen)
                            .shadow(color: primaryGreen.opacity(0.25), radius: 6)
                    )
                    .scaleEffect(showSuccessMessage ? 1.0 : 0.8)
                    .opacity(showSuccessMessage ? 1.0 : 0.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSuccessMessage)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showSuccessMessage = false
                        }
                    }
            }
            Spacer()
        }
        .padding(.top, 80)
    }
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.blue)
                    .padding(.trailing, 8)
            }
            
            VStack(alignment: .center, spacing: 2) {
                Text("Daily Assessment")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            Button(action: { showHistory = true }) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 4)
                    )
            }
        }
    }
    
    private var streakDisplayView: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(primaryGreen)
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Current Streak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                
                Text("\(streakCount) days")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            if streakCount > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Keep going!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(primaryGreen)
                    
                    Text("Stay consistent")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.black.opacity(0.6))
                }
            }
        }
        .padding(.top, 30)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach([Tab.mood, Tab.medication], id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        activeTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab == .mood ? "heart.fill" : "cross.case.fill")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text(tab == .mood ? "Mood" : "Medication")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(activeTab == tab ? .white : accentGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(activeTab == tab ? primaryGreen : Color.clear)
                            .shadow(color: activeTab == tab ? primaryGreen.opacity(0.2) : .clear, radius: 4)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 6)
        )
    }
    
    private var moodTrackingContent: some View {
        VStack(spacing: 16) {
            moodTrackingHeader
            moodSelectionButtons
            moodNotesSection
            recordMoodButton
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 8)
        )
        .padding(.bottom, 20)
    }
    
    private var moodTrackingHeader: some View {
        VStack(spacing: 8) {
            Text("How are you feeling today?")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            Text("Select your current mood to track your wellness")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.black.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
    
    private var moodSelectionButtons: some View {
        HStack(spacing: 8) {
            ForEach(0..<moodOptions.count, id: \.self) { index in
                moodButton(for: index)
            }
        }
    }
    
    private func moodButton(for index: Int) -> some View {
        Button(action: {
            selectedMood = index
            
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                selectedMoodScale = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    selectedMoodScale = 1.0
                }
            }
        }) {
            VStack(spacing: 4) {
                Text(moodOptions[index].icon)
                    .font(.system(size: 20))
                    .scaleEffect(selectedMood == index ? selectedMoodScale : 1.0)
                
                Text(moodOptions[index].name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(selectedMood == index ? .white : .black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedMood == index ? moodOptions[index].color : Color.white)
                    .shadow(
                        color: selectedMood == index ? moodOptions[index].color.opacity(0.25) : .clear,
                        radius: selectedMood == index ? 6 : 0
                    )
            )
            .scaleEffect(selectedMood == index ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private var moodNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional Notes")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)
            
            TextField("Optional: Add context or details about your mood", text: $moodText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.04), radius: 4)
                )
                .font(.system(size: 14))
                .foregroundColor(.black)
                .lineLimit(2...4)
        }
    }
    
    private var recordMoodButton: some View {
        Button(action: saveMood) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Record Mood Entry")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(selectedMood != nil ? .white : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedMood != nil ? primaryGreen : lightGreen)
                    .shadow(color: selectedMood != nil ? primaryGreen.opacity(0.2) : .clear, radius: 4)
            )
            .scaleEffect(selectedMood != nil ? 1.0 : 0.98)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: selectedMood != nil)
        }
        .disabled(selectedMood == nil)
        .buttonStyle(.plain)
    }
    
    private var medicationTrackingContent: some View {
        VStack(spacing: 16) {
            medicationTrackingHeader
            medicationInputSection
            
            if !logStore.scheduledMedications.isEmpty {
                medicationListSection
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 8)
        )
        .padding(.bottom, 20)
    }
    
    private var medicationTrackingHeader: some View {
        VStack(spacing: 8) {
            Text("Medication Schedule")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            Text("Set start date and daily time for medication tracking")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.black.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
    
    private var medicationInputSection: some View {
        VStack(spacing: 16) {
            // Medication Name Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(primaryGreen)
                    
                    Text("Medication Name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                TextField("Enter medication name", text: $newMedicationName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                    )
            }
            
            // Date and Time Row
            HStack(spacing: 12) {
                // Start Date
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(primaryGreen)
                        
                        Text("Start Date")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    DatePicker("", selection: $newMedicationTime, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accentColor(primaryGreen)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.gray.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
                
                // Daily Time
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(primaryGreen)
                        
                        Text("Daily Time")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    DatePicker("", selection: $newMedicationTime, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accentColor(primaryGreen)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.gray.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
            }
            
            // Add Button
            addMedicationButton
                .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
    
    private var addMedicationButton: some View {
        Button(action: addMedication) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Add to Schedule")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(newMedicationName.isEmpty ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(newMedicationName.isEmpty ? lightGreen : primaryGreen)
                    .shadow(color: newMedicationName.isEmpty ? .clear : primaryGreen.opacity(0.2), radius: 4)
            )
        }
        .disabled(newMedicationName.isEmpty)
        .buttonStyle(.plain)
    }
    
    private var medicationListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scheduled Medications")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)
            
            ForEach(logStore.scheduledMedications.filter { $0.isActive }) { medication in
                scheduledMedicationRow(for: medication)
            }
        }
    }
    
    private func scheduledMedicationRow(for medication: Medication) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 16))
                .foregroundColor(accentGreen)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(lightGreen)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)

                HStack(spacing: 6) {
                    Text("Daily at \(medication.scheduledTime.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.7))
                }
            }

            Spacer()

            // Show today's status for this medication
            if let todaysEntry = getTodaysEntry(for: medication) {
                HStack(spacing: 4) {
                    Image(systemName: todaysEntry.taken == true ? "checkmark.circle.fill" :
                                      todaysEntry.taken == false ? "xmark.circle.fill" : "clock.circle")
                        .font(.system(size: 16))
                        .foregroundColor(todaysEntry.taken == true ? primaryGreen :
                                       todaysEntry.taken == false ? .red : .orange)
                    
                    Text(todaysEntry.taken == true ? "Taken" :
                         todaysEntry.taken == false ? "Missed" : "Pending")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(todaysEntry.taken == true ? primaryGreen :
                                       todaysEntry.taken == false ? .red : .orange)
                }
            }

            Button(action: {
                withAnimation {
                    logStore.removeScheduledMedication(medicationId: medication.id)
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 4)
        )
    }
    
    private func getTodaysEntry(for medication: Medication) -> MedicationEntry? {
        let calendar = Calendar.current
        let today = Date()
        
        return logStore.medicationEntries.first { entry in
            entry.medicationId == medication.id &&
            calendar.isDate(entry.scheduledDateTime, inSameDayAs: today)
        }
    }

    private func saveMood() {
        guard let index = selectedMood else { return }
        let moodName = moodOptions[index].name
        let fullMood = moodText.isEmpty ? moodName : "\(moodName): \(moodText)"
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        logStore.addMoodLog(mood: fullMood, date: Date())
        updateStreak()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedMood = nil
            moodText = ""
        }
        
        showConfirmation = true
    }
    
    private func addMedication() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Add to scheduled medications (this will automatically generate daily entries)
        logStore.addScheduledMedication(name: newMedicationName, scheduledTime: newMedicationTime)
        updateStreak()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            newMedicationName = ""
            newMedicationTime = Date()
        }
        
        showConfirmation = true
    }
    
    private func updateStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastLogDate = UserDefaults.standard.object(forKey: "lastLogDate") as? Date
        let lastLogStartOfDay = lastLogDate != nil ? Calendar.current.startOfDay(for: lastLogDate!) : nil
        
        if lastLogStartOfDay == today {
            return
        } else if lastLogStartOfDay == Calendar.current.date(byAdding: .day, value: -1, to: today) {
            streakCount += 1
        } else {
            streakCount = 1
        }
        
        UserDefaults.standard.set(today, forKey: "lastLogDate")
        UserDefaults.standard.set(streakCount, forKey: "streakCount")
        UserDefaults.standard.synchronize()
    }
}
