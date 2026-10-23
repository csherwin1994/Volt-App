import ActivityKit
import Foundation

/// Shared between the app and the VoltRestTimerWidget extension.
/// In Xcode, this file must be a member of BOTH targets (File inspector → Target Membership).
struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the rest period ends. The widget counts down to this with a system timer, so no updates are needed each second.
        var endDate: Date
        /// The exercise the user just finished a set of, e.g. "Bench Press".
        var exerciseName: String?
    }

    /// Workout name shown on the Lock Screen, e.g. "Push Day".
    var workoutTitle: String
}
