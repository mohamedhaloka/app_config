import 'dart:io';

import 'dart:async';

import 'package:cli_util/cli_logging.dart';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'fileName',
      abbr: 'f',
    );

  final results = parser.parse(args);
  final String? fileName = results["fileName"];
  final logger = Logger.standard();

  logger.stdout('Hello!');

  final file = File(fileName ?? 'app_config.yaml');

  if (!(await file.exists())) {
    file.createSync(recursive: true);
    file.writeAsString(_configFileTemplate);
    logger.stdout('Run command again.');
    return;
  }
  final String yamlFileContent = await file.readAsString();
  var doc = loadYaml(yamlFileContent);

  final String? newAppName = doc['app_name'];

  if (newAppName == null) return;

  await editFile(
    filePath: "../android/app/src/main/AndroidManifest.xml",
    key: 'android:label="',
    newValue: newAppName,
  );

  final String? newAppPackageName = doc['package_name'];

  if (newAppPackageName == null) return;

  await editFile(
    filePath: "../android/app/src/main/AndroidManifest.xml",
    key: 'package="',
    newValue: newAppPackageName,
  );

  await editFile(
    filePath: "../android/app/build.gradle",
    key: 'applicationId "',
    newValue: newAppPackageName,
  );

  final String? newBundleIdentifier = doc['bundle_identifier'];

  if (newBundleIdentifier == null) return;
  changeBundleIdentifier(
    newBundleIdentifier,
  );

  await changeStringKey(
    keyName: "CFBundleName",
    newValue: newBundleIdentifier,
  );

  logger.stdout('All ${logger.ansi.emphasized('done')}.');
}

Future<void> editFile({
  required String filePath,
  required String key,
  required String newValue,
}) async {
  final File file = File(filePath);
  final bool fileIsExists = file.existsSync();

  if (fileIsExists) {
    String fileContent = await file.readAsString();
    final indexOfAppLabelStr = fileContent.indexOf(key);
    final allFileAfterAppLabel = fileContent.substring(
      indexOfAppLabelStr + key.length,
    );

    final indexOfEndOfAppNameDoubleQuote = allFileAfterAppLabel.indexOf('"');
    final String appPackageName =
        allFileAfterAppLabel.substring(0, indexOfEndOfAppNameDoubleQuote);
    fileContent =
        fileContent.replaceFirst('$key$appPackageName"', '$key$newValue"');
    await file.writeAsString(fileContent);
  }
}

Future<void> changeStringKey({
  required String keyName,
  required String newValue,
}) async {
  final File file = File('../ios/Runner/Info.plist');
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
      '$stringOpenTag$newValue$stringEndTag',
    );

    await file.writeAsString(fileContent);
  }
}

Future<void> changeBundleIdentifier(String newBundleId) async {
  final File file = File('ios/Runner.xcodeproj/project.pbxproj');
  final bool fileIsExist = file.existsSync();

  if (fileIsExist) {
    String fileContent = await file.readAsString();
    RegExp regExp79 =
        RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = +[\w]+.+[\w]+.+[\w]+;');
    var matches = regExp79.allMatches(fileContent).toList();

    String matchStr = fileContent.substring(matches[0].start, matches[0].end);
    fileContent = fileContent.replaceAll(
      matchStr,
      'PRODUCT_BUNDLE_IDENTIFIER = $newBundleId;',
    );
    await file.writeAsString(fileContent);
  }
}

const _configFileTemplate = '''
app_name: ""
bundle_identifier: ""
package_name: ""
''';
