import AVFoundation
import SwiftUI
import UIKit

/// One quiet, reusable feedback engine for controls, page turns and celebrations.
/// It never changes the app's audio category, so the silent switch and other audio stay respected.
@MainActor
final class InteractionFeedback {
  enum Event: String, Hashable {
    case tap, selection, page, success
  }

  static let shared = InteractionFeedback()

  private var preferences = FeedbackPreferences()
  private var hapticsEnabled = true
  private var players: [Event: AVAudioPlayer] = [:]
  private var lastPlayed: [Event: CFTimeInterval] = [:]
  private let soft = UIImpactFeedbackGenerator(style: .soft)
  private let light = UIImpactFeedbackGenerator(style: .light)
  private let medium = UIImpactFeedbackGenerator(style: .medium)

  private init() {
    for event in [Event.tap, .selection, .page, .success] {
      guard
        let url = Bundle.main.url(forResource: "feedback-" + event.rawValue, withExtension: "wav"),
        let player = try? AVAudioPlayer(contentsOf: url)
      else { continue }
      player.numberOfLoops = 0
      player.prepareToPlay()
      players[event] = player
    }
    prepareHaptics()
  }

  func configure(_ value: FeedbackPreferences, haptics: Bool) {
    preferences = value
    hapticsEnabled = haptics
    for player in players.values { player.volume = Float(value.volume) }
    if haptics { prepareHaptics() }
  }

  func play(_ event: Event) {
    let now = CACurrentMediaTime()
    let interval: CFTimeInterval = event == .page ? 0.12 : 0.065
    guard now - (lastPlayed[event] ?? 0) >= interval else { return }
    lastPlayed[event] = now

    let isActive = UIApplication.shared.applicationState == .active
    if isActive && hapticsEnabled && preferences.strength > 0 {
      let strength = CGFloat(min(1, max(0.05, preferences.strength)))
      switch event {
      case .tap:
        soft.impactOccurred(intensity: strength * 0.65)
        soft.prepare()
      case .selection:
        light.impactOccurred(intensity: strength * 0.72)
        light.prepare()
      case .page:
        soft.impactOccurred(intensity: strength * 0.55)
        soft.prepare()
      case .success:
        medium.impactOccurred(intensity: min(1, strength * 1.15))
        medium.prepare()
      }
    }

    guard isActive, preferences.sound, preferences.volume > 0 else { return }
    let session = AVAudioSession.sharedInstance()
    guard session.category != .record, session.category != .playAndRecord,
      !session.isOtherAudioPlaying, !session.secondaryAudioShouldBeSilencedHint,
      let player = players[event]
    else { return }
    player.volume = Float(preferences.volume)
    player.currentTime = 0
    player.play()
  }

  private func prepareHaptics() {
    soft.prepare()
    light.prepare()
    medium.prepare()
  }
}

struct FeedbackSettingsView: View {
  @EnvironmentObject private var store: AppStore
  @State private var draft = FeedbackPreferences()

  var body: some View {
    Form {
      Section("Âm thanh tương tác") {
        Toggle("Phát âm thanh tinh tế", isOn: $draft.sound)
        HStack {
          Image(systemName: "speaker.fill")
          Slider(value: $draft.volume, in: 0...0.4)
          Image(systemName: "speaker.wave.2.fill")
        }.disabled(!draft.sound)
        Text("Âm thanh tôn trọng chế độ im lặng và tự nhường khi nhạc hoặc bản thu khác đang phát.")
          .font(.footnote).foregroundStyle(.secondary)
      }
      Section("Độ rung") {
        HStack {
          Image(systemName: "hand.tap")
          Slider(value: $draft.strength, in: 0...1)
          Image(systemName: "waveform.path")
        }.disabled(!store.state.preferences.haptics)
        Text(
          store.state.preferences.haptics
            ? "Mức rung áp dụng cho nút, đổi tab, lật thẻ và lật trang sách."
            : "Bật “Rung nhẹ khi tương tác” ở màn hình Cài đặt để dùng mức này."
        ).font(.footnote).foregroundStyle(.secondary)
      }
      Section {
        Button("Nghe và cảm nhận thử") {
          InteractionFeedback.shared.configure(
            draft, haptics: store.state.preferences.haptics)
          InteractionFeedback.shared.play(.success)
        }
        Button("Lưu phản hồi") {
          if store.editStudio({ $0.interaction = draft }) {
            InteractionFeedback.shared.configure(
              draft, haptics: store.state.preferences.haptics)
          }
        }.buttonStyle(PencilButtonStyle())
      }
    }
    .navigationTitle("Âm thanh & rung")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { draft = store.state.studio.interaction }
    .onDisappear {
      InteractionFeedback.shared.configure(
        store.state.studio.interaction, haptics: store.state.preferences.haptics)
    }
  }
}
