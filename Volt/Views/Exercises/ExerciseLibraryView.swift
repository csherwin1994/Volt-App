import SwiftUI
import SwiftData

// Library tab, Exercises side. Layout follows Library.dc.html on the App Screens canvas.
struct ExerciseLibraryView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var routines: [Routine]
    @State private var search = ""
    @State private var selectedMuscle: Exercise.MuscleGroup?
    @State private var showingCreate = false
    @State private var equipmentFilter: Exercise.Equipment?
    @State private var levelFilter: String?
    @State private var includeStretches = false
    /// Set when shown inside the Library tab, which adds the Exercises / Routines switch.
    var librarySection: Binding<LibraryView.Section>? = nil

    private var filtered: [Exercise] {
        exercises.filter {
            (selectedMuscle == nil || $0.muscleGroup == selectedMuscle) &&
            (equipmentFilter == nil || $0.equipment == equipmentFilter) &&
            (levelFilter == nil || $0.level == levelFilter) &&
            (includeStretches || !$0.isStretch) &&
            (search.isEmpty
                || $0.name.localizedCaseInsensitiveContains(search)
                || $0.primaryMuscles.contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }

    private var activeFilterCount: Int {
        (equipmentFilter == nil ? 0 : 1) + (levelFilter == nil ? 0 : 1) + (includeStretches ? 1 : 0)
    }

    private var filterMenu: some View {
        Menu {
            Picker("Equipment", selection: $equipmentFilter) {
                Text("Any equipment").tag(Exercise.Equipment?.none)
                ForEach(Exercise.Equipment.allCases, id: \.self) { Text($0.rawValue).tag(Exercise.Equipment?.some($0)) }
            }
            Picker("Level", selection: $levelFilter) {
                Text("Any level").tag(String?.none)
                Text("Beginner").tag(String?.some("beginner"))
                Text("Intermediate").tag(String?.some("intermediate"))
                Text("Expert").tag(String?.some("expert"))
            }
            Toggle("Include stretches", isOn: $includeStretches)
            if activeFilterCount > 0 {
                Button("Clear Filters", role: .destructive) {
                    equipmentFilter = nil; levelFilter = nil; includeStretches = false
                }
            }
        } label: {
            Text(activeFilterCount > 0 ? "FILTER · \(activeFilterCount)" : "FILTER")
                .font(VoltFont.mono(11, weight: .medium)).tracking(0.9)
                .underline(true, color: VoltColor.label)
                .foregroundStyle(VoltColor.label)
                .frame(minHeight: 44)
        }
        .accessibilityLabel(activeFilterCount > 0 ? "Filters, \(activeFilterCount) on" : "Filters")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    VStack(alignment: .leading, spacing: 20) {
                        VoltScreenHeader(
                            caption: "\(exercises.count) exercises · \(routines.count) routines",
                            title: librarySection == nil ? "Exercises" : "Library"
                        ) {
                            HStack(spacing: 16) {
                                filterMenu
                                VoltTextLink("New") { showingCreate = true }
                                    .accessibilityLabel("New exercise")
                            }
                        }
                        if let librarySection { LibrarySectionPicker(selection: librarySection) }
                        VoltSearchField(text: $search, prompt: "Search exercises or muscles")
                        MuscleChips(selection: $selectedMuscle)
                    }
                    .padding(.bottom, 20)

                    VoltRule(strong: true)
                    if filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No exercises found.").font(VoltFont.sans(24)).tracking(-0.6).foregroundStyle(VoltColor.label)
                            Text("Try another word or muscle group, or add your own.")
                                .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                            VoltButton("Create Exercise", style: .secondary) { showingCreate = true }
                                .padding(.top, 10)
                        }
                        .padding(.vertical, 24)
                    }
                    ForEach(filtered) { exercise in
                        NavigationLink { ExerciseDetailView(exercise: exercise) } label: {
                            ExerciseRow(exercise: exercise)
                        }
                        .buttonStyle(.plain)
                        VoltRule()
                    }
                }
                .padding(.horizontal, VoltSpacing.gutter)
                .padding(.top, VoltSpacing.md)
                .padding(.bottom, VoltSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(VoltColor.bg.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreate) { CreateExerciseView() }
        }
    }
}

/// Library row: name, then MUSCLE · EQUIPMENT · LEVEL in mono, arrow (or plus in pickers) on the right.
struct ExerciseRow: View {
    let exercise: Exercise
    var trailingIcon = "arrow.right"

    private var detail: String {
        [exercise.muscleGroup.rawValue, exercise.equipment.rawValue, exercise.level.capitalized, exercise.isCustom ? "Custom" : ""]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            if let movement = MovementLibrary.shared.movement(for: exercise.name) {
                MovementThumbnail(movement: movement)
            } else {
                Rectangle().fill(VoltColor.surface)
                    .frame(width: 54, height: 36)
                    .overlay(Rectangle().strokeBorder(VoltColor.border, lineWidth: 1))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(VoltFont.sans(17))
                    .foregroundStyle(VoltColor.label)
                    .lineLimit(1)
                Text(detail.uppercased())
                    .font(VoltFont.mono(11)).tracking(0.4)
                    .foregroundStyle(VoltColor.labelSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: trailingIcon)
                .font(.system(size: 14))
                .foregroundStyle(trailingIcon == "plus" ? VoltColor.label : VoltColor.labelTertiary)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

// MARK: - Exercise page (one interactive template for every exercise)

struct ExerciseDetailView: View {
    let exercise: Exercise
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Environment(ActiveWorkoutViewModel.self) private var workoutVM: ActiveWorkoutViewModel?
    @Environment(\.modelContext) private var modelContext
    @State private var targetWeight: Double?
    @State private var addedToWorkout = false

    /// Completed sets of this exercise across finished workouts, newest workout first.
    private var history: [(date: Date, set: WorkoutSet)] {
        sessions.filter { $0.endDate != nil }.flatMap { session in
            session.exerciseLogs
                .filter { $0.exerciseName == exercise.name }
                .flatMap(\.completedSets)
                .map { (date: session.startDate, set: $0) }
        }
    }

    private var target: PlannedExercise {
        WorkoutRecommendationEngine.target(
            for: exercise.name,
            muscleGroup: exercise.muscleGroup.rawValue,
            isCompound: exercise.isLikelyCompound,
            defaultSets: exercise.isLikelyCompound ? 4 : 3,
            defaultReps: exercise.isLikelyCompound ? 6 : 10,
            routineWeight: nil,
            history: WorkoutRecommendationEngine.pastWorkouts(from: sessions),
            settings: .fromPreferences()
        )
    }

    var body: some View {
        let plan = target
        let weight = targetWeight ?? plan.weight

        ScrollView {
            VStack(alignment: .leading, spacing: 44) {
                header

                // Line-drawn animation first; the catalog photos only when no movement pattern fits
                if let movement = MovementLibrary.shared.movement(for: exercise.name) {
                    MovementPlayer(movement: movement)
                } else if exercise.imageURLs.count >= 1 {
                    ExerciseDemoView(urls: exercise.imageURLs, phases: phaseNames)
                }

                targetSection(plan: plan, weight: weight)

                if !exercise.primaryMuscles.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        VoltSectionTitle("Muscles worked")
                        MuscleMapView(primary: exercise.primaryMuscles, secondary: exercise.secondaryMuscles)
                        HStack(spacing: 6) {
                            legendTag("Primary · " + exercise.primaryMuscles.joined(separator: ", "), fill: VoltColor.accent, outlined: false)
                            if !exercise.secondaryMuscles.isEmpty {
                                legendTag("Secondary · " + exercise.secondaryMuscles.prefix(2).joined(separator: ", "), fill: VoltColor.accentDim, outlined: true)
                            }
                        }
                    }
                }

                if !exercise.instructionSteps.isEmpty {
                    FormCuesView(steps: exercise.instructionSteps)
                } else if !exercise.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        VoltSectionTitle("How to do it")
                        Text(exercise.instructions).font(VoltFont.sans(17)).foregroundStyle(VoltColor.label)
                    }
                }

                recordsSection

                if let vm = workoutVM, vm.isActive {
                    VoltButton(addedToWorkout ? "Added to \(vm.session?.title ?? "Workout")" : "Add to Current Workout") {
                        guard !addedToWorkout else { return }
                        vm.addExercise(exercise, context: modelContext)
                        addedToWorkout = true
                    }
                }
            }
            .padding(.horizontal, VoltSpacing.gutter)
            .padding(.top, VoltSpacing.sm)
            .padding(.bottom, VoltSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(VoltColor.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(exercise.muscleGroup.rawValue.uppercased())
                    .font(VoltFont.mono(11)).tracking(0.9)
                    .foregroundStyle(VoltColor.labelSecondary)
            }
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(exercise.name)
                .font(VoltFont.sans(40))
                .tracking(-1.4)
                .foregroundStyle(VoltColor.label)
                .fixedSize(horizontal: false, vertical: true)
            FlowTags(tags: [exercise.muscleGroup.rawValue, exercise.equipment.rawValue, exercise.mechanic.capitalized, exercise.level.capitalized]
                .filter { !$0.isEmpty }, markFirst: true)
        }
    }

    private var phaseNames: [String] {
        switch exercise.force {
        case "push": return ["Start · arms locked", "Lower · 3 s, controlled"]
        case "pull": return ["Start · arms long", "Pull · 1 s, squeeze"]
        default:     return ["Start position", "End position"]
        }
    }

    // MARK: Today's target
    private func targetSection(plan: PlannedExercise, weight: Double?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VoltSectionTitle("Today's target · \(plan.sets) × \(plan.reps)")
            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(weight.map { $0.formatted() } ?? "—")
                        .font(VoltFont.display(88))
                        .tracking(-3.5)
                        .contentTransition(.numericText())
                    Text(weightUnit.uppercased()).font(VoltFont.mono(13)).foregroundStyle(VoltColor.labelSecondary)
                }
                Spacer()
                if let weight {
                    HStack(spacing: 6) {
                        stepButton("−\(step.formatted())") { targetWeight = max(0, weight - step) }
                        stepButton("+\(step.formatted())") { targetWeight = weight + step }
                    }
                }
            }
            .foregroundStyle(VoltColor.label)
            .animation(.snappy, value: weight)

            Text(plan.note)
                .font(VoltFont.sans(15))
                .foregroundStyle(VoltColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if exercise.equipment == .barbell, let weight {
                PlateCalculatorView(total: weight, unit: weightUnit)
            }
        }
    }

    private var step: Double { weightUnit == "lb" ? 5 : 2.5 }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(VoltFont.mono(13)).frame(width: 52, height: 40)
                .overlay(Rectangle().strokeBorder(VoltColor.label, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: targetWeight)
    }

    private func legendTag(_ text: String, fill: Color, outlined: Bool) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(fill).frame(width: 8, height: 8)
                .overlay(Rectangle().strokeBorder(VoltColor.accentText, lineWidth: outlined ? 0.5 : 0))
            Text(text.uppercased()).font(VoltFont.mono(10)).tracking(0.6).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(VoltColor.surfaceHigh)
        .foregroundStyle(VoltColor.labelSecondary)
    }

    // MARK: Records
    @ViewBuilder
    private var recordsSection: some View {
        let entries = history.filter { $0.set.weight > 0 && $0.set.reps > 0 }
        if let heaviest = entries.max(by: { $0.set.weight < $1.set.weight }) {
            let best1RM = entries.map { PersonalRecords.estimatedOneRepMax(weight: $0.set.weight, reps: $0.set.reps) }.max() ?? 0
            let sessionsLogged = Set(entries.map { $0.date }).count
            // Heaviest set per session, oldest to newest, last 8
            let tops = Dictionary(grouping: entries, by: { $0.date })
                .map { (date: $0.key, top: $0.value.map { $0.set.weight }.max() ?? 0) }
                .sorted { $0.date < $1.date }
                .suffix(8)
            VStack(alignment: .leading, spacing: 12) {
                VoltSectionTitle("Your records")
                SpecGrid(cells: [
                    ("Heaviest", heaviest.set.weight.formatted(), "× \(heaviest.set.reps)"),
                    ("Est. 1RM", best1RM.formatted(.number.precision(.fractionLength(0))), weightUnit.uppercased()),
                    ("Logged", "\(sessionsLogged)", "×"),
                ])
                if tops.count >= 2 {
                    let lo = (tops.map(\.top).min() ?? 0) * 0.9, hi = tops.map(\.top).max() ?? 1
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(tops.enumerated()), id: \.offset) { index, item in
                            Rectangle()
                                .fill(index == tops.count - 1 ? VoltColor.accent : VoltColor.bar)
                                .frame(height: max(4, 88 * (item.top - lo) / max(1, hi - lo)))
                        }
                    }
                    .frame(height: 92, alignment: .bottom)
                    .overlay(alignment: .bottom) { Rectangle().fill(VoltColor.label).frame(height: 1) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Top set over the last \(tops.count) sessions, from \(tops.first!.top.formatted()) to \(tops.last!.top.formatted()) \(weightUnit)")
                }
            }
        }
    }
}

// MARK: - Movement demo: start and end photos crossfading at tempo
struct ExerciseDemoView: View {
    let urls: [URL]
    let phases: [String]
    @State private var frame = 0
    @State private var playing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
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
                Text(String(format: "%02d · %@", frame + 1, frame == 0 ? "START" : "END"))
                    .font(VoltFont.mono(10)).tracking(0.8)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(VoltColor.bg).foregroundStyle(VoltColor.label)
                    .padding(10)
            }
            .aspectRatio(3 / 2, contentMode: .fit)
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(phases[min(frame, phases.count - 1)])

            HStack(spacing: 12) {
                Button { playing.toggle() } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                        .frame(width: 28, height: 28)
                        .overlay(Rectangle().strokeBorder(VoltColor.onInk, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playing ? "Pause demo" : "Play demo")
                Text(phases[min(frame, phases.count - 1)].uppercased())
                Spacer()
                Text("TEMPO 3·1·1").opacity(0.65)
            }
            .font(VoltFont.mono(11)).tracking(0.6)
            .foregroundStyle(VoltColor.onInk)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(VoltColor.ink)

            if urls.count >= 2 {
                HStack(spacing: 1) {
                    positionButton(0, "01 · START")
                    positionButton(1, "02 · END")
                }
                .padding(1).background(VoltColor.border)
            }
        }
        .onReceive(timer) { _ in
            guard playing, urls.count >= 2, !reduceMotion else { return }
            frame = frame == 0 ? 1 : 0
        }
    }

    private func positionButton(_ index: Int, _ title: String) -> some View {
        Button { frame = index; playing = false } label: {
            Text(title).font(VoltFont.mono(11)).tracking(0.8)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(frame == index ? VoltColor.ink : VoltColor.bg)
                .foregroundStyle(frame == index ? VoltColor.onInk : VoltColor.labelSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Plates per side, drawn to scale
struct PlateCalculatorView: View {
    let total: Double
    let unit: String

    private var bar: Double { unit == "lb" ? 45 : 20 }
    private var sizes: [Double] { unit == "lb" ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25] }

    private var plates: [Double] {
        var side = max(0, (total - bar) / 2)
        var result: [Double] = []
        for size in sizes {
            while side >= size - 0.001 { side -= size; result.append(size) }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 3) {
                Rectangle().fill(VoltColor.labelSecondary).frame(width: 70, height: 6)
                Rectangle().fill(VoltColor.label).frame(width: 10, height: 12)
                ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                    let smallest = plate == sizes.last
                    Rectangle()
                        .fill(smallest ? VoltColor.accent : VoltColor.ink)
                        .frame(width: max(5, 16 * min(1, plate / sizes[0]) + 4), height: 28 + 64 * min(1, plate / sizes[0]))
                }
                Rectangle().fill(VoltColor.labelSecondary).frame(width: 34, height: 6)
            }
            .frame(height: 100)
            .animation(.snappy, value: plates)
            Text("EACH SIDE: \(plates.isEmpty ? "EMPTY BAR" : plates.map { $0.formatted() }.joined(separator: " + ")) · BAR \(bar.formatted()) \(unit.uppercased())")
                .font(VoltFont.mono(11)).tracking(0.6)
                .foregroundStyle(VoltColor.labelSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Numbered form cues you can step through
struct FormCuesView: View {
    let steps: [String]
    @State private var current = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VoltSectionTitle("How to do it")
                Spacer()
                Text("\(current + 1) OF \(steps.count)").font(VoltFont.mono(11)).tracking(0.9).foregroundStyle(VoltColor.labelSecondary)
            }
            VStack(spacing: 0) {
                Rectangle().fill(VoltColor.label).frame(height: 1)
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Button { withAnimation(.easeOut(duration: 0.2)) { current = index } } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(VoltFont.mono(12)).foregroundStyle(VoltColor.accentText)
                                .frame(width: 28, alignment: .leading)
                            Text(step)
                                .font(VoltFont.sans(17))
                                .foregroundStyle(index == current ? VoltColor.label : VoltColor.labelTertiary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(VoltColor.border).frame(height: 1)
                }
            }
            HStack(spacing: 8) {
                stepButton("← PREVIOUS") { current = max(0, current - 1) }
                stepButton("NEXT →") { current = min(steps.count - 1, current + 1) }
            }
        }
    }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { action() } } label: {
            Text(title).font(VoltFont.mono(11)).tracking(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(Rectangle().strokeBorder(VoltColor.label, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Geometric muscle map, front and back
struct MuscleMapView: View {
    let primary: [String]
    let secondary: [String]

    private struct Region { let rect: CGRect; let radius: CGFloat; let muscles: [String] }
    private static func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rad: CGFloat, _ m: [String]) -> Region {
        Region(rect: CGRect(x: x, y: y, width: w, height: h), radius: rad, muscles: m)
    }
    // Same geometry as the design system (viewBox 120 × 232)
    private static let front: [Region] = [
        r(49, 6, 22, 22, 11, []), r(55, 29, 10, 7, 2, ["neck"]),
        r(26, 37, 16, 16, 8, ["shoulders"]), r(78, 37, 16, 16, 8, ["shoulders"]),
        r(42, 38, 17, 22, 4, ["chest"]), r(61, 38, 17, 22, 4, ["chest"]),
        r(24, 55, 13, 30, 6, ["biceps"]), r(83, 55, 13, 30, 6, ["biceps"]),
        r(20, 88, 12, 34, 5, ["forearms"]), r(88, 88, 12, 34, 5, ["forearms"]),
        r(48, 63, 11, 12, 2, ["abdominals"]), r(61, 63, 11, 12, 2, ["abdominals"]),
        r(48, 77, 11, 12, 2, ["abdominals"]), r(61, 77, 11, 12, 2, ["abdominals"]),
        r(48, 91, 11, 12, 2, ["abdominals"]), r(61, 91, 11, 12, 2, ["abdominals"]),
        r(41, 64, 5, 36, 2, ["abdominals"]), r(74, 64, 5, 36, 2, ["abdominals"]),
        r(43, 106, 34, 12, 4, ["adductors", "abductors"]),
        r(42, 121, 17, 52, 8, ["quadriceps"]), r(61, 121, 17, 52, 8, ["quadriceps"]),
        r(44, 180, 13, 46, 6, ["calves"]), r(63, 180, 13, 46, 6, ["calves"]),
    ]
    private static let back: [Region] = [
        r(49, 6, 22, 22, 11, []), r(45, 29, 30, 14, 6, ["traps", "neck"]),
        r(26, 37, 16, 16, 8, ["shoulders"]), r(78, 37, 16, 16, 8, ["shoulders"]),
        r(40, 46, 11, 40, 5, ["lats"]), r(69, 46, 11, 40, 5, ["lats"]),
        r(53, 46, 14, 30, 3, ["middle back"]), r(50, 79, 20, 22, 3, ["lower back"]),
        r(24, 55, 13, 30, 6, ["triceps"]), r(83, 55, 13, 30, 6, ["triceps"]),
        r(20, 88, 12, 34, 5, ["forearms"]), r(88, 88, 12, 34, 5, ["forearms"]),
        r(42, 104, 17, 20, 8, ["glutes", "abductors"]), r(61, 104, 17, 20, 8, ["glutes", "abductors"]),
        r(42, 127, 17, 46, 8, ["hamstrings", "adductors"]), r(61, 127, 17, 46, 8, ["hamstrings", "adductors"]),
        r(43, 178, 15, 48, 7, ["calves"]), r(62, 178, 15, 48, 7, ["calves"]),
    ]

    var body: some View {
        HStack(spacing: 1) {
            figure(Self.front, label: "Front")
            figure(Self.back, label: "Back")
        }
        .padding(1)
        .background(VoltColor.border)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Primary: \(primary.joined(separator: ", ")). Secondary: \(secondary.isEmpty ? "none" : secondary.joined(separator: ", ")).")
    }

    private func figure(_ regions: [Region], label: String) -> some View {
        VStack(spacing: 8) {
            Canvas { context, size in
                let scale = min(size.width / 120, size.height / 232)
                let dx = (size.width - 120 * scale) / 2
                for region in regions {
                    let rect = CGRect(x: dx + region.rect.minX * scale, y: region.rect.minY * scale,
                                      width: region.rect.width * scale, height: region.rect.height * scale)
                    let path = Path(roundedRect: rect, cornerRadius: region.radius * scale)
                    let isPrimary = !Set(region.muscles).isDisjoint(with: primary)
                    let isSecondary = !isPrimary && !Set(region.muscles).isDisjoint(with: secondary)
                    context.fill(path, with: .color(isPrimary ? VoltColor.accent : isSecondary ? VoltColor.accentDim : VoltColor.surfaceHigh))
                    if isSecondary { context.stroke(path, with: .color(VoltColor.accentText), lineWidth: 0.6 * scale) }
                }
            }
            .frame(height: 260)
            Text(label.uppercased()).font(VoltFont.mono(10)).tracking(0.8).foregroundStyle(VoltColor.labelSecondary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(VoltColor.bg)
    }
}

// MARK: - Spec grid: hard cells with hairline gaps
struct SpecGrid: View {
    let cells: [(label: String, value: String, unit: String)]
    var columns = 3

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: columns), spacing: 1) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                VStack(alignment: .leading, spacing: 8) {
                    Text(cell.label.uppercased()).font(VoltFont.mono(10)).tracking(0.8).foregroundStyle(VoltColor.labelSecondary)
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(cell.value).font(VoltFont.display(28)).tracking(-0.9).foregroundStyle(VoltColor.label)
                        Text(cell.unit).font(VoltFont.mono(11)).foregroundStyle(VoltColor.labelSecondary)
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 12).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VoltColor.bg)
            }
        }
        .padding(1)
        .background(VoltColor.border)
    }
}

// MARK: - Uppercase mono tags that wrap
struct FlowTags: View {
    let tags: [String]
    var markFirst = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { content }
            VStack(alignment: .leading, spacing: 6) { content }
        }
    }

    @ViewBuilder private var content: some View {
        ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
            HStack(spacing: 6) {
                if markFirst && index == 0 { Rectangle().fill(VoltColor.accent).frame(width: 6, height: 6) }
                Text(tag.uppercased()).font(VoltFont.mono(11)).tracking(0.6)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(VoltColor.surfaceHigh)
            .foregroundStyle(VoltColor.labelSecondary)
        }
    }
}

struct CreateExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var muscleGroup: Exercise.MuscleGroup = .chest
    @State private var equipment: Exercise.Equipment = .barbell
    @State private var instructions = ""

    var body: some View {
        NavigationStack {
            ZStack {
                VoltColor.bg.ignoresSafeArea()
                List {
                    Section("Exercise Details") {
                        TextField("Name (e.g. Cable Fly)", text: $name)
                            .foregroundStyle(VoltColor.label)
                            .listRowBackground(VoltColor.surface)
                        Picker("Muscle Group", selection: $muscleGroup) {
                            ForEach(Exercise.MuscleGroup.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .foregroundStyle(VoltColor.label)
                        .listRowBackground(VoltColor.surface)
                        Picker("Equipment", selection: $equipment) {
                            ForEach(Exercise.Equipment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .foregroundStyle(VoltColor.label)
                        .listRowBackground(VoltColor.surface)
                    }
                    .listRowSeparatorTint(VoltColor.border)

                    Section("Instructions (Optional)") {
                        TextEditor(text: $instructions)
                            .frame(minHeight: 80)
                            .foregroundStyle(VoltColor.label)
                            .listRowBackground(VoltColor.surface)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(VoltColor.labelSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let ex = Exercise(name: name.trimmingCharacters(in: .whitespaces),
                                         muscleGroup: muscleGroup, equipment: equipment,
                                         instructions: instructions, isCustom: true)
                        modelContext.insert(ex); try? modelContext.save(); dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(VoltColor.accent)
                }
            }
        }
    }
}

#Preview("Exercise Library") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Exercise.self, configurations: config)
    DataManager.seedExercisesIfNeeded(context: container.mainContext)
    return ExerciseLibraryView().modelContainer(container)
}
