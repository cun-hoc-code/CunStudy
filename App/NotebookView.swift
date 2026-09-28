import SwiftUI

struct NotebookView: View {
  @EnvironmentObject private var store: AppStore
  @State private var draft: QuickNote?
  @State private var search = ""
  @State private var folder = ""
  @State private var subject = ""
  private var items: [QuickNote] {
    store.state.notes.filter { n in
      let attached = store.state.studio.documents.filter { n.details.attachments.contains($0.id) }
        .map(\.extractedText).joined(separator: " ")
      return (folder.isEmpty || n.details.folder == folder)
        && (subject.isEmpty || n.details.subject == subject)
        && (search.isEmpty
          || ([n.title, n.body, n.details.subject, n.details.folder, attached] + n.details.tags
            + n.details.checklist.map(\.title)).joined(separator: " ")
            .localizedCaseInsensitiveContains(search))
    }.sorted { $0.pinned != $1.pinned ? $0.pinned : $0.updatedAt > $1.updatedAt }
  }
  var body: some View {
    NavigationStack {
      PaperPage {
        HStack {
          NavigationLink {
            StudyHubView()
          } label: {
            Label("Không gian học", systemImage: "square.grid.2x2")
          }
          Spacer()
          NavigationLink {
            LibraryView()
          } label: {
            Label("Tài liệu", systemImage: "books.vertical")
          }
        }
        NavigationLink {
          BookshelfView()
        } label: {
          Label("Kệ sách & phòng đọc", systemImage: "book.pages")
        }
        HStack {
          Menu {
            Picker("Thư mục", selection: $folder) {
              Text("Tất cả").tag("")
              ForEach(
                Array(Set(store.state.notes.map { $0.details.folder })).filter { !$0.isEmpty }
                  .sorted(), id: \.self
              ) { Text($0).tag($0) }
            }
            Picker("Môn học", selection: $subject) {
              Text("Tất cả").tag("")
              ForEach(
                Array(Set(store.state.notes.map { $0.details.subject })).filter { !$0.isEmpty }
                  .sorted(), id: \.self
              ) { Text($0).tag($0) }
            }
          } label: {
            Label(
              folder.isEmpty && subject.isEmpty
                ? "Lọc" : ([folder, subject].filter { !$0.isEmpty }.joined(separator: " • ")),
              systemImage: "line.3.horizontal.decrease.circle")
          }
          Spacer()
          LayoutPicker()
        }
        if items.isEmpty {
          EmptyPageCard(
            symbol: "pencil.and.scribble", title: "Nghĩ đến đâu, ghi đến đó",
            detail: "Ghi chú có Markdown, checklist, bản thu, trang viết tay và tài liệu đi kèm.")
        }
        LazyVGrid(
          columns: store.state.studio.settings.layout == .grid
            ? [GridItem(.adaptive(minimum: 155))] : [GridItem(.flexible())], spacing: 14
        ) {
          ForEach(items) { note in
            Button {
              draft = note
            } label: {
              PaperCard(color: note.color) {
                VStack(alignment: .leading, spacing: 9) {
                  HStack {
                    Text(note.details.subject.isEmpty ? note.category.title : note.details.subject)
                      .font(.caption2.bold())
                    Spacer()
                    if note.pinned { Image(systemName: "pin.fill") }
                  }
                  Text(note.title).font(.system(.title3, design: .rounded, weight: .semibold))
                  if store.state.studio.settings.layout != .list {
                    Text(note.body).lineLimit(store.state.studio.settings.layout == .grid ? 3 : 6)
                      .font(.body)
                  }
                  HStack {
                    Text(note.updatedAt, format: .dateTime.day().month())
                    Spacer()
                    if !note.details.attachments.isEmpty {
                      Label("\(note.details.attachments.count)", systemImage: "paperclip")
                    }
                  }.font(.caption).foregroundStyle(.secondary)
                }
              }
            }.buttonStyle(SoftPressStyle())
          }
        }
      }.navigationTitle("Sổ tay").searchable(text: $search, prompt: "Tìm ghi chú, tag, OCR…")
        .toolbar {
          Button {
            var note = QuickNote()
            note.details.folder = folder
            note.details.subject = subject
            draft = note
          } label: {
            Image(systemName: "square.and.pencil")
          }.accessibilityLabel("Ghi nhanh")
        }.sheet(item: $draft) { NoteEditor(value: $0) }
    }
  }
}
