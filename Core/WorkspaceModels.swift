import Foundation

enum TaskKind: String, Codable, CaseIterable, Identifiable {
  case assignment, exam, tuition, personal
  var id: String { rawValue }
  var title: String {
    switch self {
    case .assignment: return "Bài tập"
    case .exam: return "Kỳ thi"
    case .tuition: return "Học phí"
    case .personal: return "Cá nhân"
    }
  }
}
enum LibraryKind: String, Codable, CaseIterable { case pdf, image, audio, file, link, drawing }
enum CollectionLayout: String, Codable, CaseIterable, Identifiable {
  case list, grid, cards
  var id: String { rawValue }
  var title: String {
    switch self {
    case .list: return "Danh sách"
    case .grid: return "Lưới"
    case .cards: return "Thẻ"
    }
  }
}
struct NoteDetails: Codable, Equatable {
  var subject = ""
  var folder = ""
  var tags: [String] = []
  var checklist: [ChecklistItem] = []
  var attachments: [UUID] = []
}
struct LibraryDocument: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var subject = ""
  var term = ""
  var tags: [String] = []
  var kind: LibraryKind = .file
  var filename: String? = nil
  var link: String? = nil
  var extractedText = ""
  var bookmarks: [Int] = []
  var createdAt = Date()
}
struct TimeBlock: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var subject = ""
  var start = Date()
  var end = Date().addingTimeInterval(1500)
  var completed = false
  var reminderMinutes: Int? = 10
}
struct CalendarRecord: Identifiable, Codable, Equatable {
  var id: String
  var title: String
  var calendar: String
  var start: Date
  var end: Date
  var location: String
  var isAllDay: Bool
}
struct LearningJournal: Identifiable, Codable, Equatable {
  var id = UUID()
  var date = Date()
  var subject = ""
  var learned = ""
  var nextStep = ""
  var minutes = 0
  var mood = 3
}
struct PracticeQuestion: Identifiable, Codable, Equatable {
  var id = UUID()
  var subject = ""
  var chapter = ""
  var prompt = ""
  var options = ["", "", "", ""]
  var correctIndex = 0
  var explanation = ""
  var sourceCardID: UUID? = nil
}
struct PracticeAnswer: Identifiable, Codable, Equatable {
  var id: UUID { question.id }
  var question: PracticeQuestion
  var selectedIndex: Int? = nil
  var correct: Bool { selectedIndex == question.correctIndex }
}
struct PracticeAttempt: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var startedAt = Date()
  var finishedAt = Date()
  var answers: [PracticeAnswer] = []
  var score: Double {
    answers.isEmpty ? 0 : Double(answers.filter(\.correct).count) / Double(answers.count) * 100
  }
}
struct RunningTest: Codable, Equatable {
  var id = UUID()
  var title = ""
  var startedAt = Date()
  var deadline = Date().addingTimeInterval(1200)
  var answers: [PracticeAnswer] = []
  var position = 0
  func finish(at now: Date) -> PracticeAttempt {
    PracticeAttempt(
      id: id, title: title, startedAt: startedAt, finishedAt: max(startedAt, min(now, deadline)),
      answers: answers)
  }
}
struct GradeComponent: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var weight = 0.0
  var score: Double? = nil
}
struct AcademicCourse: Identifiable, Codable, Equatable {
  var id = UUID()
  var code = ""
  var name = ""
  var semester = ""
  var credits = 3
  var components: [GradeComponent] = []
  var officialGrade4: Double? = nil
  var passed = false
  var needsRetake = false
}
enum GoalUnit: String, Codable, CaseIterable, Identifiable {
  case minutes, cards, chapters, tasks
  var id: String { rawValue }
  var title: String {
    switch self {
    case .minutes: return "Phút tập trung"
    case .cards: return "Thẻ đã ôn"
    case .chapters: return "Chương"
    case .tasks: return "Công việc"
    }
  }
}
struct LearningGoal: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var unit: GoalUnit = .chapters
  var target = 5
  var manualProgress = 0
  var start = Date()
  var end = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
}
struct Expense: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var category = "Ăn uống"
  var amount: Int64 = 0
  var date = Date()
}
struct SharedBill: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var amount: Int64 = 0
  var payer = ""
  var members: [String] = []
  var settledMembers: [String] = []
  var date = Date()
}
struct WorkspaceSettings: Codable, Equatable {
  var language = "vi"
  var layout: CollectionLayout = .cards
  var reduceMotion = false
  var appLock = false
  var streakReminder = false
  var streakHour = 20
  var monthlyBudget: Int64 = 2_000_000
  var graduationCredits = 120
}
struct WorkspaceState: Codable, Equatable {
  var documents: [LibraryDocument] = []
  var blocks: [TimeBlock] = []
  var calendarRecords: [CalendarRecord] = []
  var journals: [LearningJournal] = []
  var questions: [PracticeQuestion] = []
  var attempts: [PracticeAttempt] = []
  var runningTest: RunningTest? = nil
  var courses: [AcademicCourse] = []
  var goals: [LearningGoal] = []
  var expenses: [Expense] = []
  var bills: [SharedBill] = []
  var settings = WorkspaceSettings()
  var reading: ReadingState? = nil
  var feedback: FeedbackPreferences? = nil
  var readingRoom: ReadingState { get { reading ?? ReadingState() } set { reading = newValue } }
  var interaction: FeedbackPreferences { get { feedback ?? FeedbackPreferences() } set { feedback = newValue } }
}
