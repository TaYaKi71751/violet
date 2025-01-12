import 'dart:convert';

import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/network/wrapper.dart' as http;

class MessageSearch {
  static late final List<(String, String, int)> autocompleteTarget;

  static bool _init = false;

  static Future<void> init() async {
    if (_init) return;
    _init = true;

    const url =
        'https://raw.githubusercontent.com/project-violet/violet-message-search/master/SORT-COMBINE.json';

    var m = jsonDecode((await http.get(url)).body) as Map<String, dynamic>;

    autocompleteTarget = m.entries
        .map((e) => (e.key, TagTranslate.disassembly(e.key), e.value as int))
        .toList();

    autocompleteTarget.sort((x, y) => y.$3.compareTo(x.$3));
  }
}

class MessageSearchResult {
  final double matchScore;
  final int id;
  final int page;
  final double correctness;
  final List<double> rect;

  MessageSearchResult({
    required this.matchScore,
    required this.id,
    required this.page,
    required this.correctness,
    required this.rect,
  });

  static List<MessageSearchResult> fromJson(String json) {
    final result = jsonDecode(json) as List<dynamic>;
    return result
        .map(
          (e) => MessageSearchResult(
            matchScore: e['MatchScore'] as double,
            id: e['Id'] as int,
            page: e['Page'] as int,
            correctness: e['Correctness'] as double,
            rect: (e['Rect'] as List<dynamic>)
                .map((e) => double.parse(e.toString()))
                .toList(),
          ),
        )
        .toList();
  }
}
