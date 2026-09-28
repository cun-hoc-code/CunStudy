import XCTest

@testable import StudyCore

final class ProgressTests: XCTestCase {
  let utc = ScheduleEngine.calendar(TimeZone(secondsFromGMT: 0)!)
  func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
  func session(_ start: Date, seconds: Double = 300) -> FocusSession {
    FocusSession(
      id: UUID(), subject: "OOP", plannedSeconds: seconds,
      segments: [.init(start: start, end: start.addingTimeInterval(seconds))],
      finishedAt: start.addingTimeInterval(seconds), completed: true)
  }
  func reviews(at date: Date, count: Int) -> [ReviewLog] {
    (0..<count).map { _ in .init(cardID: UUID(), date: date, rating: .good, wasNew: true) }
  }

  func testStreakKeepsYesterdayUntilTodayEndsAndRestartsAfterGap() {
    var state = StudyState()
    state.sessions = [session(date("2026-09-14T08:00:00Z")), session(date("2026-09-15T08:00:00Z"))]
    let today = date("2026-09-16T18:00:00Z")
    let kept = StudyProgress.summary(state, at: today, calendar: utc)
    XCTAssertEqual(kept.currentStreak, 2)
    XCTAssertFalse(kept.today.qualifies)
    XCTAssertEqual(
      StudyProgress.summary(state, at: date("2026-09-17T00:00:00Z"), calendar: utc).currentStreak, 0
    )
    state.sessions.append(session(date("2026-09-17T08:00:00Z")))
    let restarted = StudyProgress.summary(state, at: date("2026-09-17T09:00:00Z"), calendar: utc)
    XCTAssertEqual(restarted.currentStreak, 1)
    XCTAssertEqual(restarted.bestStreak, 2)
  }

  func testFlashcardsQualifyWithoutFocusAndRepeatedCardDoesNotFarmXP() {
    let now = date("2026-09-17T12:00:00Z")
    var state = StudyState()
    state.reviews = reviews(at: now, count: 4)
    let first = state.reviews[0]
    for _ in 0..<20 {
      state.reviews.append(.init(cardID: first.cardID, date: now, rating: .easy, wasNew: false))
    }
    let initial = StudyProgress.summary(state, at: now, calendar: utc)
    XCTAssertFalse(initial.today.qualifies)
    XCTAssertEqual(initial.today.xp, 20)
    state.reviews += reviews(at: now, count: 1)
    let qualified = StudyProgress.summary(state, at: now, calendar: utc)
    XCTAssertEqual(qualified.currentStreak, 1)
    XCTAssertEqual(qualified.today.uniqueCards, 5)
    XCTAssertEqual(qualified.today.reviewCount, 25)
    XCTAssertEqual(qualified.today.xp, 25)
  }

  func testSplitMidnightDoesNotCreditWholeSessionToFinishDay() {
    var state = StudyState()
    state.sessions = [session(date("2026-09-16T23:55:00Z"), seconds: 600)]
    let summary = StudyProgress.summary(state, at: date("2026-09-17T08:00:00Z"), calendar: utc)
    XCTAssertEqual(summary.currentStreak, 2)
    XCTAssertEqual(summary.today.focusSeconds, 300)
    XCTAssertEqual(summary.completedSessions, 1)
    XCTAssertEqual(summary.days.map(\.focusSeconds), [300, 300])
  }

  func testStreakUsesCalendarDaysAcrossDaylightSaving() {
    let cal = ScheduleEngine.calendar(TimeZone(identifier: "America/New_York")!)
    var state = StudyState()
    state.sessions = [
      session(date("2026-03-07T16:00:00Z")), session(date("2026-03-08T15:00:00Z")),
      session(date("2026-03-09T15:00:00Z")),
    ]
    let summary = StudyProgress.summary(state, at: date("2026-03-09T18:00:00Z"), calendar: cal)
    XCTAssertEqual(summary.currentStreak, 3)
    XCTAssertEqual(summary.bestStreak, 3)
    let days = StudyProgress.recentDays(
      summary, count: 3, at: date("2026-03-09T18:00:00Z"), calendar: cal)
    XCTAssertEqual(days.count, 3)
    XCTAssertEqual(days[2].date.timeIntervalSince(days[1].date), 23 * 3600)
  }

  func testCurrentTimeClipsFutureDataAndActiveTimerDoesNotEarnXP() {
    let now = date("2026-09-17T12:00:00Z")
    var state = StudyState()
    state.activeFocus = ActiveFocus(
      subject: "Học", plannedSeconds: 1500, startedAt: now.addingTimeInterval(-900),
      runningSince: now.addingTimeInterval(-900))
    state.reviews = reviews(at: now.addingTimeInterval(60), count: 5)
    XCTAssertEqual(StudyProgress.summary(state, at: now, calendar: utc).xp, 0)
    state.sessions = [session(now.addingTimeInterval(-120), seconds: 600)]
    let summary = StudyProgress.summary(state, at: now, calendar: utc)
    XCTAssertEqual(summary.today.focusSeconds, 120)
    XCTAssertEqual(summary.completedSessions, 0)
    XCTAssertFalse(summary.today.qualifies)
  }

  func testXPIsCappedAndProgressCanBeRecomputedAfterUndo() {
    let now = date("2026-09-17T12:00:00Z")
    var state = StudyState()
    state.sessions = [session(now.addingTimeInterval(-14400), seconds: 14400)]
    state.reviews = reviews(at: now, count: 150)
    XCTAssertEqual(StudyProgress.summary(state, at: now, calendar: utc).xp, 740)
    state.sessions = []
    state.reviews = reviews(at: now, count: 5)
    XCTAssertEqual(StudyProgress.summary(state, at: now, calendar: utc).currentStreak, 1)
    state.reviews.removeLast()
    XCTAssertEqual(StudyProgress.summary(state, at: now, calendar: utc).currentStreak, 0)
    XCTAssertEqual(StudyProgress.summary(state, at: now, calendar: utc).xp, 20)
  }

  func testEmptyHeatmapHasExactlyRequestedDaysAndNoInventedActivity() {
    let now = date("2026-09-17T12:00:00Z")
    let summary = StudyProgress.summary(StudyState(), at: now, calendar: utc)
    let days = StudyProgress.recentDays(summary, count: 84, at: now, calendar: utc)
    XCTAssertEqual(days.count, 84)
    XCTAssertEqual(Set(days.map(\.date)).count, 84)
    XCTAssertTrue(days.allSatisfy { $0.xp == 0 && !$0.qualifies })
    XCTAssertEqual(days.last?.date, utc.startOfDay(for: now))
    XCTAssertEqual(summary.level, 1)
    XCTAssertEqual(summary.bestStreak, 0)
    XCTAssertTrue(StudyProgress.badges(summary).allSatisfy { !$0.unlocked })
  }

  func testV1BackupWithoutNewFieldsKeepsAllOriginalData() throws {
    var original = StudyState()
    original.preferences.name = "Cún"
    original.preferences.hasOnboarded = true
    original.preferences.dailyFocusMinutes = 90
    var card = Flashcard()
    card.front = "class"
    card.back = "lớp"
    card.due = date("2026-09-16T10:00:00Z")
    card.createdAt = card.due
    original.cards = [card]
    original.reviews = [
      .init(cardID: card.id, date: date("2026-09-16T10:00:00Z"), rating: .good, wasNew: true)
    ]
    var json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: StateCodec.encode(original)) as? [String: Any])
    var prefs = try XCTUnwrap(json["preferences"] as? [String: Any])
    for key in ["appearance", "haptics", "liveActivities", "dailyReviewGoal"] {
      prefs.removeValue(forKey: key)
    }
    json["preferences"] = prefs
    let restored = try StateCodec.decode(JSONSerialization.data(withJSONObject: json))
    XCTAssertEqual(restored, original)
    XCTAssertEqual(restored.preferences.appearance, .system)
    XCTAssertTrue(restored.preferences.haptics)
    XCTAssertTrue(restored.preferences.liveActivities)
    XCTAssertEqual(restored.preferences.dailyReviewGoal, 10)
  }

  func testReviewSnapshotSurvivesCardDeletionAndBackupRoundTrip() throws {
    var state = StudyState()
    let due = date("2026-09-19T10:00:00Z")
    state.reviews = [
      .init(
        cardID: UUID(), date: date("2026-09-17T10:00:00Z"), rating: .good, wasNew: true,
        deck: "OOP", question: "Đa hình là gì?", nextDue: due)
    ]
    let restored = try StateCodec.decode(StateCodec.encode(state))
    XCTAssertEqual(restored.reviews, state.reviews)
    XCTAssertEqual(restored.reviews.first?.question, "Đa hình là gì?")
    XCTAssertEqual(restored.cards.count, 0)
  }

  func testNewPreferencesRoundTripAndRejectInvalidReviewGoal() throws {
    var state = StudyState()
    state.preferences.appearance = .dark
    state.preferences.haptics = false
    state.preferences.liveActivities = false
    state.preferences.dailyReviewGoal = 25
    XCTAssertEqual(try StateCodec.decode(StateCodec.encode(state)), state)
    state.preferences.dailyReviewGoal = 0
    XCTAssertThrowsError(try StateCodec.validate(state))
    state.preferences.dailyReviewGoal = 101
    XCTAssertThrowsError(try StateCodec.validate(state))
  }
}
