// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/log/log.dart';
import 'package:violet/platform/android_external_storage_directory.dart';
import 'package:violet/settings/device_type.dart';

class Settings {
  static late final SharedPreferences prefs;

  // Bookmark Git Settings
  static final bookmarkRepository =
      SettingItem<String>('bookmarkRepository', 'example/bookmark');
  static final bookmarkHost = SettingItem<String>('bookmarkHost', 'gitee.com');

  // Timeout Settings
  static final ignoreTimeout = SettingItem<bool>('ignoreTimeout', false);

  // Color Settings
  static Color get themeColor => themeWhat.value ? Colors.white : Colors.black;
  static final themeWhat = SettingItem<bool>('themeColor', false);
  static final majorColor = SettingItem<Color>('majorColor', Colors.purple);
  static final majorAccentColor =
      SettingItem<Color>('majorAccentColor', Colors.purpleAccent);
  static final searchResultType = EnumSettingItem<SearchResultType>(
      'searchResultType', SearchResultType.values, SearchResultType.ultra);
  static final downloadResultType = EnumSettingItem<DownloadResultType>(
      'downloadResultType',
      DownloadResultType.values,
      DownloadResultType.detail);
  static final downloadAlignType = SettingItem<int>('downloadAlignType', 0);
  static final themeFlat = SettingItem<bool>('themeFlat', false);
  static final themeBlack = SettingItem<bool>('themeBlack', false);
  static final useTabletMode = SettingItem<bool>('usetabletmode', false);

  // Tag Settings
  static final includeTags = SettingItem<String>('includetags', () {
    final langcode = Platform.localeName.split('_')[0];
    var language = 'lang:english';
    if (langcode == 'ko') {
      language = 'lang:korean';
    } else if (langcode == 'ja') {
      language = 'lang:japanese';
    } else if (langcode.startsWith('zh')) {
      language = 'lang:chinese';
    }
    return '($language)';
  }());
  static final excludeTags = SettingItem<List<String>>('excludetags', []);
  static final blurredTags = SettingItem<List<String>>('blurredtags', []);
  static final language = SettingItem<String>('language', '');
  static final translateTags = SettingItem<bool>('translatetags', false);

  static String get serializedExcludeTags => Settings.excludeTags.value
      .where((e) => e.trim() != '')
      .map((e) => '-$e')
      .join(' ')
      .trim();

  // Like this Hitomi.la => e-hentai => exhentai => nhentai
  static late List<String> routingRule; // image routing rule
  static late List<String> searchRule;
  static final searchNetwork = SettingItem<bool>('searchNetwork', false);
  static final includeTagNetwork =
      SettingItem<bool>('includeTagNetwork', false);
  static final excludeTagNetwork =
      SettingItem<bool>('excludeTagNetwork', false);
  static final searchExpunged = SettingItem<bool>('searchExpunged', false);
  static final searchCategory = SettingItem<int>('searchCategory', 993);

  // Global? English? Korean?
  static final databaseType = SettingItem<String>('databasetype', () {
    final langcode = Platform.localeName.split('_')[0];
    final acclc = ['ko', 'ja', 'en', 'ru', 'zh'];

    if (!acclc.contains(langcode)) return 'global';

    return langcode;
  }());

  // Reader Option
  static final rightToLeft = SettingItem<bool>('rightToLeft', true);
  static final isHorizontal = SettingItem<bool>('ishorizontal', false);
  static final scrollVertical = SettingItem<bool>('scrollvertical', false);
  static final animation = SettingItem<bool>('animation', false);
  static final padding = SettingItem<bool>('padding', false);
  static final disableOverlayButton =
      SettingItem<bool>('disableoverlaybutton', false);
  static final disableFullScreen =
      SettingItem<bool>('disablefullscreen', false);
  static final enableTimer = SettingItem<bool>('enabletimer', false);
  static final timerTick = SettingItem<double>('timertick', 1.0);
  static final disableTwoPageView =
      SettingItem<bool>('disableTwoPageView', false);
  static final secondPageToSecondPage =
      SettingItem<bool>('secondPageToSecondPage', false);
  static final moveToAppBarToBottom =
      SettingItem<bool>('movetoappbartobottom', Platform.isIOS);
  static final showSlider = SettingItem<bool>('showslider', false);
  static final imageQuality = SettingItem<int>('imagequality', 3);
  static final thumbSize = SettingItem<int>('thumbSize', 1);
  static final enableThumbSlider =
      SettingItem<bool>('enableThumbSlider', false);
  static final showPageNumberIndicator =
      SettingItem<bool>('showPageNumberIndicator', true);
  static final showRecordJumpMessage =
      SettingItem<bool>('showRecordJumpMessage', true);

  // Download Options
  static final threadCount = SettingItem<int>('thread_count', 4);

  static final useInnerStorage =
      FutureSettingItem<bool>('useinnerstorage', () async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 30;
    }
    return Platform.isIOS;
  });
  static final downloadBasePath =
      FutureSettingItem<String>('downloadbasepath', () async {
    if (Platform.isAndroid) {
      final String path = await AndroidExternalStorageDirectory.instance
          .getExternalStorageDirectory();
      var downloadBasePath = join(path, '.violet');

      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 30 && prefs.getBool('android30downpath') == null) {
        await prefs.setBool('android30downpath', true);
        var ext = await getExternalStorageDirectory();
        downloadBasePath = ext!.path;
      } else if (sdkInt < 30 &&
          downloadBasePath == join(path, 'Violet') &&
          prefs.getBool('downloadbasepathcc1') == null) {
        downloadBasePath = join(path, '.violet');
        await prefs.setBool('downloadbasepathcc1', true);

        try {
          if (await Permission.manageExternalStorage.isGranted) {
            var prevDir = Directory(join(path, 'Violet'));
            if (await prevDir.exists()) {
              await prevDir.rename(join(path, '.violet'));
            }

            var downloaded =
                await (await Download.getInstance()).getDownloadItems();
            for (var download in downloaded) {
              Map<String, dynamic> result =
                  Map<String, dynamic>.from(download.result);
              if (download.files() != null) {
                result['Files'] =
                    download.files()!.replaceAll('/Violet/', '/.violet/');
              }
              if (download.path() != null) {
                result['Path'] =
                    download.path()!.replaceAll('/Violet/', '/.violet/');
              }
              download.result = result;
              await download.update();
            }
          }
        } catch (e, st) {
          Logger.error('[Settings] E: $e\n'
              '$st');
          FirebaseCrashlytics.instance.recordError(e, st);
        }
      }
      return downloadBasePath;
    } else if (Platform.isIOS) {
      return 'not supported';
    } else {
      // Desktop
      return join(dirname(Platform.resolvedExecutable), 'download');
    }
  });
  static final downloadRule = SettingItem<String>(
      'downloadrule', '%(extractor)s/%(id)s/%(file)s.%(ext)s');

  static final searchMessageAPI = SettingItem<String>(
      'searchmessageapi', 'https://koromo.xyz/api/search/msg');
  static final useVioletServer = SettingItem<bool>('usevioletserver', false);

  static final useDrawer = SettingItem<bool>('usedrawer', false);

  static final useOptimizeDatabase =
      SettingItem<bool>('useoptimizedatabase', true);

  static final useLowPerf = SettingItem<bool>('uselowperf', true);

  // View Option
  static final showArticleProgress =
      SettingItem<bool>('showarticleprogress', false);

  // Search Option
  static final searchUseFuzzy = SettingItem<bool>('searchusefuzzy', false);
  static final searchTagTranslation =
      SettingItem<bool>('searchtagtranslation', false);
  static final searchUseTranslated =
      SettingItem<bool>('searchusetranslated', false);
  static final searchShowCount = SettingItem<bool>('searchshowcount', true);
  static final searchPure = SettingItem<bool>('searchPure', false);

  static late String userAppId;

  static final autobackupBookmark =
      SettingItem<bool>('autobackupbookmark', false);

  // Crop Bookmark
  static final cropBookmarkAlign =
      SettingItem<int>('cropBookmarkAlign', Device.get().isTablet ? 3 : 2);
  static final cropBookmarkShowOverlay =
      SettingItem<bool>('cropBookmarkShowOverlay', true);
  static final cropBookmarkSortDesc =
      SettingItem<bool>('cropBookmarkSortDesc', false);

  // Lab
  static final simpleItemWidgetLoadingIcon =
      SettingItem<bool>('simpleItemWidgetLoadingIcon', true);
  static final showNewViewerWhenArtistArticleListItemTap =
      SettingItem<bool>('showNewViewerWhenArtistArticleListItemTap', true);
  static final enableViewerFunctionBackdropFilter =
      SettingItem<bool>('enableViewerFunctionBackdropFilter', true);
  static final usingPushReplacementOnArticleRead =
      SettingItem<bool>('usingPushReplacementOnArticleRead', true);
  static final downloadEhRawImage =
      SettingItem<bool>('downloadEhRawImage', false);
  static final bookmarkScrollbarPositionToLeft =
      SettingItem<bool>('bookmarkScrollbarPositionToLeft', false);
  static final inViewerMessageSearch =
      SettingItem<bool>('inViewerMessageSearch', false);

  static final useLockScreen = SettingItem<bool>('useLockScreen', false);
  static final useSecureMode = SettingItem<bool>('useSecureMode', false);

  static Future<void> initFirst() async {
    prefs = await SharedPreferences.getInstance();

    await setSecureMode();
  }

  static Future<void> setSecureMode() async {
    if (Platform.isAndroid) {
      if (Settings.useSecureMode.value) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
    }
  }

  static Future<void> init() async {
    routingRule = (await _getString(
            'routingrule', 'Hitomi|EHentai|ExHentai|Hiyobi|NHentai'))
        .split('|');
    searchRule =
        (await _getString('searchrule', 'Hitomi|EHentai|ExHentai|NHentai'))
            .split('|');

    if (!routingRule.contains('Hiyobi')) {
      routingRule.add('Hiyobi');
      await prefs.setString('routingrule', routingRule.join('|'));
    }

    await useInnerStorage.load();
    await downloadBasePath.load();

    // main에서 셋팅됨
    if (Platform.isAndroid || Platform.isIOS) {
      userAppId = prefs.getString('fa_userid')!;
    } else {
      userAppId = 'null';
    }

    await regacy1_20_2();
  }

  static Future resetIncludeTags() async {
    var language = 'lang:english';
    var langcode = Settings.language.value;
    if (langcode == 'ko') {
      language = 'lang:korean';
    } else if (langcode == 'ja') {
      language = 'lang:japanese';
    } else if (langcode.startsWith('zh')) {
      language = 'lang:chinese';
    }
    await includeTags.setValue('($language)');
  }

  static Future regacy1_20_2() async {
    if (await _checkLegacyExists('regacy1_20_2')) return;

    if (!simpleItemWidgetLoadingIcon.value) {
      await simpleItemWidgetLoadingIcon.setValue(true);
    }
    if (!showNewViewerWhenArtistArticleListItemTap.value) {
      await showNewViewerWhenArtistArticleListItemTap.setValue(true);
    }
  }

  static Future<bool> _checkLegacyExists(String name) async {
    var nn = prefs.getBool(name);
    if (nn == null) {
      await prefs.setBool(name, true);
      return false;
    }
    return true;
  }

  static Future<String> _getString(String key,
      [String defaultValue = '']) async {
    var nn = prefs.getString(key);
    if (nn == null) {
      nn = defaultValue;
      await prefs.setString(key, nn);
    }
    return nn;
  }

  static Future<String> getDefaultDownloadPath() async {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    var sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      var ext = await getExternalStorageDirectory();
      return ext!.path;
    }

    return downloadBasePath.value;
  }

  static Future<void> setMajorColor(Color color) async {
    if (majorColor.value == color) return;

    await majorColor.setValue(color);

    Color? accent;
    for (int i = 0; i < Colors.primaries.length - 2; i++) {
      if (color.value == Colors.primaries[i].value) {
        accent = Colors.accents[i];
        break;
      }
    }

    if (accent == null) {
      if (color == Colors.grey) {
        accent = Colors.grey.shade700;
      } else if (color == Colors.brown) {
        accent = Colors.brown.shade700;
      } else if (color == Colors.blueGrey) {
        accent = Colors.blueGrey.shade700;
      } else if (color == Colors.black) {
        accent = Colors.black;
      }
    }

    await majorAccentColor.setValue(accent!);
  }
}

class SettingItem<T> {
  final String key;
  final T defaultValue;
  T? _value;

  SettingItem(this.key, this.defaultValue) {
    load();
  }

  T get value => _value!;
  Future<void> setValue(T v) async {
    _value = v;
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      await saveToPrefs(key, v);
    }
  }

  void load() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _value = loadFromPrefs<T>(key, defaultValue);
    }
  }

  @override
  String toString() {
    throw UnsupportedError('donot support toString()');
  }
}

class FutureSettingItem<T> {
  final String key;
  final Future<T> Function() computeDefault;
  T? _value;
  bool _initialized = false;

  FutureSettingItem(this.key, this.computeDefault);

  T get value {
    if (!_initialized) {
      throw StateError(
          'FutureSettingItem<$T> not initialized. Call `load()` first.');
    }
    return _value!;
  }

  Future<void> setValue(T v) async {
    _value = v;
    await saveToPrefs(key, v);
  }

  Future<void> load() async {
    _value = loadFromPrefs<T>(key, null);
    if (_value == null) {
      _value = await computeDefault();
      await saveToPrefs<T>(key, _value! as T);
    }
    _initialized = true;
  }

  @override
  String toString() {
    throw UnsupportedError('donot support toString()');
  }
}

T? loadFromPrefs<T>(String key, T? fallback) {
  final prefs = Settings.prefs;
  if (T == bool) return prefs.getBool(key) as T? ?? fallback;
  if (T == int) return prefs.getInt(key) as T? ?? fallback;
  if (T == double) return prefs.getDouble(key) as T? ?? fallback;
  if (T == String) return prefs.getString(key) as T? ?? fallback;
  if (T == Color) {
    final val = prefs.getInt(key);
    return (val != null ? Color(val) : fallback) as T?;
  }
  if (T == List<String>) {
    final val = prefs.getString(key);
    return (val != null ? val.split('|') : fallback) as T?;
  }
  throw Exception('Unsupported type');
}

Future<void> saveToPrefs<T>(String key, T value) async {
  final prefs = Settings.prefs;
  if (value is bool) {
    await prefs.setBool(key, value);
  } else if (value is int) {
    await prefs.setInt(key, value);
  } else if (value is double) {
    await prefs.setDouble(key, value);
  } else if (value is String) {
    await prefs.setString(key, value);
  } else if (value is Color) {
    await prefs.setInt(key, value.value);
  } else if (value is List<String>) {
    await prefs.setString(key, value.join('|'));
  } else {
    throw Exception('Unsupported type');
  }
}

class EnumSettingItem<T extends Enum> {
  final String key;
  final List<T> values;
  final T defaultValue;
  T? _value;

  EnumSettingItem(this.key, this.values, this.defaultValue) {
    load();
  }

  T get value => _value ?? defaultValue;
  Future<void> setValue(T v) async {
    _value = v;
    await Settings.prefs.setInt(key, values.indexOf(v));
  }

  void load() {
    int index = Settings.prefs.getInt(key) ?? values.indexOf(defaultValue);
    _value = values[index];
  }
}

enum SearchResultType {
  threeGrid,
  twoGrid,
  bigLine,
  detail,
  ultra,
}

extension SearchResultTypeExtension on SearchResultType {
  bool get isUltra {
    return this == SearchResultType.ultra;
  }

  bool get isDetailLike {
    switch (this) {
      case SearchResultType.detail:
      case SearchResultType.ultra:
        return true;

      default:
        return false;
    }
  }

  bool get isGridLike {
    switch (this) {
      case SearchResultType.threeGrid:
      case SearchResultType.twoGrid:
        return true;

      default:
        return false;
    }
  }
}

enum DownloadResultType {
  threeGrid,
  twoGrid,
  bigLine,
  detail,
}

extension DownloadResultTypeExtension on DownloadResultType {
  bool get isThreeGrid => this == DownloadResultType.threeGrid;
  bool get isDetail => this == DownloadResultType.detail;

  bool get isGridLike {
    switch (this) {
      case DownloadResultType.threeGrid:
      case DownloadResultType.twoGrid:
        return true;

      default:
        return false;
    }
  }
}
