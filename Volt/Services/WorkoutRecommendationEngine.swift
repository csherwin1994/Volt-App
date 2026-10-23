import Foundation

// MARK: - What the engine returns

/// One exercise in a suggested workout, with targets for today.
struct PlannedExercise: Equatable {
    let name: String
    let muscleGroup: String
    let sets: Int
    let reps: Int
    /// Suggested working weight in the user's unit, or nil when there is no history to base it on.
    let weight: Double?
    /// Short reason for the target, e.g. "+2.5 kg: you hit 6 reps on every set last time".
    let note: String
}

/// A suggested workout: either one of the user's routines or one built from the exercise library.
struct WorkoutRecommendation {
    let title: String
    let reason: String
    let muscleGroups: [String]
    let exercises: [PlannedExercise]
    /// Name of the saved routine this is based on, if any.
    let routineName: String?

    var buttonLabel: String { "Start \(title)" }
}

// MARK: - Inputs (plain values, so the engine can be tested without SwiftData)

enum Recommender {
    struct LoggedSet: Equatable { let weight: Double; let reps: Int }

    struct LoggedExercise {
        let name: String
        let muscleGroup: String
        let sets: [LoggedSet]
    }

    struct PastWorkout {
        let date: Date
        let title: String
        let exercises: [LoggedExercise]
    }

    struct RoutineTemplate {
        let name: String
        let exercises: [(name: String, muscleGroup: String, sets: Int, reps: Int, weight: Double)]
    }

    struct CandidateExercise {
        let name: String
        let muscleGroup: String
        let equipment: String
        let isCompound: Bool
        let level: String
    }

    struct Settings {
        /// Equipment raw values the user has access to; empty means everything.
        var availableEquipment: Set<String> = []
        /// Working-weight step for compound lifts; isolation lifts use half of it.
        var weightIncrement: Double = 2.5
        /// Hard sets per muscle group per week the engine aims for.
        var weeklySetTarget: Double = 12
        var exercisesPerWorkout: Int = 5
        /// "kg" or "lb", used in the notes.
        var unit: String = "kg"
    }
}

// MARK: - Engine

/// Suggests the next workout from training history.
///
/// How it decides:
/// 1. **Recovery.** Each muscle group carries fatigue from recent sets (a full set for the exercise's own
///    group, half a set for groups it trains secondarily), fading with a 36-hour half-life. A group is
///    ready once its remaining fatigue drops below about three sets.
/// 2. **Weekly volume.** Groups that got fewer than `weeklySetTarget` hard sets in the last 7 days score higher.
/// 3. **Pick.** If one of the user's routines trains ready, under-worked groups (and wasn't the last workout),
///    suggest it. Otherwise build a workout from exercises the user already knows, filled in from the library.
/// 4. **Targets.** Every exercise gets sets, reps and a weight from the last time it was done
///    (double progression: add reps up to the target, then add weight and drop back).
enum WorkoutRecommendationEngine {
    static let halfLifeHours: Double = 36
    static let readyFatigue: Double = 3
    static let trainableGroups = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Legs", "Glutes", "Core"]

    /// Groups an exercise in each group also loads, at half weight.
    static let secondaryGroups: [String: [String]] = [
        "Chest": ["Triceps", "Shoulders"],
        "Back": ["Biceps"],
        "Shoulders": ["Triceps"],
        "Legs": ["Glutes"],
        "Glutes": ["Legs"],
    ]

    // MARK: Entry point

    static func recommend(
        history: [Recommender.PastWorkout],
        routines: [Recommender.RoutineTemplate],
        candidates: [Recommender.CandidateExercise],
        settings: Recommender.Settings = .init(),
        now: Date = Date()
    ) -> WorkoutRecommendation {
        let history = history.sorted { $0.date > $1.date }

        guard !history.isEmpty else {
            if let first = routines.first {
                return fromRoutine(first, history: [], candidates: candidates, settings: settings,
                                   reason: "Start with one of your routines. Suggestions get smarter with every workout you log.")
            }
            let starter = ["Legs", "Chest", "Back"]
            return generated(for: starter, history: [], candidates: candidates, settings: settings,
                             title: "Full Body Starter",
                             reason: "A balanced first session. Pick weights you could lift for two more reps.")
        }

        let fatigue = muscleFatigue(history: history, now: now)
        let weekly = weeklySets(history: history, now: now)
        let score = groupScores(fatigue: fatigue, weekly: weekly, settings: settings)
        let ready = trainableGroups.filter { (fatigue[$0] ?? 0) < readyFatigue }

        guard !ready.isEmpty else {
            return WorkoutRecommendation(
                title: "Recovery Day",
                reason: "Every major muscle group was trained hard in the last day or two. Rest, walk or stretch today.",
                muscleGroups: [],
                exercises: [],
                routineName: nil
            )
        }

        // A saved routine that fits today
        let lastTitle = history.first?.title
        let scoredRoutines = routines.compactMap { routine -> (Recommender.RoutineTemplate, Double, [String])? in
            let groups = orderedGroups(routine.exercises.map(\.muscleGroup)).filter { trainableGroups.contains($0) }
            guard !groups.isEmpty, groups.allSatisfy({ ready.contains($0) }) else { return nil }
            let value = groups.map { score[$0] ?? 0 }.reduce(0, +) / Double(groups.count)
            let penalty = routine.name == lastTitle ? 0.5 : 1
            return (routine, value * penalty, groups)
        }
        if let best = scoredRoutines.max(by: { $0.1 < $1.1 }) {
            return fromRoutine(best.0, history: history, candidates: candidates, settings: settings,
                               reason: reason(for: best.2, fatigue: fatigue, weekly: weekly, history: history, now: now))
        }

        // Otherwise build one: the two or three most ready, least-worked groups
        let picks = Array(ready.sorted { (score[$0] ?? 0) > (score[$1] ?? 0) }.prefix(ready.count >= 3 ? 3 : ready.count))
        return generated(for: picks, history: history, candidates: candidates, settings: settings,
                         title: title(for: picks),
                         reason: reason(for: picks, fatigue: fatigue, weekly: weekly, history: history, now: now))
    }

    // MARK: Recovery and volume

    /// Remaining fatigue per group, in "sets".
    static func muscleFatigue(history: [Recommender.PastWorkout], now: Date) -> [String: Double] {
        var fatigue: [String: Double] = [:]
        for workout in history {
            let hours = max(0, now.timeIntervalSince(workout.date) / 3600)
            guard hours < 24 * 10 else { continue }
            let decay = pow(0.5, hours / halfLifeHours)
            for exercise in workout.exercises {
                let sets = Double(exercise.sets.count)
                fatigue[exercise.muscleGroup, default: 0] += sets * decay
                for secondary in secondaryGroups[exercise.muscleGroup] ?? [] {
                    fatigue[secondary, default: 0] += sets * 0.5 * decay
                }
            }
        }
        return fatigue
    }

    /// Hard sets per group over the last 7 days (secondary work counts half).
    static func weeklySets(history: [Recommender.PastWorkout], now: Date) -> [String: Double] {
        var sets: [String: Double] = [:]
        for workout in history where now.timeIntervalSince(workout.date) < 7 * 86_400 {
            for exercise in workout.exercises {
                sets[exercise.muscleGroup, default: 0] += Double(exercise.sets.count)
                for secondary in secondaryGroups[exercise.muscleGroup] ?? [] {
                    sets[secondary, default: 0] += Double(exercise.sets.count) * 0.5
                }
            }
        }
        return sets
    }

    /// Higher = better to train today. Combines readiness with how far below the weekly target a group is.
    static func groupScores(fatigue: [String: Double], weekly: [String: Double], settings: Recommender.Settings) -> [String: Double] {
        var scores: [String: Double] = [:]
        for group in trainableGroups {
            let readiness = max(0, 1 - (fatigue[group] ?? 0) / 10)
            let deficit = max(0, settings.weeklySetTarget - (weekly[group] ?? 0)) / settings.weeklySetTarget
            // Small groups (arms, core) get trained indirectly; weight the big ones a little higher
            let size: Double = ["Legs", "Back", "Chest"].contains(group) ? 1.15 : (group == "Shoulders" || group == "Glutes" ? 1.0 : 0.8)
            scores[group] = (readiness * 0.6 + deficit * 0.4) * size
        }
        return scores
    }

    // MARK: Building the suggestion

    static func fromRoutine(
        _ routine: Recommender.RoutineTemplate,
        history: [Recommender.PastWorkout],
        candidates: [Recommender.CandidateExercise],
        settings: Recommender.Settings,
        reason: String
    ) -> WorkoutRecommendation {
        let compound = Dictionary(candidates.map { ($0.name, $0.isCompound) }, uniquingKeysWith: { a, _ in a })
        let exercises = routine.exercises.map { item in
            target(for: item.name, muscleGroup: item.muscleGroup,
                   isCompound: compound[item.name] ?? (item.reps <= 8),
                   defaultSets: item.sets, defaultReps: item.reps,
                   routineWeight: item.weight > 0 ? item.weight : nil,
                   history: history, settings: settings)
        }
        return WorkoutRecommendation(
            title: routine.name,
            reason: reason,
            muscleGroups: orderedGroups(routine.exercises.map(\.muscleGroup)),
            exercises: exercises,
            routineName: routine.name
        )
    }

    static func generated(
        for groups: [String],
        history: [Recommender.PastWorkout],
        candidates: [Recommender.CandidateExercise],
        settings: Recommender.Settings,
        title: String,
        reason: String
    ) -> WorkoutRecommendation {
        let usage = exerciseUsage(history: history)
        let usable = candidates.filter {
            settings.availableEquipment.isEmpty || settings.availableEquipment.contains($0.equipment)
        }
        let perGroup = max(1, settings.exercisesPerWorkout / max(1, groups.count))
        var chosen: [PlannedExercise] = []
        var used = Set<String>()

        for (index, group) in groups.enumerated() {
            // Familiar exercises first (most logged), then compound lifts for beginners and intermediates
            let options = usable.filter { $0.muscleGroup == group && !used.contains($0.name) }
                .sorted { a, b in
                    let ua = usage[a.name] ?? 0, ub = usage[b.name] ?? 0
                    if ua != ub { return ua > ub }
                    if a.isCompound != b.isCompound { return a.isCompound }
                    if levelRank(a.level) != levelRank(b.level) { return levelRank(a.level) < levelRank(b.level) }
                    return a.name < b.name
                }
            // The first group leads, so it gets an extra exercise when there is room
            let count = index == 0 ? perGroup + (settings.exercisesPerWorkout - perGroup * groups.count) : perGroup
            for option in options.prefix(max(1, count)) {
                used.insert(option.name)
                chosen.append(target(for: option.name, muscleGroup: group, isCompound: option.isCompound,
                                     defaultSets: option.isCompound ? 4 : 3,
                                     defaultReps: option.isCompound ? 6 : 10,
                                     routineWeight: nil, history: history, settings: settings))
            }
        }
        // Compound lifts first
        let ordered = chosen.enumerated().sorted { a, b in
            let ca = a.element.reps <= 8, cb = b.element.reps <= 8
            return ca != cb ? ca : a.offset < b.offset
        }.map(\.element)

        return WorkoutRecommendation(title: title, reason: reason, muscleGroups: groups,
                                     exercises: ordered, routineName: nil)
    }

    /// Sets, reps and weight for today, by double progression on the last session of this exercise.
    static func target(
        for name: String,
        muscleGroup: String,
        isCompound: Bool,
        defaultSets: Int,
        defaultReps: Int,
        routineWeight: Double?,
        history: [Recommender.PastWorkout],
        settings: Recommender.Settings
    ) -> PlannedExercise {
        let repTop = isCompound ? max(defaultReps, 6) : max(defaultReps, 10)
        // Rep range: compound lifts work in [top - 2, top], isolation in [top - 3, top]
        let repFloor = isCompound ? max(3, repTop - 2) : max(5, repTop - 3)
        let step = isCompound ? settings.weightIncrement : settings.weightIncrement / 2

        guard let last = lastSets(of: name, history: history), let top = last.max(by: { $0.weight < $1.weight }), top.weight > 0 else {
            let note = routineWeight == nil
                ? "Pick a weight you could lift for \(defaultReps + 2) reps."
                : "From your routine."
            return PlannedExercise(name: name, muscleGroup: muscleGroup, sets: defaultSets, reps: defaultReps,
                                   weight: routineWeight, note: note)
        }

        let working = last.filter { $0.weight == top.weight }
        let minReps = working.map(\.reps).min() ?? top.reps
        let sets = max(defaultSets, last.count)

        if minReps >= repTop {
            return PlannedExercise(name: name, muscleGroup: muscleGroup, sets: sets, reps: repFloor,
                                   weight: top.weight + step,
                                   note: "Up \(step.formatted()) \(settings.unit): you hit \(repTop) reps on every set last time.")
        }
        let reps = min(repTop, max(repFloor, minReps + 1))
        return PlannedExercise(name: name, muscleGroup: muscleGroup, sets: sets, reps: reps, weight: top.weight,
                               note: "Same weight, aim for \(reps) reps (last time \(minReps)).")
    }

    // MARK: Helpers

    static func lastSets(of name: String, history: [Recommender.PastWorkout]) -> [Recommender.LoggedSet]? {
        for workout in history {
            if let exercise = workout.exercises.first(where: { $0.name == name }), !exercise.sets.isEmpty {
                return exercise.sets
            }
        }
        return nil
    }

    static func exerciseUsage(history: [Recommender.PastWorkout]) -> [String: Int] {
        var usage: [String: Int] = [:]
        for workout in history { for exercise in workout.exercises { usage[exercise.name, default: 0] += 1 } }
        return usage
    }

    static func orderedGroups(_ groups: [String]) -> [String] {
        var counts: [String: Int] = [:]
        var firstIndex: [String: Int] = [:]
        for (i, g) in groups.enumerated() {
            counts[g, default: 0] += 1
            if firstIndex[g] == nil { firstIndex[g] = i }
        }
        return counts.keys.sorted { (counts[$0]!, -firstIndex[$0]!) > (counts[$1]!, -firstIndex[$1]!) }
    }

    static func levelRank(_ level: String) -> Int {
        switch level { case "beginner": return 0; case "intermediate": return 1; case "expert": return 2; default: return 1 }
    }

    static func title(for groups: [String]) -> String {
        let set = Set(groups)
        if set.isSubset(of: ["Chest", "Shoulders", "Triceps"]) { return "Push Day" }
        if set.isSubset(of: ["Back", "Biceps"]) { return "Pull Day" }
        if set.isSubset(of: ["Legs", "Glutes", "Core"]) { return "Leg Day" }
        return groups.prefix(2).joined(separator: " & ")
    }

    static func reason(
        for groups: [String],
        fatigue: [String: Double],
        weekly: [String: Double],
        history: [Recommender.PastWorkout],
        now: Date
    ) -> String {
        let lead = groups.first ?? ""
        let daysSince = history.first { $0.exercises.contains { $0.muscleGroup == lead } }
            .map { Int(now.timeIntervalSince($0.date) / 86_400) }
        let sets = Int((weekly[lead] ?? 0).rounded())
        let named = groups.prefix(2).map { $0.lowercased() }.joined(separator: " and ")
        let subject = named.prefix(1).uppercased() + named.dropFirst()
        let verb = groups.count > 1 ? "are" : "is"
        switch daysSince {
        case nil:
            return "You haven't trained \(named) yet."
        case let d? where d >= 7:
            return "\(subject) last trained \(d) days ago."
        case let d?:
            let when = d <= 1 ? "yesterday" : "\(d) days ago"
            return "\(subject) \(verb) recovered since \(when), with \(sets) sets so far this week."
        }
    }
}

// MARK: - SwiftData adapter

extension WorkoutRecommendationEngine {
    /// Categories the generator draws from. Stretches, cardio and skill-heavy lifts are left to the user to add.
    static let generatorCategories: Set<String> = ["strength", "powerlifting"]

    static func recommend(
        sessions: [WorkoutSession],
        routines: [Routine],
        library: [Exercise],
        settings: Recommender.Settings = .init(),
        now: Date = Date()
    ) -> WorkoutRecommendation {
        let history = sessions.filter { $0.endDate != nil }.map { session in
            Recommender.PastWorkout(
                date: session.startDate,
                title: session.title,
                exercises: session.exerciseLogs.map { log in
                    Recommender.LoggedExercise(
                        name: log.exerciseName,
                        muscleGroup: log.exerciseMuscleGroup,
                        sets: log.completedSets.map { Recommender.LoggedSet(weight: $0.weight, reps: $0.reps) }
                    )
                }.filter { !$0.sets.isEmpty }
            )
        }
        let templates = routines.map { routine in
            Recommender.RoutineTemplate(
                name: routine.name,
                exercises: routine.exercises.sorted { $0.orderIndex < $1.orderIndex }.map {
                    (name: $0.exerciseName, muscleGroup: $0.exerciseMuscleGroup,
                     sets: $0.targetSets, reps: $0.targetReps, weight: $0.targetWeight)
                }
            )
        }
        let candidates = library
            .filter { generatorCategories.contains($0.category) && trainableGroups.contains($0.muscleGroup.rawValue) }
            .map {
                Recommender.CandidateExercise(
                    name: $0.name,
                    muscleGroup: $0.muscleGroup.rawValue,
                    equipment: $0.equipment.rawValue,
                    isCompound: $0.isLikelyCompound,
                    level: $0.level
                )
            }
        return recommend(history: history, routines: templates, candidates: candidates, settings: settings, now: now)
    }
}

extension Recommender.Settings {
    /// Settings from the user's preferences (Profile → weight unit and gym equipment).
    static func fromPreferences(_ defaults: UserDefaults = .standard) -> Recommender.Settings {
        var settings = Recommender.Settings()
        let unit = defaults.string(forKey: "weightUnit") ?? "kg"
        settings.unit = unit
        settings.weightIncrement = unit == "lb" ? 5 : 2.5
        let unavailable = Set((defaults.string(forKey: "unavailableEquipment") ?? "").split(separator: ",").map(String.init))
        if !unavailable.isEmpty {
            settings.availableEquipment = Set(Exercise.Equipment.allCases.map(\.rawValue)).subtracting(unavailable)
        }
        return settings
    }
}

