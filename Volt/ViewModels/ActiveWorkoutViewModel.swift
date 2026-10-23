import SwiftUI
import SwiftData

@Observable
final class ActiveWorkoutViewModel {
    var session: WorkoutSession?
    var isActive: Bool = false
    var elapsedSeconds: Int = 0
    var restTimerSeconds: Int = 0
    var isRestTimerRunning: Bool = false
    /// Length of the current rest period, used to draw the progress bar.
    var restTimerTotal: Int = 90

    /// Sets that beat the previous best for their exercise during this workout.
    var personalRecordSetIDs: Set<UUID> = []
    /// Short message shown briefly after a new personal record, e.g. "New PR · Bench Press 90 kg".
    var latestRecordMessage: String?

    /// Finished workouts, loaded when a workout starts. Used for the "Previous" column and PR checks.
    private(set) var history: [WorkoutSession] = []

    private var workoutTimer: Timer?
    private var restTimer: Timer?
    private var restEndDate: Date?
    private var modelContext: ModelContext?

    // MARK: - Lifecycle

    func startWorkout(title: String = "My Workout", context: ModelContext) {
        loadHistory(context: context)
        let newSession = WorkoutSession(title: title)
        context.insert(newSession)
        self.session = newSession
        self.modelContext = context
        self.isActive = true
        self.elapsedSeconds = 0
        self.personalRecordSetIDs = []
        self.latestRecordMessage = nil
        startWorkoutTimer()
    }

    func startFromRoutine(_ routine: Routine, context: ModelContext) {
        routine.lastUsedAt = Date()
        startWorkout(title: routine.name, context: context)
        guard let session else { return }

        let sorted = routine.exercises.sorted { $0.orderIndex < $1.orderIndex }
        for (index, routineExercise) in sorted.enumerated() {
            let log = ExerciseLog(
                exerciseName: routineExercise.exerciseName,
                exerciseMuscleGroup: routineExercise.exerciseMuscleGroup,
                orderIndex: index
            )
            context.insert(log)
            for i in 0..<routineExercise.targetSets {
                let set = WorkoutSet(
                    orderIndex: i,
                    weight: routineExercise.targetWeight,
                    reps: routineExercise.targetReps
                )
                context.insert(set)
                log.sets.append(set)
            }
            session.exerciseLogs.append(log)
        }
        try? context.save()
    }

    /// Starts the suggested workout with each exercise's target sets, reps and weight filled in.
    func startFromRecommendation(_ recommendation: WorkoutRecommendation, routines: [Routine], context: ModelContext) {
        if let name = recommendation.routineName, let routine = routines.first(where: { $0.name == name }) {
            routine.lastUsedAt = Date()
        }
        startWorkout(title: recommendation.title, context: context)
        guard let session else { return }
        for (index, planned) in recommendation.exercises.enumerated() {
            let log = ExerciseLog(exerciseName: planned.name, exerciseMuscleGroup: planned.muscleGroup, orderIndex: index)
            context.insert(log)
            for i in 0..<max(1, planned.sets) {
                let set = WorkoutSet(orderIndex: i, weight: planned.weight ?? 0, reps: planned.reps)
                context.insert(set)
                log.sets.append(set)
            }
            session.exerciseLogs.append(log)
        }
        try? context.save()
    }

    func addExercise(_ exercise: Exercise, context: ModelContext) {
        guard let session else { return }
        let log = ExerciseLog(
            exerciseName: exercise.name,
            exerciseMuscleGroup: exercise.muscleGroup.rawValue,
            orderIndex: session.exerciseLogs.count
        )
        context.insert(log)
        // Pre-fill the first set from last time, so the user only has to adjust it
        let previous = previousSets(for: exercise.name).first
        let firstSet = WorkoutSet(orderIndex: 0, weight: previous?.weight ?? 0, reps: previous?.reps ?? 0)
        context.insert(firstSet)
        log.sets.append(firstSet)
        session.exerciseLogs.append(log)
        try? context.save()
    }

    func addSet(to log: ExerciseLog, context: ModelContext) {
        let lastSet = log.sets.sorted { $0.orderIndex < $1.orderIndex }.last
        let newSet = WorkoutSet(
            orderIndex: log.sets.count,
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 0
        )
        context.insert(newSet)
        log.sets.append(newSet)
        try? context.save()
    }

    func removeSet(_ set: WorkoutSet, from log: ExerciseLog, context: ModelContext) {
        log.sets.removeAll { $0.id == set.id }
        personalRecordSetIDs.remove(set.id)
        context.delete(set)
        try? context.save()
    }

    func toggleSetComplete(_ set: WorkoutSet, context: ModelContext) {
        set.isCompleted.toggle()
        if set.isCompleted {
            set.completedAt = Date()
            checkForRecord(set)
            startRestTimer(seconds: 90, exerciseName: exerciseName(for: set))
        } else {
            personalRecordSetIDs.remove(set.id)
        }
        try? context.save()
    }

    func finishWorkout(context: ModelContext) {
        session?.endDate = Date()
        try? context.save()
        stopTimers()
        isActive = false
    }

    func discardWorkout(context: ModelContext) {
        if let session {
            context.delete(session)
            try? context.save()
        }
        stopTimers()
        session = nil
        isActive = false
        elapsedSeconds = 0
        personalRecordSetIDs = []
    }

    // MARK: - History helpers

    private func loadHistory(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        history = ((try? context.fetch(descriptor)) ?? []).filter { $0.endDate != nil }
    }

    /// Completed sets from the most recent finished workout that included this exercise.
    func previousSets(for exerciseName: String) -> [WorkoutSet] {
        for workout in history {
            if let log = workout.exerciseLogs.first(where: { $0.exerciseName == exerciseName }), !log.completedSets.isEmpty {
                return log.completedSets
            }
        }
        return []
    }

    private func exerciseName(for set: WorkoutSet) -> String? {
        session?.exerciseLogs.first { log in log.sets.contains { $0.id == set.id } }?.exerciseName
    }

    // MARK: - Personal records

    private func checkForRecord(_ set: WorkoutSet) {
        guard let name = exerciseName(for: set), set.weight > 0, set.reps > 0 else { return }

        // Best from earlier workouts, plus sets already completed in this one
        var earlier = history.flatMap { $0.exerciseLogs }.filter { $0.exerciseName == name }.flatMap(\.completedSets)
        if let log = session?.exerciseLogs.first(where: { $0.exerciseName == name }) {
            earlier += log.completedSets.filter { $0.id != set.id }
        }
        let best = PersonalRecords.best(in: earlier)
        let record = PersonalRecords.record(for: set, comparedTo: best)

        guard let record else { return }
        personalRecordSetIDs.insert(set.id)
        let unit = UserDefaults.standard.string(forKey: "weightUnit") ?? "kg"
        latestRecordMessage = "New \(record.label) · \(name) \(set.weight.formatted()) \(unit) × \(set.reps)"
        let message = latestRecordMessage
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.latestRecordMessage == message { self?.latestRecordMessage = nil }
        }
    }

    // MARK: - Rest timer

    func startRestTimer(seconds: Int, exerciseName: String? = nil) {
        restTimerSeconds = seconds
        restTimerTotal = seconds
        restEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        isRestTimerRunning = true
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickRest()
        }
        RestTimerLiveActivity.start(
            workoutTitle: session?.title ?? "Workout",
            exerciseName: exerciseName,
            endDate: restEndDate ?? Date()
        )
    }

    /// Adds or removes time from the running rest timer (e.g. −15 s / +15 s buttons).
    func adjustRestTimer(by seconds: Int) {
        guard isRestTimerRunning, let end = restEndDate else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(seconds))
        if newEnd <= Date() { stopRestTimer(); return }
        restEndDate = newEnd
        restTimerTotal = max(restTimerTotal + seconds, 1)
        restTimerSeconds = max(0, Int(newEnd.timeIntervalSinceNow.rounded()))
        RestTimerLiveActivity.update(endDate: newEnd)
    }

    func stopRestTimer() {
        restTimer?.invalidate()
        isRestTimerRunning = false
        restTimerSeconds = 0
        restEndDate = nil
        RestTimerLiveActivity.end()
    }

    /// Counts down from the end date, so the timer stays correct if the app was in the background.
    private func tickRest() {
        guard let end = restEndDate else { stopRestTimer(); return }
        let left = Int(end.timeIntervalSinceNow.rounded())
        if left > 0 {
            restTimerSeconds = left
        } else {
            stopRestTimer()
        }
    }

    var restProgress: Double {
        guard restTimerTotal > 0 else { return 0 }
        return min(1, max(0, Double(restTimerSeconds) / Double(restTimerTotal)))
    }

    private func startWorkoutTimer() {
        workoutTimer?.invalidate()
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func stopTimers() {
        workoutTimer?.invalidate()
        restTimer?.invalidate()
        workoutTimer = nil
        restTimer = nil
        isRestTimerRunning = false
        restTimerSeconds = 0
        restEndDate = nil
        RestTimerLiveActivity.end()
    }

    var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    var formattedRest: String {
        let m = restTimerSeconds / 60
        let s = restTimerSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Personal records

enum PersonalRecords {
    struct Best: Equatable {
        var heaviestWeight: Double = 0
        var bestOneRepMax: Double = 0
        var mostRepsAtHeaviest: Int = 0
    }

    enum Kind {
        case weight, oneRepMax
        var label: String {
            switch self {
            case .weight:    return "weight PR"
            case .oneRepMax: return "1RM PR"
            }
        }
    }

    struct Record { let kind: Kind; var label: String { kind.label } }

    /// Estimated one-rep max using the Epley formula.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        return reps == 1 ? weight : weight * (1 + Double(reps) / 30)
    }

    static func best(in sets: [WorkoutSet]) -> Best {
        var best = Best()
        for set in sets where set.weight > 0 && set.reps > 0 {
            if set.weight > best.heaviestWeight {
                best.heaviestWeight = set.weight
                best.mostRepsAtHeaviest = set.reps
            } else if set.weight == best.heaviestWeight {
                best.mostRepsAtHeaviest = max(best.mostRepsAtHeaviest, set.reps)
            }
            best.bestOneRepMax = max(best.bestOneRepMax, estimatedOneRepMax(weight: set.weight, reps: set.reps))
        }
        return best
    }

    /// Returns a record if this set beats the previous best. The first time an exercise is logged doesn't count.
    static func record(for set: WorkoutSet, comparedTo best: Best) -> Record? {
        guard best.heaviestWeight > 0, set.weight > 0, set.reps > 0 else { return nil }
        if set.weight > best.heaviestWeight { return Record(kind: .weight) }
        if estimatedOneRepMax(weight: set.weight, reps: set.reps) > best.bestOneRepMax + 0.01 { return Record(kind: .oneRepMax) }
        return nil
    }

    /// IDs of sets in `session` that were personal records at the time, compared with earlier finished workouts.
    static func recordSetIDs(in session: WorkoutSession, history: [WorkoutSession]) -> Set<UUID> {
        let earlierSessions = history.filter { $0.endDate != nil && $0.startDate < session.startDate }
        var ids = Set<UUID>()
        for log in session.exerciseLogs {
            var earlier = earlierSessions.flatMap(\.exerciseLogs).filter { $0.exerciseName == log.exerciseName }.flatMap(\.completedSets)
            for set in log.completedSets {
                if record(for: set, comparedTo: best(in: earlier)) != nil { ids.insert(set.id) }
                earlier.append(set)
            }
        }
        return ids
    }
}
