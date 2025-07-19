// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';

import 'package:html/parser.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/util/helper.dart';

class EHBookmark {
  static List<HashSet<int>>? bookmarkInfo;
  static Future<List<HashSet<int>>> process() async {
    // https://e-hentai.org/favorites.php?page=0&favcat=0
    // https://exhentai.org/favorites.php?page=0&favcat=0

    var result = <HashSet<int>>[];

    const candidateHosts = [
      'https://exhentai.org',
      'https://e-hentai.org',
    ];
    for (final host in candidateHosts) {
      for (int i = 0; i < 10; i++) {
        await catchUnwind(() async {
          var bookmark = HashSet<int>();

          int? next;
          while (next != -1) {
            final html = await EHSession.requestString(
                '$host/favorites.php?favcat=$i&inline_set=fs_p${next == null ? '' : '&next=$next'}');
            parse(html).querySelectorAll('a[href*="/g/"]').forEach((element) {
              final href = element.attributes['href'];
              if (href == null) return;
              bookmark.add(int.parse((href.split('/')[4])));
            });
            if (parse(html).querySelectorAll('a[href*="/g/"]').isEmpty) {
              next = -1;
            } else {
              if (next == bookmark.last) {
                next = -1;
              } else {
                next = bookmark.last;
              }
            }
          }

          result.add(bookmark);
        });
      }
    }

    return bookmarkInfo = result;
  }
}
