# Tạo IPA của Mầm trên Arch / Windows

**Đã có IPA 1.0?** Đọc [Cập nhật lên Mầm 1.1](docs/UPGRADE-v1.1.md): cập nhật repo hiện tại, build job `MamStudy` để có Live Activity. Các bước tạo repo dưới đây dành cho lần đầu.

File ZIP bạn tải là **mã nguồn**, nên nhỏ hơn app đã biên dịch. Chưa thể cài ZIP này lên iPhone. Đổi tên ZIP thành IPA cũng không tạo ra app.

Quy trình: giải nén → đưa source lên GitHub → GitHub Actions build bằng Mac → tải IPA → ký bằng chứng chỉ/profile phù hợp → cài lên iPhone.

## 1. Giải nén vào một thư mục mới

Giữ nguyên project StudyFlow cũ. Giải nén gói mới, mở thư mục **MamStudy**. Ngay trong thư mục này phải có `project.yml`, `Package.swift`, các thư mục `App`, `Core`, `Widget` và workflow.

Trên Arch, nếu giải nén vào Downloads:

```bash
cd ~/Downloads/MamStudy
pwd
ls
```

Nếu đường dẫn của bạn khác, mở thư mục bằng trình quản lý file rồi chọn mở Terminal tại đó. Các lệnh tiếp theo chạy trong thư mục chứa `project.yml`.

## 2. Đăng nhập GitHub CLI

Bạn đã có `git` và `gh` trên Arch. Kiểm tra:

```bash
git --version
gh --version
gh auth status
```

Nếu chưa đăng nhập:

```bash
gh auth login
```

Chọn GitHub.com → HTTPS → đăng nhập bằng trình duyệt. Thực hiện bước xác thực trên GitHub, sau đó:

```bash
gh auth setup-git
gh api user --jq .login
```

Tài khoản mong đợi theo repo bạn đã dùng là `cun-hoc-code`. Nếu kết quả khác, dùng tên tài khoản thực tế trong lệnh tạo repo, hoặc đăng nhập lại đúng tài khoản. Không dán token vào mã nguồn hay gửi token qua chat.

## 3. Tạo repository cho project mới

Chỉ chạy khối sau trong thư mục Mầm mới, chưa có Git:

```bash
git init -b main
git add .
git status --short
git commit -m "Create MamStudy student planner"
gh repo create cun-hoc-code/MamStudy --private --source=. --remote=origin --push
```

Lệnh `gh repo create` tạo repo trên GitHub trước khi push, tránh lỗi `Repository not found` của lần trước. `git add .` lấy cả workflow; không chỉ chọn các file nhìn thấy để upload thủ công.

Nếu `git commit` báo chưa cấu hình tên/email, đặt **trong repo này**, thay giá trị ví dụ bằng tên và email/noreply email GitHub của bạn:

```bash
git config user.name "Ten GitHub cua ban"
git config user.email "email-tren-github-cua-ban"
git commit -m "Create MamStudy student planner"
```

Sau đó chạy lại `gh repo create ...` nếu chưa chạy thành công. Không ghi nguyên email ví dụ vào commit.

Nếu GitHub báo repo `MamStudy` đã tồn tại, không chạy lệnh xóa hay force push. Kiểm tra repo đó trước:

```bash
gh repo view cun-hoc-code/MamStudy --web
git remote -v
```

Nếu repo tồn tại đúng là project Mầm của bạn, hãy clone nó sang thư mục mới rồi cập nhật các file từ gói này, giữ lịch sử Git. Các file nguồn tốt đã có không cần xóa. Nếu đó là repo khác, chọn một tên mới, ví dụ `MamStudy-iOS`, rồi dùng tên đó nhất quán trong các bước sau.

## 4. Chạy build

Push lên `main` sẽ tự kích hoạt workflow. Mở repo → **Actions → Build MamStudy IPA**. Nếu chưa có lượt chạy, bấm **Run workflow → main → Run workflow**.

Workflow có hai job độc lập:

| Job | Sử dụng |
| --- | --- |
| `MamStudy` | Bản đầy đủ có widget. Chọn khi cách ký của bạn giữ được extension và App Groups. |
| `MamStudyBasic` | Bản không có widget; phù hợp để thử toàn bộ chức năng bên trong app trước. |

Workflow chọn Xcode 26.x từ runner, kiểm thử lõi, sinh project và build iOS. Không cần đưa certificate vào repo để tạo IPA chưa ký. Repo private cần còn hạn mức Actions phù hợp trong tài khoản GitHub; nếu job không được cấp runner, xem thông báo trong trang Actions/Billing của tài khoản.

Không cần cài Xcode trên Arch hoặc Windows.

## 5. Tải IPA sau khi build xanh

1. Bấm vào lượt chạy có dấu tích xanh.
2. Ở trang tổng quan lượt chạy, kéo xuống **Artifacts**.
3. Tải `MamStudy-unsigned-ipa` hoặc `MamStudyBasic-unsigned-ipa`.
4. Giải nén artifact: bên trong là file `.ipa` và `SHA256SUMS.txt`.
5. Đọc [docs/SIGNING.md](docs/SIGNING.md) trước khi ký, đặc biệt nếu dùng widget.

Nếu dùng terminal để tải, hãy chỉ định đúng ID lượt chạy:

```bash
gh run list --repo cun-hoc-code/MamStudy --workflow build-ios.yml --limit 5
```

Lấy số ở cột ID, thay `123456789` trong lệnh sau:

```bash
gh run download 123456789 --repo cun-hoc-code/MamStudy --name MamStudy-unsigned-ipa --dir ipa-download
```

Không có IPA khi bước compile thất bại. Artifact `*-build-logs` là log, không phải app.

## 6. Nếu build đỏ

Không chỉ chụp dòng `exit code 65`: nó là kết quả thất bại chung, không phải nguyên nhân.

Mở job bị đỏ → bước **Test core and build device app**. Đọc dòng lỗi đầu tiên có `error:` và vài dòng xung quanh, hoặc tải artifact `MamStudy-build-logs`/`MamStudyBasic-build-logs`. Gói log chứa cả kiểm thử, XcodeGen, phiên bản toolchain và xcodebuild nếu đã đến bước đó.

Lấy log bằng CLI mà không gặp lỗi thiếu Run ID:

```bash
mam_run_id=$(gh run list --repo cun-hoc-code/MamStudy --workflow build-ios.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$mam_run_id" --repo cun-hoc-code/MamStudy --log-failed
```

Chỉ chạy khi danh sách đã có lượt build. Gửi file log hoặc link lượt chạy cùng đoạn `error:` để xác định lỗi cụ thể. Không cần gửi certificate, profile chứa thông tin thiết bị hoặc mật khẩu ký.

## 7. Mở app lần đầu

1. Đặt tên gọi và mục tiêu học vừa sức.
2. Tạo một lịch tự học/đi học thử; nhập đúng giờ bắt đầu và số phút chuẩn bị + di chuyển.
3. Vào **Hôm nay → bánh răng → Nhắc đi học**, cấp quyền theo chế độ bạn cần.
4. Nếu iOS 26+, chọn **Thử báo thức sau 30 giây**, khóa màn hình và kiểm tra trên máy thật.
5. Tạo một phiên tập trung ngắn, thử tạm dừng/tiếp tục và xem thống kê.
6. Nếu ký bản đầy đủ, thêm widget Mầm rồi sửa lịch trong app để kiểm tra cập nhật.
7. Xuất một bản sao lưu JSON ra ứng dụng Tệp sau khi nhập lịch chính.

Lịch, flashcard và ghi chú mẫu chỉ xuất hiện khi bạn chủ động bấm **Thử dữ liệu mẫu** trong Cài đặt. Không có báo thức mẫu tự bật.
