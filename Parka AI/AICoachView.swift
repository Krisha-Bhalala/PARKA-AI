import SwiftUI
import PDFKit
import UIKit

//Data Models
struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

//Main View
struct AICoachView: View {
    @State private var userInput: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var conversationHistory: [[String: String]] = []
    @State private var showingPDFPreview = false
    @State private var generatedPDFData: Data?
    @State private var pdfErrorMessage: String?
    @State private var editableReportContent: String = ""
    @State private var showPDFSavedConfirmation = false
    @State private var showClearChatAlert = false
    @State private var showIntro: Bool = true
    @State private var promptOffset: CGFloat = 0
    @State private var isUserInteractingWithScroll = false
    @State private var animationTask: Task<Void, Never>?

    // Color palette: inspired by Grok's clean and modern aesthetic
    private let primaryColor = Color(.sRGB, red: 0.20, green: 0.67, blue: 0.86, opacity: 1.0)
    private let secondaryColor = Color(.sRGB, red: 0.22, green: 0.24, blue: 0.27, opacity: 1.0)
    private let backgroundColor = Color(.sRGB, red: 0.95, green: 0.96, blue: 0.97, opacity: 1.0)
    private let cardColor = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)
    private let shadowColor = Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 0.1)
    private let quickPrompts = [
        ("Doctor's Report", "Provide a concise report for my physician"),
        ("Symptom Trends", "Analyze recent motor symptom changes"),
        ("Medication Impact", "Evaluate my medication effectiveness"),
        ("Sleep Insights", "Assess my weekly sleep quality"),
        ("Daily Patterns", "Examine daily symptom variations"),
        ("Exercise Effects", "Explore exercise benefits for my condition")
    ]

    // Mock health data
    private let healthData: [String: [[String: Any]]] = {
        let calendar = Calendar.current
        let today = Date()
        let dates = (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        return [
            "heartRate": dates.flatMap { date in
                [
                    ["date": date, "value": Double.random(in: 62...68), "unit": "bpm"],
                    ["date": date, "value": Double.random(in: 70...78), "unit": "bpm"],
                    ["date": date, "value": Double.random(in: 80...88), "unit": "bpm"]
                ]
            },
            "walkingSpeed": dates.enumerated().map { (index, date) in
                ["date": date, "value": [0.65, 0.72, 0.68, 0.75, 0.62, 0.70, 0.78][index], "unit": "m/s"]
            },
            "mood": dates.enumerated().map { (index, date) in
                ["date": date, "value": ["Stable", "Low", "Anxious", "Stable", "Low", "Stable", "Elevated"][index], "unit": ""]
            },
            "medicationAdherence": dates.enumerated().map { (index, date) in
                ["date": date, "value": index == 2 || index == 5 ? 0 : 1, "unit": "doses taken"]
            }
        ]
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                VStack(spacing: 8) {
                    if showIntro {
                        initialGreetingView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity.animation(.easeOut(duration: 0.5)))
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(conversationHistory.enumerated()), id: \.offset) { index, message in
                                        messageView(for: message)
                                            .id("message-\(index)")
                                            .transition(.opacity.animation(.easeIn(duration: 0.3)))
                                    }
                                    if isLoading {
                                        loadingView
                                            .id("loading")
                                    }
                                    Color.clear.frame(height: 20)
                                        .id("bottom")
                                }
                                .padding(.horizontal, 8)
                                .padding(.top, 8)
                                .scrollDismissesKeyboard(.interactively)
                            }
                            .onChange(of: conversationHistory.count) { _ in
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                            .onChange(of: isLoading) { newValue in
                                if !newValue {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        quickPromptsView
                        inputAreaView
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(cardColor)
                    .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
                }
                .padding(.bottom, 4)
                if let errorMessage = errorMessage {
                    errorMessageView(errorMessage)
                }
                if let pdfErrorMessage = pdfErrorMessage {
                    errorMessageView(pdfErrorMessage)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("AI Health Coach")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showClearChatAlert = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(primaryColor)
                    }
                    .scaleEffectAnimation()
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .alert("Clear Conversation?", isPresented: $showClearChatAlert) {
                Button("Clear", role: .destructive) {
                    conversationHistory.removeAll()
                    userInput = ""
                    errorMessage = nil
                    pdfErrorMessage = nil
                    showIntro = true
                    isUserInteractingWithScroll = false
                    promptOffset = 0
                    animationTask?.cancel()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action will remove all messages.")
            }
            .sheet(isPresented: $showingPDFPreview) {
                if let pdfData = generatedPDFData {
                    PDFPreviewView(
                        pdfData: pdfData,
                        editableContent: $editableReportContent,
                        onSave: { updatedContent in
                            generatePDFReport(content: updatedContent)
                        }
                    )
                } else {
                    PDFErrorView {
                        showingPDFPreview = false
                    }
                }
            }
            .overlay(showPDFSavedConfirmation ? saveConfirmationView : nil)
            .onChange(of: conversationHistory) { _ in
                withAnimation { showIntro = conversationHistory.isEmpty }
            }
            .onAppear { startPromptAnimation() }
            .onChange(of: isUserInteractingWithScroll) { newValue in
                if newValue {
                    animationTask?.cancel()
                    withAnimation { promptOffset = 0 }
                } else {
                    startPromptAnimation()
                }
            }
        }
    }

    func startPromptAnimation() {
        animationTask = Task {
            var direction: CGFloat = 10
            while !isUserInteractingWithScroll {
                withAnimation(.linear(duration: 2)) {
                    promptOffset = direction
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                direction = -direction
            }
        }
    }



    //View Components
    private var initialGreetingView: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36))
                .foregroundColor(primaryColor)
            Text("Welcome to AI Health Coach")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
            Text("I'm here to assist with your Parkinson’s care. Try a prompt or ask away!")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.black.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    private func messageView(for message: [String: String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message["role"] == "user" {
                Spacer()
                Text(message["content"] ?? "")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.black)
                    .padding(10)
                    .background(cardColor)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(secondaryColor.opacity(0.2), lineWidth: 1))
                    .shadow(color: shadowColor, radius: 1, x: 0, y: 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 280, alignment: .trailing)
                    .padding(.leading, 32)
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundColor(primaryColor)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 6) {
                    Text(message["content"] ?? "")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.black)
                        .padding(10)
                        .background(cardColor)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(primaryColor.opacity(0.2), lineWidth: 1))
                        .shadow(color: shadowColor, radius: 1, x: 0, y: 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 280, alignment: .leading)
                    if shouldShowDisclaimer(for: message["content"] ?? "") {
                        disclaimerView
                    }
                    if shouldHelpPrompt() {
                        helpPromptView
                    }
                    if shouldShowPDFOptions(for: message["content"] ?? "") {
                        reportOptionsView
                    }
                }
                .padding(.trailing, 32)
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    private var disclaimerView: some View {
        Text("This information is for guidance only. Always consult your physician for medical advice.")
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(.black.opacity(0.6))
            .padding(.top, 2)
    }

    private var helpPromptView: some View {
        Text("Would you like help with Parkinson’s care or health data insights?")
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(primaryColor)
            .padding(.top, 2)
    }

    private var reportOptionsView: some View {
        HStack(spacing: 8) {
            Button(action: {
                editableReportContent = cleanContent(conversationHistory.last?["content"] ?? createHealthDataSummary())
                generatePDFReport(content: editableReportContent)
            }) {
                Label("Preview Report", systemImage: "eye.fill")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(primaryColor)
                    .cornerRadius(8)
            }
            .scaleEffectAnimation()
            Button(action: {
                editableReportContent = cleanContent(conversationHistory.last?["content"] ?? createHealthDataSummary())
                savePDF(content: editableReportContent)
            }) {
                Label("Save Report", systemImage: "arrow.down.doc.fill")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(primaryColor)
                    .cornerRadius(8)
            }
            .scaleEffectAnimation()
        }
        .padding(.top, 6)
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .tint(primaryColor)
            Text("Analyzing...")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.black.opacity(0.7))
        }
        .padding(10)
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: shadowColor, radius: 1, x: 0, y: 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorMessageView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.black)
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private var quickPromptsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPrompts, id: \.0) { prompt in
                    Button(action: {
                        userInput = prompt.1
                        Task { await sendMessage() }
                    }) {
                        Text(prompt.0)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(secondaryColor)
                            .cornerRadius(10)
                    }
                    .scaleEffectAnimation()
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .offset(x: isUserInteractingWithScroll ? 0 : promptOffset)
        }
        .frame(height: 44)
        .padding(.horizontal, 4)
        .gesture(
            DragGesture()
                .onChanged { _ in isUserInteractingWithScroll = true }
                .onEnded { _ in isUserInteractingWithScroll = false }
        )
    }

    private var inputAreaView: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                if userInput.isEmpty {
                    Text("Ask a question...")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.black.opacity(0.5))
                        .padding(.leading, 12)
                        .padding(.vertical, 10)
                }
                TextField("", text: $userInput, axis: .vertical)
                    .font(.system(size: 15, design: .rounded))
                    .textFieldStyle(.plain)
                    .foregroundColor(.black)
                    .padding(10)
                    .background(cardColor)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(secondaryColor.opacity(0.2), lineWidth: 1))
                    .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
                    .disabled(isLoading)
            }
            Button(action: { Task { await sendMessage() } }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(primaryColor)
                    .clipShape(Circle())
            }
            .disabled(userInput.isEmpty || isLoading)
            .scaleEffectAnimation()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }

    private var saveConfirmationView: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(primaryColor)
                    .font(.system(size: 16))
                Text("Report saved")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.black)
            }
            .padding(10)
            .background(cardColor)
            .cornerRadius(8)
            .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
            .transition(.move(edge: .bottom))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showPDFSavedConfirmation = false }
                }
            }
        }
        .padding(.bottom, 12)
    }

    //Core Functions
    private func sendMessage() async {
        guard !userInput.isEmpty else { return }
        let currentInput = userInput
        userInput = ""
        isLoading = true
        errorMessage = nil
        pdfErrorMessage = nil
        conversationHistory.append(["role": "user", "content": currentInput])
        guard let apiKey = getAPIKey() else {
            await MainActor.run {
                errorMessage = "Unable to find API key"
                isLoading = false
            }
            return
        }
        await fetchGeminiResponse(apiKey: apiKey, userMessage: currentInput)
    }

    private func getAPIKey() -> String? {
        guard let path = Bundle.main.path(forResource: "APIConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["GeminiAPIKey"] as? String else {
            return nil
        }
        return key
    }

    private func fetchGeminiResponse(apiKey: String, userMessage: String) async {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=\(apiKey)") else {
            await setError("Invalid API URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let healthDataSummary = createHealthDataSummary()
        let prompt = createPrompt(userMessage: userMessage, healthData: healthDataSummary)
        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["maxOutputTokens": 200, "temperature": 0.4]
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                await setError("No response from server")
                return
            }
            if httpResponse.statusCode == 200 {
                await handleSuccessResponse(data)
            } else {
                await setError("Request failed with code: \(httpResponse.statusCode)")
            }
        } catch {
            await setError("Connection error: \(error.localizedDescription)")
        }
    }

    private func handleSuccessResponse(_ data: Data) async {
        do {
            let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
            if let content = response.candidates.first?.content.parts.first?.text {
                let cleanContent = cleanContent(content.trimmingCharacters(in: .whitespacesAndNewlines))
                await MainActor.run {
                    conversationHistory.append(["role": "assistant", "content": cleanContent])
                    isLoading = false
                }
            } else {
                await setError("No content in response")
            }
        } catch {
            await setError("Failed to process response")
        }
    }

    private func setError(_ message: String) async {
        await MainActor.run {
            errorMessage = message
            isLoading = false
        }
    }

    private func cleanContent(_ content: String) -> String {
        content
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    //Health Data Processing
    private func createHealthDataSummary() -> String {
        var summary = "Parkinson’s Health Report\nGenerated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))\n\n"
        let metrics: [(name: String, key: String, unit: String, format: String)] = [
            ("Heart Rate", "heartRate", "bpm", "%.0f"),
            ("Walking Speed", "walkingSpeed", "m/s", "%.2f")
        ]
        for metric in metrics {
            if let data = healthData[metric.key] as? [[String: Any]], !data.isEmpty {
                let values = data.compactMap { $0["value"] as? Double }
                let avg = values.reduce(0, +) / Double(values.count)
                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 0
                summary += "\(metric.name):\n"
                summary += "  Average: \(String(format: metric.format, avg)) \(metric.unit)\n"
                summary += "  Range: \(String(format: metric.format, minVal))-\(String(format: metric.format, maxVal)) \(metric.unit)\n\n"
            }
        }
        if let moodData = healthData["mood"] as? [[String: Any]], !moodData.isEmpty {
            summary += "Mood (Last 7 Days):\n"
            for (index, mood) in moodData.enumerated() {
                let date = mood["date"] as? Date ?? Date()
                let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
                let moodValue = mood["value"] as? String ?? "Unknown"
                summary += "  \(dateString): \(moodValue)\n"
            }
            summary += "\n"
        }
        if let medData = healthData["medicationAdherence"] as? [[String: Any]], !medData.isEmpty {
            let adherenceValues = medData.compactMap { $0["value"] as? Int }
            let missedDoses = adherenceValues.filter { $0 == 0 }.count
            summary += "Medication Adherence:\n"
            summary += "  Doses Missed: \(missedDoses) out of \(adherenceValues.count)\n"
            for (index, adherence) in adherenceValues.enumerated() {
                if adherence == 0 {
                    let date = medData[index]["date"] as? Date ?? Date()
                    let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
                    summary += "  Missed on: \(dateString)\n"
                }
            }
            summary += "\n"
        }
        summary += "Source: Apple Watch\n"
        return summary
    }

    private func createPrompt(userMessage: String, healthData: String) -> String {
        let msg = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isGreeting = ["hi", "hello", "hey", "how are you", "how r u", "hi how are you"].contains(msg)
        let isGeneral = msg.contains("weather") || msg.contains("news") || msg.contains("time") || msg.contains("joke")
        let isReport = msg.contains("report") || msg.contains("physician") || msg.contains("doctor") || msg.contains("summary")
        if isGreeting {
            return """
            System: You are an empathetic AI Health Coach for Parkinson’s users.
            When the user greets you, reply with:
            • One warm, friendly sentence (15‑20 words max).
            • One short follow‑up question inviting them to share what they need.
            Do NOT mention Parkinson’s unless the user does.
            End with: “How can I help you today?”
            """
        }
        if isGeneral {
            return """
            System: You are an AI Health Coach who can also answer everyday questions.
            Reply format:
            1. Direct answer (1–2 sentences).
            2. Brief extra context (1–2 sentences) to build trust.
            3. Invite further health questions in one sentence.
            4. Close with: “Let me know if you’d like more details.”
            Word limit: 70 words total. No markdown symbols.
            USER: \(userMessage)
            """
        }
        if isReport {
            return """
            System: Generate a concise physician‑ready summary for a Parkinson’s patient.
            Include sections (labels must appear exactly as written):
            Summary:
            Key Observations:
            Motor Symptoms:
            Non‑Motor Symptoms:
            Mood & Behavior:
            Medication Adherence:
            Disclaimer:
            • Use plain bullets (•) for observations.
            • 170‑200 words total.
            • Conclude Disclaimer with: “Consult your physician for personalized medical advice.”
            • Finish with: “Please let me know if any detail needs clarification.”
            PATIENT DATA: \(healthData)
            REQUEST: \(userMessage)
            """
        }
        return """
        System: You are an AI Health Coach specializing in Parkinson’s.
        Answer clearly and conversationally:
        • Start with 1–2 plain sentences that directly address the question.
        • Follow with up to five bullet points (•) giving practical insights or data.
        • End with a single‑sentence nudge to consult a healthcare professional.
        • Close with: “Would you like me to explain anything further?”
        • 110‑130 words. No markdown.
        PATIENT DATA (if helpful): \(healthData)
        USER QUESTION: \(userMessage)
        """
    }

    //PDF Generation
    private func generatePDFReport(content: String) {
        let cleanContent = content.replacingOccurrences(of: "*", with: "")
        let reportContent = cleanContent.isEmpty ? createDefaultReport() : cleanContent
        let pdfData = generateAdvancedPDFReport(content: reportContent)
        DispatchQueue.main.async {
            self.generatedPDFData = pdfData
            self.showingPDFPreview = true
        }
    }


    private func generateAdvancedPDFReport(content: String) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 50
        let contentWidth: CGFloat = 512
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return renderer.pdfData { context in
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let headerFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let smallFont = UIFont.systemFont(ofSize: 10, weight: .regular)
            let tableHeaderFont = UIFont.systemFont(ofSize: 11, weight: .bold)
            let tableBodyFont = UIFont.systemFont(ofSize: 10, weight: .regular)
            let primaryColor = UIColor.black
            let secondaryColor = UIColor.darkGray
            let accentColor = UIColor.systemBlue
            let tableLineColor = UIColor.systemGray3
            var currentY: CGFloat = margin
            var currentPage = 1
            var isFirstPage = true

            func beginNewPageIfNeeded(heightNeeded: CGFloat) -> Bool {
                if currentY + heightNeeded > pageRect.height - margin - 40 {
                    context.beginPage()
                    currentY = margin
                    currentPage += 1
                    isFirstPage = false
                    return true
                }
                return false
            }

            func drawHeaderSection() {
                if !isFirstPage { return }
                let headerText = "Parkinson’s Health Report"
                let headerAttributes: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: primaryColor]
                headerText.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 35), withAttributes: headerAttributes)
                currentY += 45
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .long
                let dateString = dateFormatter.string(from: Date())
                let infoText = "Generated: \(dateString)"
                let sourceText = "Source: Apple Watch & Patient Logs"
                let infoAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: secondaryColor]
                infoText.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 18), withAttributes: infoAttributes)
                currentY += 20
                sourceText.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 18), withAttributes: infoAttributes)
                currentY += 35
                context.cgContext.setStrokeColor(accentColor.cgColor)
                context.cgContext.setLineWidth(2)
                context.cgContext.setLineCap(.square)
                context.cgContext.move(to: CGPoint(x: margin, y: currentY))
                context.cgContext.addLine(to: CGPoint(x: margin + contentWidth, y: currentY))
                context.cgContext.strokePath()
                currentY += 25
            }

            func drawModernTable() {
                let tableColumns = ["Health Metric", "Average Value", "Range", "Unit", "Clinical Notes"]
                let columnWidths: [CGFloat] = [120, 85, 90, 55, 162]
                let headerHeight: CGFloat = 30
                let tableData = [
                    ["Heart Rate", "65", "62–68", "bpm", "Stable rhythm, no irregularities detected"],
                    ["Walking Speed", "0.72", "0.65–0.78", "m/s", "Consistent gait, no freezing episodes"],
                    ["Mood Assessment", "Mixed", "Stable–Low", "—", "Low mood documented on 2 occasions"],
                    ["Medication Adherence", "92%", "90–95%", "%", "2 missed evening doses this week"],
                    ["Tremor Severity", "Mild", "Mild–Moderate", "—", "Predominantly resting tremor"],
                    ["Sleep Quality", "Fair", "Poor–Good", "—", "Frequent nighttime awakenings"]
                ]
                let totalRows = tableData.count
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineBreakMode = .byWordWrapping
                let cellAttributes: [NSAttributedString.Key: Any] = [
                    .font: tableBodyFont,
                    .foregroundColor: primaryColor,
                    .paragraphStyle: paragraphStyle
                ]

                // Calculate dynamic row heights
                var rowHeights: [CGFloat] = []
                for row in tableData {
                    var maxHeight: CGFloat = 0
                    for (colIndex, cell) in row.enumerated() {
                        let textWidth = columnWidths[colIndex] - 20 // Account for dx: 10 padding
                        let attributedText = NSAttributedString(string: cell, attributes: cellAttributes)
                        let textHeight = attributedText.boundingRect(
                            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin],
                            context: nil
                        ).height
                        maxHeight = max(maxHeight, textHeight + 12) // Add dy: 6 padding top/bottom
                    }
                    rowHeights.append(maxHeight)
                }
                let tableHeight = headerHeight + rowHeights.reduce(0, +)
                if beginNewPageIfNeeded(heightNeeded: tableHeight + 40) { drawHeaderSection() }

                // Section title
                let sectionTitle = "Health Metrics"
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: primaryColor]
                sectionTitle.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 20), withAttributes: sectionAttributes)
                currentY += 40

                // Draw header
                let headerRect = CGRect(x: margin, y: currentY, width: contentWidth, height: headerHeight)
                context.cgContext.setFillColor(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0).cgColor)
                context.cgContext.fill(headerRect)
                let headerAttributes: [NSAttributedString.Key: Any] = [.font: tableHeaderFont, .foregroundColor: primaryColor]
                var x: CGFloat = margin
                for (i, col) in tableColumns.enumerated() {
                    let rect = CGRect(x: x, y: currentY, width: columnWidths[i], height: headerHeight)
                    let centeredRect = rect.insetBy(dx: 10, dy: 0)
                    let textRect = CGRect(x: centeredRect.origin.x, y: centeredRect.origin.y + (headerHeight - tableHeaderFont.pointSize) / 2, width: centeredRect.width, height: tableHeaderFont.pointSize)
                    NSAttributedString(string: col, attributes: headerAttributes).draw(in: textRect)
                    x += columnWidths[i]
                }
                currentY += headerHeight

                // Draw rows with dynamic heights
                for (rowIndex, row) in tableData.enumerated() {
                    let rowHeight = rowHeights[rowIndex]
                    let rowRect = CGRect(x: margin, y: currentY, width: contentWidth, height: rowHeight)
                    context.cgContext.setFillColor(UIColor.white.cgColor)
                    context.cgContext.fill(rowRect)
                    x = margin
                    for (colIndex, cell) in row.enumerated() {
                        let rect = CGRect(x: x, y: currentY, width: columnWidths[colIndex], height: rowHeight)
                        let textRect = rect.insetBy(dx: 10, dy: 6)
                        let attributedText = NSAttributedString(string: cell, attributes: cellAttributes)
                        attributedText.draw(in: CGRect(x: textRect.origin.x, y: textRect.origin.y, width: textRect.width, height: rowHeight - 12))
                        x += columnWidths[colIndex]
                    }
                    currentY += rowHeight
                }

                // Draw table lines
                context.cgContext.setStrokeColor(tableLineColor.cgColor)
                context.cgContext.setLineWidth(0.5)
                context.cgContext.setLineCap(.square)
                x = margin
                for width in columnWidths {
                    context.cgContext.move(to: CGPoint(x: x, y: currentY - tableHeight))
                    context.cgContext.addLine(to: CGPoint(x: x, y: currentY))
                    context.cgContext.strokePath()
                    x += width
                }
                context.cgContext.move(to: CGPoint(x: margin + contentWidth, y: currentY - tableHeight))
                context.cgContext.addLine(to: CGPoint(x: margin + contentWidth, y: currentY))
                context.cgContext.strokePath()
                var cumulativeHeight: CGFloat = headerHeight
                context.cgContext.move(to: CGPoint(x: margin, y: currentY - tableHeight))
                context.cgContext.addLine(to: CGPoint(x: margin + contentWidth, y: currentY - tableHeight))
                context.cgContext.strokePath()
                for (i, rowHeight) in rowHeights.enumerated() {
                    cumulativeHeight += rowHeight
                    let y = currentY - tableHeight + cumulativeHeight
                    context.cgContext.move(to: CGPoint(x: margin, y: y))
                    context.cgContext.addLine(to: CGPoint(x: margin + contentWidth, y: y))
                    context.cgContext.strokePath()
                }
                currentY += 40
            }

            func drawPatientNotes() {
                if beginNewPageIfNeeded(heightNeeded: 200) { drawHeaderSection() }
                let sectionTitle = "Patient Notes"
                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: primaryColor]
                sectionTitle.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 20), withAttributes: sectionAttributes)
                currentY += 40

                let textAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: primaryColor]
                let paragraphs = [
                    "Stable heart rate observed at 65 bpm, with no irregularities, indicating good cardiovascular stability. Apple Watch data confirms consistent heart rate patterns during rest and activity.",
                    "Walking speed remains steady at 0.72 m/s, with no freezing episodes, supported by Apple Watch gait analysis showing stable stride length and arm swing.",
                    "Mood assessment indicates mixed mood with two documented low mood episodes this week, per self-reported logs. Apple Watch activity data shows reduced daily step count (approximately 3,500 steps) during low mood periods, suggesting a correlation.",
                    "Medication adherence is at 92%, with two missed evening doses noted in self-reported logs. Apple Watch medication reminders were set, but adherence requires further reinforcement.",
                    "Mild resting tremor detected, with Apple Watch (NeuroRPM app) reporting tremor present 19% of the day, consistent with clinical observations of no significant progression.",
                    "Sleep quality is fair, with frequent nighttime awakenings reported. Apple Watch sleep tracking indicates an average of 5.5 hours of sleep per night, with multiple interruptions.",
                    "Additional Apple Watch metrics: Dyskinesia episodes detected 5% of the day, primarily during medication 'on' periods, per StrivePD app. Bradykinesia observed in fine motor tasks, with slower finger tapping speed noted in BrainBaseline app assessments."
                ]
                for para in paragraphs {
                    let attr = NSAttributedString(string: para, attributes: textAttributes)
                    let height = attr.boundingRect(with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height
                    if beginNewPageIfNeeded(heightNeeded: height + 20) { drawHeaderSection() }
                    attr.draw(in: CGRect(x: margin + 15, y: currentY, width: contentWidth - 15, height: height))
                    currentY += height + 15
                }
                currentY += 40
            }

            func drawFooter() {
                let footerText = "This report is generated using AI assistance. Please consult your physician for clinical interpretation."
                let pageText = "Page \(currentPage)"
                let footerAttributes: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: secondaryColor]
                let footerRect = CGRect(x: margin, y: pageRect.height - margin - 25, width: contentWidth - 60, height: 15)
                let pageRect = CGRect(x: pageRect.width - margin - 60, y: pageRect.height - margin - 25, width: 60, height: 15)
                footerText.draw(in: footerRect, withAttributes: footerAttributes)
                pageText.draw(in: pageRect, withAttributes: footerAttributes)
            }

            context.beginPage()
            drawHeaderSection()
            drawModernTable()
            drawPatientNotes()
            drawFooter()
        }


    }

    private func createDefaultReport() -> String {
        """
        Parkinson's Clinical Observation Report
        Generated by: AI Clinical Assistant
        Patient ID: Redacted
        Report Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))
        Data Sources: Apple Watch sensor data, patient mood and medication logs (past 7 days)

        CLINICAL SUMMARY:
        The patient's Parkinson's status appears clinically stable with mild symptom variability. Evening tremor intensification and low mood periods may be influenced by sleep inefficiency and partial medication non-adherence.

        MOTOR SYMPTOMS:
        • Tremor Intensity (avg): 2.1 (range: 1.8–2.5) — mild, with evening spikes
        • Gait Speed: 0.72 m/s (range: 0.65–0.78 m/s) — stable, no freezing episodes
        • Bradykinesia: Not prominently observed
        • Rigidity: Not flagged via current motion sensor data

        NON-MOTOR SYMPTOMS:
        • Sleep Efficiency: 82% (target >85%)
        • Avg Sleep Duration: 5.8 hours/night
        • Fatigue: Reported on 4 out of 7 days, especially after poor sleep nights
        • Cognition: No decline observed in interactions or behavioral metrics

        MOOD & BEHAVIOR:
        • Day 1: Neutral
        • Day 2: Low mood — associated with fatigue and disrupted sleep
        • Day 3: Mild anxiety — triggered by a social stressor
        • Day 4: Neutral
        • Day 5: Positive mood — linked to high activity and social interaction
        • Day 6: Low mood — fatigue-related, poor sleep recorded
        • Day 7: Slightly elevated — stable sleep and consistent routine

        Interpretation:
        Mood fluctuations were moderate, with identifiable external and physiological triggers. Emotional variability may influence symptom perception and adherence.

        MEDICATION ADHERENCE:
        • Prescribed: Levodopa 100mg — 3x daily
        • Adherence Rate: 92%
        • Missed Doses: 2 (both evening doses on separate days)
        • No reported side effects or adverse responses

        Interpretation:
        Evening symptom worsening correlates with missed Levodopa doses. Consistent timing remains critical for tremor control and motor stability.

        AI ASSISTANT RECOMMENDATIONS:
        • Physician may consider reviewing patient's evening medication routine
        • Suggest reinforcing structured sleep hygiene for improved non-motor symptom control
        • Encourage continued mood tracking to evaluate trends vs symptom severity
        • No evidence suggesting urgent intervention or medication adjustment at this stage

        DISCLAIMER:
        This report was generated using patient-approved wearable and self-logged data. It is intended for use by the treating physician and does not substitute for an in-person neurological evaluation.
        """
    }

    private func savePDF(content: String) {
        let pdfData = generateAdvancedPDFReport(content: content)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent("Health_Report_\(Date().formatted(date: .numeric, time: .omitted)).pdf")
        do {
            try pdfData.write(to: fileURL)
            DispatchQueue.main.async {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation { showPDFSavedConfirmation = true }
            }
        } catch {
            DispatchQueue.main.async {
                pdfErrorMessage = "Unable to save report: \(error.localizedDescription)"
            }
        }
    }

    private func shouldShowDisclaimer(for content: String) -> Bool {
        let medicalKeywords = ["symptom", "mood", "medication", "adherence", "assessment", "analysis"]
        return medicalKeywords.contains { content.lowercased().contains($0) }
    }

    private func shouldHelpPrompt() -> Bool {
        guard let lastMessage = conversationHistory.last, lastMessage["role"] == "assistant" else { return false }
        let content = lastMessage["content"]?.lowercased() ?? ""
        let generalKeywords = ["hi", "hello", "how are you", "weather", "news", "time", "joke"]
        return generalKeywords.contains { content.contains($0) }
    }

    private func shouldShowPDFOptions(for content: String) -> Bool {
        let reportKeywords = ["report", "summary", "observations", "assessment", "analysis"]
        return reportKeywords.contains { content.lowercased().contains($0) }
    }
}

//PDF Preview View
struct PDFPreviewView: View {
    @Binding var editableContent: String
    let onSave: (String) -> Void
    @State private var pdfData: Data
    @State private var isEditing = false
    @Environment(\.dismiss) private var dismiss

    private let primaryColor = Color(.sRGB, red: 0.18, green: 0.45, blue: 0.71, opacity: 1.0)
    private let secondaryColor = Color(.sRGB, red: 0.28, green: 0.30, blue: 0.33, opacity: 1.0)
    private let backgroundColor = Color.white

    init(pdfData: Data, editableContent: Binding<String>, onSave: @escaping (String) -> Void) {
        self._pdfData = State(initialValue: pdfData)
        self._editableContent = editableContent
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                PDFViewRepresentable(pdfData: pdfData)
                    .frame(maxHeight: .infinity)
                if isEditing {
                    TextEditor(text: $editableContent)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(height: 100)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(secondaryColor.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 8)
                }
                HStack(spacing: 8) {
                    Button(isEditing ? "Save Changes" : "Edit Report") {
                        if isEditing {
                            onSave(editableContent)
                            regeneratePDF()
                        }
                        isEditing.toggle()
                    }
                    .buttonStyle(ReportButtonStyle())
                    .scaleEffectAnimation()
                    ShareLink(
                        item: pdfData,
                        preview: SharePreview("Health Report", icon: Image(systemName: "doc.text"))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(ReportButtonStyle())
                    .scaleEffectAnimation()
                    Button("Close") { dismiss() }
                        .buttonStyle(ReportButtonStyle())
                        .scaleEffectAnimation()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Report Preview")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(primaryColor)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor, for: .navigationBar)
        }
    }

    private func regeneratePDF() {
        self.pdfData = generateAdvancedPDFReport(content: editableContent)
    }


    private func generateAdvancedPDFReport(content: String) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 50
        let contentWidth: CGFloat = 512
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            // Fonts & colors
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let headerFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let smallFont = UIFont.systemFont(ofSize: 10, weight: .regular)
            let tableHeaderFont = UIFont.systemFont(ofSize: 11, weight: .bold)
            let tableBodyFont = UIFont.systemFont(ofSize: 10, weight: .regular)

            let primaryColor = UIColor.black
            let secondaryColor = UIColor.darkGray
            let accentColor = UIColor.systemBlue
            let lightGray = UIColor.systemGray5
            let tableLineColor = UIColor.systemGray3

            var currentY: CGFloat = margin
            var currentPage = 1
            var isFirstPage = true

            func beginNewPageIfNeeded(heightNeeded: CGFloat) -> Bool {
                if currentY + heightNeeded > pageRect.height - margin - 40 {
                    context.beginPage()
                    currentY = margin
                    currentPage += 1
                    isFirstPage = false
                    return true
                }
                return false
            }

            func drawHeaderSection() {
                if !isFirstPage { return }
                let headerText = "Parkinson's Health Report"
                let headerAttributes: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: primaryColor]
                headerText.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 35), withAttributes: headerAttributes)
                currentY += 45

                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .long
                let dateString = dateFormatter.string(from: Date())
                let infoText = "Generated: \(dateString)"
                let sourceText = "Source: Apple Watch & Patient Logs"
                let infoAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: secondaryColor]
                infoText.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 18), withAttributes: infoAttributes)
                currentY += 20
                sourceText.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 18), withAttributes: infoAttributes)
                currentY += 35

                context.cgContext.setStrokeColor(accentColor.cgColor)
                context.cgContext.setLineWidth(2)
                context.cgContext.move(to: CGPoint(x: margin, y: currentY))
                context.cgContext.addLine(to: CGPoint(x: margin + contentWidth, y: currentY))
                context.cgContext.strokePath()
                currentY += 25
            }

            func drawModernTable() {
                let tableColumns = ["Health Metric", "Average Value", "Range", "Unit", "Clinical Notes"]
                let columnWidths: [CGFloat] = [120, 85, 90, 55, 162]
                let rowHeight: CGFloat = 35
                let headerHeight: CGFloat = 40
                let tableData = [
                    ["Heart Rate", "65", "62–68", "bpm", "Stable rhythm, no irregularities detected"],
                    ["Walking Speed", "0.72", "0.65–0.78", "m/s", "Consistent gait, no freezing episodes"],
                    ["Mood Assessment", "Mixed", "Stable–Low", "—", "Low mood documented on 2 occasions"],
                    ["Medication Adherence", "92%", "90–95%", "%", "2 missed evening doses this week"],
                    ["Tremor Severity", "Mild", "Mild–Moderate", "—", "Predominantly resting tremor"],
                    ["Sleep Quality", "Fair", "Poor–Good", "—", "Frequent nighttime awakenings"]
                ]

                let totalRows = tableData.count
                let tableHeight = headerHeight + CGFloat(totalRows) * rowHeight

                if beginNewPageIfNeeded(heightNeeded: tableHeight + 40) {
                    drawHeaderSection()
                }

                if isFirstPage {

                    // Table header
                    let headerRect = CGRect(x: margin, y: currentY, width: contentWidth, height: headerHeight)
                    context.cgContext.setFillColor(UIColor.white.cgColor)
                    context.cgContext.fill(headerRect)

                    let headerAttributes: [NSAttributedString.Key: Any] = [.font: tableHeaderFont, .foregroundColor: primaryColor]
                    var x: CGFloat = margin
                    for (i, col) in tableColumns.enumerated() {
                        let rect = CGRect(x: x, y: currentY, width: columnWidths[i], height: headerHeight)
                        let centeredRect = rect.insetBy(dx: 8, dy: 0)
                        let textRect = CGRect(x: centeredRect.origin.x, y: centeredRect.origin.y + (headerHeight - 16) / 2, width: centeredRect.width, height: 16)
                        NSAttributedString(string: col, attributes: headerAttributes).draw(in: textRect)
                        x += columnWidths[i]
                    }
                    currentY += headerHeight
                }

                let cellAttributes: [NSAttributedString.Key: Any] = [.font: tableBodyFont, .foregroundColor: primaryColor]
                for row in tableData {
                    beginNewPageIfNeeded(heightNeeded: rowHeight)
                    let rowRect = CGRect(x: margin, y: currentY, width: contentWidth, height: rowHeight)
                    context.cgContext.setFillColor(UIColor.white.cgColor)
                    context.cgContext.fill(rowRect)

                    var x = margin
                    for (colIndex, cell) in row.enumerated() {
                        let rect = CGRect(x: x, y: currentY, width: columnWidths[colIndex], height: rowHeight)
                        let textRect = rect.insetBy(dx: 8, dy: 5)
                        let centeredTextRect = CGRect(x: textRect.origin.x,
                                                      y: textRect.origin.y + (rowHeight - 12) / 2,
                                                      width: textRect.width,
                                                      height: 12)
                        NSAttributedString(string: cell, attributes: cellAttributes).draw(in: centeredTextRect)
                        x += columnWidths[colIndex]
                    }

                    currentY += rowHeight
                }

                // Table lines
                context.cgContext.setStrokeColor(tableLineColor.cgColor)
                context.cgContext.setLineWidth(0.5)

                var x = margin
                for width in columnWidths {
                    context.cgContext.move(to: CGPoint(x: x, y: currentY - tableHeight))
                    context.cgContext.addLine(to: CGPoint(x: x, y: currentY))
                    context.cgContext.strokePath()
                    x += width
                }

                context.cgContext.move(to: CGPoint(x: margin + contentWidth, y: currentY - tableHeight))
                context.cgContext.addLine(to: CGPoint(x: margin + contentWidth, y: currentY))
                context.cgContext.strokePath()

                for i in 0...(totalRows + 1) {
                    let y = currentY - tableHeight + CGFloat(i) * (i == 0 ? headerHeight : rowHeight)
                    context.cgContext.move(to: CGPoint(x: margin, y: y))
                    context.cgContext.addLine(to: CGPoint(x: margin + contentWidth, y: y))
                    context.cgContext.strokePath()
                }

                currentY += 30
            }

            func drawPatientNotes() {

                let sectionAttributes: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: primaryColor]



                let bulletAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: primaryColor]
                let paragraphs = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                for para in paragraphs {
                    let bullet = "• \(para.trimmingCharacters(in: .whitespaces))"
                    let attr = NSAttributedString(string: bullet, attributes: bulletAttributes)
                    let height = attr.boundingRect(with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height



                    attr.draw(in: CGRect(x: margin + 15, y: currentY, width: contentWidth - 15, height: height))
                    currentY += height + 10
                }
            }

            func drawFooter() {
                let footerText = "This report is generated using AI assistance. Please consult your physician for clinical interpretation."
                let footerAttributes: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: secondaryColor]
                let footerHeight: CGFloat = 40 // Increased height to prevent clipping
                let footerRect = CGRect(x: margin, y: pageRect.height - margin - footerHeight - 10, width: contentWidth, height: footerHeight)
                footerText.draw(in: footerRect, withAttributes: footerAttributes)
            }

            // Page rendering
            context.beginPage()
            drawHeaderSection()
            drawModernTable()
            drawPatientNotes()
            drawFooter()
        }
    }
}

//PDF View Representable
struct PDFViewRepresentable: UIViewRepresentable {
    let pdfData: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: pdfData)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: pdfData)
    }
}

//PDF Error View
struct PDFErrorView: View {
    let action: () -> Void
    private let primaryColor = Color(.sRGB, red: 0.20, green: 0.67, blue: 0.86, opacity: 1.0)
    private let backgroundColor = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.red)
            Text("Unable to generate report")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
            Button("OK", action: action)
                .buttonStyle(ReportButtonStyle())
                .scaleEffectAnimation()
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
    }
}

//Report Button Style
struct ReportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.sRGB, red: 0.20, green: 0.67, blue: 0.86, opacity: 1.0))
            .cornerRadius(8)
            .shadow(color: Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 0.1), radius: 2, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

//Scale Effect Animation
struct ScaleEffectAnimation: ViewModifier {
    @State private var isTapped = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isTapped ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isTapped)
            .onTapGesture {
                isTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isTapped = false
                }
            }
    }
}

extension View {
    func scaleEffectAnimation() -> some View {
        modifier(ScaleEffectAnimation())
    }
}
