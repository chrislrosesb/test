import SwiftUI

struct ProfileView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM

    @AppStorage("libraryViewMode") private var viewMode: String = "cards"
    @AppStorage("readerFontSize") private var fontSize: Double = 17
    @AppStorage("readerFont") private var fontRaw: String = "system"
    @AppStorage("readerTheme") private var themeRaw: String = "dark"
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""
    @AppStorage("dailyDigestEnabled") private var digestEnabled: Bool = false
    @AppStorage("digestHour") private var digestHour: Int = 8
    @AppStorage("digestMinute") private var digestMinute: Int = 0
    @AppStorage("digestFrequency") private var digestFrequencyRaw: String = DigestFrequency.daily.rawValue

    var body: some View {
        NavigationStack {
            List {
                notificationSection
                readerSection
                librarySection
                aiSection
                accountSection
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Notifications

    private var digestFrequency: DigestFrequency {
        DigestFrequency(rawValue: digestFrequencyRaw) ?? .daily
    }

    private var digestTime: Date {
        get {
            var comps = DateComponents()
            comps.hour = digestHour
            comps.minute = digestMinute
            return Calendar.current.date(from: comps) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            digestHour = comps.hour ?? 8
            digestMinute = comps.minute ?? 0
        }
    }

    var notificationSection: some View {
        Section("Digest Notification") {
            Toggle("Enable", isOn: $digestEnabled)
                .onChange(of: digestEnabled) { _, enabled in
                    if enabled {
                        rescheduleDigest()
                    } else {
                        DigestNotificationManager.shared.cancel()
                    }
                }

            if digestEnabled {
                DatePicker("Time", selection: Binding(
                    get: { digestTime },
                    set: { newValue in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        digestHour = comps.hour ?? 8
                        digestMinute = comps.minute ?? 0
                        rescheduleDigest()
                    }
                ), displayedComponents: .hourAndMinute)

                Picker("Frequency", selection: Binding(
                    get: { digestFrequencyRaw },
                    set: { newValue in
                        digestFrequencyRaw = newValue
                        rescheduleDigest()
                    }
                )) {
                    ForEach(DigestFrequency.allCases, id: \.rawValue) { freq in
                        Text(freq.label).tag(freq.rawValue)
                    }
                }
            }
        }
    }

    func rescheduleDigest() {
        DigestNotificationManager.shared.requestAndSchedule(
            links: vm.allLinks,
            hour: digestHour,
            minute: digestMinute,
            frequency: digestFrequency
        )
    }

    // MARK: - Reader Settings

    var readerSection: some View {
        Section("Reader") {
            HStack {
                Text("Font Size")
                Spacer()
                Text("\(Int(fontSize))pt")
                    .foregroundStyle(.secondary)
                Stepper("", value: $fontSize, in: 13...24, step: 1)
                    .labelsHidden()
                    .frame(width: 100)
            }
            Picker("Font", selection: $fontRaw) {
                Text("System").tag("system")
                Text("Serif").tag("serif")
                Text("Mono").tag("mono")
            }
            Picker("Theme", selection: $themeRaw) {
                Text("Dark").tag("dark")
                Text("Light").tag("light")
                Text("Sepia").tag("sepia")
            }
        }
    }

    // MARK: - Library Settings

    var librarySection: some View {
        Section("Library") {
            Picker("Default View", selection: $viewMode) {
                Text("Cards").tag("cards")
                Text("List").tag("list")
            }
        }
    }

    // MARK: - AI Services

    var aiSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Gemini API Key")
                    .font(.subheadline)
                SecureField("Paste your key here", text: $geminiAPIKey)
                    .font(.callout)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.vertical, 4)
        } header: {
            Text("AI Services")
        } footer: {
            Text("Used for Audio Briefing. Free at aistudio.google.com — no credit card required.")
        }
    }

    // MARK: - Account

    var accountSection: some View {
        Section {
            Button(role: .destructive) {
                authVM.signOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
        }
    }
}
