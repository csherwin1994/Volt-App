import SwiftData
import Foundation

@Model
final class Exercise {
    var id: UUID
    var name: String
    var muscleGroup: MuscleGroup
    var equipment: Equipment
    var instructions: String
    var isCustom: Bool

    // Details from the bundled exercise catalog (free-exercise-db). Defaults keep older stores migrating cleanly.
    /// The catalog entry this exercise came from, if any.
    var catalogID: String? = nil
    /// Detailed muscles, e.g. "quadriceps", "lats", "middle back".
    var primaryMuscles: [String] = []
    var secondaryMuscles: [String] = []
    /// "beginner", "intermediate" or "expert".
    var level: String = ""
    /// "compound" or "isolation".
    var mechanic: String = ""
    /// "push", "pull" or "static".
    var force: String = ""
    /// "strength", "stretching", "plyometrics", "powerlifting", "olympic weightlifting", "strongman" or "cardio".
    var category: String = "strength"
    var instructionSteps: [String] = []
    /// Photo paths relative to `ExerciseCatalog.imageBaseURL`.
    var imagePaths: [String] = []

    var isCompound: Bool { mechanic == "compound" }
    var isStretch: Bool { category == "stretching" }
    var imageURLs: [URL] {
        imagePaths.compactMap { path in
            path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                .flatMap { URL(string: $0, relativeTo: ExerciseCatalog.imageBaseURL) }
        }
    }

    init(
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        instructions: String = "",
        isCustom: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.instructions = instructions
        self.isCustom = isCustom
    }

    /// Per-exercise SF Symbol — specific first, equipment-based fallback for custom exercises.
    var icon: String {
        switch name {
        // Cardio
        case "Cycling", "Assault Bike":      return "figure.indoor.cycle"
        case "Rowing Machine", "Ski Erg",
             "Seated Cable Row",
             "Single Arm Cable Row":         return "figure.rowing"
        case "Treadmill", "Sprints":         return "figure.run"
        case "Elliptical":                   return "figure.cross.training"
        case "Stair Climber":                return "figure.walk"
        case "Swimming":                     return "figure.open.water.swim"
        case "Jump Rope":                    return "figure.jumprope"

        // Bodyweight movements with dedicated symbols
        case "Push Up", "Wide Push Up",
             "Decline Push Up",
             "Diamond Push Up",
             "Close Grip Push Up":           return "figure.push.ups"
        case "Pull Up", "Chin Up",
             "Neutral Grip Pull Up":         return "figure.strengthtraining.functional"
        case "Chest Dip", "Tricep Dip",
             "Bench Dip":                    return "figure.strengthtraining.functional"
        case "Lunge", "Walking Lunge",
             "Reverse Lunge":                return "figure.walk"
        case "Box Jump":                     return "figure.cross.training"
        case "Burpee", "Bear Crawl":         return "figure.cross.training"
        case "Pistol Squat", "Sissy Squat",
             "Wall Sit":                     return "figure.strengthtraining.functional"
        case "Handstand Push Up",
             "Pike Push Up":                 return "figure.strengthtraining.functional"
        case "Back Extension":               return "figure.strengthtraining.functional"
        case "Nordic Curl", "Glute-Ham Raise": return "figure.strengthtraining.functional"

        // Core — always specific
        case "Plank", "Side Plank",
             "Crunch", "Decline Crunch",
             "Oblique Crunch", "Sit Up",
             "V-Up", "Hollow Body Hold",
             "Dead Bug", "Bird Dog",
             "Ab Rollout", "Hanging Leg Raise",
             "Toes to Bar", "L-Sit",
             "Dragon Flag", "Russian Twist",
             "Bicycle Crunch", "Cable Crunch",
             "Cable Woodchop", "Pallof Press",
             "Landmine Rotation", "GHD Sit Up",
             "Medicine Ball Slam":           return "figure.core.training"

        // Full body / Olympic
        case "Power Clean", "Clean and Jerk",
             "Snatch", "Thruster",
             "Kettlebell Swing", "Kettlebell Clean",
             "Kettlebell Snatch",
             "Turkish Get-Up":               return "figure.strengthtraining.traditional"
        case "Farmer's Walk", "Man Maker":   return "dumbbell.fill"
        case "Battle Ropes":                 return "figure.cross.training"
        case "Sled Push", "Sled Pull",
             "Tire Flip":                    return "figure.strengthtraining.functional"

        // Cable movements
        case "Cable Fly", "Low Cable Fly",
             "High Cable Fly", "Face Pull",
             "Cable Reverse Fly",
             "Cable Lateral Raise",
             "Cable Front Raise",
             "Cable Curl", "Cable Hammer Curl",
             "Bayesian Curl",
             "Tricep Pushdown", "Rope Pushdown",
             "Reverse Grip Pushdown",
             "Cable Overhead Tricep Extension",
             "Cable Kickback",
             "Straight Arm Pulldown":        return "figure.arms.open"

        // Dumbbell exercises
        case "Dumbbell Bench Press",
             "Incline Dumbbell Press",
             "Decline Dumbbell Press",
             "Dumbbell Fly", "Incline Dumbbell Fly",
             "Dumbbell Curl", "Incline Dumbbell Curl",
             "Hammer Curl", "Zottman Curl",
             "Concentration Curl", "Spider Curl",
             "Dumbbell Shoulder Press",
             "Arnold Press", "Lateral Raise",
             "Front Raise",
             "Bent Over Lateral Raise",
             "Chest Supported Row", "Dumbbell Row",
             "Kroc Row", "Reverse Fly",
             "Overhead Tricep Extension",
             "Tate Press", "Kickback",
             "Bulgarian Split Squat",
             "Walking Lunge", "Reverse Lunge",
             "Step Up", "Single Leg RDL",
             "Dumbbell Hip Thrust":          return "dumbbell.fill"

        // Kettlebell exercises
        case "Goblet Squat",
             "Banded Squat":                 return "dumbbell.fill"

        // Machine exercises
        case "Pec Deck", "Smith Machine Bench Press",
             "Smith Machine Squat",
             "Hack Squat", "Leg Press",
             "Single Leg Press",
             "Leg Extension", "Leg Curl",
             "Seated Leg Curl",
             "Calf Raise", "Seated Calf Raise",
             "Donkey Calf Raise",
             "Lat Pulldown", "Close Grip Lat Pulldown",
             "Preacher Curl", "Machine Curl",
             "Machine Shoulder Press",
             "Rear Delt Fly",
             "Abductor Machine",
             "Adductor Machine",
             "GHD Sit Up":                  return "figure.strengthtraining.functional"

        // Barbell / compound lifts
        case "Bench Press", "Incline Bench Press",
             "Decline Bench Press",
             "Close Grip Bench Press",
             "Landmine Press", "Svend Press",
             "Overhead Press", "Push Press",
             "Bradford Press", "Upright Row",
             "Landmine Lateral Raise",
             "Plate Front Raise",
             "Barbell Row", "Pendlay Row",
             "T-Bar Row", "Meadows Row",
             "Good Morning", "Rack Pull",
             "Barbell Curl", "EZ Bar Curl",
             "Reverse Barbell Curl",
             "Reverse Curl",
             "Skull Crusher", "EZ Bar Skull Crusher",
             "JM Press",
             "Deadlift", "Sumo Deadlift",
             "Romanian Deadlift",
             "Stiff Leg Deadlift",
             "Squat", "Front Squat",
             "Pause Squat", "Box Squat",
             "Sumo Squat",
             "Hip Thrust",
             "Landmine Rotation":            return "figure.strengthtraining.traditional"

        default:
            // Custom / unknown — fall back to equipment, then muscle group
            return equipment.icon(for: muscleGroup)
        }
    }

    enum MuscleGroup: String, CaseIterable, Codable {
        case chest = "Chest"
        case back = "Back"
        case shoulders = "Shoulders"
        case biceps = "Biceps"
        case triceps = "Triceps"
        case legs = "Legs"
        case glutes = "Glutes"
        case core = "Core"
        case cardio = "Cardio"
        case fullBody = "Full Body"

        var icon: String {
            switch self {
            case .chest:     return "figure.strengthtraining.traditional"
            case .back:      return "figure.strengthtraining.functional"
            case .shoulders: return "figure.strengthtraining.traditional"
            case .biceps:    return "dumbbell.fill"
            case .triceps:   return "dumbbell.fill"
            case .legs:      return "figure.run"
            case .glutes:    return "figure.strengthtraining.functional"
            case .core:      return "figure.core.training"
            case .cardio:    return "heart.fill"
            case .fullBody:  return "figure.mixed.cardio"
            }
        }
    }

    enum Equipment: String, CaseIterable, Codable {
        case barbell = "Barbell"
        case dumbbell = "Dumbbell"
        case machine = "Machine"
        case cablePulley = "Cable/Pulley"
        case bodyweight = "Bodyweight"
        case kettlebell = "Kettlebell"
        case bands = "Bands"
        case other = "Other"

        func icon(for muscleGroup: MuscleGroup) -> String {
            switch self {
            case .barbell:     return "figure.strengthtraining.traditional"
            case .dumbbell, .kettlebell: return "dumbbell.fill"
            case .machine:     return "figure.strengthtraining.functional"
            case .cablePulley: return "figure.arms.open"
            case .bands:       return "figure.flexibility"
            case .bodyweight:
                switch muscleGroup {
                case .chest:                 return "figure.push.ups"
                case .core:                  return "figure.core.training"
                case .legs:                  return "figure.walk"
                case .cardio:                return "figure.run"
                case .fullBody:              return "figure.cross.training"
                default:                     return "figure.strengthtraining.functional"
                }
            case .other:       return muscleGroup.icon
            }
        }
    }
}
