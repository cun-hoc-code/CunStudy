import Charts
import SwiftUI

private func money(_ amount: Int64) -> String {
  amount.formatted(.currency(code: "VND").precision(.fractionLength(0)))
}
struct WalletView: View {
  @EnvironmentObject private var store: AppStore
  @State private var month = Date()
  @State private var expense: Expense?
  @State private var bill: SharedBill?
  private var expenses: [Expense] {
    store.state.studio.expenses.filter {
      Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month)
    }
  }
  var body: some View {
    PaperPage {
      DatePicker("Tháng", selection: $month, displayedComponents: .date)
      let total = expenses.reduce(Int64(0)) { $0 + $1.amount }
      let budget = store.state.studio.settings.monthlyBudget
      PaperCard(color: .rose) {
        VStack(alignment: .leading, spacing: 12) {
          Text("Đã chi tháng này").font(.caption)
          Text(money(total)).font(.system(.largeTitle, design: .rounded, weight: .bold))
            .contentTransition(.numericText())
          ProgressView(value: Double(min(total, max(1, budget))), total: Double(max(1, budget)))
            .tint(total > budget ? .orange : Pencil.green)
          HStack {
            Text("Ngân sách VND")
            TextField(
              "Ngân sách",
              value: Binding(
                get: { budget },
                set: { v in _ = store.editStudio { $0.settings.monthlyBudget = v } }),
              format: .number
            ).keyboardType(.numberPad).multilineTextAlignment(.trailing)
          }
          Text(total <= budget ? "Còn \(money(budget-total))" : "Vượt \(money(total-budget))")
            .bold()
        }
      }
      let categories = Dictionary(grouping: expenses, by: \.category).map {
        (name: $0.key, value: $0.value.reduce(Int64(0)) { $0 + $1.amount })
      }.sorted { $0.value > $1.value }
      if !categories.isEmpty {
        Chart(categories, id: \.name) { item in
          BarMark(x: .value("VND", item.value), y: .value("Mục", item.name)).foregroundStyle(
            Pencil.green.gradient
          ).cornerRadius(6)
        }.frame(height: CGFloat(max(130, categories.count * 38))).accessibilityLabel(
          "Chi tiêu theo nhóm")
      }
      SectionTitle(
        title: "Khoản chi", caption: "Chia tiền nhóm được theo dõi riêng để tránh tính hai lần.")
      ForEach(expenses.sorted { $0.date > $1.date }) { v in
        Button {
          expense = v
        } label: {
          PaperCard {
            HStack {
              VStack(alignment: .leading, spacing: 5) {
                Text(v.title).font(.headline)
                Text(v.category + " · " + v.date.formatted(.dateTime.day().month())).font(.caption)
              }
              Spacer()
              Text(money(v.amount)).bold()
            }
          }
        }.buttonStyle(SoftPressStyle())
      }
      SectionTitle(title: "Chia tiền cùng nhóm")
      ForEach(store.state.studio.bills.sorted { $0.date > $1.date }) { v in
        Button {
          bill = v
        } label: {
          PaperCard(color: .butter) {
            VStack(alignment: .leading, spacing: 9) {
              HStack {
                Text(v.title).font(.headline)
                Spacer()
                Text(money(v.amount)).bold()
              }
              Text("\(v.payer) đã trả").font(.caption)
              ForEach(WorkspaceEngine.shares(v), id: \.name) { share in
                HStack {
                  Text(share.name)
                  Spacer()
                  Text(money(share.amount))
                  Image(
                    systemName: share.name == v.payer || v.settledMembers.contains(share.name)
                      ? "checkmark.circle.fill" : "circle")
                }.font(.caption)
              }
            }
          }
        }.buttonStyle(SoftPressStyle())
      }
      if expenses.isEmpty && store.state.studio.bills.isEmpty {
        EmptyPageCard(
          symbol: "wallet.pass", title: "Chi tiêu rõ ràng hơn",
          detail: "Ghi khoản chi ăn uống, photo tài liệu hoặc khoản chung của nhóm.")
      }
    }.navigationTitle(store.t("Ví sinh viên", "Student wallet")).toolbar {
      Menu {
        Button("Khoản chi") { expense = Expense() }
        Button("Chia tiền nhóm") { bill = SharedBill() }
      } label: {
        Image(systemName: "plus")
      }
    }.sheet(item: $expense) { ExpenseEditor(value: $0) }.sheet(item: $bill) {
      BillEditor(value: $0)
    }
  }
}
struct ExpenseEditor: View {
  @EnvironmentObject private var store: AppStore
  @State var value: Expense
  var body: some View {
    StudioEditor(
      title: "Khoản chi", canSave: !value.title.trimmed.isEmpty && value.amount >= 0,
      save: { store.saveExpense(value) },
      delete: { store.editStudio { $0.expenses.removeAll { $0.id == value.id } } }
    ) {
      TextField("Nội dung", text: $value.title)
      TextField("Nhóm chi tiêu", text: $value.category)
      TextField("Số tiền VND", value: $value.amount, format: .number).keyboardType(.numberPad)
      DatePicker("Ngày chi", selection: $value.date, displayedComponents: .date)
    }
  }
}
struct BillEditor: View {
  @EnvironmentObject private var store: AppStore
  @State var value: SharedBill
  @State private var names = ""
  var body: some View {
    StudioEditor(
      title: "Chia tiền nhóm",
      canSave: !value.title.trimmed.isEmpty && value.members.contains(value.payer),
      save: { store.saveBill(value) },
      delete: { store.editStudio { $0.bills.removeAll { $0.id == value.id } } }
    ) {
      TextField("Tên khoản chung", text: $value.title)
      TextField("Tổng tiền VND", value: $value.amount, format: .number).keyboardType(.numberPad)
      TextField("Thành viên, cách nhau bằng dấu phẩy", text: $names, axis: .vertical).onChange(
        of: names
      ) { _, new in
        value.members = new.components(separatedBy: ",").map(\.trimmed).filter { !$0.isEmpty }
        value.settledMembers = value.settledMembers.filter { value.members.contains($0) }
      }
      Picker("Người đã trả", selection: $value.payer) {
        Text("Chọn người trả").tag("")
        ForEach(Array(Set(value.members)).sorted(), id: \.self) { Text($0).tag($0) }
      }
      DatePicker("Ngày", selection: $value.date, displayedComponents: .date)
      Section("Chia đều · phần lẻ chia theo thứ tự tên") {
        ForEach(Array(WorkspaceEngine.shares(value).enumerated()), id: \.offset) { _, share in
          if share.name == value.payer {
            LabeledContent(share.name, value: money(share.amount) + " · đã trả")
          } else {
            Toggle(
              share.name + " · " + money(share.amount),
              isOn: Binding(
                get: { value.settledMembers.contains(share.name) },
                set: {
                  if $0 {
                    if !value.settledMembers.contains(share.name) {
                      value.settledMembers.append(share.name)
                    }
                  } else {
                    value.settledMembers.removeAll { $0 == share.name }
                  }
                }))
          }
        }
      }
    }.onAppear { names = value.members.joined(separator: ", ") }
  }
}
