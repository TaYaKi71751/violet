// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/index.dart';
import 'package:violet/component/query_translate.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/three_article_panel.dart';
import 'package:violet/settings/settings.dart';

class SimilarListPage extends StatelessWidget {
  final ArtistType type;
  final List<(String, double)> similarsAll;

  const SimilarListPage({
    super.key,
    required this.similarsAll,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor:
          Settings.themeWhat.value && Settings.themeBlack.value,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
        physics: const ClampingScrollPhysics(),
        itemCount: similarsAll.length,
        itemBuilder: (BuildContext ctxt, int index) {
          var e = similarsAll[index];
          return FutureBuilder<List<QueryResult>>(
            future: queryDedupedArtistArticles(type, e.$1),
            builder: (BuildContext context,
                AsyncSnapshot<List<QueryResult>> snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  height: 195,
                );
              }

              return ThreeArticlePanel(
                tappedRoute: () => ArtistInfoPage(
                  type: type,
                  name: e.$1,
                ),
                title:
                    ' ${e.$1} (${HentaiIndex.getArticleCount(type.name, e.$1)})',
                count:
                    '${Translations.instance!.trans('score')}: ${e.$2.toStringAsFixed(1)} ',
                articles: snapshot.data!,
              );
            },
          );
        },
      ),
    );
  }
}

Future<List<QueryResult>> queryDedupedArtistArticles(
    ArtistType type, String e) async {
  final postfix = e.toLowerCase().replaceAll(' ', '_');
  final queryString = translate2query(
      '${type.name}:$postfix ${Settings.includeTags.value} ${Settings.serializedExcludeTags}');
  final qm = QueryManager.queryPagination(queryString, 10);
  final quries = await qm.next();

  if (quries.isEmpty) {
    return [];
  }

  final titles = [removeChapter(quries[0].title() as String)];
  final results = [quries[0]];

  // 제목이 비슷한(중복) 작품을 보여주지 않기 위해 필터링
  for (final query in quries) {
    final target = removeChapter(query.title() as String);
    final hasSimilar = titles.any((source) {
      return Distance.levenshteinDistanceComparable(
              source.runes.map((e) => e.toString()).toList(),
              target.runes.map((e) => e.toString()).toList()) <
          3;
    });

    if (!hasSimilar) {
      titles.add(target);
      results.add(query);
    }
  }

  return results;
}

String removeChapter(String title) {
  final unescapedTitle = HtmlUnescape().convert(title.trim());
  final pos = unescapedTitle.indexOf(RegExp(r'Ch\.|ch\.'));

  return (pos == -1 ? unescapedTitle : unescapedTitle.substring(0, pos)).trim();
}
