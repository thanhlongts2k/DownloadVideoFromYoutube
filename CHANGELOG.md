# Changelog

Tất cả các thay đổi đáng chú ý của dự án **YouTubex** sẽ được ghi lại trong tài liệu này theo chuẩn [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
