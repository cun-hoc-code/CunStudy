import SwiftUI
import UIKit

/// Keeps each tab's navigation/scroll state alive and performs one short UIKit transition.
/// This avoids rebuilding every tab during the old SwiftUI TabView animation.
struct SmoothTabHost: UIViewControllerRepresentable {
  @ObservedObject var store: AppStore
  let reduceMotion: Bool

  func makeUIViewController(context: Context) -> TabHostController {
    let controller = TabHostController(store: store)
    controller.configure(reduceMotion: reduceMotion)
    controller.show(index: store.tab, animated: false)
    return controller
  }

  func updateUIViewController(_ controller: TabHostController, context: Context) {
    controller.configure(reduceMotion: reduceMotion)
    controller.show(index: store.tab, animated: !reduceMotion)
  }
}

private struct TabConfiguration: Equatable {
  var language: String
  var appearance: AppAppearance
  var reduceMotion: Bool
}

@MainActor
final class TabHostController: UIViewController {
  private let store: AppStore
  private var hosts: [Int: UIHostingController<AnyView>] = [:]
  private var currentIndex: Int?
  private var pendingIndex: Int?
  private var animating = false
  private var reduceMotion = false
  private var configuration: TabConfiguration?
  private var installedHosts = Set<Int>()

  init(store: AppStore) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func loadView() {
    let root = UIView()
    root.backgroundColor = .clear
    root.clipsToBounds = true
    view = root
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    for host in hosts.values where host.view.superview != nil { host.view.frame = view.bounds }
  }

  func configure(reduceMotion: Bool) {
    self.reduceMotion = reduceMotion
    let next = TabConfiguration(
      language: store.state.studio.settings.language,
      appearance: store.state.preferences.appearance,
      reduceMotion: reduceMotion)
    guard next != configuration else { return }
    configuration = next
    for (index, host) in hosts { host.rootView = rootView(for: index) }
  }

  func show(index: Int, animated: Bool) {
    let target = min(max(0, index), 4)
    if animating {
      pendingIndex = target
      return
    }
    guard currentIndex != target else {
      pendingIndex = nil
      return
    }

    let incoming = host(for: target)
    attach(incoming, index: target)
    guard let oldIndex = currentIndex, let outgoing = hosts[oldIndex] else {
      incoming.view.alpha = 1
      incoming.view.transform = .identity
      currentIndex = target
      return
    }

    currentIndex = target
    let duration = reduceMotion || !animated ? 0 : 0.32
    if duration == 0 {
      outgoing.view.removeFromSuperview()
      incoming.view.alpha = 1
      incoming.view.transform = .identity
      finishTransition()
      return
    }

    animating = true
    let forward = target > oldIndex
    incoming.view.accessibilityElementsHidden = false
    outgoing.view.accessibilityElementsHidden = true
    incoming.view.alpha = 0
    incoming.view.transform = CGAffineTransform(
      translationX: forward ? 18 : -18, y: 0
    ).scaledBy(x: 0.992, y: 0.992)
    view.bringSubviewToFront(incoming.view)
    UIView.animate(
      withDuration: duration, delay: 0, usingSpringWithDamping: 0.92,
      initialSpringVelocity: 0.18,
      options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState]
    ) {
      incoming.view.alpha = 1
      incoming.view.transform = .identity
      outgoing.view.alpha = 0
      outgoing.view.transform = CGAffineTransform(
        translationX: forward ? -12 : 12, y: 0
      ).scaledBy(x: 0.996, y: 0.996)
    } completion: { [weak self, weak outgoing] _ in
      outgoing?.view.removeFromSuperview()
      outgoing?.view.alpha = 1
      outgoing?.view.transform = .identity
      outgoing?.view.accessibilityElementsHidden = false
      self?.finishTransition()
    }
  }

  private func finishTransition() {
    animating = false
    guard let pendingIndex else { return }
    self.pendingIndex = nil
    show(index: pendingIndex, animated: !reduceMotion)
  }

  private func host(for index: Int) -> UIHostingController<AnyView> {
    if let host = hosts[index] { return host }
    let host = UIHostingController(rootView: rootView(for: index))
    host.view.backgroundColor = .clear
    addChild(host)
    hosts[index] = host
    return host
  }

  private func attach(_ host: UIHostingController<AnyView>, index: Int) {
    host.view.accessibilityElementsHidden = false
    if host.view.superview == nil {
      host.view.frame = view.bounds
      host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(host.view)
    }
    if installedHosts.insert(index).inserted { host.didMove(toParent: self) }
  }

  private func rootView(for index: Int) -> AnyView {
    let content: AnyView
    switch index {
    case 1: content = AnyView(PlannerView())
    case 2: content = AnyView(FocusView())
    case 3: content = AnyView(CardsView())
    case 4: content = AnyView(NotebookView())
    default: content = AnyView(TodayView())
    }
    return AnyView(
      content
        .environmentObject(store)
        .environmentObject(store.reminders)
        .environmentObject(store.liveActivity)
        .environment(
          \.locale,
          Locale(identifier: store.state.studio.settings.language == "en" ? "en_US" : "vi_VN")
        )
        .environment(\.mamReduceMotion, reduceMotion)
        .tint(Pencil.green)
        .foregroundStyle(Pencil.ink)
        .preferredColorScheme(store.state.preferences.appearance.colorScheme)
        .buttonStyle(SoftPressStyle()))
  }
}
