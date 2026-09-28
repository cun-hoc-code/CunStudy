import ActivityKit
import Combine
import UIKit

/// ActivityKit owns the visible countdown. Never run a one-second background task.
@MainActor
final class FocusActivityService: ObservableObject {
  @Published private(set) var message = "Bắt đầu một phiên để hiện Mầm trên màn hình khóa."
  private var pending: StudyState?
  private var syncing = false
  private var attemptedIDs: Set<UUID> = []
  private var lastEnabled: Bool?

  func reconcile(_ state: StudyState) {
    pending = state
    guard !syncing else { return }
    syncing = true
    Task {
      // Serialize lifecycle changes: a pause/end cannot race a previous update.
      while let next = pending {
        pending = nil
        await sync(next)
      }
      syncing = false
    }
  }

  private func sync(_ state: StudyState) async {
    let enabled = WidgetStorage.isEnabled && state.preferences.liveActivities
    if lastEnabled == false && enabled, let id = state.activeFocus?.id { attemptedIDs.remove(id) }
    lastEnabled = enabled
    let active = enabled ? state.activeFocus : nil
    let activities = Activity<FocusActivityAttributes>.activities
    for activity in activities where activity.attributes.sessionID != active?.id {
      var final = activity.content.state
      let completed =
        state.sessions.first { $0.id == activity.attributes.sessionID }?.completed == true
      final.isComplete = completed
      final.isPaused = false
      if completed {
        final.progress = 1
        final.remainingSeconds = 0
      }
      await activity.end(
        ActivityContent(state: final, staleDate: nil),
        dismissalPolicy: completed && enabled ? .after(Date().addingTimeInterval(120)) : .immediate)
    }
    guard WidgetStorage.isEnabled else {
      message = "Live Activity cần bản Mầm đầy đủ."
      return
    }
    guard enabled else {
      message = "Bạn đã tắt hiển thị trên màn hình khóa."
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      message = "Bật Hoạt động trực tiếp trong Cài đặt iPhone → Mầm."
      return
    }
    guard let active else {
      message = "Sẵn sàng cho phiên tập trung tiếp theo."
      return
    }
    let now = Date()
    let content = ActivityContent(
      state: FocusActivityAttributes.ContentState(focus: active, at: now),
      staleDate: active.endDate)
    if let existing = Activity<FocusActivityAttributes>.activities.first(where: {
      $0.attributes.sessionID == active.id
        && ($0.activityState == .active || $0.activityState == .stale)
    }) {
      attemptedIDs.insert(active.id)
      if existing.content.state != content.state { await existing.update(content) }
      message =
        active.isPaused
        ? "Mầm trên màn hình khóa đang tạm dừng."
        : "Mầm và thời gian còn lại đang hiện trên màn hình khóa."
      return
    }
    // Respect dismissal during this app run; do not recreate on every flashcard edit.
    guard !attemptedIDs.contains(active.id) else {
      message = "Live Activity của phiên này đã được đóng. Phiên học vẫn tiếp tục."
      return
    }
    guard UIApplication.shared.applicationState == .active else {
      message = "Mở Mầm để hiển thị phiên học trên màn hình khóa."
      return
    }
    guard content.state.remainingSeconds > 0 else { return }
    do {
      _ = try Activity.request(
        attributes: FocusActivityAttributes(
          sessionID: active.id,
          subject: String(active.subject.prefix(100)),
          plannedMinutes: Int(active.plannedSeconds / 60)),
        content: content, pushType: nil)
      attemptedIDs.insert(active.id)
      message = "Mầm và thời gian còn lại đang hiện trên màn hình khóa."
    } catch {
      message = "Chưa hiện được Live Activity: \(error.localizedDescription)"
    }
  }
}
