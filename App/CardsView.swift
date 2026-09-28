import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class CardSpeech: ObservableObject {
  private let synthesizer = AVSpeechSynthesizer()
  func say(_ text: String, language: String) {
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: language)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
    synthesizer.speak(utterance)
  }
  func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

struct CardsView: View {
  @EnvironmentObject private var store: AppStore
  @State private var deck: String? = nil
  @State private var search = ""
  @State private var draft: Flashcard?
  @State private var importing = false
  @State private var importDeck = "Thẻ nhập"
  @State private var showImport = false
  @State private var message: String?
  @State private var sourceImport = false
  var body: some View {
    NavigationStack {
      TimelineView(.periodic(from: .now, by: 30)) { context in
        PaperPage {
          NavigationLink {
            DeckToolsView()
          } label: {
            Label("Ôn nhanh, thẻ khó & nhập/xuất bộ thẻ", systemImage: "rectangle.stack.badge.plus")
          }
          Picker("Bộ thẻ", selection: $deck) {
            Text("Tất cả bộ thẻ").tag(String?.none)
            ForEach(Set(store.state.cards.map(\.deck)).sorted(), id: \.self) {
              Text($0).tag(Optional($0))
            }
          }
          let queue = ReviewEngine.queue(store.state, deck: deck, at: context.date)
          PaperCard(color: .lavender) {
            VStack(alignment: .leading, spacing: 10) {
              Text("Nhớ từng chút một.").font(.system(.title2, design: .rounded, weight: .bold))
              Text(
                "\(queue.count) thẻ sẵn sàng • tối đa \(store.state.preferences.newCardsPerDay) thẻ mới / ngày"
              ).font(.subheadline)
              NavigationLink {
                ReviewSessionView(deck: deck)
              } label: {
                Label("Bắt đầu ôn", systemImage: "play.fill")
              }
              .buttonStyle(PencilButtonStyle(color: .butter)).disabled(queue.isEmpty)
            }
          }
          Text(
            "Nghĩ câu trả lời trước khi lật thẻ. Thẻ quên được ôn lại sớm; thẻ nhớ tốt được giãn lịch."
          ).font(.subheadline).foregroundStyle(.secondary)
          let reviews = store.state.reviews.filter { Calendar.current.isDateInToday($0.date) }
          if !reviews.isEmpty {
            Text(
              "Hôm nay: \(reviews.count) lượt ôn • \(reviews.filter { $0.rating != .again }.count) lượt tự đánh giá đã nhớ"
            ).font(.caption)
          }
          NavigationLink {
            ReviewHistoryView()
          } label: {
            Label("Xem lịch sử ôn tập", systemImage: "clock.arrow.circlepath")
          }.buttonStyle(PencilButtonStyle(color: .sky))
          let cards = store.state.cards.filter {
            (deck == nil || $0.deck == deck)
              && (search.isEmpty
                || "\($0.front) \($0.back) \($0.deck)".localizedCaseInsensitiveContains(search))
          }.sorted { $0.createdAt > $1.createdAt }
          if cards.isEmpty {
            EmptyPageCard(
              symbol: "rectangle.on.rectangle", title: "Bộ nhớ bắt đầu từ một thẻ",
              detail:
                "Thêm từ vựng, câu hỏi kiến thức hoặc câu điền khuyết. Mỗi thẻ nên chứa một ý nhỏ.")
          }
          ForEach(cards) { card in
            Button {
              draft = card
            } label: {
              PaperCard {
                VStack(alignment: .leading, spacing: 6) {
                  HStack {
                    Chip(text: card.deck, color: .lavender)
                    Spacer()
                    Text(card.kind.title).font(.caption).foregroundStyle(.secondary)
                  }
                  Text(card.question).font(.headline).lineLimit(3)
                  Text(
                    card.suspended
                      ? "Đã tạm ngưng"
                      : card.isNew
                        ? "Thẻ mới"
                        : "Ôn lại: \(card.due.formatted(.dateTime.day().month().hour().minute()))"
                  )
                  .font(.caption).foregroundStyle(.secondary)
                }
              }
            }.buttonStyle(.plain)
          }
        }
      }
      .navigationTitle("Ôn thẻ")
      .searchable(text: $search, prompt: "Tìm từ hoặc kiến thức…")
      .toolbar {
        Menu {
          Button("Thêm thẻ", systemImage: "plus") {
            var card = Flashcard()
            card.deck = deck ?? "Kiến thức"
            draft = card
          }
          Button("Nhập file TSV", systemImage: "square.and.arrow.down") { showImport = true }
          Button("Tạo thẻ từ ảnh / tài liệu", systemImage: "doc.viewfinder") {
            sourceImport = true
          }
        } label: {
          Image(systemName: "plus")
        }.accessibilityLabel("Thêm thẻ hoặc nhập bộ thẻ")
      }
      .sheet(item: $draft) { CardEditor(value: $0) }
      .sheet(isPresented: $sourceImport) { ImportCenter() }
      .alert("Nhập bộ thẻ TSV", isPresented: $showImport) {
        TextField("Tên bộ thẻ", text: $importDeck)
        Button("Chọn file") { importing = true }
        Button("Hủy", role: .cancel) {}
      } message: {
        Text(
          "Mỗi dòng: câu hỏi, phím Tab, đáp án, tùy chọn thêm Tab và ví dụ. Không hỗ trợ file .apkg."
        )
      }
      .sheet(isPresented: $importing) {
        LocalFilePicker(types: [.tabSeparatedText, .plainText]) { response in
          importing = false
          switch response {
          case .success(let selected):
            guard let url = selected else { return }
            defer { ImportSource.discard(url) }
            do {
              let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
              guard size <= 5 * 1024 * 1024 else {
                throw StudyError.invalid("File tối đa 5 MB.")
              }
              let cards = try ReviewEngine.importTSV(
                TextFileDecoder.decode(Data(contentsOf: url)),
                deck: importDeck.trimmed.isEmpty ? "Thẻ nhập" : importDeck.trimmed)
              if store.change({ $0.cards.append(contentsOf: cards) }) {
                message = "Đã nhập \(cards.count) thẻ."
              }
            } catch { message = error.localizedDescription }
          case .failure(let error): message = error.localizedDescription
          }
        }
      }
      .alert(
        "Nhập thẻ", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
      ) {
        Button("OK") { message = nil }
      } message: {
        Text(message ?? "")
      }
    }
  }
}

private struct ReviewSessionView: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.mamReduceMotion) private var reduceMotion
  @FocusState private var typing: Bool
  @StateObject private var speech = CardSpeech()
  let deck: String?
  @State private var revealed = false
  @State private var typed = ""
  @State private var completed = 0
  @State private var currentCardID: UUID?
  @State private var hasStarted = false
  var body: some View {
    TimelineView(.periodic(from: .now, by: 10)) { context in
      PaperPage {
        if let card = store.state.cards.first(where: { $0.id == currentCardID && !$0.suspended }) {
          HStack {
            Chip(text: card.deck, color: .lavender)
            Spacer()
            Text("Đã ôn \(completed)").font(.caption)
          }
          ZStack {
            PaperCard(color: .butter) {
              VStack(alignment: .leading, spacing: 18) {
                Text(card.kind.title.uppercased()).font(.caption.bold())
                Text(card.question).font(.system(.title2, design: .rounded, weight: .semibold))
                  .textSelection(.enabled)
                if card.kind == .vocabulary {
                  Button {
                    speech.say(card.front, language: card.language)
                  } label: {
                    Label("Nghe phát âm", systemImage: "speaker.wave.2")
                  }.font(.subheadline)
                }
                TextField("Thử gõ đáp án (không bắt buộc)", text: $typed, axis: .vertical)
                  .lineLimit(2...4)
                  .textInputAutocapitalization(.never).autocorrectionDisabled().focused($typing)
              }.frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            }
            .modifier(FlashcardFace(angle: revealed ? 180 : 0))
            .accessibilityHidden(revealed).allowsHitTesting(!revealed)
            PaperCard(color: .sage) {
              VStack(alignment: .leading, spacing: 18) {
                Label("ĐÁP ÁN", systemImage: "sparkle").font(.caption.bold())
                Text(card.answer).font(.title3).textSelection(.enabled)
                if !card.example.isEmpty {
                  Text(card.example).font(.body).foregroundStyle(.secondary)
                }
                if !typed.trimmed.isEmpty {
                  Text("Bạn đã trả lời: \(typed)").font(.footnote).foregroundStyle(.secondary)
                }
                if card.kind == .vocabulary {
                  Button {
                    speech.say(card.front, language: card.language)
                  } label: {
                    Label("Nghe lại phát âm", systemImage: "speaker.wave.2")
                  }.font(.subheadline)
                }
              }.frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            }
            .modifier(FlashcardFace(angle: revealed ? 0 : -180))
            .accessibilityHidden(!revealed).allowsHitTesting(revealed)
          }
          if revealed {
            Text("Bạn nhớ đến mức nào?").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
              ForEach(RecallRating.allCases) { rating in
                Button {
                  if store.review(card, rating: rating) {
                    completed += 1
                    showNextCard()
                  }
                } label: {
                  VStack(spacing: 3) {
                    Text(rating.title)
                    Text(ReviewEngine.intervalLabel(card, rating: rating, at: context.date)).font(
                      .caption)
                  }
                }.buttonStyle(
                  PencilButtonStyle(color: [.rose, .peach, .sage, .sky][rating.rawValue]))
              }
            }
            Text("Quên = chưa nhớ. Khó = nhớ đúng nhưng chậm. Nhớ = trả lời đúng. Dễ = nhớ ngay.")
              .font(.caption).foregroundStyle(.secondary)
          } else {
            Button("Lật thẻ xem đáp án") {
              typing = false
              StudyHaptics.flip(enabled: store.state.preferences.haptics)
              withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.42)) { revealed = true }
            }.buttonStyle(PencilButtonStyle())
            Text("Thử nhớ lại bằng lời của mình trước khi xem.").font(.footnote).foregroundStyle(
              .secondary)
          }
        } else {
          Sprout()
          if completed > 0 {
            Text("Bạn vừa ôn \(completed) lượt. Thêm một chút kiến thức cho hôm nay!")
              .font(.system(.title3, design: .rounded, weight: .semibold)).multilineTextAlignment(
                .center)
          }
          EmptyPageCard(
            symbol: "checkmark.seal", title: "Đã ôn hết thẻ sẵn sàng",
            detail:
              "Bạn có thể nghỉ. Những thẻ đang học sẽ trở lại khi đến hạn; không cần ép mình ôn thêm liên tục."
          )
          if let next = store.state.cards.filter({
            !$0.suspended && !$0.isNew && $0.due > context.date && (deck == nil || $0.deck == deck)
          }).min(by: { $0.due < $1.due }) {
            Text("Lượt tiếp theo: \(next.due.formatted(.dateTime.day().month().hour().minute()))")
              .font(.footnote)
          }
        }
        if store.reviewUndoAvailable {
          Button("Hoàn tác lần chấm vừa rồi") {
            if let id = store.undoReview() {
              currentCardID = id
              revealed = false
              typed = ""
              speech.stop()
              completed = max(0, completed - 1)
            }
          }.font(.subheadline)
        }
      }
      .onChange(of: context.date) { _, _ in
        // Keep the question stable while the user is answering it.
        if currentCardID == nil { showNextCard() }
      }
    }
    .navigationTitle("Một thẻ, một ý").navigationBarTitleDisplayMode(.inline)
    .onAppear {
      if !hasStarted {
        store.clearReviewUndo()
        showNextCard()
        hasStarted = true
      }
    }
    .onDisappear { speech.stop() }
    .onChange(of: currentCardID) { old, new in
      if old != nil && new == nil && completed > 0 {
        StudyHaptics.success(enabled: store.state.preferences.haptics)
      }
    }
  }
  private func showNextCard() {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) { revealed = false }
    typed = ""
    typing = false
    speech.stop()
    currentCardID = ReviewEngine.queue(store.state, deck: deck, at: Date()).first?.id
  }
}

private struct CardEditor: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  @State var value: Flashcard
  @State private var deleting = false
  private var existing: Bool { store.state.cards.contains { $0.id == value.id } }
  private var valid: Bool { value.hasValidContent }
  var body: some View {
    NavigationStack {
      Form {
        Section("Bộ thẻ") {
          TextField("Tên bộ thẻ / môn học", text: $value.deck)
          Picker("Loại thẻ", selection: $value.kind) {
            ForEach(CardKind.allCases) { Text($0.title).tag($0) }
          }
        }
        Section {
          TextField(
            value.kind == .cloze ? "Ví dụ: C++ hỗ trợ {{đa hình}}." : "Câu hỏi / từ vựng",
            text: $value.front, axis: .vertical
          ).lineLimit(3...8)
          if value.kind != .cloze {
            TextField("Đáp án / nghĩa của từ", text: $value.back, axis: .vertical).lineLimit(3...8)
          }
          TextField("Ví dụ hoặc giải thích ngắn", text: $value.example, axis: .vertical).lineLimit(
            2...5)
        } header: {
          Text("Nội dung")
        } footer: {
          Text(
            value.kind == .cloze
              ? "Đặt phần cần nhớ trong {{hai dấu ngoặc nhọn}}. Mầm sẽ che tất cả phần đó khi hỏi."
              : "Mỗi thẻ nên hỏi một ý rõ ràng. Thêm ví dụ riêng giúp kiến thức có ngữ cảnh.")
        }
        if value.kind == .vocabulary {
          Picker("Giọng đọc", selection: $value.language) {
            Text("Anh — Mỹ").tag("en-US")
            Text("Anh — Anh").tag("en-GB")
            Text("Tiếng Việt").tag("vi-VN")
            Text("Tiếng Trung").tag("zh-CN")
          }
        }
        Toggle("Tạm ngưng ôn thẻ", isOn: $value.suspended)
        if existing {
          Text("Đã ôn \(value.reviews) lượt • \(value.lapses) lần quên sau khi tốt nghiệp").font(
            .caption)
          Button("Xóa thẻ này", role: .destructive) { deleting = true }
        }
      }
      .navigationTitle(existing ? "Sửa thẻ" : "Thêm thẻ").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Lưu") {
            value.deck = value.deck.trimmed
            value.front = value.front.trimmed
            value.back = value.back.trimmed
            if store.saveCard(value) { dismiss() }
          }.disabled(!valid)
        }
      }
      .confirmationDialog("Xóa thẻ này?", isPresented: $deleting, titleVisibility: .visible) {
        Button("Xóa", role: .destructive) {
          if store.change({ $0.cards.removeAll { $0.id == value.id } }) { dismiss() }
        }
      }
    }
  }
}
