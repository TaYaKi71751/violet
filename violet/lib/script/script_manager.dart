// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
// import 'package:html/parser.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/context/viewer_context.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/script/script_webview.dart';
import 'package:violet/util/helper.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class ScriptManager {
  static const String scriptNoCDNUrl =
      'https://github.com/project-violet/scripts/blob/main/hitomi_get_image_list_v3.js';
  static const String scriptUrl =
      'https://raw.githubusercontent.com/project-violet/scripts/main/hitomi_get_image_list_v3.js';
  static const String scriptV4Url =
      'https://github.com/project-violet/scripts/raw/main/hitomi_get_image_list_v4_model.js';
  static const String enableRefreshV4NoWebViewCheckUrl =
      'https://raw.githubusercontent.com/project-violet/scripts/refs/heads/main/enableRefreshV4NoWebView';
  static bool enableV4 = false;
  static bool enableRefreshV4NoWebView = true;
  static String? v4Cache;
  static String? scriptCache;
  static late JavascriptRuntime runtime;
  static late DateTime latestUpdate;

  // static Future<void> init() async {
  //   Future fallbackFail(Future Function() fn) async {
  //     await catchUnwind(fn, (e, st) async {
  //       await Logger.warning(
  //         '[ScriptManager-init] W: $e\n'
  //         '$st',
  //       );
  //       debugPrint(e.toString());
  //     });
  //   }

  //   await fallbackFail(() async {
  //     final scriptHtml = (await http.get(scriptNoCDNUrl)).body;
  //     scriptCache = json.decode(
  //       parse(
  //         scriptHtml,
  //       ).querySelector("script[data-target='react-app.embeddedData']")!.text,
  //     )['payload']['blob']['rawBlob'];
  //   });

  //   if (scriptCache == null) {
  //     await fallbackFail(() async {
  //       scriptCache = (await http.get(scriptUrl)).body;
  //     });
  //   }

  //   await fallbackFail(() async {
  //     v4Cache = (await http.get(scriptV4Url)).body;
  //   });

  //   await fallbackFail(() async {
  //     final check = (await http.get(enableRefreshV4NoWebViewCheckUrl)).body;
  //     enableRefreshV4NoWebView = int.parse(check) == 1;
  //     if (enableRefreshV4NoWebView) {
  //       await refreshV4NoWebView();
  //     }
  //   });

  //   await fallbackFail(() async {
  //     initRuntime();
  //   });
  // }

  static Future<void> refresh() async {
    // 1. (V4) NoWebView가 활성화되어 있다면 해당 방법으로 refresh 시도, 아니라면 webview로 시도
    if (enableRefreshV4NoWebView) {
      if (await refreshV4NoWebView()) {
        return;
      }
    } else if (enableV4 && ScriptWebViewProxy.reload != null) {
      /// proxy may be calling `refreshV4` function
      ScriptWebViewProxy.reload!();
      return;
    }

    // 2. (V3) V4 disable 상태이거나 no web-view가 실패한다면 V3로 fallback한다
    // 너무 잦은 refresh try를 방지하기 위해 많아도 5분에 한 번씩만 실행되게 끔 설정
    if (DateTime.now().difference(latestUpdate).inMinutes < 5) {
      return;
    }

    await refreshV3();
  }

  static Future<void> refreshV3() async {
    final scriptTemp = (await http.get(scriptUrl)).body;
    replaceScriptCacheIfRequired(scriptTemp);
  }

  static Future<bool> refreshV4NoWebView() async {
    var success = false;
    await catchUnwind(
      () async {
        final ggBody = (await http.get(
          'https://ltn.gold-usergeneratedcontent.net/gg.js',
        )).body;
        final ggRuntime = getJavascriptRuntime();
        // TODO: 이유는 잘 모르겠으나 use strict를 삭제하지 않으면 gg instance를 찾을 수 없어서 실패함
        ggRuntime.evaluate(ggBody.split("'use strict';")[1]);
        final gg = ggRuntime.evaluate('''
              var r = "";
              for (var i = 0; i < 4096; i++) {
                r += gg.m(i).toString();
                r += ",";
              }
              r + '|' + gg.b
              ''').stringResult;
        await refreshV4(gg.split('|')[0], gg.split('|')[1]);
        success = true;
      },
      (e, st) async {
        await Logger.warning(
          '[ScriptManager-refreshV4NoWebView] W: $e\n'
          '$st',
        );
        debugPrint(e.toString());
      },
    );
    return success;
  }

  /// this function may be called by `ScriptWebView`
  static Future<void> refreshV4(String ggM, String ggB) async {
    enableV4 = true;
    v4Cache ??= (await http.get(scriptV4Url)).body;
    final scriptTemp = v4Cache!
        .replaceAll('%%gg.m%', ggM)
        .replaceAll('%%gg.b%', ggB);
    replaceScriptCacheIfRequired(scriptTemp);
  }

  static void replaceScriptCacheIfRequired(String scriptTemp) {
    if (scriptCache == scriptTemp) {
      return;
    }

    scriptCache = scriptTemp;
    initRuntime();
    ProviderManager.checkMustRefresh();
    ViewerContext.signal((c) => c.refreshImgUrlWhenRequired());
    Logger.info('[Script Manager] Update Sync!');
  }

  static void initRuntime() {
    latestUpdate = DateTime.now();
    runtime = getJavascriptRuntime();
    runtime.evaluate(scriptCache!);
  }

  static Future<String?> getGalleryInfoRaw(String id) async {
    final downloadUrl =
        'http://ltn.gold-usergeneratedcontent.net/galleries/$id.js';
    final headers = await runHitomiGetHeaderContent(id.toString());
    final galleryInfo = await http.get(downloadUrl, headers: headers);
    if (galleryInfo.statusCode != 200) return null;
    return galleryInfo.body;
  }

  static Future<ImageList?> runHitomiGetImageList(int id) async {
    try {
      final imageUrls = await HitomiImageResolver.getImages(id);
      final bigThumbnailUrls = await HitomiImageResolver.getBigThumbnailUrls(
        id,
      );
      final smallThumbnailUrls =
          await HitomiImageResolver.getSmallThumbnailUrls(id);
      return ImageList(
        urls: imageUrls,
        bigThumbnails: bigThumbnailUrls,
        smallThumbnails: smallThumbnailUrls,
      );
    } catch (e, st) {
      Logger.error(
        '[script-HitomiGetImageList] E: $e\n'
        'Id: $id\n'
        '$st',
      );
      return null;
    }
  }

  static Future<Map<String, String>> runHitomiGetHeaderContent(
    String id,
  ) async {
    try {
      final jResult = '''
      {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:150.0) Gecko/20100101 Firefox/150.0",
        "Accept": "image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5",
        "Accept-Language": "en-US",
        "Referer": "https://hitomi.la/",
        "Sec-Fetch-Dest": "image",
        "Sec-Fetch-Mode": "no-cors",
        "Sec-Fetch-Site": "cross-site",
        "Priority": "u=4, i"
    }
      ''';
      final jResultObject = jsonDecode(jResult);

      if (jResultObject is Map<dynamic, dynamic>) {
        return Map<String, String>.from(jResultObject);
      } else {
        throw Exception(
          '[script-HitomiGetHeaderContent] E: JSError\n'
          'Id: $id\n'
          'Message: $jResult',
        );
      }
    } catch (e, st) {
      Logger.error(
        '[script-HitomiGetHeaderContent] E: $e\n'
        'Id: $id\n'
        '$st',
      );
      rethrow;
    }
  }
}

/// 히토미 최신 라우팅(a1, a2 서버 및 AVIF/Webp)을 완벽 지원하는 리졸버
class HitomiImageResolver {
  // Credits to https://discord.com/users/1407344738750824459
  static const String baseDomain = 'gold-usergeneratedcontent.net';

  static Future<List<String>> getImages(
    int galleryId, {
    bool useAvif = true,
  }) async {
    try {
      // 1. gg.js 해석 (완벽한 mList 추출 로직 적용)
      final ggResponse = await http.get('https://ltn.$baseDomain/gg.js');
      if (ggResponse.statusCode != 200) return [];
      final ggText = ggResponse.body;

      final bMatch = RegExp(r"b:\s*'([^']+)'").firstMatch(ggText);
      final bValue = bMatch?.group(1) ?? "";

      final mList = RegExp(
        r"case (\d+):",
      ).allMatches(ggText).map((m) => m.group(1)!).toList();

      int o1 = 0;
      int o2 = 1;
      final oMatches = RegExp(r"o = (\d+)").allMatches(ggText);
      if (oMatches.isNotEmpty) {
        o1 = int.parse(oMatches.first.group(1) ?? "0");
        o2 = int.parse(oMatches.last.group(1) ?? "1");
      }

      // 2. 갤러리 메타데이터 로드
      final galResponse = await http.get(
        'https://ltn.$baseDomain/galleries/$galleryId.js',
      );
      if (galResponse.statusCode != 200) return [];

      String content = galResponse.body.replaceFirst('var galleryinfo = ', '');
      final Map<String, dynamic> data = json.decode(content);
      final List<dynamic> files = data['files'] ?? [];

      // 3. 최신 공식 기반 URL 조립
      List<String> imageUrls = [];
      String domain = useAvif ? 'a' : 'w';
      String ext = useAvif ? 'avif' : 'webp';

      for (var file in files) {
        final String hash = file['hash'];
        if (hash.isEmpty) continue;

        // [핵심] 해시 문자 재조합 (끝 1글자 + 끝에서 3, 2번째 글자)
        var part =
            hash[hash.length - 1] +
            hash[hash.length - 3] +
            hash[hash.length - 2];
        String s = int.parse(part, radix: 16).toString(); // 16진수 -> 10진수

        // 서버 라우팅 계산 (a1 or a2)
        bool isModern = mList.contains(s);
        int node = isModern ? o2 : o1;
        int serverNum = node + 1;

        // 최종 주소 완성 (ex: https://a1.gold.../1775551322/3988/hash.avif)
        final finalUrl =
            'https://$domain$serverNum.$baseDomain/$bValue$s/$hash.$ext';
        imageUrls.add(finalUrl);
      }

      return imageUrls;
    } catch (e) {
      print('[Hitomi Resolver] 에러: $e');
      return [];
    }
  }

  static Future<List<String>> getBigThumbnailUrls(
    int galleryId, {
    bool useAvif = true,
  }) async {
    try {
      final ggResponse = await http.get('https://ltn.$baseDomain/gg.js');
      if (ggResponse.statusCode != 200) return [];
      final ggText = ggResponse.body;

      final mList = RegExp(
        r"case (\d+):",
      ).allMatches(ggText).map((m) => m.group(1)!).toList();

      int o1 = 0;
      int o2 = 1;
      final oMatches = RegExp(r"o = (\d+)").allMatches(ggText);
      if (oMatches.isNotEmpty) {
        o1 = int.parse(oMatches.first.group(1) ?? "0");
        o2 = int.parse(oMatches.last.group(1) ?? "1");
      }
      final galResponse = await http.get(
        'https://ltn.$baseDomain/galleries/$galleryId.js',
      );
      if (galResponse.statusCode != 200) return [];
      String content = galResponse.body.replaceFirst('var galleryinfo = ', '');
      final Map<String, dynamic> data = json.decode(content);
      final List<dynamic> files = data['files'] ?? [];
      List<String> thumbUrls = [];
      String firstPath = useAvif ? 'avifbigtn' : 'webpbigtn';
      for (var file in files) {
        final String hash = file['hash'];
        if (hash.isEmpty) continue;
        var part =
            hash[hash.length - 1] +
            hash[hash.length - 3] +
            hash[hash.length - 2];
        String s = int.parse(part, radix: 16).toString(); // 16진수 -> 10진수

        // 서버 라우팅 계산 (a1 or a2)
        bool isModern = mList.contains(s);
        int node = isModern ? o2 : o1;
        int serverNum = node + 1;
        String domain = serverNum == 1 ? 'atn' : 'btn';
        String secondPath = hash.substring(hash.length - 1, hash.length);
        String thirdPath = hash.substring(hash.length - 3, hash.length - 1);
        String ext = useAvif ? 'avif' : 'webp';
        final thumbUrl =
            'https://$domain.$baseDomain/$firstPath/$secondPath/$thirdPath/$hash.$ext';
        thumbUrls.add(thumbUrl);
      }
      return thumbUrls;
    } catch (e) {
      print('[Hitomi Resolver] 에러: $e');
      return [];
    }
  }

  static Future<List<String>> getSmallThumbnailUrls(
    int galleryId, {
    bool useAvif = true,
  }) async {
    try {
      // 1. gg.js 해석 (완벽한 mList 추출 로직 적용)
      final ggResponse = await http.get('https://ltn.$baseDomain/gg.js');
      if (ggResponse.statusCode != 200) return [];
      final ggText = ggResponse.body;

      final mList = RegExp(
        r"case (\d+):",
      ).allMatches(ggText).map((m) => m.group(1)!).toList();

      int o1 = 0;
      int o2 = 1;
      final oMatches = RegExp(r"o = (\d+)").allMatches(ggText);
      if (oMatches.isNotEmpty) {
        o1 = int.parse(oMatches.first.group(1) ?? "0");
        o2 = int.parse(oMatches.last.group(1) ?? "1");
      }

      final galResponse = await http.get(
        'https://ltn.$baseDomain/galleries/$galleryId.js',
      );
      if (galResponse.statusCode != 200) return [];
      String content = galResponse.body.replaceFirst('var galleryinfo = ', '');
      final Map<String, dynamic> data = json.decode(content);
      final List<dynamic> files = data['files'] ?? [];
      List<String> thumbUrls = [];
      String firstPath = useAvif ? 'avifsmallsmalltn' : 'webpsmalltn';
      for (var file in files) {
        final String hash = file['hash'];
        if (hash.isEmpty) continue;
        var part =
            hash[hash.length - 1] +
            hash[hash.length - 3] +
            hash[hash.length - 2];
        String s = int.parse(part, radix: 16).toString(); // 16진수 -> 10진수

        // 서버 라우팅 계산 (a1 or a2)
        bool isModern = mList.contains(s);
        int node = isModern ? o2 : o1;
        int serverNum = node + 1;
        String domain = serverNum == 1 ? 'atn' : 'btn';

        // 최종 주소 완성 (ex: https://a1.gold.../1775551322/3988/hash.avif)
        String secondPath = hash.substring(hash.length - 1, hash.length);
        String thirdPath = hash.substring(hash.length - 3, hash.length - 1);
        String ext = useAvif ? 'avif' : 'webp';
        final thumbUrl =
            'https://$domain.$baseDomain/$firstPath/$secondPath/$thirdPath/$hash.$ext';
        thumbUrls.add(thumbUrl);
      }
      return thumbUrls;
    } catch (e) {
      print('[Hitomi Resolver] 에러: $e');
      return [];
    }
  }
}
