import XCTest
@testable import Volt

final class RecommendationEngineTests: XCTestCase {
    typealias R = Recommender

    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func daysAgo(_ d: Double) -> Date { now.addingTimeInterval(-d * 86_400) }

    func workout(_ title: String, _ daysAgo: Double, _ items: [(String, String, [(Double, Int)])]) -> R.PastWorkout {
        R.PastWorkout(
            date: self.daysAgo(daysAgo),
            title: title,
            exercises: items.map { R.LoggedExercise(name: $0.0, muscleGroup: $0.1, sets: $0.2.map { R.LoggedSet(weight: $0.0, reps: $0.1) }) }
        )
    }

    var push: R.PastWorkout { workout("Push Day", 0, [("Bench Press", "Chest", [(80, 6), (80, 6), (80, 6)]), ("Tricep Pushdown", "Triceps", [(30, 10), (30, 10), (30, 10)])]) }

    let routines = [
        R.RoutineTemplate(name: "Push Day", exercises: [(name: "Bench Press", muscleGroup: "Chest", sets: 3, reps: 6, weight: 80),
                                                       (name: "Tricep Pushdown", muscleGroup: "Triceps", sets: 3, reps: 10, weight: 30)]),
        R.RoutineTemplate(name: "Pull Day", exercises: [(name: "Barbell Row", muscleGroup: "Back", sets: 3, reps: 8, weight: 60),
                                                       (name: "Barbell Curl", muscleGroup: "Biceps", sets: 3, reps: 10, weight: 30)]),
        R.RoutineTemplate(name: "Leg Day", exercises: [(name: "Squat", muscleGroup: "Legs", sets: 3, reps: 6, weight: 100),
                                                      (name: "Hip Thrust", muscleGroup: "Glutes", sets: 3, reps: 10, weight: 80)]),
    ]

    let candidates = [
        R.CandidateExercise(name: "Bench Press", muscleGroup: "Chest", equipment: "Barbell", isCompound: true, level: "beginner"),
        R.CandidateExercise(name: "Dumbbell Fly", muscleGroup: "Chest", equipment: "Dumbbell", isCompound: false, level: "beginner"),
        R.CandidateExercise(name: "Squat", muscleGroup: "Legs", equipment: "Barbell", isCompound: true, level: "beginner"),
        R.CandidateExercise(name: "Leg Press", muscleGroup: "Legs", equipment: "Machine", isCompound: true, level: "beginner"),
        R.CandidateExercise(name: "Barbell Row", muscleGroup: "Back", equipment: "Barbell", isCompound: true, level: "beginner"),
        R.CandidateExercise(name: "Lat Pulldown", muscleGroup: "Back", equipment: "Machine", isCompound: true, level: "beginner"),
    ]

    // MARK: Recovery

    func test_fatigue_halvesEvery36Hours() {
        let fatigue = WorkoutRecommendationEngine.muscleFatigue(history: [workout("A", 1.5, [("Squat", "Legs", [(100, 5), (100, 5), (100, 5), (100, 5)])])], now: now)
        XCTAssertEqual(fatigue["Legs"] ?? 0, 2, accuracy: 0.01)   // 4 sets × 0.5
        XCTAssertEqual(fatigue["Glutes"] ?? 0, 1, accuracy: 0.01) // secondary at half
    }

    func test_doesNotSuggestMusclesTrainedToday() {
        let rec = WorkoutRecommendationEngine.recommend(history: [push], routines: routines, candidates: candidates, now: now)
        XCTAssertNotEqual(rec.routineName, "Push Day")
        XCTAssertFalse(rec.muscleGroups.contains("Chest"))
    }

    func test_prefersLongestRestedRoutine() {
        let history = [
            workout("Pull Day", 1, [("Barbell Row", "Back", [(60, 8), (60, 8), (60, 8)])]),
            workout("Push Day", 3, [("Bench Press", "Chest", [(80, 6), (80, 6), (80, 6)])]),
            workout("Leg Day", 6, [("Squat", "Legs", [(100, 6), (100, 6), (100, 6)])]),
        ]
        let rec = WorkoutRecommendationEngine.recommend(history: history, routines: routines, candidates: candidates, now: now)
        XCTAssertEqual(rec.routineName, "Leg Day")
    }

    func test_buildsWorkoutWhenNoRoutines() {
        let rec = WorkoutRecommendationEngine.recommend(history: [push], routines: [], candidates: candidates, now: now)
        XCTAssertNil(rec.routineName)
        XCTAssertFalse(rec.exercises.isEmpty)
        XCTAssertFalse(rec.exercises.contains { $0.muscleGroup == "Chest" })
    }

    func test_respectsEquipment() {
        var settings = R.Settings()
        settings.availableEquipment = ["Machine"]
        let rec = WorkoutRecommendationEngine.recommend(history: [push], routines: [], candidates: candidates, settings: settings, now: now)
        let allowed = Set(candidates.filter { $0.equipment == "Machine" }.map(\.name))
        XCTAssertTrue(rec.exercises.allSatisfy { allowed.contains($0.name) })
    }

    // MARK: Progressive overload

    func test_addsWeightWhenAllRepsHit() {
        let target = WorkoutRecommendationEngine.target(for: "Bench Press", muscleGroup: "Chest", isCompound: true,
                                                        defaultSets: 3, defaultReps: 6, routineWeight: 80,
                                                        history: [push], settings: .init())
        XCTAssertEqual(target.weight, 82.5)
        XCTAssertEqual(target.reps, 4)
    }

    func test_addsRepWhenRepsMissed() {
        let history = [workout("Push Day", 3, [("Bench Press", "Chest", [(80, 6), (80, 5), (80, 4)])])]
        let target = WorkoutRecommendationEngine.target(for: "Bench Press", muscleGroup: "Chest", isCompound: true,
                                                        defaultSets: 3, defaultReps: 6, routineWeight: 80,
                                                        history: history, settings: .init())
        XCTAssertEqual(target.weight, 80)
        XCTAssertEqual(target.reps, 5)
    }

    func test_newExerciseHasNoWeight() {
        let target = WorkoutRecommendationEngine.target(for: "Dumbbell Fly", muscleGroup: "Chest", isCompound: false,
                                                        defaultSets: 3, defaultReps: 10, routineWeight: nil,
                                                        history: [push], settings: .init())
        XCTAssertNil(target.weight)
        XCTAssertEqual(target.reps, 10)
    }

    func test_recoveryDayWhenEverythingIsTired() {
        let groups = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Legs", "Glutes", "Core"]
        let heavy = workout("Everything", 0, groups.map { ("\($0) work", $0, Array(repeating: (50.0, 10), count: 6)) })
        let rec = WorkoutRecommendationEngine.recommend(history: [heavy], routines: routines, candidates: candidates, now: now)
        XCTAssertEqual(rec.title, "Recovery Day")
        XCTAssertTrue(rec.exercises.isEmpty)
    }
}
