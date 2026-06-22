# BÁO CÁO TIẾN ĐỘ THỰC HIỆN DỰ ÁN (WALKTHROUGH)

> [!NOTE]  
> Báo cáo này ghi nhận toàn bộ kết quả công việc đã thực hiện của dự án ứng dụng **HocZiTa** tính đến ngày **23/06/2026**. Mọi thành phần mã nguồn cơ bản đã được thiết lập sẵn sàng và đồng bộ lên Git.

---

## 🛠️ Những nội dung đã hoàn thành

### 1. Cơ sở dữ liệu Supabase Schema
Chúng ta đã thiết lập cơ sở dữ liệu hoàn chỉnh tại:
*   [schema.sql](file:///d:/HocZiTa/supabase/schema.sql)
    *   **Bảng `profiles`**: Lưu thông tin thành viên (avatar, tên hiển thị, tổng điểm).
    *   **Bảng `game_scores`**: Lưu lịch sử chơi game, số sao (1-3 sao) và điểm số cụ thể. Đã chỉnh sửa tên cột từ `created_at` thành `completed_at` để thống nhất.
    *   **Bảng `bookings` [MỚI]**: Lưu thông tin lịch đặt tư vấn 1:1 của học viên.
    *   **Trigger `handle_new_user`**: Tự động tạo hồ sơ profile mới khi đăng ký.
    *   **Trigger `handle_update_total_score`**: Tự động cộng dồn điểm tích lũy của người dùng khi hoàn thành game.
    *   **Trigger `handle_new_booking` & Webhook [MỚI]**: Tự động gọi webhook Edge Function `send-booking-email` để gửi email xác nhận cho Admin (`vanncuong1614@gmail.com`) và Khách hàng khi có lịch đặt mới.
    *   **Row Level Security (RLS)**: Đảm bảo bảo mật thông tin tài khoản và kết quả của từng học viên. Bảng `bookings` cho phép insert ẩn danh/xác thực nhưng chỉ chủ sở hữu và Admin mới xem được lịch hẹn.

### 2. Tích hợp API Xác thực & Đồng bộ Hồ sơ
*   **Đăng nhập/Đăng ký với NKS API**: Kết nối trực tiếp với backend của NKS để xác thực người dùng.
*   **Đồng bộ Supabase Auth**: Khi đăng nhập NKS thành công, ứng dụng tự động thực hiện đăng nhập/đăng ký Supabase trong nền để lấy token thực hiện tải ảnh đại diện lên Storage và thao tác database.
*   **API Địa giới Hành chính**: Tích hợp NKS Geography API để lấy danh sách Tỉnh/Thành phố, Quận/Huyện, Phường/Xã cho màn hình cập nhật thông tin cá nhân.
*   **Cập nhật Profile & Avatar**: Tích hợp các API cập nhật thông tin và cập nhật avatar của NKS. Avatar được tải lên Supabase Storage và lưu liên kết vào Supabase Profiles.

### 3. Phân hệ Quét QR CCCD & Tự động điền [MỚI]
*   [cccd_qr_scanner_dialog.dart](file:///d:/HocZiTa/lib/features/profile/views/cccd_qr_scanner_dialog.dart) & [edit_profile_screen.dart](file:///d:/HocZiTa/lib/features/profile/views/edit_profile_screen.dart):
    *   Tích hợp thư viện quét mã `mobile_scanner`.
    *   Thêm tính năng **Quét QR Căn cước công dân** trên trang chỉnh sửa hồ sơ.
    *   Tự động giải mã chuỗi QR (số CCCD, Họ tên, Ngày sinh, Giới tính, Địa chỉ thường trú, Ngày cấp).
    *   Tự động tách địa chỉ thường trú và khớp với các đơn vị hành chính từ NKS Geography API để điền tự động vào các trường Tỉnh/Thành, Quận/Huyện, Phường/Xã, Số nhà/Đường.
    *   Yêu cầu quyền truy cập Camera trên Android (`AndroidManifest.xml`) và iOS (`Info.plist`).

### 4. Đặt lịch tư vấn 1:1 [MỚI]
*   [advising_booking_screen.dart](file:///d:/HocZiTa/lib/features/learn/views/advising_booking_screen.dart):
    *   Giao diện cho phép chọn Khóa học (Tiếng Anh 1:1, Tiếng Anh giao tiếp, Tiếng Anh cho người đi làm), thời gian tư vấn, thông tin cá nhân (Họ tên, SĐT, Email, Ghi chú).
    *   Lưu lịch hẹn vào bảng `bookings` trên database.
    *   Gửi email thông báo xác nhận tự động tới Admin (`vanncuong1614@gmail.com`) và email của Khách hàng.

### 5. Hệ thống Mini-Game & Ô chữ Toán học [MỚI]
*   [game_tab.dart](file:///d:/HocZiTa/lib/features/game/views/game_tab.dart): Phân chia hệ thống game thành 2 Tab rõ rệt: *Ngoại ngữ* và *Toán học*.
*   **Các game hiện có**:
    1.  *Flashcard Speed Run*: Trắc nghiệm từ vựng nhanh trong 6s.
    2.  *Memory Match*: Lật 16 thẻ tìm cặp từ đồng nghĩa Anh-Việt.
    3.  *Picture Guess*: Nhìn hình đoán từ tiếng Anh trong 6s.
    4.  *Đếm Số Nhanh*: Nhìn hình đếm số lượng vật thể trong 6s.
    5.  *Thêm Bớt Vui Nhộn*: Giải toán cộng trừ phạm vi 100 trong 6s.
    6.  *So Sánh Trái Phải*: Chọn hình nhiều hơn/ít hơn trong 6s.
    7.  *Ô Chữ Toán Học (Math Crossword) [MỚI]*:
        *   [math_crossword_game_screen.dart](file:///d:/HocZiTa/lib/features/game/views/math_crossword_game_screen.dart):
        *   Cho phép chọn số lượng phép tính để bắt đầu (Dễ: 5 phép tính - lưới 5x5, Trung bình: 10 phép tính - lưới 9x5, Khó: 20 phép tính - lưới 9x9).
        *   Tự động sinh ma trận các phép tính ngang/dọc liên kết logic với nhau.
        *   Tự động hiển thị các gợi ý (hints) và ô trống cần điền.
        *   Bàn phím ảo số học mượt mà và trực quan dành riêng cho trẻ em.
        *   Khi giải đúng tất cả phép tính, các ô sẽ hiển thị nền xanh lá tươi sáng và tự động lưu điểm số, xếp hạng sao (1-3 sao dựa theo thời gian hoàn thành).

### 6. Bảng xếp hạng (Leaderboard) & Bộ lọc
*   [profile_tab.dart](file:///d:/HocZiTa/lib/features/profile/views/profile_tab.dart): Hiển thị BXH Top 10 học viên tích lũy điểm cao nhất.
*   **Bộ lọc xếp hạng**: Hỗ trợ lọc chi tiết theo từng game cụ thể và theo thời gian (Tháng hiện tại, Tất cả thời gian) đúng như yêu cầu nghiệp vụ.

---

## 📅 Kế hoạch công việc ngày mai (24/06/2026)

Dựa trên tài liệu PDF mô tả hệ thống Game và Review, nhiệm vụ trọng tâm của ngày mai là hoàn thiện game **Ô chữ Tiếng Anh (English Crossword / Advent Crossword)** và chuẩn bị bàn giao:

1.  **Phát triển Ô Chữ Tiếng Anh (English Crossword)**
    *   **Giao diện**: Thiết kế lưới ô chữ phân bố dọc/ngang (Advent Crossword) kèm danh sách gợi ý nghĩa tiếng Việt hoặc câu hỏi mô tả (Across/Down).
    *   **Logic game**:
        *   Cho phép người chơi chọn số lượng từ để bắt đầu (tối đa 20 từ).
        *   Xây dựng thuật toán xếp từ (crossword layout generator) tự động kết nối các ký tự chung giữa các từ hàng ngang và hàng dọc từ danh sách từ vựng có sẵn.
        *   Khi điền đúng từ, các ô chữ tương ứng sẽ đổi sang nền xanh lục.
    *   **Tính điểm**: Tính sao và điểm dựa trên thời gian hoàn thành (1 sao: <60s, 2 sao: <40s, 3 sao: <20s) và lưu kết quả lên Supabase.
    *   **Tích hợp**: Liên kết game vào mục *Ngoại ngữ* trên `GameTab`.

2.  **Đóng gói & Kiểm thử toàn diện (Testing & Clean-up)**
    *   Kiểm tra tính tương thích và hiệu năng của bộ quét QR CCCD trên cả thiết bị Android và iOS thật.
    *   Kiểm tra việc gửi nhận mail đặt lịch thực tế đến hộp thư `vanncuong1614@gmail.com`.
    *   Tối ưu hóa thời gian tải hình ảnh và precache các GIF game.
