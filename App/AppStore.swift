import Combine
import SwiftUI
import WidgetKit

@MainActor
final class AppStore: ObservableObject {
  @Published private(set) var state = StudyState()
  @Published var errorMessage: String?
  @Published var widgetMessage = "Chưa kiểm tra"
  @Published private(set) var readOnly = false
  @Published var tab = 0
  @Published var reviewUndoAvailable = false
  @Published var completedFocus: FocusSession?
  let reminders = ReminderService()
  let liveActivity = FocusActivityService()
  private let disk: DiskStore
  private var previousReview: ReviewUndo?

  init() {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    disk = DiskStore(directory: base.appendingPathComponent("MamStudy", isDirectory: true))
    do { state = try disk.load() } catch {
      readOnly = true
      errorMessage =
        "Không đọc được dữ liệu đã lưu. Dữ liệu gốc được giữ nguyên. Vào Cài đặt để khôi phục bản trước hoặc nhập bản sao lưu. \(error.localizedDescription)"
    }
    refresh()
  }

  @discardableResult
  func change(publishServices: Bool = true, _ edit: (inout StudyState) -> Void) -> Bool {
    guard !readOnly else {
      errorMessage = "Hãy khôi phục dữ liệu trong Cài đặt trước khi sửa."
      return false
    }
    var next = state
    edit(&next)
    next.schemaVersion = 2
    do {
      try StateCodec.validate(next)
      try disk.save(next)
      if let previousReview, !previousReview.canRestore(in: next) { clearReviewUndo() }
      state = next
      if publishServices {
        publishSnapshot()
        reminders.reconcile(state)
        liveActivity.reconcile(state)
        FocusShield.shared.reconcile(state.activeFocus)
      }
      return true
    } catch {
      errorMessage = "Chưa lưu được: \(error.localizedDescription)"
      return false
    }
  }

  func refresh() {
    guard !readOnly else { return }
    if let test = state.studio.runningTest, test.deadline <= Date() { finishTest() }
    settleFocus()
    publishSnapshot()
    reminders.reconcile(state)
    liveActivity.reconcile(state)
    FocusShield.shared.reconcile(state.activeFocus)
  }
  func publishSnapshot() {
    guard !readOnly else {
      widgetMessage = "Hãy khôi phục dữ liệu trước khi cập nhật widget."
      return
    }
    guard WidgetStorage.isEnabled else {
      widgetMessage = "Bản Basic không có widget. Cài bản đầy đủ để dùng tiện ích."
      return
    }
    let progress = StudyProgress.summary(state, at: Date())
    let value = WidgetSnapshot(
      updatedAt: Date(), lessons: state.lessons,
      pendingTasks: state.tasks.filter { !$0.done }.count,
      dueCards: ReviewEngine.queue(state, at: Date()).count,
      todayFocusMinutes: Int(progress.today.minutes),
      goalMinutes: state.preferences.dailyFocusMinutes,
      currentStreak: progress.currentStreak,
      lastStudyDay: progress.days.last(where: \.qualifies)?.date,
      deadlines: state.tasks.filter { !$0.done && $0.due != nil }.compactMap { task in
        task.due.map {
          WidgetDeadline(id: task.id, title: task.title, due: $0, isExam: task.kind == .exam)
        }
      }.sorted { $0.due < $1.due })
    do {
      try WidgetStorage.save(value)
      WidgetCenter.shared.reloadAllTimelines()
      widgetMessage = "Đã gửi dữ liệu mới tới widget."
    } catch { widgetMessage = error.localizedDescription }
  }
  func saveLesson(_ value: Lesson) -> Bool { change { upsert(value, in: &$0.lessons) } }
  func saveTask(_ value: StudyTask) -> Bool { change { upsert(value, in: &$0.tasks) } }
  func saveNote(_ value: QuickNote) -> Bool { change { upsert(value, in: &$0.notes) } }
  func saveCard(_ value: Flashcard) -> Bool { change { upsert(value, in: &$0.cards) } }
  func toggleTask(_ id: UUID) {
    let wasDone = state.tasks.first { $0.id == id }?.done == true
    if change({ s in
      guard let i = s.tasks.firstIndex(where: { $0.id == id }) else { return }
      s.tasks[i].done.toggle()
      s.tasks[i].completedAt = s.tasks[i].done ? Date() : nil
    }) {
      if !wasDone { StudyHaptics.success(enabled: state.preferences.haptics) }
    }
  }
  func startFocus(subject: String, minutes: Int) {
    guard state.activeFocus == nil, (1...120).contains(minutes) else { return }
    let now = Date()
    if change({
      $0.activeFocus = ActiveFocus(
        subject: subject.trimmed.isEmpty ? "Tự học" : subject.trimmed,
        plannedSeconds: Double(minutes * 60), startedAt: now, runningSince: now)
    }) {
      completedFocus = nil
      reminders.cancelBreak()
      StudyHaptics.selection(enabled: state.preferences.haptics)
    }
  }
  func pauseOrResume() {
    settleFocus()
    _ = change { s in
      if s.activeFocus?.isPaused == true {
        s.activeFocus?.resume(at: Date())
      } else {
        s.activeFocus?.pause(at: Date())
      }
    }
  }
  func finishFocus(discard: Bool = false) {
    guard let active = state.activeFocus else { return }
    let session = active.finish(at: Date())
    if change({ s in
      if !discard && session.seconds >= 1 && !s.sessions.contains(where: { $0.id == session.id }) {
        s.sessions.append(session)
      }
      s.activeFocus = nil
    }) {
      AmbientAudio.shared.stop()
      if !discard && session.completed {
        completedFocus = session
        StudyHaptics.success(enabled: state.preferences.haptics)
      }
    }
  }
  func settleFocus() {
    guard !readOnly, let active = state.activeFocus, let end = active.endDate, end <= Date() else {
      return
    }
    finishFocus()
  }
  @discardableResult
  func review(_ card: Flashcard, rating: RecallRating) -> Bool {
    guard let current = state.cards.first(where: { $0.id == card.id }), current == card else {
      return false
    }
    let now = Date()
    let graded = ReviewEngine.graded(current, rating: rating, at: now)
    let log = ReviewLog(
      cardID: card.id, date: now, rating: rating, wasNew: current.isNew,
      deck: current.deck, question: String(current.question.prefix(500)), nextDue: graded.due)
    if change({ s in
      upsert(graded, in: &s.cards)
      s.reviews.append(log)
    }) {
      previousReview = ReviewUndo(before: current, after: graded, logID: log.id)
      reviewUndoAvailable = true
      StudyHaptics.selection(enabled: state.preferences.haptics)
      return true
    }
    return false
  }
  @discardableResult
  func undoReview() -> UUID? {
    guard let undo = previousReview, let restored = undo.restored(state) else {
      clearReviewUndo()
      return nil
    }
    if change({ $0 = restored }) {
      clearReviewUndo()
      return undo.before.id
    }
    return nil
  }
  func clearReviewUndo() {
    previousReview = nil
    reviewUndoAvailable = false
  }
  func exportData() throws -> URL {
    guard !readOnly else {
      throw StudyError.invalid(
        "Dữ liệu chưa đọc được. Hãy khôi phục trước khi xuất bản sao lưu mới.")
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("MamStudy-backup.json")
    try StateCodec.encode(StateCodec.backupSnapshot(state, at: Date())).write(
      to: url, options: .atomic)
    return url
  }
  func readImport(_ url: URL) throws -> StudyState {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    let values = try url.resourceValues(forKeys: [.fileSizeKey])
    guard (values.fileSize ?? 0) <= 25 * 1024 * 1024 else {
      throw StudyError.invalid("File lớn hơn 25 MB.")
    }
    return try StateCodec.decode(Data(contentsOf: url))
  }
  func restore(_ value: StudyState) {
    do {
      var value = StateCodec.restoredSnapshot(value)
      value.studio.settings.appLock = false
      try StateCodec.validate(value)
      try FileManager.default.createDirectory(at: disk.directory, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: disk.file.path) {
        try Data(contentsOf: disk.file).write(to: disk.beforeRestore, options: .atomic)
      }
      try StateCodec.encode(value).write(to: disk.file, options: .atomic)
      state = value
      readOnly = false
      completedFocus = nil
      clearReviewUndo()
      refresh()
    } catch { errorMessage = "Chưa khôi phục: \(error.localizedDescription)" }
  }
  func restorePrevious() {
    do { restore(try StateCodec.decode(Data(contentsOf: disk.previous))) } catch {
      errorMessage = "Không đọc được bản trước: \(error.localizedDescription)"
    }
  }
  func restoreBeforeImport() {
    do { restore(try StateCodec.decode(Data(contentsOf: disk.beforeRestore))) } catch {
      errorMessage =
        "Chưa có bản trước lần nhập, hoặc bản đó không đọc được: \(error.localizedDescription)"
    }
  }
  func addDemo() {
    _ = change { s in
      guard s.lessons.isEmpty && s.tasks.isEmpty && s.cards.isEmpty && s.notes.isEmpty else {
        return
      }
      var lesson = Lesson()
      lesson.title = "Lập trình hướng đối tượng"
      lesson.subject = "C++ / OOP"
      lesson.weekdays = [2, 5]
      lesson.location = "Phòng học mẫu"
      lesson.color = .sage
      var home = Lesson()
      home.title = "Ôn tiếng Anh"
      home.area = .home
      home.weekdays = [2, 4, 6]
      home.startMinute = 19 * 60
      home.durationMinutes = 45
      home.color = .lavender
      var task = StudyTask()
      task.title = "Thử tạo lịch học của mình"
      task.area = .personal
      var note = QuickNote()
      note.title = "Chào bạn, đây là Mầm 🌱"
      note.body = "Dữ liệu này là ví dụ. Bạn có thể sửa hoặc xóa để bắt đầu sổ học tập riêng."
      var card = Flashcard()
      card.deck = "Tiếng Anh"
      card.kind = .vocabulary
      card.front = "curious"
      card.back = "tò mò, ham tìm hiểu"
      card.example = "I am curious about how this works."
      s.lessons = [lesson, home]
      s.tasks = [task]
      s.notes = [note]
      s.cards = [card]
    }
  }
}

func upsert<T: Identifiable>(_ value: T, in array: inout [T]) where T.ID: Equatable {
  if let i = array.firstIndex(where: { $0.id == value.id }) {
    array[i] = value
  } else {
    array.append(value)
  }
}
extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
