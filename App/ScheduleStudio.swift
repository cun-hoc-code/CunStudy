import SwiftUI

struct ScheduleStudio: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.mamReduceMotion) private var reduce
  @State private var selected = Date()
  @State private var mode = 1
  @State private var duration = 25
  @State private var block: TimeBlock?
  @State private var task: StudyTask?
  @State private var lesson: Lesson?
  private var calendar: Calendar { ScheduleEngine.calendar() }
  private var days: [Date] {
    guard mode == 1 else { return [calendar.startOfDay(for: selected)] }
    let start = calendar.dateInterval(of: .weekOfYear, for: selected)?.start ?? selected
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }
  var body: some View {
    PaperPage {
      Picker("Xem lịch", selection: $mode) {
        Text("Ngày").tag(0)
        Text("Tuần").tag(1)
        Text("Tháng").tag(2)
      }.pickerStyle(.segmented)
      HStack {
        Button {
          move(-1)
        } label: {
          Image(systemName: "chevron.left").padding(12)
        }.accessibilityLabel("Trước")
        DatePicker("Ngày", selection: $selected, displayedComponents: .date).labelsHidden().frame(
          maxWidth: .infinity)
        Button {
          move(1)
        } label: {
          Image(systemName: "chevron.right").padding(12)
        }.accessibilityLabel("Sau")
      }
      if mode == 2 { monthGrid }
      ForEach(days, id: \.self) { dayContent($0) }
      SectionTitle(
        title: "Tìm một khoảng yên",
        caption: "Dựa trên lịch, Calendar và khung học đã lưu, từ 7:00–22:00.")
      Picker("Thời lượng", selection: $duration) {
        ForEach([15, 25, 45, 60], id: \.self) { Text("\($0) phút").tag($0) }
      }.pickerStyle(.segmented)
      let slots = WorkspaceEngine.freeSlots(store.state, on: selected, minutes: duration)
      if slots.isEmpty {
        Text("Chưa có khoảng trống phù hợp ngày này.").foregroundStyle(.secondary)
      }
      ForEach(Array(slots.prefix(4).enumerated()), id: \.offset) { _, slot in
        Button {
          block = TimeBlock(
            title: "Tự học", start: slot.start,
            end: slot.start.addingTimeInterval(Double(duration * 60)))
        } label: {
          PaperCard(color: .sage) {
            HStack {
              Label(
                slot.start.formatted(.dateTime.hour().minute()) + " – "
                  + slot.end.formatted(.dateTime.hour().minute()), systemImage: "sparkles")
              Spacer()
              Text("Dành \(duration) phút").font(.caption.bold())
            }
          }
        }.buttonStyle(SoftPressStyle())
      }
      SectionTitle(title: "Đếm ngược & deadline")
      ForEach(
        store.state.tasks.filter { !$0.done && $0.due != nil }.sorted {
          ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)
        }
      ) { item in
        Button {
          task = item
        } label: {
          PaperCard(color: item.kind == .exam ? .lavender : .peach) {
            HStack {
              VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.headline)
                Text(item.subject).font(.caption)
                Text(item.due ?? Date(), style: .date).font(.caption)
              }
              Spacer()
              let count =
                calendar.dateComponents(
                  [.day], from: calendar.startOfDay(for: Date()),
                  to: calendar.startOfDay(for: item.due ?? Date())
                ).day ?? 0
              VStack {
                Text((item.due ?? .distantFuture) < Date() ? "!" : "\(count)").font(
                  .system(.largeTitle, design: .rounded, weight: .bold)
                ).contentTransition(.numericText())
                Text((item.due ?? .distantFuture) < Date() ? "Quá hạn" : "ngày").font(.caption)
              }
            }
          }
        }.buttonStyle(SoftPressStyle())
      }
    }.navigationTitle(store.t("Lịch & khung học", "Schedule & blocks")).toolbar {
      Menu {
        Button("Khung tự học", systemImage: "clock") { block = TimeBlock(title: "Tự học") }
        Button("Lịch học", systemImage: "calendar") { lesson = Lesson() }
        Button("Kỳ thi / deadline", systemImage: "flag") {
          var v = StudyTask()
          v.kind = .exam
          v.due = Date().addingTimeInterval(86400)
          task = v
        }
        NavigationLink("Apple / Google Calendar") { CalendarConnectionView() }
      } label: {
        Image(systemName: "plus")
      }
    }.sheet(item: $block) { BlockEditor(value: $0) }.sheet(item: $task) { TaskEditor(value: $0) }
      .sheet(item: $lesson) { LessonEditor(value: $0) }
  }
  private func move(_ offset: Int) {
    withAnimation(reduce ? nil : .snappy(duration: 0.3)) {
      selected =
        calendar.date(
          byAdding: mode == 2 ? .month : (mode == 1 ? .weekOfYear : .day), value: offset,
          to: selected) ?? selected
    }
  }
  private var monthGrid: some View {
    let start = calendar.dateInterval(of: .month, for: selected)?.start ?? selected
    let weekday = (calendar.component(.weekday, from: start) + 5) % 7
    let count = calendar.range(of: .day, in: .month, for: selected)?.count ?? 30
    return LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 5
    ) {
      ForEach(Pencil.weekdays, id: \.self) {
        Text(Pencil.weekday($0)).font(.caption).foregroundStyle(.secondary)
      }
      ForEach(0..<(weekday + count), id: \.self) { cell in
        if cell < weekday {
          Color.clear.frame(height: 46)
        } else {
          let day = calendar.date(byAdding: .day, value: cell - weekday, to: start) ?? selected
          let chosen = calendar.isDate(day, inSameDayAs: selected)
          Button {
            withAnimation(reduce ? nil : .spring(response: 0.32, dampingFraction: 0.75)) {
              selected = day
            }
          } label: {
            VStack(spacing: 4) {
              Text("\(cell-weekday+1)").font(.subheadline.bold())
              Circle().fill(hasEvents(day) ? Pencil.green : .clear).frame(width: 4, height: 4)
            }.frame(maxWidth: .infinity, minHeight: 46).background(
              chosen ? InkColor.sage.wash : Pencil.surface, in: RoundedRectangle(cornerRadius: 12))
          }.buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted))
            .accessibilityAddTraits(chosen ? .isSelected : [])
        }
      }
    }
  }
  private func overlaps(_ event: CalendarRecord, day: Date) -> Bool {
    let begin = calendar.startOfDay(for: day)
    let end = calendar.date(byAdding: .day, value: 1, to: begin) ?? begin
    return event.start < end && event.end > begin
  }
  private func hasEvents(_ day: Date) -> Bool {
    !ScheduleEngine.occurrences(store.state.lessons, from: day, days: 1).isEmpty
      || store.state.studio.calendarRecords.contains { overlaps($0, day: day) }
      || store.state.studio.blocks.contains { calendar.isDate($0.start, inSameDayAs: day) }
      || store.state.tasks.contains {
        $0.due.map { calendar.isDate($0, inSameDayAs: day) } ?? false
      }
  }
  @ViewBuilder private func dayContent(_ day: Date) -> some View {
    SectionTitle(title: day.formatted(.dateTime.weekday(.wide).day().month()))
    ForEach(ScheduleEngine.occurrences(store.state.lessons, from: day, days: 1)) { occurrence in
      Button {
        lesson = occurrence.lesson
      } label: {
        LessonRow(occurrence: occurrence)
      }.buttonStyle(.plain)
    }
    ForEach(
      store.state.studio.blocks.filter { calendar.isDate($0.start, inSameDayAs: day) }.sorted {
        $0.start < $1.start
      }
    ) { item in
      Button {
        block = item
      } label: {
        PaperCard(color: .sky) {
          HStack {
            Image(systemName: item.completed ? "checkmark.circle.fill" : "clock")
            VStack(alignment: .leading, spacing: 5) {
              Text(item.title).font(.headline)
              Text(
                item.start.formatted(.dateTime.hour().minute()) + " – "
                  + item.end.formatted(.dateTime.hour().minute())
              ).font(.caption)
            }
            Spacer()
            Text(item.subject).font(.caption)
          }
        }
      }.buttonStyle(SoftPressStyle())
    }
    ForEach(
      store.state.studio.calendarRecords.filter { overlaps($0, day: day) }.sorted {
        $0.start < $1.start
      }
    ) { item in
      PaperCard {
        VStack(alignment: .leading, spacing: 4) {
          Label(item.title, systemImage: "calendar.badge.clock").font(.headline)
          Text(
            item.calendar + " · "
              + (item.isAllDay
                ? store.t("Cả ngày", "All day") : item.start.formatted(.dateTime.hour().minute()))
          ).font(
            .caption)
          if !item.location.isEmpty { Text(item.location).font(.caption) }
        }
      }
    }
    ForEach(
      store.state.tasks.filter {
        !$0.done && ($0.due.map { calendar.isDate($0, inSameDayAs: day) } ?? false)
      }
    ) { v in TaskCard(value: v, edit: { task = v }) }
  }
}
struct BlockEditor: View {
  @EnvironmentObject private var store: AppStore
  @State var value: TimeBlock
  var body: some View {
    StudioEditor(
      title: "Khung tự học", canSave: !value.title.trimmed.isEmpty && value.end > value.start,
      save: { store.saveBlock(value) },
      delete: { store.editStudio { $0.blocks.removeAll { $0.id == value.id } } }
    ) {
      TextField("Tên khung học", text: $value.title)
      TextField("Môn học", text: $value.subject)
      DatePicker("Bắt đầu", selection: $value.start)
      DatePicker("Kết thúc", selection: $value.end)
      Toggle("Đã hoàn thành", isOn: $value.completed)
      Toggle(
        "Nhắc trước khi học",
        isOn: Binding(
          get: { value.reminderMinutes != nil }, set: { value.reminderMinutes = $0 ? 10 : nil }))
      if value.reminderMinutes != nil {
        Stepper(
          "Trước \(value.reminderMinutes ?? 0) phút",
          value: Binding(get: { value.reminderMinutes ?? 0 }, set: { value.reminderMinutes = $0 }),
          in: 0...1440, step: 5)
      }
    }
  }
}
