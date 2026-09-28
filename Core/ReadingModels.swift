import Foundation

enum PaperTone: String, Codable, CaseIterable, Identifiable, Sendable {
  case cream, ivory, sage, rose, night
  var id: String { rawValue }
  var title: String {
    switch self {
    case .cream: return "Giấy vàng"
    case .ivory: return "Ngà"
    case .sage: return "Xanh dịu"
    case .rose: return "Hồng phấn"
    case .night: return "Đêm"
    }
  }
}
struct ReaderPreferences: Codable, Equatable, Sendable {
  var font = "Georgia"
  var size = 20.0
  var lineSpacing = 6.0
  var tone: PaperTone = .cream
  var originalPDF = false
}
struct BookRecord: Codable, Equatable, Identifiable {
  var id = UUID()
  var documentID: UUID
  var title: String
  var textOffset = 0
  var pdfPage = 0
  var lastOpened = Date()
  /// Text offsets. Kept under the original key so v2.0/v2.1 backups remain readable.
  var bookmarks: [Int] = []
  /// PDF page bookmarks are separate from text offsets. Optional keeps old backups compatible.
  var storedPDFBookmarks: [Int]? = nil
  var preferences = ReaderPreferences()
  var pdfBookmarks: [Int] {
    get { storedPDFBookmarks ?? [] }
    set { storedPDFBookmarks = newValue }
  }
}
struct ReadingState: Codable, Equatable { var books: [BookRecord] = [] }
struct FeedbackPreferences: Codable, Equatable {
  var sound = true
  var volume = 0.18
  var strength = 0.32
}
enum TextFileDecoder {
  static func decode(_ data: Data) throws -> String {
    guard data.count <= 50 * 1024 * 1024 else { throw StudyError.invalid("File chữ tối đa 50 MB.") }
    let bytes = [UInt8](data.prefix(4))
    let encoding: String.Encoding
    if bytes.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
      encoding = .utf32LittleEndian
    } else if bytes.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
      encoding = .utf32BigEndian
    } else if bytes.starts(with: [0xFF, 0xFE]) {
      encoding = .utf16LittleEndian
    } else if bytes.starts(with: [0xFE, 0xFF]) {
      encoding = .utf16BigEndian
    } else {
      encoding = .utf8
    }
    guard let text = String(data: data, encoding: encoding) else {
      throw StudyError.invalid(
        "Không đọc được mã chữ. Lưu TXT dạng UTF-8 hoặc UTF-16 có BOM rồi nhập lại.")
    }
    let result = text.replacingOccurrences(of: "\u{feff}", with: "").replacingOccurrences(
      of: "\r\n", with: "\n"
    ).replacingOccurrences(of: "\r", with: "\n")
    guard !result.contains("\0") else {
      throw StudyError.invalid("File không phải văn bản TXT hợp lệ.")
    }
    return result
  }
}
