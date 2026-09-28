import SwiftUI

struct TodayView: View {
  @EnvironmentObject private var store: AppStore
  @EnvironmentObject private var reminders: ReminderService
  @State private var settings = false
  @State private var progress = false
  @State private var lesson: Lesson?
  @State private var task: StudyTask?
  @State private var note: QuickNote?
  var body: some View {
    NavigationStack {
      TimelineView(.periodic(from: .now, by: 30)) { timeline in
        content(at: timeline.date)
      }
      .navigationTitle("Mầm").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            settings = true
          } label: {
            Image(systemName: "gearshape")
          }.accessibilityLabel("Cài đặt")
        }
        ToolbarItem(placement: .topBarLeading) {
          Menu {
            Button("Thêm lịch học", systemImage: "calendar.badge.plus") { lesson = Lesson() }
            Button("Thêm việc cần làm", systemImage: "checklist") { task = StudyTask() }
            Button("Ghi nhanh", systemImage: "square.and.pencil") { note = QuickNote() }
          } label: {
            Image(systemName: "plus.circle")
          }.accessibilityLabel("Thêm nhanh")
        }
      }
      .sheet(isPresented: $settings) { SettingsView() }
      .sheet(isPresented: $progress) { ProgressDashboard() }
      .sheet(item: $lesson) { LessonEditor(value: $0) }
      .sheet(item: $task) { TaskEditor(value: $0) }
      .sheet(item: $note) { NoteEditor(value: $0) }
    }
  }
  private func content(at now: Date) -> some View {
    let today = ScheduleEngine.occurrences(store.state.lessons, from: now, days: 1)
    let pending = store.state.tasks.filter { !$0.done }.sorted {
      ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)
    }
    let focus = StudyStats.daily(store.state.sessions, ending: now, days: 1).first?.minutes ?? 0
    let due = ReviewEngine.queue(store.state, at: now).count
    let summary = StudyProgress.summary(store.state, at: now)
    return PaperPage {
      VStack(alignment: .leading, spacing: 6) {
        Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.footnote)
          .foregroundStyle(.secondary)
        Text("Chào \(store.state.preferences.name),").font(
          .system(.largeTitle, design: .rounded, weight: .bold))
        Text("Hôm nay mình học gì?").font(.title3)
      }
      NavigationLink {
        StudyHubView()
      } label: {
        PaperCard(color: .sage) {
          HStack {
            Image(systemName: "square.grid.2x2.fill").font(.title2)
            VStack(alignment: .leading, spacing: 4) {
              Text(store.t("Góc học tập", "Study studio")).font(.headline)
              Text(
                store.t(
                  "Tài liệu · Luyện đề · Điểm số · Nhật ký", "Library · Practice · Grades · Journal"
                )
              ).font(.caption)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
          }
        }
      }.buttonStyle(SoftPressStyle())
      NavigationLink {
        BookshelfView()
      } label: {
        PaperCard(color: .butter) {
          HStack {
            Image(systemName: "book.pages.fill").font(.title2)
            VStack(alignment: .leading, spacing: 4) {
              Text("Đọc tiếp").font(.headline)
              Text("Kệ sách · lật trang như sách giấy").font(.caption)
            }
            Spacer()
            Image(systemName: "chevron.right")
          }
        }
      }.buttonStyle(SoftPressStyle())
      StreakCard(summary: summary) { progress = true }
      DailyMissions(summary: summary, preferences: store.state.preferences)
      if let active = store.state.activeFocus {
        Button {
          store.tab = 2
        } label: {
          PaperCard(color: .sage) {
            HStack {
              Label(
                active.isPaused ? "Phiên đang tạm dừng" : "Mầm đang lớn", systemImage: "leaf.fill")
              Spacer()
              Image(systemName: "arrow.right")
            }.font(.subheadline.bold())
          }
        }.buttonStyle(.plain)
      } else if store.completedFocus != nil {
        Button {
          store.tab = 2
        } label: {
          PaperCard(color: .butter) {
            Label("Bạn có một mầm mới. Xem phiên vừa hoàn thành", systemImage: "checkmark.seal")
          }
        }.buttonStyle(.plain)
      }
      if !reminders.problems.isEmpty {
        Button {
          settings = true
        } label: {
          PaperCard(color: .peach) {
            Label("Kiểm tra nhắc học: \(reminders.problems[0])", systemImage: "bell.badge")
          }
        }.buttonStyle(.plain)
      }
      if let next = ScheduleEngine.next(store.state.lessons, at: now) {
        Button {
          lesson = next.lesson
        } label: {
          PaperCard(color: next.lesson.color) {
            VStack(alignment: .leading, spacing: 10) {
              Label(
                next.start <= now ? "ĐANG DIỄN RA" : "LỊCH TIẾP THEO",
                systemImage: next.lesson.area.symbol
              ).font(.caption.bold())
              Text(next.lesson.title).font(.system(.title2, design: .rounded, weight: .bold))
              Text(
                next.start, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
              if !next.lesson.location.isEmpty {
                Label(next.lesson.location, systemImage: "mappin")
              }
              if next.lesson.reminder != .off && next.start > now {
                Label(
                  "Chuẩn bị lúc \(next.leaveAt.formatted(.dateTime.hour().minute()))",
                  systemImage: "bell")
              }
            }
          }
        }.buttonStyle(.plain)
      } else {
        EmptyPageCard(
          symbol: "calendar", title: "Một trang lịch còn trống",
          detail: "Bấm + để thêm lịch ở trường hoặc một buổi tự học.")
      }
      HStack(alignment: .top, spacing: 12) {
        Button {
          store.tab = 2
        } label: {
          PaperCard(color: .sage) {
            VStack(alignment: .leading, spacing: 6) {
              Image(systemName: "leaf")
              Text("\(Int(focus)) phút").font(.title2.bold())
              Text("tập trung hôm nay").font(.caption)
            }
          }
        }.buttonStyle(.plain)
        Button {
          store.tab = 3
        } label: {
          PaperCard(color: .lavender) {
            VStack(alignment: .leading, spacing: 6) {
              Image(systemName: "rectangle.on.rectangle")
              Text("\(due) thẻ").font(.title2.bold())
              Text("sẵn sàng để ôn").font(.caption)
            }
          }
        }.buttonStyle(.plain)
      }
      SectionTitle(title: "Dòng thời gian", caption: "\(today.count) lịch trong ngày")
      ForEach(today) { occurrence in
        Button {
          lesson = occurrence.lesson
        } label: {
          LessonRow(occurrence: occurrence)
        }.buttonStyle(.plain)
      }
      SectionTitle(title: "Việc cần làm", caption: "\(pending.count) việc chưa hoàn thành")
      if pending.isEmpty {
        Text("Không còn việc đang chờ. Bạn có thể dành một chút thời gian nghỉ ngơi.").font(
          .subheadline
        ).foregroundStyle(.secondary)
      }
      ForEach(pending.prefix(4)) { value in TaskCard(value: value, edit: { task = value }) }
      if let pinned = store.state.notes.filter(\.pinned).sorted(by: { $0.updatedAt > $1.updatedAt })
        .first
      {
        Button {
          note = pinned
        } label: {
          PaperCard(color: pinned.color) {
            VStack(alignment: .leading, spacing: 8) {
              Label(pinned.title, systemImage: "pin").font(.headline)
              Text(pinned.body).lineLimit(4)
            }
          }
        }.buttonStyle(.plain)
      }
    }
  }
}

struct LessonRow: View {
  let occurrence: LessonOccurrence
  var body: some View {
    PaperCard {
      HStack(alignment: .top, spacing: 12) {
        VStack(spacing: 4) {
          Text(occurrence.start, style: .time).font(.subheadline.bold())
          Text(occurrence.end, style: .time).font(.caption).foregroundStyle(.secondary)
        }.frame(minWidth: 54)
        RoundedRectangle(cornerRadius: 3).fill(occurrence.lesson.color.wash).frame(
          width: 5, height: 46)
        VStack(alignment: .leading, spacing: 5) {
          Text(occurrence.lesson.title).font(.headline)
          Label(
            occurrence.lesson.area.title
              + (occurrence.lesson.location.isEmpty ? "" : " • " + occurrence.lesson.location),
            systemImage: occurrence.lesson.area.symbol
          ).font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
        if occurrence.lesson.reminder != .off {
          Image(systemName: occurrence.lesson.reminder == .alarm ? "alarm" : "bell").font(.caption)
        }
      }
    }
  }
}

struct TaskCard: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject private var store: AppStore
  let value: StudyTask
  let edit: () -> Void
  var body: some View {
    PaperCard {
      HStack(alignment: .top, spacing: 10) {
        Button {
          withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.75)) {
            store.toggleTask(value.id)
          }
        } label: {
          Image(systemName: value.done ? "checkmark.circle.fill" : "circle").contentTransition(
            .symbolEffect(.replace)
          ).symbolEffect(.bounce, value: reduceMotion ? false : value.done).font(.title2).frame(
            width: 44, height: 44)
        }.buttonStyle(.plain).accessibilityLabel(value.done ? "Đánh dấu chưa làm" : "Hoàn thành")
        Button(action: edit) {
          VStack(alignment: .leading, spacing: 5) {
            Text(value.title).font(.headline).strikethrough(value.done)
            Text([value.area.title, value.subject].filter { !$0.isEmpty }.joined(separator: " • "))
              .font(.caption).foregroundStyle(.secondary)
            if let due = value.due {
              Text(due, format: .dateTime.day().month().hour().minute())
                .font(.caption).foregroundStyle(
                  due < Date() && !value.done ? Color.red : Color.secondary)
            }
            if !value.subtasks.isEmpty {
              Text("\(value.subtasks.filter(\.done).count)/\(value.subtasks.count) bước nhỏ").font(
                .caption)
            }
          }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain)
        if value.priority == .high {
          Image(systemName: "flag.fill").foregroundStyle(.orange).accessibilityLabel("Ưu tiên cao")
        }
      }
    }
  }
}
