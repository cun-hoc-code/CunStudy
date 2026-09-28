import Foundation
import XCTest
import ZIPFoundation

@testable import StudyCore

final class WorkspaceTests: XCTestCase {
  private func day() -> Date { ISO8601DateFormatter().date(from: "2026-09-18T00:00:00Z")! }
  private var utc: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }
  private func card(_ front: String, _ back: String, deck: String = "Môn học") -> Flashcard {
    var c = Flashcard()
    c.front = front
    c.back = back
    c.deck = deck
    return c
  }
  private func temp() throws -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: u) }
    return u
  }
  func testLegacyBackupWithoutWorkspaceLoads() throws {
    var old = StudyState()
    old.schemaVersion = 1
    old.notes = [QuickNote(title: "Ghi chú cũ", body: "Nội dung")]
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: StateCodec.encode(old)) as? [String: Any])
    object.removeValue(forKey: "workspace")
    let restored = try StateCodec.decode(JSONSerialization.data(withJSONObject: object))
    XCTAssertEqual(restored.notes.first?.title, "Ghi chú cũ")
    XCTAssertTrue(restored.studio.documents.isEmpty)
    XCTAssertEqual(restored.studio.settings.language, "vi")
  }
  func testWorkspaceRoundtrip() throws {
    var s = StudyState()
    s.notes = [
      QuickNote(
        title: "Bài 1", body: "# Đề cương",
        metadata: NoteDetails(subject: "Vật lý", folder: "HK1", tags: ["ôn thi"]))
    ]
    s.studio.journals = [LearningJournal(date: day(), learned: "Cơ học", minutes: 30, mood: 4)]
    let r = try StateCodec.decode(StateCodec.encode(s))
    XCTAssertEqual(r.notes[0].details, s.notes[0].details)
    XCTAssertEqual(r.studio.journals, s.studio.journals)
    XCTAssertEqual(
      r.notes[0].updatedAt.timeIntervalSince1970, s.notes[0].updatedAt.timeIntervalSince1970,
      accuracy: 0.001)
  }
  func testFreeSlotsMergeOverlapsAndClipNow() {
    let d = day()
    var s = StudyState()
    s.studio.blocks = [
      TimeBlock(title: "A", start: d.addingTimeInterval(28800), end: d.addingTimeInterval(36000)),
      TimeBlock(title: "B", start: d.addingTimeInterval(32400), end: d.addingTimeInterval(39600)),
    ]
    let slots = WorkspaceEngine.freeSlots(
      s, on: d, minutes: 30, now: d.addingTimeInterval(27000), calendar: utc)
    XCTAssertEqual(slots.count, 2)
    XCTAssertEqual(slots[0].duration, 1800)
    XCTAssertEqual(slots[1].start, d.addingTimeInterval(39600))
    XCTAssertTrue(
      WorkspaceEngine.freeSlots(s, on: d, now: d.addingTimeInterval(86400), calendar: utc).isEmpty)
  }
  func testCalendarAllDayOccupiesFreeTime() {
    var s = StudyState()
    let d = day()
    s.studio.calendarRecords = [
      CalendarRecord(
        id: "1", title: "Thi", calendar: "Trường", start: d, end: d.addingTimeInterval(86400),
        location: "", isAllDay: true)
    ]
    XCTAssertTrue(WorkspaceEngine.freeSlots(s, on: d, now: d, calendar: utc).isEmpty)
  }
  func testGPAUsesCreditsAndExcludesUngraded() {
    let c = [
      AcademicCourse(credits: 3, officialGrade4: 4), AcademicCourse(credits: 1, officialGrade4: 2),
      AcademicCourse(credits: 8),
    ]
    XCTAssertEqual(WorkspaceEngine.gpa(c), 3.5)
    XCTAssertNil(WorkspaceEngine.gpa([]))
  }
  func testRequiredScoreAndImpossibleTarget() {
    var c = AcademicCourse(components: [
      GradeComponent(weight: 40, score: 2), GradeComponent(weight: 60),
    ])
    XCTAssertEqual(WorkspaceEngine.requiredScore(c, target: 5)!, 7, accuracy: 0.0001)
    XCTAssertGreaterThan(WorkspaceEngine.requiredScore(c, target: 9)!, 10)
    c.components[1].score = 8
    XCTAssertNil(WorkspaceEngine.requiredScore(c, target: 5))
    XCTAssertEqual(WorkspaceEngine.finalScore(c)!, 5.6, accuracy: 0.0001)
  }
  func testValidationRejectsInvalidWeightsMoneyAndAnswer() {
    var s = StudyState()
    s.studio.courses = [
      AcademicCourse(components: [GradeComponent(weight: 60), GradeComponent(weight: 60)])
    ]
    XCTAssertThrowsError(try StateCodec.validate(s))
    s.studio = WorkspaceState()
    s.studio.expenses = [Expense(amount: -1)]
    XCTAssertThrowsError(try StateCodec.validate(s))
    s.studio = WorkspaceState()
    s.studio.questions = [PracticeQuestion(prompt: "Q", options: ["a", "b"], correctIndex: 9)]
    XCTAssertThrowsError(try StateCodec.validate(s))
  }
  func testSplitPreservesRemainderAndRejectsDuplicateMembers() {
    let bill = SharedBill(title: "Photo", amount: 100, payer: "An", members: ["An", "Bình", "Chi"])
    XCTAssertEqual(WorkspaceEngine.shares(bill).map(\.amount), [34, 33, 33])
    var bad = bill
    bad.members = ["An", "An"]
    var s = StudyState()
    s.studio.bills = [bad]
    XCTAssertThrowsError(try StateCodec.validate(s))
  }
  func testGoalClipsFocusToItsTimeWindow() {
    let d = day()
    var s = StudyState()
    s.sessions = [
      FocusSession(
        id: UUID(), subject: "Học", plannedSeconds: 3600,
        segments: [
          FocusSegment(start: d.addingTimeInterval(-1800), end: d.addingTimeInterval(1800))
        ], finishedAt: d.addingTimeInterval(1800), completed: true)
    ]
    let g = LearningGoal(unit: .minutes, start: d, end: d.addingTimeInterval(900))
    XCTAssertEqual(WorkspaceEngine.goalProgress(g, state: s), 15)
  }
  func testCSVQuotesNewlinesUnicodeAndCloze() throws {
    let a = card("Có dấu, \"trích\"\nHàng 2", "Đáp án\nMầm 🌱")
    var b = card("Đây là {{Mầm}}", "")
    b.kind = .cloze
    let r = try DeckCSV.decode(DeckCSV.encode([a, b]))
    XCTAssertEqual(r[0].front, a.front)
    XCTAssertEqual(r[0].back, a.back)
    XCTAssertEqual(r[1].kind, .cloze)
    XCTAssertThrowsError(try DeckCSV.decode("front,back\n\"unclosed,a"))
    XCTAssertEqual(try DeckCSV.decode("\u{feff}front,back\r\nQ,A").count, 1)
  }
  func testQuizHasDistinctDistractors() {
    let c = [card("Q1", "A"), card("Q2", "A"), card("Q3", "B")]
    for q in WorkspaceEngine.questions(from: c) {
      XCTAssertEqual(Set(q.options).count, q.options.count)
      XCTAssertEqual(q.options[q.correctIndex], c.first { $0.id == q.sourceCardID }?.answer)
    }
    XCTAssertTrue(WorkspaceEngine.questions(from: [c[0]]).isEmpty)
  }
  func testDraftsAndBacklinks() {
    let c = WorkspaceEngine.cardDrafts(
      from: "Tế bào: đơn vị sống\nMầm là {{app học tập}}\nKhông cấu trúc", deck: "Sinh học")
    XCTAssertEqual(c.count, 2)
    XCTAssertTrue(c.allSatisfy(\.hasValidContent))
    XCTAssertEqual(WorkspaceEngine.links(in: "[[ Bài 1 ]] và [[Ôn tập]]"), ["Bài 1", "Ôn tập"])
  }
  func testTimedTestSnapshotsQuestionAndClampsDeadline() {
    let d = day()
    var q = PracticeQuestion(prompt: "Cũ", options: ["a", "b"], correctIndex: 1)
    let t = RunningTest(
      startedAt: d, deadline: d.addingTimeInterval(60),
      answers: [PracticeAnswer(question: q, selectedIndex: 1)])
    q.prompt = "Mới"
    let a = t.finish(at: d.addingTimeInterval(600))
    XCTAssertEqual(a.finishedAt, t.deadline)
    XCTAssertEqual(a.answers[0].question.prompt, "Cũ")
    XCTAssertEqual(a.score, 100)
    XCTAssertEqual(t.finish(at: d.addingTimeInterval(-10)).finishedAt, d)
  }
  func testFullBackupPreservesOriginalFilesAndDisablesLock() throws {
    let root = try temp()
    let vault = FileVault(root: root.appendingPathComponent("vault"))
    let bytes = Data("bản thu".utf8)
    let name = try vault.put(bytes, extension: "m4a")
    var s = StudyState()
    s.studio.documents = [LibraryDocument(title: "Thu", kind: .audio, filename: name)]
    s.studio.settings.appLock = true
    let url = root.appendingPathComponent("backup.mamstudy")
    try vault.backup(s, to: url)
    let r = try vault.readBackup(url)
    let new = try XCTUnwrap(r.studio.documents.first?.filename)
    XCTAssertNotEqual(new, name)
    XCTAssertEqual(try Data(contentsOf: vault.url(name)), bytes)
    XCTAssertEqual(try Data(contentsOf: vault.url(new)), bytes)
    XCTAssertFalse(r.studio.settings.appLock)
  }
  func testMissingAttachmentRejected() throws {
    let root = try temp()
    let stage = root.appendingPathComponent("stage")
    let vault = FileVault(root: root.appendingPathComponent("vault"))
    try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
    var s = StudyState()
    s.studio.documents = [LibraryDocument(title: "Lost", kind: .pdf, filename: "missing.pdf")]
    try StateCodec.encode(s).write(to: stage.appendingPathComponent("state.json"))
    let url = root.appendingPathComponent("bad.zip")
    try FileManager.default.zipItem(at: stage, to: url, shouldKeepParent: false)
    XCTAssertThrowsError(try vault.readBackup(url))
  }
  func testTraversalRejectedBeforeWriting() throws {
    let root = try temp()
    let url = root.appendingPathComponent("bad.zip")
    let bytes = Data("bad".utf8)
    let archive = try Archive(url: url, accessMode: .create)
    try archive.addEntry(
      with: "files/../escape.txt", type: .file, uncompressedSize: Int64(bytes.count),
      compressionMethod: .none
    ) { position, size in bytes.subdata(in: Int(position)..<min(bytes.count, Int(position) + size))
    }
    XCTAssertThrowsError(try FileVault(root: root.appendingPathComponent("vault")).readBackup(url))
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: root.appendingPathComponent("escape.txt").path))
  }
  func testAnkiRoundtrip() throws {
    let root = try temp()
    let url = root.appendingPathComponent("cards.apkg")
    let c = [
      card("Thẻ <1>", "Một & hai", deck: "Sinh học"), card("What?", "Answer", deck: "English"),
    ]
    try AnkiDeck.write(c, to: url)
    let r = try AnkiDeck.read(url)
    XCTAssertEqual(r.map(\.front), c.map(\.front))
    XCTAssertEqual(r.map(\.back), c.map(\.back))
    XCTAssertEqual(r.map(\.deck), c.map(\.deck))
    if let path = ProcessInfo.processInfo.environment["MAM_ANKI_FIXTURE"] {
      try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: path))
    }
  }
  func testModernAnkiFailsExplicitly() throws {
    let root = try temp()
    let stage = root.appendingPathComponent("stage")
    try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
    try Data([0, 1, 2]).write(to: stage.appendingPathComponent("collection.anki21b"))
    let url = root.appendingPathComponent("modern.apkg")
    try FileManager.default.zipItem(at: stage, to: url, shouldKeepParent: false)
    XCTAssertThrowsError(try AnkiDeck.read(url))
  }
}
