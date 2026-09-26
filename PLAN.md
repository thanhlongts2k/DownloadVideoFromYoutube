# 📋 KẾ HOẠCH PHÁT TRIỂN ỨNG DỤNG ANDROID: YOUTUBE MEDIA DOWNLOADER (YouTubex)

> **Mục tiêu**: Xây dựng ứng dụng di động Android chuyên nghiệp, giao diện Dark Glassmorphism cao cấp, hỗ trợ bóc tách và tải video/audio YouTube mọi chất lượng (1080p, 720p, 480p, MP3 CBR 192k, Fast M4A), quản lý tiến trình tải nền và thư viện phát offline.

---
> ⚠️ **Yêu cầu quan trọng từ người dùng**:
> Sau khi hoàn tất toàn bộ các Phase, BẮT BUỘC tiến hành đóng gói APK Release (lutter build apk --release), tạo tag git release (ví dụ 1.0.0) và tự động tạo GitHub Release đính kèm file pp-release.apk lên repository https://github.com/thanhlongts2k/DownloadVideoFromYoutube.git!

---

## 🏗️ 1. KIẾN TRÚC TỔNG THỂ (DUAL-ENGINE ARCHITECTURE)

\┌────────────────────────────────────────────────────────┐
│                   YouTubex Mobile App                  │
│       (Flutter 3.24+ / Riverpod / Glassmorphism)       │
└───────────────────────────┬────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
 ┌──────────────────────┐       ┌──────────────────────┐
 │   ENGINE A: DIRECT   │       │   ENGINE B: SERVER   │
 │ (youtube_explode_dart│       │ (Flask + yt-dlp API  │
 │  Chạy Offline Local) │       │  Node JS Solver)     │
 └──────────┬───────────┘       └──────────┬───────────┘
            │                              │
            └───────────────┬──────────────┘
                            ▼
 ┌─────────────────────────────────────────────────────┐
 │                  DOWNLOAD MANAGER                   │
 │   - Dio Parallel Streaming / Chunked Download       │
 │   - Tự động cộng dồn / cập nhật % & tốc độ          │
 │   - Android Foreground Notification Service         │
 └──────────────────────────┬──────────────────────────┘
                            ▼
 ┌─────────────────────────────────────────────────────┐
 │               LOCAL STORAGE & LIBRARY               │
 │   - Lưu vào Movies/YouTubex & Music/YouTubex        │
 │   - Trình phát tích hợp Audio/Video Player          │
 │   - Chia sẻ nhanh qua Zalo, Telegram, Open With     │
 └─────────────────────────────────────────────────────┘
\
---

## 🎯 2. LỘ TRÌNH TRIỂN KHAI TỪNG PHASE (DETAILED PHASES)

### 📌 PHASE 0: Khởi tạo dự án & Đặc tả kế hoạch
- [x] Tạo dự án Flutter Android (\ytdownloader\).
- [x] Lập kế hoạch chi tiết \PLAN.md\ và \README.md\.
- [x] Cấu hình \.gitignore\ và git remote \https://github.com/thanhlongts2k/DownloadVideoFromYoutube.git\.
- [ ] Commit & Push Phase 0.

### 📌 PHASE 1: Nền tảng Core, Design System & Data Models
- [ ] Cấu hình \pubspec.yaml\ với các package chuẩn:
  - State Management: \lutter_riverpod  - Network & Download: \dio  - Direct YouTube Extractor: \youtube_explode_dart  - Storage & Cache: \shared_preferences\, \path_provider  - UI & Media: \cached_network_image\, \open_filex\, \share_plus\, \permission_handler\, \lutter_local_notifications- [ ] Xây dựng **Design System Tokens** (\AppColors\, \AppTextStyles\, \LiquidGlassSurface\, \GlassButton\, \QualityBadge\).
- [ ] Định nghĩa Data Models:
  - \VideoMetadata\ (ID, tiêu đề, tác giả, thời lượng, thumbnail, lượt xem).
  - \DownloadFormat\ (độ phân giải, bitrate, dung lượng ước tính, loại video/audio).
  - \DownloadTask\ (ID, tiến độ %, tốc độ tải, dung lượng đã tải, trạng thái: downloading, paused, completed, error).
- [ ] Commit & Push Phase 1.

### 📌 PHASE 2: Services & Downloader Engines
- [ ] **Engine Service**:
  - \DirectYouTubeService\: Bóc tách trực tiếp trên máy bằng \youtube_explode_dart\.
  - \ServerApiService\: Kết nối tới Python Flask API (\http://192.168.x.x:5000\ hoặc host online) khi người dùng muốn tận dụng FFmpeg gộp 1080p hoặc nén MP3 192k.
- [ ] **URL Parser & Cleaner**: Tự động nhận diện link YouTube, shorts, youtu.be, loại bỏ tham số playlist/mix rác.
- [ ] **Download Service**: Quản lý hàng đợi tải (Download Queue), ghi file trực tiếp vào bộ nhớ thiết bị, cập nhật notification nền.
- [ ] Commit & Push Phase 2.

### 📌 PHASE 3: Giao diện Người dùng Chính (Core UI Screens)
- [ ] **Màn hình Trang chủ (Home Screen)**:
  - Tự động nhận diện URL từ Clipboard khi vừa mở ứng dụng.
  - Thanh nhập URL kiểu kính mờ (Glassmorphism Input) với nút Paste & Clear nhanh.
  - Trạng thái tải thông tin (Shimmer Skeleton Loader).
- [ ] **Bảng chọn chất lượng (Format Selector Modal)**:
  - Hiển thị đầy đủ Thumbnail, Thời lượng, Kênh, Tiêu đề.
  - Danh sách video: 1080p Full HD, 720p HD, 480p, 360p kèm pill dung lượng \📦 ... MB\.
  - Danh sách audio: HQ MP3 192kbps & Fast M4A.
  - Nút Tải về hiệu ứng bấm mượt mà, phản hồi rung haptic.
- [ ] **Màn hình Tiến trình Đang tải (Active Downloads Tab)**:
  - Thẻ tải động với thanh Progress Bar neon phát sáng.
  - Hiển thị % hoàn thành, tốc độ tải tức thì (MB/s), thời gian còn lại (ETA).
- [ ] Commit & Push Phase 3.

### 📌 PHASE 4: Thư viện Đã tải & Trình phát Offline (Media Library)
- [ ] **Thư viện Media (Downloaded Tab)**:
  - Bộ lọc tabs: Tất cả, Video, Âm thanh.
  - Hiển thị ngày tải, kích thước file, thời lượng.
  - Menu ngữ cảnh: Mở bằng ứng dụng ngoài (\open_filex\), Chia sẻ (\share_plus\), Xóa file.
- [ ] **Trình phát Offline tích hợp**:
  - Trình phát âm thanh nổi (Mini Audio Player) với nút Play/Pause/Seek bar.
- [ ] Commit & Push Phase 4.

### 📌 PHASE 5: Cài đặt, Phân quyền & Đóng gói Release APK
- [ ] **Màn hình Cài đặt (Settings)**:
  - Cấu hình Server IP (mặc định hoặc tự nhập LAN IP của máy tính chạy server Flask).
  - Chọn thư mục lưu trữ mặc định.
  - Chuyển đổi qua lại giữa Engine Direct (Offline) và Engine Server (FFmpeg HQ).
- [ ] Cấu hình quyền \AndroidManifest.xml\ (INTERNET, WRITE_EXTERNAL_STORAGE, FOREGROUND_SERVICE, POST_NOTIFICATIONS).
- [ ] Kiểm thử toàn diện & build file APK Release (\lutter build apk --release\).
- [ ] Cập nhật tài liệu \README.md\ hoàn chỉnh.
- [ ] Commit & Push Phase 5.

---

## 🔒 NGUYÊN TẮC QUẢN LÝ DỰ ÁN
1. Mọi phase đều được kiểm tra biên dịch không lỗi trước khi commit.
2. Commit message tuân thủ chuẩn Conventional Commits (\eat\, \docs\, \ix\, efactor\).
3. Push lần lượt từng phase lên repository GitHub \https://github.com/thanhlongts2k/DownloadVideoFromYoutube.git\.
