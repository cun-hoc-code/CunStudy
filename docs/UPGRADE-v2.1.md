# Nâng cấp Mầm 2.1

## Trước khi build

1. Trong Mầm bản cũ, vào Cài đặt → Sao lưu và xuất một file `.mamstudy`.
2. Giữ nguyên bundle ID `com.cunz.mamstudy` nếu muốn cài đè và giữ dữ liệu.
3. Không thêm IPA, certificate, provisioning profile hoặc mật khẩu vào Git.

Dữ liệu 2.0/1.1 không có cài đặt phòng đọc và phản hồi âm thanh vẫn được đọc với giá trị mặc định. Backup mới giữ file sách/PDF gốc.

## Đẩy source lên repository hiện có

Giải nén sao cho `project.yml`, `App/`, `Core/` và `.github/` nằm ngay ở gốc repository. Sau đó:

```bash
git status
git add .
git commit -m "Upgrade MamStudy to 2.1"
git pull --rebase origin main
git push -u origin main
```

Nếu `git pull --rebase` báo conflict, không dùng `--force`. Sửa từng file conflict, chạy `git add <file>`, `git rebase --continue`, rồi push lại.

## Build IPA bằng GitHub Actions

Mở tab **Actions** → **Build MamStudy IPA** → **Run workflow**. Workflow tạo ba artifact:

- `MamStudy-unsigned-ipa`: app + widget + Live Activity.
- `MamStudyBasic-unsigned-ipa`: app không widget, dễ ký nhất.
- `MamStudyManaged-unsigned-ipa`: thêm Screen Time; cần entitlement được Apple duyệt.

Nếu job fail, tải artifact `*-build-logs` và xem `xcodebuild.log`. Chỉ dùng IPA khi job build đã xanh; file source ZIP không phải IPA.

## Ký bằng LC Sign

Với chứng thư cá nhân không có App Groups, hãy bắt đầu bằng `MamStudyBasic-unsigned.ipa`. Bản widget phải ký cả app và extension bằng cùng Team, App Group và provisioning profile phù hợp. Hướng dẫn chi tiết nằm trong `docs/SIGNING.md`.

## Sau khi cài

Chạy toàn bộ `docs/DEVICE-QA-v2.1.md` trước khi coi bản 2.1 là bản phát hành. Đặc biệt thử file trong iCloud chưa tải, PDF scan, xoay máy khi đọc và chạm tab liên tiếp.
