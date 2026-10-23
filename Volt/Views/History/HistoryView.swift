import SwiftUI
import SwiftData

// History tab. Layout follows History.dc.html on the App Screens canvas.
struct HistoryView: View {
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext
    @State private var sessionToDelete: WorkoutSession?

    private var completed: [WorkoutSession] { sessions.filter { $0.endDate != nil } }
    private var hours: Double { completed.reduce(0) { $0 + $1.duration } / 3600 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    VoltScreenHeader(
                        caption: "\(completed.count) workouts · \(String(format: "%.1f", hours)) hours",
                        title: "History"
                    )

                    if completed.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            VoltRule(strong: true)
                            Text("Nothing logged yet.").font(VoltFont.sans(24)).tracking(-0.6)
                                .foregroundStyle(VoltColor.label).padding(.top, 14)
                            Text("Finished workouts appear here.")
                                .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                        }
                    }

                    ForEach(groupedByMonth, id: \.key) { month, workouts in
                        VStack(alignment: .leading, spacing: 12) {
                            VoltSectionTitle(month)
                            VStack(spacing: 0) {
                                VoltRule(strong: true)
                                ForEach(workouts) { session in
                                    NavigationLink { WorkoutDetailView(session: session) } label: {
                                        WorkoutHistoryRow(session: session, hasRecord: hasRecord(session))
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Delete Workout", role: .destructive) { sessionToDelete = session }
                                    }
                                    VoltRule()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, VoltSpacing.gutter)
                .padding(.top, VoltSpacing.md)
                .padding(.bottom, VoltSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .background(VoltColor.bg.ignoresSafeArea())
            .navigationBarHidden(true)
            .confirmationDialog("Delete workout?", isPresented: Binding(
                get: { sessionToDelete != nil }, set: { if !$0 { sessionToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let s = sessionToDelete { modelContext.delete(s); try? modelContext.save() }
                    sessionToDelete = nil
                }
                Button("Cancel", role: .cancel) { sessionToDelete = nil }
            } message: {
                Text("It will be removed from your history and charts.")
            }
        }
    }

    /// True when the workout set a personal record against everything logged before it.
    private func hasRecord(_ session: WorkoutSession) -> Bool {
        guard completed.contains(where: { $0.startDate < session.startDate }) else { return false }
        return !PersonalRecords.recordSetIDs(in: session, history: completed).isEmpty
    }

    private var groupedByMonth: [(key: String, value: [WorkoutSession])] {
        let fmt = DateFormatter(); fmt.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: completed) { fmt.string(from: $0.startDate) }
        return grouped.sorted { ($0.value.first?.startDate ?? .distantPast) > ($1.value.first?.startDate ?? .distantPast) }
    }
}

// MARK: - Row: date block, title, mono stats, gold PR tag
struct WorkoutHistoryRow: View {
    let session: WorkoutSession
    var hasRecord = false
    @AppStorage("weightUnit") private var weightUnit = "kg"

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startDate.formatted(.dateTime.day()))
                    .font(VoltFont.mono(20)).foregroundStyle(VoltColor.label)
                Text(session.startDate.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(VoltFont.mono(10)).tracking(0.8).foregroundStyle(VoltColor.labelTertiary)
            }
            .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(VoltFont.sans(17)).foregroundStyle(VoltColor.label)
                    .lineLimit(1)
                Text("\(Int(session.duration / 60)) min · \(session.totalSets) sets · \(voltVolume(session.totalVolume)) \(weightUnit)".uppercased())
                    .font(VoltFont.mono(11)).tracking(0.4)
                    .foregroundStyle(VoltColor.labelSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if hasRecord { VoltTag(text: "PR", gold: true) }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail
struct WorkoutDetailView: View {
    let session: WorkoutSession
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @Query(sort: \WorkoutSession.startDate) private var allSessions: [WorkoutSession]
    @Query private var library: [Exercise]

    /// Sets in this workout that beat every earlier workout for that exercise.
    private var recordSetIDs: Set<UUID> {
        PersonalRecords.recordSetIDs(in: session, history: allSessions)
    }

    private var sortedLogs: [ExerciseLog] {
        session.exerciseLogs.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        let records = recordSetIDs
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 20) {
                    VoltScreenHeader(
                        caption: session.startDate.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                        title: session.title
                    )
                    SpecGrid(cells: [
                        ("Time", "\(Int(session.duration / 60))", "MIN"),
                        ("Sets", "\(session.totalSets)", ""),
                        ("Volume", voltVolume(session.totalVolume), weightUnit.uppercased())
                    ])
                }

                ForEach(sortedLogs) { log in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            if let exercise = library.first(where: { $0.name == log.exerciseName }) {
                                NavigationLink { ExerciseDetailView(exercise: exercise) } label: { exerciseName(log) }
                                    .buttonStyle(.plain)
                            } else {
                                exerciseName(log)
                            }
                            Spacer()
                            Text(log.exerciseMuscleGroup.uppercased())
                                .font(VoltFont.mono(11)).tracking(0.4).foregroundStyle(VoltColor.labelSecondary)
                        }
                        VStack(spacing: 0) {
                            VoltRule(strong: true)
                            if log.completedSets.isEmpty {
                                Text("No completed sets")
                                    .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                VoltRule()
                            }
                            ForEach(Array(log.completedSets.enumerated()), id: \.element.id) { idx, set in
                                HStack(spacing: 12) {
                                    Text(String(format: "%02d", idx + 1))
                                        .font(VoltFont.mono(11)).foregroundStyle(VoltColor.labelTertiary)
                                        .frame(width: 18, alignment: .leading)
                                    Text(set.weight > 0 ? "\(voltWeight(set.weight)) \(weightUnit.uppercased()) × \(set.reps)" : "\(set.reps) reps")
                                        .font(VoltFont.mono(14)).foregroundStyle(VoltColor.label)
                                    Spacer()
                                    if records.contains(set.id) { VoltTag(text: "PR", gold: true) }
                                }
                                .padding(.vertical, 10)
                                VoltRule()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, VoltSpacing.gutter)
            .padding(.top, VoltSpacing.sm)
            .padding(.bottom, VoltSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(VoltColor.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exerciseName(_ log: ExerciseLog) -> some View {
        Text(log.exerciseName)
            .font(VoltFont.sans(20)).tracking(-0.5)
            .foregroundStyle(VoltColor.label)
    }
}

#Preview("History") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutSession.self, Exercise.self, Routine.self, configurations: config)
    let ctx = container.mainContext
    for (title, days, exName, muscle, sets) in [
        ("Push Day", 1, "Bench Press", "Chest", [(80.0,8),(85.0,6),(90.0,4)]),
        ("Pull Day", 3, "Deadlift", "Back",     [(100.0,5),(105.0,3)]),
        ("Leg Day",  7, "Squat",    "Legs",     [(80.0,5),(85.0,5),(90.0,3)])
    ] as [(String,Int,String,String,[(Double,Int)])] {
        let s = WorkoutSession(title: title)
        s.startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        s.endDate = s.startDate.addingTimeInterval(3600)
        ctx.insert(s)
        let log = ExerciseLog(exerciseName: exName, exerciseMuscleGroup: muscle)
        ctx.insert(log)
        for (i, (w, r)) in sets.enumerated() {
            let ws = WorkoutSet(orderIndex: i, weight: w, reps: r); ws.isCompleted = true
            ctx.insert(ws); log.sets.append(ws)
        }
        s.exerciseLogs = [log]
    }
    try? ctx.save()
    return HistoryView().modelContainer(container)
}
