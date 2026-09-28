import Foundation

enum WidgetStorage {
  static var isEnabled: Bool {
    (Bundle.main.object(forInfoDictionaryKey: "StudyWidgetsEnabled") as? String) == "YES"
  }
  static var groupID: String {
    Bundle.main.object(forInfoDictionaryKey: "StudyAppGroup") as? String
      ?? "group.com.cunz.mamstudy"
  }
  static var directory: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
  }
  static var url: URL? { directory?.appendingPathComponent("widget-snapshot.json") }
  static func save(_ value: WidgetSnapshot) throws {
    guard let url else {
      throw StudyError.invalid(
        "Widget chưa chia sẻ được dữ liệu. Bản ký cần hỗ trợ App Groups cho app và widget.")
    }
    let data = try JSONEncoder().encode(value)
    try data.write(
      to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }
  static func load() -> WidgetSnapshot? {
    guard let url, let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
  }
}
