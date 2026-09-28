import Foundation
import ZIPFoundation

#if canImport(CSQLite)
  import CSQLite
#else
  import SQLite3
#endif

/// Interoperates with Anki's legacy collection.anki2 / collection.anki21 export.
/// Media, scheduling and arbitrary templates are deliberately not interpreted.
enum AnkiDeck {
  static func read(_ source: URL) throws -> [Flashcard] {
    #if os(iOS) || os(macOS)
      let access = source.startAccessingSecurityScopedResource()
      defer { if access { source.stopAccessingSecurityScopedResource() } }
    #endif
    guard
      (try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 100 * 1024 * 1024
    else { throw StudyError.invalid("APKG tối đa 100 MB.") }
    let archive = try Archive(url: source, accessMode: .read)
    guard archive["collection.anki21b"] == nil else {
      throw StudyError.invalid(
        "Hãy xuất từ Anki với ‘Support older Anki versions’. Định dạng anki21b chưa được hỗ trợ.")
    }
    guard let entry = archive["collection.anki21"] ?? archive["collection.anki2"],
      entry.type == .file, entry.uncompressedSize <= 50 * 1024 * 1024
    else { throw StudyError.invalid("Thiếu cơ sở dữ liệu Anki hợp lệ (tối đa 50 MB).") }
    var bytes = Data()
    let crc = try archive.extract(entry) { chunk in
      guard bytes.count + chunk.count <= 50 * 1024 * 1024 else {
        throw StudyError.invalid("Database Anki quá lớn.")
      }
      bytes.append(chunk)
    }
    guard crc == entry.checksum else { throw StudyError.invalid("APKG bị lỗi checksum.") }
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".anki2")
    try bytes.write(to: temp)
    defer { try? FileManager.default.removeItem(at: temp) }
    let db = try Database(temp, readOnly: true)
    var deckNames: [String: String] = [:]
    if let raw = try db.rows("SELECT decks FROM col LIMIT 1").first?.first,
      let data = raw.data(using: .utf8),
      let object = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
    {
      for (k, v) in object { deckNames[k] = v["name"] as? String }
    }
    let rows = try db.rows(
      "SELECT n.flds,MIN(c.did) FROM notes n JOIN cards c ON c.nid=n.id GROUP BY n.id ORDER BY n.id LIMIT 30001"
    )
    guard rows.count <= 30_000 else {
      throw StudyError.invalid("Mỗi lần nhập tối đa 30.000 ghi chú Anki.")
    }
    return rows.compactMap { row in
      guard row.count >= 2 else { return nil }
      let fields = row[0].components(separatedBy: "\u{1f}")
      guard fields.count >= 2 else { return nil }
      let front = plain(fields[0])
      let back = plain(fields[1])
      guard !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
      let cloze = front.replacingOccurrences(
        of: #"\{\{c\d+::(.*?)(?:::[^}]*?)?\}\}"#, with: "{{$1}}", options: .regularExpression)
      var card = Flashcard()
      card.deck = deckNames[row[1]] ?? "Anki"
      card.front = cloze
      card.back = back
      card.kind = cloze != front ? .cloze : .knowledge
      if fields.count > 2 { card.example = plain(fields[2]) }
      return card
    }
  }
  static func write(_ cards: [Flashcard], to destination: URL) throws {
    guard !cards.isEmpty, cards.count <= 30_000 else {
      throw StudyError.invalid("Chọn từ 1 đến 30.000 thẻ.")
    }
    let stage = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: stage) }
    let db = try Database(stage.appendingPathComponent("collection.anki2"), readOnly: false)
    try db.run(
      """
      CREATE TABLE col(id integer primary key,crt integer not null,mod integer not null,scm integer not null,ver integer not null,dty integer not null,usn integer not null,ls integer not null,conf text not null,models text not null,decks text not null,dconf text not null,tags text not null);
      CREATE TABLE notes(id integer primary key,guid text not null,mid integer not null,mod integer not null,usn integer not null,tags text not null,flds text not null,sfld integer not null,csum integer not null,flags integer not null,data text not null);
      CREATE TABLE cards(id integer primary key,nid integer not null,did integer not null,ord integer not null,mod integer not null,usn integer not null,type integer not null,queue integer not null,due integer not null,ivl integer not null,factor integer not null,reps integer not null,lapses integer not null,left integer not null,odue integer not null,odid integer not null,flags integer not null,data text not null);
      CREATE TABLE revlog(id integer primary key,cid integer not null,usn integer not null,ease integer not null,ivl integer not null,lastIvl integer not null,factor integer not null,time integer not null,type integer not null);
      CREATE TABLE graves(usn integer not null,oid integer not null,type integer not null);
      """)
    let now = Int64(Date().timeIntervalSince1970)
    let base = now * 1000
    let names = Array(Set(cards.map(\.deck))).sorted()
    var decks: [String: Any] = [:]
    var ids: [String: Int] = [:]
    for (i, name) in names.enumerated() {
      let id = i + 2
      ids[name] = id
      decks[String(id)] =
        [
          "id": id, "name": name, "mod": now, "usn": -1, "desc": "", "dyn": 0, "collapsed": false,
          "conf": 1, "extendNew": 0, "extendRev": 0, "newToday": [0, 0], "revToday": [0, 0],
          "lrnToday": [0, 0], "timeToday": [0, 0],
        ] as [String: Any]
    }
    let fields: [Any] = ["Front", "Back"].enumerated().map {
      [
        "name": $0.element, "ord": $0.offset, "sticky": false, "rtl": false, "font": "Arial",
        "size": 20,
      ] as [String: Any]
    }
    let template: [String: Any] = [
      "name": "Card 1", "ord": 0, "qfmt": "{{Front}}",
      "afmt": "{{FrontSide}}<hr id=answer>{{Back}}", "bqfmt": "", "bafmt": "", "did": NSNull(),
    ]
    let model: [String: Any] = [
      "id": 1, "name": "MamStudy Basic", "type": 0, "mod": now, "usn": -1, "sortf": 0, "did": 2,
      "tmpls": [template], "flds": fields,
      "css": ".card { font-family: Arial; font-size: 20px; text-align: left; }", "latexPre": "",
      "latexPost": "", "req": [[0, "all", [0]]], "tags": [], "vers": [],
    ]
    func json(_ object: Any) throws -> String {
      String(
        decoding: try JSONSerialization.data(withJSONObject: object, options: .sortedKeys),
        as: UTF8.self)
    }
    try db.run(
      "INSERT INTO col VALUES(1,\(now),\(base),\(base),11,0,-1,0,'{}',\(sql(try json(["1":model]))),\(sql(try json(decks))),'{}','{}');BEGIN TRANSACTION;"
    )
    for (i, card) in cards.enumerated() {
      let id = base + Int64(i)
      let front = card.kind == .cloze ? card.question : card.front
      let back = card.kind == .cloze ? card.answer : card.back
      let flds =
        html(front) + "\u{1f}" + html(back + (card.example.isEmpty ? "" : "\n\n" + card.example))
      try db.run(
        "INSERT INTO notes VALUES(\(id),\(sql(UUID().uuidString)),1,\(now),-1,'',\(sql(flds)),\(sql(front)),0,0,'');INSERT INTO cards VALUES(\(id),\(id),\(ids[card.deck] ?? 2),0,\(now),-1,0,0,\(i+1),0,2500,0,0,0,0,0,0,'');"
      )
    }
    try db.run("COMMIT;")
    try Data("{}".utf8).write(to: stage.appendingPathComponent("media"))
    try FileManager.default.zipItem(
      at: stage, to: destination, shouldKeepParent: false, compressionMethod: .deflate)
  }
  private static func sql(_ s: String) -> String {
    "'" + s.replacingOccurrences(of: "'", with: "''").replacingOccurrences(of: "\0", with: "") + "'"
  }
  private static func html(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\n", with: "<br>")
  }
  private static func plain(_ s: String) -> String {
    s.replacingOccurrences(
      of: #"(?i)<br\s*/?>|</p>|</div>"#, with: "\n", options: .regularExpression
    ).replacingOccurrences(of: #"<[^>]*>|\[sound:[^\]]*\]"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&amp;", with: "&")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
  private final class Database {
    private var handle: OpaquePointer?
    init(_ url: URL, readOnly: Bool) throws {
      let flags = readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
      guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
        if let handle { sqlite3_close(handle) }
        handle = nil
        throw StudyError.invalid("Không mở được database Anki.")
      }
      sqlite3_limit(handle, SQLITE_LIMIT_LENGTH, 4_000_000)
    }
    deinit { sqlite3_close(handle) }
    func run(_ sql: String) throws {
      guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
        throw StudyError.invalid(
          "Database Anki không hợp lệ: " + String(cString: sqlite3_errmsg(handle)))
      }
    }
    func rows(_ sql: String) throws -> [[String]] {
      var statement: OpaquePointer?
      guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
        throw StudyError.invalid("Cấu trúc Anki chưa được hỗ trợ.")
      }
      defer { sqlite3_finalize(statement) }
      var result: [[String]] = []
      var status = sqlite3_step(statement)
      while status == SQLITE_ROW {
        result.append(
          (0..<sqlite3_column_count(statement)).map { index in
            guard let text = sqlite3_column_text(statement, index) else { return "" }
            return String(cString: text)
          })
        status = sqlite3_step(statement)
      }
      guard status == SQLITE_DONE else { throw StudyError.invalid("Không đọc được Anki.") }
      return result
    }
  }
}
