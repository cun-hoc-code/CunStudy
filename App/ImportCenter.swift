import ImageIO
import PDFKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct LocalFilePicker: UIViewControllerRepresentable {
  var types: [UTType] = [.data, .content]
  var finished: (Result<URL?, Error>) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(finished) }
  func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    picker.allowsMultipleSelection = false
    picker.delegate = context.coordinator
    return picker
  }
  func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {}
  @MainActor final class Coordinator: NSObject, UIDocumentPickerDelegate {
    let finished: (Result<URL?, Error>) -> Void
    private var delivered = false
    init(_ finished: @escaping (Result<URL?, Error>) -> Void) { self.finished = finished }
    func documentPicker(
      _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
      guard let url = urls.first else {
        complete(.success(nil))
        return
      }
      Task {
        do {
          let local = try await Task.detached(priority: .userInitiated) {
            try ImportSource.stage(url)
          }.value
          complete(.success(local))
        } catch { complete(.failure(error)) }
      }
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
      complete(.success(nil))
    }
    private func complete(_ value: Result<URL?, Error>) {
      guard !delivered else { return }
      delivered = true
      finished(value)
    }
  }
}
enum ImportSource {
  static func stage(_ source: URL) throws -> URL {
    let access = source.startAccessingSecurityScopedResource()
    defer { if access { source.stopAccessingSecurityScopedResource() } }
    var error: NSError?
    var result: Result<URL, Error>?
    NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &error) { readable in
      result = Result {
        let meta = try readable.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        guard meta.isDirectory != true else {
          throw StudyError.invalid("Chọn file thay vì thư mục.")
        }
        if let size = meta.fileSize, size > 50 * 1024 * 1024 {
          throw StudyError.invalid("Mỗi file tối đa 50 MB.")
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
          "mam-import-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let local = folder.appendingPathComponent(readable.lastPathComponent)
        do {
          try FileManager.default.copyItem(at: readable, to: local)
          guard
            (try local.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 50 * 1024
              * 1024
          else { throw StudyError.invalid("Mỗi file tối đa 50 MB.") }
          return local
        } catch {
          try? FileManager.default.removeItem(at: folder)
          throw error
        }
      }
    }
    if let error { throw error }
    guard let result else {
      throw StudyError.invalid(
        "Chưa tải được file. Mở trong ứng dụng Tệp để tải về máy rồi thử lại.")
    }
    return try result.get()
  }
  static func discard(_ url: URL) {
    let folder = url.deletingLastPathComponent()
    if folder.lastPathComponent.hasPrefix("mam-import-") {
      try? FileManager.default.removeItem(at: folder)
    }
  }
}
struct ImportedContent {
  var document: LibraryDocument
  var notice = ""
}
actor ContentImporter {
  static let shared = ContentImporter()
  func file(_ url: URL) async throws -> ImportedContent {
    let name = try FileVault.current.importFile(url)
    let local = try FileVault.current.url(name)
    do {
      let ext = url.pathExtension.lowercased()
      let type = UTType(filenameExtension: url.pathExtension)
      var d = LibraryDocument(title: url.deletingPathExtension().lastPathComponent, filename: name)
      var notice = ""
      if ext == "pdf" {
        d.kind = .pdf
        guard let pdf = PDFDocument(url: local), !pdf.isLocked, pdf.pageCount > 0 else {
          throw StudyError.invalid("PDF bị khóa hoặc không đọc được. Dùng bản không có mật khẩu.")
        }
        var parts: [String] = []
        var length = 0
        for i in 0..<pdf.pageCount {
          let part = pdf.page(at: i)?.string ?? ""
          parts.append(part)
          length += part.count
          if length >= 2_000_000 {
            notice = "Văn bản chỉ lấy 2 triệu ký tự đầu. PDF gốc vẫn đầy đủ."
            break
          }
        }
        d.extractedText = String(parts.joined(separator: "\n\n").prefix(2_000_000))
        if d.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          let count = min(pdf.pageCount, 40)
          var recognized = 0
          for i in 0..<count {
            try Task.checkCancellation()
            guard let page = pdf.page(at: i),
              let data = page.thumbnail(of: CGSize(width: 1400, height: 1900), for: .mediaBox)
                .pngData()
            else { continue }
            if let text = try? await TextRecognition.read(data), !text.trimmed.isEmpty {
              d.extractedText += text + "\n\n"
              recognized += 1
            }
          }
          d.extractedText = String(d.extractedText.prefix(2_000_000))
          notice =
            recognized == 0
            ? "PDF scan đã được lưu nhưng chưa nhận ra chữ. Bạn vẫn có thể đọc đủ ở chế độ trang gốc."
            : "PDF scan: nhận được chữ ở \(recognized) / \(count) trang đã quét; chỉ quét tối đa 40 trang đầu. Chế độ trang gốc vẫn đọc đủ sách."
        }
      } else if type?.conforms(to: .image) == true {
        d.kind = .image
        d.extractedText = (try? await TextRecognition.read(Data(contentsOf: local))) ?? ""
        if d.extractedText.isEmpty {
          notice = "Ảnh đã nhập nhưng chưa nhận ra chữ. Bạn có thể tạo câu hỏi và đáp án thủ công."
        }
      } else if ["txt", "md", "csv", "tsv", "text"].contains(ext) {
        d.extractedText = String(
          try TextFileDecoder.decode(Data(contentsOf: local)).prefix(2_000_000))
      } else if ["rtf", "rtfd", "doc", "docx", "html", "htm"].contains(ext) {
        let extracted = try? await MainActor.run {
          // Let Foundation inspect the extension and file contents. Explicit Word
          // document-type constants are not exposed consistently by every iOS SDK.
          return String(
            try NSAttributedString(
              url: local, options: [:], documentAttributes: nil
            ).string.prefix(2_000_000))
        }
        d.extractedText = extracted ?? ""
        if extracted == nil {
          notice =
            "Đã lưu file nhưng iOS chưa đọc được phần chữ. Bạn vẫn có thể đính kèm hoặc nhập bản TXT/PDF để tạo thẻ."
        }
      } else if type?.conforms(to: .audio) == true {
        d.kind = .audio
        notice = "Đã lưu bản thu; chưa có chuyển giọng nói thành chữ."
      } else {
        notice =
          "Đã lưu file gốc. Định dạng này chưa trích được chữ; dùng TXT, PDF, ảnh, RTF hoặc DOCX để tạo thẻ từ nội dung."
      }
      return ImportedContent(document: d, notice: notice)
    } catch {
      try? FileManager.default.removeItem(at: local)
      throw error
    }
  }
  func photo(_ bytes: Data) async throws -> ImportedContent {
    guard bytes.count <= 50 * 1024 * 1024,
      let source = CGImageSourceCreateWithData(bytes as CFData, nil),
      let cg = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: 2400,
          kCGImageSourceCreateThumbnailWithTransform: true,
        ] as CFDictionary),
      let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.9)
    else { throw StudyError.invalid("Không đọc được ảnh hoặc ảnh vượt 50 MB.") }
    let filename = try FileVault.current.put(jpeg, extension: "jpg")
    let text = (try? await TextRecognition.read(jpeg)) ?? ""
    return ImportedContent(
      document: LibraryDocument(
        title: "Ảnh " + Date().formatted(date: .abbreviated, time: .shortened), kind: .image,
        filename: filename, extractedText: text),
      notice: text.isEmpty ? "Đã lưu ảnh; chưa nhận ra chữ. Có thể tạo thẻ thủ công." : "")
  }
}
struct ImportCenter: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  var bookMode = false
  var imported: ((LibraryDocument) -> Void)? = nil
  @State private var picker = false
  @State private var photoPicker = false
  @State private var photo: PhotosPickerItem?
  @State private var busy = false
  @State private var message = ""
  @State private var failure = ""
  @State private var result: LibraryDocument?
  @State private var cards = false
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Image(systemName: bookMode ? "books.vertical" : "doc.viewfinder").font(.system(size: 40))
            .foregroundStyle(Pencil.green)
          Text(bookMode ? "Thêm sách vào kệ" : "Từ tài liệu đến thẻ ôn").font(.title2.bold())
          Text(
            "Chọn file từ Tệp hoặc ảnh từ thư viện. Mầm lấy chữ trên máy để bạn kiểm tra và tạo flashcard."
          ).foregroundStyle(.secondary)
          Button {
            picker = true
          } label: {
            Label("Chọn file từ Tệp", systemImage: "folder")
          }.buttonStyle(PencilButtonStyle()).disabled(busy)
          Button {
            photoPicker = true
          } label: {
            Label("Chọn ảnh", systemImage: "photo")
          }.buttonStyle(PencilButtonStyle(color: .sky)).disabled(busy)
          Text(
            "TXT · PDF · ảnh · Markdown · RTF · DOC/DOCX · HTML. File khác vẫn lưu được nhưng có thể không trích chữ. Tối đa 50 MB/file."
          ).font(.caption).foregroundStyle(.secondary)
          if busy {
            HStack {
              ProgressView()
              Text("Đang tải và đọc nội dung… PDF scan có thể mất một lúc.")
            }
          }
          if !failure.isEmpty {
            Label(failure, systemImage: "exclamationmark.circle").foregroundStyle(.red)
              .textSelection(.enabled)
          }
          if let result {
            PaperCard(color: .sage) {
              VStack(alignment: .leading, spacing: 10) {
                Label("Đã nhập: " + result.title, systemImage: "checkmark.circle.fill").font(
                  .headline)
                Text("\(result.extractedText.count) ký tự nhận được").font(.caption)
                if !message.isEmpty { Text(message).font(.caption) }
                Text(
                  result.extractedText.isEmpty
                    ? "Có thể tự viết câu hỏi và đáp án ở bước tiếp theo."
                    : String(result.extractedText.prefix(1800))
                ).textSelection(.enabled)
              }
            }
            Button("Chỉnh nội dung & tạo flashcard", systemImage: "rectangle.on.rectangle") {
              cards = true
            }.buttonStyle(PencilButtonStyle(color: .butter))
            Button(bookMode ? "Xong, về kệ sách" : "Xong") { dismiss() }.frame(
              maxWidth: .infinity, minHeight: 44)
          }
        }.padding(24)
      }.background(Pencil.paper).navigationTitle(bookMode ? "Nhập sách" : "Nhập tài liệu")
        .toolbar { Button("Đóng") { dismiss() }.disabled(busy) }.interactiveDismissDisabled(busy)
        .sheet(isPresented: $picker) {
          LocalFilePicker { response in
            picker = false
            switch response {
            case .success(let url): if let url { load(url) }
            case .failure(let error): failure = error.localizedDescription
            }
          }
        }
        .photosPicker(
          isPresented: $photoPicker, selection: $photo, matching: .images,
          preferredItemEncoding: .compatible
        )
        .onChange(of: photo) { _, item in
          guard let item else { return }
          busy = true
          failure = ""
          result = nil
          Task {
            defer {
              busy = false
              photo = nil
            }
            do {
              guard let data = try await item.loadTransferable(type: Data.self) else {
                throw StudyError.invalid(
                  "Không tải được ảnh. Nếu ở iCloud, kiểm tra mạng rồi thử lại.")
              }
              accept(try await ContentImporter.shared.photo(data))
            } catch { failure = error.localizedDescription }
          }
        }
        .sheet(isPresented: $cards) { if let result { SourceCardWorkshop(document: result) } }
    }
  }
  private func load(_ url: URL) {
    busy = true
    failure = ""
    result = nil
    Task {
      defer {
        busy = false
        ImportSource.discard(url)
      }
      do { accept(try await ContentImporter.shared.file(url)) } catch {
        failure = error.localizedDescription
      }
    }
  }
  private func accept(_ content: ImportedContent) {
    guard store.saveDocument(content.document) else {
      failure = store.errorMessage ?? "Chưa lưu được tài liệu."
      store.errorMessage = nil
      return
    }
    result = content.document
    message = content.notice
    if bookMode, !store.addBook(content.document) {
      failure = store.errorMessage ?? "Chưa thêm được sách."
      store.errorMessage = nil
    }
    imported?(content.document)
    InteractionFeedback.shared.play(.success)
  }
}
struct SourceCardWorkshop: View {
  @EnvironmentObject private var store: AppStore
  let document: LibraryDocument
  @State private var source = ""
  @State private var question = ""
  @State private var answer = ""
  @State private var deck = ""
  @State private var auto = false
  @State private var saved = 0
  @State private var loaded = false
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      Form {
        Section("Văn bản từ tài liệu · có thể sửa") {
          TextEditor(text: $source).frame(minHeight: 180)
          Text(
            "OCR có thể sai dấu hoặc xuống dòng. Copy phần cần học để làm câu hỏi/đáp án; không bắt buộc có dấu hai chấm."
          ).font(.caption)
        }
        Section("Tạo thẻ hai mặt") {
          TextField("Bộ thẻ", text: $deck)
          TextField("Câu hỏi / mặt trước", text: $question, axis: .vertical).lineLimit(3...8)
          TextField("Đáp án / mặt sau", text: $answer, axis: .vertical).lineLimit(3...12)
          Button("Dùng văn bản phía trên làm đáp án") { answer = source }
          Button("Lưu thẻ") {
            var card = Flashcard()
            card.deck = deck
            card.front = question
            card.back = answer
            if store.saveCard(card) {
              saved += 1
              question = ""
              answer = ""
              InteractionFeedback.shared.play(.success)
            }
          }.disabled(question.trimmed.isEmpty || answer.trimmed.isEmpty || deck.trimmed.isEmpty)
          if saved > 0 { Text("Đã lưu \(saved) thẻ vào bộ này.").foregroundStyle(Pencil.green) }
        }
        Section("Tách hàng loạt") {
          Button("Xem thẻ nháp từ dòng ‘câu hỏi: đáp án’") { auto = true }.disabled(
            source.trimmed.isEmpty)
          Text("Tách dòng có cấu trúc và {{cloze}}, không tự suy diễn đáp án từ cả tài liệu.").font(
            .caption)
        }
      }.navigationTitle("Tài liệu → flashcard").toolbar { Button("Xong") { dismiss() } }.onAppear {
        guard !loaded else { return }
        loaded = true
        source = document.extractedText
        deck = document.subject.isEmpty ? document.title : document.subject
      }.sheet(isPresented: $auto) { CardDraftReview(text: source, deck: deck) }
    }
  }
}
