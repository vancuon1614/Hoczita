# KẾ HOẠCH HÀNH ĐỘNG HỎA TỐC: ĐỂ HOÀN THÀNH APP HOCZITA TRONG 2 TUẦN (MVP STRATEGY)

> [!WARNING]  
> Thời gian **2 tuần** là một thử thách rất lớn đối với việc phát triển một ứng dụng di động hoàn chỉnh có cả game và backend. Để bàn giao sản phẩm chạy tốt, không lỗi và đúng hạn, chúng ta bắt buộc phải chuyển sang **Chiến lược tối ưu hóa MVP (Sản phẩm Khả dụng Tối thiểu)**.

---

## 1. Bí quyết Rút ngắn 70% Thời gian: Kiến trúc "Game Template" tái sử dụng

Khi phân tích kỹ 6 trò chơi trong tài liệu đặc tả, chúng ta phát hiện ra **4 trong số 6 game hoạt động trên cùng một cơ chế (Core Engine)**:

| Mini-game | Loại câu hỏi | Loại đáp án | Bộ đếm thời gian | Số câu hỏi |
| :--- | :--- | :--- | :--- | :--- |
| **Flashcard Speed Run** | Chữ (English Word) | 4 nút chữ tiếng Việt | 6 giây | 10 |
| **Picture Guess** | Ảnh (Vocabulary Image) | 4 nút chữ tiếng Việt | 6 giây | 10 |
| **Đếm số (Game Math)** | Ảnh (Object Image) | 4 nút số tiếng Việt | 6 giây | 10 |
| **Thêm bớt (Game Math)** | Chữ (Equation `13 + 5`) | 4 nút số tiếng Việt | 6 giây | 10 |

### Giải pháp kỹ thuật:
Thay vì viết code riêng cho 4 màn hình game khác nhau, chúng ta sẽ viết **duy nhất 1 Widget màn hình game đa năng** đặt tên là `MultipleChoiceGameScreen`. Widget này nhận dữ liệu đầu vào (Data Model) linh hoạt:
*   Nếu câu hỏi có ảnh $\rightarrow$ hiển thị `Image.network` hoặc `SvgPicture`.
*   Nếu câu hỏi có chữ $\rightarrow$ hiển thị `Text`.
*   Bộ đếm giờ 6s và cơ chế tự động chuyển câu hỏi được dùng chung cho tất cả.

Như vậy, chúng ta chỉ cần viết code cho:
1.  `MultipleChoiceGameScreen` (Dùng cho 4 game).
2.  `MemoryMatchGameScreen` (Game lật 16 thẻ - Đòi hỏi giao diện riêng).
3.  `ComparisonGameScreen` (Game chọn Trái/Phải - Đòi hỏi giao diện riêng).

---

## 2. Kế hoạch Rút gọn Tính năng (Scope Prioritization) cho 2 Tuần

Để đảm bảo chất lượng, chúng ta sẽ phân loại các tính năng theo thứ tự ưu tiên:

```
┌────────────────────────────────────────────────────────────────────────┐
│                          MVP SCOPE (2 WEEKS)                           │
├───────────────────────────────────┬────────────────────────────────────┤
│           MUST HAVE (Làm)         │        COULD HAVE (Để sau)         │
├───────────────────────────────────┼────────────────────────────────────┤
│ - Splash Screen & Main Screen     │ - Đăng nhập bằng Google/Facebook   │
│ - Đăng ký/Đăng nhập (Email/Pass)  │ - Đổi mật khẩu / Quên mật khẩu     │
│ - Tải/Cập nhật Avatar             │ - Trò chơi "So sánh" (Nếu thiếu t.g)│
│ - Phần Học tập (Toán 1)           │ - Âm nhạc nền phức tạp (Background)│
│ - 3-4 Game cốt lõi (dùng chung   │ - Hiệu ứng chuyển động quá phức tạp│
│   template)                       │                                    │
│ - Xem điểm & Bảng xếp hạng (Supabase)│                                    │
└───────────────────────────────────┴────────────────────────────────────┘
```

---

## 3. Lịch trình chi tiết theo từng ngày (Day-by-Day Roadmap)

### TUẦN 1: Thiết lập hạ tầng và Hoàn thiện Khung ứng dụng (Core App & Auth)

*   **Ngày 1 (Thứ Tư): Khởi tạo dự án & Thiết lập Cơ sở dữ liệu**
    *   Tạo mới dự án Flutter (Sử dụng kiến trúc thư mục Feature-first: `auth`, `learn`, `game`, `profile`).
    *   Tạo tài khoản Supabase (mất 5 phút) để có ngay cơ sở dữ liệu Postgres và dịch vụ Auth.
    *   Tạo các bảng trong Database: `profiles` (id, username, avatar_url, total_score), `game_scores` (profile_id, game_name, score, completed_at).
*   **Ngày 2 (Thứ Năm): Tính năng Đăng nhập & Đăng ký**
    *   Tích hợp SDK `supabase_flutter`.
    *   Hoàn thiện màn hình: Đăng ký, Đăng nhập, và màn hình cập nhật thông tin tài khoản (username, upload avatar).
*   **Ngày 3 (Thứ Sáu): Splash Screen & Main Screen**
    *   Thiết kế Splash giới thiệu 3 màn hình Onboarding (chuyển màn hình sau 3s).
    *   Thiết kế Main Screen:
        *   Trạng thái Guest: Khóa tab Game, chỉ mở tab Learn.
        *   Trạng thái Member: Hiển thị lời chào kèm Avatar từ Supabase và tổng điểm.
*   **Ngày 4-5 (Thứ Bảy & Chủ Nhật): Xây dựng phân hệ Học tập (Learn Screen)**
    *   Xây dựng UI cho phần học tập "Toán lớp 1" (Đếm số & Thêm bớt). Không tính giờ, giao diện đơn giản, thân thiện với trẻ em.

---

### TUẦN 2: Xây dựng Game Engine, Bảng xếp hạng & Kiểm thử bàn giao

*   **Ngày 6-7 (Thứ Hai & Thứ Ba): Phát triển Core Game Template**
    *   Viết widget `MultipleChoiceGameScreen` có bộ đếm ngược 6 giây bằng Stream/Timer, thanh tiến trình tròn đếm ngược.
    *   Tích hợp dữ liệu để hiển thị 4 trò chơi: *Flashcard Speed Run*, *Picture Guess*, *Đếm số*, *Thêm bớt*.
*   **Ngày 8 (Thứ Tư): Phát triển Game Lật thẻ (Memory Match)**
    *   Tập trung xây dựng game lật 16 thẻ. Viết thuật toán xáo trộn thẻ (shuffle) và ghép cặp (matching logic). Tính tổng thời gian chơi.
*   **Ngày 9 (Thứ Năm): Kết nối dữ liệu điểm & Bảng xếp hạng**
    *   Lưu điểm số (1 sao, 2 sao, 3 sao) sau khi chơi xong lên Supabase.
    *   Viết màn hình Bảng xếp hạng (Leaderboard) lấy dữ liệu từ Supabase theo tháng và theo từng game.
*   **Ngày 10 (Thứ Sáu): Kiểm thử (Testing) & Sửa lỗi (Debugging)**
    *   Kiểm tra kỹ các trường hợp gián đoạn: Đang chơi thì nhấn Back, mất mạng, thiết bị màn hình nhỏ.
    *   Tối ưu hóa tốc độ tải ảnh (sử dụng cache).
*   **Ngày 11-12 (Thứ Bảy & Chủ Nhật): Đóng gói & Bàn giao sản phẩm**
    *   Build ứng dụng bản Release (`flutter build apk` và cấu hình iOS test).
    *   Chuẩn bị video demo các luồng chạy thử để bàn giao cho khách hàng/giáo viên hướng dẫn.

---

## 4. Các điểm cần lưu ý để giữ đúng tiến độ (Tips for Success)

1.  **Dùng Mock Data khi làm UI:** Khi viết giao diện, đừng đợi backend xong. Hãy tạo dữ liệu giả (Mock Data) trực tiếp trong code Flutter để làm giao diện chạy thử trước, sau đó chỉ cần map với dữ liệu từ API Supabase.
2.  **Sử dụng thư viện chất lượng cao:**
    *   Quản lý trạng thái: Sử dụng `flutter_riverpod` hoặc `provider` cho nhanh và dễ bảo trì.
    *   Thông báo: `fluttertoast` hoặc `cool_alert` để làm thông báo đẹp không tốn thời gian.
    *   Avatar: Dùng package `image_picker` để chụp/chọn ảnh và đưa thẳng lên Supabase Storage.
3.  **Tập trung vào phần nhìn (Visuals First):** Dù thời gian ngắn, tông màu `#0077bb` và các nút bấm bo góc tròn, đổ bóng mịn sẽ tạo cảm giác ứng dụng cực kỳ "xịn". Hãy trau chuốt phần giao diện và micro-interactions vì đó là thứ người dùng/stakeholder đánh giá đầu tiên.
