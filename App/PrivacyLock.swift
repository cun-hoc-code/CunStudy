import Combine
import LocalAuthentication
import SwiftUI
import UIKit

/// A separate window covers presented sheets as well as the root and app-switcher snapshot.
@MainActor final class PrivacyLock: ObservableObject {
  static let shared = PrivacyLock()
  @Published private(set) var authenticating = false
  @Published private(set) var message = ""
  private var enabled = false
  private var active = true
  private var locked = true
  private var context: LAContext?
  private var cover: UIWindow?
  private weak var contentWindow: UIWindow?
  func configure(_ enabled: Bool) {
    guard self.enabled != enabled else { return }
    self.enabled = enabled
    locked = enabled
    if enabled {
      show()
      authenticate()
    } else {
      context?.invalidate()
      context = nil
      authenticating = false
      hide()
    }
  }
  func phase(_ phase: ScenePhase) {
    active = phase == .active
    guard enabled else { return }
    if phase == .background {
      locked = true
      context?.invalidate()
      context = nil
      authenticating = false
      show()
    } else if phase == .inactive {
      show()
    } else if locked {
      show()
      authenticate()
    } else {
      hide()
    }
  }
  func verify() async -> Bool {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
      message = error?.localizedDescription ?? "Thiết lập mật mã thiết bị trước."
      return false
    }
    do {
      return try await context.evaluatePolicy(
        .deviceOwnerAuthentication, localizedReason: "Xác thực để bật khóa Mầm")
    } catch {
      message = error.localizedDescription
      return false
    }
  }
  func authenticate() {
    guard enabled, active, locked, !authenticating else { return }
    let context = LAContext()
    self.context = context
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
      message = error?.localizedDescription ?? "Không dùng được xác thực thiết bị."
      return
    }
    authenticating = true
    message = ""
    Task {
      let ok =
        (try? await context.evaluatePolicy(
          .deviceOwnerAuthentication, localizedReason: "Mở sổ học tập của bạn")) == true
      guard self.context === context else { return }
      authenticating = false
      if ok {
        locked = false
        if active { hide() }
      } else {
        message = "Chưa mở khóa. Chạm để thử lại."
      }
    }
  }
  private func show() {
    guard cover == nil else { return }
    guard
      let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(
        where: { $0.activationState != .unattached })
    else { return }
    contentWindow = scene.windows.first(where: { $0.isKeyWindow })
    let window = UIWindow(windowScene: scene)
    window.windowLevel = .alert + 1
    window.rootViewController = UIHostingController(rootView: LockCover(lock: self))
    window.backgroundColor = .systemBackground
    cover = window
    window.makeKeyAndVisible()
  }
  private func hide() {
    cover?.isHidden = true
    cover = nil
    contentWindow?.makeKey()
    contentWindow = nil
  }
}
private struct LockCover: View {
  @ObservedObject var lock: PrivacyLock
  var body: some View {
    ZStack {
      Pencil.paper.ignoresSafeArea()
      VStack(spacing: 22) {
        Image(systemName: "lock.shield").font(.system(size: 56)).foregroundStyle(Pencil.green)
        Text("Mầm").font(.largeTitle.bold())
        Text("Sổ học tập đang khóa")
        if lock.authenticating {
          ProgressView()
        } else {
          Button("Mở bằng Face ID / mật mã") { lock.authenticate() }.buttonStyle(.borderedProminent)
        }
        if !lock.message.isEmpty {
          Text(lock.message).font(.caption).multilineTextAlignment(.center)
        }
      }.padding(30)
    }
  }
}
