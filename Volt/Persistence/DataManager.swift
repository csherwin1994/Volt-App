import SwiftData
import Foundation

/// Seeds the app with a default exercise library on first launch.
struct DataManager {
    static func seedExercisesIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let existingNames = Set(existing.filter { !$0.isCustom }.map(\.name))

        let exercises: [(String, Exercise.MuscleGroup, Exercise.Equipment)] = [
            // MARK: Chest
            ("Bench Press", .chest, .barbell),
            ("Incline Bench Press", .chest, .barbell),
            ("Decline Bench Press", .chest, .barbell),
            ("Close Grip Bench Press", .chest, .barbell),
            ("Smith Machine Bench Press", .chest, .machine),
            ("Dumbbell Bench Press", .chest, .dumbbell),
            ("Incline Dumbbell Press", .chest, .dumbbell),
            ("Decline Dumbbell Press", .chest, .dumbbell),
            ("Dumbbell Fly", .chest, .dumbbell),
            ("Incline Dumbbell Fly", .chest, .dumbbell),
            ("Cable Fly", .chest, .cablePulley),
            ("Low Cable Fly", .chest, .cablePulley),
            ("High Cable Fly", .chest, .cablePulley),
            ("Pec Deck", .chest, .machine),
            ("Push Up", .chest, .bodyweight),
            ("Wide Push Up", .chest, .bodyweight),
            ("Diamond Push Up", .chest, .bodyweight),
            ("Decline Push Up", .chest, .bodyweight),
            ("Chest Dip", .chest, .bodyweight),
            ("Svend Press", .chest, .other),
            ("Landmine Press", .chest, .barbell),

            // MARK: Back
            ("Deadlift", .back, .barbell),
            ("Rack Pull", .back, .barbell),
            ("Romanian Deadlift", .back, .barbell),
            ("Sumo Deadlift", .back, .barbell),
            ("Good Morning", .back, .barbell),
            ("Barbell Row", .back, .barbell),
            ("Pendlay Row", .back, .barbell),
            ("T-Bar Row", .back, .barbell),
            ("Chest Supported Row", .back, .dumbbell),
            ("Dumbbell Row", .back, .dumbbell),
            ("Kroc Row", .back, .dumbbell),
            ("Meadows Row", .back, .barbell),
            ("Pull Up", .back, .bodyweight),
            ("Chin Up", .back, .bodyweight),
            ("Neutral Grip Pull Up", .back, .bodyweight),
            ("Lat Pulldown", .back, .machine),
            ("Close Grip Lat Pulldown", .back, .machine),
            ("Seated Cable Row", .back, .cablePulley),
            ("Single Arm Cable Row", .back, .cablePulley),
            ("Straight Arm Pulldown", .back, .cablePulley),
            ("Face Pull", .back, .cablePulley),
            ("Reverse Fly", .back, .dumbbell),
            ("Cable Reverse Fly", .back, .cablePulley),
            ("Back Extension", .back, .bodyweight),
            ("Band Pull Apart", .back, .bands),

            // MARK: Shoulders
            ("Overhead Press", .shoulders, .barbell),
            ("Push Press", .shoulders, .barbell),
            ("Bradford Press", .shoulders, .barbell),
            ("Upright Row", .shoulders, .barbell),
            ("Dumbbell Shoulder Press", .shoulders, .dumbbell),
            ("Arnold Press", .shoulders, .dumbbell),
            ("Lateral Raise", .shoulders, .dumbbell),
            ("Front Raise", .shoulders, .dumbbell),
            ("Bent Over Lateral Raise", .shoulders, .dumbbell),
            ("Cable Lateral Raise", .shoulders, .cablePulley),
            ("Cable Front Raise", .shoulders, .cablePulley),
            ("Machine Shoulder Press", .shoulders, .machine),
            ("Rear Delt Fly", .shoulders, .machine),
            ("Plate Front Raise", .shoulders, .other),
            ("Landmine Lateral Raise", .shoulders, .barbell),
            ("Pike Push Up", .shoulders, .bodyweight),
            ("Handstand Push Up", .shoulders, .bodyweight),

            // MARK: Biceps
            ("Barbell Curl", .biceps, .barbell),
            ("EZ Bar Curl", .biceps, .barbell),
            ("Reverse Barbell Curl", .biceps, .barbell),
            ("Dumbbell Curl", .biceps, .dumbbell),
            ("Incline Dumbbell Curl", .biceps, .dumbbell),
            ("Hammer Curl", .biceps, .dumbbell),
            ("Zottman Curl", .biceps, .dumbbell),
            ("Concentration Curl", .biceps, .dumbbell),
            ("Spider Curl", .biceps, .dumbbell),
            ("Preacher Curl", .biceps, .machine),
            ("Machine Curl", .biceps, .machine),
            ("Cable Curl", .biceps, .cablePulley),
            ("Cable Hammer Curl", .biceps, .cablePulley),
            ("Bayesian Curl", .biceps, .cablePulley),
            ("Reverse Curl", .biceps, .barbell),
            ("Chin Up", .biceps, .bodyweight),

            // MARK: Triceps
            ("Skull Crusher", .triceps, .barbell),
            ("EZ Bar Skull Crusher", .triceps, .barbell),
            ("JM Press", .triceps, .barbell),
            ("Tricep Pushdown", .triceps, .cablePulley),
            ("Rope Pushdown", .triceps, .cablePulley),
            ("Reverse Grip Pushdown", .triceps, .cablePulley),
            ("Cable Overhead Tricep Extension", .triceps, .cablePulley),
            ("Overhead Tricep Extension", .triceps, .dumbbell),
            ("Tate Press", .triceps, .dumbbell),
            ("Kickback", .triceps, .dumbbell),
            ("Tricep Dip", .triceps, .bodyweight),
            ("Bench Dip", .triceps, .bodyweight),
            ("Diamond Push Up", .triceps, .bodyweight),
            ("Close Grip Push Up", .triceps, .bodyweight),

            // MARK: Legs
            ("Squat", .legs, .barbell),
            ("Front Squat", .legs, .barbell),
            ("Pause Squat", .legs, .barbell),
            ("Box Squat", .legs, .barbell),
            ("Hack Squat", .legs, .machine),
            ("Smith Machine Squat", .legs, .machine),
            ("Goblet Squat", .legs, .kettlebell),
            ("Sumo Squat", .legs, .barbell),
            ("Leg Press", .legs, .machine),
            ("Single Leg Press", .legs, .machine),
            ("Leg Extension", .legs, .machine),
            ("Leg Curl", .legs, .machine),
            ("Seated Leg Curl", .legs, .machine),
            ("Nordic Curl", .legs, .bodyweight),
            ("Calf Raise", .legs, .machine),
            ("Seated Calf Raise", .legs, .machine),
            ("Donkey Calf Raise", .legs, .machine),
            ("Lunge", .legs, .bodyweight),
            ("Walking Lunge", .legs, .dumbbell),
            ("Reverse Lunge", .legs, .dumbbell),
            ("Bulgarian Split Squat", .legs, .dumbbell),
            ("Step Up", .legs, .dumbbell),
            ("Box Jump", .legs, .bodyweight),
            ("Pistol Squat", .legs, .bodyweight),
            ("Sissy Squat", .legs, .bodyweight),
            ("Wall Sit", .legs, .bodyweight),
            ("Glute-Ham Raise", .legs, .bodyweight),
            ("Stiff Leg Deadlift", .legs, .barbell),
            ("Single Leg RDL", .legs, .dumbbell),

            // MARK: Glutes
            ("Hip Thrust", .glutes, .barbell),
            ("Dumbbell Hip Thrust", .glutes, .dumbbell),
            ("Glute Bridge", .glutes, .bodyweight),
            ("Single Leg Glute Bridge", .glutes, .bodyweight),
            ("Cable Kickback", .glutes, .cablePulley),
            ("Donkey Kick", .glutes, .bodyweight),
            ("Fire Hydrant", .glutes, .bodyweight),
            ("Abductor Machine", .glutes, .machine),
            ("Adductor Machine", .glutes, .machine),
            ("Banded Squat", .glutes, .bands),
            ("Banded Hip Thrust", .glutes, .bands),
            ("Sumo Deadlift", .glutes, .barbell),
            ("Romanian Deadlift", .glutes, .barbell),
            ("Step Up", .glutes, .dumbbell),

            // MARK: Core
            ("Plank", .core, .bodyweight),
            ("Side Plank", .core, .bodyweight),
            ("Crunch", .core, .bodyweight),
            ("Decline Crunch", .core, .bodyweight),
            ("Oblique Crunch", .core, .bodyweight),
            ("Sit Up", .core, .bodyweight),
            ("V-Up", .core, .bodyweight),
            ("Hollow Body Hold", .core, .bodyweight),
            ("Dead Bug", .core, .bodyweight),
            ("Bird Dog", .core, .bodyweight),
            ("Ab Rollout", .core, .other),
            ("Hanging Leg Raise", .core, .bodyweight),
            ("Toes to Bar", .core, .bodyweight),
            ("L-Sit", .core, .bodyweight),
            ("Dragon Flag", .core, .bodyweight),
            ("Russian Twist", .core, .bodyweight),
            ("Bicycle Crunch", .core, .bodyweight),
            ("Cable Crunch", .core, .cablePulley),
            ("Cable Woodchop", .core, .cablePulley),
            ("Pallof Press", .core, .cablePulley),
            ("Landmine Rotation", .core, .barbell),
            ("GHD Sit Up", .core, .machine),
            ("Medicine Ball Slam", .core, .other),

            // MARK: Full Body
            ("Power Clean", .fullBody, .barbell),
            ("Clean and Jerk", .fullBody, .barbell),
            ("Snatch", .fullBody, .barbell),
            ("Thruster", .fullBody, .barbell),
            ("Farmer's Walk", .fullBody, .dumbbell),
            ("Turkish Get-Up", .fullBody, .kettlebell),
            ("Kettlebell Swing", .fullBody, .kettlebell),
            ("Kettlebell Clean", .fullBody, .kettlebell),
            ("Kettlebell Snatch", .fullBody, .kettlebell),
            ("Battle Ropes", .fullBody, .other),
            ("Sled Push", .fullBody, .other),
            ("Sled Pull", .fullBody, .other),
            ("Tire Flip", .fullBody, .other),
            ("Burpee", .fullBody, .bodyweight),
            ("Bear Crawl", .fullBody, .bodyweight),
            ("Man Maker", .fullBody, .dumbbell),

            // MARK: Cardio
            ("Treadmill", .cardio, .machine),
            ("Cycling", .cardio, .machine),
            ("Elliptical", .cardio, .machine),
            ("Stair Climber", .cardio, .machine),
            ("Rowing Machine", .cardio, .machine),
            ("Assault Bike", .cardio, .machine),
            ("Jump Rope", .cardio, .other),
            ("Swimming", .cardio, .other),
            ("Sprints", .cardio, .bodyweight),
            ("Box Jump", .cardio, .bodyweight),
            ("Ski Erg", .cardio, .machine),
        ]

        for (name, muscle, equipment) in exercises where !existingNames.contains(name) {
            context.insert(Exercise(name: name, muscleGroup: muscle, equipment: equipment))
        }

        try? context.save()

        // Then the full catalog (~870 exercises with instructions and photos)
        importCatalogIfNeeded(context: context)
    }
}

// MARK: - Exercise catalog (free-exercise-db, public domain)

/// One entry of `Resources/exercises.json`, built by `tools/build_exercise_catalog.py`.
struct CatalogExercise: Decodable {
    let id: String
    let name: String
    let sourceName: String
    let group: String
    let equipmentType: String
    let equipment: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let level: String
    let mechanic: String
    let force: String
    let category: String
    let instructions: [String]
    let images: [String]
}

enum ExerciseCatalog {
    /// Bump when `exercises.json` changes so existing installs import the new entries.
    static let version = 1
    static let imageBaseURL = URL(string: "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/")!

    private struct File: Decodable { let exercises: [CatalogExercise] }
    private final class BundleToken {}

    /// The bundled catalog, or an empty list if the resource is missing.
    static func load(bundle: Bundle = Bundle(for: BundleToken.self)) -> [CatalogExercise] {
        guard let url = bundle.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else { return [] }
        return file.exercises
    }
}

extension DataManager {
    private static let catalogVersionKey = "exerciseCatalogVersion"

    /// Imports the bundled catalog once per catalog version. Called from `seedExercisesIfNeeded`.
    static func importCatalogIfNeeded(context: ModelContext, defaults: UserDefaults = .standard) {
        let imported = (try? context.fetchCount(FetchDescriptor<Exercise>(predicate: #Predicate<Exercise> { $0.catalogID != nil }))) ?? 0
        guard imported == 0 || defaults.integer(forKey: catalogVersionKey) < ExerciseCatalog.version else { return }
        importCatalog(ExerciseCatalog.load(), context: context)
        defaults.set(ExerciseCatalog.version, forKey: catalogVersionKey)
    }

    /// Adds catalog exercises to the library. A built-in exercise with the same name gains the
    /// catalog's details instead of being duplicated; a custom exercise with the same name is left alone.
    static func importCatalog(_ catalog: [CatalogExercise], context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var byName: [String: Exercise] = [:]
        for exercise in existing { byName[exercise.name.lowercased()] = byName[exercise.name.lowercased()] ?? exercise }
        let importedIDs = Set(existing.compactMap(\.catalogID))

        for item in catalog where !importedIDs.contains(item.id) {
            let key = item.name.lowercased()
            if let match = byName[key] {
                guard !match.isCustom else { continue }
                apply(item, to: match)
            } else {
                let exercise = Exercise(
                    name: item.name,
                    muscleGroup: Exercise.MuscleGroup(rawValue: item.group) ?? .fullBody,
                    equipment: Exercise.Equipment(rawValue: item.equipmentType) ?? .other,
                    instructions: item.instructions.joined(separator: "\n\n")
                )
                apply(item, to: exercise)
                context.insert(exercise)
                byName[key] = exercise
            }
        }
        try? context.save()
    }

    private static func apply(_ item: CatalogExercise, to exercise: Exercise) {
        exercise.catalogID = item.id
        exercise.primaryMuscles = item.primaryMuscles
        exercise.secondaryMuscles = item.secondaryMuscles
        exercise.level = item.level
        exercise.mechanic = item.mechanic
        exercise.force = item.force
        exercise.category = item.category
        exercise.instructionSteps = item.instructions
        exercise.imagePaths = item.images
        if exercise.instructions.isEmpty {
            exercise.instructions = item.instructions.joined(separator: "\n\n")
        }
    }
}
