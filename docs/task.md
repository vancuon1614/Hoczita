# BẢNG PHÂN CHIA NHIỆM VỤ CHI TIẾT (TASK LIST) - APP HOCZITA MVP (2 TUẦN)

> [!NOTE]  
> Đây là bảng danh sách các nhiệm vụ (Todo List) được chia nhỏ theo mô hình Agile/Scrum cho dự án. Trạng thái nhiệm vụ:
> *   `[ ]` Chưa làm
> *   `[/]` Đang làm
> *   `[x]` Đã hoàn thành

---

## 🛠️ PHASE 1: THIẾT LẬP DỰ ÁN & CƠ SỞ DỮ LIỆU (Ngày 1 - 2)

- [x] **1.1. Thiết lập Database (Supabase)**
  - [x] Khởi tạo Project trên trang quản trị Supabase.
  - [x] Tạo bảng `profiles`:
    - `id` (uuid, primary key, foreign key liên kết với auth.users)
    - `username` (text, hiển thị tên người dùng)
    - `avatar_url` (text, link ảnh đại diện)
    - `total_score` (int, mặc định = 0)
    - `updated_at` (timestamp)
  - [x] Tạo bảng `game_scores`:
    - `id` (bigint, primary key, auto-increment)
    - `profile_id` (uuid, foreign key liên kết với `profiles.id`)
    - `game_name` (text, lưu tên trò chơi)
    - `stars` (int, số sao đạt được: 1, 2, hoặc 3)
    - `score` (int, điểm số cụ thể)
    - `completed_at` (timestamp, mặc định = now)
  - [x] Thiết lập chính sách bảo mật Row Level Security (RLS) để chỉ cho phép user tự đọc/ghi điểm của chính mình.

- [x] **1.2. Khởi tạo & Cấu trúc Dự án Flutter**
  - [x] Khởi tạo dự án mới: `flutter create hoczita_app`
  - [x] Cấu hình màu sắc chủ đạo (`#0077bb`) trong `ThemeData` (PrimaryColor, ColorScheme).
  - [x] Cài đặt các package cần thiết trong `pubspec.yaml` (`supabase_flutter`, `flutter_riverpod`, `google_fonts`, `image_picker`, `cached_network_image`).
  - [x] Tạo cấu trúc thư mục chuẩn MVP (Feature-first).

---

## 🔐 PHASE 2: XÁC THỰC NGƯỜI DÙNG & CORE SCREENS (Ngày 3 - 5)

- [x] **2.1. Phân hệ Xác thực (Auth Feature)**
  - [x] Thiết kế UI đẹp mắt, bo góc hiện đại cho màn hình **Đăng nhập (Login)** và **Đăng ký (Register)**.
  - [x] Viết logic Authentication Service để kết nối với NKS API & Supabase.
  - [x] Tích hợp trạng thái Auth vào ứng dụng: Tự động chuyển màn hình dựa trên việc user đã login hay chưa.

- [x] **2.2. Splash Screen & Onboarding UI**
  - [x] Tạo giao diện Splash giới thiệu 3 màn hình Onboarding.
  - [x] Cài đặt bộ đếm giờ tự động chuyển sang **Main Screen** sau 3 giây.

- [x] **2.3. Màn hình Chính (Main Screen & Bottom Navigation)**
  - [x] Tạo thanh điều hướng dưới (Bottom Navigation Bar) gồm 3 tab: `Learn`, `Game`, `Account`.
  - [x] Phân quyền trạng thái đăng nhập: Khách chưa đăng nhập chỉ được dùng tab Learn; click Game/Account sẽ hiện BottomSheet yêu cầu đăng nhập.

- [x] **2.4. Phân hệ Học tập (Learn Feature)**
  - [x] Xây dựng màn hình danh sách bài học **Toán lớp 1**.
  - [x] Xây dựng màn hình **Học Đếm số** (danh sách biểu tượng động, chọn đáp án).
  - [x] Xây dựng màn hình **Học Thêm bớt** (sinh phép tính ngẫu nhiên, đáp án bong bóng).

---

## 🎮 PHASE 3: GAME ENGINE TEMPLATE & MINI-GAMES (Ngày 6 - 9)

- [x] **3.1. Xây dựng Generic Game Engine (MultipleChoiceGameScreen)**
  - [x] Thiết kế giao diện game chuẩn: Nút quay lại, tên trò chơi, tổng câu, điểm số và Timer đếm ngược 6 giây.
  - [x] Viết logic Timer bằng Stream/Timer trong Flutter.
  - [x] Thiết kế màn hình **Tổng kết điểm (Game Summary Screen)** hiển thị số câu đúng, số giây hoàn thành và xếp hạng sao (⭐, ⭐⭐, ⭐⭐⭐) kèm hiệu ứng chúc mừng (confetti).

- [x] **3.2. Cấu hình Dữ liệu cho các Game Trắc nghiệm**
  - [x] Tạo Mock Data cho: *Flashcard Speed Run*, *Picture Guess*, *Đếm số (Game Version)*, *Thêm bớt (Game Version)*.
  - [x] Đưa dữ liệu tương ứng vào `MultipleChoiceGameScreen` để chạy thử nghiệm cả 4 game.

- [x] **3.3. Phát triển Game Lật thẻ (Memory Match)**
  - [x] Tạo lưới thẻ 4x4 (16 thẻ): 8 từ tiếng Anh và 8 nghĩa tiếng Việt.
  - [x] Viết thuật toán xáo trộn vị trí ngẫu nhiên và logic lật thẻ khớp cặp Anh-Việt.
  - [x] Tính số sao đạt được dựa trên tổng thời gian hoàn thành (1 sao: <60s, 2 sao: <40s, 3 sao: <20s).

---

## 🏆 PHASE 4: TÍCH HỢP HỆ THỐNG & ĐÓNG GÓI BÀN GIAO (Ngày 10 - 12)

- [x] **4.1. Kết nối Backend (Lưu điểm & Bảng xếp hạng)**
  - [x] Khi kết thúc game, gửi điểm số (`stars` và `score`) lên bảng `game_scores` trên Supabase.
  - [x] Tự động cộng dồn điểm tích lũy vào cột `total_score` trong bảng `profiles`.
  - [x] Xây dựng màn hình **Account / Leaderboard Tab** hiển thị thông tin cá nhân và bảng xếp hạng Top 10.

- [x] **4.2. Tối ưu hóa UI/UX & Trơn chu hóa Hiệu ứng**
  - [x] Đưa hình ảnh vào bộ nhớ đệm (`precacheImage`) tại Splash Screen.
  - [x] Căn chỉnh lề (padding) đồng nhất, font chữ Outfit mượt mà không lỗi tiếng Việt.

---

## 🚀 PHASE 5: TÍNH NĂNG MỞ RỘNG & PHÁT TRIỂN TUẦN 2 (Ngày 13 - 15)

- [x] **5.1. Quét QR CCCD & Tự động điền (Profile Feature)**
  - [x] Tích hợp package `mobile_scanner` quét mã QR CCCD.
  - [x] Viết logic tách chuỗi thông tin mã hóa (Số CCCD, Họ tên, Ngày sinh, Giới tính, Địa chỉ thường trú, Ngày cấp).
  - [x] Gọi NKS Geography API để tự động đối chiếu và điền Quận/Huyện, Tỉnh/Thành, Phường/Xã từ địa chỉ thường trú.

- [x] **5.2. Đặt lịch tư vấn 1:1 & Gửi Email tự động**
  - [x] Tạo bảng `bookings` lưu trữ lịch tư vấn (khóa học, thời gian, tên, SĐT, email, ghi chú).
  - [x] Tích hợp Edge Function gửi email tự động khi có lịch hẹn mới đến Admin (`vanncuong1614@gmail.com`) và email Khách hàng.

- [x] **5.3. Trò chơi Ô Chữ Toán Học (Math Crossword)**
  - [x] Thiết kế giao diện và logic game Ô chữ Toán học sinh động.
  - [x] Cấu hình 3 mức độ (Dễ - 5 phép tính, Trung bình - 10 phép tính, Khó - 20 phép tính).
  - [x] Thiết kế bàn phím số học chuyên biệt và logic đổi màu nền xanh khi giải đúng.

- [/] **5.4. Trò chơi Ô Chữ Tiếng Anh (English Crossword / Advent Crossword) [Kế hoạch ngày mai]**
  - [ ] Thiết kế giao diện lưới ô chữ chia đều theo hàng ngang và hàng dọc (Advent Crossword).
  - [ ] Hỗ trợ chọn số lượng từ để bắt đầu (tối đa 20 từ).
  - [ ] Thiết kế logic điền ký tự cho từng ô chữ, kiểm tra đáp án đúng thì đổi màu nền xanh.
  - [ ] Tính điểm, xếp sao và lưu kết quả lên Supabase.

- [/] **5.5. Đóng gói & Kiểm thử cuối tuần**
  - [ ] Kiểm thử luồng quét CCCD và gửi email đặt lịch trên cả Android/iOS thật.
  - [ ] Đóng gói phiên bản ứng dụng Android (APK) và iOS tối ưu.
