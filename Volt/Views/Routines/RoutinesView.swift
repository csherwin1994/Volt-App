import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @Environment(\.modelContext) private var modelContext
    @State private var showingCreate = false
    /// Set when shown inside the Library tab, which adds the Exercises / Routines switch.
    var librarySection: Binding<LibraryView.Section>? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                VoltColor.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                if let librarySection { LibrarySectionPicker(selection: librarySection) }

                if routines.isEmpty {
                    EmptyStateView(
                        icon: "repeat",
                        title: "No Routines Yet",
                        message: "Create routines to quickly start structured workouts without planning each time.",
                        actionTitle: "Create Routine",
                        action: { showingCreate = true }
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(routines) { routine in
                            NavigationLink { RoutineDetailView(routine: routine) } label: {
                                RoutineRow(routine: routine)
                            }
                            .listRowBackground(VoltColor.surface)
                            .listRowSeparatorTint(VoltColor.border)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        }
                        .onDelete { offsets in
                            offsets.forEach { modelContext.delete(routines[$0]) }
                            try? modelContext.save()
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
                }
            }
            .navigationTitle(librarySection == nil ? "Routines" : "Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus").foregroundStyle(VoltColor.ink)
                    }
                }
            }
            .sheet(isPresented: $showingCreate) { CreateRoutineView() }
        }
    }
}

struct RoutineRow: View {
    let routine: Routine

    private var muscles: [Exercise.MuscleGroup] {
        Array(Set(routine.exercises.map(\.exerciseMuscleGroup)))
            .compactMap { Exercise.MuscleGroup(rawValue: $0) }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(routine.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(VoltColor.label)
                Spacer()
                Text("\(routine.exerciseCount) ex")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(VoltColor.labelSecondary)
            }
            if !muscles.isEmpty {
                HStack(spacing: 5) { ForEach(muscles, id: \.self) { MuscleBadge(group: $0) } }
            }
            if let last = routine.lastUsedAt {
                Text("Last used \(last.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(VoltColor.labelTertiary)
            }
        }
    }
}

struct RoutineDetailView: View {
    @Bindable var routine: Routine
    @Environment(\.modelContext) private var modelContext
    @State private var showingExercisePicker = false

    private var sortedExercises: [RoutineExercise] {
        routine.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        ZStack {
            VoltColor.bg.ignoresSafeArea()
            List {
                Section("Exercises") {
                    ForEach(sortedExercises) { ex in
                        RoutineExerciseRow(exercise: ex)
                            .listRowBackground(VoltColor.surface)
                            .listRowSeparatorTint(VoltColor.border)
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

                    Button {
                        showingExercisePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill").foregroundStyle(VoltColor.accent)
                            Text("Add Exercise").foregroundStyle(VoltColor.accent)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    .listRowBackground(VoltColor.surface)
                }

                if !routine.notes.isEmpty {
                    Section("Notes") {
                        Text(routine.notes)
                            .font(.subheadline)
                            .foregroundStyle(VoltColor.labelSecondary)
                            .listRowBackground(VoltColor.surface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { EditButton().foregroundStyle(VoltColor.accent) } }
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
    @Bindable var exercise: RoutineExercise
    @AppStorage("weightUnit") private var weightUnit = "kg"

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VoltColor.label)
                Text("\(exercise.targetSets) × \(exercise.targetReps) reps")
                    .font(.caption)
                    .foregroundStyle(VoltColor.labelSecondary)
            }
            Spacer()
            if exercise.targetWeight > 0 {
                Text(String(format: "%.0f \(weightUnit)", exercise.targetWeight))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(VoltColor.accent)
            }
        }
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
