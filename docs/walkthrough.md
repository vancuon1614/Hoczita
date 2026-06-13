# BÁO CÁO TIẾN ĐỘ THỰC HIỆN DỰ ÁN (WALKTHROUGH)

> [!NOTE]  
> Báo cáo này ghi nhận toàn bộ kết quả công việc đã thực hiện trong **Phase 1** của dự án ứng dụng **HocZiTa**. Mọi thành phần mã nguồn cơ bản đã được thiết lập sẵn sàng để báo cáo lúc **14:30**.

---

## 🛠️ Những nội dung đã hoàn thành

### 1. Cơ sở dữ liệu Supabase Schema
Chúng ta đã lập trình sẵn mã lệnh SQL thiết lập cơ sở dữ liệu hoàn chỉnh tại:
*   [schema.sql](file:///d:/HocZiTa/supabase/schema.sql)
    *   **Bảng `profiles`**: Lưu thông tin thành viên (avatar, tên hiển thị, tổng điểm).
    *   **Bảng `game_scores`**: Lưu lịch sử chơi game, số sao (1-3 sao) và điểm số cụ thể.
    *   **Trigger `handle_new_user`**: Tự động tạo hàng mới trong `profiles` khi người dùng đăng ký tài khoản thành công ở Supabase Auth.
    *   **Trigger `handle_update_total_score`**: Tự động cộng dồn điểm số của người dùng khi có bản ghi điểm game mới.
    *   **Row Level Security (RLS)**: Cấu hình phân quyền bảo mật dữ liệu. Bất kỳ ai cũng có thể đọc thông tin để hiển thị bảng xếp hạng, nhưng chỉ có chủ sở hữu tài khoản mới được cập nhật hồ sơ và thêm điểm số của mình.

### 2. Khởi tạo & Cấu trúc mã nguồn Flutter
Chúng ta đã tạo thành công mã nguồn cơ sở của ứng dụng Flutter với cấu trúc thư mục **Feature-first** cực kỳ ngăn nắp:
*   [app_theme.dart](file:///d:/HocZiTa/lib/core/theme/app_theme.dart): Thiết lập hệ thống màu sắc chủ đạo (`#0077bb`), các gradient đẹp mắt, bo góc nút bấm 16px hiện đại, và font chữ thời thượng `Google Fonts Outfit`.
*   [supabase_constants.dart](file:///d:/HocZiTa/lib/core/constants/supabase_constants.dart): File cấu hình credentials để người dùng kết nối với dự án Supabase của họ.
*   [supabase_service.dart](file:///d:/HocZiTa/lib/core/services/supabase_service.dart): Lớp quản lý kết nối cơ sở dữ liệu và xác thực. Đặc biệt tích hợp **Chế độ Demo Offline** (Offline Demo Mode) tự động kích hoạt khi chưa điền thông tin kết nối Supabase, cho phép ứng dụng chạy demo mượt mà (đăng ký, đăng nhập giả lập, chơi lưu điểm giả lập và xem bảng xếp hạng) mà không sợ bị crash/lỗi mạng.
*   [auth_provider.dart](file:///d:/HocZiTa/lib/features/auth/providers/auth_provider.dart): Quản lý trạng thái xác thực bằng **Riverpod StateNotifier** đồng bộ toàn app.

### 3. Thiết kế giao diện luồng chính (Main Shell Flows)
Chúng ta đã hoàn thiện toàn bộ luồng giao diện cơ sở của ứng dụng:
*   [splash_screen.dart](file:///d:/HocZiTa/lib/features/onboarding/views/splash_screen.dart): Giao diện onboarding giới thiệu 3 bước bằng hiệu ứng chuyển trang mượt mà, tự động chuyển trang sau 1s và tự chuyển sang Màn hình chính sau 3.2s.
*   [main_screen.dart](file:///d:/HocZiTa/lib/features/home/views/main_screen.dart): Khung sườn BottomNavigationBar với 3 tab: *Học tập, Trò chơi, Tài khoản*. Có tính năng chặn (Auth Gating) khách chưa đăng nhập khi truy cập phần Game/Tài khoản và hiển thị hộp thoại BottomSheet yêu cầu đăng nhập bằng tiếng Việt bắt mắt.
*   [learn_tab.dart](file:///d:/HocZiTa/lib/features/learn/views/learn_tab.dart): Tab học tập hiển thị các danh mục bài học Toán lớp 1 sinh động. Đã liên kết đầy đủ nút bấm với các bài học thực tế:
    *   [counting_lesson_screen.dart](file:///d:/HocZiTa/lib/features/learn/views/counting_lesson_screen.dart): Giao diện học đếm số thông minh sử dụng danh sách biểu tượng động (emoji) bắt mắt. Bé đếm số lượng vật thể hiển thị và chọn 1 trong 4 đáp án (cho phép chọn lại khi chọn sai, không giới hạn thời gian).
    *   [math_ops_lesson_screen.dart](file:///d:/HocZiTa/lib/features/learn/views/math_ops_lesson_screen.dart): Giao diện học cộng trừ cơ bản thiết kế bảng đen phấn trắng sinh động. Sinh phép tính ngẫu nhiên và 4 đáp án bong bóng.

*   [game_tab.dart](file:///d:/HocZiTa/lib/features/game/views/game_tab.dart): Tab trò chơi chia làm 2 phân mục lớn (Ngoại ngữ, Toán học) hiển thị danh sách 6 mini-game có xếp hạng sao.
*   [profile_tab.dart](file:///d:/HocZiTa/lib/features/profile/views/profile_tab.dart): Tab hồ sơ hiển thị thẻ thông tin cá nhân và Bảng xếp hạng Top 10 người chơi cao điểm nhất trong tháng.
*   [login_screen.dart](file:///d:/HocZiTa/lib/features/auth/views/login_screen.dart) & [register_screen.dart](file:///d:/HocZiTa/lib/features/auth/views/register_screen.dart): Giao diện form đăng ký/đăng nhập trực quan, đã được tối ưu hóa bộ lọc và xác thực (chặn khoảng trắng email bằng `FilteringTextInputFormatter`, loại bỏ lỗi TLD email dài hơn 4 ký tự bằng regex chuẩn, và kiểm tra khoảng trắng ở đầu/cuối mật khẩu) để tránh lỗi định dạng khi người dùng sao chép-dán hoặc nhập liệu. Có kèm nút tắt để chạy nhanh ở **Chế độ Demo Offline (Không cần mạng)**.

