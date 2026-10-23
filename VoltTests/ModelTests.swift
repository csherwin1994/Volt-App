import XCTest
@testable import Volt

final class ModelTests: XCTestCase {

    // MARK: - WorkoutSet

    func test_workoutSet_defaultsNotCompleted() {
        let set = WorkoutSet(orderIndex: 0)
        XCTAssertFalse(set.isCompleted)
        XCTAssertNil(set.completedAt)
    }

    func test_workoutSet_defaultsNormalType() {
        let set = WorkoutSet(orderIndex: 0)
        XCTAssertEqual(set.setType, .normal)
    }

    func test_workoutSet_defaultWeightAndRepsZero() {
        let set = WorkoutSet(orderIndex: 0)
        XCTAssertEqual(set.weight, 0)
        XCTAssertEqual(set.reps, 0)
    }

    func test_workoutSet_setTypeColors() {
        XCTAssertEqual(WorkoutSet.SetType.warmup.color, "yellow")
        XCTAssertEqual(WorkoutSet.SetType.normal.color, "blue")
        XCTAssertEqual(WorkoutSet.SetType.dropSet.color, "purple")
        XCTAssertEqual(WorkoutSet.SetType.failureSet.color, "red")
    }

    // MARK: - ExerciseLog

    func test_exerciseLog_completedSets_onlyReturnsCompleted() {
        let log = ExerciseLog(exerciseName: "Bench Press", exerciseMuscleGroup: "Chest")
        let set1 = WorkoutSet(orderIndex: 0, weight: 60, reps: 8)
        set1.isCompleted = true
        let set2 = WorkoutSet(orderIndex: 1, weight: 60, reps: 8)
        set2.isCompleted = false
        log.sets.append(contentsOf: [set1, set2])
        XCTAssertEqual(log.completedSets.count, 1)
        XCTAssertEqual(log.completedSets.first?.orderIndex, 0)
    }

    func test_exerciseLog_completedSets_sortedByOrderIndex() {
        let log = ExerciseLog(exerciseName: "Squat", exerciseMuscleGroup: "Legs")
        let set1 = WorkoutSet(orderIndex: 2, weight: 100, reps: 5)
        set1.isCompleted = true
        let set2 = WorkoutSet(orderIndex: 0, weight: 80, reps: 8)
        set2.isCompleted = true
        let set3 = WorkoutSet(orderIndex: 1, weight: 90, reps: 6)
        set3.isCompleted = true
        log.sets.append(contentsOf: [set1, set2, set3])
        let completed = log.completedSets
        XCTAssertEqual(completed[0].orderIndex, 0)
        XCTAssertEqual(completed[1].orderIndex, 1)
        XCTAssertEqual(completed[2].orderIndex, 2)
    }

    // MARK: - Exercise

    func test_exercise_muscleGroupIcons_allCasesCovered() {
        for group in Exercise.MuscleGroup.allCases {
            let icon = group.icon
            XCTAssertFalse(icon.isEmpty, "No icon for \(group.rawValue)")
        }
    }

    func test_exercise_defaultNotCustom() {
        let ex = Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell)
        XCTAssertFalse(ex.isCustom)
    }

    func test_exercise_customFlag() {
        let ex = Exercise(name: "My Move", muscleGroup: .core, equipment: .bodyweight, isCustom: true)
        XCTAssertTrue(ex.isCustom)
    }

    func test_exercise_muscleGroupRawValues() {
        XCTAssertEqual(Exercise.MuscleGroup.chest.rawValue, "Chest")
        XCTAssertEqual(Exercise.MuscleGroup.back.rawValue, "Back")
        XCTAssertEqual(Exercise.MuscleGroup.shoulders.rawValue, "Shoulders")
        XCTAssertEqual(Exercise.MuscleGroup.biceps.rawValue, "Biceps")
        XCTAssertEqual(Exercise.MuscleGroup.triceps.rawValue, "Triceps")
        XCTAssertEqual(Exercise.MuscleGroup.legs.rawValue, "Legs")
        XCTAssertEqual(Exercise.MuscleGroup.glutes.rawValue, "Glutes")
        XCTAssertEqual(Exercise.MuscleGroup.core.rawValue, "Core")
        XCTAssertEqual(Exercise.MuscleGroup.cardio.rawValue, "Cardio")
        XCTAssertEqual(Exercise.MuscleGroup.fullBody.rawValue, "Full Body")
    }

    func test_exercise_equipmentRawValues() {
        XCTAssertEqual(Exercise.Equipment.barbell.rawValue, "Barbell")
        XCTAssertEqual(Exercise.Equipment.dumbbell.rawValue, "Dumbbell")
        XCTAssertEqual(Exercise.Equipment.machine.rawValue, "Machine")
        XCTAssertEqual(Exercise.Equipment.bodyweight.rawValue, "Bodyweight")
        XCTAssertEqual(Exercise.Equipment.kettlebell.rawValue, "Kettlebell")
        XCTAssertEqual(Exercise.Equipment.bands.rawValue, "Bands")
    }

    // MARK: - Routine

    func test_routine_exerciseCount() {
        let routine = Routine(name: "Push Day")
        XCTAssertEqual(routine.exerciseCount, 0)
        routine.exercises.append(RoutineExercise(exerciseName: "Bench Press", exerciseMuscleGroup: "Chest"))
        routine.exercises.append(RoutineExercise(exerciseName: "Overhead Press", exerciseMuscleGroup: "Shoulders"))
        XCTAssertEqual(routine.exerciseCount, 2)
    }

    func test_routine_defaultValues() {
        let routine = Routine(name: "Legs")
        XCTAssertEqual(routine.notes, "")
        XCTAssertNil(routine.lastUsedAt)
        XCTAssertTrue(routine.exercises.isEmpty)
    }

    func test_routineExercise_defaultTargets() {
        let re = RoutineExercise(exerciseName: "Squat", exerciseMuscleGroup: "Legs")
        XCTAssertEqual(re.targetSets, 3)
        XCTAssertEqual(re.targetReps, 10)
        XCTAssertEqual(re.targetWeight, 0)
    }

    // MARK: - Personal records

    private func completedSet(_ weight: Double, _ reps: Int) -> WorkoutSet {
        let set = WorkoutSet(orderIndex: 0, weight: weight, reps: reps)
        set.isCompleted = true
        return set
    }

    func test_oneRepMax_singleRepIsTheWeight() {
        XCTAssertEqual(PersonalRecords.estimatedOneRepMax(weight: 100, reps: 1), 100)
    }

    func test_oneRepMax_epley() {
        // 100 × (1 + 10/30) = 133.33
        XCTAssertEqual(PersonalRecords.estimatedOneRepMax(weight: 100, reps: 10), 133.33, accuracy: 0.01)
    }

    func test_record_heavierSetIsWeightPR() {
        let best = PersonalRecords.best(in: [completedSet(80, 8), completedSet(85, 5)])
        XCTAssertEqual(PersonalRecords.record(for: completedSet(87.5, 3), comparedTo: best)?.kind, .weight)
    }

    func test_record_moreRepsAtSameWeightIsOneRepMaxPR() {
        let best = PersonalRecords.best(in: [completedSet(85, 5)])
        XCTAssertEqual(PersonalRecords.record(for: completedSet(85, 7), comparedTo: best)?.kind, .oneRepMax)
    }

    func test_record_weakerSetIsNotPR() {
        let best = PersonalRecords.best(in: [completedSet(85, 5)])
        XCTAssertNil(PersonalRecords.record(for: completedSet(80, 5), comparedTo: best))
    }

    func test_record_firstTimeLoggedIsNotPR() {
        let best = PersonalRecords.best(in: [])
        XCTAssertNil(PersonalRecords.record(for: completedSet(60, 8), comparedTo: best))
    }
}
