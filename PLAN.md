# 📋 KẾ HOẠCH PHÁT TRIỂN ỨNG DỤNG ANDROID: YOUTUBE MEDIA DOWNLOADER (YouTubex)

> **Mục tiêu**: Xây dựng ứng dụng di động Android chuyên nghiệp, giao diện Dark Glassmorphism cao cấp, hỗ trợ bóc tách và tải video/audio YouTube mọi chất lượng (1080p, 720p, 480p, MP3 CBR 192k, Fast M4A), quản lý tiến trình tải nền và thư viện phát offline.

---
> ⚠️ **Yêu cầu quan trọng từ người dùng**:
> Sau khi hoàn tất toàn bộ các Phase, BẮT BUỘC tiến hành đóng gói APK Release (`flutter build apk --release`), tạo tag git release (ví dụ `v1.0.0`) và tự động tạo GitHub Release đính kèm file `app-release.apk` lên repository `https://github.com/thanhlongts2k/DownloadVideoFromYoutube.git`!
---

## 🏗️ 1. KIẾN TRÚC TỔNG THỂ (DUAL-ENGINE ARCHITECTURE)

```
┌────────────────────────────────────────────────────────┐
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
```

---

## 🎯 2. LỘ TRÌNH TRIỂN KHAI TỪNG PHASE (DETAILED PHASES)

### 📌 PHASE 0: Khởi tạo dự án & Đặc tả kế hoạch
- [x] Tạo dự án Flutter Android (`ytdownloader`).
- [x] Lập kế hoạch chi tiết `PLAN.md` và `README.md`.
- [x] Cấu hình `.gitignore` và git remote `https://github.com/thanhlongts2k/DownloadVideoFromYoutube.git`.
- [x] Commit & Push Phase 0 (`0e167ed`).

### 📌 PHASE 1: Nền tảng Core, Design System & Data Models
- [x] Cấu hình `pubspec.yaml` với các package chuẩn:
  - State Management: `flutter_riverpod`
  - Network & Download: `dio`
  - Direct YouTube Extractor: `youtube_explode_dart`
  - Storage & Cache: `shared_preferences`, `path_provider`
  - UI & Media: `cached_network_image`, `open_filex`, `share_plus`, `permission_handler`, `flutter_local_notifications`
- [x] Xây dựng **Design System Tokens** (`AppColors`, `AppTypography`, `AppTheme`).
- [x] Bổ sung components Liquid Glass: `LiquidGlassCard`, `GlassButton`, `QualityBadge`.
- [x] Định nghĩa Data Models: `VideoMetadata`, `DownloadFormat`, `DownloadTask`.
- [x] Commit & Push Phase 1 (`2d541cb`).

### 📌 PHASE 2: Services & Downloader Engines
- [x] **URL Parser & Cleaner** (`UrlCleaner`): Tự động nhận diện link YouTube, shorts, youtu.be, loại bỏ tham số playlist/mix rác.
- [x] **Engine A (Direct)**: Bóc tách trực tiếp trên máy bằng `youtube_explode_dart`.
- [x] **Engine B (Server)**: Kết nối tới Python Flask API (`http://192.168.x.x:5000`).
- [x] **Storage Service**: Quản lý đường dẫn lưu Movies/Music công cộng trên Android.
- [x] **Notification Service**: Cập nhật tiến độ tải nền trên thanh trạng thái Notification.
- [x] **Download Manager**: Quản lý hàng đợi tải, tính tốc độ (MB/s) và tiến độ thời gian thực.
- [x] Commit & Push Phase 2 (`8c8692c`).

### 📌 PHASE 3: Giao diện Người dùng Chính (Core UI Screens)
- [x] **Màn hình Trang chủ (Home Screen)**:
  - Tự động nhận diện URL từ Clipboard khi mở ứng dụng.
  - Thanh nhập URL kiểu kính mờ (Glassmorphism Input) với nút Paste & Clear nhanh.
  - Chuyển đổi linh hoạt giữa Engine Direct và Server Mode.
- [x] **Bảng chọn chất lượng (Format Selector Modal)**:
  - Hiển thị đầy đủ Thumbnail, Thời lượng, Kênh, Tiêu đề.
  - Danh sách video: 1080p Full HD, 720p HD, 480p, 360p kèm pill dung lượng `📦 ... MB`.
  - Danh sách audio: HQ MP3 192kbps & Fast M4A.
- [x] **Màn hình Tiến trình Đang tải (Active Downloads Tab)**:
  - Thẻ tải động với thanh Progress Bar neon phát sáng.
  - Hiển thị % hoàn thành, tốc độ tải tức thì (MB/s), thời gian còn lại (ETA).
- [x] Tích hợp thanh điều hướng Bottom Navigation vào `main.dart`.
- [x] Commit & Push Phase 3 (`5980aa3`).

### 📌 PHASE 4: Thư viện Đã tải & Trình phát Offline (Media Library)
- [x] **Thư viện Media (Downloaded Tab)**:
  - Bộ lọc tabs: Tất cả, Video, Âm thanh.
  - Tìm kiếm file đã tải trực tiếp.
  - Thao tác: Mở bằng ứng dụng ngoài (`open_filex`), Chia sẻ (`share_plus`), Xóa file.
- [x] Commit & Push Phase 4 (`4234789`).

### 📌 PHASE 5: Cài đặt, Phân quyền & Đóng gói Release APK
- [x] **Màn hình Cài đặt (Settings)**:
  - Cấu hình Server IP (mặc định hoặc tự nhập LAN IP của máy tính chạy server Flask).
  - Chọn chế độ Engine mặc định, thông tin phiên bản app.
- [x] Cấu hình quyền `AndroidManifest.xml` (INTERNET, STORAGE, NOTIFICATIONS, usesCleartextTraffic).
- [x] Nâng cấp cấu hình Android Gradle sang Kotlin DSL (`settings.gradle.kts`, `build.gradle.kts`, Gradle 8.10.2, Kotlin 1.9.24).
- [x] Bật `coreLibraryDesugaring` cho `flutter_local_notifications`.
- [x] Biên dịch thành công APK Release: `build/app/outputs/flutter-apk/app-release.apk` (26.8 MB).
- [x] Thiết lập GitHub Actions CI/CD workflow `.github/workflows/release.yml` tự động phát hành bản build APK khi đẩy git tag.
- [x] Commit, tạo tag `v1.0.0` và Push lên Git.

---

## 🔒 NGUYÊN TẮC QUẢN LÝ DỰ ÁN
1. Mọi phase đều được kiểm tra biên dịch không lỗi trước khi commit.
2. Commit message tuân thủ chuẩn Conventional Commits (`feat`, `docs`, `fix`, `refactor`).
3. Push lần lượt từng phase lên repository GitHub `https://github.com/thanhlongts2k/DownloadVideoFromYoutube.git`.
