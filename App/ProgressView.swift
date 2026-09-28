import Charts
import SwiftUI

struct StreakCard: View {
  let summary: ProgressSummary
  let open: () -> Void
  var body: some View {
    Button(action: open) {
      PaperCard(color: .peach) {
        HStack(spacing: 14) {
          Image(systemName: "flame.fill").font(.largeTitle).foregroundStyle(
            Color.adaptive(0xB95726, 0xFFB47E))
          VStack(alignment: .leading, spacing: 5) {
            Text("\(summary.currentStreak) ngày giữ nhịp").font(
              .system(.title2, design: .rounded, weight: .bold))
            Text(
              summary.today.qualifies
                ? "Hôm nay đã tưới mầm. Làm tốt lắm!" : "5 phút học hoặc 5 thẻ để tưới mầm hôm nay."
            )
            .font(.caption)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right").font(.caption.bold())
        }
      }
    }.buttonStyle(.plain).accessibilityHint("Mở thống kê và thành tích")
  }
}

struct DailyMissions: View {
  let summary: ProgressSummary
  let preferences: Preferences
  var body: some View {
    PaperCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text("Một chút mỗi ngày").font(.headline)
          Spacer()
          Chip(text: "+\(summary.today.xp) XP", color: .butter)
        }
        mission(
          "Tập trung", symbol: "leaf", value: Int(summary.today.minutes),
          goal: preferences.dailyFocusMinutes, unit: "phút")
        mission(
          "Ôn thẻ khác nhau", symbol: "rectangle.on.rectangle", value: summary.today.uniqueCards,
          goal: preferences.dailyReviewGoal, unit: "thẻ")
      }
    }
  }
  private func mission(_ title: String, symbol: String, value: Int, goal: Int, unit: String)
    -> some View
  {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Label(title, systemImage: value >= goal ? "checkmark.circle.fill" : symbol)
        Spacer()
        Text("\(value)/\(goal) \(unit)").monospacedDigit().foregroundStyle(.secondary)
      }.font(.subheadline)
      ProgressView(value: Double(min(value, goal)), total: Double(goal)).tint(Pencil.green)
        .accessibilityLabel(title).accessibilityValue("\(value) trên \(goal) \(unit)")
    }
  }
}

struct ProgressDashboard: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  @State private var range = 7
  @State private var metric = 0
  @State private var selectedDate: Date?
  @State private var heatmapDate: Date?
  var body: some View {
    NavigationStack {
      TimelineView(.periodic(from: .now, by: 60)) { context in
        dashboard(at: context.date)
      }
      .navigationTitle("Vườn & nhịp học").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
    }
  }
  private func dashboard(at now: Date) -> some View {
    let summary = StudyProgress.summary(store.state, at: now)
    let days = StudyProgress.recentDays(summary, count: range, at: now)
    let minutes = days.reduce(0) { $0 + $1.minutes }
    let reviews = days.reduce(0) { $0 + $1.reviewCount }
    let remembered = days.reduce(0) { $0 + $1.rememberedCount }
    let selected = selectedDate.flatMap { date in
      days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    return PaperPage {
      levelCard(summary)
      HStack(alignment: .top, spacing: 12) {
        MetricTile(
          value: "\(summary.currentStreak) ngày", title: "streak hiện tại", symbol: "flame",
          color: .peach)
        MetricTile(
          value: "\(summary.bestStreak) ngày", title: "chuỗi dài nhất", symbol: "trophy",
          color: .butter)
      }
      Text(
        summary.today.qualifies
          ? "Hôm nay đã giữ nhịp. Bạn có thể học thêm hoặc nghỉ ngơi."
          : "Streak tính khi có 5 phút tập trung đã lưu hoặc ôn 5 thẻ khác nhau trong ngày."
      )
      .font(.footnote).foregroundStyle(.secondary)
      DailyMissions(summary: summary, preferences: store.state.preferences)
      SectionTitle(
        title: "Nhìn lại nhịp học", caption: "Thời gian đã lưu và các lượt tự đánh giá khi ôn thẻ")
      Picker("Khoảng thời gian", selection: $range) {
        Text("7 ngày").tag(7)
        Text("30 ngày").tag(30)
        Text("90 ngày").tag(90)
      }.pickerStyle(.segmented)
        .onChange(of: range) { _, _ in selectedDate = nil }
      HStack(alignment: .top, spacing: 12) {
        MetricTile(
          value: Pencil.duration(minutes), title: "tập trung", symbol: "clock", color: .sage)
        MetricTile(
          value: "\(reviews) lượt", title: "ôn thẻ", symbol: "rectangle.on.rectangle",
          color: .lavender)
      }
      PaperCard {
        VStack(alignment: .leading, spacing: 14) {
          Picker("Chỉ số biểu đồ", selection: $metric) {
            Text("Phút tập trung").tag(0)
            Text("Lượt ôn").tag(1)
          }.pickerStyle(.segmented)
          Chart {
            ForEach(days) { day in
              BarMark(
                x: .value("Ngày", day.date, unit: .day),
                y: .value(
                  metric == 0 ? "Phút" : "Lượt ôn",
                  metric == 0 ? day.minutes : Double(day.reviewCount))
              )
              .foregroundStyle(Pencil.green.gradient).cornerRadius(4)
              .opacity(selected == nil || selected?.date == day.date ? 1 : 0.4)
            }
            if metric == 0 {
              RuleMark(y: .value("Mục tiêu", store.state.preferences.dailyFocusMinutes))
                .foregroundStyle(.orange.opacity(0.6)).lineStyle(StrokeStyle(dash: [4]))
            }
          }
          .frame(height: 190).chartXSelection(value: $selectedDate)
          .chartYAxisLabel(metric == 0 ? "phút" : "lượt")
          .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
              AxisGridLine()
              AxisValueLabel(format: .dateTime.day().month())
            }
          }
          if let selected {
            Text(
              "\(selected.date.formatted(.dateTime.day().month())): \(Int(selected.minutes)) phút • \(selected.reviewCount) lượt ôn"
            )
            .font(.subheadline).monospacedDigit()
          } else {
            Text("Chạm hoặc kéo trên biểu đồ để xem từng ngày.").font(.caption).foregroundStyle(
              .secondary)
          }
          if reviews > 0 {
            Label(
              "\(Int((Double(remembered) / Double(reviews) * 100).rounded()))% lượt tự đánh giá đã nhớ",
              systemImage: "brain.head.profile"
            ).font(.subheadline)
            Text("Tính các mức Khó, Nhớ và Dễ; không phải điểm kiểm tra khách quan.").font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      PaperCard(color: .butter) {
        Text(StudyStats.insight(store.state.sessions, at: now)).font(.subheadline)
      }
      subjects(from: days.first?.date ?? now, to: now)
      heatmap(summary, at: now)
      garden(summary)
      SectionTitle(title: "Những dấu mốc nhỏ", caption: "Tiến bộ được ghi nhận từ lịch sử của bạn")
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(StudyProgress.badges(summary)) { badge in
          PaperCard(color: badge.unlocked ? .butter : nil) {
            VStack(alignment: .leading, spacing: 8) {
              Image(systemName: badge.unlocked ? badge.symbol : "lock").font(.title2)
                .foregroundStyle(Pencil.green)
              Text(badge.title).font(.subheadline.bold())
              Text(badge.detail).font(.caption).foregroundStyle(.secondary)
              Text(badge.unlocked ? "Đã đạt" : "Đang vun trồng").font(.caption2)
            }.frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
          }
        }
      }
      NavigationLink {
        ReviewHistoryView()
      } label: {
        Label("Lịch sử ôn tập", systemImage: "clock.arrow.circlepath")
      }.buttonStyle(PencilButtonStyle(color: .lavender))
      NavigationLink {
        FocusHistoryView()
      } label: {
        Label("Nhật ký tập trung", systemImage: "list.bullet.rectangle")
      }.buttonStyle(PencilButtonStyle())
      Text(
        "XP: 2 điểm/phút (tối đa 120 phút/ngày) và 5 điểm/thẻ khác nhau (tối đa 100 thẻ/ngày). Mỗi 250 XP lên một cấp. Học vừa sức cũng đủ để tiến bộ."
      )
      .font(.caption).foregroundStyle(.secondary)
    }
  }
  private func levelCard(_ summary: ProgressSummary) -> some View {
    PaperCard(color: .sage) {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "leaf.fill").font(.largeTitle)
          VStack(alignment: .leading, spacing: 4) {
            Text(summary.levelTitle).font(.system(.title, design: .rounded, weight: .bold))
            Text("Cấp \(summary.level) • \(summary.xp) XP").font(.subheadline).monospacedDigit()
          }
          Spacer()
        }
        ProgressView(value: summary.levelProgress).tint(Pencil.green)
        Text("Còn \(250 - summary.xp % 250) XP đến cấp tiếp theo").font(.caption)
      }
    }
  }
  private func subjects(from start: Date, to end: Date) -> some View {
    let grouped = Dictionary(grouping: store.state.sessions, by: \.subject)
    let values = grouped.map {
      (name: $0.key, minutes: StudyStats.seconds($0.value, from: start, to: end) / 60)
    }
    .filter { $0.minutes > 0 }.sorted { $0.minutes > $1.minutes }
    let largest = values.first?.minutes ?? 1
    return PaperCard {
      VStack(alignment: .leading, spacing: 14) {
        Text("Theo môn trong \(range) ngày").font(.headline)
        if values.isEmpty {
          Text("Chưa có thời gian tập trung trong khoảng này.").font(.subheadline).foregroundStyle(
            .secondary)
        }
        ForEach(Array(values.enumerated()), id: \.offset) { entry in
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(entry.element.name)
              Spacer()
              Text(Pencil.duration(entry.element.minutes)).foregroundStyle(.secondary)
            }.font(.subheadline)
            ProgressView(value: entry.element.minutes, total: largest).tint(Pencil.green)
              .accessibilityLabel(entry.element.name).accessibilityValue(
                Pencil.duration(entry.element.minutes))
          }
        }
      }
    }
  }
  private func garden(_ summary: ProgressSummary) -> some View {
    let sessions = store.state.sessions.filter(\.completed).sorted { $0.finishedAt < $1.finishedAt }
      .suffix(35)
    return PaperCard(color: .sage) {
      VStack(alignment: .leading, spacing: 14) {
        Text("Vườn nhỏ của bạn").font(.headline)
        Text("\(summary.completedSessions) phiên hoàn thành • 35 mầm gần nhất").font(.caption)
        if sessions.isEmpty {
          Text("Hoàn thành phiên đầu tiên để trồng một mầm ở đây.").font(.subheadline)
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 14) {
          ForEach(sessions) { session in
            Image(systemName: "leaf.fill").font(.title2).foregroundStyle(Pencil.green)
              .accessibilityLabel(
                "\(session.subject), \(Int(session.seconds / 60)) phút, \(session.finishedAt.formatted(.dateTime.day().month()))"
              )
          }
        }
      }
    }
  }
  private func heatmap(_ summary: ProgressSummary, at now: Date) -> some View {
    let days = StudyProgress.recentDays(summary, count: 84, at: now)
    let selected = heatmapDate.flatMap { date in days.first { $0.date == date } }
    return PaperCard {
      VStack(alignment: .leading, spacing: 12) {
        Text("84 ngày vun trồng").font(.headline)
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHGrid(rows: Array(repeating: GridItem(.fixed(22), spacing: 4), count: 7), spacing: 4)
          {
            ForEach(days) { day in
              Button {
                heatmapDate = day.date
              } label: {
                RoundedRectangle(cornerRadius: 5)
                  .fill(
                    day.xp == 0
                      ? Pencil.ink.opacity(0.06)
                      : Pencil.green.opacity(
                        day.qualifies ? min(1, 0.45 + Double(day.xp) / 180) : 0.22)
                  )
                  .overlay(
                    RoundedRectangle(cornerRadius: 5).stroke(
                      heatmapDate == day.date ? Pencil.ink : .clear, lineWidth: 2)
                  )
                  .frame(width: 22, height: 22)
              }.buttonStyle(.plain)
                .accessibilityLabel(
                  "\(day.date.formatted(.dateTime.day().month())), \(Int(day.minutes)) phút, \(day.reviewCount) lượt ôn, \(day.qualifies ? "đạt streak" : "chưa đạt streak")"
                )
            }
          }.padding(2)
        }
        HStack {
          Text(days.first?.date.formatted(.dateTime.day().month()) ?? "")
          Spacer()
          Text("Hôm nay")
        }.font(.caption2).foregroundStyle(.secondary)
        Text(
          selected.map {
            "\($0.date.formatted(.dateTime.day().month())) • \(Int($0.minutes)) phút • \($0.reviewCount) lượt ôn"
          } ?? "Mỗi ô là một ngày, từ trên xuống dưới. Xanh đậm hơn = nhiều hoạt động hơn."
        )
        .font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}

private struct MetricTile: View {
  let value: String
  let title: String
  let symbol: String
  let color: InkColor
  var body: some View {
    PaperCard(color: color) {
      VStack(alignment: .leading, spacing: 6) {
        Image(systemName: symbol)
        Text(value).font(.system(.title3, design: .rounded, weight: .bold)).contentTransition(
          .numericText())
        Text(title).font(.caption)
      }
    }
  }
}

struct FocusHistoryView: View {
  @EnvironmentObject private var store: AppStore
  @State private var search = ""
  @State private var limit = 40
  var body: some View {
    let sessions = store.state.sessions.filter {
      search.isEmpty || $0.subject.localizedCaseInsensitiveContains(search)
    }.sorted { $0.finishedAt > $1.finishedAt }
    PaperPage {
      if sessions.isEmpty {
        EmptyPageCard(
          symbol: "leaf", title: "Chưa có phiên phù hợp",
          detail: "Thời gian tập trung được lưu khi bạn kết thúc hoặc hoàn thành phiên.")
      }
      ForEach(sessions.prefix(limit)) { session in
        PaperCard {
          HStack(alignment: .top) {
            Image(systemName: session.completed ? "checkmark.seal.fill" : "circle.lefthalf.filled")
              .foregroundStyle(Pencil.green)
            VStack(alignment: .leading, spacing: 6) {
              Text(session.subject).font(.headline)
              Text(session.finishedAt, format: .dateTime.day().month().year().hour().minute()).font(
                .caption
              ).foregroundStyle(.secondary)
              Text(
                "\(Pencil.duration(session.seconds / 60)) • \(session.completed ? "Hoàn thành" : "Kết thúc sớm")"
              ).font(.subheadline)
            }
          }
        }
      }
      if sessions.count > limit {
        Button("Xem thêm") { limit += 40 }.buttonStyle(PencilButtonStyle())
      }
    }.navigationTitle("Nhật ký tập trung").navigationBarTitleDisplayMode(.inline)
      .searchable(text: $search, prompt: "Tìm môn học…")
      .onChange(of: search) { _, _ in limit = 40 }
  }
}
