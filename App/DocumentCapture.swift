import AVFoundation
import Combine
import PDFKit
import PencilKit
import SwiftUI
import Vision
import VisionKit

struct ScanCamera: UIViewControllerRepresentable {
  var finished: (Result<[UIImage], Error>) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(finished) }
  func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
    let c = VNDocumentCameraViewController()
    c.delegate = context.coordinator
    return c
  }
  func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}
  final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
    let finished: (Result<[UIImage], Error>) -> Void
    init(_ finished: @escaping (Result<[UIImage], Error>) -> Void) { self.finished = finished }
    func documentCameraViewController(
      _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
    ) {
      guard scan.pageCount <= 20 else {
        finished(.failure(StudyError.invalid("Mỗi lần scan tối đa 20 trang.")))
        return
      }
      finished(.success((0..<scan.pageCount).map { scan.imageOfPage(at: $0) }))
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
      finished(.success([]))
    }
    func documentCameraViewController(
      _ controller: VNDocumentCameraViewController, didFailWithError error: Error
    ) { finished(.failure(error)) }
  }
}
enum TextRecognition {
  static func read(_ data: Data) async throws -> String {
    try await Task.detached(priority: .userInitiated) {
      let r = VNRecognizeTextRequest()
      r.recognitionLevel = .accurate
      r.usesLanguageCorrection = true
      let available = try r.supportedRecognitionLanguages()
      let wanted = ["vi-VN", "en-US"].filter { available.contains($0) }
      if !wanted.isEmpty { r.recognitionLanguages = wanted }
      r.automaticallyDetectsLanguage = true
      try VNImageRequestHandler(data: data).perform([r])
      return String(
        (r.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
          .prefix(2_000_000))
    }.value
  }
  @MainActor static func document(from images: [UIImage]) async throws -> LibraryDocument {
    let pdf = PDFDocument()
    var text: [String] = []
    for (i, image) in images.enumerated() {
      if let page = PDFPage(image: image) { pdf.insert(page, at: pdf.pageCount) }
      if let data = image.jpegData(compressionQuality: 0.8) {
        text.append("--- \(i+1) ---\n" + (try await read(data)))
      }
    }
    guard let data = pdf.dataRepresentation() else {
      throw StudyError.invalid("Chưa tạo được PDF scan.")
    }
    return LibraryDocument(
      title: "Scan " + Date().formatted(.dateTime.day().month().hour().minute()), kind: .pdf,
      filename: try FileVault.current.put(data, extension: "pdf"),
      extractedText: String(text.joined(separator: "\n\n").prefix(2_000_000)))
  }
}
@MainActor final class LectureRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
  @Published var recording = false
  @Published var starting = false
  @Published var seconds = 0.0
  @Published var error: String?
  @Published var completedURL: URL?
  private var recorder: AVAudioRecorder?
  private var timer: Timer?
  private var interruption: NSObjectProtocol?
  private var cancelled = false
  func start() async {
    guard !recording && !starting else { return }
    starting = true
    cancelled = false
    defer { starting = false }
    let allowed = await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
    }
    guard !cancelled else { return }
    guard allowed else {
      error = "Chưa có quyền micro. Bật trong Cài đặt iPhone để ghi âm."
      return
    }
    do {
      AmbientAudio.shared.stop()
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
      try session.setActive(true)
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString + ".m4a")
      let r = try AVAudioRecorder(
        url: url,
        settings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 22050, AVNumberOfChannelsKey: 1,
          AVEncoderBitRateKey: 48000,
        ])
      recorder = r
      r.delegate = self
      guard r.record(forDuration: 3600) else {
        throw StudyError.invalid("Không bắt đầu được ghi âm.")
      }
      recording = true
      seconds = 0
      timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
        Task { @MainActor in self?.seconds = self?.recorder?.currentTime ?? 0 }
      }
      interruption = NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
      ) { [weak self] _ in Task { @MainActor in self?.stop() } }
    } catch {
      self.error = error.localizedDescription
      cleanup()
    }
  }
  func stop() {
    cancelled = true
    guard let r = recorder else { return }
    r.stop()
    finish(r.url)
  }
  private func finish(_ url: URL) {
    guard recording else { return }
    completedURL = url
    cleanup()
  }
  private func cleanup() {
    recording = false
    timer?.invalidate()
    timer = nil
    if let interruption { NotificationCenter.default.removeObserver(interruption) }
    interruption = nil
    recorder = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
  }
  nonisolated func audioRecorderDidFinishRecording(
    _ recorder: AVAudioRecorder, successfully flag: Bool
  ) {
    let url = recorder.url
    Task { @MainActor in
      if !flag { self.error = "Bản thu bị gián đoạn. Hãy kiểm tra lại." }
      self.finish(url)
    }
  }
}
struct HandwritingSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var canvas = PKCanvasView()
  @State private var picker = PKToolPicker()
  var saved: (Data) -> Void
  var body: some View {
    NavigationStack {
      PencilCanvas(canvas: canvas, picker: picker).ignoresSafeArea(edges: .bottom).navigationTitle(
        "Trang viết tay"
      ).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Lưu") {
            saved(canvas.drawing.dataRepresentation())
            dismiss()
          }
        }
        ToolbarItem(placement: .bottomBar) { Button("Hoàn tác") { canvas.undoManager?.undo() } }
      }
    }
  }
}
struct PencilCanvas: UIViewRepresentable {
  let canvas: PKCanvasView
  let picker: PKToolPicker
  func makeUIView(context: Context) -> PKCanvasView {
    canvas.backgroundColor = .systemBackground
    canvas.drawingPolicy = .anyInput
    canvas.contentSize = CGSize(width: 1000, height: 1600)
    canvas.alwaysBounceVertical = true
    picker.addObserver(canvas)
    DispatchQueue.main.async {
      picker.setVisible(true, forFirstResponder: canvas)
      canvas.becomeFirstResponder()
    }
    return canvas
  }
  func updateUIView(_ view: PKCanvasView, context: Context) {}
}
struct ShareSheet: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
