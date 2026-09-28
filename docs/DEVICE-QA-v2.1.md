# Device QA cho Mầm 2.1

Ghi lại model iPhone/iPad, phiên bản iOS, scheme và cách ký. Thử cả Light, Dark và tùy chọn Giảm chuyển động.

## Nhập tài liệu và flashcard

- [ ] Nhập TXT UTF-8, TXT UTF-16, Markdown, DOCX, HTML và PDF từ **Trên iPhone của tôi**.
- [ ] Nhập một file trong iCloud Drive chưa tải sẵn; app chờ tải và không báo thành công giả.
- [ ] Nhập ảnh từ Photos, ảnh không có chữ và ảnh tiếng Việt; ảnh vẫn được lưu khi OCR không thành công.
- [ ] Nhập PDF có lớp chữ, PDF scan và PDF khóa mật khẩu.
- [ ] Hủy file picker giữa chừng; app không treo và không hiện kết quả cũ.
- [ ] File trên 50 MB bị từ chối với thông báo rõ ràng.
- [ ] Từ nội dung nhập, tạo thẻ thủ công, tách dòng `câu hỏi: đáp án`, sửa preview và lưu nhiều thẻ.
- [ ] Nhập/xuất CSV và APKG legacy vẫn hoạt động; thẻ trùng không bị thêm lặp.

## Phòng đọc

- [ ] Thêm TXT, DOCX và PDF vào kệ; đóng/mở lại app vẫn còn sách.
- [ ] Vuốt tiến/lùi nhiều trang: hiệu ứng curl đúng hướng, không trang trắng và không nhảy sai trang.
- [ ] Bật Giảm chuyển động: page curl đổi thành cuộn ngang nhẹ.
- [ ] Thử đủ 10 font, cỡ 12–36, khoảng dòng 0–16 và 5 màu giấy; không mất vị trí đọc khi dàn trang lại.
- [ ] PDF chuyển qua lại giữa trang gốc và chữ dàn lại; PDF scan không có chữ luôn mở được trang gốc.
- [ ] Tạo/xóa bookmark, nhảy tới bookmark, đóng mở lại và xác nhận vị trí được nhớ.
- [ ] Xoay iPhone/iPad, thay kích thước Split View và đổi Dynamic Type khi đang đọc.
- [ ] Xóa tài liệu gốc: sách liên quan biến mất khỏi kệ, không còn bản ghi mồ côi.

## Chuyển tab, âm thanh và rung

- [ ] Cuộn sâu trong mỗi tab, đổi qua lại và xác nhận navigation/scroll state không bị reset.
- [ ] Chạm 5 tab liên tiếp thật nhanh; chuyển động không chồng view, nhấp nháy hoặc kẹt tab.
- [ ] Bật Giảm chuyển động: tab đổi ngay, không spring/crossfade kéo dài.
- [ ] Thử các mức âm lượng/rung; lật flashcard, lật sách và hoàn thành focus cho phản hồi đúng loại.
- [ ] Bật công tắc im lặng: không phát click. Phát nhạc/podcast: Mầm không chen âm thanh.
- [ ] Bắt đầu ghi âm bài giảng: click không làm đổi audio session hay ngắt bản thu.

## Hồi quy

- [ ] Focus, Live Activity, widget, streak, heatmap, nhắc deadline, Face ID và dark mode vẫn hoạt động.
- [ ] Xuất `.mamstudy`, xóa dữ liệu thử nghiệm, khôi phục và xác nhận tài liệu/sách/bookmark được giữ.
- [ ] Nâng cấp trên bản 2.0 có dữ liệu thật; không crash và cài đặt mới có mặc định hợp lý.
