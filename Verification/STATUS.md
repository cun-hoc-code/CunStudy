# Mầm 2.0 — trạng thái kiểm tra

Ngày: 2026-09-18. Đây là bản nguồn để build và thử, chưa phải bản phát hành iOS đã xác nhận.

| Kiểm tra | Kết quả | Bằng chứng |
| --- | --- | --- |
| Core Swift 6.1.2 / Linux, strict concurrency, compiler warnings-as-errors | PASS: 51 tests, 0 failures; gồm 18 tests mới | core-tests-v2.log |
| Import file APKG Mầm xuất bằng thư viện Anki chính thức 26.9.2 | PASS: 2 notes / 2 cards | anki-interop-v2.log |
| Swift syntax, nhánh thường và MAM_SCREEN_TIME | PASS | swift-parse-v2.log |
| XcodeGen 2.46.0 tạo project ba app scheme + widget/monitor | PASS | xcodegen-v2.log |
| Membership các target, plist, App Groups, entitlement, icon, âm thanh và localization | PASS | structure-v2.log |
| Shell syntax build script và ZIP source CRC | PASS khi đóng gói | build/package scripts |
| Xcode iOS SDK typecheck, link và unsigned IPA 2.0 | CHƯA CHẠY — môi trường hiện tại là Linux | Chạy GitHub Actions hoặc Xcode 26+ |
| iPhone/iPad, camera, Face ID, haptic, Calendar, Screen Time, widget, Live Activity, FPS | CHƯA CHẠY | docs/DEVICE-QA-v2.0.md |
| Ký LC Sign và cài IPA mới | CHƯA CHẠY | docs/UPGRADE-v2.0.md |

Swift syntax pass không kiểm tra tên/type của SwiftUI hoặc API Apple. Test core không thay thế native compile. SwiftPM có thông báo về pkg-config/zlib và resource manifest của ZIPFoundation trên Linux; không có Swift compiler warning trong core của dự án, các tests vẫn đạt.

Không có IPA giả hoặc executable placeholder trong gói. Không push/merge vào GitHub của người dùng. Các báo cáo STATUS-v1.0/v1.1, patch v1.1 và ipa-inspection.json là tài liệu lịch sử của bản cũ, không phải bằng chứng build 2.0.

## Phạm vi

Đã triển khai mã cho các module lịch, ghi chú/tệp/OCR/PDF, flashcard, luyện đề, học vụ, mục tiêu/nhật ký, ví, animation, âm thanh, khóa app, backup, widget deadline và optional Screen Time. Xem docs/FEATURE-MATRIX-v2.0.md để biết mức hỗ trợ từng yêu cầu.

Chưa có CloudKit tự đồng bộ, Google OAuth riêng/hợp nhất lịch chạy nền, backend cộng đồng hay Apple Watch app. English dịch nhãn điều hướng/chỉnh sửa chính, chưa phủ toàn bộ nội dung. Một số tích hợp chỉ hoạt động khi provisioning profile có entitlement đúng.
