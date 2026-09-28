import SwiftUI

struct JournalView: View {
  @EnvironmentObject private var store: AppStore
  @State private var draft: LearningJournal?
  @State private var search = ""
  var body: some View {
    PaperPage {
      SectionTitle(
        title: "Một dòng cũng là tiến bộ",
        caption: "Nhật ký không cộng thêm XP để tránh tính trùng phiên học.")
      let entries = store.state.studio.journals.filter {
        search.isEmpty
          || ($0.learned + $0.subject + $0.nextStep).localizedCaseInsensitiveContains(search)
      }.sorted { $0.date > $1.date }
      if entries.isEmpty {
        EmptyPageCard(
          symbol: "book", title: "Trang hôm nay còn trống",
          detail: "Ghi điều bạn đã hiểu và một việc nhỏ cho buổi sau.")
      }
      ForEach(entries) { entry in
        Button {
          draft = entry
        } label: {
          PaperCard(color: .butter) {
            VStack(alignment: .leading, spacing: 10) {
              HStack {
                Text(entry.date, style: .date).font(.caption)
                Spacer()
                Text(["☁️", "🌥️", "🌤️", "☀️", "🌈"][max(0, min(4, entry.mood - 1))])
              }
              Text(entry.subject.isEmpty ? "Nhật ký học" : entry.subject).font(.headline)
              Text(entry.learned).lineLimit(6)
              if !entry.nextStep.isEmpty {
                Label(entry.nextStep, systemImage: "arrow.turn.down.right").font(.subheadline)
              }
              Text("\(entry.minutes) phút").font(.caption.bold())
            }
          }
        }.buttonStyle(SoftPressStyle())
      }
    }.navigationTitle(store.t("Nhật ký học", "Learning journal")).searchable(text: $search).toolbar
    {
      Button {
        draft = LearningJournal()
      } label: {
        Image(systemName: "plus")
      }
    }.sheet(item: $draft) { JournalEditor(value: $0) }
  }
}
struct JournalEditor: View {
  @EnvironmentObject private var store: AppStore
  @State var value: LearningJournal
  var body: some View {
    StudioEditor(
      title: "Một trang nhỏ", canSave: !value.learned.trimmed.isEmpty,
      save: { store.saveJournal(value) },
      delete: { store.editStudio { $0.journals.removeAll { $0.id == value.id } } }
    ) {
      DatePicker("Ngày", selection: $value.date, displayedComponents: .date)
      TextField("Môn học", text: $value.subject)
      TextField("Hôm nay đã hiểu điều gì?", text: $value.learned, axis: .vertical).lineLimit(4...12)
      TextField("Bước tiếp theo", text: $value.nextStep, axis: .vertical)
      Stepper("Thời gian: \(value.minutes) phút", value: $value.minutes, in: 0...1440, step: 5)
      Button("Lấy phút tập trung đã ghi nhận ngày này") {
        value.minutes = Int(
          StudyStats.daily(store.state.sessions, ending: value.date, days: 1).first?.minutes ?? 0)
      }
      Picker("Cảm giác buổi học", selection: $value.mood) {
        ForEach(1...5, id: \.self) { Text(["☁️", "🌥️", "🌤️", "☀️", "🌈"][$0 - 1]).tag($0) }
      }.pickerStyle(.segmented)
    }
  }
}
struct GoalsView: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.mamReduceMotion) private var reduce
  @State private var draft: LearningGoal?
  @State private var celebrate: UUID?
  var body: some View {
    PaperPage {
      Text(
        store.t(
          "Chọn nhịp học vừa sức. Mầm lớn từ những lần quay lại.",
          "Choose a comfortable pace. Growth comes from returning.")
      ).font(.title3)
      if store.state.studio.goals.isEmpty {
        EmptyPageCard(
          symbol: "flag", title: "Một đích đến nho nhỏ",
          detail: "Ví dụ: ôn 5 chương tuần này hoặc tập trung 120 phút.")
      }
      ForEach(store.state.studio.goals.sorted { $0.end < $1.end }) { goal in
        let amount = WorkspaceEngine.goalProgress(goal, state: store.state)
        PaperCard(color: amount >= goal.target ? .sage : .butter) {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text(goal.title).font(.headline)
              Spacer()
              Button {
                draft = goal
              } label: {
                Image(systemName: "pencil")
              }.accessibilityLabel("Sửa mục tiêu")
            }
            HStack {
              Text("\(amount) / \(goal.target)").font(
                .system(.title, design: .rounded, weight: .bold)
              ).contentTransition(.numericText())
              Text(LocalizedStringKey(goal.unit.title)).font(.caption)
            }
            ProgressView(value: Double(min(amount, goal.target)), total: Double(goal.target)).tint(
              Pencil.green)
            Text(goal.end, style: .date).font(.caption)
            if goal.unit == .chapters && Date() >= goal.start && Date() < goal.end {
              Button("Thêm một chương đã ôn", systemImage: "plus.circle") {
                var changed = goal
                changed.manualProgress += 1
                withAnimation(reduce ? nil : .spring(response: 0.45, dampingFraction: 0.7)) {
                  if store.saveGoal(changed) && amount < goal.target
                    && changed.manualProgress >= goal.target
                  {
                    celebrate = goal.id
                    StudyHaptics.success(enabled: store.state.preferences.haptics)
                  }
                }
              }.disabled(goal.manualProgress >= 100000)
            }
            if amount >= goal.target {
              Label("Bạn đã đến đích!", systemImage: "checkmark.seal.fill").foregroundStyle(
                Pencil.green)
            }
          }.overlay { if celebrate == goal.id { LeafCelebration().id(goal.id) } }
        }
      }
    }.navigationTitle(store.t("Mục tiêu", "Goals")).toolbar {
      Button {
        draft = LearningGoal()
      } label: {
        Image(systemName: "plus")
      }
    }.sheet(item: $draft) { GoalEditor(value: $0) }
  }
}
struct GoalEditor: View {
  @EnvironmentObject private var store: AppStore
  @State var value: LearningGoal
  var body: some View {
    StudioEditor(
      title: "Mục tiêu học", canSave: !value.title.trimmed.isEmpty && value.end > value.start,
      save: { store.saveGoal(value) },
      delete: { store.editStudio { $0.goals.removeAll { $0.id == value.id } } }
    ) {
      TextField("Tên mục tiêu", text: $value.title)
      Picker("Đơn vị", selection: $value.unit) {
        ForEach(GoalUnit.allCases) { Text(LocalizedStringKey($0.title)).tag($0) }
      }
      Stepper("Mục tiêu: \(value.target)", value: $value.target, in: 1...100000)
      if value.unit == .chapters {
        Stepper("Đã ôn: \(value.manualProgress)", value: $value.manualProgress, in: 0...100000)
      }
      DatePicker("Từ", selection: $value.start)
      DatePicker("Đến", selection: $value.end)
      Text(
        "Phút, thẻ khác nhau và việc hoàn thành được tính tự động trong khoảng thời gian này. Số chương do bạn đánh dấu."
      ).font(.footnote)
    }
  }
}
