import Foundation
import ZIPFoundation

/// Files are immutable. Editing a PDF creates a new filename so old state snapshots stay recoverable.
struct FileVault {
  static var current: FileVault {
    FileVault(
      root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MamStudy/Attachments", isDirectory: true))
  }
  let root: URL
  func url(_ name: String) throws -> URL {
    guard WorkspaceValidation.safeFilename(name) else {
      throw StudyError.invalid("Tên tệp không hợp lệ.")
    }
    return root.appendingPathComponent(name)
  }
  func put(_ data: Data, extension ext: String) throws -> String {
    guard data.count <= 50 * 1024 * 1024 else { throw StudyError.invalid("Mỗi tệp tối đa 50 MB.") }
    let ext = String(
      ext.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(12))
    let name = UUID().uuidString + (ext.isEmpty ? "" : "." + ext)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try data.write(to: url(name), options: .atomic)
    #if os(iOS)
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: url(name).path)
    #endif
    return name
  }
  func importFile(_ source: URL) throws -> String {
    #if os(iOS) || os(macOS)
      let access = source.startAccessingSecurityScopedResource()
      defer { if access { source.stopAccessingSecurityScopedResource() } }
    #endif
    #if os(iOS) || os(macOS)
    var coordinationError: NSError?
    var result: Result<String, Error>?
    NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { url in result = Result { try importLocal(url) } }
    if let coordinationError { throw coordinationError }
    guard let result else { throw StudyError.invalid("Không đọc được file từ nhà cung cấp.") }
    return try result.get()
    #else
    return try importLocal(source)
    #endif
  }
  private func importLocal(_ source: URL) throws -> String {
    let attributes = try source.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
    guard attributes.isDirectory != true else { throw StudyError.invalid("Hãy chọn file, không chọn thư mục.") }
    if let size = attributes.fileSize, size > 50 * 1024 * 1024 { throw StudyError.invalid("Mỗi file tối đa 50 MB.") }
    let handle = try FileHandle(forReadingFrom: source)
    defer { try? handle.close() }
    var data = Data()
    while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
      guard data.count + chunk.count <= 50 * 1024 * 1024 else { throw StudyError.invalid("Mỗi file tối đa 50 MB.") }
      data.append(chunk)
    }
    return try put(data, extension: source.pathExtension)
  }

  func backup(_ state: StudyState, to destination: URL) throws {
    let stage = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let folder = stage.appendingPathComponent("files", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: stage) }
    try StateCodec.encode(StateCodec.backupSnapshot(state, at: Date())).write(
      to: stage.appendingPathComponent("state.json"))
    var total = 0
    for name in Set(state.studio.documents.compactMap(\.filename)) {
      let source = try url(name)
      total += try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard total <= 256 * 1024 * 1024 else {
        throw StudyError.invalid("Tệp đính kèm trong bản sao lưu vượt 256 MB.")
      }
      try FileManager.default.copyItem(at: source, to: folder.appendingPathComponent(name))
    }
    try FileManager.default.zipItem(
      at: stage, to: destination, shouldKeepParent: false, compressionMethod: .deflate)
  }
  func readBackup(_ source: URL) throws -> StudyState {
    #if os(iOS) || os(macOS)
      let access = source.startAccessingSecurityScopedResource()
      defer { if access { source.stopAccessingSecurityScopedResource() } }
    #endif
    guard
      (try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 300 * 1024 * 1024
    else { throw StudyError.invalid("Bản sao lưu tối đa 300 MB.") }
    let archive = try Archive(url: source, accessMode: .read)
    let entries = Array(try Archive(url: source, accessMode: .read))
    guard entries.count <= 10002 else { throw StudyError.invalid("Bản sao lưu có quá nhiều tệp.") }
    var seen = Set<String>()
    var total: UInt64 = 0
    for entry in entries {
      let parts = entry.path.split(separator: "/", omittingEmptySubsequences: false)
      let valid =
        entry.path == "state.json" || entry.path == "files/"
        || (parts.count == 2 && parts[0] == "files"
          && WorkspaceValidation.safeFilename(String(parts[1])))
      guard valid, entry.type != .symlink, seen.insert(entry.path).inserted,
        entry.uncompressedSize <= 50 * 1024 * 1024
      else { throw StudyError.invalid("Cấu trúc bản sao lưu không hợp lệ.") }
      total += entry.uncompressedSize
      guard total <= 281 * 1024 * 1024 else {
        throw StudyError.invalid("Bản sao lưu giải nén vượt giới hạn.")
      }
    }
    func extract(_ entry: Entry, limit: Int) throws -> Data {
      var bytes = Data()
      let crc = try archive.extract(entry) { chunk in
        guard bytes.count + chunk.count <= limit else {
          throw StudyError.invalid("Tệp giải nén quá lớn.")
        }
        bytes.append(chunk)
      }
      guard crc == entry.checksum else { throw StudyError.invalid("Tệp bị lỗi checksum.") }
      return bytes
    }
    guard let manifest = archive["state.json"] else {
      throw StudyError.invalid("Thiếu state.json.")
    }
    var state = try StateCodec.decode(extract(manifest, limit: 25 * 1024 * 1024))
    var installed: [String] = []
    var mapping: [String: String] = [:]
    do {
      for old in Set(state.studio.documents.compactMap(\.filename)) {
        guard let entry = archive["files/" + old], entry.type == .file else {
          throw StudyError.invalid("Bản sao lưu thiếu tệp \(old).")
        }
        let name = try put(
          extract(entry, limit: 50 * 1024 * 1024),
          extension: URL(fileURLWithPath: old).pathExtension)
        installed.append(name)
        mapping[old] = name
      }
      for i in state.studio.documents.indices {
        if let old = state.studio.documents[i].filename {
          state.studio.documents[i].filename = mapping[old]
        }
      }
      state.studio.settings.appLock = false
      return StateCodec.restoredSnapshot(state)
    } catch {
      for name in installed {
        if let file = try? url(name) { try? FileManager.default.removeItem(at: file) }
      }
      throw error
    }
  }
}
