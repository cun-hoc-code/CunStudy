import SwiftUI
import UniformTypeIdentifiers

actor BackupWorker {
  static let shared = BackupWorker()
  func export(_ data: Data) throws -> URL {
    let state = try StateCodec.decode(data)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "MamStudy-" + UUID().uuidString + ".mamstudy")
    try FileVault.current.backup(state, to: url)
    return url
  }
  func read(_ url: URL) throws -> Data {
    if url.pathExtension.lowercased() == "mamstudy" {
      return try StateCodec.encode(FileVault.current.readBackup(url))
    }
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 25 * 1024 * 1024
    else { throw StudyError.invalid("JSON tối đa 25 MB.") }
    var state = try StateCodec.decode(Data(contentsOf: url))
    state.studio.settings.appLock = false
    return try StateCodec.encode(StateCodec.restoredSnapshot(state))
  }
}
struct ConnectionsView: View {
  @EnvironmentObject private var store: AppStore
  @State private var busy = false
  @State private var importing = false
  @State private var share = false
  @State private var shareURL: URL?
  @State private var pending: StudyState?
  @State private var confirm = false
  @State private var lockBusy = false
  @State private var lockMessage = ""
  var body: some View {
    Form {
      Section("Trải nghiệm") {
        Picker(
          "Ngôn ngữ",
          selection: Binding(
            get: { store.state.studio.settings.language },
            set: { value in _ = store.editStudio { $0.settings.language = value } })
        ) {
          Text("Tiếng Việt").tag("vi")
          Text("English").tag("en")
        }
        Toggle(
          "Giảm chuyển động",
          isOn: Binding(
            get: { store.state.studio.settings.reduceMotion },
            set: { value in _ = store.editStudio { $0.settings.reduceMotion = value } }))
        LayoutPicker()
        Toggle(
          "Khóa bằng Face ID / mật mã",
          isOn: Binding(
            get: { store.state.studio.settings.appLock },
            set: { value in
              if value {
                lockBusy = true
                Task {
                  if await PrivacyLock.shared.verify() {
                    _ = store.editStudio { $0.settings.appLock = true }
                  } else {
                    lockMessage = PrivacyLock.shared.message
                  }
                  lockBusy = false
                }
              } else {
                _ = store.editStudio { $0.settings.appLock = false }
              }
            })
        ).disabled(lockBusy)
        if !lockMessage.isEmpty { Text(lockMessage).font(.caption) }
      }
      Section("Nhắc nhịp học") {
        Toggle(
          "Nhắc giữ streak",
          isOn: Binding(
            get: { store.state.studio.settings.streakReminder },
            set: { value in
              _ = store.editStudio { $0.settings.streakReminder = value }
              if value {
                Task {
                  await store.reminders.requestNotifications()
                  store.refresh()
                }
              }
            }))
        Stepper(
          "Nhắc lúc \(store.state.studio.settings.streakHour):00",
          value: Binding(
            get: { store.state.studio.settings.streakHour },
            set: { hour in _ = store.editStudio { $0.settings.streakHour = hour } }), in: 7...22)
        Text("Không nhắc hôm nay nếu bạn đã đủ streak. Mở app định kỳ để làm mới lịch nhắc.").font(
          .caption)
      }
      Section("Kết nối") {
        NavigationLink {
          CalendarConnectionView()
        } label: {
          Label("Apple / Google Calendar", systemImage: "calendar.badge.clock")
        }
        NavigationLink {
          FocusProtectionView()
        } label: {
          Label("Screen Time", systemImage: "shield.lefthalf.filled")
        }
        Text(store.widgetMessage).font(.caption)
      }
      Section("Sao lưu đầy đủ") {
        Button("Xuất dữ liệu kèm tất cả tệp", systemImage: "square.and.arrow.up") {
          Task {
            busy = true
            defer { busy = false }
            do {
              guard !store.readOnly else {
                throw StudyError.invalid("Khôi phục dữ liệu trước khi xuất.")
              }
              let bytes = try StateCodec.encode(store.state)
              shareURL = try await BackupWorker.shared.export(bytes)
              share = true
            } catch { store.errorMessage = error.localizedDescription }
          }
        }.disabled(busy)
        Button("Nhập .mamstudy / JSON", systemImage: "square.and.arrow.down") { importing = true }
          .disabled(busy)
        if busy { ProgressView("Đang xử lý bản sao lưu…") }
        Text(
          "Chọn Lưu vào Tệp → iCloud Drive khi xuất. Trên iPad hoặc iPhone khác, tải file rồi nhập để chuyển dữ liệu. Đây là sao lưu và khôi phục thủ công; chưa có đồng bộ tự động."
        ).font(.caption)
        Text(
          "File .mamstudy chứa cả PDF, ảnh, bản thu và trang viết tay. JSON chỉ lưu dữ liệu và tên tệp, không mang tệp đính kèm sang máy khác."
        ).font(.caption)
      }
    }.navigationTitle("Kết nối & bảo mật").interactiveDismissDisabled(busy)
      .fileImporter(
        isPresented: $importing,
        allowedContentTypes: [UTType(filenameExtension: "mamstudy") ?? .data, .json]
      ) { result in
        Task {
          busy = true
          defer { busy = false }
          do {
            let data = try await BackupWorker.shared.read(result.get())
            pending = try StateCodec.decode(data)
            confirm = true
          } catch { store.errorMessage = error.localizedDescription }
        }
      }
      .sheet(isPresented: $share) { if let shareURL { ShareSheet(url: shareURL) } }
      .confirmationDialog(
        "Khôi phục bản sao lưu?", isPresented: $confirm, titleVisibility: .visible
      ) {
        Button("Thay dữ liệu hiện tại", role: .destructive) {
          if let pending { store.restore(pending) }
          pending = nil
        }
        Button("Hủy", role: .cancel) { pending = nil }
      } message: {
        if let pending {
          Text(
            "\(pending.notes.count) ghi chú • \(pending.cards.count) thẻ • \(pending.studio.documents.count) tài liệu. Dữ liệu hiện tại được giữ làm bản phục hồi. Khóa app được tắt để bạn thiết lập lại trên máy này."
          )
        }
      }
  }
}
