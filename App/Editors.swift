import SwiftUI

struct LessonEditor: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  @State var value: Lesson
  @State private var deleting = false
  private var existing: Bool { store.state.lessons.contains { $0.id == value.id } }
  private var valid: Bool {
    !value.title.trimmed.isEmpty && (!value.weekly || !value.weekdays.isEmpty)
  }
  private var timeBinding: Binding<Date> {
    Binding(
      get: {
        Calendar.current.date(
          bySettingHour: value.startMinute / 60, minute: value.startMinute % 60, second: 0,
          of: Date()) ?? Date()
      },
      set: {
        value.startMinute =
          Calendar.current.component(.hour, from: $0) * 60
          + Calendar.current.component(.minute, from: $0)
      })
  }
  var body: some View {
    NavigationStack {
      Form {
        Section("Buổi học") {
          TextField("Tên buổi học", text: $value.title)
          TextField("Môn học", text: $value.subject)
          Picker("Mục", selection: $value.area) {
            ForEach(StudyArea.allCases) { Text($0.title).tag($0) }
          }
          TextField(value.area == .school ? "Phòng / cơ sở" : "Địa điểm học", text: $value.location)
          if value.area == .school { TextField("Giảng viên", text: $value.teacher) }
        }
        Section("Khi nào?") {
          Toggle("Lặp hằng tuần", isOn: $value.weekly)
          if value.weekly {
            HStack {
              ForEach(Pencil.weekdays, id: \.self) { day in
                Button {
                  if value.weekdays.contains(day) {
                    value.weekdays.removeAll { $0 == day }
                  } else {
                    value.weekdays.append(day)
                  }
                } label: {
                  Text(Pencil.weekday(day)).font(.caption.bold()).frame(
                    maxWidth: .infinity, minHeight: 40
                  )
                  .background(
                    value.weekdays.contains(day) ? InkColor.sage.wash : Color.gray.opacity(0.1),
                    in: Capsule())
                }.buttonStyle(.plain).accessibilityLabel(
                  "\(Pencil.weekday(day)), \(value.weekdays.contains(day) ? "đã chọn" : "chưa chọn")"
                )
              }
            }
          } else {
            DatePicker("Ngày", selection: $value.date, displayedComponents: .date)
          }
          DatePicker("Bắt đầu", selection: timeBinding, displayedComponents: .hourAndMinute)
          Stepper(
            "Thời lượng: \(value.durationMinutes) phút", value: $value.durationMinutes,
            in: 15...720, step: 15)
          Text(
            "Kết thúc lúc \(Pencil.time(value.startMinute + value.durationMinutes))\(value.startMinute + value.durationMinutes >= 1440 ? " ngày hôm sau" : "")"
          ).font(.caption)
          Toggle("Đang áp dụng", isOn: $value.enabled)
        }
        Section {
          Picker("Nhắc học", selection: $value.reminder) {
            ForEach(ReminderMode.allCases) { Text($0.title).tag($0) }
          }
          if value.reminder != .off {
            Stepper(
              "Chuẩn bị + di chuyển: \(value.leadMinutes) phút", value: $value.leadMinutes,
              in: 0...1440, step: 5)
            let shift = ScheduleEngine.shifted(
              weekday: 2, minute: value.startMinute, lead: value.leadMinutes)
            Text(
              "Nhắc lúc \(Pencil.time(shift.minute))\(shift.weekday != 2 ? " ngày hôm trước" : "")"
            ).font(.headline)
          }
        } header: {
          Text("Đi học đúng giờ")
        } footer: {
          Text(
            value.reminder == .alarm
              ? "Báo thức cần iOS 26+ và quyền Báo thức. Vào Cài đặt của Mầm để bật quyền và thử khi khóa máy. Lịch hằng tuần tiếp tục lặp cho đến khi bạn tắt hoặc xóa."
              : "Thông báo phát khi app đóng nếu đã được cấp quyền; âm thanh chịu ảnh hưởng bởi chế độ im lặng và Tập trung."
          )
        }
        Section("Màu bút") { ColorPickerRow(selection: $value.color) }
        Section("Ghi nhớ") {
          TextField("Mang tài liệu, chuẩn bị bài…", text: $value.notes, axis: .vertical).lineLimit(
            3...6)
        }
        if existing { Section { Button("Xóa lịch này", role: .destructive) { deleting = true } } }
      }
      .navigationTitle(existing ? "Sửa lịch" : "Thêm lịch").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Lưu") {
            value.title = value.title.trimmed
            value.subject = value.subject.trimmed
            if store.saveLesson(value) { dismiss() }
          }.disabled(!valid)
        }
      }
      .confirmationDialog(
        "Xóa lịch và báo thức của lịch này?", isPresented: $deleting, titleVisibility: .visible
      ) {
        Button("Xóa lịch", role: .destructive) {
          if store.change({ $0.lessons.removeAll { $0.id == value.id } }) { dismiss() }
        }
      }
    }
  }
}

struct TaskEditor: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  @State var value: StudyTask
  @State private var stepTitle = ""
  @State private var deleting = false
  private var existing: Bool { store.state.tasks.contains { $0.id == value.id } }
  var body: some View {
    NavigationStack {
      Form {
        Section("Việc cần làm") {
          TextField("Tên việc", text: $value.title)
          Picker(
            "Loại", selection: Binding(get: { value.kind ?? .assignment }, set: { value.kind = $0 })
          ) { ForEach(TaskKind.allCases) { Text(LocalizedStringKey($0.title)).tag($0) } }
          TextField("Môn học / nhóm", text: $value.subject)
          Picker("Mục", selection: $value.area) {
            ForEach(StudyArea.allCases) { Text($0.title).tag($0) }
          }
          Picker("Ưu tiên", selection: $value.priority) {
            ForEach(Priority.allCases) { Text($0.title).tag($0) }
          }
        }
        Section("Hạn hoàn thành") {
          Toggle(
            "Có thời hạn",
            isOn: Binding(
              get: { value.due != nil },
              set: {
                value.due = $0 ? Date().addingTimeInterval(3600) : nil
                if !$0 { value.remind = false }
              }))
          if value.due != nil {
            DatePicker(
              "Thời hạn", selection: Binding(get: { value.due ?? Date() }, set: { value.due = $0 }))
            Toggle("Nhắc deadline", isOn: $value.remind)
            if value.remind {
              Picker(
                "Nhắc trước",
                selection: Binding(
                  get: { value.reminderLeadMinutes ?? 0 }, set: { value.reminderLeadMinutes = $0 })
              ) {
                Text("Đúng hạn").tag(0)
                Text("1 giờ").tag(60)
                Text("3 giờ").tag(180)
                Text("1 ngày").tag(1440)
                Text("3 ngày").tag(4320)
              }
            }
          }
        }
        Section("Từng bước nhỏ") {
          ForEach($value.subtasks) { $step in Toggle(step.title, isOn: $step.done) }
            .onDelete { value.subtasks.remove(atOffsets: $0) }
          HStack {
            TextField("Thêm một bước", text: $stepTitle)
            Button {
              value.subtasks.append(.init(title: stepTitle.trimmed))
              stepTitle = ""
            } label: {
              Image(systemName: "plus.circle.fill")
            }
            .disabled(stepTitle.trimmed.isEmpty).accessibilityLabel("Thêm bước")
          }
        }
        Section {
          TextField("Ghi chú", text: $value.note, axis: .vertical).lineLimit(3...7)
          Toggle("Đã hoàn thành", isOn: $value.done)
        }
        if existing { Section { Button("Xóa việc này", role: .destructive) { deleting = true } } }
      }
      .navigationTitle(existing ? "Sửa công việc" : "Thêm công việc").navigationBarTitleDisplayMode(
        .inline
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Lưu") {
            value.title = value.title.trimmed
            value.completedAt = value.done ? (value.completedAt ?? Date()) : nil
            if store.saveTask(value) { dismiss() }
          }.disabled(value.title.trimmed.isEmpty)
        }
      }
      .confirmationDialog("Xóa công việc này?", isPresented: $deleting, titleVisibility: .visible) {
        Button("Xóa", role: .destructive) {
          if store.change({ $0.tasks.removeAll { $0.id == value.id } }) { dismiss() }
        }
      }
    }
  }
}
