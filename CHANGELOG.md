# 2.1.0 — import, books and tactile polish

- Thay luồng nhập cũ bằng một Import Center dùng bản sao cục bộ an toàn từ Files/iCloud, giới hạn 50 MB và giữ file gốc khi OCR không nhận ra chữ.
- Hỗ trợ trích chữ TXT/UTF-8/UTF-16, Markdown, CSV/TSV, PDF, ảnh OCR, RTF/RTFD, DOC/DOCX và HTML; PDF scan thử OCR 40 trang đầu. File khác vẫn được lưu để đính kèm.
- Tạo/sửa thẻ từ nội dung vừa nhập, tách hàng loạt dòng `câu hỏi: đáp án` và cloze; giữ nhập/xuất CSV và Anki APKG cũ.
- Thêm Phòng đọc: kệ sách, nhớ vị trí, bookmark, PDF nguyên bản hoặc dàn lại phần chữ, 10 font, cỡ chữ/khoảng dòng và 5 màu giấy.
- Dùng page curl gốc của iOS để lật trang; tự chuyển sang cuộn ngang khi bật Giảm chuyển động.
- Thay `TabView` bằng tab host giữ sống từng navigation/scroll state, chuyển cảnh spring + crossfade và xử lý chạm tab liên tiếp.
- Thêm bốn âm thanh nguyên bản cho chạm/chọn/lật trang/hoàn thành, cường độ rung và cài đặt riêng; tôn trọng chế độ im lặng, nhạc đang phát và ghi âm.
- Thêm mô hình dữ liệu tương thích backup cũ, kiểm tra bookmark/vị trí/sách mồ côi và 6 test reader/import; 57 test core đạt.
- Tăng version lên 2.1.0 (build 6). Build 5 sửa access control của page curl và kết hợp Reduce Motion bằng environment key có thể ghi an toàn. Build 6 bỏ phụ thuộc vào các hằng Word/Office không đồng nhất giữa các iOS SDK; Foundation tự nhận dạng RTF, DOC, DOCX và HTML, còn file gốc vẫn được giữ nếu không trích được chữ. Native iOS build và device QA vẫn phải chạy trên macOS/Xcode.

# 2.0.0 — source update

- Study hub, calendar day/week/month, time-blocks, free-slot suggestions, exam/tuition deadlines, configurable lead reminders, journal and goals.
- Note metadata/checklists/basic Markdown/backlinks, attachments, PencilKit, lecture recording, scanning/OCR, document library, PDF annotations/bookmarks.
- CSV/legacy Anki import/export with review preview, quick/hard-card review and editable offline note-to-card drafts.
- Question bank, timed/resumable mock tests, immutable results, mistake book, chapter analysis and JSON sharing.
- Credit-weighted GPA/CPA, component score prediction, graduation progress, expenses/budget/charts/equal bill splits.
- Garden motion system, soundscapes, deadline widget, manual full-file backup/restore, Face ID/passcode, optional Managed Screen Time target, 305 translated UI labels.
- Added 18 behavioral tests; 51 tests passing. Native iOS compile/device QA pending. Full scope and limitations: docs/FEATURE-MATRIX-v2.0.md.

# Mầm 1.1 — 17/09/2026

- Thêm ActivityKit: thời gian, mầm, tiến độ, tạm dừng và mở lại phiên từ màn hình khóa/Dynamic Island.
- Thêm streak hiện tại/dài nhất, mục tiêu ngày, XP/cấp độ, sáu huy hiệu và heatmap.
- Thêm lịch sử ôn tìm/lọc, snapshot bộ thẻ/câu hỏi/lịch tiếp theo; phân trang danh sách.
- Giữ thống kê theo môn và vườn; mở rộng biểu đồ 90 ngày/chọn ngày, nhật ký focus có tìm kiếm.
- Thêm sáng/tối/theo hệ thống, bảng màu tối cho widget, chuyển tab nhẹ, lật thẻ 3D, haptic tùy chọn và Giảm chuyển động.
- Xử lý hoàn thành phiên từ mọi tab, ghi một lần và có thẻ nhận mầm. Bắt đầu phiên mới hủy nhắc giờ nghỉ cũ.
- Đọc JSON 1.0 với mặc định cho các tùy chọn mới; log cũ không bị bịa thêm nội dung.
- Tăng version 1.1.0/build 2; bổ sung kiểm thử tiến độ và nâng cấp dữ liệu.

Xem hướng dẫn tại `docs/UPGRADE-v1.1.md`, kết quả xác minh tại `Verification/STATUS.md`.

---

# Tiếp tục từ project Mầm đang làm

## Trạng thái lúc tiếp tục

Thư mục có đầy đủ mã nguồn app, widget, lõi dữ liệu, 14 bài kiểm thử trong source, icon và cấu hình build. Chưa có README/hướng dẫn hoàn chỉnh. Không có repository Git trong thư mục nên không có lịch sử commit hay `git diff` để đối chiếu. Mã nguồn được chụp lại thành archive trước khi sửa; không thay project bằng bản khác, không sửa StudyFlow V1/V2.

## Lỗi đã sửa và phần đã hoàn thiện

- Giữ nguyên câu hỏi đang ôn; không tự chuyển sang thẻ khác khi có thẻ đến hạn trong lúc người dùng đang trả lời.
- Chỉ chuyển sang thẻ tiếp theo sau khi lưu kết quả thành công. Hoàn tác không ghi đè thẻ đã chỉnh sửa hoặc khôi phục thẻ đã xóa.
- Lưu thời gian theo ISO-8601 có phần lẻ, tránh sai số do nhiều lần tạm dừng/tiếp tục. Vẫn đọc định dạng ngày cũ không có phần lẻ.
- Xuất backup chụp trạng thái focus tại thời điểm xuất mà không dừng đồng hồ thật. Mọi đường khôi phục đều đưa đồng hồ lịch sử về tạm dừng, tránh cộng thời gian ngoài ý muốn.
- Không xuất dữ liệu trống hoặc ghi đè snapshot widget khi app đang ở chế độ bảo vệ vì không đọc được dữ liệu gốc.
- Có nút lấy lại dữ liệu trước lần nhập gần nhất, thay vì chỉ lưu một file phục hồi khó truy cập trong sandbox app.
- Kiểm tra dữ liệu ngay tại tầng ghi đĩa; từ chối mã bước checklist trùng, dữ liệu ôn tập sai, lịch lặp có ngày trùng và phiên focus vừa đang chạy vừa nằm trong lịch sử.
- Ôn thẻ tôn trọng ngày đến hạn của thẻ mới; có thứ tự ổn định khi trùng thời gian. Điền khuyết hỗ trợ xuống dòng. TSV nhận BOM, cắt khoảng trắng, từ chối cột thừa.
- Báo thức thử dùng ID cố định để không bị hủy khi mở lại app. Không truy vấn danh sách AlarmKit khi chưa được cho phép. Có trạng thái quyền âm thanh riêng và không báo thành công nếu chưa đặt được giờ nghỉ.
- Dành một khoảng chạy nền ngắn để hoàn tất việc đồng bộ nhắc sau thao tác lưu; không dùng tiến trình nền liên tục để đếm giờ.
- Tách cấu hình widget của Basic và Full; thêm privacy manifest cho extension, kiểm tra group dùng chung.
- Biểu đồ dùng một đường mục tiêu; thêm định hướng màn hình cho iPad, các import framework rõ ràng.
- Build script chạy được từ đường dẫn khác, ghi log XcodeGen/toolchain, xóa IPA đầu ra cũ trước rebuild và đóng gói qua thư mục mới để tránh giữ file cũ.
- Sinh project bằng XcodeGen 2.46.0 và sửa lỗi Basic: scheme trỏ tới `MamStudyBasic.app` nhưng `PRODUCT_NAME` trước đó bị ép thành `MamStudy`. Tên executable, product reference, scheme và đường dẫn đóng gói nay cùng theo tên target. Tên hiển thị trên iPhone vẫn là Mầm.
- Tăng kiểm tra tài nguyên: kích thước và định dạng RGB của từng icon, entitlement và Info.plist.
- Bổ sung hướng dẫn GitHub/IPA/ký, file TSV mẫu và checklist thử máy thật.

Kết quả đã chạy và các bước chưa thể xác nhận được ghi riêng trong `Verification/STATUS.md`. Sửa mã và kiểm thử lõi không đồng nghĩa đã build thành công app iOS.
