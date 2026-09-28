import PDFKit
import SwiftUI

struct BookshelfView: View {
  @EnvironmentObject private var store: AppStore
  @State private var importing = false
  @State private var choosing = false
  @State private var opened: BookRecord?
  @State private var removing: BookRecord?

  private var books: [BookRecord] {
    store.state.studio.readingRoom.books.sorted { $0.lastOpened > $1.lastOpened }
  }

  var body: some View {
    PaperPage {
      PaperCard(color: .butter) {
        HStack(spacing: 16) {
          Image(systemName: "books.vertical.fill").font(.system(size: 34)).foregroundStyle(
            Pencil.green)
          VStack(alignment: .leading, spacing: 5) {
            Text("Phòng đọc của Mầm").font(.system(.title2, design: .serif, weight: .bold))
            Text("Sách chữ được chia trang lại; PDF có thể giữ nguyên từng trang.")
              .font(.subheadline).foregroundStyle(.secondary)
          }
        }
      }

      HStack {
        Button {
          importing = true
        } label: {
          Label("Nhập sách", systemImage: "square.and.arrow.down")
        }.buttonStyle(PencilButtonStyle())
        Button {
          choosing = true
        } label: {
          Label("Từ thư viện", systemImage: "books.vertical")
        }.buttonStyle(PencilButtonStyle(color: .sky))
      }

      if books.isEmpty {
        EmptyPageCard(
          symbol: "book.closed", title: "Kệ sách đang chờ cuốn đầu tiên",
          detail:
            "Nhập TXT, Markdown, RTF, DOCX, PDF hoặc ảnh có chữ. Mầm nhớ trang đang đọc trên máy.")
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 18)], spacing: 20) {
          ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
            Button {
              opened = book
            } label: {
              bookCover(book)
            }
            .buttonStyle(SoftPressStyle())
            .contextMenu {
              Button("Đọc tiếp", systemImage: "book.pages") { opened = book }
              Button("Bỏ khỏi kệ", systemImage: "books.vertical", role: .destructive) {
                removing = book
              }
            }
            .modifier(CascadeArrival(index: index))
          }
        }
      }
      Text(
        "Mầm chỉ tạo cách trình bày để đọc. Nội dung sách vẫn nằm trong file bạn nhập và hoạt động hoàn toàn offline."
      ).font(.caption).foregroundStyle(.secondary)
    }
    .navigationTitle("Kệ sách")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $importing) { ImportCenter(bookMode: true) }
    .sheet(isPresented: $choosing) { ExistingBookPicker() }
    .fullScreenCover(item: $opened) { BookReaderView(book: $0) }
    .confirmationDialog(
      "Bỏ cuốn này khỏi kệ sách?",
      isPresented: Binding(
        get: { removing != nil }, set: { if !$0 { removing = nil } }),
      titleVisibility: .visible
    ) {
      Button("Bỏ khỏi kệ", role: .destructive) {
        guard let removing else { return }
        _ = store.editStudio {
          var room = $0.readingRoom
          room.books.removeAll { $0.id == removing.id }
          $0.readingRoom = room
        }
        self.removing = nil
      }
      Button("Hủy", role: .cancel) { removing = nil }
    } message: {
      Text("Tài liệu gốc vẫn được giữ trong Thư viện.")
    }
  }

  private func bookCover(_ book: BookRecord) -> some View {
    let document = store.state.studio.documents.first { $0.id == book.documentID }
    let progress: Double = {
      guard let document, document.kind != .pdf else { return 0 }
      return min(1, Double(book.textOffset) / Double(max(1, document.extractedText.utf16.count)))
    }()
    return ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: 15).fill(Color(uiColor: book.preferences.tone.paperUIColor))
        .shadow(color: .black.opacity(0.12), radius: 9, x: 4, y: 7)
      Rectangle().fill(Pencil.ink.opacity(0.13)).frame(width: 9).padding(.vertical, 5)
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: document == nil ? "exclamationmark.triangle" : "leaf.fill")
          .foregroundStyle(document == nil ? .red : Pencil.green)
        Text(book.title).font(.system(.headline, design: .serif, weight: .bold)).lineLimit(4)
          .foregroundStyle(Color(uiColor: book.preferences.tone.inkUIColor))
        Spacer()
        if document?.kind == .pdf {
          Text("Trang \(book.pdfPage + 1)")
        } else {
          ProgressView(value: progress).tint(Pencil.green)
          Text(progress > 0 ? "Đã đọc \(Int(progress * 100))%" : "Bắt đầu đọc")
        }
      }
      .font(.caption)
      .foregroundStyle(Color(uiColor: book.preferences.tone.inkUIColor).opacity(0.7))
      .padding(18).padding(.leading, 7)
    }.frame(minHeight: 205).contentShape(RoundedRectangle(cornerRadius: 15))
  }
}

private struct ExistingBookPicker: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss

  private var documents: [LibraryDocument] {
    let used = Set(store.state.studio.readingRoom.books.map(\.documentID))
    return store.state.studio.documents.filter {
      !used.contains($0.id) && ($0.kind == .pdf || !$0.extractedText.trimmed.isEmpty)
    }.sorted { $0.createdAt > $1.createdAt }
  }

  var body: some View {
    NavigationStack {
      List {
        if documents.isEmpty {
          ContentUnavailableView(
            "Chưa có tài liệu phù hợp", systemImage: "books.vertical",
            description: Text("Hãy nhập TXT, PDF hoặc ảnh có chữ trước."))
        }
        ForEach(documents) { document in
          Button {
            if store.addBook(document) { dismiss() }
          } label: {
            HStack {
              Image(systemName: documentSymbol(document.kind)).foregroundStyle(Pencil.green)
              VStack(alignment: .leading) {
                Text(document.title).foregroundStyle(Pencil.ink)
                Text(document.kind == .pdf ? "PDF" : "Sách chữ")
                  .font(.caption).foregroundStyle(.secondary)
              }
            }
          }
        }
      }
      .navigationTitle("Chọn từ thư viện")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { Button("Đóng") { dismiss() } }
    }
  }
}

private struct ReaderLayoutKey: Hashable {
  var width = 0
  var height = 0
  var textCount = 0
  var font = ""
  var fontSize = 0
  var spacing = 0
  var tone = ""
  var originalPDF = false
}

struct BookReaderView: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var book: BookRecord
  @State private var layout: BookLayout?
  @State private var pdf: PDFDocument?
  @State private var page = 0
  @State private var bodySize: CGSize = .zero
  @State private var loading = true
  @State private var message = ""
  @State private var generation = UUID()
  @State private var settings = false
  @State private var turnsSinceSave = 0

  init(book: BookRecord) { _book = State(initialValue: book) }

  private var document: LibraryDocument? {
    store.state.studio.documents.first { $0.id == book.documentID }
  }
  private var usesOriginalPDF: Bool {
    guard let document, document.kind == .pdf else { return false }
    return book.preferences.originalPDF || document.extractedText.trimmed.isEmpty
  }
  private var pageCount: Int {
    usesOriginalPDF ? (pdf?.pageCount ?? 0) : (layout?.ranges.count ?? 0)
  }
  private var layoutKey: ReaderLayoutKey {
    ReaderLayoutKey(
      width: Int(bodySize.width.rounded()), height: Int(bodySize.height.rounded()),
      textCount: document?.extractedText.utf16.count ?? 0, font: book.preferences.font,
      fontSize: Int((book.preferences.size * 10).rounded()),
      spacing: Int((book.preferences.lineSpacing * 10).rounded()),
      tone: book.preferences.tone.rawValue, originalPDF: usesOriginalPDF)
  }

  var body: some View {
    NavigationStack {
      GeometryReader { proxy in
        ZStack {
          Color(uiColor: book.preferences.tone.paperUIColor).ignoresSafeArea()
          if loading {
            ProgressView("Đang dàn trang…")
          } else if !message.isEmpty {
            ContentUnavailableView(
              "Chưa mở được sách", systemImage: "book.closed", description: Text(message))
          } else if pageCount > 0 {
            PaperPageCurl(
              layout: layout, pdf: pdf, title: book.title, pageCount: pageCount,
              tone: book.preferences.tone, reduceMotion: reduceMotion, page: $page
            ) { finishedPage in
              remember(finishedPage)
            }
            .id("\(generation.uuidString)-\(reduceMotion)")
          }
        }
        .onAppear { bodySize = proxy.size }
        .onChange(of: proxy.size) { _, newSize in
          if bodySize != .zero && bodySize != newSize { remember(page) }
          bodySize = newSize
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if pageCount > 0 { readerControls }
      }
      .navigationTitle(book.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Đóng") {
            remember(page, persist: true)
            dismiss()
          }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            toggleBookmark()
          } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
          }.accessibilityLabel(isBookmarked ? "Bỏ đánh dấu trang" : "Đánh dấu trang")
          Menu {
            let marks = currentBookmarks.sorted()
            if marks.isEmpty { Text("Chưa có trang đánh dấu") }
            ForEach(marks, id: \.self) { mark in
              Button(bookmarkTitle(mark)) { jump(to: mark) }
            }
          } label: {
            Image(systemName: "bookmark.square")
          }.accessibilityLabel("Danh sách trang đánh dấu")
          Button {
            settings = true
          } label: {
            Image(systemName: "textformat.size")
          }
          .accessibilityLabel("Kiểu chữ và màu giấy")
        }
      }
      .task(id: layoutKey) { await prepareBook() }
      .onChange(of: scenePhase) { _, phase in
        if phase != .active { remember(page, persist: true) }
      }
      .sheet(isPresented: $settings) {
        ReaderSettingsView(
          value: book.preferences,
          canUseReflowedText: !(document?.extractedText.trimmed.isEmpty ?? true),
          isPDF: document?.kind == .pdf
        ) { value in
          remember(page)
          book.preferences = value
          _ = store.saveBook(book)
          settings = false
        }
      }
    }
  }

  private var readerControls: some View {
    HStack(spacing: 14) {
      Button {
        page = max(0, page - 1)
      } label: {
        Image(systemName: "chevron.left")
      }
      .buttonStyle(.plain).disabled(page <= 0)
      Slider(
        value: Binding(
          get: { Double(page) },
          set: { page = min(max(0, Int($0.rounded())), max(0, pageCount - 1)) }),
        in: 0...Double(max(1, pageCount - 1)), step: 1
      ).accessibilityLabel("Trang sách")
      Text("\(page + 1) / \(pageCount)").font(.caption.monospacedDigit()).frame(minWidth: 62)
      Button {
        page = min(pageCount - 1, page + 1)
      } label: {
        Image(systemName: "chevron.right")
      }.buttonStyle(.plain).disabled(page >= pageCount - 1)
    }
    .padding(.horizontal, 16).padding(.vertical, 10)
    .background(.ultraThinMaterial)
  }

  @MainActor
  private func prepareBook() async {
    guard bodySize.width >= 120, bodySize.height >= 180 else { return }
    guard let document else {
      loading = false
      message = "Tài liệu gốc không còn trong Thư viện."
      return
    }
    loading = true
    message = ""
    if usesOriginalPDF {
      do {
        guard let filename = document.filename else {
          throw StudyError.invalid("PDF không còn file gốc.")
        }
        let url = try FileVault.current.url(filename)
        guard let loaded = PDFDocument(url: url), !loaded.isLocked, loaded.pageCount > 0 else {
          throw StudyError.invalid("PDF bị khóa hoặc không đọc được.")
        }
        pdf = loaded
        layout = nil
        page = min(max(0, book.pdfPage), loaded.pageCount - 1)
        generation = UUID()
      } catch {
        message = error.localizedDescription
      }
      loading = false
      return
    }

    let text = document.extractedText
    guard !text.trimmed.isEmpty else {
      loading = false
      message = "Tài liệu chưa có chữ để dàn thành trang."
      return
    }
    pdf = nil
    let size = bodySize
    let preferences = book.preferences
    let job = Task.detached(priority: .userInitiated) {
      try BookLayout.make(text: text, size: size, preferences: preferences)
    }
    do {
      let result = try await withTaskCancellationHandler(
        operation: { try await job.value }, onCancel: { job.cancel() })
      try Task.checkCancellation()
      layout = result
      page = result.page(containingUTF16Offset: book.textOffset)
      generation = UUID()
    } catch is CancellationError {
      return
    } catch {
      message = error.localizedDescription
    }
    loading = false
  }

  private var currentBookmarks: [Int] {
    usesOriginalPDF ? book.pdfBookmarks : book.bookmarks
  }
  private var currentMark: Int {
    if usesOriginalPDF { return page }
    return layout?.ranges.indices.contains(page) == true ? layout!.ranges[page].location : 0
  }
  private var isBookmarked: Bool { currentBookmarks.contains(currentMark) }

  private func toggleBookmark() {
    let mark = currentMark
    if usesOriginalPDF {
      var values = book.pdfBookmarks
      if let index = values.firstIndex(of: mark) {
        values.remove(at: index)
      } else {
        values.append(mark)
      }
      book.pdfBookmarks = values
    } else if let index = book.bookmarks.firstIndex(of: mark) {
      book.bookmarks.remove(at: index)
    } else {
      book.bookmarks.append(mark)
    }
    book.lastOpened = Date()
    _ = store.saveBook(book)
    InteractionFeedback.shared.play(.selection)
  }

  private func bookmarkTitle(_ mark: Int) -> String {
    if usesOriginalPDF { return "Trang \(mark + 1)" }
    let target = layout?.page(containingUTF16Offset: mark) ?? 0
    return "Trang \(target + 1)"
  }

  private func jump(to mark: Int) {
    page =
      usesOriginalPDF
      ? min(max(0, mark), max(0, pageCount - 1))
      : (layout?.page(containingUTF16Offset: mark) ?? 0)
  }

  private func remember(_ finishedPage: Int, persist: Bool = false) {
    let safe = min(max(0, finishedPage), max(0, pageCount - 1))
    if usesOriginalPDF {
      book.pdfPage = safe
    } else if let layout, layout.ranges.indices.contains(safe) {
      book.textOffset = layout.ranges[safe].location
    }
    book.lastOpened = Date()
    turnsSinceSave += 1
    if persist || turnsSinceSave >= 5 {
      _ = store.saveBook(book)
      turnsSinceSave = 0
    }
  }
}

private struct ReaderSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var value: ReaderPreferences
  let canUseReflowedText: Bool
  let isPDF: Bool
  let save: (ReaderPreferences) -> Void

  init(
    value: ReaderPreferences, canUseReflowedText: Bool, isPDF: Bool,
    save: @escaping (ReaderPreferences) -> Void
  ) {
    _value = State(initialValue: value)
    self.canUseReflowedText = canUseReflowedText
    self.isPDF = isPDF
    self.save = save
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Màu giấy") {
          HStack {
            ForEach(PaperTone.allCases) { tone in
              Button {
                value.tone = tone
              } label: {
                Circle().fill(Color(uiColor: tone.paperUIColor)).frame(width: 42, height: 42)
                  .overlay(Circle().stroke(Pencil.green, lineWidth: value.tone == tone ? 3 : 0))
                  .overlay {
                    if value.tone == tone {
                      Image(systemName: "checkmark").foregroundStyle(
                        Color(uiColor: tone.inkUIColor))
                    }
                  }
              }.buttonStyle(.plain).accessibilityLabel(tone.title)
            }
          }
        }
        Section("Kiểu chữ") {
          Picker("Font", selection: $value.font) {
            ForEach(ReadingFont.options) { font in Text(font.title).tag(font.id) }
          }
          LabeledContent("Cỡ chữ", value: "\(Int(value.size))")
          Slider(value: $value.size, in: 12...36, step: 1)
          LabeledContent("Khoảng dòng", value: "\(Int(value.lineSpacing))")
          Slider(value: $value.lineSpacing, in: 0...16, step: 1)
          Text("Mỗi trang sách là một khoảng yên để một ý tưởng có chỗ nảy mầm.")
            .font(readerFont).lineSpacing(CGFloat(value.lineSpacing))
            .foregroundStyle(Color(uiColor: value.tone.inkUIColor)).padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              Color(uiColor: value.tone.paperUIColor), in: RoundedRectangle(cornerRadius: 12))
        }
        if isPDF {
          Section("PDF") {
            Toggle("Giữ nguyên trang PDF", isOn: $value.originalPDF)
              .disabled(!canUseReflowedText)
            Text(
              canUseReflowedText
                ? "Tắt để đọc phần chữ trích xuất với font và màu giấy đã chọn."
                : "PDF scan chưa có đủ chữ để dàn lại; Mầm sẽ giữ nguyên trang gốc."
            ).font(.footnote).foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("Trang sách")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Áp dụng") { save(value) } }
      }
    }
  }

  private var readerFont: Font {
    value.font == "System-Serif"
      ? .system(size: value.size, design: .serif) : .custom(value.font, size: value.size)
  }
}
