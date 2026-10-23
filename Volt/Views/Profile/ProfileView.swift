import SwiftUI
import SwiftData

// Profile tab. Layout follows Profile.dc.html on the App Screens canvas.
struct ProfileView: View {
    @Binding var selectedTab: ContentView.Tab
    @Query private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext
    @Environment(SupabaseManager.self) private var supabase
    @AppStorage("username") private var username = "Athlete"
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @AppStorage("localMode") private var localMode = false
    @State private var showingSignOutConfirm = false
    @FocusState private var nameFocused: Bool

    private var completed: [WorkoutSession] { sessions.filter { $0.endDate != nil } }

    private var totalVolume: Double { completed.reduce(0) { $0 + $1.totalVolume } }
    private var totalSets: Int { completed.reduce(0) { $0 + $1.totalSets } }
    private var totalHours: Double { completed.reduce(0) { $0 + $1.duration } / 3600 }

    /// Consecutive weeks (Monday start) with at least one workout.
    private var streakWeeks: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let weeks = Set(completed.compactMap { cal.dateInterval(of: .weekOfYear, for: $0.startDate)?.start })
        guard var start = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        if !weeks.contains(start) { start = cal.date(byAdding: .weekOfYear, value: -1, to: start) ?? start }
        var count = 0
        while weeks.contains(start) {
            count += 1
            start = cal.date(byAdding: .weekOfYear, value: -1, to: start) ?? start
        }
        return count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    header

                    Button { selectedTab = .history } label: {
                        SpecGrid(cells: [
                            ("Workouts", "\(completed.count)", ""),
                            ("Sets", "\(totalSets)", ""),
                            ("Volume", voltVolume(totalVolume), weightUnit.uppercased()),
                            ("Time", String(format: "%.1f", totalHours), "H")
                        ], columns: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens History")

                    settingsSection
                    if supabase.isSignedIn { backupSection }
                    aboutSection

                    if supabase.isSignedIn {
                        VoltButton("Sign Out", style: .danger) { showingSignOutConfirm = true }
                    } else {
                        // Local-only mode: workouts stay on this phone until you sign in
                        VoltButton("Sign In for Cloud Backup", style: .secondary) { localMode = false }
                    }
                }
                .padding(.horizontal, VoltSpacing.gutter)
                .padding(.top, VoltSpacing.md)
                .padding(.bottom, VoltSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(VoltColor.bg.ignoresSafeArea())
            .navigationBarHidden(true)
            .confirmationDialog("Sign Out?", isPresented: $showingSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { localMode = false; Task { await supabase.signOut() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your data is saved locally and will be here when you sign back in.")
            }
        }
    }

    // MARK: - Header: square avatar, editable name, streak
    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            Text(username.prefix(1).uppercased())
                .font(VoltFont.sans(28)).tracking(-0.8)
                .foregroundStyle(VoltColor.onInk)
                .padding(8)
                .frame(width: 64, height: 64, alignment: .bottomLeading)
                .background(VoltColor.ink)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Name", text: $username)
                    .font(VoltFont.sans(40)).tracking(-1.4)
                    .foregroundStyle(VoltColor.label)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { tidyName() }
                    .onChange(of: nameFocused) { _, focused in if !focused { tidyName() } }
                    .accessibilityLabel("Your name")
                Group {
                    if let email = supabase.currentEmail {
                        Text("\(streakWeeks)-week streak · \(email)")
                    } else {
                        Text("\(streakWeeks)-week streak")
                    }
                }
                .font(VoltFont.mono(11)).tracking(0.4).textCase(.uppercase)
                .foregroundStyle(VoltColor.labelSecondary)
                .lineLimit(1)
            }
        }
    }

    // MARK: - Settings
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VoltSectionTitle("Settings")
            VStack(spacing: 0) {
                VoltRule(strong: true)
                settingsRow("Appearance") { AppearanceToggle() }
                VoltRule()
                settingsRow("Weight unit") {
                    VoltSegmented(options: [(value: "kg", label: "KG"), (value: "lb", label: "LB")], selection: $weightUnit, compact: true)
                }
                VoltRule()
                NavigationLink { EquipmentSettingsView() } label: {
                    settingsRow("Gym equipment") {
                        Image(systemName: "arrow.right").font(.system(size: 14)).foregroundStyle(VoltColor.labelTertiary)
                    }
                }
                .buttonStyle(.plain)
                VoltRule()
            }
        }
    }

    // MARK: - Cloud backup
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VoltSectionTitle("Cloud backup")
            VStack(spacing: 0) {
                VoltRule(strong: true)
                Button { Task { await supabase.syncAll(context: modelContext) } } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sync to cloud").font(VoltFont.sans(17)).foregroundStyle(VoltColor.label)
                            Group {
                                if let error = supabase.lastSyncError {
                                    Text(error).foregroundStyle(VoltColor.danger)
                                } else {
                                    Text(supabase.isSyncing ? "Syncing…" : "Back up workouts and routines")
                                        .foregroundStyle(VoltColor.labelSecondary)
                                }
                            }
                            .font(VoltFont.mono(11)).tracking(0.4).textCase(.uppercase)
                        }
                        Spacer()
                        if supabase.isSyncing {
                            SwiftUI.ProgressView().tint(VoltColor.label)
                        } else {
                            Image(systemName: "arrow.right").font(.system(size: 14)).foregroundStyle(VoltColor.labelTertiary)
                        }
                    }
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(supabase.isSyncing)
                VoltRule()
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VoltSectionTitle("About")
            VStack(spacing: 0) {
                VoltRule(strong: true)
                ForEach([("App", "Volt"), ("Version", "1.0.0"), ("Platform", "iOS 17+")], id: \.0) { item in
                    settingsRow(item.0) {
                        Text(item.1.uppercased()).font(VoltFont.mono(12)).foregroundStyle(VoltColor.labelSecondary)
                    }
                    VoltRule()
                }
            }
        }
    }

    private func settingsRow<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Text(title).font(VoltFont.sans(17)).foregroundStyle(VoltColor.label)
            Spacer(minLength: 8)
            trailing()
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func tidyName() {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        username = trimmed.isEmpty ? "Athlete" : trimmed
    }
}

#Preview("Profile") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutSession.self, Exercise.self, Routine.self, configurations: config)
    let ctx = container.mainContext
    for (title, days) in [("Push Day",0),("Pull Day",1),("Leg Day",2),("Push Day",4),("Full Body",7)] {
        let s = WorkoutSession(title: title)
        s.startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        s.endDate = s.startDate.addingTimeInterval(3600)
        ctx.insert(s)
        let log = ExerciseLog(exerciseName: "Bench Press", exerciseMuscleGroup: "Chest"); ctx.insert(log)
        let ws = WorkoutSet(orderIndex: 0, weight: 80, reps: 8); ws.isCompleted = true
        ctx.insert(ws); log.sets.append(ws); s.exerciseLogs = [log]
    }
    try? ctx.save()
    return ProfileView(selectedTab: .constant(.profile))
        .modelContainer(container)
        .environment(SupabaseManager.shared)
}

// MARK: - Equipment the user can access (used by workout suggestions)

struct EquipmentSettingsView: View {
    /// Comma-separated `Exercise.Equipment` raw values the user does NOT have. Empty = everything available.
    @AppStorage("unavailableEquipment") private var unavailable = ""

    private var unavailableSet: Set<String> {
        Set(unavailable.split(separator: ",").map(String.init))
    }

    private func binding(for equipment: Exercise.Equipment) -> Binding<Bool> {
        Binding(
            get: { !unavailableSet.contains(equipment.rawValue) },
            set: { isOn in
                var set = unavailableSet
                if isOn { set.remove(equipment.rawValue) } else { set.insert(equipment.rawValue) }
                unavailable = set.sorted().joined(separator: ",")
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VoltScreenHeader(caption: "Settings", title: "Gym equipment")
                Text("Suggested workouts only use equipment that is switched on.")
                    .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                VStack(spacing: 0) {
                    VoltRule(strong: true)
                    ForEach(Exercise.Equipment.allCases, id: \.self) { equipment in
                        Toggle(isOn: binding(for: equipment)) {
                            Text(equipment.rawValue).font(VoltFont.sans(17)).foregroundStyle(VoltColor.label)
                        }
                        .tint(VoltColor.accent)
                        .frame(minHeight: 52)
                        VoltRule()
                    }
                }
            }
            .padding(.horizontal, VoltSpacing.gutter)
            .padding(.top, VoltSpacing.sm)
            .padding(.bottom, VoltSpacing.xxl)
        }
        .background(VoltColor.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
