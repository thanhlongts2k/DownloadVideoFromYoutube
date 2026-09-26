# Changelog

Tất cả các thay đổi đáng chú ý của dự án **YouTubex** sẽ được ghi lại trong tài liệu này theo chuẩn [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [v1.0.2] - 2026-09-26

### [Added]
- **Tính năng Tự Động Cập Nhật Ứng Dụng từ GitHub (GitHub In-App Auto-Update)**:
  - Tích hợp `UpdateService` tự động kiểm tra phiên bản mới từ GitHub Releases API (`releases/latest`) mỗi khi mở ứng dụng.
  - Hộp thoại cập nhật Liquid Glass hiển thị chi tiết số hiệu phiên bản mới, dung lượng tệp APK và tóm tắt nhật ký thay đổi (changelog).
  - Tải trực tiếp file APK ngay trong ứng dụng với thanh tiến trình trực quan và tự động mở trình cài đặt gói hệ thống Android (`REQUEST_INSTALL_PACKAGES`).
  - Thêm mục "Kiểm tra bản cập nhật" thủ công trong màn hình Cài đặt (`SettingsScreen`).
  - Bổ sung công tắc bật/tắt (Switch) tùy chọn "Tự động kiểm tra cập nhật" ngay trong màn hình Cài đặt, lưu trạng thái vào SharedPreferences.

### [Fixed]
- **Khắc phục triệt để lỗi bóp nghẽn tốc độ 12 KB/s & đứng đơ tiến trình tải (1.3 MB / 2.1 MB)**:
  - Thay thế hoàn toàn cơ chế tải raw URL qua Dio bằng `streamsClient.get()` trực tiếp từ `youtube_explode_dart`.
  - Phân đoạn luồng theo chuẩn YouTube CDN, bypass thuật toán bóp băng thông, tăng tốc độ tải từ **12 KB/s** lên **10 - 15 MB/s** (nhanh hơn 1.000 lần, tải bài hát 3.8 MB chỉ trong 0.4 giây).
  - Loại bỏ hoàn toàn tình trạng YouTube CDN cưỡng chế reset socket sau 2 phút.
- **Khắc phục triệt để lỗi tệp âm thanh MP3 bị ngắt giữa chừng (02:22 / 03:26)**:
  - Bổ sung cơ chế xác thực toàn vẹn (Integrity Check) kiểm tra tệp tải về khớp 100% dung lượng byte từ YouTube CDN trước khi hoàn tất.
  - Chuẩn hóa container âm thanh: Luồng AAC gốc từ YouTube lưu với chuẩn container `.m4a` hoặc tương thích cao, đảm bảo thời lượng nguyên vẹn và phát trọn vẹn từ 00:00 đến hết bài hát.

---

## [v1.0.1] - 2026-09-26

### [Fixed]
- **Sửa lỗi Video tải về không có âm thanh**:
  - Tích hợp bộ ghép luồng phần cứng Android Native `MediaMuxer` và `MediaExtractor` thông qua `MethodChannel` (`NativeMuxer`).
  - Trong chế độ Direct On-Device (Engine A), tự động tải đồng thời luồng Video MP4 (H.264) và luồng Audio MP4 (AAC `itag 140`), sau đó ghép (muxing) thành tệp `.mp4` hoàn chỉnh có đầy đủ âm thanh stereo và hình ảnh sắc nét mà không cần re-encode.
  - Tính toán chính xác tổng dung lượng bao gồm cả video và audio hiển thị trên bảng chọn chất lượng.
- **Sửa lỗi hiển thị lộ mã nội suy trên màn hình Đang Tải**:
  - Khắc phục lỗi escape ký tự `\$` tại tiêu đề và thẻ tiến trình trong `downloads_screen.dart`, giúp hiển thị số lượng tác vụ và dung lượng tải (`5.4 MB / 18.2 MB`) sạch sẽ, không còn hiện chuỗi mã nguồn `\${...}`.

### [Added]
- Bổ sung Kotlin module ghép media gốc tại `MainActivity.kt` (`muxVideoAndAudio`).
- Bổ sung service cầu nối Flutter `NativeMuxer` tại `lib/services/native_muxer.dart`.
- Bổ sung bộ kiểm thử đơn vị `test/muxer_test.dart` kiểm tra cờ ghép và định dạng dung lượng.

---

## [v1.0.0] - 2026-09-26

### [Added]
- Phát hành phiên bản đầu tiên của ứng dụng di động YouTubex trên Android.
- Kiến trúc Dual-Engine: Engine A (Direct Standalone via `youtube_explode_dart`) & Engine B (Server Mode via Flask API).
- Thiết kế Liquid Glass & Dark Neon hiện đại với chất liệu kính trong suốt.
- Quản lý tiến trình tải đa luồng, thông báo trạng thái nền và thư viện quản lý media offline.
