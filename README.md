# HocZiTa - Ứng dụng Học tập & Trò chơi cho Học sinh Lớp 1

HocZiTa là ứng dụng di động được viết bằng Flutter, giúp các bé học sinh lớp 1 vừa chơi vừa học môn Toán và Tiếng Anh thông qua các trò chơi tương tác thú vị.

---

## Các chức năng chính

### 1. Đăng nhập & Đăng ký nhanh
* Bé hoặc phụ huynh có thể đăng ký tài khoản nhanh chóng.
* Có tính năng ghi nhớ tài khoản trên thiết bị, bé có thể dễ dàng chuyển đổi qua lại giữa các tài khoản khác nhau chỉ bằng một cú chạm (không cần gõ lại email).

### 2. Học tập & Trò chơi (Gamification)
* **Phần Học tập:** Các bài học đếm số và phép tính cộng trừ cơ bản không giới hạn thời gian để bé luyện tập thoải mái.
* **Phần Trò chơi (Mini-games):**
  * *Tiếng Anh:* Đoán chữ qua hình (tải ảnh 3D Clay trực tiếp từ server), Lật thẻ ghi nhớ (Memory Match), Chạy tốc độ từ vựng.
  * *Toán học:* So sánh lớn bé / Trái phải, Đếm số nhanh, Tàu hỏa thêm bớt.
  * Có hệ thống tính điểm, đếm ngược thời gian và xếp hạng sao (1-3 sao) sinh động để tạo động lực cho bé.

### 3. Hồ sơ học sinh cá nhân hóa
* **Đổi ảnh đại diện:** Cho phép chụp ảnh mới hoặc chọn từ thư viện, sau đó di chuyển, co giãn vòng tròn cắt và xoay ảnh trước khi lưu.
* **Địa chỉ thông minh:** Các ô Tỉnh/Thành phố, Quận/Huyện, Phường/Xã được tải tự động từ API địa lý trực tuyến giúp tránh việc gõ sai.
* **Đổi mật khẩu & Tạo mật khẩu ngẫu nhiên:** Hỗ trợ đổi mật khẩu mới hoặc tự động tạo mật khẩu ngẫu nhiên cực kỳ bảo mật (tùy chọn số ký tự, chữ hoa, chữ thường, ký tự đặc biệt).

---

## Backend kết nối
Ứng dụng sử dụng song song hai hệ thống:
1. **Supabase:** Dùng để quản lý tài khoản người dùng, đồng bộ bảng xếp hạng và lưu trữ hình ảnh 3D cho trò chơi.
2. **NKS API:** Kết nối API địa lý trực tuyến để tải danh mục địa chỉ và đồng bộ hóa thông tin cá nhân/ảnh đại diện của học sinh lên máy chủ NKS.

---

## Hướng dẫn cài đặt & Chạy ứng dụng

### Bước 1: Tải các thư viện cần thiết
Mở terminal tại thư mục dự án và chạy:
```bash
flutter pub get
```

### Bước 2: Chạy ứng dụng
Kết nối điện thoại hoặc mở máy ảo lên, sau đó chạy:
```bash
flutter run
```
*(Nếu muốn chạy trên trình duyệt web, bạn có thể chạy `flutter run -d chrome` hoặc chọn Edge).*
