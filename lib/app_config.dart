import 'dart:io';

import 'dart:async';

import 'package:app_config/android_app_package_rename.dart';
import 'package:app_config/files_path.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:args/args.dart';
import 'package:process_run/process_run.dart';
import 'package:yaml/yaml.dart';

class AppConfig {
  AppConfig._();
  static AppConfig instance = AppConfig._();

  Future<void> startProcess(List<String> args) async {
    final parser = ArgParser()
      ..addOption(
        'fileName',
        abbr: 'f',
      );

    final results = parser.parse(args);

    final String fileName = results["fileName"] ?? 'app_config.yaml';
    final logger = Logger.standard();

    var shell = Shell();

    logger.stdout('Hello!');

    final file = File(fileName);

    if (!(await file.exists())) {
      file.createSync(recursive: true);
      file.writeAsString(_configFileTemplate);
      logger.stdout('File created, please fill file and run command again.');
      return;
    }

    await shell.run('''
# pub get
flutter pub get

// # Update native splash
// flutter pub run flutter_native_splash:create --path=${file.path}
//
// # Update app icons
// flutter pub run flutter_launcher_icons -f $fileName
''');

    final String yamlFileContent = await file.readAsString();
    final doc = loadYaml(yamlFileContent)['app_config'];

    await _changeAppName(logger, doc: doc);
    logger.stdout('Done.');

    await _changeAppPackageName(logger, doc: doc);
    logger.stdout('Done.');

    await _changeBundleIdentifier(logger, doc: doc);
    logger.stdout('Done.');

    logger.stdout('All ${logger.ansi.emphasized('done')}.');
  }

  Future<void> _changeAppName(
    Logger logger, {
    required YamlMap doc,
  }) async {
    final String? newAppName = doc['app_name'];

    if (newAppName == null) return;

    logger.stdout('Change app name in android.');

    await writeParticularFile(
      filePath: "android/app/src/main/AndroidManifest.xml",
      rgxSource: r'android:label=".*"',
      replacement: 'android:label="${newAppName.trim()}"',
    );

    logger.stdout('Change app name in iOS.');

    await _changeAppNameInfoPlist(
      keyName: "CFBundleName",
      replacement: newAppName.trim(),
    );
  }

  Future<void> _changeAppPackageName(
    Logger logger, {
    required YamlMap doc,
  }) async {
    final String? newAppPackageName = doc['package_name'];

    if (newAppPackageName == null) return;

    logger.stdout('Change app package name in android.');

    for (var path in [
      FilesPath.manifestMainPath,
      FilesPath.manifestDebugPath,
      FilesPath.manifestProfilePath
    ]) {
      await writeParticularFile(
        filePath: path,
        rgxSource: r'package=.*>',
        replacement: 'package="${newAppPackageName.trim()}">',
      );
    }

    AndroidRenameSteps(
      newPackageName: newAppPackageName,
    ).updateMainActivity();

    await writeParticularFile(
      filePath: FilesPath.buildGradlePath,
      rgxSource: r'applicationId ".*"',
      replacement: 'applicationId "$newAppPackageName"',
    );
  }

  Future<void> _changeBundleIdentifier(
    Logger logger, {
    required YamlMap doc,
  }) async {
    final String? newBundleIdentifier = doc['bundle_identifier'];

    if (newBundleIdentifier == null) return;

    logger.stdout('Change bundle identifier in iOS.');

    await writeParticularFile(
      filePath: FilesPath.iOSProjectPath,
      rgxSource: r'PRODUCT_BUNDLE_IDENTIFIER = +[\w]+.+[\w]+.+[\w]+;',
      replacement: 'PRODUCT_BUNDLE_IDENTIFIER = $newBundleIdentifier;',
    );
  }

  Future<void> writeParticularFile({
    required String filePath,
    required String rgxSource,
    required String replacement,
  }) async {
    final File file = File(filePath);
    final bool fileIsExists = file.existsSync();

    if (fileIsExists) {
      String fileContent = await file.readAsString();

      RegExp regExp79 = RegExp(rgxSource);
      var matches = regExp79.allMatches(fileContent).toList();

      if (matches.isEmpty) return;
      String matchStr = fileContent.substring(matches[0].start, matches[0].end);

      fileContent = fileContent.replaceAll(matchStr, replacement);
      await file.writeAsString(fileContent);
    }
  }

  Future<void> _changeAppNameInfoPlist({
    required String keyName,
    required String replacement,
  }) async {
    final File file = File(FilesPath.infoPlistPath);
    final bool infoPlistFileExist = file.existsSync();

    if (infoPlistFileExist) {
      const keyOpenTag = '<key>';
      const keyEndTag = '</key>';
      const stringOpenTag = '<string>';
      const stringEndTag = '</string>';

      String fileContent = await file.readAsString();
      final indexOfKey = fileContent.indexOf("$keyOpenTag$keyName$keyEndTag");
      final contentAfterKey = fileContent.substring(
        indexOfKey + "$keyOpenTag$keyName$keyEndTag".length,
      );

      final indexOfFirstStringOpenTag = contentAfterKey.indexOf(stringOpenTag);
      final indexOfFirstStringCloseTag = contentAfterKey.indexOf(stringEndTag);
      final String appPackageName = contentAfterKey.substring(
        indexOfFirstStringOpenTag + 8,
        indexOfFirstStringCloseTag,
      );
      fileContent = fileContent.replaceFirst(
        '$stringOpenTag$appPackageName$stringEndTag',
        '$stringOpenTag$replacement$stringEndTag',
      );

      await file.writeAsString(fileContent);
    }
  }
}

const _configFileTemplate = '''
app_config:
  app_name: ""
  bundle_identifier: ""
  package_name: ""
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icon/icon.png"
flutter_native_splash:
  color: "#42a5f5"
  image: assets/splash.png
''';
