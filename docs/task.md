# BẢNG PHÂN CHIA NHIỆM VỤ CHI TIẾT (TASK LIST) - APP HOCZITA MVP (2 TUẦN)

> [!NOTE]  
> Đây là bảng danh sách các nhiệm vụ (Todo List) được chia nhỏ theo mô hình Agile/Scrum cho dự án 2 tuần. Bạn có thể cập nhật trạng thái các task này bằng cách đánh dấu:
> *   `[ ]` Chưa làm
> *   `[/]` Đang làm
> *   `[x]` Đã hoàn thành

---

## 🛠️ PHASE 1: THIẾT LẬP DỰ ÁN & CƠ SỞ DỮ LIỆU (Ngày 1 - 2)

- [x] **1.1. Thiết lập Database (Supabase/Firebase)**
  - [x] Khởi tạo Project trên trang quản trị Supabase/Firebase.
  - [x] Tạo bảng `profiles`:
    - `id` (uuid, primary key, foreign key liên kết với auth.users)
    - `username` (text, hiển thị tên người dùng)
    - `avatar_url` (text, link ảnh đại diện)
    - `total_score` (int, mặc định = 0)
    - `updated_at` (timestamp)
  - [x] Tạo bảng `game_scores`:
    - `id` (bigint, primary key, auto-increment)
    - `profile_id` (uuid, foreign key liên kết với `profiles.id`)
    - `game_name` (text, lưu tên trò chơi: e.g. 'flashcard_speed', 'memory_match', 'counting', 'math_ops')
    - `stars` (int, số sao đạt được: 1, 2, hoặc 3)
    - `score` (int, điểm số cụ thể)
    - `completed_at` (timestamp, mặc định = now)
  - [x] Thiết lập chính sách bảo mật Row Level Security (RLS) để chỉ cho phép user tự đọc/ghi điểm của chính mình.

- [x] **1.2. Khởi tạo & Cấu trúc Dự án Flutter**
  - [x] Khởi tạo dự án mới: `flutter create hoczita_app`
  - [x] Cấu hình màu sắc chủ đạo (`#0077bb`) trong `ThemeData` (PrimaryColor, ColorScheme).
  - [x] Cài đặt các package cần thiết trong `pubspec.yaml`:
    - `supabase_flutter` (Hoặc `firebase_core`, `firebase_auth`, `cloud_firestore`)
    - `flutter_riverpod` hoặc `provider` (Quản lý trạng thái)
    - `google_fonts` (Để sử dụng font chữ hiện đại như Inter hoặc Outfit)
    - `image_picker` (Dành cho chức năng chọn avatar)
    - `cached_network_image` (Tải hình ảnh hiệu năng cao)
  - [x] Tạo cấu trúc thư mục chuẩn MVP (Feature-first):
    ```text
    lib/
    ├── core/
    │   ├── theme/          # Cấu hình màu sắc, typography
    │   └── constants/      # Assets, API endpoints
    └── features/
        ├── auth/           # Đăng ký, đăng nhập
        ├── learn/          # Màn hình lý thuyết Toán lớp 1
        ├── game/           # Các màn hình trò chơi & template
        └── profile/        # Quản lý cá nhân, bảng xếp hạng
    ```

---

## 🔐 PHASE 2: XÁC THỰC NGƯỜI DÙNG & CORE SCREENS (Ngày 3 - 5)

- [x] **2.1. Phân hệ Xác thực (Auth Feature)**
  - [x] Thiết kế UI đẹp mắt, bo góc hiện đại cho màn hình **Đăng nhập (Login)**.
  - [x] Thiết kế màn hình **Đăng ký (Register)**.
  - [x] Viết logic Authentication Service để kết nối với Supabase/Firebase Auth.
  - [x] Tích hợp trạng thái Auth vào ứng dụng: Tự động chuyển màn hình dựa trên việc user đã login hay chưa.

- [x] **2.2. Splash Screen & Onboarding UI**
  - [x] Tạo giao diện Splash giới thiệu 3 màn hình Onboarding (chứa hình ảnh và slogan giới thiệu app).
  - [x] Cài đặt bộ đếm giờ tự động chuyển sang **Main Screen** sau 3 giây hoặc khi người dùng vuốt hết 3 trang giới thiệu.

- [x] **2.3. Màn hình Chính (Main Screen & Bottom Navigation)**
  - [x] Tạo thanh điều hướng dưới (Bottom Navigation Bar) gồm 3 tab: `Learn`, `Game`, `Account`.
  - [x] Phân quyền trạng thái đăng nhập:
    - Nếu là **Khách (Guest)**: Chỉ cho click tab `Learn`. Khi click tab `Game` hoặc `Account` sẽ hiển thị một BottomSheet/Dialog thông báo yêu cầu đăng nhập bằng tiếng Việt bắt mắt.
    - Nếu là **Thành viên (Member)**: Cho phép chuyển đổi mượt mà giữa cả 3 tab, hiển thị avatar và điểm tích lũy của thành viên ở góc trên màn hình.

- [x] **2.4. Phân hệ Học tập (Learn Feature)**
  - [x] Xây dựng màn hình danh sách bài học **Toán lớp 1**.
  - [x] Xây dựng màn hình **Học Đếm số**: Hiển thị ngẫu nhiên các hình vẽ (ví dụ: 5 quả táo) kèm câu hỏi *"Có bao nhiêu...?"* và 4 nút chọn số. Không giới hạn thời gian chơi.
  - [x] Xây dựng màn hình **Học Thêm bớt**: Hiển thị phép tính ngẫu nhiên (ví dụ: `15 + 4 = ?`) và 4 đáp án chọn lựa. Không giới hạn thời gian.

---

## 🎮 PHASE 3: GAME ENGINE TEMPLATE & MINI-GAMES (Ngày 6 - 9)

- [ ] **3.1. Xây dựng Generic Game Engine (MultipleChoiceGameScreen)**
  - [ ] Thiết kế giao diện game chuẩn:
    - Thanh Header: Nút Quay lại, Tên trò chơi, Tổng số câu (ví dụ: `2/10`), Điểm hiện tại.
    - Thanh tiến trình hình tròn (Circular Timer Progress Indicator) chạy đếm ngược từ 6 giây về 0.
  - [ ] Viết logic Timer bằng Stream/Timer trong Flutter:
    - Khi hết 6 giây mà chưa chọn đáp án: Ghi nhận là Sai, tự động chuyển câu hỏi tiếp theo và reset timer về 6 giây.
    - Khi người dùng click chọn đáp án: Đổi màu nút chọn (Xanh nếu đúng, Đỏ nếu sai), dừng timer 1 giây để người dùng nhận biết kết quả, cộng điểm nếu đúng, sau đó tự động chuyển câu tiếp theo.
  - [ ] Thiết kế màn hình **Tổng kết điểm (Game Summary Screen)** hiển thị số câu đúng, số giây hoàn thành và xếp hạng sao (⭐, ⭐⭐, ⭐⭐⭐) kèm hiệu ứng chúc mừng (confetti).

- [ ] **3.2. Cấu hình Dữ liệu cho các Game Trắc nghiệm**
  - [ ] Tạo Mock Data cho 4 game:
    - *Flashcard Speed Run*: Danh sách 50 từ tiếng Anh thông dụng và nghĩa tiếng Việt tương ứng.
    - *Picture Guess*: Danh sách từ vựng kèm link ảnh minh họa tương ứng.
    - *Đếm số (Game Version)*: Danh sách câu đố đếm vật thể kèm ảnh.
    - *Thêm bớt (Game Version)*: Bộ sinh ngẫu nhiên các phép toán cộng/trừ trong phạm vi 100.
  - [ ] Đưa dữ liệu tương ứng vào `MultipleChoiceGameScreen` để chạy thử nghiệm cả 4 game.

- [ ] **3.3. Phát triển Game Lật thẻ (Memory Match)**
  - [ ] Tạo lưới thẻ 4x4 (16 thẻ): 8 từ tiếng Anh và 8 nghĩa tiếng Việt.
  - [ ] Viết thuật toán xáo trộn vị trí ngẫu nhiên khi bắt đầu game.
  - [ ] Viết logic lật thẻ: Cho phép lật tối đa 2 thẻ cùng lúc. Nếu trùng khớp (Anh-Việt đúng cặp), giữ lại thẻ mở. Nếu sai, tự động úp thẻ sau 1 giây.
  - [ ] Tạo bộ đếm tổng thời gian chơi (Stopwatch) và tính số sao đạt được dựa trên tổng thời gian hoàn thành (1 sao: <60s, 2 sao: <40s, 3 sao: <20s).

---

## 🏆 PHASE 4: TÍCH HỢP HỆ THỐNG & ĐÓNG GÓI BÀN GIAO (Ngày 10 - 12)

- [ ] **4.1. Kết nối Backend (Lưu điểm & Bảng xếp hạng)**
  - [ ] Khi kết thúc game, gửi điểm số (`stars` và `score`) lên bảng `game_scores` trên Supabase/Firebase.
  - [ ] Viết truy vấn tính tổng điểm tích lũy của user và cập nhật vào cột `total_score` trong bảng `profiles`.
  - [ ] Xây dựng màn hình **Account / Leaderboard Tab**:
    - Hiển thị thông tin cá nhân (Avatar, Username, Tổng điểm).
    - Có chức năng chọn ảnh từ thư viện bằng `image_picker` và upload lên Supabase Storage để đổi Avatar.
    - Hiển thị danh sách bảng xếp hạng Top 10 người chơi cao điểm nhất trong tháng.

- [ ] **4.2. Tối ưu hóa UI/UX & Trơn chu hóa Hiệu ứng**
  - [ ] Đưa hình ảnh vào bộ nhớ đệm (`precacheImage`) tại Splash Screen để không bị giật/trắng màn hình khi vào game.
  - [ ] Kiểm tra và hủy (cancel) toàn bộ các Stream/Timer khi rời màn hình để tránh hao pin và rò rỉ bộ nhớ.
  - [ ] Đánh bóng lại giao diện: Các góc bo của nút bấm, căn chỉnh lề (padding) đồng nhất, font chữ không bị lỗi hiển thị tiếng Việt.

- [ ] **4.3. Kiểm thử cuối cùng & Đóng gói sản phẩm**
  - [ ] Kiểm tra toàn bộ luồng hoạt động trên cả máy ảo (Emulator) và thiết bị thật (Real Device).
  - [ ] Chạy lệnh build bản tối ưu hóa: `flutter build apk --split-per-abi` (đối với Android).
  - [ ] Chuẩn bị mã nguồn sạch (clean code), viết hướng dẫn cấu hình môi trường ngắn gọn để bàn giao.
