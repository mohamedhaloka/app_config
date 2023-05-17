part of 'android_app_package_rename.dart';

Future<void> _replaceInFileRegex(String path, regex, replacement) async {
  String? contents = await _readFileAsString(path);
  if (contents == null) {
    log('ERROR:: file at $path not found');
    return;
  }
  contents = contents.replaceAll(RegExp(regex), replacement);
  var file = File(path);
  await file.writeAsString(contents);
}

Future<String?> _readFileAsString(String path) async {
  var file = File(path);
  String? contents;

  if (await file.exists()) {
    contents = await file.readAsString();
  }
  return contents;
}

