import SwiftUI

struct AcademicsView: View {
  @EnvironmentObject private var store: AppStore
  @State private var draft: AcademicCourse?
  @State private var semester = ""
  @State private var grade = 3.0
  @State private var credits = 3
  private var courses: [AcademicCourse] { store.state.studio.courses }
  var body: some View {
    PaperPage {
      let completed = courses.filter { $0.passed && !$0.needsRetake }.reduce(0) { $0 + $1.credits }
      let needed = store.state.studio.settings.graduationCredits
      PaperCard(color: .sky) {
        VStack(alignment: .leading, spacing: 12) {
          Text("CPA / GPA tích lũy").font(.caption)
          Text(WorkspaceEngine.gpa(courses).map { String(format: "%.2f", $0) } ?? "—").font(
            .system(size: 44, weight: .bold, design: .rounded)
          ).contentTransition(.numericText())
          Text("\(completed) / \(needed) tín chỉ tốt nghiệp").font(.subheadline.bold())
          ProgressView(value: Double(min(completed, needed)), total: Double(needed)).tint(
            Pencil.green)
          Stepper(
            "Chương trình: \(needed) tín chỉ",
            value: Binding(
              get: { needed },
              set: { v in _ = store.editStudio { $0.settings.graduationCredits = v } }),
            in: 1...1000)
          Text(
            "Nhập điểm hệ 4 theo quy định trường. Mỗi môn nên là kết quả được trường công nhận hiện tại; không tự quy đổi hoặc áp chính sách học lại."
          ).font(.caption)
        }
      }
      PaperCard(color: .lavender) {
        VStack(alignment: .leading, spacing: 12) {
          SectionTitle(title: "Nếu môn tiếp theo được…")
          Slider(value: $grade, in: 0...4, step: 0.1) { Text("Điểm hệ 4") }
          Stepper("\(credits) tín chỉ · \(grade,specifier:"%.1f") / 4", value: $credits, in: 1...30)
          let simulated = AcademicCourse(name: "Mô phỏng", credits: credits, officialGrade4: grade)
          Text("CPA dự kiến: \(WorkspaceEngine.gpa(courses+[simulated]) ?? 0,specifier:"%.2f")")
            .font(.title3.bold()).contentTransition(.numericText())
          Text("Mô phỏng không thay đổi bảng điểm đã lưu.").font(.caption)
        }
      }
      Picker("Học kỳ", selection: $semester) {
        Text("Tất cả").tag("")
        ForEach(Array(Set(courses.map(\.semester))).filter { !$0.isEmpty }.sorted(), id: \.self) {
          Text($0).tag($0)
        }
      }
      if !semester.isEmpty {
        Text(
          "GPA học kỳ: \(WorkspaceEngine.gpa(courses.filter{$0.semester==semester}).map{String(format:"%.2f",$0)} ?? "—")"
        ).font(.headline)
      }
      ForEach(courses.filter { semester.isEmpty || $0.semester == semester }) { course in
        Button {
          draft = course
        } label: {
          PaperCard(color: course.needsRetake ? .peach : nil) {
            HStack {
              VStack(alignment: .leading, spacing: 6) {
                Text(course.name).font(.headline)
                Text("\(course.code) · \(course.credits) tín chỉ · \(course.semester)").font(
                  .caption)
                if course.needsRetake {
                  Label("Cần học lại", systemImage: "arrow.counterclockwise").font(.caption)
                }
                if let score = WorkspaceEngine.finalScore(course) {
                  Text("Tổng kết: \(score,specifier:"%.2f") / 10").font(.caption)
                }
              }
              Spacer()
              Text(course.officialGrade4.map { String(format: "%.1f", $0) } ?? "—").font(
                .title2.bold())
            }
          }
        }.buttonStyle(SoftPressStyle())
      }
      if courses.isEmpty {
        EmptyPageCard(
          symbol: "graduationcap", title: "Bản đồ hành trình học",
          detail: "Thêm môn, tín chỉ và điểm thành phần để dự báo phần điểm còn lại.")
      }
    }.navigationTitle(store.t("Điểm & tín chỉ", "Grades & credits")).toolbar {
      Button {
        var c = AcademicCourse()
        c.components = [
          GradeComponent(title: "Quá trình", weight: 40),
          GradeComponent(title: "Cuối kỳ", weight: 60),
        ]
        draft = c
      } label: {
        Image(systemName: "plus")
      }
    }.sheet(item: $draft) { CourseEditor(value: $0) }
  }
}
struct CourseEditor: View {
  @EnvironmentObject private var store: AppStore
  @State var value: AcademicCourse
  @State private var target = 5.0
  var body: some View {
    StudioEditor(
      title: "Bảng điểm môn", canSave: !value.name.trimmed.isEmpty,
      save: { store.saveCourse(value) },
      delete: { store.editStudio { $0.courses.removeAll { $0.id == value.id } } }
    ) {
      Section("Môn học") {
        TextField("Tên môn", text: $value.name)
        TextField("Mã môn", text: $value.code)
        TextField("Học kỳ", text: $value.semester)
        Stepper("\(value.credits) tín chỉ", value: $value.credits, in: 1...100)
      }
      Section("Điểm thành phần · hệ 10") {
        ForEach($value.components) { $part in
          VStack(alignment: .leading, spacing: 8) {
            TextField("Tên thành phần", text: $part.title)
            HStack {
              Text("Trọng số %")
              TextField("%", value: $part.weight, format: .number).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            Toggle(
              "Đã có điểm",
              isOn: Binding(get: { part.score != nil }, set: { part.score = $0 ? 0 : nil }))
            if part.score != nil {
              TextField(
                "Điểm / 10", value: Binding(get: { part.score ?? 0 }, set: { part.score = $0 }),
                format: .number
              ).keyboardType(.decimalPad)
            }
          }
        }.onDelete { value.components.remove(atOffsets: $0) }
        Button("Thêm thành phần") { value.components.append(GradeComponent()) }
        Text("Tổng trọng số: \(value.components.reduce(0){$0+$1.weight},specifier:"%.0f")% / 100%")
      }
      Section("Cần bao nhiêu điểm?") {
        Slider(value: $target, in: 0...10, step: 0.1) { Text("Điểm mục tiêu") }
        Text("Mục tiêu tổng kết: \(target,specifier:"%.1f") / 10")
        if let required = WorkspaceEngine.requiredScore(value, target: target) {
          Text(
            required > 10
              ? "Mục tiêu vượt khả năng của các phần còn lại."
              : "Cần trung bình \(String(format:"%.2f",required)) / 10 ở các phần chưa có điểm."
          ).font(.headline)
        } else {
          Text("Cần tổng trọng số 100% và còn phần chưa có điểm để dự báo.").font(.footnote)
        }
        Text(
          "Điểm qua môn tùy trường, có thể kèm điều kiện điểm thi tối thiểu. Bạn tự đặt mục tiêu phù hợp."
        ).font(.caption)
      }
      Section("Kết quả chính thức") {
        Toggle(
          "Đã có điểm hệ 4",
          isOn: Binding(
            get: { value.officialGrade4 != nil }, set: { value.officialGrade4 = $0 ? 0 : nil }))
        if value.officialGrade4 != nil {
          TextField(
            "Điểm / 4",
            value: Binding(get: { value.officialGrade4 ?? 0 }, set: { value.officialGrade4 = $0 }),
            format: .number
          ).keyboardType(.decimalPad)
        }
        Toggle("Đã tích lũy tín chỉ", isOn: $value.passed)
        Toggle("Cần học lại / còn nợ", isOn: $value.needsRetake)
      }
    }
  }
}
