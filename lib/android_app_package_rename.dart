import 'dart:async';
import 'dart:io';
import 'package:app_config/files_path.dart';
import 'dart:developer';

part 'file_utils.dart';

class AndroidRenameSteps {
  final String newPackageName;
  AndroidRenameSteps({required this.newPackageName});

  Future<void> updateMainActivity() async {
    var path = await _findMainActivity(type: 'java');
    if (path != null) {
      _processMainActivity(path, 'java');
    }

    path = await _findMainActivity(type: 'kotlin');
    if (path != null) {
      _processMainActivity(path, 'kotlin');
    }
  }

  Future<void> _processMainActivity(File path, String type) async {
    var extension = type == 'java' ? 'java' : 'kt';

    await _replaceInFileRegex(
      path.path,
      'package.*',
      "package $newPackageName",
    );

    String newPackagePath = newPackageName.replaceAll('.', '/');
    String newPath = '${FilesPath.activityPath}$type/$newPackagePath';

    await Directory(newPath).create(recursive: true);
    await path.rename('$newPath/MainActivity.$extension');

    await _deleteEmptyDirs(type);
  }

  Future<void> _deleteEmptyDirs(String type) async {
    var dirs =
        Directory(FilesPath.activityPath + type).listSync(recursive: true);
    dirs = dirs.reversed.toList();

    for (var dir in dirs) {
      if (dir is! Directory) return;
      if (dir.listSync().toList().isEmpty) {
        dir.deleteSync();
      }
    }
  }

  Future<File?> _findMainActivity({String type = 'java'}) async {
    var files =
        Directory(FilesPath.activityPath + type).listSync(recursive: true);
    String extension = type == 'java' ? 'java' : 'kt';
    for (var item in files) {
      if (item is File) {
        if (item.path.endsWith('MainActivity.$extension')) {
          return item;
        }
      }
    }
    return null;
  }
}
