# Mầm 2.1 — import, flashcard và phòng đọc

Bản nâng cấp mã nguồn cho iPhone/iPad: sửa luồng nhập file/ảnh, tạo flashcard từ OCR và tài liệu, kệ sách riêng với lật trang kiểu giấy, 10 font, 5 màu giấy, chuyển tab mượt hơn, âm thanh và rung tinh tế. Toàn bộ tính năng 2.0 về lịch, ghi chú, Anki, thi thử, GPA, focus, streak, widget và dark mode được giữ nguyên.

**Chưa có IPA 2.1 đã build/ký trong gói này.** 57 kiểm thử core đạt trên Linux; SwiftUI/PDFKit/VisionKit, page curl, entitlement, widget và hành vi trên thiết bị vẫn cần Xcode/GitHub Actions và kiểm tra máy thật.

- [Nâng cấp 2.1, GitHub Actions và LC Sign](docs/UPGRADE-v2.1.md)
- [Trạng thái xác minh 2.1](Verification/UPDATE-v2.1-STATUS.md)
- [Checklist iPhone/iPad cho import, sách và animation](docs/DEVICE-QA-v2.1.md)
- [Phạm vi tính năng nền 2.0](docs/FEATURE-MATRIX-v2.0.md)

Gói gồm toàn bộ nguồn, Xcode project/XcodeGen config, test, resources và CI cho MamStudyBasic, MamStudy và MamStudyManaged. Dữ liệu v1.1 được đọc tương thích; sao lưu trước khi cài bản mới.

---

## Tài liệu nền v1.1 (lưu để tham khảo)

# Mầm 🌱

**Mỗi ngày, lớn thêm một chút.** Sổ học tập cá nhân bằng SwiftUI: lịch ở trường, lịch tự học, việc cần làm, tập trung, ôn thẻ và ghi chú. Giao diện nền giấy, màu bút chì và nét viền vẽ tay, có chế độ sáng/tối.

Đây là **project mã nguồn**, chưa phải file IPA đã biên dịch. Trạng thái kiểm tra thực tế nằm trong [Verification/STATUS.md](Verification/STATUS.md). Build iOS cần macOS + Xcode; workflow GitHub Actions đã được chuẩn bị để tạo IPA chưa ký. Không dùng lại mã nguồn StudyFlow cũ.

## Bản 1.1 — tiếp tục từ IPA đã build

Đã thêm Live Activity màn hình khóa/Dynamic Island, streak, XP/cấp độ, huy hiệu, mục tiêu ngày, lịch sử ôn có bộ lọc, biểu đồ 7/30/90 ngày và heatmap 84 ngày. Haptic và animation có thể dùng với dark mode. Xem **[hướng dẫn cập nhật 1.1](docs/UPGRADE-v1.1.md)** trước khi build lại.

IPA 1.0 do bạn gửi đã được kiểm tra cấu trúc: ZIP hợp lệ, app và widget là executable ARM64 cho thiết bị iOS. **Bản 1.1 trong gói này chưa được build bằng Xcode hoặc chạy trên iPhone ở phiên làm việc này.**

## Bắt đầu

- Dùng Arch/Windows, muốn tạo IPA: mở **[HUONG-DAN.md](HUONG-DAN.md)**.
- Muốn hiểu các phần đã sửa: [CHANGELOG.md](CHANGELOG.md).
- Ký và cài bản có widget: [docs/SIGNING.md](docs/SIGNING.md).
- Kiểm tra sau khi cài lên iPhone: [docs/DEVICE-QA.md](docs/DEVICE-QA.md).

## Các tính năng đã có trong mã nguồn

| Phần | Chức năng |
| --- | --- |
| Hôm nay | Lịch đang diễn ra/tiếp theo, giờ chuẩn bị đi học, việc sắp đến hạn, thời gian tập trung, thẻ chờ ôn và ghi chú ghim. |
| Kế hoạch | Tách Ở trường / Tự học / Cá nhân; lịch tuần hoặc một lần; phòng học, giảng viên, ghi nhớ, màu môn học; cảnh báo trùng giờ. |
| Todo | Môn học, ưu tiên, deadline, nhắc hạn, checklist, hoàn thành, tìm kiếm và lọc. |
| Tập trung | Phiên 5–120 phút, mầm cây theo tiến độ, tạm dừng/tiếp tục, lưu phiên ngắn hoặc bỏ phiên; thông báo hết phiên và giờ nghỉ. |
| Phân tích | Tổng phút/giờ, biểu đồ 7/30/90 ngày có chọn ngày, heatmap 84 ngày, thống kê theo môn, streak, XP/cấp độ, huy hiệu, nhật ký tập trung và vườn mầm. |
| Nhắc học | Báo thức AlarmKit trên iOS 26+; nhắc trước giờ học theo thời gian chuẩn bị + di chuyển; lịch lặp tuần. Có chế độ thông báo thường riêng. |
| Sổ tay | Ghi nhanh, sách cần mua, môn học, điều quan trọng; ghim, màu, tìm kiếm. |
| Ôn thẻ | Bộ thẻ, từ vựng, hỏi–đáp, điền khuyết `{{...}}`; nhớ trước khi lật; bốn mức tự chấm; lịch ôn giãn cách, giới hạn thẻ mới, hoàn tác, giọng đọc hệ thống. |
| Lịch sử ôn | Lọc thời gian/bộ thẻ/mức nhớ, tìm nội dung, bản chụp câu hỏi khi chấm, lịch ôn tiếp theo; giữ log khi xóa thẻ. |
| Giao diện | Sáng/tối/theo hệ thống, lật thẻ 3D, tab hiện nhẹ, rung có tùy chọn, tôn trọng Giảm chuyển động. |
| Nhập thẻ | TSV UTF-8 gồm câu hỏi, đáp án và ví dụ tùy chọn. Có file mẫu trong `Examples/`. Không nhập `.apkg`. |
| Widget | Lịch tiếp theo và Nhịp học; lịch hỗ trợ nhỏ/vừa/lớn và hình chữ nhật trên màn hình khóa. Chạm mở đúng mục trong app. |
| Live Activity | Mầm, đồng hồ hệ thống, tiến độ, tạm dừng và trạng thái kết thúc trên màn hình khóa/Dynamic Island; bản đầy đủ. |
| Dữ liệu | JSON trên máy, ghi nguyên tử, bản lưu trước đó, xuất/nhập, lấy lại dữ liệu trước lần nhập gần nhất. Không tài khoản hoặc backend. |

## Hai bản build

| Scheme | Đặc điểm | File đầu ra |
| --- | --- | --- |
| `MamStudy` | Đầy đủ, kèm widget, Live Activity và App Groups | `MamStudy-unsigned.ipa` |
| `MamStudyBasic` | Chức năng trong app; không có widget/Live Activity | `MamStudyBasic-unsigned.ipa` |

Cả hai dùng bundle ID `com.cunz.mamstudy`, do đó cài thay nhau, không cài song song. Xuất bản sao lưu trước khi đổi cách ký hoặc gỡ app. Bản Basic không hiện thao tác kết nối widget.

## Yêu cầu và giới hạn thực tế

- iOS 17+ để chạy app; **iOS 26+ cho báo thức AlarmKit**. Cần cấp quyền Báo thức trong Cài đặt của Mầm và kiểm tra trên máy thật. Máy khóa màn hình khác với máy tắt nguồn/hết pin.
- Thông báo thường chịu ảnh hưởng của chế độ im lặng, Tập trung và quyền âm thanh. Không có cơ chế tự đổi thông báo thường thành báo thức thật.
- Widget nhận snapshot sau mỗi lần lưu và yêu cầu iOS cập nhật. Thời điểm hiển thị lại do WidgetKit quyết định; không cam kết đồng bộ tức thì từng giây. Thống kê widget phản ánh lần app cập nhật gần nhất.
- Focus lưu mốc thời gian, nên không cần chạy mã liên tục ở nền. Thời gian nghỉ không tính, phiên không vượt quá thời lượng đặt. Đây là thời gian hẹn giờ, không chứng minh mức độ tập trung hoặc hiểu bài. Chưa có chặn ứng dụng khác.
- Ôn thẻ dùng bộ lập lịch lấy cảm hứng từ SM-2 với bước học ngắn; **không phải FSRS của Anki**, không có đồng bộ Anki hoặc dự đoán cá nhân hóa xác suất nhớ.
- Dữ liệu lưu cục bộ. Bạn có thể xuất file vào iCloud Drive bằng ứng dụng Tệp; chưa có đồng bộ iCloud tự động giữa thiết bị.
- Không dùng mạng trong mã ứng dụng. Giọng đọc tùy thuộc các giọng đã có trên iPhone; hệ thống có thể cần tải giọng nếu chưa cài.

## Build trên Mac

Cần Xcode 26.x ổn định và XcodeGen:

```bash
brew install xcodegen
bash scripts/build-ios.sh MamStudy
```

Đầu ra ở `build/MamStudy/MamStudy-unsigned.ipa`. Script chạy kiểm thử lõi, kiểm tra tài nguyên, sinh project, build thiết bị thật, kiểm tra executable Mach-O và widget, rồi mới đóng gói. Mọi lỗi build dừng quy trình. Bản cũ được loại khỏi thư mục đầu ra trước lần build mới để không nhầm với kết quả thành công.

Muốn mở và chạy trong Xcode:

```bash
xcodegen generate --spec project.yml
open MamStudy.xcodeproj
```

Gói ZIP cũng kèm `.xcodeproj` đã sinh bằng XcodeGen 2.46.0 để bạn mở trực tiếp. Khi chỉnh `project.yml`, sinh lại project bằng lệnh trên. Workflow luôn sinh lại để tránh dùng cấu hình cũ.

Chọn scheme phù hợp; chạy Simulator trước. Chạy máy thật cần cấu hình Signing như tài liệu riêng.

## Cấu trúc mã

- `Core/`: mô hình, lịch, thống kê, ôn thẻ, lưu và kiểm tra dữ liệu. Không phụ thuộc SwiftUI.
- `App/`: giao diện SwiftUI, điều phối lưu dữ liệu và AlarmKit/UserNotifications.
- `Shared/`: snapshot dùng chung với widget qua App Groups.
- `Widget/`: WidgetKit provider và giao diện hai widget.
- `Tests/`: kiểm thử Swift chạy bằng Swift Package Manager trên Linux/macOS.
- `Config/`, `Resources/`: Info.plist, entitlement, privacy manifest và icon.
- `scripts/`: tạo icon, kiểm tra tài nguyên, chọn Xcode và build IPA.
- `project.yml`: cấu hình XcodeGen; project Xcode được tạo khi build.
- `.github/workflows/build-ios.yml`: hai job build độc lập và artifact log.

Chạy kiểm thử lõi:

```bash
swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
python3 scripts/validate_project.py
```

Kiểm thử lõi **không thay thế** việc biên dịch SwiftUI/AlarmKit/WidgetKit bằng iOS SDK hoặc kiểm thử trên iPhone.

## Tài liệu nền tảng

- [Apple: Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [Apple: Meet AlarmKit](https://developer.apple.com/videos/play/wwdc2025/230/)
- [Apple: cập nhật widget](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
- [Apple: cấu hình App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [XcodeGen: ProjectSpec](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md)
- [GitHub: phần mềm có trên runner macOS 15](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)
- [Anki: cách ôn và tự đánh giá](https://docs.ankiweb.net/studying.html)
