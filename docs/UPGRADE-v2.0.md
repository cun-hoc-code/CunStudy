# Mầm 2.0 — hướng dẫn cập nhật

Đây là toàn bộ mã nguồn bản nâng cấp, chưa phải IPA đã build và ký. Dự án dựa trên MamStudy v1.1 của `cun-hoc-code/MamStudy`, commit `1da91bf96db9f121b2b993e72f0d4a33d297ec94`.

## Bắt đầu sử dụng

Mở **Hôm nay → Góc học tập** hoặc **Sổ tay → Không gian học** để đến lịch nâng cao, tài liệu, luyện đề, điểm số, nhật ký, mục tiêu, ví và kết nối. Năm tab quen thuộc vẫn giữ nguyên.

- **Lịch & khung học:** đổi ngày/tuần/tháng; tạo môn học, kỳ thi, học phí hoặc deadline; chọn khoảng trống được gợi ý để tạo phiên tự học. Khoảng trống dựa trên dữ liệu bạn đã nhập, không suy đoán lịch chưa có.
- **Sổ tay:** Markdown cơ bản, checklist, môn/thư mục/tag, `[[Tên ghi chú]]`, file, ghi âm và viết tay. Ghi âm dừng khi app vào nền. Lưu bản thu và ghi chú trong cùng lần ghi dữ liệu; nếu lưu lỗi, có nút thử lại.
- **Thư viện:** PDF, file trình chiếu/ebook qua Quick Look nếu iOS hỗ trợ, ảnh bảng, audio, trang viết tay và link. Camera scan thành PDF kèm OCR để tìm kiếm. Link có phần trích bạn tự dán để đọc offline.
- **PDF:** chọn chữ → highlight/gạch chân; thêm bình luận, bookmark, hoàn tác chú thích vừa tạo và lưu. Mỗi lần lưu tạo tệp mới để bản sao lưu trước còn khôi phục được. PDF scan chưa có lớp chữ không thể chọn chữ để highlight.
- **Flashcard:** SRS, cloze, ôn nhanh 10 thẻ, thẻ khó, CSV và APKG. Tạo thẻ từ dòng `Thuật ngữ: định nghĩa` hoặc `{{chỗ trống}}`; luôn xem lại trước khi lưu. Đây là bộ tách quy tắc offline, không phải AI hiểu tài liệu.
- **Luyện đề:** tạo câu hỏi hoặc chuyển từ flashcard, thi thử có hạn giờ, chấm đáp án, giải thích do bạn nhập, sổ lỗi sai và tỉ lệ đúng từng chương. Kết quả giữ bản chụp câu hỏi lúc thi, không đổi theo lần sửa câu hỏi sau đó.
- **Học vụ:** điểm thành phần hệ 10, dự báo điểm trung bình còn thiếu, CPA/GPA theo điểm hệ 4 bạn nhập, mô phỏng, tín chỉ và môn học lại. Tự nhập quy tắc qua môn của trường; app không tự quyết định quy chế FBU.
- **Ví:** khoản chi, ngân sách tháng, biểu đồ nhóm chi và chia đều hóa đơn bằng số nguyên VND. Phần lẻ được chia theo thứ tự thành viên; khoản chung theo dõi riêng để tránh cộng trùng vào chi tiêu.
- **Mục tiêu/nhật ký:** mục tiêu phút, thẻ khác nhau, việc hoàn thành được tính tự động; số chương do bạn đánh dấu. Nhật ký không cộng thêm XP vì có thể trùng phiên đã ghi.
- **Tập trung:** mầm chuyển động, hiệu ứng lá khi hoàn thành, âm thanh mưa/cafe/white noise tạo bằng thuật toán, haptic, Live Activity, streak/XP/huy hiệu/heatmap có từ v1.1.

## Đưa lên GitHub từ Arch

1. Trong app cũ, xuất bản sao lưu trước khi thay bản cài. Đừng gỡ app trước khi đã giữ được file sao lưu.
2. Giải nén ZIP vào một thư mục riêng:

```bash
mkdir -p ~/Downloads/mam-v2
unzip ~/Downloads/MamStudy-source.zip -d ~/Downloads/mam-v2
```

3. Mở thư mục repo đang dùng, xem `git status`. Nếu còn sửa đổi cá nhân, commit hoặc lưu chúng trước khi chép bản cập nhật. Tạo nhánh mới:

```bash
cd /duong-dan/toi/MamStudy
git status
git switch -c upgrade/mam-v2
```

Thay `/duong-dan/toi/MamStudy` bằng đường dẫn repo thực tế. ZIP không chứa thư mục `.git` nên không thay lịch sử/remote của bạn.

4. Xem trước những file sắp chép, rồi chép:

```bash
rsync -avnc --exclude='.git/' ~/Downloads/mam-v2/MamStudy/ ./
rsync -av --exclude='.git/' ~/Downloads/mam-v2/MamStudy/ ./
git diff --stat
git status
```

Các file cùng tên sẽ được thay bởi bản nâng cấp. Nếu bạn đã sửa app sau commit gốc ở trên, đọc `git diff` và giữ lại những thay đổi riêng cần thiết. Không dùng `--delete` hay force push.

5. Commit/push nhánh:

```bash
git add App Core Storage Shared Widget FocusMonitor Resources Config System Tests scripts docs Verification project.yml Package.swift Package.resolved MamStudy.xcodeproj README.md CHANGELOG.md .github
git commit -m "Add MamStudy 2.0 study workspace"
git push -u origin upgrade/mam-v2
gh pr create --base main --head upgrade/mam-v2 --title "MamStudy 2.0" --body "Add study workspace, notes, documents, practice, grades, budget and motion. See docs/UPGRADE-v2.0.md and Verification/STATUS.md."
```

Workflow chạy trên pull request hướng tới main. Xem tab **Actions → Build MamStudy IPA**. Mở PR sau khi `gh auth login` nếu chưa đăng nhập. Không nhập token hoặc chứng chỉ vào mã nguồn.

6. Khi ba job build đạt, tải artifact phù hợp và ký IPA bằng LC Sign. Build log được giữ kể cả khi thất bại; nếu đỏ, lấy file log thay vì thử ký IPA cũ.

## Chọn bản ký

| Scheme | Có gì | Quyền cần trong provisioning profile |
| --- | --- | --- |
| MamStudyBasic | Các chức năng học tập, ghi chú, OCR, audio, Face ID, backup | Không yêu cầu App Groups hoặc Family Controls; không có widget/Live Activity extension |
| MamStudy | Như Basic + widget lịch/deadline/nhịp học và Live Activity | App Groups khớp giữa app và widget; giữ widget extension khi ký |
| MamStudyManaged | Như bản đầy đủ + chọn app để che bằng Screen Time | App Groups + Family Controls cho app và monitor extension; cần Apple cấp quyền phù hợp |

**LC Sign chỉ ký theo quyền chứng chỉ/profile có sẵn, không tạo thêm quyền App Groups hay Family Controls.** Nếu bản ký không hỗ trợ, dùng Basic hoặc Full với đúng quyền; không sửa thông báo trạng thái thành thành công giả. App Group mặc định là `group.com.cunz.mamstudy`; khi đổi bundle ID/team, đổi nhóm đồng bộ giữa app, widget và cấu hình ký.

Screen Time có lựa chọn app rõ ràng, nút mở chặn ngay và monitor tự gỡ khi hết khoảng học. Chọn phiên ít nhất 16 phút để có đủ thời gian lập lịch tối thiểu. Không tự bật Không làm phiền. Cần kiểm tra cơ chế gỡ chặn trên máy thật trước khi dùng cho buổi học quan trọng.

## Sao lưu và chuyển iPad

**Kết nối & bảo mật → Xuất dữ liệu kèm tất cả tệp** tạo `.mamstudy`. Chọn Lưu vào Tệp → iCloud Drive. Trên máy khác, tải file rồi nhập. Đây là chuyển/sao lưu thủ công, chưa phải đồng bộ iCloud tự động. JSON cũ vẫn đọc được nhưng không chứa bytes của PDF/ảnh/audio.

Khôi phục hiển thị số lượng bản ghi và yêu cầu xác nhận; dữ liệu hiện tại được giữ thành bản trước lần nhập. Tệp đính kèm được khôi phục dưới tên mới, không ghi đè tệp đang dùng. Khóa app được tắt sau nhập để bạn bật lại trên máy mới. File backup không mã hóa bằng mật khẩu; Face ID là khóa truy cập trong app, không mã hóa file bạn xuất.

## Giới hạn cần biết

Xem `docs/FEATURE-MATRIX-v2.0.md`. Chưa có backend cộng đồng, CloudKit đồng bộ tự động, Google OAuth riêng hoặc app Apple Watch. Tiếng Anh có 305 nhãn điều hướng/điều khiển; một số thông báo, câu có số động và widget vẫn tiếng Việt. Các tích hợp Apple cần quyền bạn cấp; OCR phụ thuộc chất lượng ảnh và ngôn ngữ mà phiên bản iOS hỗ trợ.

Dữ liệu JSON tối đa 25 MB, file đơn tối đa 50 MB, tổng attachment trong backup tối đa 256 MB; bộ thẻ tối đa 30.000 thẻ. APKG hỗ trợ database legacy `.anki2/.anki21`, không `.anki21b`, media, scheduling, template tùy biến hay FSRS. Xuất Anki với **Support older Anki versions** để nhập; APKG Mầm xuất chuyển cloze thành Q&A thường, CSV giữ nguyên kiểu cloze.

## Build trên Mac

Xcode 26+ và XcodeGen:

```bash
brew install xcodegen
bash scripts/build-ios.sh MamStudy
# Hoặc MamStudyBasic / MamStudyManaged
```

Không thể dùng Swift Linux để build SwiftUI/iOS IPA. Kiểm thử core trên Linux không thay thế build Xcode hoặc thử máy thật.
