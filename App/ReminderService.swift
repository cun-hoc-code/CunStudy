import AlarmKit
import Combine
import Foundation
import SwiftUI
import UIKit
import UserNotifications

@available(iOS 26.0, *)
struct StudyAlarmMetadata: AlarmMetadata { var lessonID: String }

@MainActor
final class ReminderService: ObservableObject {
  @Published var status = "Chưa có lịch nhắc"
  @Published var problems: [String] = []
  @Published var alarmPermission = "Chưa kiểm tra"
  @Published var notificationPermission = "Chưa kiểm tra"
  private var latest: StudyState?
  private var running = false
  private var confirmedAlarms: [UUID: Lesson] = [:]
  // Stable across app restarts; reconciliation must not cancel a pending test.
  private let testAlarmID = UUID(uuidString: "98201801-7B39-4A1C-8658-731AC8BB774C")!
  private let center = UNUserNotificationCenter.current()

  func requestNotifications() async {
    do { _ = try await center.requestAuthorization(options: [.alert, .sound, .badge]) } catch {
      problems = [error.localizedDescription]
    }
    await updatePermissionLabels()
  }
  func requestAlarms() async {
    if #available(iOS 26.0, *) {
      do { _ = try await AlarmManager.shared.requestAuthorization() } catch {
        problems = ["Không cấp được quyền báo thức: \(error.localizedDescription)"]
      }
    } else {
      problems = ["Báo thức hệ thống cần iOS 26 trở lên. Bạn vẫn có thể chọn Thông báo."]
    }
    await updatePermissionLabels()
  }
  func updatePermissionLabels() async {
    let settings = await center.notificationSettings()
    if settings.authorizationStatus == .authorized {
      notificationPermission =
        settings.soundSetting == .enabled
        ? "Đã cho phép âm thanh" : "Đã cho phép, âm thanh đang tắt"
    } else if settings.authorizationStatus == .provisional {
      notificationPermission = "Đang gửi yên lặng"
    } else {
      notificationPermission = "Chưa cho phép"
    }
    if #available(iOS 26.0, *) {
      alarmPermission =
        AlarmManager.shared.authorizationState == .authorized ? "Đã cho phép" : "Chưa cho phép"
    } else {
      alarmPermission = "Cần iOS 26 trở lên"
    }
  }

  /// Coalesces changes and processes them serially, so an older asynchronous
  /// save can never leave stale reminders after a newer edit/delete.
  func reconcile(_ state: StudyState) {
    latest = state
    guard !running else { return }
    running = true
    Task {
      var backgroundID = UIBackgroundTaskIdentifier.invalid
      backgroundID = UIApplication.shared.beginBackgroundTask(withName: "Save study reminders") {
        if backgroundID != .invalid {
          UIApplication.shared.endBackgroundTask(backgroundID)
          backgroundID = .invalid
        }
      }
      defer {
        if backgroundID != .invalid { UIApplication.shared.endBackgroundTask(backgroundID) }
      }
      while let next = latest {
        latest = nil
        await sync(next)
      }
      running = false
    }
  }
  private func sync(_ state: StudyState) async {
    var issues: [String] = []
    var alarmCount = 0
    await updatePermissionLabels()
    let now = Date()
    let settings = await center.notificationSettings()
    let canNotify =
      settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    var requests: [UNNotificationRequest] = []
    for lesson in state.lessons where lesson.enabled && lesson.reminder == .notification {
      let content = UNMutableNotificationContent()
      content.title =
        lesson.area == .school ? "Đến giờ chuẩn bị đi học" : "Đến giờ dành cho việc học"
      content.body = "\(lesson.title) • \(lesson.location)"
      content.sound = .default
      if lesson.weekly {
        for weekday in Set(lesson.weekdays) {
          let shifted = ScheduleEngine.shifted(
            weekday: weekday, minute: lesson.startMinute, lead: lesson.leadMinutes)
          var dc = DateComponents()
          dc.weekday = shifted.weekday
          dc.hour = shifted.minute / 60
          dc.minute = shifted.minute % 60
          let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
          requests.append(
            .init(
              identifier: "mam-lesson-\(lesson.id)-\(weekday)", content: content, trigger: trigger))
        }
      } else if let date = ScheduleEngine.oneOffFire(lesson), date > now {
        requests.append(request(id: "mam-lesson-\(lesson.id)", content: content, date: date))
      }
    }
    for item in state.tasks where item.remind && !item.done {
      guard let due = item.due, due > now else { continue }
      let fire = due.addingTimeInterval(-Double(item.reminderLeadMinutes ?? 0) * 60)
      guard fire > now else { continue }
      let content = UNMutableNotificationContent()
      content.title = "Đến hạn: \(item.title)"
      content.body = item.subject
      content.sound = .default
      requests.append(request(id: "mam-task-\(item.id)", content: content, date: fire))
    }
    if let focus = state.activeFocus, let end = focus.endDate, end > now {
      let content = UNMutableNotificationContent()
      content.title = "Mầm của bạn đã lớn 🌱"
      content.body = "Hoàn thành phiên \(focus.subject). Nghỉ một chút nhé."
      content.sound = .default
      requests.append(request(id: "mam-focus", content: content, date: end))
    }
    // A separate, short break notification is owned by the Focus screen.
    for block in state.studio.blocks where !block.completed {
      if let lead = block.reminderMinutes {
        let date = block.start.addingTimeInterval(-Double(lead * 60))
        if date > now {
          let c = UNMutableNotificationContent()
          c.title = "Đến giờ nuôi mầm"
          c.body = block.title
          c.sound = .default
          requests.append(request(id: "mam-block-\(block.id)", content: c, date: date))
        }
      }
    }
    if state.studio.settings.streakReminder {
      let calendar = ScheduleEngine.calendar()
      let progress = StudyProgress.summary(state, at: now)
      for offset in 0..<7 {
        if offset == 0 && progress.today.qualifies { continue }
        if let day = calendar.date(byAdding: .day, value: offset, to: now),
          let time = calendar.date(
            bySettingHour: state.studio.settings.streakHour, minute: 0, second: 0, of: day),
          time > now
        {
          let c = UNMutableNotificationContent()
          c.title = "Một chút thời gian cho mình 🌱"
          c.body = "Ôn vài thẻ hoặc học 5 phút. Nghỉ ngơi cũng là một phần của việc học."
          c.sound = .default
          requests.append(request(id: "mam-streak-\(offset)", content: c, date: time))
        }
      }
    }
    let old = await center.pendingNotificationRequests()
    center.removePendingNotificationRequests(
      withIdentifiers: old.filter {
        $0.identifier.hasPrefix("mam-") && $0.identifier != "mam-break"
      }.map(\.identifier))
    if !requests.isEmpty && !canNotify {
      issues.append("Thông báo chưa được cấp quyền. Vào Cài đặt trong app để bật.")
    }
    if !requests.isEmpty && canNotify && settings.soundSetting != .enabled {
      issues.append("Âm thanh thông báo đang tắt. Kiểm tra Cài đặt iPhone nếu muốn nghe nhắc học.")
    }
    let ordered = requests.sorted {
      (($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture)
        < (($1.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture)
    }
    // Stay below iOS's pending-request limit and reserve room for break reminders.
    if ordered.count > 60 {
      issues.append(
        "Chỉ xếp được 60 thông báo gần nhất. Mở app thường xuyên để bổ sung các nhắc việc còn lại.")
    }
    var notificationCount = 0
    if canNotify {
      for item in ordered.prefix(60) {
        do {
          try await center.add(item)
          notificationCount += 1
        } catch { issues.append("Chưa xếp được thông báo: \(error.localizedDescription)") }
      }
    }
    let alarms = state.lessons.filter {
      $0.enabled && $0.reminder == .alarm
        && ($0.weekly || (ScheduleEngine.oneOffFire($0) ?? .distantPast) > now)
    }
    if #available(iOS 26.0, *), AlarmManager.shared.authorizationState == .authorized {
      do {
        let existing = try AlarmManager.shared.alarms
        let desired = Set(alarms.map(\.id))
        for alarm in existing where !desired.contains(alarm.id) && alarm.id != testAlarmID {
          try AlarmManager.shared.cancel(id: alarm.id)
          confirmedAlarms.removeValue(forKey: alarm.id)
        }
        let ids = Set(existing.map(\.id))
        for lesson in alarms {
          if confirmedAlarms[lesson.id] == lesson && ids.contains(lesson.id) {
            alarmCount += 1
            continue
          }
          do {
            if ids.contains(lesson.id) { try AlarmManager.shared.cancel(id: lesson.id) }
            try await scheduleAlarm(lesson)
            confirmedAlarms[lesson.id] = lesson
            alarmCount += 1
          } catch {
            issues.append("\(lesson.title): chưa đặt được báo thức. \(error.localizedDescription)")
          }
        }
      } catch { issues.append("Không đọc được danh sách báo thức: \(error.localizedDescription)") }
    } else if !alarms.isEmpty {
      if #available(iOS 26.0, *) {
        issues.append("Báo thức chưa được cấp quyền. Các lịch chọn Báo thức hiện chưa được đặt.")
      } else {
        issues.append("Báo thức hệ thống cần iOS 26+. Chọn Thông báo nếu bạn dùng iOS cũ hơn.")
      }
    }
    problems = Array(Set(issues)).sorted()
    status = "\(alarmCount) báo thức • \(notificationCount) thông báo đã đặt"
  }

  private func request(id: String, content: UNMutableNotificationContent, date: Date)
    -> UNNotificationRequest
  {
    var components = ScheduleEngine.calendar().dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: date)
    components.calendar = ScheduleEngine.calendar()
    components.timeZone = .current
    return .init(
      identifier: id, content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
  }

  @available(iOS 26.0, *)
  private func scheduleAlarm(_ lesson: Lesson) async throws {
    let schedule: Alarm.Schedule
    if lesson.weekly {
      let shift = ScheduleEngine.shifted(
        weekday: 1, minute: lesson.startMinute, lead: lesson.leadMinutes)
      let weekdays: [Locale.Weekday] = lesson.weekdays.map {
        let value = ScheduleEngine.shifted(
          weekday: $0, minute: lesson.startMinute, lead: lesson.leadMinutes
        ).weekday
        return [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday][value - 1]
      }
      schedule = .relative(
        .init(
          time: .init(hour: shift.minute / 60, minute: shift.minute % 60),
          repeats: .weekly(weekdays)))
    } else {
      guard let date = ScheduleEngine.oneOffFire(lesson), date > Date() else {
        throw StudyError.invalid("Giờ báo thức đã qua.")
      }
      schedule = .fixed(date)
    }
    let title = lesson.area == .school ? "Đi học: \(lesson.title)" : "Giờ học: \(lesson.title)"
    let alert = AlarmPresentation.Alert(
      title: LocalizedStringResource(stringLiteral: title),
      stopButton: AlarmButton(text: "Đã biết", textColor: .white, systemImageName: "checkmark"))
    let attributes = AlarmAttributes<StudyAlarmMetadata>(
      presentation: AlarmPresentation(alert: alert),
      metadata: StudyAlarmMetadata(lessonID: lesson.id.uuidString), tintColor: Color.green)
    let config = AlarmManager.AlarmConfiguration<StudyAlarmMetadata>.alarm(
      schedule: schedule, attributes: attributes)
    _ = try await AlarmManager.shared.schedule(id: lesson.id, configuration: config)
  }

  func testAlarm() async {
    await requestAlarms()
    if #available(iOS 26.0, *) {
      guard AlarmManager.shared.authorizationState == .authorized else { return }
      do {
        let alert = AlarmPresentation.Alert(
          title: "Báo thức thử của Mầm",
          stopButton: .init(text: "Tắt", textColor: .white, systemImageName: "checkmark"))
        let attributes = AlarmAttributes<StudyAlarmMetadata>(
          presentation: .init(alert: alert), tintColor: .green)
        let config = AlarmManager.AlarmConfiguration<StudyAlarmMetadata>.alarm(
          schedule: .fixed(Date().addingTimeInterval(30)), attributes: attributes)
        try? AlarmManager.shared.cancel(id: testAlarmID)
        _ = try await AlarmManager.shared.schedule(id: testAlarmID, configuration: config)
        status = "Đã đặt báo thức thử sau 30 giây. Hãy khóa màn hình để kiểm tra."
      } catch { problems = ["Không đặt được báo thức thử: \(error.localizedDescription)"] }
    }
  }
  func startBreak(minutes: Int) async -> Bool {
    let settings = await center.notificationSettings()
    guard
      settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    else {
      problems = ["Hãy cấp quyền thông báo trong Cài đặt của Mầm trước khi đặt giờ nghỉ."]
      return false
    }
    let content = UNMutableNotificationContent()
    content.title = "Hết giờ nghỉ"
    content.body = "Bạn sẵn sàng cho một mầm mới chưa?"
    content.sound = .default
    do {
      try await center.add(
        request(
          id: "mam-break", content: content, date: Date().addingTimeInterval(Double(minutes * 60))))
      return true
    } catch {
      problems = [error.localizedDescription]
      return false
    }
  }
  func cancelBreak() { center.removePendingNotificationRequests(withIdentifiers: ["mam-break"]) }
}
