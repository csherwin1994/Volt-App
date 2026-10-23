import SwiftUI
import SwiftData

struct WorkoutTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var workoutVM = ActiveWorkoutViewModel()
    @State private var showingActiveWorkout = false
    @State private var showingRoutinePicker = false
    @State private var showingCreateRoutine = false
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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VoltColor.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 36) {
                        header
                        WeekStrip(sessions: completed)
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
                    ActiveWorkoutBar(vm: workoutVM)
                        .onTapGesture { showingActiveWorkout = true }
                        .padding(.horizontal, VoltSpacing.md)
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
        }
        .environment(workoutVM)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VoltColor.labelSecondary)
            Text("\(greeting),\n\(username)")
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.6)
                .lineSpacing(2)
                .foregroundStyle(VoltColor.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Today's suggestion (the hero)
    private func suggestionSection(_ rec: WorkoutRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                VoltSectionTitle(workoutVM.isActive ? "In progress" : "Today")
                Text(workoutVM.isActive ? (workoutVM.session?.title ?? "Workout") : rec.title)
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(VoltColor.label)
                if !workoutVM.isActive {
                    Text(rec.reason)
                        .font(.system(size: 15))
                        .foregroundStyle(VoltColor.labelSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !workoutVM.isActive && !rec.exercises.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rec.exercises.prefix(6).enumerated()), id: \.offset) { index, planned in
                        if index > 0 { Divider().overlay(VoltColor.border) }
                        PlannedExerciseRow(planned: planned, unit: weightUnit)
                    }
                }
            }

            VStack(spacing: 4) {
                if workoutVM.isActive {
                    VoltButton("Resume Workout") { showingActiveWorkout = true }
                } else if !rec.exercises.isEmpty {
                    VoltButton(rec.buttonLabel) {
                        workoutVM.startFromRecommendation(rec, routines: routines, context: modelContext)
                        showingActiveWorkout = true
                    }
                }
                if !workoutVM.isActive {
                    Button("Start Empty Workout") {
                        workoutVM.startWorkout(context: modelContext)
                        showingActiveWorkout = true
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VoltColor.label)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    // MARK: - Routines
    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VoltSectionTitle("Your routines")
                Spacer()
                Button("New") { showingCreateRoutine = true }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VoltColor.accent)
            }

            if routines.isEmpty {
                Text("Save a workout plan to start it with one tap.")
                    .font(.system(size: 15))
                    .foregroundStyle(VoltColor.labelSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                        if index > 0 { Divider().overlay(VoltColor.border) }
                        RoutineListRow(routine: routine) {
                            guard !workoutVM.isActive else { showingActiveWorkout = true; return }
                            workoutVM.startFromRoutine(routine, context: modelContext)
                            showingActiveWorkout = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Last workout
    private func lastWorkoutSection(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VoltSectionTitle("Last workout")
            NavigationLink { WorkoutDetailView(session: session) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.title)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(VoltColor.label)
                        Text("\(session.startDate.formatted(.relative(presentation: .named))) · \(session.formattedDuration) · \(Self.volumeText(session.totalVolume, unit: weightUnit))")
                            .font(VoltFont.mono(14, weight: .regular))
                            .foregroundStyle(VoltColor.labelSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VoltColor.labelTertiary)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    static func volumeText(_ volume: Double, unit: String) -> String {
        volume >= 1000 ? String(format: "%.1fk \(unit)", volume / 1000) : String(format: "%.0f \(unit)", volume)
    }
}

// MARK: - A planned exercise with today's target
struct PlannedExerciseRow: View {
    let planned: PlannedExercise
    let unit: String

    private var target: String {
        let base = "\(planned.sets) × \(planned.reps)"
        guard let weight = planned.weight, weight > 0 else { return base }
        return "\(base) · \(weight.formatted()) \(unit)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(planned.name)
                .font(.system(size: 16))
                .foregroundStyle(VoltColor.label)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(target)
                .font(VoltFont.mono(15, weight: .regular))
                .foregroundStyle(VoltColor.labelSecondary)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityHint(planned.note)
    }
}

// MARK: - Week strip (Mon–Sun, filled on training days)
struct WeekStrip: View {
    let sessions: [WorkoutSession]

    private var days: [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let trained = sessions.contains { Calendar.current.isDate($0.startDate, inSameDayAs: day) }
                let isToday = Calendar.current.isDateInToday(day)
                VStack(spacing: 6) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isToday ? VoltColor.label : VoltColor.labelTertiary)
                    Text(day.formatted(.dateTime.day()))
                        .font(VoltFont.mono(14, weight: .medium))
                        .foregroundStyle(trained ? VoltColor.onInk : VoltColor.labelSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(trained ? VoltColor.ink : VoltColor.surface))
                        .overlay(Circle().stroke(VoltColor.ink, lineWidth: isToday && !trained ? 1.5 : 0))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))), \(trained ? "trained" : "rest day")")
            }
        }
    }
}

// MARK: - Floating active bar
struct ActiveWorkoutBar: View {
    let vm: ActiveWorkoutViewModel
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(VoltColor.success)
                .frame(width: 8, height: 8)
                .opacity(pulse ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.session?.title ?? "Workout")
                    .font(.system(size: 15, weight: .semibold))
                Text(vm.formattedElapsed)
                    .font(VoltFont.mono(13, weight: .regular))
                    .opacity(0.7)
            }
            Spacer()
            Text("Resume")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(VoltColor.onInk)
        .padding(.horizontal, VoltSpacing.md)
        .padding(.vertical, 12)
        .background(VoltColor.ink)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Routine row
struct RoutineListRow: View {
    let routine: Routine
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(VoltColor.label)
                    .lineLimit(1)
                Group {
                    if let last = routine.lastUsedAt {
                        Text("\(routine.exerciseCount) exercises · \(last.formatted(.relative(presentation: .named)))")
                    } else {
                        Text("\(routine.exerciseCount) exercises")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(VoltColor.labelSecondary)
            }
            Spacer()
            Button("Start", action: onStart)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VoltColor.label)
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(VoltColor.surfaceHigh)
                .clipShape(Capsule())
                .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
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
