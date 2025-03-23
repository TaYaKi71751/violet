// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

const String heroKey = 'articleInfoHero';
const String pageKey = 'artcieInfoPage';

// TODO: expand using optional arguments
Future showArticleInfoById(BuildContext context, int id) async {
  final search = await HentaiManager.idSearch(id.toString());
  if (search.results.isEmpty) {
    return;
  }

  if (!context.mounted) return;
  showArticleInfoRaw(
    context: context,
    queryResult: search.results.first,
  );
}

Future showArticleInfoRaw({
  required BuildContext context,
  required QueryResult queryResult,
  List<QueryResult>? usableTabList,
  bool lockRead = false,
}) async {
  final id = queryResult.id();
  final hasNoValidQuery = queryResult.result.keys.length == 1 &&
      queryResult.result.keys.lastOrNull == 'Id';

  if (hasNoValidQuery) {
    queryResult = await HentaiManager.idQueryWeb('$id');
  }

  final provider = await getImageProvider(queryResult);
  final thumbnail = await provider.getThumbnailUrl();
  final headers = await provider.getHeader(0);

  final isBookmarked =
      await (await Bookmark.getInstance()).isBookmark(queryResult.id());

  if (!context.mounted) return;
  final height = MediaQuery.of(context).size.height;

  var defaultShowHeight = 400;
  if (Platform.isWindows) {
    defaultShowHeight = (height * 0.85).toInt();
  }

  // https://github.com/flutter/flutter/issues/67219
  Provider<ArticleInfo>? cache;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: defaultShowHeight / height,
        minChildSize: 400 / height,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) {
          cache ??= Provider<ArticleInfo>.value(
            value: ArticleInfo.fromArticleInfo(
              queryResult: queryResult,
              thumbnail: thumbnail,
              headers: headers,
              heroKey: heroKey,
              isBookmarked: isBookmarked,
              controller: controller,
              usableTabList: usableTabList,
              lockRead: lockRead,
            ),
            child: const ArticleInfoPage(
              key: ObjectKey(pageKey),
            ),
          );
          return cache!;
        },
      );
    },
  );
}

Future<VioletImageProvider> getImageProviderFromId(int id) async {
  if (ProviderManager.isExists(id)) {
    return await ProviderManager.get(id);
  }

  final query = (await HentaiManager.idSearch(id.toString())).results;
  return getImageProvider(query[0]);
}

Future<VioletImageProvider> getImageProvider(QueryResult queryResult) async {
  final id = queryResult.id();
  if (ProviderManager.isExists(id)) {
    return await ProviderManager.get(id);
  }

  final provider = await HentaiManager.getImageProvider(queryResult);
  await provider.init();
  ProviderManager.insert(id, provider);

  return provider;
}

Future<void> showViewer(BuildContext context, int articleId, int page) async {
  if (Settings.useVioletServer) {
    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      await VioletServer.view(articleId);
    });
  }

  await (await User.getInstance()).insertUserLog(articleId, 0);

  var prov = await ProviderManager.get(articleId);

  await prov.init();

  var headers = await prov.getHeader(0);

  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) {
        return Provider<ViewerPageProvider>.value(
            value: ViewerPageProvider(
              uris: List<String>.filled(prov.length(), ''),
              useProvider: true,
              provider: prov,
              headers: headers,
              id: articleId,
              title: '<No Query>',
              jumpPage: page,
            ),
            child: const ViewerPage());
      },
    ),
  ).then((value) async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
  });
}
