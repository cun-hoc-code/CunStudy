import PDFKit
import PencilKit
import QuickLook
import SwiftUI
import VisionKit

struct LibraryView: View {
  @EnvironmentObject private var store: AppStore
  @State private var search = ""
  @State private var subject = ""
  @State private var importCenter = false
  @State private var scanning = false
  @State private var link = false
  @State private var busy = false
  private var items: [LibraryDocument] {
    store.state.studio.documents.filter { d in
      (subject.isEmpty || d.subject == subject)
        && (search.isEmpty
          || ([d.title, d.subject, d.term, d.extractedText] + d.tags).joined(separator: " ")
            .localizedCaseInsensitiveContains(search))
    }.sorted { $0.createdAt > $1.createdAt }
  }
  var body: some View {
    PaperPage {
      HStack {
        Picker("Môn học", selection: $subject) {
          Text("Tất cả").tag("")
          ForEach(
            Array(Set(store.state.studio.documents.map(\.subject))).filter { !$0.isEmpty }.sorted(),
            id: \.self
          ) { Text($0).tag($0) }
        }
        Spacer()
        LayoutPicker()
      }
      HStack {
        NavigationLink {
          BookshelfView()
        } label: {
          Label("Mở kệ sách", systemImage: "book.pages")
        }
        Spacer()
        Button("Nhập tài liệu", systemImage: "square.and.arrow.down") { importCenter = true }
      }
      if busy { ProgressView("Đang xử lý tài liệu…") }
      if items.isEmpty {
        EmptyPageCard(
          symbol: "books.vertical", title: "Thư viện của bạn",
          detail: "PDF, ảnh bảng, bài giảng, bản thu và các đường dẫn được lưu theo môn học.")
      }
      LazyVGrid(
        columns: store.state.studio.settings.layout == .grid
          ? [GridItem(.adaptive(minimum: 155))] : [GridItem(.flexible())], spacing: 14
      ) {
        ForEach(items) { d in
          NavigationLink {
            DocumentDetail(item: d)
          } label: {
            PaperCard(color: .sky) {
              VStack(alignment: .leading, spacing: 10) {
                HStack {
                  Image(systemName: documentSymbol(d.kind)).font(.title2)
                  Spacer()
                  Text(d.kind.rawValue.uppercased()).font(.caption2)
                }
                Text(d.title).font(.headline).lineLimit(3)
                if !d.subject.isEmpty { Text(d.subject).font(.caption).foregroundStyle(.secondary) }
                if store.state.studio.settings.layout == .cards {
                  Text(d.extractedText).font(.caption).lineLimit(3).foregroundStyle(.secondary)
                }
              }.frame(maxWidth: .infinity, alignment: .leading)
            }
          }.buttonStyle(SoftPressStyle())
        }
      }
    }.navigationTitle("Tài liệu").searchable(text: $search, prompt: "Tìm cả nội dung OCR…")
      .toolbar {
        Menu {
          Button("Nhập file / ảnh", systemImage: "doc.badge.plus") { importCenter = true }
          Button("Scan tài liệu", systemImage: "doc.viewfinder") { scanning = true }.disabled(
            !VNDocumentCameraViewController.isSupported)
          Button("Lưu đường dẫn", systemImage: "link") { link = true }
        } label: {
          Image(systemName: "plus")
        }.disabled(busy)
      }
      .sheet(isPresented: $importCenter) { ImportCenter() }
      .sheet(isPresented: $scanning) {
        ScanCamera { result in
          scanning = false
          Task {
            busy = true
            defer { busy = false }
            do {
              let images = try result.get()
              if !images.isEmpty {
                _ = store.saveDocument(try await TextRecognition.document(from: images))
              }
            } catch { store.errorMessage = error.localizedDescription }
          }
        }
      }
      .sheet(isPresented: $link) { LinkEditor() }
  }
}
func documentSymbol(_ kind: LibraryKind) -> String {
  switch kind {
  case .pdf: return "doc.richtext"
  case .image: return "photo"
  case .audio: return "waveform"
  case .drawing: return "pencil.tip.crop.circle"
  case .link: return "link"
  case .file: return "doc"
  }
}
struct LinkEditor: View {
  @EnvironmentObject private var store: AppStore
  @State private var value = LibraryDocument(kind: .link)
  var body: some View {
    StudioEditor(
      title: "Lưu bài viết",
      canSave: !value.title.trimmed.isEmpty && URL(string: value.link ?? "")?.host != nil,
      save: { store.saveDocument(value) }
    ) {
      TextField("Tiêu đề", text: $value.title)
      TextField("https://…", text: Binding(get: { value.link ?? "" }, set: { value.link = $0 }))
        .keyboardType(.URL).textInputAutocapitalization(.never)
      TextField("Môn học", text: $value.subject)
      Section("Nội dung lưu offline") {
        TextEditor(text: $value.extractedText).frame(minHeight: 200)
        Text(
          "Dán phần trích cần lưu. Đường dẫn được mở bằng trình duyệt; toàn bộ trang web không tự tải về."
        ).font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}
struct DocumentDetail: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  let item: LibraryDocument
  @State private var edit = false
  @State private var remove = false
  @State private var share = false
  @State private var quicklook: URL?
  @State private var drafts = false
  @State private var busy = false
  private var current: LibraryDocument {
    store.state.studio.documents.first { $0.id == item.id } ?? item
  }
  private var file: URL? { current.filename.flatMap { try? FileVault.current.url($0) } }
  var body: some View {
    Group {
      if current.kind == .pdf, let file {
        PDFNotebookView(item: current, url: file)
      } else {
        PaperPage {
          if current.kind == .image, let file, let image = UIImage(contentsOfFile: file.path) {
            Image(uiImage: image).resizable().scaledToFit().clipShape(
              RoundedRectangle(cornerRadius: 22))
          }
          if current.kind == .drawing, let file, let data = try? Data(contentsOf: file),
            let drawing = try? PKDrawing(data: data), !drawing.bounds.isEmpty
          {
            Image(uiImage: drawing.image(from: drawing.bounds.insetBy(dx: -12, dy: -12), scale: 1))
              .resizable().scaledToFit().background(.white).clipShape(
                RoundedRectangle(cornerRadius: 22))
          }
          if let file, current.kind == .audio || current.kind == .file {
            Button("Mở tài liệu / phát bản thu", systemImage: "play.circle") { quicklook = file }
              .buttonStyle(.borderedProminent)
          }
          if let link = current.link, let url = URL(string: link) {
            Link(destination: url) { Label("Mở đường dẫn", systemImage: "safari") }
          }
          if !current.subject.isEmpty { Text(current.subject).font(.headline) }
          if !current.extractedText.isEmpty {
            Text(current.extractedText).textSelection(.enabled).frame(
              maxWidth: .infinity, alignment: .leading)
          }
          if busy { ProgressView("Đang nhận dạng chữ…") }
          if current.kind == .image, let file {
            Button("Nhận dạng chữ (OCR)") {
              Task {
                busy = true
                defer { busy = false }
                do {
                  var d = current
                  d.extractedText = try await TextRecognition.read(Data(contentsOf: file))
                  _ = store.saveDocument(d)
                } catch { store.errorMessage = error.localizedDescription }
              }
            }.disabled(busy)
          }
        }
      }
    }.navigationTitle(current.title).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        Menu {
          Button("Thông tin tài liệu", systemImage: "slider.horizontal.3") { edit = true }
          Button("Tạo flashcard từ tài liệu", systemImage: "rectangle.on.rectangle") {
            drafts = true
          }
          if current.kind == .pdf || !current.extractedText.trimmed.isEmpty {
            Button("Thêm vào kệ sách", systemImage: "book.pages") {
              _ = store.addBook(current)
            }
          }
          if file != nil {
            Button("Chia sẻ file", systemImage: "square.and.arrow.up") { share = true }
          }
          Button("Xóa", role: .destructive) { remove = true }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
      .quickLookPreview($quicklook)
      .sheet(isPresented: $share) { if let file { ShareSheet(url: file) } }
      .sheet(isPresented: $edit) { DocumentMetadataEditor(value: current) }
      .sheet(isPresented: $drafts) {
        SourceCardWorkshop(document: current)
      }
      .confirmationDialog(
        "Xóa tài liệu khỏi thư viện và các ghi chú?", isPresented: $remove,
        titleVisibility: .visible
      ) {
        Button("Xóa", role: .destructive) {
          if store.change({ state in
            state.studio.documents.removeAll { $0.id == item.id }
            var room = state.studio.readingRoom
            room.books.removeAll { $0.documentID == item.id }
            state.studio.readingRoom = room
            for i in state.notes.indices {
              state.notes[i].details.attachments.removeAll { $0 == item.id }
            }
          }) {
            dismiss()
          }
        }
      }
  }
}
struct DocumentMetadataEditor: View {
  @EnvironmentObject private var store: AppStore
  @State var value: LibraryDocument
  var body: some View {
    StudioEditor(
      title: "Thông tin tài liệu", canSave: !value.title.trimmed.isEmpty,
      save: { store.saveDocument(value) }
    ) {
      TextField("Tiêu đề", text: $value.title)
      TextField("Môn học", text: $value.subject)
      TextField("Học phần / học kỳ", text: $value.term)
      TextField(
        "Tag, cách nhau bởi dấu phẩy",
        text: Binding(
          get: { value.tags.joined(separator: ", ") },
          set: {
            value.tags = $0.split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty }
          }))
      Section("Văn bản tìm kiếm") { TextEditor(text: $value.extractedText).frame(minHeight: 200) }
    }
  }
}
