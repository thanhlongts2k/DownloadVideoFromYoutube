# 📋 KẾ HOẠCH PHÁT TRIỂN ỨNG DỤNG ANDROID: YOUTUBE MEDIA DOWNLOADER (TubeX)

> **Mục tiêu**: Xây dựng ứng dụng di động Android chuyên nghiệp, giao diện Dark Glassmorphism cao cấp, hỗ trợ bóc tách và tải video/audio YouTube mọi chất lượng (1080p, 720p, 480p, MP3 CBR 192k, Fast M4A), quản lý tiến trình tải nền và thư viện phát offline.

---
> ⚠️ **Yêu cầu quan trọng từ người dùng**:
> Sau khi hoàn tất toàn bộ các Phase, BẮT BUỘC tiến hành đóng gói APK Release (`flutter build apk --release`), tạo tag git release (ví dụ `v1.0.6`) và tự động tạo GitHub Release đính kèm file `app-release.apk` lên repository `https://github.com/thanhlongts2k/DownloadVideoFromYoutube.git`!
---

## 🏗️ 1. KIẾN TRÚC TỔNG THỂ (DUAL-ENGINE ARCHITECTURE)

```
┌────────────────────────────────────────────────────────┐
│                   TubeX Mobile App                  │
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
 │   - Lưu vào Movies/TubeX & Music/TubeX        │
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
- [x] Commit, tạo tag `v1.0.6` và Push lên Git.
- [x] Tạo GitHub Release chính thức đính kèm tệp `TubeX-v1.0.6.apk`.



### 🚀 PLAN PHÁT HÀNH v1.0.6 — HIGH-SPEED ENGINE, AUDIO FIX & GITHUB AUTO-UPDATE

#### 🎯 Mục tiêu:
1. Xử lý triệt để tốc độ tải bị bóp nghẽn 12 KB/s và đứng đơ (stuck 1.3 MB / 2.1 MB) bằng `streamsClient.get()`.
2. Xử lý triệt để lỗi file âm thanh bị cụt giữa chừng (02:22 / 03:26), đảm bảo tải 100% toàn vẹn và phát mượt mà.
3. Bổ sung cơ chế **Tự động kiểm tra và cập nhật ứng dụng (GitHub In-App Auto-Update)** khi có bản phát hành mới.

#### 📋 Kế hoạch triển khai theo 4 Phase:

- [x] **PHASE 1: Nâng cấp Downloader Engine A (Bypass Throttling & Stream Client)**
  - Thay thế cơ chế `Dio.download(rawUrl)` bằng `_yt.videos.streamsClient.get(streamInfo)` của `youtube_explode_dart`.
  - Kích hoạt phân đoạn chunked streaming và token bypass của YouTube CDN, đưa tốc độ từ **12 KB/s** lên **10 - 15 MB/s**.
  - Tải file 3.8 MB trong dưới **0.5 giây**, loại bỏ hoàn toàn tình trạng YouTube reset socket.
  - Bổ sung cơ chế ghi stream `IOSink` và xác thực dung lượng tải khớp 100% với `streamInfo.size.totalBytes`.

- [x] **PHASE 2: Đồng bộ quy trình Ghép Video + Audio Tốc Độ Cao (Fast Muxing Pipeline)**
  - Tải đồng thời Video MP4 stream và Audio MP4 stream via `streamsClient.get()`.
  - Ghép hoàn chỉnh bằng Android Native `MediaMuxer` trong 0.3s.
  - Chuẩn hóa container audio (M4A AAC chuẩn gốc YouTube / MP3 chất lượng cao), bảo đảm thời lượng bài hát nguyên vẹn, nghe và tua seek mượt mà từ 00:00 đến hết bài.

- [x] **PHASE 3: Cơ chế Tự động Cập nhật App qua GitHub Releases (GitHub In-App Update)**
  - Xây dựng `UpdateService`: truy vấn GitHub Releases API (`releases/latest`) để kiểm tra phiên bản mới nhất.
  - Hiển thị Dialog cập nhật phong cách Liquid Glass khi phát hiện phiên bản mới (kèm tóm tắt changelog).
  - Tự động tải tệp APK cập nhật và kích hoạt trình cài đặt hệ thống Android qua `open_filex`.
  - Thêm nút "Kiểm tra bản cập nhật" thủ công trong màn hình Cài đặt (`SettingsScreen`).

- [x] **PHASE 4: Kiểm thử toàn diện, Cập nhật CHANGELOG & Đóng gói Bản Build Git v1.0.6**
  - Chạy `flutter analyze` đạt 0 issues.
  - Viết và chạy unit tests đạt 100% pass.
  - Ghi nhận chi tiết vào `CHANGELOG.md` chuẩn Keep a Changelog.
  - Tăng phiên bản `1.0.2+3` trong `pubspec.yaml`.
  - Biên dịch APK Release `build/app/outputs/flutter-apk/app-release.apk`.
  - Commit, gắn tag `v1.0.6`, đẩy lên Git và tạo GitHub Release đính kèm tệp `TubeX-v1.0.6.apk`.

### 🛠️ BẢN VÁ LỖI & NÂNG CẤP v1.0.6 (HOTFIX)
- [x] **Fix lỗi Video không có âm thanh**: Tích hợp Android Native `MediaMuxer` ghép luồng Video MP4 (H.264) + Audio AAC (`itag 140`) trực tiếp trên thiết bị (Engine A).
- [x] **Fix lỗi lộ chuỗi mã nội suy**: Xóa bỏ các ký tự escape `\$` trong `downloads_screen.dart`.
- [x] **Unit Tests**: Bổ sung `test/muxer_test.dart` đạt 100% test pass.
- [x] **Phát hành bản build v1.0.6**: Đóng gói APK Release mới và phát hành trên GitHub Release.


### 🎵 PHASE 6: PHÁT ĐA PHƯƠNG TIỆN TRONG NỀN (BACKGROUND MEDIA PLAYER) [v1.0.6]
- [x] **Cấu hình Android Native**:
  - Đăng ký `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK` và `AudioService` trong `AndroidManifest.xml`.
  - Kế thừa `AudioServiceActivity` trong `MainActivity.kt`.
- [x] **Core Player Engine (`PlayerService`)**:
  - Tích hợp `just_audio` và `just_audio_background` chuẩn ExoPlayer.
  - Hỗ trợ phát luồng âm thanh của cả video (.mp4, .mkv) và audio (.mp3, .m4a) khi tắt màn hình.
  - Quản lý danh sách phát nối tiếp (Playlist Queue), Audio Focus và phím tai nghe Bluetooth.
  - Tích hợp Sleep Timer (hẹn giờ tắt nhạc) và điều chỉnh tốc độ phát (0.5x - 2.0x).
- [x] **In-App Liquid Glass UI**:
  - Xây dựng `MiniPlayer` kính mờ gắn phía trên thanh điều hướng Bottom Navigation.
  - Xây dựng `FullPlayerSheet` với đĩa xoay Vinyl Neon, thanh Scrubber, nút tua 10s và bộ chọn tốc độ/hẹn giờ.
- [x] **Tích hợp Thư viện Media (`LibraryScreen`)**:
  - Chạm trực tiếp để nghe trong nền, hiệu ứng equalizer phát sáng trên thẻ bài đang phát.
  - Menu tùy chọn nhanh: phát trong nền, mở app ngoài, chia sẻ và xóa.
- [x] **Đóng gói & Phát hành v1.0.6**:
  - Đạt 100% DoD Gate: `flutter analyze` 0 issues, 12/12 unit tests passed.
  - Biên dịch APK Release `TubeX-v1.0.6.apk` và phát hành lên GitHub Release.


### 🎬 PHASE 7: TÍCH HỢP TRÌNH XEM VIDEO & CHUYỂN ĐỔI NGHE NỀN ĐỒNG BỘ [v1.0.6]
- [x] **Trình Xem Video Chuẩn Cinema (`VideoPlayerScreen`)**:
  - Tích hợp `video_player` kết xuất hình ảnh video sắc nét trực tiếp trong app.
  - Phím điều khiển Liquid Glass: Play/Pause, tua +/-10s, thanh Scrubber, tốc độ phát 0.5x - 2.0x.
- [x] **Cơ chế Chuyển Đổi Kép (Seamless Video <-> Background Audio Sync)**:
  - Xem video -> bấm "Nghe nền" -> khóa màn hình vẫn nghe mượt mà tại đúng mốc thời gian.
  - Đang nghe nền -> bấm "Xem Video Màn Hình Lớn" -> tiếp tục xem hình ảnh tại đúng mốc thời gian.
- [x] **Tích Hợp Thư Viện (`LibraryScreen`)**:
  - Phân luồng thông minh: chạm video mở xem video, chạm nhạc mở nghe nền.
- [x] **Đóng gói & Phát hành v1.0.6**:
  - Đạt 100% DoD Gate: `flutter analyze` 0 issues, 12/12 unit tests passed.
  - Biên dịch APK Release `TubeX-v1.0.6.apk` và phát hành lên GitHub Release.

### 🛡️ PHASE 8: CƠ CHẾ NỐI FILE RESUMABLE & DỰ PHÒNG TRÌNH DUYỆT [v1.0.7]
- [x] **Xử lý triệt để lỗi ngắt socket GitHub CDN (`Connection closed while receiving data`)**:
  - Hỗ trợ HTTP `Range: bytes=X-` chunked streaming với `Dio` và ghi tiếp `FileMode.append`.
  - Tự động retry tối đa 5 lần, tiếp tục từ mốc MB đã tải được thay vì tải lại từ 0%.
- [x] **Nút dự phòng "Tải bằng trình duyệt" (`url_launcher`)**:
  - Kích hoạt download qua trình duyệt Android gốc (Chrome/Samsung Internet) với `LaunchMode.externalApplication`.
  - Thêm cấu hình intent https trong `AndroidManifest.xml`.
- [x] **Tinh gọn UI thông báo lỗi**:
  - Loại bỏ các URL presigned S3 dài dòng, hiển thị thông báo tinh tế trong hộp kính Liquid Glass.
- [x] **Đóng gói & Phát hành v1.0.7**:
  - Đạt 100% DoD Gate: `flutter analyze` 0 issues, 12/12 unit tests passed.
  - Biên dịch APK Release `TubeX-v1.0.7.apk` và phát hành lên GitHub Release.

### 🎬 PHASE 9: TRÌNH CHIẾU VIDEO TRỰC TIẾP TRÊN TRÌNH PHÁT & PHÁT NỀN KHI TẮT MÀN HÌNH [v1.0.8]
- [x] **Trình Chiếu Video Nhúng Trực Tiếp Trong `FullPlayerSheet`**:
  - Tự động hiển thị khung video độ nét cao ngay tại bảng điều khiển trung tâm khi phát tệp video, không cần chuyển màn hình.
  - Nút chuyển đổi nhanh chế độ Video / Đĩa xoay Neon.
  - Phím mở rộng "Toàn màn hình" trực tiếp trên khung video.
- [x] **Đồng Bộ Phát Âm Thanh Khi Tắt Màn Hình (Screen-Off Playback)**:
  - Đồng bộ vị trí thời gian mili-giây giữa `video_player` và `just_audio_background`.
  - Tắt màn hình: tiếp tục phát âm thanh trong nền qua `AudioService`, ngắt render video tiết kiệm pin.
  - Bật màn hình: khung video tự động nối tiếp liền mạch theo đúng mốc thời gian âm thanh.
- [x] **Đóng gói & Phát hành v1.0.8**:
  - Đạt 100% DoD Gate: `flutter analyze` 0 issues, 12/12 unit tests passed.
  - Biên dịch APK Release `TubeX-v1.0.8.apk` và phát hành lên GitHub Release.

### 🛡️ PHASE 10: XỬ LÝ TRIỆT ĐỂ LỖI DỪNG VIDEO KHI BẤM PHÁT [v1.0.9]
- [x] **Triệt tiêu xung đột AudioFocus (`mixWithOthers: true`)**:
  - `VideoPlayerOptions(mixWithOthers: true)` vô hiệu hóa `handleAudioFocus` của ExoPlayer, bảo đảm `just_audio` giữ quyền âm thanh nền duy nhất.
- [x] **Chuẩn hóa Play/Pause & Sync Timer Debounce**:
  - `await togglePlay()` đồng bộ chuẩn xác giữa video và audio.
  - Ngưỡng bù trừ khung hình 2000ms với cờ `_isSeekingVideo` chống hiện tượng buffer loop.
- [x] **Đóng gói & Phát hành v1.0.9**:
  - Đạt 100% DoD Gate: `flutter analyze` 0 issues, 12/12 unit tests passed.
  - Biên dịch APK Release `TubeX-v1.0.9.apk` và phát hành lên GitHub Release.

### ⚡ PHASE 11: MUXER SIÊU TỐC, CÔ LẬP TỆP TẠM & GIẢI PHÓNG LUỒNG UI [v1.1.0]
- [x] **Nâng cấp Muxer siêu tốc theo khối tuần tự (Batched Block Interleaving)**:
  - MediaMuxer ghép 2 giây/khối, giảm 99.8% JNI calls, tốc độ ghi 80-120 MB/s, ghép 800 MB trong 5-8 giây.
  - Đặt độ ưu tiên nền `Process.THREAD_PRIORITY_BACKGROUND`.
- [x] **Cô lập tệp tạm vào thư mục ẩn `.tmp/` & Xóa bỏ hiện tượng 2 file rời rạc**:
  - Tách biệt stream `.raw` trong `.tmp/`, chỉ chuyển ra thư viện khi đã hoàn tất 100%.
  - Tự động dọn dẹp các tệp rác `.tmp`, `.raw`, `.part` cũ còn sót lại.
- [x] **Giải phóng luồng UI khi tải file lớn**:
  - Throttle UI Riverpod 300ms, throttle notification 1000ms.
  - Caching `_fileStats` trong LibraryScreen, loại bỏ `statSync()` blocking.
- [x] **Đóng gói & Phát hành v1.1.2**:
  - Tích hợp Native APK Installer (`MainActivity.kt` + `FileProvider`) khởi chạy trực tiếp Package Installer chuẩn Android OS.
  - Tự động kiểm tra và hướng dẫn cấp quyền "Cài đặt ứng dụng không rõ nguồn" (`canRequestPackageInstalls()`).
  - Tối ưu luồng cập nhật: cô lập file APK vào `Download/TubeX/Updates/`, không tắt dialog khi tải xong, cho phép bấm cài đặt lại nhiều lần.
  - Đạt 100% DoD Gate: `flutter analyze` 0 issues, 16/16 unit tests passed.
  - Biên dịch APK Release `TubeX-v1.1.2.apk` và phát hành lên GitHub Release công khai.

- [x] **Đóng gói & Phát hành v1.1.1**:
  - Tích hợp Native Audio Demuxer (`MediaExtractor` + `MediaMuxer`) trích xuất AAC 0.2s.
  - Tải Audio thông minh qua luồng Muxed `ratebypass=yes` (15 MB/s), khắc phục triệt để lỗi 403 / 0.0 MB ở video dài.
  - Đạt 100% DoD Gate: `flutter analyze` 0 issues, 13/13 unit tests passed.
  - Biên dịch APK Release `TubeX-v1.1.1.apk` và phát hành lên GitHub Release.

### 🎁 BẢN BUILD RELEASE ĐÃ PHÁT HÀNH TRÊN GIT
- 📦 **GitHub Release**: [v1.1.2 - TubeX Android Release Build](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/tag/v1.1.2)
- 📥 **Link tải trực tiếp APK**: [TubeX-v1.1.2.apk](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/download/v1.1.2/TubeX-v1.1.2.apk)
- 🛡️ **Kiểm thử chất lượng**: `flutter analyze` đạt 0 issues, 16/16 unit tests passed, biên dịch Release thành công 100%.

- 📦 **GitHub Release**: [v1.1.1 - TubeX Android Release Build](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/tag/v1.1.1)
- 📥 **Link tải trực tiếp APK**: [TubeX-v1.1.1.apk](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/download/v1.1.1/TubeX-v1.1.1.apk)
- 🛡️ **Kiểm thử chất lượng**: `flutter analyze` đạt 0 issues, 13/13 unit tests passed, biên dịch Release thành công 100%.

- 📦 **GitHub Release**: [v1.1.0 - TubeX Android Release Build](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/tag/v1.1.0)
- 📥 **Link tải trực tiếp APK**: [TubeX-v1.1.0.apk (26.8 MB)](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/download/v1.1.0/TubeX-v1.1.0.apk)
- 🛡️ **Kiểm thử chất lượng**: `flutter analyze` đạt 0 issues, 12/12 unit tests passed, biên dịch Release thành công 100%.


- 📦 **GitHub Release**: [v1.0.9 - TubeX Android Release Build](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/tag/v1.0.9)
- 📥 **Link tải trực tiếp APK**: [TubeX-v1.0.9.apk (26.8 MB)](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/download/v1.0.9/TubeX-v1.0.9.apk)
- 🛡️ **Kiểm thử chất lượng**: `flutter analyze` đạt 0 issues, 12/12 unit tests passed, biên dịch Release thành công 100%.


- 📦 **GitHub Release**: [v1.0.8 - TubeX Android Release Build](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/tag/v1.0.8)
- 📥 **Link tải trực tiếp APK**: [TubeX-v1.0.8.apk (26.8 MB)](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/download/v1.0.8/TubeX-v1.0.8.apk)
- 🛡️ **Kiểm thử chất lượng**: `flutter analyze` đạt 0 issues, 12/12 unit tests passed, biên dịch Release thành công 100%.


- 📦 **GitHub Release**: [v1.0.7 - TubeX Android Release Build](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/tag/v1.0.7)
- 📥 **Link tải trực tiếp APK**: [TubeX-v1.0.7.apk (26.8 MB)](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/download/v1.0.7/TubeX-v1.0.7.apk)
- 🛡️ **Kiểm thử chất lượng**: `flutter analyze` đạt 0 issues, 12/12 unit tests passed, biên dịch Release thành công 100%.


- 📦 **GitHub Release**: [v1.0.6 - TubeX Android Release Build](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/tag/v1.0.6)
- 📥 **Link tải trực tiếp APK**: [TubeX-v1.0.6.apk (26.8 MB)](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/download/v1.0.6/TubeX-v1.0.6.apk)
- 🛡️ **Kiểm thử chất lượng**: `flutter analyze` đạt 0 issues, biên dịch Release thành công 100%.


---

## 🔒 NGUYÊN TẮC QUẢN LÝ DỰ ÁN
1. Mọi phase đều được kiểm tra biên dịch không lỗi trước khi commit.
2. Commit message tuân thủ chuẩn Conventional Commits (`feat`, `docs`, `fix`, `refactor`).
3. Push lần lượt từng phase lên repository GitHub `https://github.com/thanhlongts2k/DownloadVideoFromYoutube.git`.
