// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:violet/settings/path.dart';

class Variables {
  static late String applicationDocumentsDirectory;
  static bool databaseDecompressed = false;

  static Future<void> init() async {
    applicationDocumentsDirectory =
        (await DefaultPathProvider.getDocumentsDirectory());
  }

  static double statusBarHeight = 0;
  static double bottomBarHeight = 0;
  static void updatePadding(double statusBar, double bottomBar) {
    if (Platform.isAndroid) {
      if (statusBarHeight == 0 && statusBar > 0.1) {
        statusBarHeight = max(statusBarHeight, statusBar);
      }
      if (bottomBarHeight == 0 && bottomBar > 0.1 && bottomBar < 80) {
        bottomBarHeight = max(bottomBarHeight, bottomBar);
      }
    }
  }

  static double articleInfoHeight = 0;
  static void setArticleInfoHeight(double pad) {
    if (articleInfoHeight == 0 && pad > 0.1) articleInfoHeight = pad;
  }
}
