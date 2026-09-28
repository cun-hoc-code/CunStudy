import SwiftUI
import WidgetKit

struct DeadlineWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: StudyWidgetEntry
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("DEADLINE", systemImage: "calendar.badge.exclamationmark").font(.caption.bold())
      if let snapshot = entry.snapshot {
        let items = (snapshot.deadlines ?? []).sorted { $0.due < $1.due }
        if items.isEmpty {
          Text("Chưa có hạn sắp tới").font(.headline)
          Text("Chạm để thêm lịch thi, bài tập hoặc học phí.").font(.caption)
        }
        ForEach(items.prefix(family == .systemSmall ? 1 : 3)) { item in
          VStack(alignment: .leading, spacing: 3) {
            HStack {
              if item.isExam { Image(systemName: "graduationcap") }
              Text(item.title).font(.headline).lineLimit(1)
            }
            HStack {
              Text(item.due, format: .dateTime.day().month().hour().minute())
              if item.due < entry.date { Text("Quá hạn").bold() }
            }.font(.caption).foregroundStyle(item.due < entry.date ? Color.red : Color.secondary)
          }
        }
      } else {
        Text("Mở Mầm để kết nối dữ liệu").font(.headline)
      }
      Spacer(minLength: 0)
    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).foregroundStyle(
      Color.adaptive(0x354033, 0xE4ECDE)
    ).containerBackground(for: .widget) { Color.adaptive(0xFAEDAD, 0x49432B) }.widgetURL(
      URL(string: "mamstudy://schedule"))
  }
}
struct MamDeadlinesWidget: Widget {
  let kind = "MamDeadlines"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) {
      DeadlineWidgetView(entry: $0)
    }.configurationDisplayName("Deadline").description("Lịch thi, hạn nộp bài và học phí sắp tới.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}
