import ActivityKit
import Foundation

struct FocusActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var timerStart: Date
    var timerEnd: Date
    var remainingSeconds: Int
    var progress: Double
    var isPaused: Bool
    var isComplete: Bool

    init(focus: ActiveFocus, at now: Date) {
      let elapsed = focus.elapsed(at: now)
      timerStart = now.addingTimeInterval(-elapsed)
      timerEnd = timerStart.addingTimeInterval(focus.plannedSeconds)
      remainingSeconds = max(0, Int(ceil(focus.plannedSeconds - elapsed)))
      progress = elapsed / max(1, focus.plannedSeconds)
      isPaused = focus.isPaused
      isComplete = remainingSeconds == 0
    }
  }
  var sessionID: UUID
  var subject: String
  var plannedMinutes: Int
}
