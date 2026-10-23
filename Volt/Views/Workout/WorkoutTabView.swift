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

    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]

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
        WorkoutRecommendationEngine.recommend(from: completed, routines: routines)
    }

    /// The routine the recommendation refers to, if it names one.
    private var recommendedRoutine: Routine? {
        routines.first { $0.name == recommendation.title }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VoltColor.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        WeekStrip(sessions: completed)
                            .padding(.horizontal, VoltSpacing.gutter)
                        startButton
                        recommendationSection
                        routinesSection
                        if let last = lastWorkout { lastWorkoutSection(last) }
                    }
                    .padding(.bottom, workoutVM.isActive ? 96 : VoltSpacing.xxl)
                }
                .scrollIndicators(.hidden)

                // Floating bar while a workout is minimised
                if workoutVM.isActive {
                    ActiveWorkoutBar(vm: workoutVM)
                        .onTapGesture { showingActiveWorkout = true }
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
        }
        .environment(workoutVM)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VoltColor.labelSecondary)
            Text("\(greeting), \(username)")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(VoltColor.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, VoltSpacing.gutter)
        .padding(.top, VoltSpacing.md)
    }

    // MARK: - Start
    private var startButton: some View {
        VoltButton(
            workoutVM.isActive ? "Resume Workout" : "Start Empty Workout",
            icon: workoutVM.isActive ? nil : "plus"
        ) {
            guard !workoutVM.isActive else { showingActiveWorkout = true; return }
            workoutVM.startWorkout(context: modelContext)
            showingActiveWorkout = true
        }
        .padding(.horizontal, VoltSpacing.gutter)
    }

    // MARK: - Recommendation
    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(VoltColor.label)
                Text(recommendation.reason)
                    .font(.system(size: 14))
                    .foregroundStyle(VoltColor.labelSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                ForEach(recommendation.muscleGroups.prefix(3), id: \.self) { group in
                    if let g = Exercise.MuscleGroup(rawValue: group) { MuscleBadge(group: g) }
                }
            }
            VoltButton(
                recommendedRoutine.map { "Start \($0.name)" } ?? "Choose a Routine",
                style: .secondary
            ) {
                guard !workoutVM.isActive else { showingActiveWorkout = true; return }
                if let routine = recommendedRoutine {
                    workoutVM.startFromRoutine(routine, context: modelContext)
                    showingActiveWorkout = true
                } else {
                    showingRoutinePicker = true
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .voltCard(padding: 18)
        .padding(.horizontal, VoltSpacing.gutter)
        .voltSection("Suggested next")
    }

    // MARK: - Routines
    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VoltSectionTitle("Routines")
                Spacer()
                Button("New") { showingCreateRoutine = true }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VoltColor.accent)
            }
            .padding(.horizontal, VoltSpacing.gutter)

            VStack(spacing: 0) {
                if routines.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.rectangle",
                        title: "No routines yet",
                        message: "Save a workout plan to start it with one tap."
                    )
                } else {
                    ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                        if index > 0 { Divider().overlay(VoltColor.border).padding(.leading, VoltSpacing.md) }
                        RoutineListRow(routine: routine) {
                            guard !workoutVM.isActive else { showingActiveWorkout = true; return }
                            workoutVM.startFromRoutine(routine, context: modelContext)
                            showingActiveWorkout = true
                        }
                    }
                }
            }
            .background(VoltColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius, style: .continuous))
            .padding(.horizontal, VoltSpacing.gutter)
        }
    }

    // MARK: - Last workout
    private func lastWorkoutSection(_ session: WorkoutSession) -> some View {
        NavigationLink { WorkoutDetailView(session: session) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(VoltColor.label)
                    Text("\(session.startDate.formatted(.relative(presentation: .named))) · \(session.formattedDuration) · \(Self.volumeText(session.totalVolume, unit: weightUnit))")
                        .font(VoltFont.mono(13, weight: .regular))
                        .foregroundStyle(VoltColor.labelSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VoltColor.labelTertiary)
            }
            .padding(.horizontal, VoltSpacing.md)
            .padding(.vertical, 14)
            .background(VoltColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, VoltSpacing.gutter)
        .voltSection("Last workout")
    }

    static func volumeText(_ volume: Double, unit: String) -> String {
        volume >= 1000 ? String(format: "%.1fk \(unit)", volume / 1000) : String(format: "%.0f \(unit)", volume)
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
        .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
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
                    .font(.system(size: 16, weight: .medium))
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
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(VoltColor.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radiusSm, style: .continuous))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, VoltSpacing.md)
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
