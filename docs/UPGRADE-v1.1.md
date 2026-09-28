# Mầm 1.1 — bản nâng cấp từ IPA 1.0 của bạn

Gói này là **toàn bộ project SwiftUI**, bao gồm project Xcode, tài nguyên, widget/Live Activity, kiểm thử và GitHub Actions. File IPA 1.0 bạn gửi không bị sửa trực tiếp. Cần build và ký IPA mới từ mã nguồn 1.1 để dùng tính năng mới.

## Những gì được thêm

| Yêu cầu | Nơi sử dụng |
| --- | --- |
| Thời gian + mầm trên màn hình khóa | Bật Hoạt động trực tiếp trong Cài đặt Mầm, bắt đầu một phiên Tập trung, khóa máy. Chạm hoạt động để trở lại app. |
| Dynamic Island | Cùng Live Activity, có dạng nhỏ/gọn/mở rộng trên iPhone hỗ trợ. Máy không có Dynamic Island vẫn dùng màn hình khóa. |
| Streak học | Thẻ màu đào ở Hôm nay; chạm để mở Vườn & nhịp học. Có chuỗi hiện tại và kỷ lục. |
| Thống kê trực quan | Biểu đồ 7/30/90 ngày, chọn phút hoặc lượt ôn; chạm/kéo để xem ngày. Heatmap 84 ngày có thể chạm từng ô. |
| Lịch sử ôn | Ôn thẻ → Xem lịch sử ôn tập. Lọc thời gian, bộ thẻ, mức nhớ và tìm câu hỏi. Có thời điểm ôn và lịch ôn được đặt lúc chấm. |
| Haptic | Rung nhẹ khi lật thẻ/đổi tab/chấm thẻ; rung thành công khi hoàn thành phiên ở foreground. Có nút tắt. |
| Animation | Lật thẻ 3D, nội dung tab hiện nhẹ, nút có phản hồi nhấn, vòng tiến độ và mầm lớn dần, mừng hoàn thành. Tôn trọng Giảm chuyển động. |
| Dark mode | Cài đặt → Giao diện → Theo hệ thống / Sáng / Tối, áp dụng ngay; màu nền giấy, mực và pastel đều có biến thể tối. Widget theo giao diện hệ thống. |
| Sáng tạo thêm | Mục tiêu tập trung + ôn thẻ từng ngày, XP/cấp độ, 6 huy hiệu, nhật ký tập trung có tìm kiếm, banner quay lại phiên đang chạy/nhận mầm mới. |

Giữ nguyên lịch học, việc cần làm, ghi chú, TSV, sao lưu, thuật toán ôn giãn cách và báo thức AlarmKit đã có. Thống kê theo môn và vườn các phiên được giữ trong Vườn & nhịp học.

## Cách tính rõ ràng

- Một ngày giữ streak khi **ít nhất 5 phút tập trung đã lưu HOẶC ôn 5 thẻ khác nhau**. Các mức tự chấm đều tính là đã học.
- Thời gian tạm dừng và phiên bị bỏ không được tính. Phiên qua nửa đêm được chia phút về đúng ngày.
- Nếu hôm nay chưa đủ mục tiêu giữ streak, chuỗi đến hôm qua vẫn còn. Chỉ đứt khi đã bỏ trống cả một ngày.
- Mục tiêu phút/thẻ trong Cài đặt là mục tiêu riêng của bạn; đổi chúng không sửa quy tắc streak hay lịch sử.
- XP mỗi ngày: 2 XP/phút, tối đa 120 phút; 5 XP/thẻ khác nhau, tối đa 100 thẻ. Ôn lặp một thẻ không nhân XP trong cùng ngày. Mỗi 250 XP lên một cấp.
- Streak/XP/huy hiệu được tính từ dữ liệu đã lưu. Hoàn tác chấm thẻ sẽ tính lại, không để lại điểm giả. Các ngày dùng múi giờ hiện tại của thiết bị; đổi múi giờ có thể đổi cách chia ngày.
- Không tạo dữ liệu mẫu để làm đẹp thống kê. Lịch sử trống sẽ có hướng dẫn bắt đầu.

## Cập nhật repo đang có và lấy IPA mới

Bạn đã tạo được IPA, nên **tiếp tục dùng repository Mầm hiện tại**.

1. Trong app cũ, xuất bản sao lưu JSON nếu đã có dữ liệu học thật.
2. Giải nén `MamStudy-source.zip`. Chép toàn bộ nội dung bên trong thư mục `MamStudy` vào thư mục repository hiện tại, ghi đè file cùng tên. Chép cả `.github`; giữ thư mục `.git` của repo hiện tại.
3. Mở terminal tại repository, kiểm tra rồi commit/push:

   ```bash
   git status --short
   git diff --stat
   git add .
   git commit -m "Add Live Activity, study streaks, history and dark mode"
   git push
   ```

4. Trên GitHub mở **Actions → Build MamStudy IPA**. Chờ job **MamStudy** của commit vừa push chạy thành công.
5. Tải artifact `MamStudy-unsigned-ipa`, giải nén để lấy IPA. Trong Cài đặt → Về Mầm sẽ hiện **1.1**.
6. Ký app **và extension** theo cách đang dùng, rồi cài bản cập nhật. Giữ bundle identifier/team nếu muốn nâng cấp tại chỗ. Nếu phải gỡ app hoặc đổi cách ký, khôi phục từ JSON đã xuất.
7. Bật Hoạt động trực tiếp trong cài đặt iPhone nếu đang tắt. Thử phiên 5 phút theo checklist bên dưới.

**Chọn bản `MamStudy`, không chọn `MamStudyBasic`, để có Live Activity.** Basic vẫn có streak, lịch sử, dark mode và các tính năng trong app, nhưng không nhúng widget extension nên không có màn hình khóa của phiên học.

Nếu build thất bại, tải artifact `MamStudy-build-logs` của **lượt build mới**. Gói source có kiểm thử tự động, nhưng chỉ Xcode/iOS SDK mới xác nhận được toàn bộ SwiftUI/WidgetKit/ActivityKit.

## Live Activity khi app ở nền

Live Activity dùng `ActivityKit` và bộ đếm ngày giờ của hệ thống. Không chạy một vòng lặp nền để vẽ mỗi giây. Timer đếm về 0; `staleDate` cho phép giao diện chuyển sang trạng thái đến giờ nghỉ. **Không có máy chủ push hay tác vụ nền bảo đảm kết thúc Activity đúng giây khi app bị đóng**: app lưu kết quả và kết thúc Activity khi được chạy lại. Lúc app đang mở, hoàn thành được xử lý từ mọi tab.

Tạm dừng làm đồng hồ đứng yên; tiếp tục tính lại mốc kết thúc; kết thúc sớm/bỏ phiên gỡ hoạt động. Thời gian trên Activity có thể cập nhật chậm theo hệ thống. Giờ kết thúc vẫn được lên lịch bằng thông báo cục bộ nếu đã cấp quyền. Haptic của giao diện chỉ phát khi app đang hoạt động; rung/âm thanh thông báo lúc khóa máy phụ thuộc thiết lập iPhone.

Activity không phụ thuộc snapshot App Group để chạy bộ đếm; các widget lịch/nhịp học vẫn cần App Group. Cách ký phải giữ extension và các quyền tương ứng. Nút tắt/bật lại Mầm trên màn hình khóa cho phép yêu cầu lại Activity của phiên hiện tại; khi bạn vuốt bỏ Activity, các thao tác ôn thẻ không tự tạo lại trong cùng lần chạy app.

Nguồn API: [Apple — Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities), [Apple — bộ đếm theo khoảng ngày](https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:)).

## Dữ liệu cũ

Các trường mới đều tương thích với JSON v1. Thiết lập giao diện mặc định là Theo hệ thống, haptic/Live Activity bật sẵn trong app (quyền hệ thống vẫn do người dùng quyết định). Không yêu cầu tạo tài khoản.

Lượt ôn mới chụp tên bộ thẻ, câu hỏi (tối đa 500 ký tự) và thời điểm ôn tiếp theo. Sửa/xóa thẻ không xóa những bản chụp đó. Lượt ôn 1.0 vốn chỉ có ID thẻ, giờ và mức nhớ: app lấy câu hỏi hiện tại nếu còn thẻ, ghi rõ nếu thẻ đã xóa; không thể phục hồi nội dung mà bản cũ chưa lưu.

## Trạng thái xác minh

Xem `Verification/STATUS.md`. Kiểm tra nguồn và kiểm thử lõi đã được thực hiện; **chưa build IPA 1.1 bằng Xcode, chưa chạy Simulator/iPhone trong phiên làm việc này**. Checklist cần chạy trên máy thật nằm trong `docs/DEVICE-QA.md`.
