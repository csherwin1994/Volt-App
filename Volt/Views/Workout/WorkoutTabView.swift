import SwiftUI
import SwiftData

// Train tab. Layout follows Main.dc.html on the App Screens canvas.
struct WorkoutTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var workoutVM = ActiveWorkoutViewModel()
    @State private var showingActiveWorkout = false
    @State private var showingRoutinePicker = false
    @State private var showingCreateRoutine = false
    @State private var selectedDay: SelectedDay?
    @AppStorage("username") private var username = "Athlete"
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @AppStorage("unavailableEquipment") private var unavailableEquipment = ""

    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var library: [Exercise]

    private var completed: [WorkoutSession] { sessions.filter { $0.endDate != nil } }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var lastWorkout: WorkoutSession? { completed.first }

    private var recommendation: WorkoutRecommendation {
        // Reading the two preferences here makes the view refresh when they change in Profile
        _ = (weightUnit, unavailableEquipment)
        return WorkoutRecommendationEngine.recommend(
            sessions: completed, routines: routines, library: library,
            settings: .fromPreferences()
        )
    }

    private func exercise(named name: String) -> Exercise? { library.first { $0.name == name } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VoltColor.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 44) {
                        header
                        WeekStrip(sessions: completed) { selectedDay = SelectedDay(date: $0) }
                        suggestionSection(recommendation)
                        routinesSection
                        if let last = lastWorkout { lastWorkoutSection(last) }
                    }
                    .padding(.horizontal, VoltSpacing.gutter)
                    .padding(.top, VoltSpacing.md)
                    .padding(.bottom, workoutVM.isActive ? 104 : VoltSpacing.xxl)
                }
                .scrollIndicators(.hidden)

                // Floating bar while a workout is minimised
                if workoutVM.isActive {
                    Button { showingActiveWorkout = true } label: { ActiveWorkoutBar(vm: workoutVM) }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.bottom, VoltSpacing.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingActiveWorkout) {
                ActiveWorkoutView(vm: workoutVM)
            }
            .sheet(isPresented: $showingRoutinePicker) {
                RoutinePickerSheet(workoutVM: workoutVM, showingActiveWorkout: $showingActiveWorkout)
            }
            .sheet(isPresented: $showingCreateRoutine) { CreateRoutineView() }
            .sheet(item: $selectedDay) { selected in
                let rec = recommendation
                DaySheet(
                    day: selected.date,
                    sessions: completed,
                    suggestion: workoutVM.isActive || rec.exercises.isEmpty ? nil : rec.title,
                    isActive: workoutVM.isActive
                ) { start in
                    selectedDay = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if start { workoutVM.startFromRecommendation(rec, routines: routines, context: modelContext) }
                        showingActiveWorkout = true
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .environment(workoutVM)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(Date().voltCaption.uppercased())
                    .font(VoltFont.mono(11)).tracking(0.9)
                    .foregroundStyle(VoltColor.labelSecondary)
                Spacer()
                AppearanceToggle()
            }
            Text("\(greeting), \(username).")
                .font(VoltFont.sans(40)).tracking(-1.4)
                .foregroundStyle(VoltColor.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Today's suggestion (the hero)
    private func suggestionSection(_ rec: WorkoutRecommendation) -> some View {
        let active = workoutVM.isActive
        let lead = rec.exercises.first
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                VoltSectionTitle(active ? "In progress" : "Today · suggested")
                Text(active ? (workoutVM.session?.title ?? "Workout") : rec.title)
                    .font(VoltFont.sans(28)).tracking(-0.8)
                    .foregroundStyle(VoltColor.label)
                if !active {
                    Text(rec.reason)
                        .font(VoltFont.sans(15)).lineSpacing(4)
                        .foregroundStyle(VoltColor.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Hero numeral: today's top set on the first exercise
            if !active, let lead, let weight = lead.weight, weight > 0 {
                NavigationLink {
                    if let ex = exercise(named: lead.name) { ExerciseDetailView(exercise: ex) }
                } label: {
                    HStack(alignment: .bottom) {
                        Text(voltWeight(weight))
                            .font(VoltFont.display(88)).tracking(-3.5)
                            .foregroundStyle(VoltColor.label)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .frame(height: 76, alignment: .bottom)
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 6) {
                            if let up = lead.increase, up > 0 {
                                VoltTag(text: "+\(voltWeight(up)) \(weightUnit)", gold: true)
                            }
                            Text("\(lead.name) top set".uppercased())
                                .font(VoltFont.mono(11)).tracking(0.4)
                                .foregroundStyle(VoltColor.labelSecondary)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.bottom, 4)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(lead.name), top set \(voltWeight(weight)) \(weightUnit)")
            }

            if !active && !rec.exercises.isEmpty {
                VStack(spacing: 0) {
                    VoltRule(strong: true)
                    ForEach(Array(rec.exercises.prefix(6).enumerated()), id: \.offset) { index, planned in
                        NavigationLink {
                            if let ex = exercise(named: planned.name) { ExerciseDetailView(exercise: ex) }
                        } label: {
                            PlannedExerciseRow(index: index, planned: planned)
                        }
                        .buttonStyle(.plain)
                        VoltRule()
                    }
                }
            }

            VStack(spacing: 8) {
                if active {
                    VoltButton("Resume Workout") { showingActiveWorkout = true }
                } else {
                    if !rec.exercises.isEmpty {
                        VoltButton(rec.buttonLabel) {
                            workoutVM.startFromRecommendation(rec, routines: routines, context: modelContext)
                            showingActiveWorkout = true
                        }
                    }
                    VoltButton("Start Empty Workout", style: .secondary) {
                        workoutVM.startWorkout(context: modelContext)
                        showingActiveWorkout = true
                    }
                }
            }
        }
    }

    // MARK: - Routines
    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VoltSectionTitle("Your routines")
                Spacer()
                VoltTextLink("New") { showingCreateRoutine = true }
                    .accessibilityLabel("New routine")
            }
            .frame(height: 20)

            if routines.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    VoltRule(strong: true)
                    Text("No routines yet.").font(VoltFont.sans(24)).tracking(-0.6).foregroundStyle(VoltColor.label)
                        .padding(.top, 14)
                    Text("Save a workout plan and start it with one tap next time.")
                        .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                }
            } else {
                VStack(spacing: 0) {
                    VoltRule(strong: true)
                    ForEach(routines) { routine in
                        RoutineListRow(routine: routine) {
                            guard !workoutVM.isActive else { showingActiveWorkout = true; return }
                            workoutVM.startFromRoutine(routine, context: modelContext)
                            showingActiveWorkout = true
                        }
                        VoltRule()
                    }
                }
            }
        }
    }

    // MARK: - Last workout
    private func lastWorkoutSection(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VoltSectionTitle("Last workout · \(session.title) · \(session.startDate.formatted(.dateTime.weekday(.abbreviated)))")
            NavigationLink { WorkoutDetailView(session: session) } label: {
                SpecGrid(cells: [
                    ("Time", "\(Int(session.duration / 60))", "MIN"),
                    ("Sets", "\(session.totalSets)", ""),
                    ("Volume", voltVolume(session.totalVolume), weightUnit.uppercased())
                ])
            }
            .buttonStyle(.plain)
        }
    }

    static func volumeText(_ volume: Double, unit: String) -> String {
        volume >= 1000 ? String(format: "%.1fk \(unit)", volume / 1000) : String(format: "%.0f \(unit)", volume)
    }
}

// MARK: - A planned exercise with today's target ("01  Squat   3 × 6 · 102.5")
struct PlannedExerciseRow: View {
    let index: Int
    let planned: PlannedExercise

    private var target: String {
        let base = "\(planned.sets) × \(planned.reps)"
        guard let weight = planned.weight, weight > 0 else { return base }
        return "\(base) · \(voltWeight(weight))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(VoltFont.mono(11)).foregroundStyle(VoltColor.labelTertiary)
                .frame(width: 18, alignment: .leading)
            Text(planned.name)
                .font(VoltFont.sans(17)).foregroundStyle(VoltColor.label)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(target)
                .font(VoltFont.mono(14)).foregroundStyle(VoltColor.labelSecondary)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(planned.note)
    }
}

// MARK: - Week strip: square cells, gold on training days, outlined today
struct WeekStrip: View {
    let sessions: [WorkoutSession]
    var onSelect: (Date) -> Void = { _ in }

    private var days: [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                let trained = sessions.contains { Calendar.current.isDate($0.startDate, inSameDayAs: day) }
                let isToday = Calendar.current.isDateInToday(day)
                Button { onSelect(day) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(VoltFont.mono(10)).tracking(0.8)
                        .foregroundStyle(isToday ? VoltColor.label : VoltColor.labelTertiary)
                    Text(day.formatted(.dateTime.day()))
                        .font(VoltFont.mono(15))
                        .foregroundStyle(trained ? VoltColor.onAccent : (isToday ? VoltColor.label : VoltColor.labelSecondary))
                        .padding(6)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottomLeading)
                        .background(trained ? VoltColor.accent : (isToday ? Color.clear : VoltColor.surfaceHigh))
                        .overlay(Rectangle().strokeBorder(VoltColor.label, lineWidth: isToday && !trained ? 1 : 0))
                }
                .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))), \(trained ? "trained" : "rest day")")
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}

// MARK: - Floating active bar
struct ActiveWorkoutBar: View {
    let vm: ActiveWorkoutViewModel
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(VoltColor.accent)
                .frame(width: 8, height: 8)
                .opacity(pulse ? 0.3 : 1)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.session?.title ?? "Workout")
                    .font(VoltFont.sans(17))
                Text(vm.formattedElapsed)
                    .font(VoltFont.mono(11))
                    .opacity(0.65)
            }
            Spacer()
            HStack(spacing: 8) {
                Text("Resume").font(VoltFont.sans(17))
                Image(systemName: "arrow.right").font(.system(size: 14))
            }
        }
        .foregroundStyle(VoltColor.onInk)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(VoltColor.ink)
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Routine row
struct RoutineListRow: View {
    let routine: Routine
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink { RoutineDetailView(routine: routine) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(VoltFont.sans(17)).foregroundStyle(VoltColor.label)
                        .lineLimit(1)
                    Group {
                        if let last = routine.lastUsedAt {
                            Text("\(routine.exerciseCount) exercises · \(last.formatted(.relative(presentation: .named)))")
                        } else {
                            Text("\(routine.exerciseCount) exercises")
                        }
                    }
                    .font(VoltFont.mono(11)).tracking(0.4).textCase(.uppercase)
                    .foregroundStyle(VoltColor.labelSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VoltOutlineButton(title: "Start", action: onStart)
                .accessibilityLabel("Start \(routine.name)")
        }
        .padding(.vertical, 13)
    }
}

// MARK: - Routine picker sheet
struct RoutinePickerSheet: View {
    let workoutVM: ActiveWorkoutViewModel
    @Binding var showingActiveWorkout: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var routines: [Routine]
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ZStack {
                VoltColor.bg.ignoresSafeArea()
                if routines.isEmpty {
                    EmptyStateView(
                        icon: "repeat",
                        title: "No Routines",
                        message: "Create a routine to quick-start structured workouts.",
                        actionTitle: "Create Routine",
                        action: { showingCreate = true }
                    )
                } else {
                    List(routines) { routine in
                        Button {
                            workoutVM.startFromRoutine(routine, context: modelContext)
                            dismiss()
                            showingActiveWorkout = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routine.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(VoltColor.label)
                                Text("\(routine.exerciseCount) exercises")
                                    .font(.caption)
                                    .foregroundStyle(VoltColor.labelSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(VoltColor.surface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Choose a Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(VoltColor.labelSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus").foregroundStyle(VoltColor.accent)
                    }
                }
            }
            .sheet(isPresented: $showingCreate) { CreateRoutineView() }
        }
    }
}

#Preview("Workout Tab") {
    WorkoutTabView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self, Routine.self], inMemory: true)
        .environment(SupabaseManager.shared)
}

// MARK: - Tapping a day (Train week strip, Progress training days)

struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}

/// The day's workouts, a rest-day note, or (today) the suggested session with a Start button.
struct DaySheet: View {
    let day: Date
    let sessions: [WorkoutSession]
    var suggestion: String? = nil
    var isActive = false
    /// `true` when the person tapped Start on the suggestion, `false` to resume the running workout.
    var onStart: ((Bool) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit = "kg"

    private var dayWorkouts: [WorkoutSession] {
        sessions.filter { Calendar.current.isDate($0.startDate, inSameDayAs: day) }.sorted { $0.startDate < $1.startDate }
    }
    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var isFuture: Bool { day > Date() && !isToday }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        VoltSectionTitle("\(isFuture ? "Coming up" : (isToday ? "Today" : "Past")) · \(dayWorkouts.count) \(dayWorkouts.count == 1 ? "workout" : "workouts")")
                        Text(!dayWorkouts.isEmpty ? "Trained." : (isFuture ? "Nothing planned." : "Rest day."))
                            .font(VoltFont.sans(40)).tracking(-1.4)
                            .foregroundStyle(VoltColor.label)
                    }

                    if !dayWorkouts.isEmpty {
                        VStack(spacing: 0) {
                            VoltRule(strong: true)
                            ForEach(dayWorkouts) { session in
                                NavigationLink { WorkoutDetailView(session: session) } label: {
                                    WorkoutHistoryRow(session: session)
                                }
                                .buttonStyle(.plain)
                                VoltRule()
                            }
                        }
                    } else if !isToday {
                        Text(isFuture
                             ? "Your suggestion for this day is chosen on the day, from what you have trained since."
                             : "No workout was logged on this day.")
                            .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                    }

                    if isToday, let onStart {
                        if isActive {
                            VoltButton("Resume Workout") { onStart(false); }
                        } else if let suggestion {
                            Text("Suggested: \(suggestion)")
                                .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                            VoltButton("Start \(suggestion)") { onStart(true) }
                        }
                    }
                }
                .padding(VoltSpacing.gutter)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(VoltColor.bg.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                        .font(VoltFont.mono(11)).tracking(0.9).foregroundStyle(VoltColor.labelSecondary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 18)).frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(VoltColor.label)
                    .accessibilityLabel("Close")
                }
                .padding(.leading, VoltSpacing.gutter).padding(.trailing, 8).padding(.top, 8)
                .background(VoltColor.bg)
            }
            .navigationBarHidden(true)
        }
    }
}
