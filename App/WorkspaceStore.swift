import Foundation

extension AppStore {
  @discardableResult func editStudio(
    publishServices: Bool = true, _ edit: (inout WorkspaceState) -> Void
  ) -> Bool {
    change(publishServices: publishServices) {
      var value = $0.studio
      edit(&value)
      $0.studio = value
    }
  }
  func saveDocument(_ value: LibraryDocument) -> Bool {
    editStudio {
      upsert(value, in: &$0.documents)
      var room = $0.readingRoom
      for index in room.books.indices where room.books[index].documentID == value.id {
        room.books[index].title = value.title
      }
      $0.readingRoom = room
    }
  }
  func saveBlock(_ value: TimeBlock) -> Bool { editStudio { upsert(value, in: &$0.blocks) } }
  func saveJournal(_ value: LearningJournal) -> Bool {
    editStudio { upsert(value, in: &$0.journals) }
  }
  func saveQuestion(_ value: PracticeQuestion) -> Bool {
    editStudio { upsert(value, in: &$0.questions) }
  }
  func saveCourse(_ value: AcademicCourse) -> Bool { editStudio { upsert(value, in: &$0.courses) } }
  func saveGoal(_ value: LearningGoal) -> Bool { editStudio { upsert(value, in: &$0.goals) } }
  func saveExpense(_ value: Expense) -> Bool { editStudio { upsert(value, in: &$0.expenses) } }
  func saveBill(_ value: SharedBill) -> Bool { editStudio { upsert(value, in: &$0.bills) } }
  func startTest(_ questions: [PracticeQuestion], minutes: Int, title: String) {
    guard state.studio.runningTest == nil, !questions.isEmpty, (1...180).contains(minutes) else {
      return
    }
    let now = Date()
    _ = editStudio {
      $0.runningTest = RunningTest(
        title: title, startedAt: now, deadline: now.addingTimeInterval(Double(minutes * 60)),
        answers: questions.prefix(500).map { PracticeAnswer(question: $0) })
    }
  }
  func answerTest(_ index: Int) {
    guard let t = state.studio.runningTest, t.deadline > Date(),
      t.answers.indices.contains(t.position),
      t.answers[t.position].question.options.indices.contains(index)
    else { return }
    _ = editStudio { $0.runningTest?.answers[t.position].selectedIndex = index }
  }
  func finishTest() {
    guard let test = state.studio.runningTest else { return }
    if editStudio({
      if !$0.attempts.contains(where: { $0.id == test.id }) {
        $0.attempts.append(test.finish(at: Date()))
      }
      $0.runningTest = nil
    }) {
      StudyHaptics.success(enabled: state.preferences.haptics)
    }
  }
  func t(_ vi: String, _ en: String) -> String { state.studio.settings.language == "en" ? en : vi }
}

extension AppStore {
  @discardableResult func addBook(_ document: LibraryDocument) -> Bool {
    guard document.kind == .pdf || !document.extractedText.trimmed.isEmpty else { errorMessage = "Tài liệu chưa có chữ để đọc thành sách. Dùng TXT, PDF hoặc ảnh có chữ OCR."; return false }
    return editStudio {
      guard !$0.readingRoom.books.contains(where: { $0.documentID == document.id }) else { return }
      var book = BookRecord(documentID: document.id, title: document.title)
      book.preferences.originalPDF = document.kind == .pdf && document.extractedText.trimmed.isEmpty
      $0.readingRoom.books.append(book)
    }
  }
  /// Reader progress does not affect reminders, Live Activity or widgets.
  @discardableResult func saveBook(_ value: BookRecord) -> Bool {
    editStudio(publishServices: false) { upsert(value, in: &$0.readingRoom.books) }
  }
}
