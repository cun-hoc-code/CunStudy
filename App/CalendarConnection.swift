import Combine
import EventKit
import SwiftUI

@MainActor final class CalendarBridge: ObservableObject {
  private let events = EKEventStore()
  @Published var calendars: [EKCalendar] = []
  @Published var busy = false
  @Published var message = ""
  func connect() async {
    busy = true
    defer { busy = false }
    do {
      guard try await events.requestFullAccessToEvents() else {
        message = "Chưa có quyền Calendar. Có thể bật trong Cài đặt iPhone."
        return
      }
      calendars = events.calendars(for: .event).sorted { $0.title < $1.title }
      message = "Đã kết nối Calendar."
    } catch { message = error.localizedDescription }
  }
  func pull(into store: AppStore, selected: Set<String>) {
    guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
      message = "Hãy kết nối Calendar trước."
      return
    }
    let now = Date()
    let start = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    let end = Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
    let chosen = calendars.filter { selected.contains($0.calendarIdentifier) }
    guard !chosen.isEmpty else {
      message = "Chọn ít nhất một lịch."
      return
    }
    let values = events.events(
      matching: events.predicateForEvents(withStart: start, end: end, calendars: chosen))
    var seen = Set<String>()
    let records = values.filter { $0.url?.scheme != "mamstudy" }.compactMap {
      event -> CalendarRecord? in
      guard let id = event.eventIdentifier, let begin = event.startDate, let finish = event.endDate,
        finish >= begin
      else { return nil }
      let key = id + "-" + String(Int(begin.timeIntervalSince1970))
      guard seen.insert(key).inserted else { return nil }
      return CalendarRecord(
        id: key, title: event.title ?? "Calendar", calendar: event.calendar.title, start: begin,
        end: finish, location: event.location ?? "", isAllDay: event.isAllDay)
    }
    if store.editStudio({ $0.calendarRecords = records }) {
      message =
        "Đã nhập \(records.count) sự kiện, 30 ngày trước đến 90 ngày tới. Cập nhật: \(now.formatted(date:.omitted,time:.shortened))"
    }
  }
  func publish(_ state: StudyState, calendarID: String) {
    guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
      let target = calendars.first(where: {
        $0.calendarIdentifier == calendarID && $0.allowsContentModifications
      })
    else {
      message = "Chọn lịch cho phép ghi."
      return
    }
    let now = Date()
    let end = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    let existing = events.events(
      matching: events.predicateForEvents(
        withStart: now, end: end.addingTimeInterval(86400), calendars: [target]))
    struct Export {
      var key: String
      var title: String
      var start: Date
      var end: Date
      var location: String
      var lead: Int?
    }
    var items = ScheduleEngine.occurrences(state.lessons, from: now, days: 30).filter {
      $0.start >= now
    }.map {
      Export(
        key: "lesson-" + $0.id, title: $0.lesson.title, start: $0.start, end: $0.end,
        location: $0.lesson.location, lead: $0.lesson.reminder == .off ? nil : $0.lesson.leadMinutes
      )
    }
    items += state.studio.blocks.filter { $0.start >= now && $0.start < end && !$0.completed }.map {
      Export(
        key: "block-\($0.id)", title: $0.title, start: $0.start, end: $0.end, location: "",
        lead: $0.reminderMinutes)
    }
    items += state.tasks.filter { !$0.done && ($0.due.map { $0 >= now && $0 < end } ?? false) }.map
    {
      Export(
        key: "task-\($0.id)", title: $0.title, start: $0.due ?? now,
        end: ($0.due ?? now).addingTimeInterval(900), location: "",
        lead: $0.remind ? ($0.reminderLeadMinutes ?? 0) : nil)
    }
    do {
      for item in items {
        let marker = URL(string: "mamstudy://schedule/" + item.key)
        let event =
          existing.first { $0.url == URL(string: "mamstudy://schedule/" + item.key) }
          ?? EKEvent(eventStore: events)
        event.calendar = target
        event.title = item.title
        event.startDate = item.start
        event.endDate = item.end
        event.location = item.location
        event.url = marker
        event.alarms = item.lead.map { [EKAlarm(relativeOffset: -Double($0 * 60))] } ?? []
        try events.save(event, span: .thisEvent, commit: false)
      }
      try events.commit()
      message = "Đã gửi / cập nhật \(items.count) lịch."
    } catch {
      events.reset()
      message = error.localizedDescription
    }
  }
}
struct CalendarConnectionView: View {
  @EnvironmentObject private var store: AppStore
  @StateObject private var bridge = CalendarBridge()
  @State private var selected = Set<String>()
  @State private var target = ""
  @State private var confirm = false
  var body: some View {
    Form {
      Section {
        Text(
          "Apple Calendar và lịch Google đã thêm trong Cài đặt iPhone xuất hiện ở đây. Lịch đã nhập vẫn xem được khi offline."
        )
        Button("Kết nối Calendar") { Task { await bridge.connect() } }.disabled(bridge.busy)
        if bridge.busy { ProgressView() }
        Text(bridge.message).font(.footnote)
      }
      if !bridge.calendars.isEmpty {
        Section("Lịch muốn hiển thị trong Mầm") {
          ForEach(bridge.calendars, id: \.calendarIdentifier) { c in
            Toggle(
              c.title + " · " + c.source.title,
              isOn: Binding(
                get: { selected.contains(c.calendarIdentifier) },
                set: {
                  if $0 {
                    selected.insert(c.calendarIdentifier)
                  } else {
                    selected.remove(c.calendarIdentifier)
                  }
                }))
          }
          Button("Làm mới lịch đã chọn") { bridge.pull(into: store, selected: selected) }
        }
        Section("Gửi lịch từ Mầm") {
          Picker("Lịch đích", selection: $target) {
            Text("Chọn lịch").tag("")
            ForEach(bridge.calendars.filter(\.allowsContentModifications), id: \.calendarIdentifier)
            { Text($0.title + " · " + $0.source.title).tag($0.calendarIdentifier) }
          }
          Button("Gửi 30 ngày sắp tới") { confirm = true }.disabled(target.isEmpty)
          Text(
            "Gửi lại cập nhật các sự kiện do Mầm tạo. Xóa trong Mầm không tự xóa bên Calendar; các sự kiện cá nhân khác không bị sửa."
          ).font(.footnote)
        }
      }
      Section {
        Text(
          "Đồng bộ thủ công qua Calendar iOS. Chưa có Google OAuth riêng hoặc hợp nhất hai chiều chạy nền."
        ).font(.footnote)
      }
    }.navigationTitle("Apple / Google Calendar").confirmationDialog(
      "Gửi lịch của 30 ngày tới?", isPresented: $confirm, titleVisibility: .visible
    ) { Button("Gửi lịch") { bridge.publish(store.state, calendarID: target) } }
  }
}
