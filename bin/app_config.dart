import 'dart:async';

import 'package:app_config/app_config.dart';

Future<void> main(List<String> args) async {
  AppConfig.instance.startProcess(args);
}
