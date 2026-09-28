import Combine
import SwiftUI
import UniformTypeIdentifiers

struct PracticeView: View {
  @EnvironmentObject private var store: AppStore
  @State private var subject = ""
  @State private var draft: PracticeQuestion?
  @State private var test = false
  @State private var minutes = 20
  @State private var count = 20
  @State private var importing = false
  @State private var imported: [PracticeQuestion] = []
  @State private var preview = false
  @State private var share = false
  @State private var shareURL: URL?
  private var questions: [PracticeQuestion] {
    store.state.studio.questions.filter { subject.isEmpty || $0.subject == subject }
  }
  var body: some View {
    PaperPage {
      PaperCard(color: .lavender) {
        VStack(alignment: .leading, spacing: 12) {
          SectionTitle(
            title: "Thử sức một chút", caption: "Tự kiểm tra để biết phần nào cần chăm thêm.")
          Picker("Môn học", selection: $subject) {
            Text("Tất cả").tag("")
            ForEach(Array(Set(store.state.studio.questions.map(\.subject))).sorted(), id: \.self) {
              Text($0).tag($0)
            }
          }
          Stepper("\(count) câu hỏi", value: $count, in: 1...100)
          Stepper("\(minutes) phút", value: $minutes, in: 1...180)
          if store.state.studio.runningTest != nil {
            Button("Tiếp tục bài đang làm", systemImage: "play.fill") { test = true }.buttonStyle(
              PencilButtonStyle())
          } else {
            Button("Bắt đầu thi thử", systemImage: "timer") {
              store.startTest(
                Array(questions.shuffled().prefix(count)), minutes: minutes,
                title: subject.isEmpty ? "Thi thử" : subject)
              test = store.state.studio.runningTest != nil
            }.disabled(questions.isEmpty).buttonStyle(PencilButtonStyle())
          }
        }
      }
      HStack {
        NavigationLink {
          MistakeBookView()
        } label: {
          Label("Sổ lỗi sai", systemImage: "arrow.counterclockwise")
        }
        Spacer()
        NavigationLink {
          PracticeHistoryView()
        } label: {
          Label("Kết quả", systemImage: "chart.bar.xaxis")
        }
      }
      SectionTitle(
        title: "Ngân hàng câu hỏi",
        caption: "\(questions.count) câu • đáp án và giải thích có thể chỉnh sửa")
      if questions.isEmpty {
        EmptyPageCard(
          symbol: "questionmark.bubble", title: "Thêm câu hỏi đầu tiên",
          detail:
            "Tạo câu hỏi của bạn hoặc chuyển flashcard có ít nhất hai đáp án khác nhau thành bài trắc nghiệm."
        )
      }
      ForEach(questions.prefix(150)) { q in
        Button {
          draft = q
        } label: {
          PaperCard {
            VStack(alignment: .leading, spacing: 8) {
              Text(q.prompt).font(.headline)
              Text([q.subject, q.chapter].filter { !$0.isEmpty }.joined(separator: " • ")).font(
                .caption
              ).foregroundStyle(.secondary)
            }
          }
        }.buttonStyle(SoftPressStyle())
      }
    }.navigationTitle("Luyện tập").toolbar {
      Menu {
        Button("Tạo câu hỏi", systemImage: "plus") { draft = PracticeQuestion() }
        Button("Từ flashcard", systemImage: "rectangle.on.rectangle") {
          let ids = Set(store.state.studio.questions.compactMap(\.sourceCardID))
          let values = WorkspaceEngine.questions(from: store.state.cards).filter {
            !ids.contains($0.sourceCardID ?? UUID())
          }
          if values.isEmpty {
            store.errorMessage =
              "Cần ít nhất hai flashcard có đáp án khác nhau trong cùng bộ, chưa được chuyển thành câu hỏi."
          } else {
            _ = store.editStudio { $0.questions.append(contentsOf: values) }
          }
        }
        Button("Nhập bộ câu hỏi JSON", systemImage: "square.and.arrow.down") { importing = true }
        Button("Chia sẻ bộ câu hỏi", systemImage: "square.and.arrow.up") {
          do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(
              "MamStudy-questions-" + UUID().uuidString + ".json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(questions).write(to: url)
            shareURL = url
            share = true
          } catch { store.errorMessage = error.localizedDescription }
        }.disabled(questions.isEmpty)
      } label: {
        Image(systemName: "plus.circle")
      }
    }
    .sheet(item: $draft) { QuestionEditor(value: $0) }.sheet(isPresented: $test) { TimedTestView() }
    .sheet(isPresented: $share) { if let shareURL { ShareSheet(url: shareURL) } }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
      do {
        let url = try result.get()
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard
          (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 5 * 1024 * 1024
        else { throw StudyError.invalid("Bộ câu hỏi tối đa 5 MB.") }
        let values = try JSONDecoder().decode([PracticeQuestion].self, from: Data(contentsOf: url))
        var state = StudyState()
        state.studio.questions = values
        try WorkspaceValidation.validate(state)
        imported = values
        preview = true
      } catch { store.errorMessage = error.localizedDescription }
    }
    .sheet(isPresented: $preview) {
      NavigationStack {
        List {
          Text("\(imported.count) câu hỏi. Câu có cùng ID đã tồn tại sẽ được bỏ qua.")
          ForEach(imported.prefix(40)) { q in
            VStack(alignment: .leading) {
              Text(q.prompt).bold()
              Text(q.options[q.correctIndex]).foregroundStyle(.secondary)
            }
          }
        }.navigationTitle("Xem trước câu hỏi").toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Hủy") { preview = false } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Nhập") {
              let known = Set(store.state.studio.questions.map(\.id))
              if store.editStudio({
                $0.questions.append(contentsOf: imported.filter { !known.contains($0.id) })
              }) {
                preview = false
              }
            }
          }
        }
      }
    }
  }
}
struct QuestionEditor: View {
  @EnvironmentObject private var store: AppStore
  @State var value: PracticeQuestion
  private var valid: Bool {
    !value.prompt.trimmed.isEmpty && value.options.allSatisfy { !$0.trimmed.isEmpty }
      && Set(value.options.map(\.trimmed)).count == value.options.count
  }
  var body: some View {
    StudioEditor(
      title: "Câu hỏi", canSave: valid, save: { store.saveQuestion(value) },
      delete: store.state.studio.questions.contains(where: { $0.id == value.id })
        ? { store.editStudio { $0.questions.removeAll { $0.id == value.id } } } : nil
    ) {
      TextField("Môn học", text: $value.subject)
      TextField("Chương", text: $value.chapter)
      TextField("Câu hỏi", text: $value.prompt, axis: .vertical).lineLimit(3...12)
      Section("Các lựa chọn") {
        ForEach(value.options.indices, id: \.self) { i in
          HStack {
            Button {
              value.correctIndex = i
            } label: {
              Image(systemName: value.correctIndex == i ? "checkmark.circle.fill" : "circle")
            }.buttonStyle(.plain).accessibilityLabel("Đặt đáp án đúng \(i+1)")
            TextField("Lựa chọn \(i+1)", text: $value.options[i], axis: .vertical)
          }
        }
      }
      Section("Giải thích đáp án") { TextEditor(text: $value.explanation).frame(minHeight: 120) }
    }
  }
}
struct TimedTestView: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  @State private var now = Date()
  @State private var submit = false
  @State private var result: PracticeAttempt?
  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  var body: some View {
    NavigationStack {
      Group {
        if let result {
          TestResultView(attempt: result)
        } else if let t = store.state.studio.runningTest, t.answers.indices.contains(t.position) {
          let a = t.answers[t.position]
          PaperPage {
            HStack {
              Text("Câu \(t.position+1) / \(t.answers.count)")
              Spacer()
              Text(t.deadline, style: .timer).monospacedDigit().foregroundStyle(
                t.deadline.timeIntervalSince(now) < 60 ? .red : Pencil.green)
            }.font(.headline)
            ProgressView(
              value: Double(t.answers.filter { $0.selectedIndex != nil }.count),
              total: Double(t.answers.count))
            PaperCard(color: .butter) {
              Text(a.question.prompt).font(.title3.bold()).frame(minHeight: 90, alignment: .leading)
            }
            ForEach(a.question.options.indices, id: \.self) { i in
              Button {
                store.answerTest(i)
              } label: {
                HStack {
                  Image(systemName: a.selectedIndex == i ? "checkmark.circle.fill" : "circle")
                  Text(a.question.options[i]).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(16).background(
                  a.selectedIndex == i ? InkColor.sage.wash : Pencil.surface,
                  in: RoundedRectangle(cornerRadius: 18))
              }.buttonStyle(SoftPressStyle())
            }
            HStack {
              Button("Câu trước") { move(-1) }.disabled(t.position == 0)
              Spacer()
              Button("Câu sau") { move(1) }.disabled(t.position == t.answers.count - 1)
            }.padding(.vertical)
            Button("Nộp bài") { submit = true }.buttonStyle(PencilButtonStyle())
            Text("Bạn có thể đóng để làm tiếp; đồng hồ vẫn chạy.").font(.caption).foregroundStyle(
              .secondary)
          }
        } else {
          ContentUnavailableView("Bài thi đã kết thúc", systemImage: "checkmark.circle")
        }
      }.navigationTitle("Thi thử").navigationBarTitleDisplayMode(.inline).toolbar {
        Button("Đóng") { dismiss() }
      }
      .confirmationDialog("Nộp bài và chấm điểm?", isPresented: $submit, titleVisibility: .visible)
      { Button("Nộp bài") { finish() } }
      .onReceive(timer) {
        now = $0
        if let t = store.state.studio.runningTest, t.deadline <= now { finish() }
      }
      .onAppear { if let t = store.state.studio.runningTest, t.deadline <= Date() { finish() } }
    }
  }
  private func move(_ step: Int) {
    _ = store.editStudio {
      guard var t = $0.runningTest else { return }
      t.position = max(0, min(t.answers.count - 1, t.position + step))
      $0.runningTest = t
    }
  }
  private func finish() {
    let id = store.state.studio.runningTest?.id
    store.finishTest()
    result = store.state.studio.attempts.first { $0.id == id }
  }
}
struct TestResultView: View {
  let attempt: PracticeAttempt
  var body: some View {
    PaperPage {
      PaperCard(color: .sage) {
        VStack(alignment: .leading, spacing: 10) {
          Text(attempt.score / 100, format: .percent.precision(.fractionLength(0))).font(
            .system(size: 48, weight: .bold, design: .rounded)
          ).contentTransition(.numericText())
          Text("\(attempt.answers.filter(\.correct).count) / \(attempt.answers.count) câu đúng")
          Text(attempt.finishedAt, format: .dateTime.day().month().year().hour().minute()).font(
            .caption)
        }
      }
      ForEach(attempt.answers) { a in
        PaperCard(color: a.correct ? .sage : .peach) {
          VStack(alignment: .leading, spacing: 8) {
            Label(
              a.question.prompt,
              systemImage: a.correct ? "checkmark.circle" : "arrow.counterclockwise"
            ).font(.headline)
            Text(
              "Bạn chọn: "
                + (a.selectedIndex.flatMap {
                  a.question.options.indices.contains($0) ? a.question.options[$0] : nil
                } ?? "Chưa trả lời"))
            Text("Đáp án: " + a.question.options[a.question.correctIndex]).bold()
            if !a.question.explanation.isEmpty { Text(a.question.explanation).font(.subheadline) }
          }
        }
      }
    }.navigationTitle(attempt.title)
  }
}
struct PracticeHistoryView: View {
  @EnvironmentObject private var store: AppStore
  private var groups: [String: [PracticeAnswer]] {
    Dictionary(
      grouping: store.state.studio.attempts.flatMap(\.answers),
      by: {
        [$0.question.subject, $0.question.chapter].filter { !$0.isEmpty }.joined(separator: " • ")
      })
  }
  var body: some View {
    PaperPage {
      SectionTitle(title: "Theo chương", caption: "Tỉ lệ đúng trên các lần làm bài đã lưu")
      ForEach(groups.keys.sorted(), id: \.self) { key in
        let values = groups[key] ?? []
        PaperCard {
          HStack {
            Text(key.isEmpty ? "Chưa phân loại" : key)
            Spacer()
            Text(
              Double(values.filter(\.correct).count) / Double(max(1, values.count)),
              format: .percent.precision(.fractionLength(0)))
          }
        }
      }
      SectionTitle(title: "Lịch sử thi thử")
      if store.state.studio.attempts.isEmpty {
        Text("Chưa có bài thi đã nộp.").foregroundStyle(.secondary)
      }
      ForEach(store.state.studio.attempts.sorted { $0.finishedAt > $1.finishedAt }) { a in
        NavigationLink {
          TestResultView(attempt: a)
        } label: {
          PaperCard {
            HStack {
              VStack(alignment: .leading) {
                Text(a.title).bold()
                Text(a.finishedAt, format: .dateTime.day().month().hour().minute()).font(.caption)
              }
              Spacer()
              Text(a.score / 100, format: .percent.precision(.fractionLength(0)))
            }
          }
        }.buttonStyle(SoftPressStyle())
      }
    }.navigationTitle("Kết quả luyện tập")
  }
}
struct MistakeBookView: View {
  @EnvironmentObject private var store: AppStore
  @State private var test = false
  private var mistakes: [PracticeQuestion] {
    var latest: [UUID: PracticeAnswer] = [:]
    for a in store.state.studio.attempts.sorted(by: { $0.finishedAt < $1.finishedAt }) {
      for answer in a.answers { latest[answer.id] = answer }
    }
    return latest.values.filter { !$0.correct }.map(\.question).sorted { $0.prompt < $1.prompt }
  }
  var body: some View {
    PaperPage {
      SectionTitle(
        title: "Chăm lại phần chưa vững",
        caption: "Một câu rời sổ lỗi khi lần làm gần nhất của bạn đúng.")
      Button(store.state.studio.runningTest == nil ? "Ôn lại câu sai" : "Tiếp tục bài đang làm") {
        if store.state.studio.runningTest == nil {
          store.startTest(
            mistakes, minutes: max(5, min(180, mistakes.count * 2)), title: "Ôn lỗi sai")
        }
        test = store.state.studio.runningTest != nil
      }.disabled(mistakes.isEmpty && store.state.studio.runningTest == nil).buttonStyle(
        PencilButtonStyle())
      ForEach(mistakes) { q in
        PaperCard(color: .peach) {
          VStack(alignment: .leading, spacing: 8) {
            Text(q.prompt).bold()
            Text(q.options[q.correctIndex])
            Text(q.explanation).font(.caption)
          }
        }
      }
      if mistakes.isEmpty { Text("Chưa có câu cần ôn lại.").foregroundStyle(.secondary) }
    }.navigationTitle("Sổ lỗi sai").sheet(isPresented: $test) { TimedTestView() }
  }
}
