# Ký IPA và widget

IPA do workflow tạo là bản **chưa ký** cho thiết bị iOS thật, không phải app Simulator. iPhone thông thường yêu cầu chữ ký/profile phù hợp để cài. Project không chứa private key, certificate, tài khoản hoặc mật khẩu của bạn.

## Bản đầy đủ

Giá trị mặc định:

| Thành phần | Identifier |
| --- | --- |
| App chính | `com.cunz.mamstudy` |
| Widget extension | `com.cunz.mamstudy.widgets` |
| App Group dùng chung | `group.com.cunz.mamstudy` |

App và widget phải được ký hợp lệ cùng team; profile tương ứng phải cho phép App Group dùng chung. Công cụ ký cần giữ extension, ký cả executable của widget và giữ entitlement phù hợp. Có certificate không tự động có nghĩa là mọi App Group đều được phép.

Nếu cần đổi identifier, chỉnh `project.yml` trước khi build:

- Hai dòng `PRODUCT_BUNDLE_IDENTIFIER` cho app và widget.
- `STUDY_APP_GROUP` thành group mà profile cho phép.
- `bundleIdPrefix` có thể chỉnh cho nhất quán, nhưng hai identifier cụ thể phía trên mới quyết định sản phẩm.

Info.plist và entitlement lấy group từ cùng biến build, tránh chỉnh lệch từng nơi. Giữ bundle của widget có tiền tố bundle app, ví dụ `vn.tenban.mam.widgets` đi cùng `vn.tenban.mam`.

Khi dùng Xcode, chọn team và cấu hình Signing & Capabilities cho cả `MamStudy` và `MamStudyWidgets`. Chọn đúng App Group trên cả hai target rồi build máy thật. Khi dùng công cụ ký ngoài Xcode, kiểm tra khả năng hỗ trợ extension/App Groups của chính công cụ và profile đó.

## Bản Basic

`MamStudyBasic` không nhúng widget/Live Activity và không yêu cầu App Groups. Lịch học, todo, Focus, thống kê, ghi chú, flashcard và AlarmKit vẫn có trong app. Đây là lựa chọn nếu profile/công cụ ký của bạn không hỗ trợ widget.

Bản Basic và bản đầy đủ có cùng bundle ID; đổi bản có thể thay thế app. Dữ liệu có được giữ hay không còn phụ thuộc cách cài, cùng chữ ký/team và có gỡ app hay không. Hãy xuất JSON trước khi thay bản.

## Báo thức

App tối thiểu iOS 17, nhưng AlarmKit chỉ gọi trong nhánh iOS 26+. Cần cấp quyền **Báo thức** riêng; quyền **Thông báo** không thay thế quyền này. Project dùng báo thức theo lịch, không dùng countdown/snooze của AlarmKit và có Live Activity riêng cho phiên Focus ở bản 1.1 đầy đủ.

Apple thiết kế AlarmKit để phát báo thức qua chế độ im lặng/Tập trung. Khả năng thực tế của bản ký cần kiểm tra trên iPhone bằng nút thử 30 giây; thử cả khi khóa màn hình và khi app không mở. Thiết bị hết pin/tắt nguồn không thể chạy báo thức từ app.

Nguồn: [Apple — Meet AlarmKit](https://developer.apple.com/videos/play/wwdc2025/230/), [Apple — App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups).

## Live Activity của phiên tập trung

Bản `MamStudy` nhúng `FocusLiveActivity` trong `MamStudyWidgets.appex`; Info.plist app có `NSSupportsLiveActivities = YES`. Không dùng remote push. Giữ extension khi ký lại; bật Hoạt động trực tiếp trong cài đặt iPhone nếu bị tắt. Đồng hồ dùng ActivityKit, không lấy dữ liệu đếm giây từ snapshot App Group. Chi tiết vòng đời khi ở nền trong [UPGRADE-v1.1.md](UPGRADE-v1.1.md).
