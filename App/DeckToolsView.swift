import SwiftUI
import UniformTypeIdentifiers

struct DeckToolsView: View {
  @EnvironmentObject private var store: AppStore
  @State private var deck = ""
  @State private var hard = false
  @State private var importing = false
  @State private var pending: [Flashcard] = []
  @State private var preview = false
  @State private var share = false
  @State private var shareURL: URL?
  @State private var quick = false
  @State private var busy = false
  private var cards: [Flashcard] {
    store.state.cards.filter {
      (deck.isEmpty || $0.deck == deck) && (!hard || $0.lapses > 0 || $0.ease < 2)
    }
  }
  var body: some View {
    PaperPage {
      SectionTitle(
        title: "Vườn kiến thức", caption: "Ôn nhanh, chăm lại thẻ khó và mang bộ thẻ theo bạn.")
      Picker("Bộ thẻ", selection: $deck) {
        Text("Tất cả").tag("")
        ForEach(Array(Set(store.state.cards.map(\.deck))).sorted(), id: \.self) { Text($0).tag($0) }
      }
      Toggle("Chỉ thẻ khó / từng quên", isOn: $hard)
      HStack {
        Chip(text: "\(cards.count) thẻ")
        Spacer()
        Button("Ôn nhanh 10 thẻ", systemImage: "bolt.fill") { quick = true }.disabled(
          cards.filter { !$0.suspended }.isEmpty)
      }
      PaperCard(color: .sky) {
        VStack(alignment: .leading, spacing: 12) {
          Button("Nhập CSV / Anki APKG", systemImage: "square.and.arrow.down") { importing = true }
          Button("Xuất CSV", systemImage: "square.and.arrow.up") { export(anki: false) }.disabled(
            cards.isEmpty)
          Button("Xuất Anki APKG", systemImage: "square.and.arrow.up") { export(anki: true) }
            .disabled(cards.isEmpty)
          Text(
            "APKG: nhập nội dung từ bản xuất ‘Support older Anki versions’. Không nhập media, lịch ôn hay template; xuất cloze thành câu hỏi và đáp án thường. CSV giữ nguyên cloze."
          ).font(.caption).foregroundStyle(.secondary)
        }
      }
      if busy { ProgressView("Đang chuẩn bị bộ thẻ…") }
      ForEach(cards.prefix(100)) { card in
        PaperCard(color: card.lapses > 0 ? .peach : .sage) {
          VStack(alignment: .leading, spacing: 6) {
            Text(card.question).font(.headline)
            Text(card.answer).font(.subheadline)
            Text("\(card.lapses) lần quên • \(card.reviews) lần ôn").font(.caption).foregroundStyle(
              .secondary)
          }
        }
      }
      if cards.count > 100 {
        Text("Hiển thị 100 thẻ đầu. Xuất và ôn áp dụng toàn bộ bộ thẻ đã chọn.").font(.caption)
      }
    }.navigationTitle("Công cụ flashcard")
      .sheet(isPresented: $importing) {
        LocalFilePicker(
          types: [.commaSeparatedText, UTType(filenameExtension: "apkg") ?? .data, .data]
        ) { response in
          importing = false
          switch response {
          case .success(let url): if let url { importDeck(url) }
          case .failure(let error): store.errorMessage = error.localizedDescription
          }
        }
      }
      .sheet(isPresented: $preview) { DeckImportPreview(cards: pending) }
      .sheet(isPresented: $share) { if let shareURL { ShareSheet(url: shareURL) } }
      .sheet(isPresented: $quick) {
        QuickReview(
          cards: Array(cards.filter { !$0.suspended }.sorted { $0.due < $1.due }.prefix(10)))
      }
  }
  private func importDeck(_ url: URL) {
    busy = true
    Task {
      defer { busy = false; ImportSource.discard(url) }
      do {
        let values = try await Task.detached(priority: .userInitiated) { () -> [Flashcard] in
          if url.pathExtension.lowercased() == "apkg" { return try AnkiDeck.read(url) }
          guard
            (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max)
              <= 10 * 1024 * 1024
          else { throw StudyError.invalid("CSV tối đa 10 MB.") }
          return try DeckCSV.decode(TextFileDecoder.decode(Data(contentsOf: url)))
        }.value
        pending = values.filter(\.hasValidContent)
        preview = true
      } catch { store.errorMessage = error.localizedDescription }
    }
  }
  private func export(anki: Bool) {
    do {
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "MamStudy-" + UUID().uuidString + (anki ? ".apkg" : ".csv"))
      if anki {
        try AnkiDeck.write(cards, to: url)
      } else {
        try DeckCSV.encode(cards).write(to: url, atomically: true, encoding: .utf8)
      }
      shareURL = url
      share = true
    } catch { store.errorMessage = error.localizedDescription }
  }
}
struct DeckImportPreview: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  let cards: [Flashcard]
  private var additions: [Flashcard] {
    var seen = Set(
      store.state.cards.map {
        [$0.deck, $0.front, $0.back, $0.kind.rawValue].joined(separator: "\u{1f}")
      })
    return cards.filter {
      seen.insert([$0.deck, $0.front, $0.back, $0.kind.rawValue].joined(separator: "\u{1f}"))
        .inserted
    }
  }
  var body: some View {
    NavigationStack {
      List {
        Section {
          Text("\(cards.count) thẻ đọc được • \(additions.count) thẻ mới")
          Text("Thẻ trùng nội dung được bỏ qua. Các thẻ mới bắt đầu lịch ôn mới.").font(.caption)
        }
        ForEach(additions.prefix(40)) { c in
          VStack(alignment: .leading) {
            Text(c.front).bold()
            Text(c.back).foregroundStyle(.secondary)
          }
        }
      }.navigationTitle("Xem trước bộ thẻ").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Nhập") {
            if store.change({ $0.cards.append(contentsOf: additions) }) { dismiss() }
          }.disabled(additions.isEmpty)
        }
      }
    }
  }
}
struct CardDraftReview: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  let text: String
  let deck: String
  @State private var cards: [Flashcard] = []
  @State private var selected = Set<UUID>()
  @State private var edit: Flashcard?
  var body: some View {
    NavigationStack {
      List {
        Section {
          Text(
            "Mầm tách dòng ‘thuật ngữ: định nghĩa’ và {{chỗ trống}} ngay trên máy. Kiểm tra, sửa rồi chọn các thẻ muốn lưu."
          ).font(.subheadline)
          if cards.isEmpty {
            Text(
              "Chưa thấy dòng phù hợp. Thêm dấu : giữa câu hỏi và đáp án trong ghi chú rồi thử lại."
            )
          }
        }
        ForEach(cards) { c in
          HStack {
            Button {
              if selected.contains(c.id) { selected.remove(c.id) } else { selected.insert(c.id) }
            } label: {
              Image(systemName: selected.contains(c.id) ? "checkmark.circle.fill" : "circle")
            }.buttonStyle(.plain).accessibilityLabel("Chọn thẻ")
            Button {
              edit = c
            } label: {
              VStack(alignment: .leading) {
                Text(c.question).bold()
                Text(c.answer).foregroundStyle(.secondary)
              }
            }.buttonStyle(.plain)
          }
        }
      }.navigationTitle("Bản nháp flashcard").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Lưu \(selected.count)") {
            if store.change({
              $0.cards.append(contentsOf: cards.filter { selected.contains($0.id) })
            }) {
              dismiss()
            }
          }.disabled(selected.isEmpty)
        }
      }.onAppear {
        if cards.isEmpty {
          cards = Array(WorkspaceEngine.cardDrafts(from: text, deck: deck).prefix(500))
          selected = Set(cards.map(\.id))
        }
      }.sheet(item: $edit) { card in
        DraftCardEditor(value: card) { updated in
          if let i = cards.firstIndex(where: { $0.id == updated.id }) { cards[i] = updated }
        }
      }
    }
  }
}
struct DraftCardEditor: View {
  @State var value: Flashcard
  let saved: (Flashcard) -> Void
  var body: some View {
    StudioEditor(
      title: "Sửa thẻ nháp", canSave: value.hasValidContent,
      save: {
        saved(value)
        return true
      }
    ) {
      TextField("Bộ thẻ", text: $value.deck)
      TextField("Câu hỏi", text: $value.front, axis: .vertical).lineLimit(3...12)
      TextField("Đáp án", text: $value.back, axis: .vertical).lineLimit(3...12)
      TextField("Giải thích", text: $value.example, axis: .vertical)
      Picker("Loại", selection: $value.kind) {
        ForEach(CardKind.allCases) { Text($0.title).tag($0) }
      }
    }
  }
}
struct QuickReview: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduce
  let cards: [Flashcard]
  @State private var index = 0
  @State private var revealed = false
  @State private var burst = 0
  var body: some View {
    NavigationStack {
      PaperPage {
        if index < cards.count {
          let card = cards[index]
          ProgressView(value: Double(index), total: Double(max(1, cards.count)))
          Text("\(index+1) / \(cards.count)").font(.caption).monospacedDigit()
          Button {
            withAnimation(reduce ? nil : .spring(response: 0.5, dampingFraction: 0.8)) {
              revealed.toggle()
            }
            StudyHaptics.flip(enabled: store.state.preferences.haptics)
          } label: {
            PaperCard(color: revealed ? .sage : .butter) {
              VStack(spacing: 20) {
                Text(revealed ? card.answer : card.question).font(.title2).frame(
                  maxWidth: .infinity, minHeight: 210)
                Text(revealed ? "Chạm để xem câu hỏi" : "Chạm để lật thẻ").font(.caption)
              }
            }.rotation3DEffect(.degrees(revealed ? 0 : 5), axis: (x: 0, y: 1, z: 0))
          }.buttonStyle(SoftPressStyle())
          if revealed {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
              ForEach(RecallRating.allCases) { rating in
                Button(LocalizedStringKey(rating.title)) {
                  if store.review(card, rating: rating) {
                    index += 1
                    revealed = false
                    if index == cards.count { burst += 1 }
                  }
                }.buttonStyle(PencilButtonStyle())
              }
            }
          }
        } else {
          Sprout()
          Text("Đã chăm thêm một góc vườn!").font(.title2.bold())
          Text("\(cards.count) thẻ đã được ghi vào lịch sử ôn tập.")
          Button("Xong") { dismiss() }.buttonStyle(PencilButtonStyle())
        }
      }.overlay { if burst > 0 { LeafCelebration().id(burst) } }.navigationTitle("Ôn nhanh").toolbar
      { Button("Đóng") { dismiss() } }
    }
  }
}
