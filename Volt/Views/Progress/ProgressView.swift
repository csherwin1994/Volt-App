import SwiftUI
import SwiftData
import Charts

// Progress tab. Layout follows Progress.dc.html on the App Screens canvas.
struct ProgressView: View {
    @Query(sort: \WorkoutSession.startDate) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @State private var selectedExercise: String?

    private var completed: [WorkoutSession] { sessions.filter { $0.endDate != nil } }

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private var weekStart: Date {
        Self.calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Self.calendar.startOfDay(for: Date())
    }

    private var thisWeek: [WorkoutSession] { completed.filter { $0.startDate >= weekStart } }

    /// Consecutive weeks with at least one workout, counting back from this week (or last week if this one is empty).
    private var streakWeeks: Int {
        let cal = Self.calendar
        var start = weekStart
        let trainedWeeks = Set(completed.compactMap { cal.dateInterval(of: .weekOfYear, for: $0.startDate)?.start })
        if !trainedWeeks.contains(start) { start = cal.date(byAdding: .weekOfYear, value: -1, to: start) ?? start }
        var count = 0
        while trainedWeeks.contains(start) {
            count += 1
            start = cal.date(byAdding: .weekOfYear, value: -1, to: start) ?? start
        }
        return count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    VoltScreenHeader(caption: "Last 8 weeks", title: "Progress")

                    SpecGrid(cells: [
                        ("This week", "\(thisWeek.count)", "OF 3"),
                        ("Lifted", voltVolume(thisWeek.reduce(0) { $0 + $1.totalVolume }), weightUnit.uppercased()),
                        ("Streak", "\(streakWeeks)", "WK")
                    ])

                    WeeklyVolumeChart(sessions: completed, weekStart: weekStart, unit: weightUnit)
                    FrequencyHeatmap(sessions: completed, weekStart: weekStart)
                    ExerciseProgressChart(sessions: completed, exercises: exercises, selectedExercise: $selectedExercise)
                }
                .padding(.horizontal, VoltSpacing.gutter)
                .padding(.top, VoltSpacing.md)
                .padding(.bottom, VoltSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .background(VoltColor.bg.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Weekly volume: square bars, this week in gold
struct WeeklyVolumeChart: View {
    let sessions: [WorkoutSession]
    let weekStart: Date
    let unit: String

    private struct Week: Identifiable {
        let id: Int
        let label: String
        let volume: Double
    }

    private var data: [Week] {
        let cal = Calendar.current
        return (0..<8).map { i in
            let ago = 7 - i
            let start = cal.date(byAdding: .day, value: -7 * ago, to: weekStart) ?? weekStart
            let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
            let vol = sessions.filter { $0.startDate >= start && $0.startDate < end }.reduce(0.0) { $0 + $1.totalVolume }
            return Week(id: i, label: ago == 0 ? "NOW" : start.formatted(.dateTime.day()), volume: vol)
        }
    }

    var body: some View {
        let weeks = data
        let peak = max(weeks.map(\.volume).max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VoltSectionTitle("Weekly volume · \(unit)")
                Spacer()
                Text("This week \(voltVolume(weeks.last?.volume ?? 0))".uppercased())
                    .font(VoltFont.mono(11, weight: .medium)).tracking(0.9)
                    .foregroundStyle(VoltColor.accentText)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(weeks) { week in
                    Rectangle()
                        .fill(week.id == 7 ? VoltColor.accent : VoltColor.bar)
                        .frame(height: week.volume > 0 ? max(2, 140 * week.volume / peak) : 0)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Week of \(week.label), \(Int(week.volume)) \(unit)")
                }
            }
            .frame(height: 150, alignment: .bottom)
            .overlay(alignment: .bottom) { VoltRule(strong: true) }
            HStack(spacing: 6) {
                ForEach(weeks) { week in
                    Text(week.label).font(VoltFont.mono(10)).foregroundStyle(VoltColor.labelTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Training days: five Monday-aligned weeks, gold when trained, outlined today
struct FrequencyHeatmap: View {
    let sessions: [WorkoutSession]
    let weekStart: Date

    private var days: [Date] {
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -28, to: weekStart) ?? weekStart
        return (0..<35).compactMap { cal.date(byAdding: .day, value: $0, to: from) }
    }

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let from = days.first ?? today
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VoltSectionTitle("Training days · 5 weeks")
                Spacer()
                VoltSectionTitle("\(sessions.filter { $0.startDate >= from }.count) workouts")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let trained = sessions.contains { cal.isDate($0.startDate, inSameDayAs: day) }
                    let future = day > today
                    Rectangle()
                        .fill(future ? Color.clear : (trained ? VoltColor.accent : VoltColor.surfaceHigh))
                        .frame(height: 30)
                        .overlay(Rectangle().strokeBorder(
                            cal.isDateInToday(day) ? VoltColor.label : (future ? VoltColor.border : .clear), lineWidth: 1))
                        .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(trained ? "trained" : "rest")")
                }
            }
        }
    }
}

// MARK: - Strength: heaviest set per workout for one exercise
struct ExerciseProgressChart: View {
    let sessions: [WorkoutSession]
    let exercises: [Exercise]
    @Binding var selectedExercise: String?
    @AppStorage("weightUnit") private var weightUnit = "kg"

    private struct Point: Identifiable {
        let id: Int
        let date: Date
        let maxWeight: Double
    }

    private var exerciseNames: [String] {
        Set(sessions.flatMap { $0.exerciseLogs }.filter { !$0.completedSets.isEmpty }.map(\.exerciseName)).sorted()
    }

    private var activeName: String {
        if let selectedExercise, exerciseNames.contains(selectedExercise) { return selectedExercise }
        return exerciseNames.contains("Bench Press") ? "Bench Press" : (exerciseNames.first ?? "")
    }

    private var points: [Point] {
        sessions.sorted { $0.startDate < $1.startDate }.compactMap { s -> (Date, Double)? in
            guard let log = s.exerciseLogs.first(where: { $0.exerciseName == activeName }),
                  let maxW = log.completedSets.map(\.weight).max(), maxW > 0
            else { return nil }
            return (s.startDate, maxW)
        }
        .enumerated().map { Point(id: $0.offset, date: $0.element.0, maxWeight: $0.element.1) }
    }

    var body: some View {
        let pts = points
        let best = pts.map(\.maxWeight).max() ?? 0
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VoltSectionTitle("Strength")
                Spacer()
                if !exerciseNames.isEmpty {
                    Menu {
                        Picker("Exercise", selection: Binding(get: { activeName }, set: { selectedExercise = $0 })) {
                            ForEach(exerciseNames, id: \.self) { Text($0).tag($0) }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(activeName.uppercased()).font(VoltFont.mono(12)).tracking(0.4).lineLimit(1)
                            Image(systemName: "chevron.down").font(.system(size: 11))
                        }
                        .foregroundStyle(VoltColor.label)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .overlay(Rectangle().strokeBorder(VoltColor.label, lineWidth: 1))
                    }
                    .accessibilityLabel("Exercise, \(activeName)")
                }
            }

            if exerciseNames.isEmpty {
                Text("Log a workout to start tracking strength.")
                    .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(voltWeight(best))
                        .font(VoltFont.display(56)).tracking(-2.4)
                        .foregroundStyle(VoltColor.label)
                    Group {
                        if pts.count > 1, let first = pts.first, let last = pts.last, last.maxWeight > first.maxWeight {
                            Text("\(weightUnit) · +\(voltWeight(last.maxWeight - first.maxWeight)) since \(first.date.formatted(.dateTime.day().month(.abbreviated)))")
                        } else {
                            Text(weightUnit)
                        }
                    }
                    .font(VoltFont.mono(11)).tracking(0.4).textCase(.uppercase)
                    .foregroundStyle(VoltColor.labelSecondary)
                }

                if pts.count < 2 {
                    Text("Log this exercise twice to see a trend.")
                        .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                } else {
                    let low = (pts.map(\.maxWeight).min() ?? 0) * 0.95
                    Chart(pts) { pt in
                        AreaMark(x: .value("Workout", pt.id), yStart: .value("Base", low), yEnd: .value(weightUnit, pt.maxWeight))
                            .foregroundStyle(VoltColor.accentDim)
                        LineMark(x: .value("Workout", pt.id), y: .value(weightUnit, pt.maxWeight))
                            .foregroundStyle(VoltColor.accentText)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                        if pt.id == pts.count - 1 {
                            PointMark(x: .value("Workout", pt.id), y: .value(weightUnit, pt.maxWeight))
                                .symbol(.square)
                                .symbolSize(140)
                                .foregroundStyle(VoltColor.accent)
                        }
                    }
                    .chartYScale(domain: low...(best * 1.02))
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                            AxisGridLine().foregroundStyle(VoltColor.border)
                            AxisValueLabel().foregroundStyle(VoltColor.labelTertiary).font(VoltFont.mono(10))
                        }
                    }
                    .frame(height: 120)
                    .accessibilityLabel("Heaviest \(activeName) set per workout")
                }
            }
        }
    }
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
