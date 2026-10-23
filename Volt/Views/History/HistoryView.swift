import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext

    private var completed: [WorkoutSession] { sessions.filter { $0.endDate != nil } }

    var body: some View {
        NavigationStack {
            ZStack {
                VoltColor.bg.ignoresSafeArea()

                if completed.isEmpty {
                    EmptyStateView(
                        icon: "clock",
                        title: "No Workouts Yet",
                        message: "Your completed workouts will appear here once you finish your first session."
                    )
                } else {
                    List {
                        ForEach(groupedByMonth, id: \.key) { month, workouts in
                            Section {
                                ForEach(workouts) { session in
                                    NavigationLink {
                                        WorkoutDetailView(session: session)
                                    } label: {
                                        WorkoutHistoryRow(session: session)
                                    }
                                    .listRowBackground(VoltColor.surface)
                                    .listRowSeparatorTint(VoltColor.border)
                                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                }
                                .onDelete { offsets in
                                    offsets.forEach { modelContext.delete(workouts[$0]) }
                                    try? modelContext.save()
                                }
                            } header: {
                                Text(month)
                                    .font(VoltFont.sans(12, weight: .medium))
                                    .foregroundStyle(VoltColor.labelSecondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
        }
    }

    private var groupedByMonth: [(key: String, value: [WorkoutSession])] {
        let fmt = DateFormatter(); fmt.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: completed) { fmt.string(from: $0.startDate) }
        return grouped.sorted { ($0.value.first?.startDate ?? .distantPast) > ($1.value.first?.startDate ?? .distantPast) }
    }
}

// MARK: - Row
struct WorkoutHistoryRow: View {
    let session: WorkoutSession
    @AppStorage("weightUnit") private var weightUnit = "kg"

    private var muscles: [Exercise.MuscleGroup] {
        Set(session.exerciseLogs.map(\.exerciseMuscleGroup))
            .compactMap { Exercise.MuscleGroup(rawValue: $0) }
            .sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VoltColor.label)
                    Text(session.startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(VoltColor.labelSecondary)
                }
                Spacer()
                Text(session.formattedDuration)
                    .font(VoltFont.mono(12))
                    .foregroundStyle(VoltColor.labelSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(VoltColor.surfaceHigh)
                    .clipShape(Rectangle())
            }

            HStack(spacing: 14) {
                historyPill("\(session.totalSets)", label: "sets", icon: "dumbbell")
                historyPill(
                    session.totalVolume >= 1000
                        ? String(format: "%.1fk \(weightUnit)", session.totalVolume/1000)
                        : String(format: "%.0f \(weightUnit)", session.totalVolume),
                    label: "vol", icon: "scalemass"
                )
                historyPill("\(session.exerciseLogs.count)", label: "exercises", icon: "list.bullet")
            }

            if !muscles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) { ForEach(muscles, id: \.self) { MuscleBadge(group: $0) } }
                }
            }
        }
    }

    private func historyPill(_ value: String, label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(VoltFont.sans(9))
            Text(value).font(VoltFont.sans(11, weight: .medium))
        }
        .foregroundStyle(VoltColor.labelSecondary)
    }
}

// MARK: - Detail
struct WorkoutDetailView: View {
    let session: WorkoutSession
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @Query(sort: \WorkoutSession.startDate) private var allSessions: [WorkoutSession]

    /// Sets in this workout that beat every earlier workout for that exercise.
    private var recordSetIDs: Set<UUID> {
        PersonalRecords.recordSetIDs(in: session, history: allSessions)
    }

    private var sortedLogs: [ExerciseLog] {
        session.exerciseLogs.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        ZStack {
            VoltColor.bg.ignoresSafeArea()
            List {
                // Summary strip
                Section {
                    HStack(spacing: 0) {
                        SummaryCell(value: session.formattedDuration, label: "Duration", icon: "clock.fill", color: VoltColor.labelSecondary)
                        Divider().frame(height: 40)
                        SummaryCell(value: "\(session.totalSets)", label: "Sets", icon: "dumbbell.fill", color: VoltColor.labelSecondary)
                        Divider().frame(height: 40)
                        SummaryCell(
                            value: session.totalVolume >= 1000
                                ? String(format: "%.1fk", session.totalVolume/1000)
                                : String(format: "%.0f", session.totalVolume),
                            label: "Volume \(weightUnit)",
                            icon: "scalemass.fill",
                            color: VoltColor.labelSecondary
                        )
                    }
                }
                .listRowBackground(VoltColor.surface)
                .listRowSeparatorTint(VoltColor.border)

                // Exercises
                let records = recordSetIDs
                ForEach(sortedLogs) { log in
                    Section {
                        ForEach(Array(log.completedSets.enumerated()), id: \.element.id) { idx, set in
                            HStack {
                                Text("Set \(idx + 1)")
                                    .font(.subheadline)
                                    .foregroundStyle(VoltColor.labelSecondary)
                                if records.contains(set.id) {
                                    Label("PR", systemImage: "trophy.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(VoltColor.accent)
                                }
                                Spacer()
                                Text(set.weight > 0
                                     ? String(format: "%.1f \(weightUnit) × %d", set.weight, set.reps)
                                     : "\(set.reps) reps")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(VoltColor.label)
                            }
                            .listRowBackground(VoltColor.surface)
                            .listRowSeparatorTint(VoltColor.border)
                        }
                        if log.completedSets.isEmpty {
                            Text("No completed sets")
                                .font(.subheadline)
                                .foregroundStyle(VoltColor.labelTertiary)
                                .listRowBackground(VoltColor.surface)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Text(log.exerciseName)
                                .font(VoltFont.sans(13, weight: .medium))
                                .foregroundStyle(VoltColor.label)
                                .textCase(nil)
                            if let g = Exercise.MuscleGroup(rawValue: log.exerciseMuscleGroup) {
                                MuscleBadge(group: g)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SummaryCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption2).foregroundStyle(color)
            Text(value).font(VoltFont.sans(15, weight: .medium)).foregroundStyle(VoltColor.label)
            Text(label).font(VoltFont.sans(10)).foregroundStyle(VoltColor.labelTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
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
