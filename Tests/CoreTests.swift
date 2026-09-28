import XCTest

@testable import StudyCore

final class CoreTests: XCTestCase {
  let utc = ScheduleEngine.calendar(TimeZone(secondsFromGMT: 0)!)
  func date(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

  func testWeeklyAlarmCanMoveToPreviousDayAndWeek() {
    let v = ScheduleEngine.shifted(weekday: 2, minute: 10, lead: 40)
    XCTAssertEqual(v.weekday, 1)
    XCTAssertEqual(v.minute, 23 * 60 + 30)
    let sunday = ScheduleEngine.shifted(weekday: 1, minute: 0, lead: 60)
    XCTAssertEqual(sunday.weekday, 7)
    XCTAssertEqual(sunday.minute, 1380)
  }
  func testWeekdaysOneOffAndDisabledSchedules() {
    var l = Lesson()
    l.title = "OOP"
    l.weekdays = [2, 4]
    let start = date("2026-09-14T00:00:00Z")
    XCTAssertEqual(ScheduleEngine.occurrences([l], from: start, days: 7, calendar: utc).count, 2)
    l.weekly = false
    l.date = start
    XCTAssertEqual(ScheduleEngine.occurrences([l], from: start, days: 14, calendar: utc).count, 1)
    l.enabled = false
    XCTAssertTrue(ScheduleEngine.occurrences([l], from: start, calendar: utc).isEmpty)
  }
  func testLateNightLessonRemainsVisibleAfterMidnight() {
    var l = Lesson()
    l.title = "Ôn thi"
    l.weekdays = [2]
    l.startMinute = 23 * 60 + 30
    l.durationMinutes = 90
    let now = date("2026-09-15T00:15:00Z")
    let next = ScheduleEngine.next([l], at: now, calendar: utc)
    XCTAssertEqual(next?.start, date("2026-09-14T23:30:00Z"))
    XCTAssertEqual(ScheduleEngine.occurrences([l], from: now, days: 1, calendar: utc).count, 1)
  }
  func testWeeklyTimeKeepsLocalHourAcrossDST() {
    let cal = ScheduleEngine.calendar(TimeZone(identifier: "America/New_York")!)
    var l = Lesson()
    l.title = "Học"
    l.weekdays = [1]
    l.startMinute = 7 * 60
    let values = ScheduleEngine.occurrences(
      [l], from: date("2026-03-01T12:00:00Z"), days: 9, calendar: cal)
    XCTAssertEqual(values.count, 2)
    XCTAssertTrue(values.allSatisfy { cal.component(.hour, from: $0.start) == 7 })
    XCTAssertEqual(values[1].start.timeIntervalSince(values[0].start), 7 * 86400 - 3600)
  }
  func testOneOffAlarmAndNoDoubleCountingAtTouchingEdges() {
    var l = Lesson()
    l.title = "Thi"
    l.weekly = false
    l.date = date("2026-09-14T00:00:00Z")
    l.startMinute = 10
    l.leadMinutes = 40
    XCTAssertEqual(ScheduleEngine.oneOffFire(l, calendar: utc), date("2026-09-13T23:30:00Z"))
    let a = LessonOccurrence(lesson: l, start: l.date, end: l.date.addingTimeInterval(60))
    let b = LessonOccurrence(lesson: l, start: a.end, end: a.end.addingTimeInterval(60))
    XCTAssertFalse(ScheduleEngine.overlaps(a, b))
  }
  func testTimerSurvivesClosingAndCapsAtPlannedDuration() {
    let start = date("2026-09-14T07:00:00Z")
    let f = ActiveFocus(subject: "OOP", plannedSeconds: 1500, startedAt: start, runningSince: start)
    let session = f.finish(at: start.addingTimeInterval(10000))
    XCTAssertEqual(session.seconds, 1500)
    XCTAssertEqual(session.finishedAt, start.addingTimeInterval(1500))
    XCTAssertTrue(session.completed)
  }
  func testPausedTimeNeverCounts() {
    let start = date("2026-09-14T07:00:00Z")
    var f = ActiveFocus(subject: "OOP", plannedSeconds: 1500, startedAt: start, runningSince: start)
    f.pause(at: start.addingTimeInterval(300))
    XCTAssertEqual(f.elapsed(at: start.addingTimeInterval(900)), 300)
    f.resume(at: start.addingTimeInterval(900))
    XCTAssertEqual(f.finish(at: start.addingTimeInterval(1200)).seconds, 600)
  }
  func testStatsSplitAcrossMidnight() {
    let start = date("2026-09-14T23:50:00Z")
    let session = ActiveFocus(
      subject: "OOP", plannedSeconds: 1200, startedAt: start, runningSince: start
    ).finish(at: start.addingTimeInterval(1200))
    let days = StudyStats.daily(
      [session], ending: date("2026-09-15T12:00:00Z"), days: 2, calendar: utc)
    XCTAssertEqual(days[0].minutes, 10)
    XCTAssertEqual(days[1].minutes, 10)
  }
  func testForgottenCardReturnsSoonAndLearningGraduates() {
    let now = date("2026-09-14T12:00:00Z")
    var card = Flashcard()
    card.front = "A"
    card.back = "B"
    card = ReviewEngine.graded(card, rating: .good, at: now)
    XCTAssertEqual(card.due.timeIntervalSince(now), 600)
    card = ReviewEngine.graded(card, rating: .good, at: card.due)
    XCTAssertEqual(card.intervalDays, 1)
    card = ReviewEngine.graded(card, rating: .again, at: now)
    XCTAssertEqual(card.due.timeIntervalSince(now), 60)
    XCTAssertEqual(card.lapses, 1)
    XCTAssertEqual(card.intervalDays, 0)
  }
  func testOverdueReviewsPrecedeNewCardsAndNewLimitPersists() {
    let now = date("2026-09-14T12:00:00Z")
    var state = StudyState()
    state.preferences.newCardsPerDay = 1
    var old = Flashcard()
    old.reviews = 5
    old.due = now.addingTimeInterval(-60)
    var firstNew = Flashcard()
    firstNew.createdAt = now.addingTimeInterval(-60)
    firstNew.due = now
    var secondNew = Flashcard()
    secondNew.createdAt = now
    secondNew.due = now
    state.cards = [firstNew, secondNew, old]
    XCTAssertEqual(ReviewEngine.queue(state, at: now).map(\.id), [old.id, firstNew.id])
    state.reviews.append(.init(cardID: firstNew.id, date: now, rating: .good, wasNew: true))
    XCTAssertEqual(ReviewEngine.queue(state, at: now).map(\.id), [old.id])
  }
  func testClozeAndSuspension() {
    var c = Flashcard()
    c.kind = .cloze
    c.front = "C++ có {{kế thừa}} và {{đa hình}}."
    XCTAssertEqual(c.question, "C++ có […] và […].")
    XCTAssertEqual(c.answer, "C++ có kế thừa và đa hình.")
    c.suspended = true
    var state = StudyState()
    state.cards = [c]
    XCTAssertTrue(ReviewEngine.queue(state, at: Date()).isEmpty)
  }
  func testTSVImportIsAtomicOnMalformedRow() throws {
    XCTAssertEqual(try ReviewEngine.importTSV("front\tback\nhello\txin chào", deck: "EN").count, 1)
    XCTAssertThrowsError(try ReviewEngine.importTSV("hello\txin chào\nbroken", deck: "EN"))
  }
  func testBackupRejectsUnsupportedVersionAndInvalidTime() throws {
    var state = StudyState()
    state.schemaVersion = 10
    XCTAssertThrowsError(try StateCodec.decode(StateCodec.encode(state)))
    state.schemaVersion = 1
    var l = Lesson()
    l.title = "OOP"
    l.startMinute = 2000
    state.lessons = [l]
    XCTAssertThrowsError(try StateCodec.decode(StateCodec.encode(state)))
  }
  func testDiskRoundTripAndKeepsPreviousVersion() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let disk = DiskStore(directory: dir)
    var state = StudyState()
    try disk.save(state)
    state.preferences.name = "Cún"
    try disk.save(state)
    XCTAssertEqual(try disk.load().preferences.name, "Cún")
    XCTAssertEqual(try StateCodec.decode(Data(contentsOf: disk.previous)).preferences.name, "Bạn")
    try Data("corrupt".utf8).write(to: disk.file)
    XCTAssertThrowsError(try disk.save(state))
    XCTAssertEqual(try StateCodec.decode(Data(contentsOf: disk.previous)).preferences.name, "Bạn")
  }

  func testFractionalFocusDatesSurviveManyPauseResumeCycles() throws {
    let start = date("2026-09-14T07:00:00Z")
    // Whole-second JSON dates used to inflate these five 11.2-second segments to 60 seconds.
    let segments = (0..<5).map { index in
      let time = start.addingTimeInterval(Double(index * 20) + 0.9)
      return FocusSegment(start: time, end: time.addingTimeInterval(11.2))
    }
    var state = StudyState()
    state.sessions = [
      .init(
        id: UUID(), subject: "OOP", plannedSeconds: 60,
        segments: segments, finishedAt: segments.last!.end, completed: false)
    ]
    let result = try StateCodec.decode(StateCodec.encode(state))
    XCTAssertEqual(result.sessions[0].seconds, 56, accuracy: 0.01)
    XCTAssertEqual(
      result.sessions[0].segments[0].start.timeIntervalSince(segments[0].start), 0, accuracy: 0.001)
  }
  func testBackupStillReadsLegacyWholeSecondDates() throws {
    var state = StudyState()
    var lesson = Lesson()
    lesson.title = "Lịch cũ"
    state.lessons = [lesson]
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    XCTAssertEqual(try StateCodec.decode(encoder.encode(state)).lessons[0].title, "Lịch cũ")
  }
  func testExportFreezesCopyAndRestoreNeverResumesHistoricalTimer() {
    let start = date("2026-09-14T07:00:00Z")
    var state = StudyState()
    state.activeFocus = .init(
      subject: "OOP", plannedSeconds: 1500, startedAt: start, runningSince: start)
    let snapshot = StateCodec.backupSnapshot(state, at: start.addingTimeInterval(301))
    XCTAssertFalse(state.activeFocus!.isPaused)
    XCTAssertTrue(snapshot.activeFocus!.isPaused)
    XCTAssertEqual(snapshot.activeFocus!.elapsed(at: start.addingTimeInterval(86400)), 301)
    let restored = StateCodec.restoredSnapshot(state)
    XCTAssertTrue(restored.activeFocus!.isPaused)
    XCTAssertEqual(restored.activeFocus!.elapsed(at: start.addingTimeInterval(86400)), 0)
    let ended = StateCodec.backupSnapshot(state, at: start.addingTimeInterval(86400))
    XCTAssertNil(ended.activeFocus)
    XCTAssertEqual(ended.sessions.count, 1)
    XCTAssertEqual(ended.sessions[0].seconds, 1500)
  }
  func testUndoDoesNotOverwriteAnEditedOrDeletedCard() {
    var before = Flashcard()
    before.front = "A"
    before.back = "B"
    let now = Date()
    let after = ReviewEngine.graded(before, rating: .good, at: Date())
    let log = ReviewLog(cardID: before.id, date: now, rating: .good, wasNew: true)
    let undo = ReviewUndo(before: before, after: after, logID: log.id)
    var state = StudyState()
    state.cards = [after]
    state.reviews = [log]
    XCTAssertEqual(undo.restored(state)?.cards, [before])
    XCTAssertEqual(undo.restored(state)?.reviews, [])
    state.cards[0].front = "Đã sửa"
    XCTAssertNil(undo.restored(state))
    state.cards = []
    XCTAssertNil(undo.restored(state))
  }
  func testClozeConcealsAnswersAcrossNewlines() {
    var card = Flashcard()
    card.kind = .cloze
    card.front = "Nhớ {{dòng 1\ndòng 2}} nhé"
    XCTAssertTrue(card.hasValidContent)
    XCTAssertEqual(card.question, "Nhớ […] nhé")
    XCTAssertEqual(card.answer, "Nhớ dòng 1\ndòng 2 nhé")
  }
  func testNewCardInFutureAndDailyLimitAcrossDecks() {
    let now = Date()
    var state = StudyState()
    state.preferences.newCardsPerDay = 1
    var card = Flashcard()
    card.deck = "OOP"
    card.due = now.addingTimeInterval(600)
    state.cards = [card]
    XCTAssertTrue(ReviewEngine.queue(state, at: now).isEmpty)
    state.cards[0].due = now
    state.reviews = [.init(cardID: UUID(), date: now, rating: .easy, wasNew: true)]
    XCTAssertTrue(ReviewEngine.queue(state, deck: "OOP", at: now).isEmpty)
    XCTAssertEqual(
      ReviewEngine.queue(state, deck: "OOP", at: now.addingTimeInterval(86400)).count, 1)
  }
  func testTSVUnderstandsBOMAndRejectsExtraColumns() throws {
    let cards = try ReviewEngine.importTSV(
      "\u{FEFF}front\tback\r\n hello \t xin chào \t ví dụ ", deck: "EN")
    XCTAssertEqual(cards.count, 1)
    XCTAssertEqual(cards[0].front, "hello")
    XCTAssertEqual(cards[0].example, "ví dụ")
    XCTAssertThrowsError(try ReviewEngine.importTSV("A\tB\tC\tLost", deck: "EN"))
  }
  func testInvalidStateCannotOverwriteGoodDiskData() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let disk = DiskStore(directory: dir)
    try disk.save(StudyState())
    var bad = StudyState()
    var card = Flashcard()
    card.front = "A"
    card.back = "B"
    card.learningStep = -1
    bad.cards = [card]
    XCTAssertThrowsError(try disk.save(bad))
    XCTAssertTrue(try disk.load().cards.isEmpty)
    bad = StudyState()
    var task = StudyTask()
    task.title = "Bài tập"
    let step = ChecklistItem(title: "Bước 1")
    task.subtasks = [step, step]
    bad.tasks = [task]
    XCTAssertThrowsError(try StateCodec.validate(bad))
  }
  func testCompletedFocusCannotAlsoBeActiveInBackup() {
    let now = Date()
    let active = ActiveFocus(subject: "OOP", plannedSeconds: 60, startedAt: now, runningSince: now)
    var state = StudyState()
    state.activeFocus = active
    state.sessions = [active.finish(at: now.addingTimeInterval(60))]
    XCTAssertThrowsError(try StateCodec.validate(state))
  }
}
