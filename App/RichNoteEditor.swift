import SwiftUI
import VisionKit

struct NoteEditor: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var phase
  @State var value: QuickNote
  @StateObject private var recorder = LectureRecorder()
  @State private var preview = false
  @State private var scan = false
  @State private var drawing = false
  @State private var importing = false
  @State private var attachments = false
  @State private var drafts = false
  @State private var removing = false
  @State private var busy = false
  @State private var linked: QuickNote?
  @State private var pendingRecordingURL: URL?
  private var links: [QuickNote] {
    let names = WorkspaceEngine.links(in: value.body)
    return store.state.notes.filter {
      $0.id != value.id
        && (names.contains($0.title) || WorkspaceEngine.links(in: $0.body).contains(value.title))
    }
  }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Tiêu đề", text: $value.title)
          Toggle("Xem Markdown", isOn: $preview)
          if preview {
            MarkdownNote(text: value.body)
          } else {
            TextEditor(text: $value.body).frame(minHeight: 230).accessibilityLabel(
              "Nội dung ghi chú")
          }
          Text("Markdown: # tiêu đề, **in đậm**, - danh sách, | bảng |. Liên kết: [[Tên ghi chú]].")
            .font(.caption).foregroundStyle(.secondary)
        }
        Section("Phân loại") {
          TextField("Môn học", text: $value.details.subject)
          TextField("Thư mục", text: $value.details.folder)
          TextField(
            "Tag, cách nhau bởi dấu phẩy",
            text: Binding(
              get: { value.details.tags.joined(separator: ", ") },
              set: {
                value.details.tags = $0.split(separator: ",").map { String($0).trimmed }.filter {
                  !$0.isEmpty
                }
              }))
          Picker("Mục", selection: $value.category) {
            ForEach(NoteCategory.allCases) { Text(LocalizedStringKey($0.title)).tag($0) }
          }
          Toggle("Ghim lên đầu", isOn: $value.pinned)
          ColorPickerRow(selection: $value.color)
        }
        Section("Checklist") {
          ForEach($value.details.checklist) { $item in
            HStack {
              Toggle("Hoàn thành", isOn: $item.done).labelsHidden()
              TextField("Việc cần làm", text: $item.title)
            }
          }.onDelete { value.details.checklist.remove(atOffsets: $0) }
          Button("Thêm mục", systemImage: "plus") {
            value.details.checklist.append(ChecklistItem(title: ""))
          }
        }
        Section("Bản thu bài giảng") {
          HStack {
            Image(systemName: recorder.recording ? "record.circle.fill" : "mic").foregroundStyle(
              recorder.recording ? .red : Pencil.green)
            Text(
              recorder.recording
                ? String(
                  format: "%02d:%02d", Int(recorder.seconds) / 60, Int(recorder.seconds) % 60)
                : "Ghi âm cùng lúc với ghi chú")
            Spacer()
          }
          if recorder.recording {
            Button("Dừng và đính kèm") {
              recorder.stop()
              consumeRecording()
            }
          } else {
            Button(recorder.starting ? "Đang mở micro…" : "Bắt đầu ghi âm") {
              Task { await recorder.start() }
            }.disabled(recorder.starting || pendingRecordingURL != nil)
          }
          if pendingRecordingURL != nil { Button("Thử lưu lại bản thu") { consumeRecording() } }
          if let error = recorder.error { Text(error).font(.caption).foregroundStyle(.red) }
          Text(
            "Bản thu tối đa 60 phút. Ghi âm dừng và được lưu khi app vào nền. Hãy xin phép người nói trước khi thu."
          ).font(.caption).foregroundStyle(.secondary)
        }
        Section("Tệp đính kèm") {
          ForEach(store.state.studio.documents.filter { value.details.attachments.contains($0.id) })
          { d in
            NavigationLink {
              DocumentDetail(item: d)
            } label: {
              Label(d.title, systemImage: documentSymbol(d.kind))
            }.swipeActions {
              Button("Gỡ", role: .destructive) {
                value.details.attachments.removeAll { $0 == d.id }
              }
            }
          }
          Menu("Thêm tài liệu", systemImage: "paperclip") {
            Button("Từ thư viện") { attachments = true }
            Button("Nhập file") { importing = true }
            Button("Scan + OCR") { scan = true }.disabled(
              !VNDocumentCameraViewController.isSupported)
            Button("Viết tay") { drawing = true }
          }
          if busy { ProgressView("Đang xử lý…") }
        }
        if !links.isEmpty {
          Section("Ghi chú liên kết / backlinks") {
            ForEach(links) { note in
              Button(note.title) {
                _ = save()
                linked = note
              }
            }
          }
        }
        Section {
          Button("Tạo bản nháp flashcard", systemImage: "rectangle.on.rectangle") { drafts = true }
            .disabled(value.body.trimmed.isEmpty)
          if store.state.notes.contains(where: { $0.id == value.id }) {
            Button("Xóa ghi chú", role: .destructive) { removing = true }.disabled(
              recorder.recording || recorder.starting)
          }
        }
      }.navigationTitle("Sổ tay").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Hủy") { dismiss() }.disabled(
              recorder.recording || recorder.starting || busy || pendingRecordingURL != nil)
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Lưu") {
              recorder.stop()
              consumeRecording()
              if pendingRecordingURL == nil && save() { dismiss() }
            }.disabled(busy || recorder.starting)
          }
        }
        .interactiveDismissDisabled(
          recorder.recording || recorder.starting || busy || pendingRecordingURL != nil
        )
        .confirmationDialog("Xóa ghi chú?", isPresented: $removing, titleVisibility: .visible) {
          Button("Xóa", role: .destructive) {
            if store.change({ $0.notes.removeAll { $0.id == value.id } }) { dismiss() }
          }
        }
        .sheet(isPresented: $importing) {
          ImportCenter { document in
            attach(document)
            importing = false
          }
        }
        .sheet(isPresented: $attachments) {
          NavigationStack {
            List(store.state.studio.documents) { doc in
              Button {
                if !value.details.attachments.contains(doc.id) {
                  value.details.attachments.append(doc.id)
                }
                attachments = false
              } label: {
                Label(doc.title, systemImage: documentSymbol(doc.kind))
              }
            }.navigationTitle("Chọn tài liệu").toolbar { Button("Xong") { attachments = false } }
          }
        }
        .sheet(isPresented: $drawing) {
          HandwritingSheet { data in
            do {
              attach(
                LibraryDocument(
                  title: value.title.isEmpty ? "Trang viết tay" : value.title + " • viết tay",
                  subject: value.details.subject, kind: .drawing,
                  filename: try FileVault.current.put(data, extension: "drawing")))
            } catch { store.errorMessage = error.localizedDescription }
          }
        }
        .sheet(isPresented: $scan) {
          ScanCamera { result in
            scan = false
            Task {
              busy = true
              defer { busy = false }
              do {
                let images = try result.get()
                guard !images.isEmpty else { return }
                let doc = try await TextRecognition.document(from: images)
                attach(doc)
                value.body += "\n\n" + String(doc.extractedText.prefix(50_000))
                _ = save()
              } catch { store.errorMessage = error.localizedDescription }
            }
          }
        }
        .sheet(isPresented: $drafts) {
          CardDraftReview(
            text: value.body,
            deck: value.details.subject.isEmpty ? value.title : value.details.subject)
        }
        .sheet(item: $linked) { NoteEditor(value: $0) }
        .onChange(of: recorder.completedURL) { _, _ in consumeRecording() }
        .onChange(of: phase) { _, new in
          if new == .background {
            recorder.stop()
            consumeRecording()
            _ = save()
          }
        }
        .onDisappear {
          recorder.stop()
          consumeRecording()
        }
    }
  }
  private func attach(_ document: LibraryDocument) {
    if store.saveDocument(document) { value.details.attachments.append(document.id) }
  }
  @discardableResult private func save() -> Bool {
    if value.title.trimmed.isEmpty {
      value.title = String(value.body.trimmed.prefix(50))
      if value.title.isEmpty {
        value.title = "Ghi chú " + Date().formatted(date: .abbreviated, time: .shortened)
      }
    }
    value.updatedAt = Date()
    return store.saveNote(value)
  }
  private func consumeRecording() {
    guard let url = recorder.completedURL ?? pendingRecordingURL else { return }
    recorder.completedURL = nil
    pendingRecordingURL = url
    do {
      let document = LibraryDocument(
        title: (value.title.isEmpty ? "Bài giảng" : value.title) + " • "
          + Date().formatted(date: .omitted, time: .shortened),
        subject: value.details.subject, kind: .audio,
        filename: try FileVault.current.importFile(url))
      var next = value
      if next.title.trimmed.isEmpty {
        next.title = "Bài giảng " + Date().formatted(date: .abbreviated, time: .shortened)
      }
      next.details.attachments.append(document.id)
      next.updatedAt = Date()
      guard
        store.change({ state in
          state.studio.documents.append(document)
          upsert(next, in: &state.notes)
        })
      else {
        recorder.error = "Chưa lưu được bản thu. Bấm thử lại trước khi đóng ghi chú."
        return
      }
      value = next
      pendingRecordingURL = nil
      recorder.error = nil
      try? FileManager.default.removeItem(at: url)
    } catch { recorder.error = error.localizedDescription }
  }
}

/// Offline headings, inline Markdown, lists, block quotes and scrollable tables.
struct MarkdownNote: View {
  let text: String
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
        if line.hasPrefix("|") {
          ScrollView(.horizontal) {
            HStack(spacing: 16) {
              ForEach(Array(line.split(separator: "|").enumerated()), id: \.offset) { _, cell in
                Text(.init(String(cell).trimmed)).frame(minWidth: 90, alignment: .leading)
              }
            }.padding(8).background(Pencil.surface)
          }
        } else if line.hasPrefix("# ") {
          Text(.init(String(line.dropFirst(2)))).font(.title.bold())
        } else if line.hasPrefix("## ") {
          Text(.init(String(line.dropFirst(3)))).font(.title2.bold())
        } else if line.hasPrefix("### ") {
          Text(.init(String(line.dropFirst(4)))).font(.headline)
        } else if line.hasPrefix("- ") {
          HStack(alignment: .top) {
            Text("•")
            Text(.init(String(line.dropFirst(2))))
          }
        } else if line.hasPrefix("> ") {
          Text(.init(String(line.dropFirst(2)))).italic().padding(.leading, 14).overlay(
            alignment: .leading
          ) { Rectangle().fill(Pencil.green).frame(width: 3) }
        } else {
          Text(.init(line.isEmpty ? " " : line))
        }
      }
    }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
  }
}
