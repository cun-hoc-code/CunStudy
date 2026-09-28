import AVFoundation
import Combine
import SwiftUI

@MainActor final class AmbientAudio: ObservableObject {
  static let shared = AmbientAudio()
  @Published private(set) var current: String?
  @Published var volume: Float = 0.25 { didSet { player?.volume = volume } }
  @Published var error: String?
  private var player: AVAudioPlayer?
  private var interruption: NSObjectProtocol?
  private init() {
    interruption = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
    ) { [weak self] _ in Task { @MainActor in self?.stop() } }
  }
  func play(_ name: String) {
    if current == name {
      stop()
      return
    }
    do {
      guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
        throw StudyError.invalid("Thiếu tệp âm thanh trong bản build.")
      }
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
      try session.setActive(true)
      let p = try AVAudioPlayer(contentsOf: url)
      p.numberOfLoops = -1
      p.volume = volume
      guard p.play() else { throw StudyError.invalid("Không phát được âm thanh.") }
      player = p
      current = name
      error = nil
    } catch {
      self.error = error.localizedDescription
      stop()
    }
  }
  func stop() {
    player?.stop()
    player = nil
    current = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
  }
}
struct AmbientPanel: View {
  @ObservedObject private var audio = AmbientAudio.shared
  var body: some View {
    PaperCard(color: .sky) {
      VStack(alignment: .leading, spacing: 12) {
        Label("Góc âm thanh", systemImage: "headphones").font(.headline)
        HStack {
          sound("rain", "Mưa", "cloud.rain")
          sound("cafe", "Quán cà phê", "cup.and.saucer")
          sound("white", "White noise", "waveform")
        }
        if audio.current != nil {
          HStack {
            Image(systemName: "speaker.wave.1")
            Slider(value: $audio.volume, in: 0...0.7).accessibilityLabel("Âm lượng")
            Button("Dừng") { audio.stop() }
          }
        }
        if let error = audio.error { Text(error).font(.caption).foregroundStyle(.red) }
        NavigationLink {
          FocusProtectionView()
        } label: {
          Label("Bảo vệ phiên tập trung", systemImage: "shield.lefthalf.filled")
        }
      }
    }
  }
  private func sound(_ name: String, _ title: String, _ icon: String) -> some View {
    Button {
      audio.play(name)
    } label: {
      VStack(spacing: 6) {
        Image(systemName: icon).symbolEffect(
          .pulse, options: .nonRepeating, value: audio.current == name)
        Text(LocalizedStringKey(title)).font(.caption)
      }.frame(maxWidth: .infinity, minHeight: 62).background(
        audio.current == name ? InkColor.sage.wash : Pencil.surface,
        in: RoundedRectangle(cornerRadius: 15))
    }.buttonStyle(SoftPressStyle()).accessibilityAddTraits(audio.current == name ? .isSelected : [])
  }
}
