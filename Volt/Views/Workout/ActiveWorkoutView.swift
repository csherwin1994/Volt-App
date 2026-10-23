import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var vm: ActiveWorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @State private var showingExercisePicker = false
    @State private var showingFinish = false
    @State private var showingDiscard = false
    @State private var showingNothingToSave = false

    private var sortedLogs: [ExerciseLog] {
        (vm.session?.exerciseLogs ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedSetCount: Int { vm.session?.totalSets ?? 0 }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VoltColor.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    exerciseList
                }

                if vm.isRestTimerRunning {
                    restBar
                        .padding(.horizontal, 12)
                        .padding(.bottom, VoltSpacing.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                if let message = vm.latestRecordMessage {
                    recordBanner(message)
                        .padding(.top, 64)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: vm.isRestTimerRunning)
            .animation(.spring(duration: 0.3), value: vm.latestRecordMessage)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet { vm.addExercise($0, context: modelContext) }
        }
        .confirmationDialog("Finish workout?", isPresented: $showingFinish, titleVisibility: .visible) {
            Button("Finish and Save") { vm.finishWorkout(context: modelContext); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save \(completedSetCount) completed \(completedSetCount == 1 ? "set" : "sets") to your history.")
        }
        .confirmationDialog("Discard workout?", isPresented: $showingDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { vm.discardWorkout(context: modelContext); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This workout and its sets will be deleted.")
        }
        .alert("No sets completed", isPresented: $showingNothingToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tick off at least one set before finishing, or discard this workout.")
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: VoltSpacing.sm) {
                // Minimise: the workout keeps running and shows as a bar on the Train tab
                VoltIconButton(icon: "chevron.down", action: { dismiss() })
                    .accessibilityLabel("Minimise workout")

                VStack(spacing: 2) {
                    TextField("Workout name", text: Binding(
                        get: { vm.session?.title ?? "" },
                        set: { newTitle in if let session = vm.session { session.title = newTitle } }
                    ))
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VoltColor.label)
                    Text(vm.formattedElapsed)
                        .font(VoltFont.mono(13, weight: .semibold))
                        .foregroundStyle(VoltColor.accent)
                }
                .frame(maxWidth: .infinity)

                Button {
                    if completedSetCount == 0 { showingNothingToSave = true } else { showingFinish = true }
                } label: {
                    Text("Finish")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(VoltColor.success)
                        .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radiusSm, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, VoltSpacing.sm)

            // Running totals
            let totalVol = vm.session?.totalVolume ?? 0
            HStack {
                stat(value: "\(completedSetCount)", label: "sets done")
                stat(value: WorkoutTabView.volumeText(totalVol, unit: "").trimmingCharacters(in: .whitespaces), label: "\(weightUnit) volume")
                stat(value: "\(sortedLogs.count)", label: "exercises")
            }
            .padding(.vertical, 10)

            Divider().overlay(VoltColor.border)
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(VoltFont.mono(17, weight: .semibold))
                .foregroundStyle(VoltColor.label)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(VoltColor.labelTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rest timer bar
    private var restBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("Rest")
                    .font(.system(size: 13))
                    .opacity(0.7)
                Text(vm.formattedRest)
                    .font(VoltFont.mono(24, weight: .semibold))
                    .contentTransition(.numericText(countsDown: true))
                Spacer()
                restButton("−15") { vm.adjustRestTimer(by: -15) }
                restButton("+15") { vm.adjustRestTimer(by: 15) }
                restButton("Skip") { vm.stopRestTimer() }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(VoltColor.onInk.opacity(0.18))
                    Capsule().fill(VoltColor.onInk)
                        .frame(width: geo.size.width * vm.restProgress)
                        .animation(.linear(duration: 1), value: vm.restProgress)
                }
            }
            .frame(height: 4)
        }
        .foregroundStyle(VoltColor.onInk)
        .padding(.horizontal, VoltSpacing.md)
        .padding(.vertical, 14)
        .background(VoltColor.ink)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rest timer, \(vm.formattedRest) remaining")
    }

    private func restButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(VoltColor.onInk.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radiusSm, style: .continuous))
            .buttonStyle(.plain)
    }

    // MARK: - PR banner
    private func recordBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
            Text(message).lineLimit(1)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(VoltColor.onInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VoltColor.ink)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, VoltSpacing.gutter)
    }

    // MARK: - Exercise list
    private var exerciseList: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(sortedLogs) { log in
                    ExerciseLogCard(log: log, vm: vm)
                }

                VoltButton("Add Exercise", icon: "plus", style: .secondary) {
                    showingExercisePicker = true
                }

                Button("Discard Workout") { showingDiscard = true }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VoltColor.danger)
                    .frame(height: 44)
            }
            .padding(VoltSpacing.md)
            .padding(.bottom, 120) // room for the rest bar
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VoltColor.accent)
            }
        }
    }
}

// MARK: - Exercise log card
struct ExerciseLogCard: View {
    let log: ExerciseLog
    let vm: ActiveWorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @State private var showingRemove = false

    private var sortedSets: [WorkoutSet] {
        log.sets.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        let previous = vm.previousSets(for: log.exerciseName)

        VStack(spacing: 0) {
            // Exercise header
            HStack(spacing: VoltSpacing.sm) {
                Text(log.exerciseName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VoltColor.label)
                Spacer()
                Text(log.exerciseMuscleGroup)
                    .font(.system(size: 13))
                    .foregroundStyle(VoltColor.labelTertiary)
                VoltIconButton(icon: "ellipsis", action: { showingRemove = true })
                    .accessibilityLabel("Exercise options")
            }
            .padding(.leading, VoltSpacing.md)
            .padding(.trailing, VoltSpacing.sm)
            .padding(.top, 10)

            // Column headers
            HStack(spacing: 6) {
                Text("SET").frame(width: 34)
                Text("PREVIOUS").frame(maxWidth: .infinity)
                Text(weightUnit.uppercased()).frame(width: 64)
                Text("REPS").frame(width: 56)
                Image(systemName: "checkmark").frame(width: 38)
            }
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(VoltColor.labelTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // Sets
            ForEach(Array(sortedSets.enumerated()), id: \.element.id) { index, set in
                SetRow(
                    set: set,
                    setNumber: index + 1,
                    previous: index < previous.count ? previous[index] : nil,
                    isRecord: vm.personalRecordSetIDs.contains(set.id),
                    vm: vm
                )
                .contextMenu {
                    if sortedSets.count > 1 {
                        Button("Remove Set", role: .destructive) {
                            vm.removeSet(set, from: log, context: modelContext)
                        }
                    }
                }
            }

            // Add set
            Button { vm.addSet(to: log, context: modelContext) } label: {
                Text("+ Add Set")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VoltColor.labelSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(VoltColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius, style: .continuous))
        .confirmationDialog("Remove \(log.exerciseName)?", isPresented: $showingRemove, titleVisibility: .visible) {
            Button("Remove Exercise", role: .destructive) {
                vm.session?.exerciseLogs.removeAll { $0.id == log.id }
                modelContext.delete(log)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Set row
struct SetRow: View {
    @Bindable var set: WorkoutSet
    let setNumber: Int
    let previous: WorkoutSet?
    let isRecord: Bool
    let vm: ActiveWorkoutViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 6) {
            // Set number, or a trophy when this set is a personal record
            Group {
                if isRecord {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(VoltColor.accent)
                        .accessibilityLabel("Set \(setNumber), personal record")
                } else {
                    Text("\(setNumber)")
                        .font(VoltFont.mono(14, weight: .semibold))
                        .foregroundStyle(VoltColor.labelSecondary)
                }
            }
            .frame(width: 34)

            // Previous
            Text(previous.map { "\($0.weight.formatted()) × \($0.reps)" } ?? "–")
                .font(VoltFont.mono(13, weight: .regular))
                .foregroundStyle(VoltColor.labelTertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            // Weight
            TextField("0", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(VoltFont.mono(15, weight: .semibold))
                .foregroundStyle(VoltColor.label)
                .frame(width: 64, height: 36)
                .background(set.isCompleted ? Color.clear : VoltColor.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radiusXs, style: .continuous))

            // Reps
            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(VoltFont.mono(15, weight: .semibold))
                .foregroundStyle(VoltColor.label)
                .frame(width: 56, height: 36)
                .background(set.isCompleted ? Color.clear : VoltColor.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radiusXs, style: .continuous))

            // Complete toggle
            Button { vm.toggleSetComplete(set, context: modelContext) } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(set.isCompleted ? Color.white : VoltColor.labelTertiary)
                    .frame(width: 38, height: 36)
                    .background(set.isCompleted ? VoltColor.success : VoltColor.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radiusSm, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Mark set \(setNumber) not done" : "Mark set \(setNumber) done")
            .sensoryFeedback(.success, trigger: set.isCompleted) { _, done in done }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(set.isCompleted ? VoltColor.successSoft : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: set.isCompleted)
    }
}

// MARK: - Exercise picker sheet
struct ExercisePickerSheet: View {
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var search = ""
    @State private var selectedMuscle: Exercise.MuscleGroup?

    private var filtered: [Exercise] {
        exercises.filter {
            (selectedMuscle == nil || $0.muscleGroup == selectedMuscle) &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VoltColor.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "All", isSelected: selectedMuscle == nil) { selectedMuscle = nil }
                            ForEach(Exercise.MuscleGroup.allCases, id: \.self) { g in
                                FilterChip(label: g.rawValue, isSelected: selectedMuscle == g) {
                                    selectedMuscle = selectedMuscle == g ? nil : g
                                }
                            }
                        }
                        .padding(.horizontal, VoltSpacing.md)
                        .padding(.vertical, VoltSpacing.sm)
                    }
                    Divider().background(VoltColor.border)

                    if exercises.isEmpty {
                        VStack(spacing: VoltSpacing.md) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(VoltColor.labelTertiary)
                            Text("Exercise library is empty")
                                .font(.headline)
                                .foregroundStyle(VoltColor.label)
                            Text("Visit the Exercises tab to browse and manage your library.")
                                .font(.subheadline)
                                .foregroundStyle(VoltColor.labelSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, VoltSpacing.xl)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filtered.isEmpty {
                        VStack(spacing: VoltSpacing.md) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundStyle(VoltColor.labelTertiary)
                            Text("No exercises found")
                                .font(.headline)
                                .foregroundStyle(VoltColor.label)
                            Text("Try a different search or muscle group filter.")
                                .font(.subheadline)
                                .foregroundStyle(VoltColor.labelSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filtered) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(VoltColor.muscle(exercise.muscleGroup).opacity(0.12))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: exercise.icon)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(VoltColor.muscle(exercise.muscleGroup))
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(VoltColor.label)
                                        HStack(spacing: 6) {
                                            MuscleBadge(group: exercise.muscleGroup)
                                            Text(exercise.equipment.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(VoltColor.labelTertiary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(VoltColor.surface)
                            .listRowSeparatorTint(VoltColor.border)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(VoltColor.labelSecondary)
                }
            }
            .onAppear { DataManager.seedExercisesIfNeeded(context: modelContext) }
        }
    }
}

#Preview("Active Workout") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutSession.self, Exercise.self, Routine.self, configurations: config)
    let ctx = container.mainContext
    let session = WorkoutSession(title: "Push Day")
    ctx.insert(session)
    let log = ExerciseLog(exerciseName: "Bench Press", exerciseMuscleGroup: "Chest")
    ctx.insert(log)
    for (i, (w, r)) in [(80.0,8),(85.0,6),(90.0,4)].enumerated() {
        let s = WorkoutSet(orderIndex: i, weight: w, reps: r)
        s.isCompleted = i == 0
        ctx.insert(s); log.sets.append(s)
    }
    session.exerciseLogs = [log]
    try? ctx.save()
    let vm = ActiveWorkoutViewModel()
    vm.session = session; vm.isActive = true; vm.elapsedSeconds = 847
    return ActiveWorkoutView(vm: vm).modelContainer(container)
}
