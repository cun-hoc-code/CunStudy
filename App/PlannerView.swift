import SwiftUI

struct PlannerView: View {
  @EnvironmentObject private var store: AppStore
  @State private var mode = 0
  @State private var area: StudyArea? = nil
  @State private var selectedDate = Date()
  @State private var search = ""
  @State private var showCompleted = false
  @State private var allSchedules = false
  @State private var lesson: Lesson?
  @State private var task: StudyTask?
  var body: some View {
    NavigationStack {
      PaperPage {
        NavigationLink {
          ScheduleStudio()
        } label: {
          Label("Lịch ngày / tuần / tháng & khung học", systemImage: "calendar.badge.clock")
        }
        Picker("Nội dung", selection: $mode) {
          Text("Lịch học").tag(0)
          Text("Việc cần làm").tag(1)
        }.pickerStyle(.segmented)
        Picker("Khu vực", selection: $area) {
          Text("Tất cả").tag(StudyArea?.none)
          ForEach(StudyArea.allCases) { Text($0.title).tag(Optional($0)) }
        }.pickerStyle(.segmented)
        if mode == 0 { scheduleContent } else { taskContent }
      }
      .navigationTitle("Kế hoạch")
      .searchable(text: $search, prompt: "Tìm môn, bài tập, địa điểm…")
      .toolbar {
        Button {
          if mode == 0 {
            var value = Lesson()
            value.area = area ?? .school
            lesson = value
          } else {
            var value = StudyTask()
            value.area = area ?? .school
            task = value
          }
        } label: {
          Image(systemName: "plus")
        }.accessibilityLabel("Thêm kế hoạch")
      }
      .sheet(item: $lesson) { LessonEditor(value: $0) }
      .sheet(item: $task) { TaskEditor(value: $0) }
    }
  }
  private var filteredLessons: [Lesson] {
    store.state.lessons.filter {
      (area == nil || $0.area == area)
        && (search.isEmpty
          || "\($0.title) \($0.subject) \($0.location)".localizedCaseInsensitiveContains(search))
    }
  }
  @ViewBuilder private var scheduleContent: some View {
    Toggle("Xem tất cả lịch đã tạo", isOn: $allSchedules).font(.subheadline)
    if allSchedules {
      ForEach(filteredLessons) { value in
        Button {
          lesson = value
        } label: {
          PaperCard(color: value.color) {
            VStack(alignment: .leading, spacing: 6) {
              Text(value.title).font(.headline)
              Text(
                value.weekly
                  ? value.weekdays.map(Pencil.weekday).joined(separator: ", ")
                  : value.date.formatted(.dateTime.day().month().year()))
              Text(
                "\(Pencil.time(value.startMinute)) • \(value.durationMinutes) phút"
                  + (value.enabled ? "" : " • Tạm tắt")
              ).font(.caption)
            }
          }
        }.buttonStyle(.plain)
      }
    } else {
      DatePicker("Ngày", selection: $selectedDate, displayedComponents: .date).datePickerStyle(
        .compact)
      let calendar = ScheduleEngine.calendar()
      let weekStart =
        calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
      HStack(spacing: 4) {
        ForEach(0..<7) { offset in
          let date = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? selectedDate
          let selected = calendar.isDate(date, inSameDayAs: selectedDate)
          Button {
            selectedDate = date
          } label: {
            VStack(spacing: 7) {
              Text(Pencil.weekday(calendar.component(.weekday, from: date))).font(.caption)
              Text("\(calendar.component(.day, from: date))").font(.body.bold())
            }.frame(maxWidth: .infinity).padding(.vertical, 12)
              .background(
                selected ? InkColor.sage.wash : Pencil.surface.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 12))
          }.buttonStyle(.plain)
        }
      }
      let events = ScheduleEngine.occurrences(filteredLessons, from: selectedDate, days: 1)
      if events.isEmpty {
        EmptyPageCard(
          symbol: "sun.max", title: "Chưa có lịch ngày này",
          detail: "Bấm + để dành một khoảng thời gian cho điều bạn muốn học.")
      }
      ForEach(events) { occurrence in
        VStack(alignment: .leading, spacing: 4) {
          Button {
            lesson = occurrence.lesson
          } label: {
            LessonRow(occurrence: occurrence)
          }.buttonStyle(.plain)
          if events.contains(where: {
            $0.id != occurrence.id && ScheduleEngine.overlaps($0, occurrence)
          }) {
            Label("Trùng giờ với một lịch khác", systemImage: "exclamationmark.triangle").font(
              .caption
            ).foregroundStyle(.orange)
          }
        }
      }
    }
  }
  @ViewBuilder private var taskContent: some View {
    Toggle("Hiện việc đã xong", isOn: $showCompleted)
    let items = store.state.tasks.filter {
      ($0.done == showCompleted) && (area == nil || $0.area == area)
        && (search.isEmpty
          || "\($0.title) \($0.subject) \($0.note)".localizedCaseInsensitiveContains(search))
    }.sorted {
      if $0.priority != $1.priority { return $0.priority.rawValue > $1.priority.rawValue }
      return ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)
    }
    Text("Ưu tiên cao trước, sau đó đến thời hạn gần nhất.").font(.caption).foregroundStyle(
      .secondary)
    if items.isEmpty {
      EmptyPageCard(
        symbol: "checkmark.circle", title: "Chưa có việc trong mục này",
        detail: "Thêm bài tập, việc cá nhân hoặc chia một mục tiêu lớn thành vài bước nhỏ.")
    }
    ForEach(items) { value in TaskCard(value: value, edit: { task = value }) }
  }
}
