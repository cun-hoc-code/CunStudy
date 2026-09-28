# Phạm vi Mầm 2.0

“Đã triển khai” bên dưới nghĩa là có mã nguồn và luồng sử dụng. Không đồng nghĩa đã vượt qua Xcode build hoặc kiểm thử thiết bị; xem `Verification/STATUS.md`.

| Nhóm yêu cầu | Đã triển khai | Phần giới hạn / chưa có |
| --- | --- | --- |
| Lịch trình | Lịch môn/phòng/giảng viên, thi/deadline/học phí, nhắc trước, countdown, khung tự học, ngày/tuần/tháng, gợi ý giờ trống, nhật ký | Calendar qua EventKit: nhập/làm mới và xuất 30 ngày thủ công. Google phải được thêm vào Calendar iOS. Chưa đồng bộ hai chiều tự động/xóa đồng bộ. |
| Ghi chú | Văn bản, checklist, Markdown cơ bản/bảng theo hàng, môn/folder/tag, tìm nội dung và OCR, backlinks, file/ảnh/audio, viết tay PencilKit, ghi âm khi soạn, scan | Markdown không phải trình soạn WYSIWYG đầy đủ. Viết tay tạo trang mới và xem lại; chưa chỉnh sửa nét trên trang đã lưu. Chưa đồng bộ CloudKit. |
| Flashcard | 2 mặt, cloze, SRS hiện có, CSV, APKG legacy, Share Sheet, ôn nhanh, thẻ khó, quiz, nháp thẻ từ ghi chú/tài liệu | APKG không media/template/SRS/anki21b; không FSRS. Tạo thẻ offline theo dấu ':'/cloze, chưa AI sinh câu hỏi tự do. |
| Tài liệu | Lưu PDF/ảnh/audio/file/link, môn/học phần/tag, Quick Look, PDF reader/highlight/underline/comment/bookmark, OCR ảnh/scan | File slide/ebook tùy Quick Look. Link lưu URL và trích tự dán, chưa extension web clipper/Safari hoặc tải toàn trang offline. |
| Luyện tập | Ngân hàng theo môn/chương, đề từ flashcard, thi có giờ, điểm/giải thích, sổ lỗi sai, thống kê chương, chia sẻ/nhập JSON | Giải thích do người tạo nhập. Chưa ngân hàng cộng đồng online, tài khoản, moderation/backend. |
| Học vụ | Điểm thành phần, GPA/CPA theo tín chỉ, mô phỏng, điểm cần đạt, tín chỉ tốt nghiệp, học lại/môn nợ | Người dùng nhập điểm hệ 4 và quy tắc của trường. Không tự áp chính sách học lại hoặc điều kiện điểm thi. |
| Tập trung | Pomodoro, nghỉ, nền âm thanh, cây, phút học/biểu đồ/heatmap, Live Activity | Cây dựa trên thời gian phiên, không chứng minh điện thoại không được sử dụng. Chặn app chỉ ở Managed với quyền Family Controls; không tự đổi chế độ Focus của iOS. |
| Động lực | Streak, XP, cấp, huy hiệu, vườn, mục tiêu, nhắc streak | Nhắc lên lịch cục bộ 7 ngày và làm mới khi mở app; không thông báo từ server. Không leaderboard/community. |
| Tiện ích | Chi tiêu/tháng/ngân sách/biểu đồ, chia tiền/đánh dấu đã trả, học phí dưới dạng deadline, to-do/checklist | Không kết nối ngân hàng, không thanh toán và không gửi đòi tiền tự động. |
| Hệ thống | Dark/light/system, offline cho dữ liệu cục bộ, backup/restore có file, Face ID/passcode, bố cục iPad, list/grid/cards, widget deadline | iCloud Drive backup thủ công; chưa đồng bộ tự động. Tiếng Anh một phần (305 nhãn chính), chưa dịch hết thông báo/widget. Chưa app Apple Watch. |
| Animation | Tab pill matched geometry, page arrival, giấy hiện lên, hub stagger, press spring/tilt, mầm sway/fireflies, vòng tiến độ, lật thẻ, lá hoàn thành, checkmark bounce, số chuyển động | Có Reduce Motion. Chưa đo FPS, hiệu năng/pin hoặc chụp giao diện trên iPhone trong môi trường hiện tại. |

Các phần cần dịch vụ, entitlement hoặc thiết bị riêng được nêu rõ trong giao diện/tài liệu; không có nút cộng đồng hay trạng thái “đã đồng bộ” giả.
