// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

// ignore_for_file: unnecessary_string_escapes

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/script/script_manager.dart';

/*
for linux

git clone https://github.com/abner/quickjs-c-bridge
cd quickjs-c-bridge
cmake -S ./linux -B ./build/linux
cmake --build build/linux
sudo cp build/linux/libquickjs_c_bridge_plugin.so /usr/lib/libquickjs_c_bridge_plugin.so
*/
void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // await ScriptManager.init();
  });

  test('Refresh by V4 NoWebView', () async {
    ScriptManager.enableRefreshV4NoWebView = true;
    expect(await ScriptManager.refreshV4NoWebView(), true);
  });

  test('Get Gallery Info Raw', () async {
    // https://ltn.gold-usergeneratedcontent.net/galleries/1234567.js
    final raw = await ScriptManager.getGalleryInfoRaw('1234567');
    expect(raw != null, true);
  });

  test('Get Image List', () async {
    // https://ltn.gold-usergeneratedcontent.net/galleries/1234567.js
    final list = await ScriptManager.runHitomiGetImageList(1234567);
    expect(list != null, true);
  });

  test('Get Header Contents', () async {
    // https://ltn.gold-usergeneratedcontent.net/galleries/1234567.js
    final headers = await ScriptManager.runHitomiGetHeaderContent('1234567');
    expect(headers.isNotEmpty, true);
  });
}
