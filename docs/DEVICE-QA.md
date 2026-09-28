# Kiểm tra trên iPhone sau khi build và ký

Các mục dưới đây **chưa được chạy trong môi trường Linux tạo gói source**. Dùng để nghiệm thu bản IPA thực tế, ghi phiên bản iOS, scheme và công cụ ký trước khi thử. Có thể dùng dữ liệu thử riêng và xuất backup trước khi thay đổi dữ liệu chính.

| Tình huống | Kết quả cần có |
| --- | --- |
| Cài lần đầu | Mở được app, hoàn tất giới thiệu, cả 5 tab hoạt động. Không có popup xin quyền ngoài ý muốn. |
| Lịch tuần | Tạo lịch thứ 2/thứ 5, đổi giờ, phòng và màu; các ngày hiển thị đúng. Tắt/xóa lịch thì hết hiển thị. |
| Lịch một lần | Ngày xa hơn hai tuần vẫn có thể xuất hiện là lịch tiếp theo nếu không có lịch gần hơn. |
| Qua nửa đêm | Lịch 23:30–01:00 còn hiện đang diễn ra sau 00:00. Chuẩn bị trước 00:10 một khoảng 40 phút rơi về 23:30 ngày trước. |
| Trùng giờ | Hai lịch chồng giờ có cảnh báo; một lịch kết thúc đúng lúc lịch khác bắt đầu thì không báo trùng. |
| Todo | Thêm checklist và deadline; hoàn thành/xóa thì nhắc deadline được gỡ. Mở lại app vẫn giữ trạng thái. |
| Focus | Chạy, khóa máy, mở lại; số còn lại tính đúng. Tạm dừng rồi đợi: không cộng thời gian nghỉ. Quay lại sau giờ kết thúc: chỉ có một phiên, không cộng quá thời lượng đặt. |
| Thống kê | Phút trong phiên qua nửa đêm được chia đúng ngày. Biểu đồ chỉ có một đường mục tiêu. Phiên bỏ không được tính. |
| Ôn thẻ | Câu hỏi giữ nguyên khi có thẻ khác đến hạn; lật rồi mới chấm; thẻ quên trở lại sau khoảng một phút. Hoàn tác phục hồi thẻ/lịch ôn, không khôi phục thẻ đã sửa/xóa. |
| Điền khuyết | `{{đáp án}}` bị che cả khi chứa xuống dòng. Khi lật, nội dung hiện đủ. |
| TSV | Nhập file mẫu; một dòng sai phải hủy cả lần nhập, không lưu một phần. Không bỏ mất cột thừa một cách im lặng. |
| Ghi chú | Thêm/sửa/tìm kiếm/ghim, chọn các loại ghi chú và mở lại app để kiểm tra. |
| Backup | Xuất JSON trong lúc focus đang chạy; nhập lại phải ở trạng thái dừng hoặc đã hoàn thành, không cộng thời gian từ lúc xuất đến lúc nhập. Dùng nút lấy lại dữ liệu trước nhập để phục hồi. |
| Từ chối quyền | Lịch chọn báo thức/thông báo vẫn lưu, nhưng app báo chưa đặt được nhắc. Không hiển thị thành công giả. |
| Báo thức iOS 26+ | Cấp quyền, thử sau 30 giây; thử khi khóa máy, im lặng, Focus và app không mở. Mở lại Mầm trong 30 giây không làm hủy báo thức thử. |
| Sửa báo thức | Đổi giờ, đổi ngày, tắt, xóa rồi khóa máy. Chỉ lịch mới được đặt; theo dõi trạng thái trong Cài đặt. |
| Widget đầy đủ | Thêm cả hai widget; sửa lịch/địa điểm; dữ liệu mới được gửi, iOS cập nhật; chạm mở đúng tab. Kiểm tra không trống do App Groups bị bỏ khi ký. |
| Widget theo thời gian | Tới giờ học chuyển từ tiếp theo sang đang học; hết tiết chuyển sang lịch kế; qua ngày mới không giữ thống kê hôm qua. |
| Basic | App hoạt động khi không có entitlement App Groups; Cài đặt ghi rõ không có widget. |
| Khả năng đọc | Màn hình nhỏ, chữ lớn, VoiceOver, bàn phím tiếng Việt, xoay iPad; nút lưu/xóa vẫn truy cập được. |

Đồng hồ và thống kê không đo được sự chú ý thực tế. WidgetKit có thể trì hoãn việc vẽ lại theo chính sách hệ thống. Không đánh dấu mục báo thức/widget đạt chỉ vì Simulator hiển thị giao diện.

## Bổ sung nghiệm thu bản 1.1

| Tình huống | Kết quả cần có |
| --- | --- |
| Live Activity Full | Bắt đầu 5 phút, khóa màn hình: mầm, tên môn, đồng hồ giảm, thanh tiến độ tăng. Chạm mở đúng Tập trung. |
| Máy có Dynamic Island | Thử dạng compact, minimal khi có hoạt động khác, nhấn giữ expanded; đồng hồ không bị cắt. |
| Tạm dừng/tiếp tục | Pause trong app rồi khóa máy: đồng hồ đứng yên. Resume: cộng đúng thời gian còn lại, không tính thời gian nghỉ. |
| Hết giờ khi app mở | Thử từ tab Hôm nay, Ôn thẻ, Tập trung: phiên chỉ được lưu một lần, không vượt thời lượng; có haptic nếu bật và thẻ nhận mầm. |
| Hết giờ ở nền/đóng app | Đồng hồ Activity về 0, hiển thị đến giờ nghỉ khi hệ thống đánh dấu stale. Mở app: lưu đúng một phiên, kết thúc Activity. Không yêu cầu có haptic UIKit lúc app đóng. |
| Hủy/kết thúc sớm | Activity biến mất. Lưu sớm chỉ ghi số giây đã học; bỏ phiên không cộng phút/XP/streak. |
| Tắt quyền/thiếu extension | Phiên focus vẫn hoạt động; app báo trạng thái thực tế. Basic không hiện công tắc khả dụng. |
| Tắt/bật Live Activity | Tắt gỡ hoạt động, bật lại khi phiên đang chạy tạo lại được; vuốt bỏ hoạt động rồi sửa thẻ không làm nó liên tục xuất hiện lại. |
| Streak | Tạo 5 phút đã lưu hoặc ôn 5 thẻ khác nhau: tăng ngày một lần. Ôn lặp một thẻ không đủ 5 thẻ. Chuỗi hôm qua còn đến hết hôm nay. |
| Undo & lịch sử | Undo xóa lượt chấm đó và tính lại XP/streak; sửa/xóa thẻ vẫn thấy snapshot của lượt ôn mới. Log cũ chưa có snapshot ghi rõ. |
| Biểu đồ & heatmap | Đổi 7/30/90 ngày, đổi phút/lượt ôn, kéo chọn ngày; so số với lịch sử. Mỗi biểu đồ có một đường mục tiêu. |
| Dark mode | Bật theo hệ thống/sáng/tối, mở lại app, thử Form/sheet/bàn phím/chart/widget; chữ rõ trên mọi màu thẻ. |
| Lật thẻ | Đáp án không hiện trước lúc lật, không bị ngược chữ, bàn phím đóng trước khi lật; thẻ kế tiếp không chớp lộ đáp án. |
| Haptic/Reduce Motion | Tắt haptic thì các thao tác không rung. Bật Giảm chuyển động: lật/đổi tab/nhận mầm không có hiệu ứng xoay/nhảy. |
| Nâng cấp JSON | Nhập backup 1.0, kiểm tra tên/mục tiêu/cards/lịch sử/focus; xuất mới rồi nhập lại. Không mất dữ liệu hoặc cộng thời gian lúc đã tạm dừng. |
| Nhắc nghỉ | Đặt nghỉ rồi bắt đầu focus mới: không còn thông báo giờ nghỉ cũ chen ngang. |
