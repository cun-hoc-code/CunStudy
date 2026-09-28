import SwiftUI

struct ReviewHistoryView: View {
  @EnvironmentObject private var store: AppStore
  @State private var range = 30
  @State private var deck: String?
  @State private var rating: RecallRating?
  @State private var search = ""
  @State private var limit = 50
  private var cardIndex: [UUID: Flashcard] {
    Dictionary(uniqueKeysWithValues: store.state.cards.map { ($0.id, $0) })
  }
  private var decks: [String] {
    let cards = cardIndex
    return Set(store.state.reviews.map { $0.deck ?? cards[$0.cardID]?.deck ?? "Bộ thẻ cũ" })
      .sorted()
  }
  private var filtered: [ReviewLog] {
    let now = Date()
    let start =
      range == 0
      ? Date.distantPast
      : Calendar.current.date(
        byAdding: .day, value: 1 - range, to: Calendar.current.startOfDay(for: now)) ?? now
    let cards = cardIndex
    return store.state.reviews.filter { log in
      let name = log.deck ?? cards[log.cardID]?.deck ?? "Bộ thẻ cũ"
      let question = log.question ?? cards[log.cardID]?.question ?? "Thẻ đã xóa"
      return log.date >= start && log.date <= now && (deck == nil || deck == name)
        && (rating == nil || rating == log.rating)
        && (search.isEmpty || "\(name) \(question)".localizedCaseInsensitiveContains(search))
    }.sorted { $0.date > $1.date }
  }
  var body: some View {
    let logs = filtered
    let visible = Array(logs.prefix(limit))
    let grouped = Dictionary(grouping: visible) { Calendar.current.startOfDay(for: $0.date) }
    let cards = cardIndex
    PaperPage {
      Picker("Thời gian", selection: $range) {
        Text("7 ngày").tag(7)
        Text("30 ngày").tag(30)
        Text("Tất cả").tag(0)
      }.pickerStyle(.segmented)
      HStack {
        Picker("Bộ thẻ", selection: $deck) {
          Text("Mọi bộ thẻ").tag(String?.none)
          ForEach(decks, id: \.self) { Text($0).tag(Optional($0)) }
        }
        Spacer(minLength: 0)
        Picker("Mức nhớ", selection: $rating) {
          Text("Mọi mức nhớ").tag(RecallRating?.none)
          ForEach(RecallRating.allCases) { Text($0.title).tag(Optional($0)) }
        }
      }.font(.subheadline)
      PaperCard(color: .lavender) {
        VStack(alignment: .leading, spacing: 6) {
          Text("\(logs.count) lượt ôn").font(.system(.title2, design: .rounded, weight: .bold))
          Text(
            "\(Set(logs.map(\.cardID)).count) thẻ khác nhau • \(logs.filter { $0.rating == .again }.count) lượt cần nhớ lại"
          ).font(.subheadline)
        }
      }
      if logs.isEmpty {
        EmptyPageCard(
          symbol: "clock.arrow.circlepath", title: "Chưa có lượt ôn phù hợp",
          detail:
            "Mỗi lần bạn tự chấm thẻ, Mầm ghi lại thời gian và mức nhớ ở đây. Thử thay bộ lọc nếu bạn đã ôn."
        )
      }
      ForEach(grouped.keys.sorted(by: >), id: \.self) { day in
        SectionTitle(title: day.formatted(.dateTime.weekday(.wide).day().month().year()))
        ForEach(grouped[day] ?? []) { log in historyRow(log, card: cards[log.cardID]) }
      }
      if logs.count > limit {
        Button("Xem thêm \(min(50, logs.count - limit)) lượt") { limit += 50 }.buttonStyle(
          PencilButtonStyle())
      }
      if logs.contains(where: { $0.question == nil }) {
        Text(
          "Lượt ôn từ bản 1.0 chỉ lưu thời gian và mức nhớ. Nội dung cũ được lấy từ thẻ hiện tại nếu còn; Mầm không tự dựng lại thẻ đã xóa."
        ).font(.caption).foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Lịch sử ôn tập").navigationBarTitleDisplayMode(.inline)
    .searchable(text: $search, prompt: "Tìm từ, câu hỏi hoặc bộ thẻ…")
    .onChange(of: search) { _, _ in limit = 50 }
    .onChange(of: range) { _, _ in limit = 50 }
    .onChange(of: deck) { _, _ in limit = 50 }
    .onChange(of: rating) { _, _ in limit = 50 }
  }
  private func historyRow(_ log: ReviewLog, card: Flashcard?) -> some View {
    return PaperCard {
      VStack(alignment: .leading, spacing: 9) {
        HStack {
          Chip(text: log.deck ?? card?.deck ?? "Bộ thẻ cũ", color: .lavender)
          Spacer()
          Text(log.date, style: .time).font(.caption).foregroundStyle(.secondary)
        }
        Text(log.question ?? card?.question ?? "Thẻ đã xóa • chưa có bản chụp nội dung").font(
          .subheadline.weight(.medium)
        ).lineLimit(4)
        HStack {
          Chip(text: log.rating.title, color: [.rose, .peach, .sage, .sky][log.rating.rawValue])
          if log.wasNew { Text("Lần đầu").font(.caption).foregroundStyle(.secondary) }
        }
        if let due = log.nextDue {
          Text("Lịch được đặt: \(due.formatted(.dateTime.day().month().hour().minute()))").font(
            .caption
          ).foregroundStyle(.secondary)
        }
      }
    }
  }
}

struct FlashcardFace: AnimatableModifier {
  var angle: Double
  var animatableData: Double {
    get { angle }
    set { angle = newValue }
  }
  func body(content: Content) -> some View {
    content.opacity(abs(angle) < 90 ? 1 : 0)
      .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
  }
}
