import Foundation

enum StudyArea: String, Codable, CaseIterable, Identifiable {
  case school, home, personal
  var id: String { rawValue }
  var title: String {
    switch self {
    case .school: return "Ở trường"
    case .home: return "Tự học"
    case .personal: return "Cá nhân"
    }
  }
  var symbol: String {
    switch self {
    case .school: return "building.2"
    case .home: return "house"
    case .personal: return "leaf"
    }
  }
}

enum InkColor: String, Codable, CaseIterable, Identifiable {
  case sage, peach, lavender, sky, butter, rose
  var id: String { rawValue }
  var title: String {
    switch self {
    case .sage: return "Xanh lá"
    case .peach: return "Cam đào"
    case .lavender: return "Tím"
    case .sky: return "Xanh trời"
    case .butter: return "Vàng"
    case .rose: return "Hồng"
    }
  }
}

enum ReminderMode: String, Codable, CaseIterable, Identifiable {
  case off, notification, alarm
  var id: String { rawValue }
  var title: String {
    switch self {
    case .off: return "Tắt"
    case .notification: return "Thông báo"
    case .alarm: return "Báo thức hệ thống"
    }
  }
}

struct Lesson: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var subject = ""
  var area: StudyArea = .school
  var location = ""
  var teacher = ""
  var notes = ""
  var color: InkColor = .sage
  var weekly = true
  /// Gregorian weekday: Sunday = 1, Monday = 2.
  var weekdays = [2]
  var date = Date()
  var startMinute = 7 * 60
  var durationMinutes = 90
  var reminder: ReminderMode = .off
  /// Minutes needed to prepare + travel. Alarm fires before the lesson by this amount.
  var leadMinutes = 30
  var enabled = true
}

struct LessonOccurrence: Identifiable, Equatable {
  let lesson: Lesson
  let start: Date
  let end: Date
  var id: String { "\(lesson.id.uuidString)-\(Int(start.timeIntervalSince1970))" }
  var leaveAt: Date { start.addingTimeInterval(-Double(lesson.leadMinutes) * 60) }
}

enum Priority: Int, Codable, CaseIterable, Identifiable {
  case low, normal, high
  var id: Int { rawValue }
  var title: String { ["Thấp", "Vừa", "Cao"][rawValue] }
}

struct StudyTask: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var subject = ""
  var area: StudyArea = .school
  var note = ""
  var due: Date? = nil
  var priority: Priority = .normal
  var done = false
  var completedAt: Date? = nil
  var remind = false
  var subtasks: [ChecklistItem] = []
  var kind: TaskKind? = nil
  var reminderLeadMinutes: Int? = nil
}

struct ChecklistItem: Identifiable, Codable, Equatable {
  var id = UUID()
  var title: String
  var done = false
}

enum NoteCategory: String, Codable, CaseIterable, Identifiable {
  case quick, books, subjects, important
  var id: String { rawValue }
  var title: String {
    switch self {
    case .quick: return "Ghi nhanh"
    case .books: return "Sách cần mua"
    case .subjects: return "Môn học"
    case .important: return "Quan trọng"
    }
  }
}

struct QuickNote: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var body = ""
  var category: NoteCategory = .quick
  var color: InkColor = .butter
  var pinned = false
  var updatedAt = Date()
  var metadata: NoteDetails? = nil
  var details: NoteDetails {
    get { metadata ?? NoteDetails() }
    set { metadata = newValue }
  }
}

struct FocusSegment: Codable, Equatable {
  var start: Date
  var end: Date
  var seconds: Double { max(0, end.timeIntervalSince(start)) }
}

struct FocusSession: Identifiable, Codable, Equatable {
  var id: UUID
  var subject: String
  var plannedSeconds: Double
  var segments: [FocusSegment]
  var finishedAt: Date
  var completed: Bool
  var seconds: Double { min(plannedSeconds, segments.reduce(0) { $0 + $1.seconds }) }
}

struct ActiveFocus: Identifiable, Codable, Equatable {
  var id = UUID()
  var subject: String
  var plannedSeconds: Double
  var startedAt: Date
  var runningSince: Date?
  var segments: [FocusSegment] = []
  var isPaused: Bool { runningSince == nil }
  var savedSeconds: Double { segments.reduce(0) { $0 + $1.seconds } }
  func elapsed(at now: Date) -> Double {
    min(
      plannedSeconds, savedSeconds + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0))
  }
  var endDate: Date? { runningSince?.addingTimeInterval(max(0, plannedSeconds - savedSeconds)) }
  mutating func pause(at now: Date) {
    guard let start = runningSince else { return }
    let end = min(max(start, now), start.addingTimeInterval(max(0, plannedSeconds - savedSeconds)))
    segments.append(FocusSegment(start: start, end: end))
    runningSince = nil
  }
  mutating func resume(at now: Date) {
    if isPaused && savedSeconds < plannedSeconds { runningSince = now }
  }
  func finish(at now: Date) -> FocusSession {
    var copy = self
    copy.pause(at: now)
    return FocusSession(
      id: id, subject: subject, plannedSeconds: plannedSeconds,
      segments: copy.segments, finishedAt: copy.segments.last?.end ?? now,
      completed: copy.savedSeconds >= plannedSeconds - 0.5)
  }
}

enum CardKind: String, Codable, CaseIterable, Identifiable {
  case vocabulary, knowledge, cloze
  var id: String { rawValue }
  var title: String {
    switch self {
    case .vocabulary: return "Từ vựng"
    case .knowledge: return "Hỏi — đáp"
    case .cloze: return "Điền khuyết"
    }
  }
}

enum RecallRating: Int, Codable, CaseIterable, Identifiable {
  case again, hard, good, easy
  var id: Int { rawValue }
  var title: String { ["Quên", "Khó", "Nhớ", "Dễ"][rawValue] }
}

struct Flashcard: Identifiable, Codable, Equatable {
  var id = UUID()
  var deck = "Kiến thức"
  var kind: CardKind = .knowledge
  var front = ""
  var back = ""
  var example = ""
  var language = "en-US"
  var due = Date()
  var intervalDays = 0.0
  var ease = 2.5
  var repetitions = 0
  var lapses = 0
  var learningStep = 0
  var reviews = 0
  var suspended = false
  var createdAt = Date()
  var isNew: Bool { reviews == 0 }
  static let clozePattern = "(?s)\\{\\{(.+?)\\}\\}"
  var hasValidContent: Bool {
    !deck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && (kind == .cloze
        ? front.range(of: Self.clozePattern, options: .regularExpression) != nil
        : !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }
  var question: String {
    kind == .cloze
      ? front.replacingOccurrences(of: Self.clozePattern, with: "[…]", options: .regularExpression)
      : front
  }
  var answer: String {
    kind == .cloze
      ? front.replacingOccurrences(of: Self.clozePattern, with: "$1", options: .regularExpression)
      : back
  }
}

struct ReviewLog: Identifiable, Codable, Equatable {
  var id = UUID()
  var cardID: UUID
  var date: Date
  var rating: RecallRating
  var wasNew: Bool
  // Preserve what was actually reviewed, even after a card is edited/deleted.
  // Optional fields keep v1 backups readable.
  var deck: String? = nil
  var question: String? = nil
  var nextDue: Date? = nil
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
  case system, light, dark
  var id: String { rawValue }
  var title: String {
    switch self {
    case .system: return "Theo hệ thống"
    case .light: return "Sáng"
    case .dark: return "Tối"
    }
  }
}

struct Preferences: Codable, Equatable {
  var name = "Bạn"
  var dailyFocusMinutes = 60
  var newCardsPerDay = 15
  var focusMinutes = 25
  var breakMinutes = 5
  var hasOnboarded = false
  var appearance: AppAppearance = .system
  var haptics = true
  var liveActivities = true
  var dailyReviewGoal = 10

  init() {}
  enum CodingKeys: String, CodingKey {
    case name, dailyFocusMinutes, newCardsPerDay, focusMinutes, breakMinutes, hasOnboarded
    case appearance, haptics, liveActivities, dailyReviewGoal
  }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Bạn"
    dailyFocusMinutes = try c.decodeIfPresent(Int.self, forKey: .dailyFocusMinutes) ?? 60
    newCardsPerDay = try c.decodeIfPresent(Int.self, forKey: .newCardsPerDay) ?? 15
    focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25
    breakMinutes = try c.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 5
    hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? false
    appearance = try c.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
    haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
    liveActivities = try c.decodeIfPresent(Bool.self, forKey: .liveActivities) ?? true
    dailyReviewGoal = try c.decodeIfPresent(Int.self, forKey: .dailyReviewGoal) ?? 10
  }
}

struct StudyState: Codable, Equatable {
  var schemaVersion = 2
  var lessons: [Lesson] = []
  var tasks: [StudyTask] = []
  var notes: [QuickNote] = []
  var sessions: [FocusSession] = []
  var activeFocus: ActiveFocus? = nil
  var cards: [Flashcard] = []
  var reviews: [ReviewLog] = []
  var preferences = Preferences()
  var workspace: WorkspaceState? = nil
  var studio: WorkspaceState {
    get { workspace ?? WorkspaceState() }
    set { workspace = newValue }
  }
}
