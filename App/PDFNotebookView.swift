import PDFKit
import SwiftUI

struct PDFNotebookView: View {
  @EnvironmentObject private var store: AppStore
  let item: LibraryDocument
  let url: URL
  @State private var view = PDFView()
  @State private var comment = ""
  @State private var ask = false
  @State private var changed = false
  @State private var recent: [(PDFPage, PDFAnnotation)] = []
  @State private var pageNumber = 1
  @State private var message = ""
  private var bookmarks: [Int] {
    store.state.studio.documents.first { $0.id == item.id }?.bookmarks ?? []
  }
  var body: some View {
    VStack(spacing: 0) {
      PDFSurface(view: view, url: url).onReceive(
        NotificationCenter.default.publisher(for: .PDFViewPageChanged)
      ) { notification in
        guard let source = notification.object as? PDFView, source === view,
          let page = view.currentPage, let doc = view.document
        else { return }
        pageNumber = doc.index(for: page) + 1
      }
      VStack(spacing: 8) {
        HStack {
          Button {
            annotate(.highlight)
          } label: {
            Image(systemName: "highlighter")
          }.accessibilityLabel("Highlight vùng chữ được chọn")
          Spacer()
          Button {
            annotate(.underline)
          } label: {
            Image(systemName: "underline")
          }.accessibilityLabel("Gạch chân vùng chữ được chọn")
          Spacer()
          Button {
            ask = true
          } label: {
            Image(systemName: "text.bubble")
          }.accessibilityLabel("Thêm bình luận")
          Spacer()
          Button {
            bookmark()
          } label: {
            Image(systemName: bookmarks.contains(pageNumber - 1) ? "bookmark.fill" : "bookmark")
          }.accessibilityLabel("Đánh dấu trang")
          Spacer()
          Button {
            if let pair = recent.popLast() {
              pair.0.removeAnnotation(pair.1)
              changed = true
            }
          } label: {
            Image(systemName: "arrow.uturn.backward")
          }.disabled(recent.isEmpty).accessibilityLabel("Hoàn tác chú thích")
          Spacer()
          Button("Lưu") { save() }.bold().disabled(!changed)
        }.font(.title3).padding(.horizontal, 18).frame(minHeight: 44)
        HStack {
          Text("Trang \(pageNumber) / \(view.document?.pageCount ?? 0)").font(.caption)
          if !bookmarks.isEmpty {
            Menu("Đã đánh dấu") {
              ForEach(bookmarks, id: \.self) { index in
                Button("Trang \(index+1)") {
                  if let page = view.document?.page(at: index) { view.go(to: page) }
                }
              }
            }
          }
          Spacer()
        }.padding(.horizontal, 18)
        if !message.isEmpty { Text(message).font(.caption) }
        Text("Chọn chữ trước khi highlight / gạch chân. Lưu để giữ các chú thích.").font(.caption2)
          .foregroundStyle(.secondary).padding(.bottom, 6)
      }.background(Pencil.surface)
    }.alert("Bình luận trang \(pageNumber)", isPresented: $ask) {
      TextField("Nội dung", text: $comment)
      Button("Thêm") {
        guard let page = view.currentPage, !comment.trimmed.isEmpty else { return }
        let box = page.bounds(for: .cropBox)
        let note = PDFAnnotation(
          bounds: CGRect(x: box.minX + 24, y: box.maxY - 58, width: 28, height: 28), forType: .text,
          withProperties: nil)
        note.contents = comment
        note.color = .systemYellow
        page.addAnnotation(note)
        recent.append((page, note))
        changed = true
        comment = ""
      }
      Button("Hủy", role: .cancel) {}
    }.onDisappear { if changed { save() } }
  }
  private func bookmark() {
    guard var d = store.state.studio.documents.first(where: { $0.id == item.id }),
      view.currentPage != nil
    else { return }
    let index = pageNumber - 1
    if d.bookmarks.contains(index) {
      d.bookmarks.removeAll { $0 == index }
    } else {
      d.bookmarks.append(index)
      d.bookmarks.sort()
    }
    _ = store.saveDocument(d)
  }
  private func annotate(_ type: PDFAnnotationSubtype) {
    guard let selection = view.currentSelection, !(selection.string ?? "").isEmpty else {
      message = "Chọn chữ trước. PDF scan có thể chưa có lớp chữ."
      return
    }
    for line in selection.selectionsByLine() {
      for page in line.pages {
        let a = PDFAnnotation(bounds: line.bounds(for: page), forType: type, withProperties: nil)
        a.color =
          type == .highlight ? UIColor.systemYellow.withAlphaComponent(0.45) : UIColor.systemGreen
        page.addAnnotation(a)
        recent.append((page, a))
        changed = true
      }
    }
    view.clearSelection()
    message = "Đã thêm chú thích."
  }
  private func save() {
    guard let data = view.document?.dataRepresentation(),
      var d = store.state.studio.documents.first(where: { $0.id == item.id })
    else { return }
    do {
      d.filename = try FileVault.current.put(data, extension: "pdf")
      if store.saveDocument(d) {
        changed = false
        message = "Đã lưu chú thích."
      }
    } catch { store.errorMessage = error.localizedDescription }
  }
}
struct PDFSurface: UIViewRepresentable {
  let view: PDFView
  let url: URL
  func makeUIView(context: Context) -> PDFView {
    view.document = PDFDocument(url: url)
    view.autoScales = true
    view.displayMode = .singlePageContinuous
    view.displayDirection = .vertical
    view.backgroundColor = .secondarySystemBackground
    return view
  }
  func updateUIView(_ view: PDFView, context: Context) {}
}
