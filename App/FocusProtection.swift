import Combine
import SwiftUI

#if MAM_SCREEN_TIME
  import FamilyControls
  import ManagedSettings
  import DeviceActivity

  @MainActor final class FocusShield: ObservableObject {
    static let shared = FocusShield()
    @Published var selection = FamilyActivitySelection()
    @Published var enabled = false
    @Published var message = "Chọn ứng dụng bạn muốn tạm che trong phiên học."
    private let managed = ManagedSettingsStore(named: .init("mam.focus"))
    private let center = DeviceActivityCenter()
    private let name = DeviceActivityName("mam.focus")
    private var fingerprint = ""
    private init() {
      enabled = UserDefaults.standard.bool(forKey: "mam.shield.enabled")
      fingerprint = UserDefaults.standard.string(forKey: "mam.shield.fingerprint") ?? ""
      if let data = UserDefaults.standard.data(forKey: "mam.shield.selection"),
        let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
      {
        selection = value
      }
    }
    func authorize() async {
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        message = "Đã được cho phép. Chọn ứng dụng rồi bật bảo vệ."
      } catch { message = error.localizedDescription }
    }
    func save() {
      UserDefaults.standard.set(enabled, forKey: "mam.shield.enabled")
      if let bytes = try? JSONEncoder().encode(selection) {
        UserDefaults.standard.set(bytes, forKey: "mam.shield.selection")
      }
      fingerprint = ""
      UserDefaults.standard.removeObject(forKey: "mam.shield.fingerprint")
    }
    func release() {
      managed.clearAllSettings()
      center.stopMonitoring([name])
      fingerprint = ""
      UserDefaults.standard.removeObject(forKey: "mam.shield.fingerprint")
    }
    func reconcile(_ focus: ActiveFocus?) {
      guard enabled, AuthorizationCenter.shared.authorizationStatus == .approved, let focus,
        !focus.isPaused, let end = focus.endDate, end > Date()
      else {
        release()
        return
      }
      let key = focus.id.uuidString + "-" + String(Int(end.timeIntervalSince1970))
      guard fingerprint != key else { return }
      release()
      guard end.timeIntervalSinceNow >= 15 * 60 else {
        message =
          "Screen Time cần ít nhất 15 phút còn lại để đặt lịch tự mở chặn. Phiên này tiếp tục với bộ đếm thông thường."
        return
      }
      let calendar = Calendar.current
      let startParts = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: Date())
      let endParts = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: end)
      do {
        try center.startMonitoring(
          name,
          during: DeviceActivitySchedule(
            intervalStart: startParts, intervalEnd: endParts, repeats: false))
        managed.shield.applications =
          selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        managed.shield.applicationCategories =
          selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        managed.shield.webDomains =
          selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        fingerprint = key
        UserDefaults.standard.set(key, forKey: "mam.shield.fingerprint")
        message = "Đang bảo vệ phiên học. Bạn luôn có thể mở chặn tại đây."
      } catch {
        release()
        message = "Chưa bật được bảo vệ: " + error.localizedDescription
      }
    }
  }
  struct FocusProtectionView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var shield = FocusShield.shared
    @State private var picker = false
    var body: some View {
      Form {
        Section("Screen Time") {
          Text(shield.message)
          Button("Cho phép Screen Time") { Task { await shield.authorize() } }
          Button("Chọn app / nhóm app") { picker = true }.disabled(
            AuthorizationCenter.shared.authorizationStatus != .approved)
          Toggle("Bảo vệ phiên tập trung", isOn: $shield.enabled).disabled(
            AuthorizationCenter.shared.authorizationStatus != .approved)
          Button("Mở chặn ngay") {
            shield.enabled = false
            shield.save()
            shield.release()
          }
        }
        Section("Thông báo") {
          Text(
            "Để tắt thông báo, bật chế độ Tập trung trong Trung tâm điều khiển iPhone. Mầm không tự đổi chế độ Không làm phiền."
          )
        }
        Text(
          "Đặt phiên ít nhất 16 phút để iOS có đủ khoảng thời gian lập lịch. Việc chặn chỉ áp dụng cho lựa chọn được hệ thống cho phép và cần quyền Family Controls trong bản ký."
        ).font(.caption)
      }.navigationTitle("Bảo vệ tập trung").familyActivityPicker(
        isPresented: $picker, selection: $shield.selection
      ).onChange(of: shield.selection) { _, _ in
        shield.save()
        shield.reconcile(store.state.activeFocus)
      }.onChange(of: shield.enabled) { _, _ in
        shield.save()
        shield.reconcile(store.state.activeFocus)
      }
    }
  }
#else
  @MainActor final class FocusShield {
    static let shared = FocusShield()
    func reconcile(_ focus: ActiveFocus?) {}
    func release() {}
  }
  struct FocusProtectionView: View {
    var body: some View {
      Form {
        Section("Một khoảng yên tĩnh") {
          Text(
            "Bật Tập trung / Không làm phiền trong Trung tâm điều khiển để giảm thông báo khi học.")
          Text("Bạn vẫn có thể dùng bộ đếm, âm thanh nền và trồng mầm trong bản này.")
        }
        Section("Chặn ứng dụng") {
          Text(
            "Cần bản MamStudyManaged được ký với quyền Family Controls và extension theo dõi Screen Time. Bản đang cài chưa có quyền này."
          )
        }
        Text(
          "Mầm tính cây theo thời gian phiên đã lưu. App không theo dõi mọi thao tác sử dụng điện thoại."
        ).font(.caption)
      }.navigationTitle("Bảo vệ tập trung")
    }
  }
#endif
