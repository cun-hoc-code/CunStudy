import Combine
import SwiftUI
import UIKit
import UserNotifications

final class ForegroundNotifications: NSObject, UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}

@main
struct MamStudyApp: App {
  @StateObject private var store = AppStore()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private let notifications = ForegroundNotifications()
  init() { UNUserNotificationCenter.current().delegate = notifications }
  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(store).environmentObject(store.reminders)
        .environmentObject(store.liveActivity)
        .tint(Pencil.green).foregroundStyle(Pencil.ink)
        .preferredColorScheme(store.state.preferences.appearance.colorScheme)
        .environment(
          \.locale,
          Locale(identifier: store.state.studio.settings.language == "en" ? "en_US" : "vi_VN")
        )
        .environment(
          \.mamReduceMotion,
          systemReduceMotion || store.state.studio.settings.reduceMotion
        )
        .onChange(of: scenePhase) { _, phase in
          PrivacyLock.shared.phase(phase)
          if phase == .active { store.refresh() }
        }
        .onChange(of: store.state.studio.settings.appLock) { _, enabled in
          PrivacyLock.shared.configure(enabled)
        }
        .onChange(of: store.state.preferences.haptics) { _, enabled in
          InteractionFeedback.shared.configure(store.state.studio.interaction, haptics: enabled)
        }
        .onChange(of: store.state.studio.interaction) { _, value in
          InteractionFeedback.shared.configure(value, haptics: store.state.preferences.haptics)
        }
        .task {
          store.refresh()
          PrivacyLock.shared.configure(store.state.studio.settings.appLock)
          PrivacyLock.shared.phase(scenePhase)
          InteractionFeedback.shared.configure(
            store.state.studio.interaction, haptics: store.state.preferences.haptics)
        }
        .onReceive(
          NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
        ) { _ in store.refresh() }
        .onOpenURL { url in
          guard url.scheme == "mamstudy" else { return }
          switch url.host {
          case "schedule": store.tab = 1
          case "focus": store.tab = 2
          case "cards": store.tab = 3
          case "notes": store.tab = 4
          default: store.tab = 0
          }
        }
        .alert(
          "Mầm",
          isPresented: Binding(
            get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
        ) {
          Button("Đã hiểu", role: .cancel) { store.errorMessage = nil }
        } message: {
          Text(store.errorMessage ?? "")
        }
    }
  }
}

struct RootView: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.mamReduceMotion) private var reduceMotion
  var body: some View {
    SmoothTabHost(store: store, reduceMotion: reduceMotion)
      .safeAreaInset(edge: .bottom, spacing: 0) { GardenTabBar() }
      .onChange(of: store.tab) { _, _ in
        StudyHaptics.selection(enabled: store.state.preferences.haptics)
      }
      .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
        // Any tab can be visible when a focus session ends. Disk is written only once.
        if store.state.activeFocus != nil && !store.readOnly { store.settleFocus() }
      }
      .fullScreenCover(
        isPresented: Binding(
          get: { !store.state.preferences.hasOnboarded && !store.readOnly }, set: { _ in })
      ) {
        WelcomeView()
      }
  }
}

private struct WelcomeView: View {
  @EnvironmentObject private var store: AppStore
  @State private var name = ""
  @State private var goal = 60
  var body: some View {
    NavigationStack {
      PaperPage {
        Text("Mầm").font(.system(size: 56, weight: .bold, design: .serif))
        Text("Mỗi ngày, lớn thêm một chút.").font(.title3)
        Sprout()
        PaperCard(color: .butter) {
          VStack(alignment: .leading, spacing: 12) {
            Text("Một cuốn sổ nhỏ cho việc học").font(.headline)
            Label("Lịch ở trường, tự học và bài tập", systemImage: "calendar")
            Label("Trồng mầm bằng từng phiên tập trung", systemImage: "leaf")
            Label("Ôn điều cần nhớ, đúng lúc", systemImage: "rectangle.on.rectangle")
          }
        }
        TextField("Bạn muốn Mầm gọi mình là gì?", text: $name).textFieldStyle(.roundedBorder)
        Stepper("Mục tiêu: \(goal) phút / ngày", value: $goal, in: 15...180, step: 15)
        Text(
          "Không cần tài khoản. Dữ liệu lưu trên iPhone. Bạn chủ động bật quyền báo thức và thông báo khi cần."
        )
        .font(.footnote).foregroundStyle(.secondary)
        Button("Mở sổ của mình") {
          _ = store.change {
            $0.preferences.name = name.trimmed.isEmpty ? "Bạn" : name.trimmed
            $0.preferences.dailyFocusMinutes = goal
            $0.preferences.hasOnboarded = true
          }
        }.buttonStyle(PencilButtonStyle())
      }
    }
  }
}
