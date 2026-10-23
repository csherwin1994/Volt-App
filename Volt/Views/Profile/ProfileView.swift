import SwiftUI
import SwiftData

struct ProfileView: View {
    @Binding var selectedTab: ContentView.Tab
    @Query private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext
    @Environment(SupabaseManager.self) private var supabase
    @AppStorage("username") private var username = "Athlete"
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @State private var editingName = false
    @State private var tempName = ""
    @State private var showingSignOutConfirm = false

    private var completed: [WorkoutSession] { sessions.filter { $0.endDate != nil } }

    private var totalVolume: Double {
        completed.flatMap { $0.exerciseLogs }.flatMap { $0.sets }
            .filter(\.isCompleted).reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    private var totalSets: Int {
        completed.flatMap { $0.exerciseLogs }.flatMap { $0.sets }
            .filter(\.isCompleted).count
    }

    private var workoutsThisWeek: Int {
        let start = Calendar.current.startOfWeek(for: Date())
        return completed.filter { $0.startDate >= start }.count
    }

    private var streak: Int {
        var count = 0
        var day = Calendar.current.startOfDay(for: Date())
        while completed.contains(where: { Calendar.current.isDate($0.startDate, inSameDayAs: day) }) {
            count += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VoltColor.bg.ignoresSafeArea()
                List {
                    profileHeader
                    statsSection
                    syncSection
                    settingsSection
                    aboutSection
                    signOutSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Profile")

        }
    }

    // MARK: - Profile header
    private var profileHeader: some View {
        Section {
            HStack(spacing: VoltSpacing.md) {
                ZStack {
                    Circle()
                        .fill(VoltGradient.brand)
                        .frame(width: 68, height: 68)
                    Text(username.prefix(1).uppercased())
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(VoltColor.onInk)
                }
                VStack(alignment: .leading, spacing: 6) {
                    if editingName {
                        TextField("Name", text: $tempName)
                            .font(.title3.bold())
                            .foregroundStyle(VoltColor.label)
                            .onSubmit { saveName() }
                    } else {
                        Text(username)
                            .font(.title3.bold())
                            .foregroundStyle(VoltColor.label)
                    }
                    if let email = supabase.currentEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(VoltColor.labelSecondary)
                    }
                    if streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").foregroundStyle(VoltColor.labelSecondary).font(.caption)
                            Text("\(streak)-day streak")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VoltColor.labelSecondary)
                        }
                    }
                }
                Spacer()
                Button(editingName ? "Done" : "Edit") {
                    if editingName { saveName() } else { tempName = username }
                    editingName.toggle()
                }
                .font(.subheadline)
                .foregroundStyle(VoltColor.accent)
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(VoltColor.surface)
    }

    // MARK: - Stats
    private var statsSection: some View {
        Section("Stats") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ProfileStatCard(value: "\(completed.count)", label: "Total Workouts", icon: "dumbbell.fill", color: VoltColor.labelSecondary) {
                    selectedTab = .history
                }
                ProfileStatCard(value: "\(workoutsThisWeek)", label: "This Week", icon: "calendar", color: VoltColor.labelSecondary) {
                    selectedTab = .history
                }
                ProfileStatCard(value: "\(totalSets)", label: "Total Sets", icon: "repeat", color: VoltColor.labelSecondary) {
                    selectedTab = .progress
                }
                ProfileStatCard(
                    value: totalVolume >= 1_000_000
                        ? String(format: "%.1fM", totalVolume / 1_000_000)
                        : totalVolume >= 1000
                            ? String(format: "%.1fk", totalVolume / 1000)
                            : String(format: "%.0f", totalVolume),
                    label: "Volume (\(weightUnit))",
                    icon: "scalemass.fill",
                    color: VoltColor.labelSecondary
                ) {
                    selectedTab = .progress
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    // MARK: - Settings
    private var settingsSection: some View {
        Section("Settings") {
            Picker("Weight Unit", selection: $weightUnit) {
                Text("Kilograms (kg)").tag("kg")
                Text("Pounds (lb)").tag("lb")
            }
            .foregroundStyle(VoltColor.label)
            .listRowBackground(VoltColor.surface)
            .listRowSeparatorTint(VoltColor.border)
        }
    }

    // MARK: - Sync
    private var syncSection: some View {
        Section("Cloud Backup") {
            Button {
                Task { await supabase.syncAll(context: modelContext) }
            } label: {
                HStack {
                    Image(systemName: supabase.isSyncing ? "arrow.triangle.2.circlepath" : "icloud.and.arrow.up")
                        .foregroundStyle(VoltColor.accent)
                        .frame(width: 28)
                        .symbolEffect(.pulse, isActive: supabase.isSyncing)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync to Cloud")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(VoltColor.label)
                        if let error = supabase.lastSyncError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(VoltColor.danger)
                        } else {
                            Text(supabase.isSyncing ? "Syncing..." : "Back up your workouts & routines")
                                .font(.caption)
                                .foregroundStyle(VoltColor.labelSecondary)
                        }
                    }
                    Spacer()
                    if !supabase.isSyncing {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VoltColor.labelTertiary)
                    }
                }
            }
            .disabled(supabase.isSyncing)
            .listRowBackground(VoltColor.surface)
            .listRowSeparatorTint(VoltColor.border)
        }
    }

    // MARK: - Sign Out
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showingSignOutConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
            }
            .listRowBackground(VoltColor.surface)
            .confirmationDialog("Sign Out?", isPresented: $showingSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await supabase.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your data is saved locally and will be here when you sign back in.")
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App", value: "Volt")
                .foregroundStyle(VoltColor.label)
            LabeledContent("Version", value: "1.0.0")
                .foregroundStyle(VoltColor.label)
            LabeledContent("Platform", value: "iOS 17+")
                .foregroundStyle(VoltColor.label)
        }
        .listRowBackground(VoltColor.surface)
        .listRowSeparatorTint(VoltColor.border)
    }

    private func saveName() {
        let trimmed = tempName.trimmingCharacters(in: .whitespaces)
        username = trimmed.isEmpty ? "Athlete" : trimmed
    }
}

struct ProfileStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color.opacity(0.5))
                }
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(VoltColor.label)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(VoltColor.labelSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(VoltSpacing.md)
            .background(color.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
            .overlay(RoundedRectangle(cornerRadius: VoltSpacing.radius)
                .stroke(color.opacity(0.15), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let c = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: c) ?? date
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
