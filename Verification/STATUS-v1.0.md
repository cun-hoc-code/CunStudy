# Kết quả kiểm tra — 17/09/2026

**Mã nguồn đã được rà soát và các kiểm tra khả dụng đã đạt. Chưa có kết quả build iOS bằng Xcode, chưa có IPA và chưa thử trên iPhone.**

## Đã thực hiện

| Kiểm tra | Kết quả | Bằng chứng |
| --- | --- | --- |
| Biên dịch lõi bằng Swift 6.1.2 trên Linux | Đạt | `checks.log` |
| XCTest | **23/23 đạt**, không thất bại | `checks.log` |
| Warnings-as-errors + strict concurrency complete cho lõi | Đạt, không cảnh báo | `checks.log` |
| Phân tích cú pháp toàn bộ Swift trong App/Core/Shared/Widget | Đạt | `checks.log`; không phải type-check bằng iOS SDK |
| Info.plist, entitlement, privacy manifest, App Groups | Đạt kiểm tra cấu trúc | `checks.log` |
| Kích thước, PNG và RGB không alpha của icon | Đạt | `checks.log` |
| Shell syntax | Đạt | `checks.log` |
| Workflow GitHub Actions bằng actionlint 1.7.12 | Đạt | `checks.log` |
| Sinh project Xcode bằng XcodeGen 2.46.0 | Đạt | `xcodegen.log`, `MamStudy.xcodeproj/` |
| Tên sản phẩm và scheme Full/Basic sau khi sinh project | Đạt | `xcodegen.log` |

CoreTests bao gồm lịch lặp/qua nửa đêm/đổi DST, báo trước sang ngày cũ, không trùng khi chạm mép giờ, focus khi đóng app/tạm dừng/qua nửa đêm, lịch ôn/quên/giới hạn thẻ mới, điền khuyết nhiều dòng, TSV lỗi nguyên khối, BOM/cột thừa, hoàn tác không ghi đè chỉnh sửa, lưu file/bản trước, độ chính xác thời gian, đọc backup cũ và khôi phục timer an toàn.

Các kiểm tra XcodeGen và cấu trúc giúp phát hiện cấu hình sai, nhưng **không kiểm tra được toàn bộ kiểu/API SwiftUI, AlarmKit hoặc WidgetKit**. Chỉ Xcode với iOS SDK mới xác nhận được bước đó.

## Chưa thể thực hiện ở đây

Đã chạy `bash scripts/build-ios.sh`; script dừng đúng ở điều kiện thiếu `xcodebuild` với exit status 2. Môi trường hiện tại là Ubuntu Linux, không có Xcode/iOS SDK, không có phiên GitHub đã đăng nhập để chạy workflow trên tài khoản của bạn. Xem `ios-build-attempt.log`.

Vì vậy các mục sau còn chờ:

- Compile/link app và widget bằng iOS SDK.
- Đóng gói executable thiết bị thật thành IPA.
- Ký, cài đặt và chạy trên Simulator/iPhone.
- Báo thức khi khóa máy/app đóng, quyền hệ thống và cập nhật widget trên bản ký thực tế.
- Kiểm tra bố cục màn hình nhỏ/chữ lớn và khả năng sử dụng trên thiết bị.

Chạy workflow **Build MamStudy IPA** sau khi đưa project lên GitHub theo `HUONG-DAN.md`, hoặc chạy `bash scripts/build-ios.sh MamStudy` trên Mac có Xcode 26+. Checklist máy thật nằm trong `docs/DEVICE-QA.md`.

## Bảo toàn công việc trước đó

`before-resume.tar.gz` là bản chụp source ngay trước đợt tiếp tục này, không chứa build cache. SHA-256:

```text
b1a2d7dcb9674b65f6e5356033e333c8e793d60ebbf6e9e45e43ed45ae0c621d
```

`resume-diff.patch` đối chiếu các file cũ đã thay đổi. `resume-files.txt` liệt kê file giữ nguyên, chỉnh sửa và thêm. Đây là so sánh từ archive, không phải lịch sử Git vì thư mục ban đầu chưa có Git. Giao diện bút chì và các màn hình lịch/ghi chú đã có được giữ lại; không chỉnh các thư mục StudyFlow cũ.

## Chạy lại kiểm tra

Trên máy có Swift và Python 3:

```bash
bash scripts/check.sh
```

Nếu có `actionlint` trong PATH, script kiểm tra workflow; nếu không, script ghi rõ bước đó bị bỏ qua. Log mới ở `build/checks/checks.log`. Muốn kiểm tra iOS phải chạy build riêng trên macOS, không suy ra từ dấu xanh của kiểm thử lõi.
