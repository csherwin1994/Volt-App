import SwiftUI
import SwiftData
import Charts

struct ProgressView: View {
    @Query(sort: \WorkoutSession.startDate) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var selectedExercise: String?

    private var completed: [WorkoutSession] { sessions.filter { $0.endDate != nil } }

    var body: some View {
        NavigationStack {
            ZStack {
                VoltColor.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: VoltSpacing.xl) {
                        WeeklyVolumeChart(sessions: completed)
                            .voltSection("Weekly Volume")

                        FrequencyHeatmap(sessions: completed)
                            .voltSection("Last 30 Days")

                        ExerciseProgressChart(
                            sessions: completed,
                            exercises: exercises,
                            selectedExercise: $selectedExercise
                        )
                        .voltSection("Exercise Progress")
                    }
                    .padding(.top, VoltSpacing.md)
                    .padding(.bottom, VoltSpacing.xxl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Progress")
        }
    }
}

// MARK: - Weekly volume bar chart
struct WeeklyVolumeChart: View {
    let sessions: [WorkoutSession]

    private struct Week: Identifiable {
        let id = UUID()
        let label: String
        let volume: Double
    }

    private var data: [Week] {
        let cal = Calendar.current
        return (0..<8).reversed().compactMap { ago -> Week? in
            guard let start = cal.date(byAdding: .weekOfYear, value: -ago, to: Date()),
                  let interval = cal.dateInterval(of: .weekOfYear, for: start)
            else { return nil }
            let vol = sessions.filter { interval.contains($0.startDate) }
                .reduce(0.0) { $0 + $1.totalVolume }
            let fmt = DateFormatter(); fmt.dateFormat = ago == 0 ? "'Now'" : "M/d"
            return Week(label: fmt.string(from: interval.start), volume: vol)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if data.allSatisfy({ $0.volume == 0 }) {
                emptyChart(message: "Complete workouts to see weekly volume trends")
            } else {
                Chart(data) { week in
                    BarMark(x: .value("Week", week.label), y: .value("Volume", week.volume))
                        // Highlight the current week; earlier weeks stay grey
                        .foregroundStyle(week.label == data.last?.label ? VoltColor.accent : VoltColor.bar)
                        .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine().foregroundStyle(VoltColor.border)
                        AxisValueLabel()
                            .foregroundStyle(VoltColor.labelTertiary)
                            .font(.system(size: 10))
                    }
                }
                .chartXAxis {
                    AxisMarks { AxisValueLabel().foregroundStyle(VoltColor.labelTertiary).font(.system(size: 10)) }
                }
                .frame(height: 160)
                .padding(VoltSpacing.md)
            }
        }
        .background(VoltColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
        .padding(.horizontal, VoltSpacing.md)
    }
}

// MARK: - 30-day heatmap
struct FrequencyHeatmap: View {
    let sessions: [WorkoutSession]

    private struct Day: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }

    private var days: [Day] {
        let cal = Calendar.current
        return (0..<30).reversed().compactMap { ago -> Day? in
            guard let d = cal.date(byAdding: .day, value: -ago, to: Date()),
                  let iv = cal.dateInterval(of: .day, for: d)
            else { return nil }
            let count = sessions.filter { iv.contains($0.startDate) }.count
            return Day(date: iv.start, count: count)
        }
    }

    private var max: Int { days.map(\.count).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: VoltSpacing.sm) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(day.count == 0
                              ? VoltColor.surfaceHigh
                              : VoltColor.accent.opacity(0.2 + 0.8 * (Double(day.count) / Double(max))))
                        .frame(height: 26)
                }
            }
            HStack {
                Circle().fill(VoltColor.surfaceHigh).frame(width: 8, height: 8)
                Text("Rest").font(.system(size: 10)).foregroundStyle(VoltColor.labelTertiary)
                Spacer()
                Circle().fill(VoltColor.accent.opacity(0.6)).frame(width: 8, height: 8)
                Text("Trained").font(.system(size: 10)).foregroundStyle(VoltColor.labelTertiary)
            }
        }
        .padding(VoltSpacing.md)
        .background(VoltColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
        .padding(.horizontal, VoltSpacing.md)
    }
}

// MARK: - Per-exercise progress
struct ExerciseProgressChart: View {
    let sessions: [WorkoutSession]
    let exercises: [Exercise]
    @Binding var selectedExercise: String?
    @AppStorage("weightUnit") private var weightUnit = "kg"

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let maxWeight: Double
    }

    private var exerciseNames: [String] {
        let used = Set(sessions.flatMap { $0.exerciseLogs }.map(\.exerciseName))
        return exercises.filter { used.contains($0.name) }.map(\.name).sorted()
    }

    private var activeName: String { selectedExercise ?? exerciseNames.first ?? "" }

    private var points: [Point] {
        sessions.compactMap { s in
            guard let log = s.exerciseLogs.first(where: { $0.exerciseName == activeName }),
                  let maxW = log.sets.filter(\.isCompleted).map(\.weight).max(),
                  maxW > 0
            else { return nil }
            return Point(date: s.startDate, maxWeight: maxW)
        }
        .sorted { $0.date < $1.date }
    }

    private var pr: Double { points.map(\.maxWeight).max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: VoltSpacing.md) {
            if exerciseNames.isEmpty {
                emptyChart(message: "Log workouts to track your strength progress per exercise")
                    .padding(.horizontal, VoltSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(exerciseNames, id: \.self) { name in
                            FilterChip(label: name, isSelected: activeName == name) {
                                selectedExercise = name
                            }
                        }
                    }
                    .padding(.horizontal, VoltSpacing.md)
                }

                VStack(alignment: .leading, spacing: VoltSpacing.md) {
                    if pr > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                            Text("PR: \(String(format: "%.1f \(weightUnit)", pr))")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(VoltColor.label)
                            Spacer()
                            Text("\(points.count) sessions")
                                .font(.caption)
                                .foregroundStyle(VoltColor.labelSecondary)
                        }
                    }

                    if points.count < 2 {
                        Text("Log at least 2 sessions with this exercise to see a trend")
                            .font(.caption)
                            .foregroundStyle(VoltColor.labelTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, VoltSpacing.lg)
                    } else {
                        Chart(points) { pt in
                            AreaMark(x: .value("Date", pt.date), y: .value("kg", pt.maxWeight))
                                .foregroundStyle(VoltGradient.brandSubtle)
                            LineMark(x: .value("Date", pt.date), y: .value("kg", pt.maxWeight))
                                .foregroundStyle(VoltColor.accent)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            PointMark(x: .value("Date", pt.date), y: .value("kg", pt.maxWeight))
                                .foregroundStyle(VoltColor.accent)
                                .symbolSize(25)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) {
                                AxisGridLine().foregroundStyle(VoltColor.border)
                                AxisValueLabel()
                                    .foregroundStyle(VoltColor.labelTertiary)
                                    .font(.system(size: 10))
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, points.count / 4))) {
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                    .foregroundStyle(VoltColor.labelTertiary)
                                    .font(.system(size: 10))
                            }
                        }
                        .frame(height: 160)
                    }
                }
                .padding(VoltSpacing.md)
                .background(VoltColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
                .padding(.horizontal, VoltSpacing.md)
            }
        }
    }
}

// MARK: - Shared empty chart
private func emptyChart(message: String) -> some View {
    VStack(spacing: VoltSpacing.md) {
        Image(systemName: "chart.line.uptrend.xyaxis")
            .font(.system(size: 32))
            .foregroundStyle(VoltColor.labelTertiary)
        Text(message)
            .font(.subheadline)
            .foregroundStyle(VoltColor.labelTertiary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(VoltSpacing.xl)
    .background(VoltColor.surface)
    .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
    .padding(.horizontal, VoltSpacing.md)
}

#Preview("Progress") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutSession.self, Exercise.self, Routine.self, configurations: config)
    let ctx = container.mainContext
    DataManager.seedExercisesIfNeeded(context: ctx)
    for (i, w) in [60.0,65,67.5,70,72.5,75,77.5].enumerated() {
        let s = WorkoutSession(title: "Push Day")
        s.startDate = Calendar.current.date(byAdding: .day, value: -(7-i)*5, to: Date())!
        s.endDate = s.startDate.addingTimeInterval(3600)
        ctx.insert(s)
        let log = ExerciseLog(exerciseName: "Bench Press", exerciseMuscleGroup: "Chest")
        ctx.insert(log)
        let ws = WorkoutSet(orderIndex: 0, weight: w, reps: 5); ws.isCompleted = true
        ctx.insert(ws); log.sets.append(ws); s.exerciseLogs = [log]
    }
    try? ctx.save()
    return ProgressView().modelContainer(container)
}
