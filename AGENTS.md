# AGENTS.md — Quy Chuẩn Dành Cho AI Agent (YouTubex Android)

## 🎯 NGUYÊN TẮC CỐT LÕI BẮT BUỘC (MANDATORY CORE DIRECTIVES)

### 1. QUY TRÌNH PHÁT HÀNH TỰ ĐỘNG (AUTO RELEASE & VERSIONING WORKFLOW):
Khi thực hiện fix bug, refactor hoặc thêm tính năng mới, AI Agent **BẮT BUỘC TỰ ĐỘNG THỰC HIỆN TRỌN GÓI** mà không cần dừng lại hỏi xin phép từng bước:
1. **AUTO VERSION BUMP**:
   - Tự động tăng `versionCode` lên +1 trong `pubspec.yaml` (ví dụ: `1.0.2+3` -> `1.0.3+4`).
   - Cập nhật `versionName` theo Semantic Versioning trong `pubspec.yaml` và đồng bộ trong `lib/core/constants/app_config.dart` (`AppConfig.appVersion`).
   - Đảm bảo `android/app/build.gradle.kts` liên kết động qua `flutter.versionCode` và `flutter.versionName`.
2. **AUTO DOCS SYNC**:
   - Tự động thêm mục phiên bản mới lên đầu file `CHANGELOG.md` theo chuẩn "Keep a Changelog" với 3 mục: `[Added]`, `[Changed]`, `[Fixed]`.
   - Cập nhật đồng bộ các mốc hoàn thành trong `PLAN.md` và `README.md`.
3. **VERIFY & TEST GATE**:
   - Chạy `flutter analyze` đạt **0 issues / 0 warnings**.
   - Chạy `flutter test` đảm bảo **100% tests passed**.
4. **AUTO COMMIT, PUSH & BUILD RELEASE**:
   - Tự động commit với message chuẩn Conventional Commits (ví dụ: `fix(...)` hoặc `bump(release): vX.Y.Z`).
   - Tự động tạo git tag tương ứng `vX.Y.Z`.
   - Tự động push code và push tags lên Git remote `origin/main`.
   - Tự động biên dịch APK Release: `flutter build apk --release`.
   - Tự động tạo GitHub Release trên repository `thanhlongts2k/DownloadVideoFromYoutube` và tải tệp APK (`YouTubex-vX.Y.Z.apk`) lên Release Asset.

---

### 2. QUY CHUẨN KỸ THUẬT:
- **Tốc độ tải**: Luôn sử dụng `_yt.videos.streamsClient.get(streamInfo)` của `youtube_explode_dart` cho Engine A để đảm bảo bypass bóp băng thông 12 KB/s và tránh rớt kết nối.
- **Ghép Video**: Sử dụng Android Native `MediaMuxer` ghép MP4 H.264 và AAC `itag 140` trong 0.3s.
- **Cập nhật ứng dụng**: Tệp APK cập nhật phải được lưu vào thư mục có quyền đọc công khai (`StorageService.getDownloadDirectory()`) trước khi gọi `OpenFilex.open()` để tránh lỗi bảo mật đọc cache của Android Package Installer.
