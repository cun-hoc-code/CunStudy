import SwiftUI
import WidgetKit

struct StudyWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot?
}

struct StudyWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> StudyWidgetEntry {
    var lesson = Lesson()
    lesson.title = "Lịch học của bạn"
    lesson.location = "Mở Mầm để thêm lịch"
    return .init(
      date: Date(),
      snapshot: .init(
        updatedAt: Date(), lessons: [lesson], pendingTasks: 3, dueCards: 5, todayFocusMinutes: 25,
        goalMinutes: 60))
  }
  func getSnapshot(in context: Context, completion: @escaping (StudyWidgetEntry) -> Void) {
    completion(
      context.isPreview
        ? placeholder(in: context) : .init(date: Date(), snapshot: WidgetStorage.load()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<StudyWidgetEntry>) -> Void)
  {
    let now = Date()
    let snapshot = WidgetStorage.load()
    let events = ScheduleEngine.occurrences(snapshot?.lessons ?? [], from: now, days: 2)
    let tomorrow = Calendar.current.startOfDay(
      for: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
    )
    let boundaries =
      (events.flatMap { [$0.leaveAt, $0.start, $0.end] } + (snapshot?.deadlines ?? []).map(\.due))
      .filter { $0 > now && $0 < tomorrow }
    let dates = [now] + Array(Set(boundaries)).sorted() + [tomorrow]
    // Time changes are encoded in advance; this is not a background timer.
    let entries = dates.map { StudyWidgetEntry(date: $0, snapshot: snapshot) }
    completion(Timeline(entries: entries, policy: .after(tomorrow)))
  }
}

struct ScheduleWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: StudyWidgetEntry
  private let ink = Color.adaptive(0x354033, 0xE4ECDE)
  var body: some View {
    Group {
      if let snapshot = entry.snapshot {
        if let next = ScheduleEngine.next(snapshot.lessons, at: entry.date) {
          if family == .accessoryRectangular {
            VStack(alignment: .leading) {
              Text(next.lesson.title).font(.headline).lineLimit(1)
              Text(next.start, format: .dateTime.hour().minute())
              Text(next.lesson.location.isEmpty ? next.lesson.area.title : next.lesson.location)
                .lineLimit(1)
            }
          } else {
            VStack(alignment: .leading, spacing: 9) {
              Label(
                "MẦM • \(next.start <= entry.date ? "ĐANG HỌC" : "TIẾP THEO")", systemImage: "leaf"
              ).font(.caption2.bold())
              Text(next.lesson.title).font(.system(.headline, design: .rounded)).lineLimit(2)
              Text(next.start, format: .dateTime.weekday(.abbreviated).hour().minute()).font(
                .subheadline)
              if !next.lesson.location.isEmpty {
                Text(next.lesson.location).font(.caption).lineLimit(1)
              }
              if family == .systemMedium && next.start > entry.date {
                HStack {
                  Text("Bắt đầu sau")
                  Text(next.start, style: .timer).monospacedDigit()
                }.font(.caption)
              }
              if family == .systemLarge {
                Divider()
                ForEach(
                  ScheduleEngine.occurrences(snapshot.lessons, from: entry.date, days: 1).filter {
                    $0.start > next.start
                  }.prefix(3)
                ) { event in
                  HStack {
                    Text(event.start, style: .time)
                    Text(event.lesson.title).lineLimit(1)
                  }.font(.caption)
                }
              }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          }
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Label("Mầm", systemImage: "leaf").font(.headline)
            Text("Chưa có lịch sắp tới")
            Text("Chạm để thêm một buổi học").font(.caption)
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 7) {
          Label("Mầm", systemImage: "leaf").font(.headline)
          Text("Mở app để kết nối lịch").font(.subheadline)
          if family != .accessoryRectangular {
            Text("Nếu vẫn trống, kiểm tra App Groups của bản ký.").font(.caption)
          }
        }
      }
    }
    .foregroundStyle(family == .accessoryRectangular ? Color.primary : ink)
    .containerBackground(for: .widget) { Color.adaptive(0xF7F5E6, 0x202A23) }
    .widgetURL(URL(string: "mamstudy://schedule"))
  }
}

struct RhythmWidgetView: View {
  let entry: StudyWidgetEntry
  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label("NHỊP HỌC", systemImage: "leaf").font(.caption.bold())
      if let snapshot = entry.snapshot {
        let sameDay = Calendar.current.isDate(snapshot.updatedAt, inSameDayAs: entry.date)
        let focus = sameDay ? snapshot.todayFocusMinutes : 0
        Text("\(focus) phút").font(.system(.title2, design: .rounded, weight: .bold))
        ProgressView(
          value: Double(min(focus, snapshot.goalMinutes)),
          total: Double(max(1, snapshot.goalMinutes))
        ).tint(.green)
        Text("Mục tiêu \(snapshot.goalMinutes) phút").font(.caption)
        if let last = snapshot.lastStudyDay {
          let distance =
            Calendar.current.dateComponents(
              [.day], from: Calendar.current.startOfDay(for: last),
              to: Calendar.current.startOfDay(for: entry.date)
            ).day ?? 2
          let streak = (0...1).contains(distance) ? snapshot.currentStreak ?? 0 : 0
          Label("\(streak) ngày giữ nhịp", systemImage: "flame.fill").font(.caption.bold())
        }
        if sameDay {
          Text("\(snapshot.dueCards) thẻ • \(snapshot.pendingTasks) việc").font(.caption)
        } else {
          Text("Mở Mầm để cập nhật thẻ ôn").font(.caption)
        }
      } else {
        Text("Mở Mầm để bắt đầu").font(.subheadline)
      }
    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .foregroundStyle(Color.adaptive(0x354033, 0xE4ECDE))
      .containerBackground(for: .widget) { Color.adaptive(0xD4E6C4, 0x304431) }
      .widgetURL(URL(string: "mamstudy://focus"))
  }
}

struct MamScheduleWidget: Widget {
  let kind = "MamSchedule"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) {
      ScheduleWidgetView(entry: $0)
    }
    .configurationDisplayName("Lịch tiếp theo").description(
      "Lịch ở trường và tự học, ngay trên màn hình chính."
    )
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
  }
}
struct MamRhythmWidget: Widget {
  let kind = "MamRhythm"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) { RhythmWidgetView(entry: $0) }
      .configurationDisplayName("Nhịp học").description("Phút tập trung, thẻ ôn và việc đang chờ.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}
@main
struct MamWidgetBundle: WidgetBundle {
  var body: some Widget {
    MamScheduleWidget()
    MamRhythmWidget()
    MamDeadlinesWidget()
    FocusLiveActivity()
  }
}
