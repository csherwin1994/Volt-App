import SwiftUI
import SwiftData

// Live workout. Layout follows Workout.dc.html on the App Screens canvas.
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
    private var plannedSetCount: Int { sortedLogs.reduce(0) { $0 + $1.sets.count } }
    private var progress: Double { plannedSetCount == 0 ? 0 : Double(completedSetCount) / Double(plannedSetCount) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VoltColor.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    exerciseList
                }

                VStack(spacing: 8) {
                    if let message = vm.latestRecordMessage {
                        recordBanner(message)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if vm.isRestTimerRunning {
                        restBlock
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, VoltSpacing.sm)
            }
            .animation(.spring(duration: 0.3), value: vm.isRestTimerRunning)
            .animation(.spring(duration: 0.3), value: vm.latestRecordMessage)
            .navigationBarHidden(true)
        }
        .environment(vm)
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet { vm.addExercise($0, context: modelContext) }
        }
        .confirmationDialog("Finish workout?", isPresented: $showingFinish, titleVisibility: .visible) {
            Button("Finish and Save") { vm.finishWorkout(context: modelContext); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save \(completedSetCount) completed \(completedSetCount == 1 ? "set" : "sets") to your history. Unticked sets are left out.")
        }
        .confirmationDialog("Cancel this workout?", isPresented: $showingDiscard, titleVisibility: .visible) {
            Button("Cancel Workout", role: .destructive) { vm.discardWorkout(context: modelContext); dismiss() }
            Button("Keep Training", role: .cancel) {}
        } message: {
            Text("Nothing from it will be saved. Your history stays as it is.")
        }
        .alert("No sets completed", isPresented: $showingNothingToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tick off at least one set before finishing, or cancel this workout.")
        }
    }

    // MARK: - Header: live label, Finish, the clock as hero, progress line
    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Minimise: the workout keeps running and shows as a bar on the Train tab
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down").font(.system(size: 18))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(VoltColor.label)
                .accessibilityLabel("Minimise workout")

                Rectangle().fill(VoltColor.accent).frame(width: 7, height: 7)
                TextField("Workout name", text: Binding(
                    get: { vm.session?.title ?? "" },
                    set: { newTitle in if let session = vm.session { session.title = newTitle } }
                ))
                .font(VoltFont.mono(11)).tracking(0.9)
                .textInputAutocapitalization(.characters)
                .foregroundStyle(VoltColor.labelSecondary)

                // Cancel: leave without saving (asks first)
                Button { showingDiscard = true } label: {
                    Image(systemName: "xmark").font(.system(size: 18))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(VoltColor.label)
                .accessibilityLabel("Cancel workout")

                Button {
                    if completedSetCount == 0 { showingNothingToSave = true } else { showingFinish = true }
                } label: {
                    HStack(spacing: 10) {
                        Text("Finish").font(VoltFont.sans(15))
                        Image(systemName: "arrow.right").font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .foregroundStyle(VoltColor.onAccent)
                    .background(VoltColor.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.top, 6)

            HStack(alignment: .bottom) {
                Text(vm.formattedElapsed)
                    .font(VoltFont.display(88)).tracking(-3.5)
                    .foregroundStyle(VoltColor.label)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Workout time \(vm.formattedElapsed)")
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(completedSetCount) / \(plannedSetCount) sets")
                    Text("\(voltVolume(vm.session?.totalVolume ?? 0)) \(weightUnit)")
                }
                .font(VoltFont.mono(11)).tracking(0.4).textCase(.uppercase)
                .foregroundStyle(VoltColor.labelSecondary)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, VoltSpacing.gutter)
            .padding(.top, 4)
            .padding(.bottom, 16)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(VoltColor.surfaceHigh)
                    Rectangle().fill(VoltColor.accent).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, VoltSpacing.gutter)
            .animation(.easeOut(duration: 0.3), value: progress)
            .accessibilityLabel("\(completedSetCount) of \(plannedSetCount) sets done")
        }
    }

    // MARK: - Rest timer: ink block with a big countdown
    private var restBlock: some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("REST").font(VoltFont.mono(11)).tracking(0.9).opacity(0.65)
                    Text(vm.formattedRest)
                        .font(VoltFont.display(56)).tracking(-2.4)
                        .contentTransition(.numericText(countsDown: true))
                }
                Spacer()
                restButton("−15") { vm.adjustRestTimer(by: -15) }
                restButton("+15") { vm.adjustRestTimer(by: 15) }
                restButton("SKIP") { vm.stopRestTimer() }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(VoltColor.onInk.opacity(0.25))
                    Rectangle().fill(VoltColor.accent)
                        .frame(width: geo.size.width * vm.restProgress)
                        .animation(.linear(duration: 1), value: vm.restProgress)
                }
            }
            .frame(height: 2)
        }
        .foregroundStyle(VoltColor.onInk)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(VoltColor.ink)
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rest timer, \(vm.formattedRest) remaining")
    }

    private func restButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(VoltFont.mono(12))
                .padding(.horizontal, 12)
                .frame(height: 36)
                .overlay(Rectangle().strokeBorder(VoltColor.onInk.opacity(0.4), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - PR banner: gold, the one moment the app celebrates
    private func recordBanner(_ message: String) -> some View {
        Text(message.uppercased())
            .font(VoltFont.mono(12, weight: .medium)).tracking(0.6)
            .lineLimit(2)
            .foregroundStyle(VoltColor.onAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(VoltColor.accent)
            .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Exercise list
    private var exerciseList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(sortedLogs) { log in
                    ExerciseLogCard(log: log, vm: vm)
                }

                VoltButton("Add Exercise", style: .secondary) { showingExercisePicker = true }

                Button("Cancel workout") { showingDiscard = true }
                    .font(VoltFont.sans(17))
                    .foregroundStyle(VoltColor.danger)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, VoltSpacing.gutter)
            .padding(.top, 20)
            .padding(.bottom, 190) // room for the rest block
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .font(VoltFont.sans(15, weight: .medium))
                    .foregroundStyle(VoltColor.label)
            }
        }
    }
}

// MARK: - Exercise card with its set table
struct ExerciseLogCard: View {
    let log: ExerciseLog
    let vm: ActiveWorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @Query private var library: [Exercise]
    @State private var showingRemove = false
    @State private var showingDemo = false

    private var sortedSets: [WorkoutSet] {
        log.sets.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var exercise: Exercise? { library.first { $0.name == log.exerciseName } }
    private var movement: Movement? { MovementLibrary.shared.movement(for: log.exerciseName) }
    private var hasDemo: Bool { movement != nil || (exercise?.imageURLs.count ?? 0) >= 2 }

    var body: some View {
        let previous = vm.previousSets(for: log.exerciseName)

        VStack(spacing: 0) {
            // Name (opens the exercise page), muscle, options
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let exercise {
                    NavigationLink { ExerciseDetailView(exercise: exercise) } label: { name }
                        .buttonStyle(.plain)
                } else {
                    name
                }
                Spacer(minLength: 8)
                Text(log.exerciseMuscleGroup.uppercased())
                    .font(VoltFont.mono(10)).tracking(0.4)
                    .foregroundStyle(VoltColor.labelSecondary)
                if hasDemo {
                    Button { withAnimation(.easeInOut(duration: 0.2)) { showingDemo.toggle() } } label: {
                        Text(showingDemo ? "HIDE" : "DEMO")
                            .font(VoltFont.mono(11, weight: .medium)).tracking(0.9)
                            .underline(true, color: VoltColor.label)
                            .foregroundStyle(VoltColor.label)
                            .frame(minWidth: 44, minHeight: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showingDemo ? "Hide demo" : "Show how to do \(log.exerciseName)")
                }
                Button { showingRemove = true } label: {
                    Image(systemName: "ellipsis").font(.system(size: 16))
                        .frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(VoltColor.label)
                .accessibilityLabel("Exercise options")
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.top, 14)
            .padding(.bottom, 6)
            VoltRule()

            // How-to right inside the card: the line-drawn animation, or the catalog photos when there is none
            if showingDemo {
                Group {
                    if let movement {
                        ZStack(alignment: .bottomTrailing) {
                            MovementLoop(movement: movement)
                            if let exercise {
                                NavigationLink { ExerciseDetailView(exercise: exercise) } label: {
                                    Text("FULL GUIDE →")
                                        .font(VoltFont.mono(11)).tracking(0.6)
                                        .padding(.horizontal, 10).padding(.vertical, 8)
                                        .background(VoltColor.ink).foregroundStyle(VoltColor.onInk)
                                }
                                .buttonStyle(.plain)
                                .padding(10)
                            }
                        }
                        .background(VoltColor.bg)
                    } else if let exercise {
                        InlineDemoView(urls: exercise.imageURLs, name: log.exerciseName) {
                            ExerciseDetailView(exercise: exercise)
                        }
                    }
                }
                .transition(.opacity)
                VoltRule()
            }

            // Column headers
            SetGrid {
                Text("SET").frame(width: 28, alignment: .leading)
                Text("PREV").frame(maxWidth: .infinity, alignment: .leading)
                Text(weightUnit.uppercased()).padding(.trailing, 8).frame(width: 64, alignment: .trailing)
                Text("REPS").padding(.trailing, 8).frame(width: 48, alignment: .trailing)
                Color.clear.frame(width: 40, height: 1)
            }
            .font(VoltFont.mono(10)).tracking(0.8)
            .foregroundStyle(VoltColor.labelTertiary)
            .frame(minHeight: 30)

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

            Rectangle().fill(VoltColor.borderSubtle).frame(height: 1)
            Button { vm.addSet(to: log, context: modelContext) } label: {
                Text("+ ADD SET")
                    .font(VoltFont.mono(11)).tracking(0.6)
                    .foregroundStyle(VoltColor.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(VoltColor.surface)
        .confirmationDialog("Remove \(log.exerciseName)?", isPresented: $showingRemove, titleVisibility: .visible) {
            Button("Remove Exercise", role: .destructive) {
                vm.session?.exerciseLogs.removeAll { $0.id == log.id }
                modelContext.delete(log)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var name: some View {
        Text(log.exerciseName)
            .font(VoltFont.sans(20)).tracking(-0.5)
            .foregroundStyle(VoltColor.label)
            .multilineTextAlignment(.leading)
    }
}

/// Compact how-to inside the workout: start and end photos crossfade; "Full guide" opens the exercise page.
struct InlineDemoView<Guide: View>: View {
    let urls: [URL]
    let name: String
    @ViewBuilder var guide: () -> Guide
    @State private var frame = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .topLeading) {
            VoltColor.surfaceHigh
            ForEach(Array(urls.prefix(2).enumerated()), id: \.offset) { index, url in
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Color.clear }
                }
                .grayscale(1)
                .opacity(index == frame ? 1 : 0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: frame)
            }
            Text(frame == 0 ? "START" : "END")
                .font(VoltFont.mono(10)).tracking(0.8)
                .padding(.horizontal, 7).padding(.vertical, 5)
                .background(VoltColor.bg).foregroundStyle(VoltColor.label)
                .padding(10)
            VStack { Spacer(); HStack {
                Spacer()
                NavigationLink { guide() } label: {
                    Text("FULL GUIDE →")
                        .font(VoltFont.mono(11)).tracking(0.6)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(VoltColor.ink).foregroundStyle(VoltColor.onInk)
                }
                .buttonStyle(.plain)
            } }
            .padding(10)
        }
        .aspectRatio(3 / 2, contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(name) demo, \(frame == 0 ? "start" : "end") position")
        .onReceive(timer) { _ in
            guard urls.count >= 2, !reduceMotion else { return }
            frame = frame == 0 ? 1 : 0
        }
    }
}

/// One row of the set table: set · previous · weight · reps · tick (28 / flexible / 64 / 48 / 40).
struct SetGrid<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 6) { content() }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(spacing: 0) {
            Rectangle().fill(VoltColor.borderSubtle).frame(height: 1)
            SetGrid {
                // Set number, or PR in gold text when this set is a personal record
                Text(isRecord ? "PR" : String(format: "%02d", setNumber))
                    .font(VoltFont.mono(13, weight: isRecord ? .medium : .regular))
                    .foregroundStyle(isRecord || set.isCompleted ? VoltColor.accentText : VoltColor.labelTertiary)
                    .frame(width: 28, alignment: .leading)
                    .accessibilityLabel(isRecord ? "Set \(setNumber), personal record" : "Set \(setNumber)")

                Text(previous.map { "\(voltWeight($0.weight)) × \($0.reps)" } ?? "–")
                    .font(VoltFont.mono(13))
                    .foregroundStyle(VoltColor.labelTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                field(TextField("0", value: $set.weight, format: .number).keyboardType(.decimalPad), width: 64)
                    .accessibilityLabel("Weight")
                field(TextField("0", value: $set.reps, format: .number).keyboardType(.numberPad), width: 48)
                    .accessibilityLabel("Reps")

                Button { vm.toggleSetComplete(set, context: modelContext) } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14))
                        .foregroundStyle(set.isCompleted ? VoltColor.onAccent : VoltColor.labelTertiary)
                        .frame(width: 40, height: 38)
                        .background(set.isCompleted ? VoltColor.accent : Color.clear)
                        .overlay(Rectangle().strokeBorder(set.isCompleted ? Color.clear : VoltColor.border, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(set.isCompleted ? "Mark set \(setNumber) not done" : "Mark set \(setNumber) done")
                .sensoryFeedback(.success, trigger: set.isCompleted) { _, done in done }
            }
            .frame(minHeight: 48)
        }
        .background(set.isCompleted ? VoltColor.accentDim : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: set.isCompleted)
    }

    private func field<F: View>(_ textField: F, width: CGFloat) -> some View {
        textField
            .multilineTextAlignment(.trailing)
            .font(VoltFont.mono(17))
            .foregroundStyle(VoltColor.label)
            .padding(.horizontal, 8)
            .frame(width: width, height: 38)
            .background(set.isCompleted ? Color.clear : VoltColor.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radiusXs))
    }
}

// MARK: - Exercise picker sheet (Library list style)
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
            (search.isEmpty
                || $0.name.localizedCaseInsensitiveContains(search)
                || $0.primaryMuscles.contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VoltSectionTitle("Add exercise")
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 18)).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(VoltColor.label)
                .accessibilityLabel("Close")
            }
            .padding(.leading, VoltSpacing.gutter)
            .padding(.trailing, 8)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 16) {
                VoltSearchField(text: $search, prompt: "Search exercises")
                MuscleChips(selection: $selectedMuscle)
            }
            .padding(.horizontal, VoltSpacing.gutter)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 0) {
                    VoltRule(strong: true)
                    if filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No exercises found.").font(VoltFont.sans(24)).tracking(-0.6)
                            Text("Try another word or muscle group.").font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 24)
                    }
                    ForEach(filtered) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            ExerciseRow(exercise: exercise, trailingIcon: "plus")
                        }
                        .buttonStyle(.plain)
                        VoltRule()
                    }
                }
                .padding(.horizontal, VoltSpacing.gutter)
                .padding(.bottom, VoltSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(VoltColor.bg.ignoresSafeArea())
        .onAppear { DataManager.seedExercisesIfNeeded(context: modelContext) }
    }
}

/// Horizontal row of muscle-group chips with "All" first.
struct MuscleChips: View {
    @Binding var selection: Exercise.MuscleGroup?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "All", isSelected: selection == nil) { selection = nil }
                ForEach(Exercise.MuscleGroup.allCases, id: \.self) { g in
                    FilterChip(label: g.rawValue, isSelected: selection == g) {
                        selection = selection == g ? nil : g
                    }
                }
            }
            .padding(.horizontal, VoltSpacing.gutter)
        }
        .padding(.horizontal, -VoltSpacing.gutter)
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
