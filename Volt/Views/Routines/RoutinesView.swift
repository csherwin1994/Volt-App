import SwiftUI
import SwiftData

// Library tab, Routines side. Same header and rule list as Library.dc.html.
struct RoutinesView: View {
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @Query private var exercises: [Exercise]
    @Environment(\.modelContext) private var modelContext
    @State private var showingCreate = false
    @State private var routineToDelete: Routine?
    /// Set when shown inside the Library tab, which adds the Exercises / Routines switch.
    var librarySection: Binding<LibraryView.Section>? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 20) {
                        VoltScreenHeader(
                            caption: "\(exercises.count) exercises · \(routines.count) routines",
                            title: librarySection == nil ? "Routines" : "Library"
                        ) {
                            VoltTextLink("New") { showingCreate = true }
                                .accessibilityLabel("New routine")
                        }
                        if let librarySection { LibrarySectionPicker(selection: librarySection) }
                    }
                    .padding(.bottom, 20)

                    VoltRule(strong: true)
                    if routines.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No routines yet.").font(VoltFont.sans(24)).tracking(-0.6).foregroundStyle(VoltColor.label)
                            Text("Save a workout plan and start it with one tap next time.")
                                .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                            VoltButton("Create Routine", style: .secondary) { showingCreate = true }
                                .padding(.top, 10)
                        }
                        .padding(.vertical, 24)
                    }
                    ForEach(routines) { routine in
                        NavigationLink { RoutineDetailView(routine: routine) } label: {
                            RoutineRow(routine: routine)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete Routine", role: .destructive) { routineToDelete = routine }
                        }
                        VoltRule()
                    }
                }
                .padding(.horizontal, VoltSpacing.gutter)
                .padding(.top, VoltSpacing.md)
                .padding(.bottom, VoltSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .background(VoltColor.bg.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreate) { CreateRoutineView() }
            .confirmationDialog("Delete routine?", isPresented: Binding(
                get: { routineToDelete != nil }, set: { if !$0 { routineToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let routine = routineToDelete { modelContext.delete(routine); try? modelContext.save() }
                    routineToDelete = nil
                }
                Button("Cancel", role: .cancel) { routineToDelete = nil }
            } message: {
                Text("Past workouts are kept.")
            }
        }
    }
}

struct RoutineRow: View {
    let routine: Routine

    private var summary: String {
        let names = routine.exercises.sorted { $0.orderIndex < $1.orderIndex }.map(\.exerciseName)
        return names.isEmpty ? "No exercises yet" : names.prefix(3).joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(VoltFont.sans(17)).foregroundStyle(VoltColor.label)
                    .lineLimit(1)
                Text(summary.uppercased())
                    .font(VoltFont.mono(11)).tracking(0.4)
                    .foregroundStyle(VoltColor.labelSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.right").font(.system(size: 14)).foregroundStyle(VoltColor.labelTertiary)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

struct RoutineDetailView: View {
    @Bindable var routine: Routine
    @Environment(\.modelContext) private var modelContext
    @State private var editMode: EditMode = .inactive
    @Query private var library: [Exercise]
    @State private var showingExercisePicker = false

    private var sortedExercises: [RoutineExercise] {
        routine.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 10) {
                VoltSectionTitle("Routine · \(routine.exerciseCount) exercises")
                Text(routine.name)
                    .font(VoltFont.sans(40)).tracking(-1.4)
                    .foregroundStyle(VoltColor.label)
                if !routine.notes.isEmpty {
                    Text(routine.notes).font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                }
                VoltRule(strong: true).padding(.top, 10)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: VoltSpacing.gutter, bottom: 0, trailing: VoltSpacing.gutter))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, ex in
                Group {
                    if let exercise = library.first(where: { $0.name == ex.exerciseName }) {
                        NavigationLink { ExerciseDetailView(exercise: exercise) } label: {
                            RoutineExerciseRow(index: index, exercise: ex)
                        }
                    } else {
                        RoutineExerciseRow(index: index, exercise: ex)
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: VoltSpacing.gutter, bottom: 0, trailing: VoltSpacing.gutter))
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(VoltColor.border)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
            .onDelete { offsets in
                let sorted = sortedExercises
                offsets.forEach { idx in
                    let ex = sorted[idx]
                    routine.exercises.removeAll { $0.id == ex.id }
                    modelContext.delete(ex)
                }
                try? modelContext.save()
            }
            .onMove { from, to in
                var sorted = sortedExercises
                sorted.move(fromOffsets: from, toOffset: to)
                for (i, ex) in sorted.enumerated() { ex.orderIndex = i }
                try? modelContext.save()
            }

            VoltButton("Add Exercise", icon: nil, style: .secondary) { showingExercisePicker = true }
                .listRowInsets(EdgeInsets(top: 20, leading: VoltSpacing.gutter, bottom: 20, trailing: VoltSpacing.gutter))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .scrollContentBackground(.hidden)
        .background(VoltColor.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(editMode.isEditing ? "DONE" : "REORDER") {
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                }
                .font(VoltFont.mono(11, weight: .medium))
                .foregroundStyle(VoltColor.label)
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet { exercise in
                let re = RoutineExercise(
                    exerciseName: exercise.name,
                    exerciseMuscleGroup: exercise.muscleGroup.rawValue,
                    orderIndex: routine.exercises.count
                )
                modelContext.insert(re)
                routine.exercises.append(re)
                try? modelContext.save()
            }
        }
    }
}

struct RoutineExerciseRow: View {
    let index: Int
    @Bindable var exercise: RoutineExercise
    @AppStorage("weightUnit") private var weightUnit = "kg"

    private var target: String {
        let base = "\(exercise.targetSets) × \(exercise.targetReps)"
        return exercise.targetWeight > 0 ? "\(base) · \(voltWeight(exercise.targetWeight)) \(weightUnit)" : base
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(VoltFont.mono(11)).foregroundStyle(VoltColor.labelTertiary)
                .frame(width: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exerciseName)
                    .font(VoltFont.sans(17)).foregroundStyle(VoltColor.label)
                Text(target.uppercased())
                    .font(VoltFont.mono(11)).tracking(0.4)
                    .foregroundStyle(VoltColor.labelSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }
}

struct CreateRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                VoltColor.bg.ignoresSafeArea()
                List {
                    Section("Details") {
                        TextField("Routine name (e.g. Push Day)", text: $name)
                            .foregroundStyle(VoltColor.label)
                            .listRowBackground(VoltColor.surface)
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(3)
                            .foregroundStyle(VoltColor.label)
                            .listRowBackground(VoltColor.surface)
                    }
                    .listRowSeparatorTint(VoltColor.border)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(VoltColor.labelSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let r = Routine(name: name.trimmingCharacters(in: .whitespaces), notes: notes)
                        modelContext.insert(r); try? modelContext.save(); dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(VoltColor.accent)
                }
            }
        }
    }
}

#Preview("Routines") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Routine.self, Exercise.self, WorkoutSession.self, configurations: config)
    let ctx = container.mainContext
    for (name, exercises) in [
        ("Push Day", [("Bench Press","Chest",4,8), ("OHP","Shoulders",3,10), ("Tricep Pushdown","Triceps",3,12)]),
        ("Pull Day", [("Deadlift","Back",3,5), ("Pull Up","Back",3,8), ("Curl","Biceps",3,12)])
    ] as [(String, [(String,String,Int,Int)])] {
        let r = Routine(name: name); ctx.insert(r)
        for (i, (ex, muscle, sets, reps)) in exercises.enumerated() {
            let re = RoutineExercise(exerciseName: ex, exerciseMuscleGroup: muscle, orderIndex: i, targetSets: sets, targetReps: reps)
            ctx.insert(re); r.exercises.append(re)
        }
    }
    try? ctx.save()
    return RoutinesView().modelContainer(container)
}
