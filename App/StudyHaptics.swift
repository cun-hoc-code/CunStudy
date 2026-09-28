@MainActor
enum StudyHaptics {
  static func flip(enabled: Bool) {
    InteractionFeedback.shared.play(.page)
  }
  static func selection(enabled: Bool) {
    InteractionFeedback.shared.play(.selection)
  }
  static func success(enabled: Bool) {
    InteractionFeedback.shared.play(.success)
  }
}
