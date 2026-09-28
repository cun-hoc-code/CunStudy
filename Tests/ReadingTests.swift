import Foundation
import XCTest

@testable import StudyCore

final class ReadingTests: XCTestCase {
  func testTextDecoderReadsUTF8AndNormalizesNewlines() throws {
    let data = Data("Dòng một\r\nDòng hai\rDòng ba".utf8)
    XCTAssertEqual(try TextFileDecoder.decode(data), "Dòng một\nDòng hai\nDòng ba")
  }

  func testTextDecoderReadsUTF16BOM() throws {
    var data = Data([0xFF, 0xFE])
    data.append(try XCTUnwrap("Mầm đọc sách".data(using: .utf16LittleEndian)))
    XCTAssertEqual(try TextFileDecoder.decode(data), "Mầm đọc sách")
  }

  func testTextDecoderRejectsBinaryNUL() {
    XCTAssertThrowsError(try TextFileDecoder.decode(Data([0x41, 0x00, 0x42])))
  }

  func testReaderFieldsRemainCompatibleWithOlderWorkspaceJSON() throws {
    var state = StudyState()
    let document = LibraryDocument(title: "Sách cũ", extractedText: "Một đoạn sách")
    state.studio.documents = [document]
    state.studio.readingRoom.books = [
      BookRecord(documentID: document.id, title: document.title, bookmarks: [4])
    ]
    state.studio.interaction = FeedbackPreferences(sound: false, volume: 0.1, strength: 0.2)

    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: StateCodec.encode(state)) as? [String: Any])
    var workspace = try XCTUnwrap(root["workspace"] as? [String: Any])
    workspace.removeValue(forKey: "feedback")
    var reading = try XCTUnwrap(workspace["reading"] as? [String: Any])
    var books = try XCTUnwrap(reading["books"] as? [[String: Any]])
    books[0].removeValue(forKey: "storedPDFBookmarks")
    reading["books"] = books
    workspace["reading"] = reading
    root["workspace"] = workspace

    let decoded = try StateCodec.decode(JSONSerialization.data(withJSONObject: root))
    XCTAssertEqual(decoded.studio.readingRoom.books.first?.bookmarks, [4])
    XCTAssertEqual(decoded.studio.readingRoom.books.first?.pdfBookmarks, [])
    XCTAssertEqual(decoded.studio.interaction, FeedbackPreferences())
  }

  func testReaderValidationRejectsNegativePDFBookmark() {
    var state = StudyState()
    let document = LibraryDocument(title: "PDF", kind: .pdf)
    state.studio.documents = [document]
    var book = BookRecord(documentID: document.id, title: "PDF")
    book.pdfBookmarks = [-1]
    state.studio.readingRoom.books = [book]
    XCTAssertThrowsError(try WorkspaceValidation.validate(state))
  }

  func testReaderValidationRejectsMissingSourceDocument() {
    var state = StudyState()
    state.studio.readingRoom.books = [
      BookRecord(documentID: UUID(), title: "Sách không có file")
    ]
    XCTAssertThrowsError(try WorkspaceValidation.validate(state))
  }
}
