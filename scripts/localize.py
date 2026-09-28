#!/usr/bin/env python3
"""Maintain human-authored translations for navigation and main editing controls."""
from pathlib import Path
import json
pairs='''Hôm nay|Today
Kế hoạch|Planner
Tập trung|Focus
Ôn thẻ|Cards
Sổ tay|Notes
Cài đặt|Settings
Lưu|Save
Hủy|Cancel
Xóa|Delete
Xong|Done
Đóng|Close
Nhập|Import
Đã hiểu|Got it
Tất cả|All
Ngày|Day
Tuần|Week
Tháng|Month
Trước|Previous
Sau|Next
Môn học|Subject
Tiêu đề|Title
Nội dung|Content
Thư mục|Folder
Tag, cách nhau bởi dấu phẩy|Tags, separated by commas
Mục|Category
Ghim lên đầu|Pin to top
Xem Markdown|Preview Markdown
Nội dung ghi chú|Note content
Phân loại|Organize
Hoàn thành|Completed
Việc cần làm|Task
Thêm mục|Add item
Bản thu bài giảng|Lecture recording
Ghi âm cùng lúc với ghi chú|Record while taking notes
Bắt đầu ghi âm|Start recording
Đang mở micro…|Opening microphone…
Dừng và đính kèm|Stop and attach
Thử lưu lại bản thu|Retry saving recording
Tệp đính kèm|Attachments
Thêm tài liệu|Add document
Từ thư viện|From library
Nhập file|Import file
Scan + OCR|Scan + OCR
Viết tay|Handwriting
Đang xử lý…|Processing…
Ghi chú liên kết / backlinks|Linked notes / backlinks
Tạo bản nháp flashcard|Draft flashcards
Xóa ghi chú|Delete note
Xóa ghi chú?|Delete this note?
Chọn tài liệu|Select document
Trang viết tay|Handwriting page
Hoàn tác|Undo
Ghi nhanh|Quick note
Lọc|Filter
Không gian học|Study studio
Tài liệu|Documents
Tìm ghi chú, tag, OCR…|Search notes, tags, OCR…
Nghĩ đến đâu, ghi đến đó|Make room for your thoughts
Danh sách|List
Lưới|Grid
Thẻ|Cards
Kiểu xem|Layout
Đang xử lý tài liệu…|Processing document…
Nhập PDF / file|Import PDF / file
Ảnh bảng / slide|Board / slide photo
Scan tài liệu|Scan document
Lưu đường dẫn|Save link
Lưu bài viết|Save article
Nội dung lưu offline|Offline excerpt
Mở đường dẫn|Open link
Mở tài liệu / phát bản thu|Open document / play recording
Nhận dạng chữ (OCR)|Recognize text (OCR)
Đang nhận dạng chữ…|Recognizing text…
Thông tin tài liệu|Document information
Chia sẻ file|Share file
Học phần / học kỳ|Module / semester
Văn bản tìm kiếm|Searchable text
Thư viện của bạn|Your library
Tìm cả nội dung OCR…|Search including OCR text…
Xóa tài liệu khỏi thư viện và các ghi chú?|Remove document from library and notes?
Đã đánh dấu|Bookmarks
Chọn chữ trước khi highlight / gạch chân. Lưu để giữ các chú thích.|Select text to highlight or underline. Save to keep annotations.
Xem lịch|Calendar view
Thời lượng|Duration
Tìm một khoảng yên|Find a quiet moment
Đếm ngược & deadline|Countdowns & deadlines
Khung tự học|Study block
Lịch học|Timetable
Kỳ thi / deadline|Exam / deadline
Tên khung học|Block title
Bắt đầu|Start
Kết thúc|End
Đã hoàn thành|Completed
Nhắc trước khi học|Remind before studying
Bài tập|Assignment
Kỳ thi|Exam
Học phí|Tuition
Cá nhân|Personal
Ở trường|At school
Tự học|Self-study
Bộ thẻ|Deck
Công cụ flashcard|Flashcard tools
Vườn kiến thức|Knowledge garden
Chỉ thẻ khó / từng quên|Difficult / previously forgotten cards
Ôn nhanh 10 thẻ|Quick review: 10 cards
Nhập CSV / Anki APKG|Import CSV / Anki APKG
Xuất CSV|Export CSV
Xuất Anki APKG|Export Anki APKG
Xem trước bộ thẻ|Preview deck
Bản nháp flashcard|Flashcard drafts
Chọn thẻ|Select card
Sửa thẻ nháp|Edit draft card
Câu hỏi|Question
Đáp án|Answer
Giải thích|Explanation
Loại|Type
Ôn nhanh|Quick review
Chạm để xem câu hỏi|Tap to see question
Chạm để lật thẻ|Tap to flip
Đã chăm thêm một góc vườn!|Another corner of your garden is growing!
Quên|Again
Khó|Hard
Nhớ|Good
Dễ|Easy
Tất cả bộ thẻ|All decks
Bắt đầu ôn|Start review
Nhớ từng chút một.|Remember a little more.
Ôn nhanh, thẻ khó & nhập/xuất bộ thẻ|Quick review, difficult cards & deck exchange
Luyện tập|Practice
Thử sức một chút|Test yourself
Tiếp tục bài đang làm|Resume current test
Bắt đầu thi thử|Start mock test
Sổ lỗi sai|Mistake notebook
Kết quả|Results
Ngân hàng câu hỏi|Question bank
Thêm câu hỏi đầu tiên|Add your first question
Tạo câu hỏi|Create question
Từ flashcard|From flashcards
Nhập bộ câu hỏi JSON|Import question set JSON
Chia sẻ bộ câu hỏi|Share question set
Xem trước câu hỏi|Preview questions
Chương|Chapter
Các lựa chọn|Choices
Giải thích đáp án|Answer explanation
Câu trước|Previous question
Câu sau|Next question
Nộp bài|Submit test
Thi thử|Mock test
Nộp bài và chấm điểm?|Submit and grade this test?
Bài thi đã kết thúc|Test completed
Theo chương|By chapter
Lịch sử thi thử|Test history
Kết quả luyện tập|Practice results
Chăm lại phần chưa vững|Revisit what needs practice
Ôn lại câu sai|Review mistakes
Chưa có câu cần ôn lại.|No questions to revisit yet.
CPA / GPA tích lũy|Cumulative GPA
Nếu môn tiếp theo được…|What if my next grade is…
Điểm hệ 4|Grade on a 4-point scale
Học kỳ|Semester
Cần học lại|Retake needed
Bảng điểm môn|Course grades
Tên môn|Course name
Mã môn|Course code
Điểm thành phần · hệ 10|Components · 10-point scale
Tên thành phần|Component name
Trọng số %|Weight %
Đã có điểm|Graded
Điểm / 10|Score / 10
Thêm thành phần|Add component
Cần bao nhiêu điểm?|What score do I need?
Điểm mục tiêu|Target score
Kết quả chính thức|Official result
Đã có điểm hệ 4|Official 4-point grade available
Điểm / 4|Grade / 4
Đã tích lũy tín chỉ|Credits earned
Cần học lại / còn nợ|Retake / outstanding course
Bản đồ hành trình học|Your academic journey
Một dòng cũng là tiến bộ|Even one line is progress
Trang hôm nay còn trống|Today's page is waiting
Một trang nhỏ|A small journal entry
Hôm nay đã hiểu điều gì?|What did you learn today?
Bước tiếp theo|Next step
Lấy phút tập trung đã ghi nhận ngày này|Use focus minutes logged on this day
Cảm giác buổi học|How did studying feel?
Một đích đến nho nhỏ|A small destination
Sửa mục tiêu|Edit goal
Thêm một chương đã ôn|Add a reviewed chapter
Bạn đã đến đích!|You reached your goal!
Mục tiêu học|Study goal
Tên mục tiêu|Goal title
Đơn vị|Unit
Từ|From
Đến|To
Phút tập trung|Focus minutes
Thẻ đã ôn|Reviewed cards
Công việc|Tasks
Đã chi tháng này|Spent this month
Ngân sách VND|Budget in VND
Ngân sách|Budget
Khoản chi|Expense
Chia tiền cùng nhóm|Split bills with your group
Chia tiền nhóm|Split a bill
Nhóm chi tiêu|Expense category
Số tiền VND|Amount in VND
Ngày chi|Expense date
Tên khoản chung|Shared expense title
Tổng tiền VND|Total in VND
Thành viên, cách nhau bằng dấu phẩy|Members, separated by commas
Người đã trả|Paid by
Chọn người trả|Select payer
Chia đều · phần lẻ chia theo thứ tự tên|Equal split · remainder follows member order
Chi tiêu rõ ràng hơn|A clearer view of spending
Góc âm thanh|Sound corner
Mưa|Rain
Quán cà phê|Cafe
Dừng|Stop
Âm lượng|Volume
Bảo vệ phiên tập trung|Protect your focus session
Bảo vệ tập trung|Focus protection
Một khoảng yên tĩnh|A quiet moment
Chặn ứng dụng|App shielding
Cho phép Screen Time|Allow Screen Time
Chọn app / nhóm app|Choose apps / categories
Mở chặn ngay|Unblock now
Thông báo|Notifications
Sổ học tập đang khóa|Your study notebook is locked
Mở bằng Face ID / mật mã|Unlock with Face ID / passcode
Kết nối & bảo mật|Connections & privacy
Trải nghiệm|Experience
Ngôn ngữ|Language
Giảm chuyển động|Reduce motion
Khóa bằng Face ID / mật mã|Lock with Face ID / passcode
Nhắc nhịp học|Study reminders
Nhắc giữ streak|Streak reminders
Kết nối|Connections
Sao lưu đầy đủ|Full backup
Xuất dữ liệu kèm tất cả tệp|Export data and all attachments
Nhập .mamstudy / JSON|Import .mamstudy / JSON
Đang xử lý bản sao lưu…|Processing backup…
Khôi phục bản sao lưu?|Restore this backup?
Thay dữ liệu hiện tại|Replace current data
Kết nối Calendar|Connect Calendar
Lịch muốn hiển thị trong Mầm|Calendars to show in Mam
Làm mới lịch đã chọn|Refresh selected calendars
Gửi lịch từ Mầm|Publish Mam schedules
Lịch đích|Destination calendar
Chọn lịch|Choose calendar
Gửi 30 ngày sắp tới|Publish the next 30 days
Gửi lịch của 30 ngày tới?|Publish schedules for the next 30 days?
Gửi lịch|Publish schedules
Giao diện & cảm giác|Appearance & feedback
Chế độ hiển thị|Appearance
Rung nhẹ khi tương tác|Haptic feedback
Nhịp học của mình|My study rhythm
Tên gọi|Your name
Lưu thiết lập|Save preferences
Mầm trên màn hình khóa|Mam on the Lock Screen
Hoạt động trực tiếp|Live Activities
Báo thức|Alarm
Cho phép báo thức hệ thống|Allow system alarms
Thử báo thức sau 30 giây|Test alarm in 30 seconds
Cho phép thông báo|Allow notifications
Mở cài đặt iPhone|Open iPhone settings
Nhắc đi học|Class reminders
Widget màn hình chính|Home Screen widgets
Gửi lại dữ liệu cho widget|Refresh widget data
Dữ liệu của bạn|Your data
Xuất bản sao lưu JSON|Export JSON backup
Nhập bản sao lưu|Import backup
Khôi phục bản lưu trước đó|Restore previous save
Lấy lại dữ liệu trước lần nhập gần nhất|Restore data from before the last import
Thử dữ liệu mẫu|Try sample data
Về Mầm|About Mam
Kết nối, bảo mật & sao lưu đầy đủ|Connections, privacy & full backup
Hệ thống|System
Sáng|Light
Tối|Dark
Tạm dừng|Pause
Tiếp tục|Resume
Đang vun trồng|Growing
Chỉ một việc, lúc này.|One thing, right now.
Mầm tiếp theo của bạn|Your next seedling
Môn học hoặc mục tiêu phiên này|Subject or goal for this session
Đã nhận mầm mới|Seedling collected
Vườn, streak & thống kê|Garden, streak & statistics
Một mầm mới trong vườn!|A new seedling in your garden!
Lưu xong rồi. Đến lúc nghỉ một chút.|Saved. Time for a little break.
Xóa mục này?|Delete this item?
Sách cần mua|Reading list
Quan trọng|Important
Xanh lá|Sage
Cam đào|Peach
Tím|Lavender
Xanh trời|Sky
Vàng|Butter
Hồng|Rose
Thấp|Low
Vừa|Normal
Cao|High
Tắt|Off
Báo thức hệ thống|System alarm
Chưa có bài thi đã nộp.|No submitted tests yet.
Bạn có thể đóng để làm tiếp; đồng hồ vẫn chạy.|You can close and resume later; the timer keeps running.
Mô phỏng không thay đổi bảng điểm đã lưu.|Simulation does not change your saved grades.
'''
data=dict(line.split('|',1) for line in pairs.splitlines() if '|' in line)
root=Path(__file__).resolve().parents[1]/'Resources'
for lang in ['vi','en']:
 folder=root/(lang+'.lproj');folder.mkdir(exist_ok=True)
 def quote(s):return json.dumps(s,ensure_ascii=False)
 (folder/'Localizable.strings').write_text('\n'.join(quote(k)+' = '+quote(k if lang=='vi' else v)+';' for k,v in sorted(data.items()))+'\n')
print(f'{len(data)} translated navigation and control strings')
