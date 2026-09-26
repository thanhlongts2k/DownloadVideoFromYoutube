# 📱 YouTubex — YouTube Video & Audio Downloader for Android

Ứng dụng di động Android cao cấp được thiết kế theo phong cách **Liquid Glassmorphism & Dark Neon**, hỗ trợ phân tích và tải xuống video/audio từ YouTube với đầy đủ các mức độ phân giải và chất lượng âm thanh cao cấp nhất.

---

[![Release](https://img.shields.io/github/v/release/thanhlongts2k/DownloadVideoFromYoutube?color=00F0FF&label=Release&style=for-the-badge)](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/tag/v1.0.3)
[![Download APK](https://img.shields.io/badge/Download-YouTubex%20APK%20(26.8MB)-FF007F?style=for-the-badge&logo=android)](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/download/v1.0.3/YouTubex-v1.0.3.apk)

> 📲 **Tải trực tiếp bản cài đặt Android APK**: [YouTubex-v1.0.3.apk (26.8 MB)](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/download/v1.0.3/YouTubex-v1.0.3.apk)  
> 🏷️ **Xem thông tin bản phát hành trên GitHub**: [GitHub Release v1.0.3](https://github.com/thanhlongts2k/DownloadVideoFromYoutube/releases/tag/v1.0.3)

---


## ✨ TÍNH NĂNG NỔI BẬT

- 🎬 **Đa dạng chất lượng Video**: Tải 1080p (Full HD), 720p (HD), 480p, 360p, 240p, 144p.
- 🎵 **Âm thanh chuẩn HQ**: Hỗ trợ xuất file MP3 CBR 192kbps và file M4A nguyên bản từ YouTube (tải siêu tốc).
- ⚡ **Kiến trúc Dual-Engine**:
  - **Engine A (Direct Standalone)**: Tự bóc tách và tải trực tiếp trên điện thoại không cần máy chủ trung gian.
  - **Engine B (Server Fast Merge)**: Kết nối tới backend Python Flask cục bộ để gộp video 1080p 60fps và xử lý âm thanh bằng FFmpeg.
- 📋 **Nhận diện Thông minh**: Tự động bắt link từ Clipboard khi mở ứng dụng, lọc sạch link rác (loại bỏ tham số playlist, radio mix).
- 📥 **Quản lý Tải về (Download Manager)**: Hiển thị tiến trình trực quan (% hoàn thành, tốc độ tải MB/s, thời gian ước tính ETA), hỗ trợ thông báo nền trên thanh Notification.
- 📂 **Thư viện Media & Trình phát Offline**: Quản lý các file đã tải, phát thử âm thanh/video trực tiếp hoặc chia sẻ sang Zalo, Messenger, Telegram.

---

## 🛠️ CÔNG NGHỆ SỬ DỤNG

- **Framework**: Flutter 3.24+ (Dart 3.5+)
- **Target OS**: Android (Min SDK 21, Target SDK 34)
- **State Management**: Riverpod 2.x
- **Network & Download**: Dio (hỗ trợ chunked streaming & progress callback)
- **YouTube Extractor**: youtube_explode_dart (cho chế độ standalone)
- **Design System**: Liquid Glass, Vibrant Neon Gradients & Shimmer Skeleton Loading
- **Storage & Helpers**: path_provider, permission_handler, lutter_local_notifications, open_filex, share_plus

---

## 🚀 HƯỚNG DẪN CÀI ĐẶT & CHẠY DỰ ÁN

### Yêu cầu môi trường
- Flutter SDK >= 3.24.0
- Java OpenJDK 17
- Android SDK (API 34)

### Các bước thực hiện
`ash
# 1. Cài đặt các dependencies
flutter pub get

# 2. Chạy ứng dụng trên máy ảo hoặc thiết bị thật
flutter run

# 3. Đóng gói file APK Release
flutter build apk --release
`
File APK cài đặt sẽ được sinh ra tại: uild/app/outputs/flutter-apk/app-release.apk.

---

## 📄 GIẤY PHÉP (LICENSE)
Dự án được phát triển và phát hành cho mục đích học tập và nghiên cứu công nghệ.
