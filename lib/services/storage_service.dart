import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageService {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted) return true;
      if (await Permission.manageExternalStorage.request().isGranted) return true;
      final status = await Permission.videos.request();
      final audioStatus = await Permission.audio.request();
      return status.isGranted || audioStatus.isGranted;
    }
    return true;
  }

  static Future<Directory> getDownloadDirectory({required bool isAudio}) async {
    Directory? baseDir;
    try {
      if (Platform.isAndroid) {
        // Ưu tiên thư mục Download công cộng của Android
        final publicDownload = Directory('/storage/emulated/0/Download/YouTubex');
        if (await publicDownload.exists()) {
          baseDir = publicDownload;
        } else {
          try {
            await publicDownload.create(recursive: true);
            baseDir = publicDownload;
          } catch (_) {
            baseDir = await getExternalStorageDirectory();
          }
        }
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final subFolderName = isAudio ? 'Music' : 'Videos';
    final targetDir = Directory('${baseDir!.path}/$subFolderName');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  static String sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\/:*?"<>|]'), '_').trim();
  }
}
