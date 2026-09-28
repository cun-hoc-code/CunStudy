# Xác minh Mầm 1.1 — 17/09/2026

**Đã hoàn thành mã nguồn nâng cấp. 33/33 kiểm thử lõi đạt. Chưa build IPA 1.1 bằng Xcode và chưa chạy iPhone/Simulator trong phiên này.**

## IPA 1.0 do bạn gửi

`MamStudy-unsigned.ipa` có ZIP hợp lệ, executable ARM64 cho app và widget, platform iOS device, SDK build 26.2.0, minimum iOS 17.0. Phiên bản 1.0.0. Không có thư mục chữ ký/provisioning; app chưa có `NSSupportsLiveActivities`. Kết quả chi tiết và SHA-256 ở `ipa-inspection.json`.

Đây là kiểm tra cấu trúc và metadata. Không chứng minh app khởi chạy, mọi tính năng hoạt động hoặc bản ký lại có quyền đúng. Không có source-map/commit marker trong IPA để khẳng định nó khớp từng dòng với ZIP nguồn trước đó.

## Mã nguồn 1.1

Bản nâng cấp dựa trên `MamStudy-source.zip` đã lưu trước đó và giữ các phần lịch/todo/ghi chú/AlarmKit/ôn giãn cách. Có Live Activity, streak, thống kê, lịch sử ôn, XP/cấp độ/huy hiệu, dark mode và haptic/animation. Xem `../docs/UPGRADE-v1.1.md` để biết hành vi và giới hạn thực tế.

| Kiểm tra | Kết quả | Bằng chứng |
| --- | --- | --- |
| Core: biên dịch Swift 6.1.2, warnings-as-errors, strict concurrency complete | Đạt | `checks-v1.1.log` |
| 23 kiểm thử cũ | 23/23 đạt | `checks-v1.1.log` |
| 10 kiểm thử tiến độ/migration mới | 10/10 đạt | `checks-v1.1.log` |
| Phân tích cú pháp tất cả Swift App/Core/Shared/Widget | Đạt, chỉ parse, không kiểm tra kiểu iOS SDK | `checks-v1.1.log` |
| Plist, privacy manifest, icon, Live Activity, không ép Light | Đạt kiểm tra cấu trúc | `checks-v1.1.log` |
| Sinh Xcode project bằng XcodeGen 2.46.0 | Đạt | `xcodegen-v1.1.log` |
| Membership mọi file Swift cho Full/Basic/Widget | Đạt | `checks-v1.1.log` |
| Version nguồn/project | 1.1.0, build 2 | `project.yml`, `project.pbxproj` |
| Shell syntax của build/check | Đạt | Kiểm tra `bash -n` |
| GitHub Actions actionlint ở môi trường hiện tại | Không chạy vì không cài actionlint; workflow giữ nguyên | `checks-v1.1.log` |
| Build iOS/IPA 1.1 | Chưa thực hiện được: không có Xcode trên Linux | `ios-build-v1.1-attempt.log` |
| UI, Live Activity, Dynamic Island, haptic trên thiết bị | Chưa chạy | `../docs/DEVICE-QA.md` |

Kiểm thử mới bao gồm: chuỗi giữ đến hết ngày; ngày bỏ học; đủ 5 thẻ khác nhau; chống nhân XP từ một thẻ; chia phút qua nửa đêm; ngày 23 giờ; không tính dữ liệu tương lai/đồng hồ chưa lưu; giới hạn XP và hoàn tác; heatmap trống; đọc JSON 1.0; snapshot log không phụ thuộc thẻ còn tồn tại; round-trip và giới hạn tùy chọn mới.

Log/bản chụp kiểm tra cũ vẫn giữ trong `Verification/`; `STATUS-v1.0.md` là báo cáo lịch sử trước khi bạn tạo IPA 1.0. Chỉ `STATUS.md` này mô tả lượt nâng cấp hiện tại.

## Bước nghiệm thu tiếp theo

Cập nhật repo hiện tại bằng đầy đủ gói source, chạy workflow job **MamStudy**, tải IPA của commit mới, ký cả app và extension. Bản **MamStudyBasic không có Live Activity**. Chạy checklist máy thật trước khi dùng làm lịch nhắc học chính.
