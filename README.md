# HocZiTa - Hệ Thống Game & Học Tập Giáo Dục (Toán Lớp 1 & Tiếng Anh)

Ứng dụng di động đa nền tảng (iOS & Android) được xây dựng bằng **Flutter Framework** và hỗ trợ kết nối backend **Supabase**. Dự án phục vụ rèn luyện tư duy và ôn tập kiến thức cho học sinh lớp 1 thông qua cơ chế trò chơi thú vị (Gamification).

## 🚀 Tính Năng Chính
1.  **Phân hệ Học Tập (Learn):**
    *   Ôn luyện kiến thức không giới hạn thời gian.
    *   Học đếm số thông minh & Phép tính cộng/trừ trong phạm vi 100.
2.  **Hệ Thống Trò Chơi (Mini-Games):**
    *   *Ngoại ngữ (Tiếng Anh):* Flashcard Speed Run (Chọn nghĩa nhanh trong 6s), Memory Match (Lật 16 thẻ ghép Anh-Việt), Picture Guess (Đoán từ qua hình).
    *   *Toán học:* Đếm Số Nhanh (Game), Tàu Hỏa Thêm Bớt (Game), So Sánh Trái/Phải (Game).
    *   Cơ chế đếm ngược 6 giây kích thích tư duy nhạy bén và tính điểm xếp hạng sao (⭐, ⭐⭐, ⭐⭐⭐) theo thời gian hoàn thành.
3.  **Hệ Thống Thành Viên:**
    *   Đăng ký / Đăng nhập tài khoản bảo mật.
    *   Quản lý thông tin cá nhân & Đổi ảnh đại diện (Avatar).
    *   Lưu lịch sử chơi và tự động cộng dồn điểm tích lũy.
    *   Xem bảng xếp hạng Top 10 thành viên có điểm số cao nhất trong tháng.

---

## 🛠️ Hướng Dẫn Thiết Lập Backend (Supabase)

Để thiết lập cơ sở dữ liệu cho dự án, vui lòng thực hiện các bước sau:

1.  Truy cập [Supabase](https://supabase.com) và tạo một Project mới.
2.  Mở mục **SQL Editor** trong trang quản trị Supabase.
3.  Mở tệp [supabase/schema.sql](supabase/schema.sql) trong dự án này, copy toàn bộ nội dung và paste vào SQL Editor, sau đó nhấn **Run**.
    *   *Mã SQL này sẽ tự động tạo cấu trúc bảng `profiles`, `game_scores`, cài đặt bảo mật RLS và cấu hình các Trigger tự động tạo profile khi đăng ký hoặc tự động cộng dồn điểm số khi có điểm game mới.*
4.  Copy **Project URL** và **Anon Key** từ mục *Project Settings -> API* của Supabase.
5.  Mở tệp `lib/core/constants/supabase_constants.dart` trong mã nguồn Flutter của bạn và điền thông tin vào:
    ```dart
    static const String url = 'ĐIỀN_PROJECT_URL_CỦA_BẠN';
    static const String anonKey = 'ĐIỀN_ANON_KEY_CỦA_BẠN';
    ```

---

## 📱 Hướng Dẫn Chạy Ứng Dụng (Flutter)

### 1. Chuẩn bị môi trường
Yêu cầu máy tính đã cài đặt **Flutter SDK (v3.38.5 trở lên)** và **Dart SDK**.
Chạy lệnh sau trong thư mục dự án để kiểm tra:
```bash
flutter doctor
```

### 2. Cài đặt các thư viện (Dependencies)
Chạy lệnh sau để tải các package:
```bash
flutter pub get
```

### 3. Chạy Demo Offline (Offline Mode)
*   **Không cần kết nối internet hay tài khoản Supabase:** Ứng dụng đã được tích hợp cơ chế **Demo Offline** thông minh. 
*   Nếu bạn chưa điền thông tin ở file `supabase_constants.dart`, ứng dụng sẽ tự động chạy ở chế độ Demo. Khi màn hình Đăng nhập hiện ra, bạn chỉ cần nhấn nút **"Chế độ Demo Offline (Không cần mạng)"** màu cam ở bên dưới để trải nghiệm đầy đủ các tính năng giả lập (Đăng nhập mẫu, chơi lưu điểm, bảng xếp hạng) mà không bị crash hay báo lỗi.

### 4. Chạy trên thiết bị/máy ảo
Kết nối thiết bị thật (bật USB Debugging) hoặc mở máy ảo (Emulator/Simulator), sau đó chạy lệnh:
```bash
flutter run
```

---

## 📂 Cấu Trúc Mã Nguồn (Clean Architecture - Feature-First)
```text
lib/
├── core/
│   ├── theme/          # Cấu hình màu sắc (#0077bb), font Outfit và Style nút bấm.
│   ├── constants/      # Khai báo hằng số hệ thống và key kết nối.
│   └── services/       # Lớp kết nối API Supabase & logic Demo Offline.
└── features/
    ├── auth/           # Module Đăng nhập, Đăng ký & Riverpod Provider quản lý Session.
    ├── onboarding/     # Splash Screen & 3 trang giới thiệu (Onboarding slides).
    ├── home/           # Khung điều hướng chính (BottomNavigationBar).
    ├── learn/          # Tab học tập Toán lớp 1.
    ├── game/           # Tab hệ thống trò chơi trắc nghiệm & game lật thẻ.
    └── profile/        # Tab Hồ sơ cá nhân và truy vấn Bảng xếp hạng.
```

---

*Hệ thống được thiết kế và tối ưu bởi Antigravity Chuyên gia Mobile Tech*
