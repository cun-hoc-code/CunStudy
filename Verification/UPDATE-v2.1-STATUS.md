# Trạng thái xác minh Mầm 2.1

Thời điểm kiểm tra: 2026-09-24 (UTC).

## Đã chạy trong môi trường này

- `swift test` cho Core/Storage: **57 test, 0 failure**.
- Parse cú pháp toàn bộ Swift trong App/Core/Storage/Shared/Widget/FocusMonitor/Tests: **PASS**.
- `scripts/validate_project.py`: kiểm tra plist, entitlement, privacy manifest, icon, wiring target, localization, WAV và module 2.1.
- Xcode project được sinh lại từ `project.yml` bằng XcodeGen 2.46.0; các file import/reader/tab/feedback và bốn WAV đều nằm trong target phù hợp.
- Source ZIP được kiểm tra CRC sau khi đóng gói.

## Chưa thể xác nhận trên Linux

- Không có iOS SDK/Xcode nên chưa type-check/build SwiftUI, UIKit, PDFKit, VisionKit, PhotosUI, WidgetKit hoặc ActivityKit.
- Chưa tạo IPA 2.1 và chưa ký.
- Chưa thử page curl, Files/iCloud provider, OCR, âm thanh/rung, xoay màn hình hay hiệu năng trên iPhone/iPad thật.

Vì vậy, kết quả core và parse không được coi là bằng chứng IPA đã build. Bước phát hành tiếp theo là chạy GitHub Actions/macOS Xcode, sau đó chạy `docs/DEVICE-QA-v2.1.md` trên máy thật.
