import XCTest
import SwiftData
@testable import Volt

final class DataManagerTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: WorkoutSession.self, Exercise.self, Routine.self,
            configurations: config
        )
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - seedExercisesIfNeeded

    func test_seed_insertsExercisesOnFirstLaunch() throws {
        DataManager.seedExercisesIfNeeded(context: context)
        let descriptor = FetchDescriptor<Exercise>()
        let count = try context.fetchCount(descriptor)
        XCTAssertGreaterThan(count, 0)
    }

    func test_seed_insertsAtLeast50Exercises() throws {
        DataManager.seedExercisesIfNeeded(context: context)
        let descriptor = FetchDescriptor<Exercise>()
        let count = try context.fetchCount(descriptor)
        XCTAssertGreaterThanOrEqual(count, 50)
    }

    func test_seed_doesNotDuplicateOnSecondCall() throws {
        DataManager.seedExercisesIfNeeded(context: context)
        DataManager.seedExercisesIfNeeded(context: context)
        let descriptor = FetchDescriptor<Exercise>()
        let countAfterTwoCalls = try context.fetchCount(descriptor)
        // Should be same count — second call is a no-op
        DataManager.seedExercisesIfNeeded(context: context)
        let countAfterThreeCalls = try context.fetchCount(descriptor)
        XCTAssertEqual(countAfterTwoCalls, countAfterThreeCalls)
    }

    func test_seed_allMuscleGroupsPresent() throws {
        DataManager.seedExercisesIfNeeded(context: context)
        let descriptor = FetchDescriptor<Exercise>()
        let exercises = try context.fetch(descriptor)
        let muscleGroups = Set(exercises.map(\.muscleGroup))
        for group in Exercise.MuscleGroup.allCases {
            XCTAssertTrue(muscleGroups.contains(group), "Missing muscle group: \(group.rawValue)")
        }
    }

    func test_seed_exercisesHaveNames() throws {
        DataManager.seedExercisesIfNeeded(context: context)
        let descriptor = FetchDescriptor<Exercise>()
        let exercises = try context.fetch(descriptor)
        for exercise in exercises {
            XCTAssertFalse(exercise.name.isEmpty, "Exercise has empty name")
        }
    }

    func test_seed_exercisesAreNotCustom() throws {
        DataManager.seedExercisesIfNeeded(context: context)
        let descriptor = FetchDescriptor<Exercise>()
        let exercises = try context.fetch(descriptor)
        for exercise in exercises {
            XCTAssertFalse(exercise.isCustom, "\(exercise.name) should not be marked as custom")
        }
    }

    // MARK: - Exercise catalog

    func test_catalog_loadsBundledExercises() {
        XCTAssertGreaterThan(ExerciseCatalog.load().count, 800)
    }

    func test_catalog_importEnrichesBuiltInInsteadOfDuplicating() throws {
        DataManager.seedExercisesIfNeeded(context: context)
        DataManager.importCatalog(ExerciseCatalog.load(), context: context)
        let bench = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate<Exercise> { $0.name == "Bench Press" }))
        XCTAssertEqual(bench.count, 1)
        XCTAssertNotNil(bench.first?.catalogID)
        XCTAssertFalse(bench.first?.instructionSteps.isEmpty ?? true)
    }

    func test_catalog_importIsIdempotent() throws {
        let catalog = ExerciseCatalog.load()
        DataManager.importCatalog(catalog, context: context)
        let first = try context.fetchCount(FetchDescriptor<Exercise>())
        DataManager.importCatalog(catalog, context: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), first)
    }

    func test_catalog_doesNotOverwriteCustomExercise() throws {
        let custom = Exercise(name: "Plank", muscleGroup: .core, equipment: .bodyweight, instructions: "My way", isCustom: true)
        context.insert(custom)
        DataManager.importCatalog(ExerciseCatalog.load(), context: context)
        XCTAssertNil(custom.catalogID)
        XCTAssertEqual(custom.instructions, "My way")
    }
}
