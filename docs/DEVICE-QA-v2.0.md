# Kiểm tra trên thiết bị trước khi dùng chính thức

Các mục này CHƯA được đánh dấu đạt. Chạy sau khi Xcode build thành công.

- Nâng từ 1.1: sao lưu trước, cài đè cùng bundle ID, kiểm tra lịch/thẻ/streak/lịch sử/ghi chú; không gỡ app trước khi sao lưu.
- Lịch: giờ qua nửa đêm, ngày/tuần/tháng, ngày có sự kiện cả ngày, chồng time-block, deadline quá giờ trong cùng ngày; nhắc trước 0/60/180 phút.
- Calendar: từ chối/quyền giới hạn/quyền đầy đủ; chọn riêng từng lịch; xuất lặp không nhân đôi; thay giờ; không sửa lịch cá nhân.
- Ghi chú: lưu/dismiss/đổi app; scan 1 và 20 trang; OCR tiếng Việt có dấu; từ chối camera; checklist, bảng Markdown, backlinks trùng tiêu đề; search OCR.
- Audio: từ chối mic, bắt đầu/dừng nhanh, cuộc gọi/ngắt audio, khóa máy, rời app, lưu trong khi đang thu, báo lỗi ghi disk và thử lại; phát tệp đã đính kèm.
- PencilKit: vẽ bằng ngón tay/Apple Pencil, undo, trang trắng, preview trang có nét lớn; hiện bàn phím và xoay iPad.
- PDF: nhiều trang, highlight/underline, comment, bookmark, undo, rời rồi mở lại; PDF không có lớp chữ; file lỗi.
- Flashcard: lật/haptic, 4 mức nhớ, cloze, quick review, thẻ khó, undo lịch ôn, import CSV dấu phẩy/ngoặc kép/xuống dòng, APKG legacy/modern lỗi rõ ràng.
- Thi thử: trả lời, chuyển câu, đóng/mở lại, khóa máy qua hạn giờ, hết giờ khi tab khác đang mở, nộp 2 lần; sửa/xóa câu gốc không đổi kết quả đã lưu.
- GPA: tổng trọng số chưa đủ/đủ/vượt 100%, điểm mục tiêu không thể đạt, chưa có điểm, học lại/tín chỉ; tiền chia không chia hết.
- Backup: .mamstudy chứa PDF/ảnh/audio/drawing; chuyển thiết bị, khôi phục và khôi phục bản trước nhập; file zip lỗi/thiếu file; JSON cũ không attachment; dung lượng gần giới hạn.
- Face ID: bật/tắt, hủy, fallback mật mã, app switcher, đang mở sheet/PDF/ghi chú khi khóa, khôi phục bản có lock bật; không lộ nội dung sau tấm che.
- Focus: chạy/tạm dừng/tiếp tục/kết thúc, haptic/âm thanh/mầm, chế độ Reduce Motion và VoiceOver, Live Activity khóa màn hình, Dynamic Island.
- Managed: từ chối quyền, chọn app, phiên 16/25 phút, mở chặn ngay, tạm dừng, force quit, hết giờ khi app đóng; kiểm tra extension thực sự gỡ shield. Nếu không đạt, tắt bảo vệ và dùng timer thường.
- Widget Full: App Groups hợp lệ, lịch/deadline/streak sau nửa đêm, bản Basic không hiện chức năng không có; LC Sign giữ extension/quyền đúng.
- UI: sáng/tối, chữ lớn nhất, VoiceOver, xoay iPad, tiếng Anh/VN, bàn phím không che nút lưu. Đo animation/pin trên iPhone trước phát hành.
