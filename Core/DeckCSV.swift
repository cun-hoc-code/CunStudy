import Foundation

enum DeckCSV {
  static func encode(_ cards: [Flashcard]) -> String {
    func field(_ s: String) -> String {
      "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return
      (["front,back,deck,kind,example"]
      + cards.map {
        [$0.front, $0.back, $0.deck, $0.kind.rawValue, $0.example].map(field).joined(separator: ",")
      }).joined(separator: "\r\n")
  }
  static func decode(_ text: String) throws -> [Flashcard] {
    guard text.utf8.count <= 10 * 1024 * 1024 else { throw StudyError.invalid("CSV vượt 10 MB.") }
    var rows: [[String]] = []
    var row: [String] = []
    var field = ""
    var quoted = false
    var closed = false
    let chars = Array(
      text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
    var i = 0
    while i < chars.count {
      let c = chars[i]
      if quoted {
        if c == "\"" {
          if i + 1 < chars.count && chars[i + 1] == "\"" {
            field.append("\"")
            i += 1
          } else {
            quoted = false
            closed = true
          }
        } else {
          field.append(c)
        }
      } else if c == "," {
        row.append(field)
        field = ""
        closed = false
      } else if c == "\n" {
        row.append(field)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        row = []
        field = ""
        closed = false
      } else if c == "\"" && field.isEmpty && !closed {
        quoted = true
      } else if closed || c == "\"" {
        throw StudyError.invalid("Dấu ngoặc kép CSV không hợp lệ.")
      } else {
        field.append(c)
      }
      i += 1
    }
    guard !quoted else { throw StudyError.invalid("CSV thiếu dấu đóng ngoặc kép.") }
    row.append(field)
    if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
    guard !rows.isEmpty else { return [] }
    let header = rows[0].map {
      $0.trimmingCharacters(
        in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{feff}"))
      ).lowercased()
    }
    let hasHeader = header.contains("front") && header.contains("back")
    let contents = hasHeader ? Array(rows.dropFirst()) : rows
    guard contents.count <= 30000 else { throw StudyError.invalid("Tối đa 30.000 thẻ.") }
    return try contents.enumerated().map { index, fields in
      func get(_ column: Int?) -> String {
        column.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""
      }
      var c = Flashcard()
      c.front = get(hasHeader ? header.firstIndex(of: "front") : 0)
      c.back = get(hasHeader ? header.firstIndex(of: "back") : 1)
      if hasHeader {
        let deck = get(header.firstIndex(of: "deck"))
        if !deck.isEmpty { c.deck = deck }
        let kind = get(header.firstIndex(of: "kind"))
        if !kind.isEmpty {
          guard let value = CardKind(rawValue: kind) else {
            throw StudyError.invalid("Loại thẻ không hợp lệ.")
          }
          c.kind = value
        }
        c.example = get(header.firstIndex(of: "example"))
      }
      guard c.hasValidContent else {
        throw StudyError.invalid("Hàng CSV \(index + (hasHeader ? 2 : 1)) thiếu nội dung.")
      }
      return c
    }
  }
}
