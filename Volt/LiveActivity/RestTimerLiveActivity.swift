import ActivityKit
import Foundation

/// Starts, updates and ends the rest timer Live Activity (Lock Screen + Dynamic Island).
/// Every call is safe to make when Live Activities are off or unsupported: it simply does nothing.
enum RestTimerLiveActivity {
    private static var current: Activity<RestTimerAttributes>? {
        Activity<RestTimerAttributes>.activities.first
    }

    static func start(workoutTitle: String, exerciseName: String?, endDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = RestTimerAttributes.ContentState(endDate: endDate, exerciseName: exerciseName)
        let content = ActivityContent(state: state, staleDate: endDate)

        if let activity = current {
            Task { await activity.update(content) }
            return
        }
        do {
            _ = try Activity.request(
                attributes: RestTimerAttributes(workoutTitle: workoutTitle),
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activities can be refused (e.g. too many running). The in-app timer still works.
        }
    }

    static func update(endDate: Date) {
        guard let activity = current else { return }
        let state = RestTimerAttributes.ContentState(endDate: endDate, exerciseName: activity.content.state.exerciseName)
        Task { await activity.update(ActivityContent(state: state, staleDate: endDate)) }
    }

    static func end() {
        let activities = Activity<RestTimerAttributes>.activities
        guard !activities.isEmpty else { return }
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
