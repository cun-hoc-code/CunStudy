import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
  @EnvironmentObject private var store: AppStore
  @EnvironmentObject private var reminders: ReminderService
  @EnvironmentObject private var activity: FocusActivityService
  @Environment(\.dismiss) private var dismiss
  @State private var preferences = Preferences()
  @State private var shareURL: URL?
  @State private var importing = false
  @State private var pendingImport: StudyState?
  @State private var restoreConfirm = false
  @State private var previousConfirm = false
  @State private var beforeImportConfirm = false
  @State private var message: String?
  var body: some View {
    NavigationStack {
      Form {
        Section {
          NavigationLink {
            ConnectionsView()
          } label: {
            Label("Kết nối, bảo mật & sao lưu đầy đủ", systemImage: "externaldrive.badge.icloud")
          }
        }
        Section("Giao diện & cảm giác") {
          Picker(
            "Chế độ hiển thị",
            selection: Binding(
              get: { store.state.preferences.appearance },
              set: { new in
                if store.change({ $0.preferences.appearance = new }) {
                  preferences.appearance = new
                }
              })
          ) { ForEach(AppAppearance.allCases) { Text(LocalizedStringKey($0.title)).tag($0) } }
          Toggle(
            "Rung nhẹ khi tương tác",
            isOn: Binding(
              get: { store.state.preferences.haptics },
              set: { new in
                if store.change({ $0.preferences.haptics = new }) { preferences.haptics = new }
                StudyHaptics.selection(enabled: new)
              }))
          Text(
            "Rung khi lật thẻ, đổi tab, chấm thẻ và hoàn thành phiên. Hiệu ứng tự giảm khi bật Giảm chuyển động trên iPhone."
          ).font(.footnote).foregroundStyle(.secondary)
          NavigationLink {
            FeedbackSettingsView()
          } label: {
            Label("Âm thanh & độ rung chi tiết", systemImage: "waveform.and.speaker")
          }
        }
        Section("Nhịp học của mình") {
          TextField("Tên gọi", text: $preferences.name)
          Stepper(
            "Tập trung: \(preferences.dailyFocusMinutes) phút / ngày",
            value: $preferences.dailyFocusMinutes, in: 15...240, step: 15)
          Stepper(
            "Phiên mặc định: \(preferences.focusMinutes) phút", value: $preferences.focusMinutes,
            in: 5...120, step: 5)
          Stepper(
            "Giờ nghỉ: \(preferences.breakMinutes) phút", value: $preferences.breakMinutes,
            in: 1...30)
          Stepper(
            "Thẻ mới: \(preferences.newCardsPerDay) / ngày", value: $preferences.newCardsPerDay,
            in: 1...100)
          Stepper(
            "Mục tiêu ôn: \(preferences.dailyReviewGoal) thẻ / ngày",
            value: $preferences.dailyReviewGoal, in: 1...100)
          Button("Lưu thiết lập") {
            preferences.name = preferences.name.trimmed.isEmpty ? "Bạn" : preferences.name.trimmed
            if store.change({ $0.preferences = preferences }) { message = "Đã lưu thiết lập." }
          }
        }
        Section {
          Toggle(
            "Mầm trên màn hình khóa",
            isOn: Binding(
              get: { store.state.preferences.liveActivities },
              set: { new in
                if store.change({ $0.preferences.liveActivities = new }) {
                  preferences.liveActivities = new
                }
              })
          ).disabled(!WidgetStorage.isEnabled)
          Text(activity.message).font(.subheadline)
          Text(
            "Bắt đầu một phiên Tập trung để xem thời gian còn lại và mầm. Chạm vào hoạt động để trở lại phiên học."
          ).font(.footnote)
        } header: {
          Text("Hoạt động trực tiếp")
        } footer: {
          Text(
            "Cần bản đầy đủ có extension. Dynamic Island hiển thị trên máy hỗ trợ. Khi phiên kết thúc ở nền, đồng hồ về 0; mở app để lưu phiên và đóng hoạt động."
          )
        }
        Section {
          LabeledContent("Báo thức", value: reminders.alarmPermission)
          Button("Cho phép báo thức hệ thống") {
            Task {
              await reminders.requestAlarms()
              store.refresh()
            }
          }
          Button("Thử báo thức sau 30 giây") { Task { await reminders.testAlarm() } }
          LabeledContent("Thông báo", value: reminders.notificationPermission)
          Button("Cho phép thông báo") {
            Task {
              await reminders.requestNotifications()
              store.refresh()
            }
          }
          Button("Mở cài đặt iPhone") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          }
          Text(reminders.status).font(.footnote)
          ForEach(reminders.problems, id: \.self) { Text($0).font(.footnote).foregroundStyle(.red) }
        } header: {
          Text("Nhắc đi học")
        } footer: {
          Text(
            "Báo thức thật dùng AlarmKit trên iOS 26+, cần bạn cấp quyền. Hãy thử khi khóa màn hình và tắt app trước buổi học đầu tiên. Máy hết pin hoặc tắt nguồn không thể phát báo thức từ app. Thông báo thường không thay thế báo thức."
          )
        }
        Section {
          Text(store.widgetMessage).font(.subheadline)
          if WidgetStorage.isEnabled {
            Button("Gửi lại dữ liệu cho widget") { store.publishSnapshot() }.disabled(
              store.readOnly)
            Text(
              "Nhấn giữ màn hình chính → Sửa → Thêm tiện ích → Mầm. Chọn Lịch tiếp theo, Deadline hoặc Nhịp học."
            ).font(.footnote)
          }
        } header: {
          Text("Widget màn hình chính")
        } footer: {
          Text(
            "Sau mỗi lần lưu lịch, Mầm gửi dữ liệu mới và yêu cầu iOS cập nhật widget. iOS có thể trì hoãn thời điểm vẽ lại. Bản ký phải giữ widget extension và quyền App Groups phù hợp."
          )
        }
        Section {
          Button("Xuất bản sao lưu JSON") {
            do { shareURL = try store.exportData() } catch { message = error.localizedDescription }
          }
          Button("Nhập bản sao lưu") { importing = true }
          Button("Khôi phục bản lưu trước đó") { previousConfirm = true }
          Button("Lấy lại dữ liệu trước lần nhập gần nhất") { beforeImportConfirm = true }
          if store.state.lessons.isEmpty && store.state.tasks.isEmpty && store.state.cards.isEmpty
            && store.state.notes.isEmpty
          {
            Button("Thử dữ liệu mẫu") { store.addDemo() }
          }
        } header: {
          Text("Dữ liệu của bạn")
        } footer: {
          Text(
            "Lưu file sao lưu vào ứng dụng Tệp hoặc iCloud Drive tùy bạn chọn. Mầm chưa có đồng bộ iCloud tự động. App mới có dữ liệu độc lập với StudyFlow cũ."
          )
        }
        Section("Về Mầm") {
          Text("Phiên bản 2.1 • Mỗi ngày, lớn thêm một chút")
          Text("Không quảng cáo, không tài khoản, không dịch vụ phân tích gửi ra ngoài.").font(
            .footnote)
          Text(
            "Ôn tập dùng thuật toán giãn cách lấy cảm hứng từ SM-2 với bước học ngắn. Không phải FSRS của Anki và không có bảo đảm nhớ nhanh hơn cho mọi người."
          ).font(.footnote)
          Text(
            "Streak: mỗi ngày có ít nhất 5 phút tập trung đã lưu hoặc ôn 5 thẻ khác nhau. Không mất chuỗi khi hôm nay vẫn chưa kết thúc."
          ).font(.footnote)
        }
      }
      .navigationTitle("Cài đặt").navigationBarTitleDisplayMode(.inline)
      .toolbar { Button("Xong") { dismiss() } }
      .onAppear {
        preferences = store.state.preferences
        Task { await reminders.updatePermissionLabels() }
      }
      .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
        if let shareURL { ActivityShare(url: shareURL) }
      }
      .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
        do {
          pendingImport = try store.readImport(result.get())
          restoreConfirm = true
        } catch { message = error.localizedDescription }
      }
      .confirmationDialog(
        "Thay dữ liệu hiện tại bằng bản sao lưu?", isPresented: $restoreConfirm,
        titleVisibility: .visible
      ) {
        Button("Khôi phục dữ liệu", role: .destructive) {
          if let pendingImport {
            store.restore(pendingImport)
            preferences = store.state.preferences
          }
          pendingImport = nil
        }
        Button("Hủy", role: .cancel) { pendingImport = nil }
      } message: {
        Text(
          "Bản dữ liệu hiện tại được giữ thành file phục hồi trước khi thay thế. Phiên tập trung nhập vào sẽ ở trạng thái tạm dừng."
        )
      }
      .confirmationDialog(
        "Khôi phục bản lưu trước lần thay đổi gần nhất?", isPresented: $previousConfirm,
        titleVisibility: .visible
      ) {
        Button("Khôi phục", role: .destructive) {
          store.restorePrevious()
          preferences = store.state.preferences
        }
      }
      .confirmationDialog(
        "Lấy lại dữ liệu trước lần nhập gần nhất?", isPresented: $beforeImportConfirm,
        titleVisibility: .visible
      ) {
        Button("Lấy lại dữ liệu", role: .destructive) {
          store.restoreBeforeImport()
          preferences = store.state.preferences
        }
      }
      .alert(
        "Mầm", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
      ) {
        Button("OK") { message = nil }
      } message: {
        Text(message ?? "")
      }
    }
  }
}

private struct ActivityShare: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
