// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/displayed_tag.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/log/log.dart';
import 'package:violet/variables.dart';

// This is used for estimation similiar Aritst/Group/Uplaoder with each others.
class HentaiIndex {
  // Tag Group, <Tag, Article Count>
  static Map<String, dynamic>? tagCount;
  // Tag, Index
  // Map<String, int>
  static late Map<String, dynamic> tagIndex;
  // Artist, <Tag Index, Count>
  // Map<String, Map<String, int>>
  static late Map<String, dynamic> tagArtist;
  static late Map<String, dynamic> tagGroup;
  static late Map<String, dynamic> tagUploader;
  static late Map<String, dynamic> tagSeries;
  static late Map<String, dynamic> tagCharacter;
  // Series, <Character, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic>? characterSeries;
  // Unmap of character series
  // Character, <Series, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic>? seriesCharacter;
  // Series, <Series, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic>? seriesSeries;
  // Character, <Character, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic>? characterCharacter;
  // Tag, [<Tag, Similarity>]
  static late Map<String, dynamic> relatedTag;

  static Future<void> init() async {
    await _loadIndexes();
    await _loadCountMap();
  }

  static Future<void> _loadIndexes() async {
    final directory = await getApplicationDocumentsDirectory();
    final subdir = Platform.isAndroid ? '/data' : '';

    // No data on first run.
    final path2 = File('${directory.path}$subdir/tag-artist.json');
    if (!await path2.exists()) return;
    tagArtist = jsonDecode(await path2.readAsString());
    final path3 = File('${directory.path}$subdir/tag-group.json');
    tagGroup = jsonDecode(await path3.readAsString());
    final path4 = File('${directory.path}$subdir/tag-index.json');
    tagIndex = jsonDecode(await path4.readAsString());
    final path5 = File('${directory.path}$subdir/tag-uploader.json');
    tagUploader = jsonDecode(await path5.readAsString());
    try {
      final path6 = File('${directory.path}$subdir/tag-series.json');
      tagSeries = jsonDecode(await path6.readAsString());
      final path7 = File('${directory.path}$subdir/tag-character.json');
      tagCharacter = jsonDecode(await path7.readAsString());
      final path8 = File('${directory.path}$subdir/character-series.json');
      characterSeries = jsonDecode(await path8.readAsString());
      final path9 = File('${directory.path}$subdir/series-character.json');
      seriesCharacter = jsonDecode(await path9.readAsString());

      final path10 = File('${directory.path}$subdir/character-character.json');
      characterCharacter = jsonDecode(await path10.readAsString());
      final path11 = File('${directory.path}$subdir/series-series.json');
      seriesSeries = jsonDecode(await path11.readAsString());
    } catch (e, st) {
      Logger.error('[Hitomi-Indexes] E: $e\n'
          '$st');
    }

    var relatedData = json.decode(await rootBundle.loadString(
            'assets/locale/tag/related-tag-${TagTranslate.defaultLanguage}.json'))
        as List<dynamic>;
    relatedTag = <String, dynamic>{};
    for (var element in relatedData) {
      var kv = (element as Map<String, dynamic>).entries.first;
      relatedTag[kv.key] = kv.value;
    }
  }

  static Future<void> _loadCountMap() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final file = File(join(Directory.current.path, 'test/db/index.json'));
      tagCount = jsonDecode(await file.readAsString());
    } else {
      final subdir = Platform.isAndroid ? '/data' : '';
      final directory = await getApplicationDocumentsDirectory();
      final path = File('${directory.path}$subdir/index.json');
      if (!await path.exists()) return;
      final text = path.readAsStringSync();
      tagCount = jsonDecode(text);
    }

    // split `tag:female:` and `tag:male:` to `female:` and `male:`
    if (tagCount!.containsKey('tag')) {
      final tags = tagCount!['tag'] as Map<String, dynamic>;
      final femaleTags = tags.entries
          .where((e) => e.key.startsWith('female:'))
          .map((e) => MapEntry(e.key.split(':')[1], e.value))
          .toList();
      final maleTags = tags.entries
          .where((e) => e.key.startsWith('male:'))
          .map((e) => MapEntry(e.key.split(':')[1], e.value))
          .toList();
      tagCount!['female'] = Map.fromEntries(femaleTags);
      tagCount!['male'] = Map.fromEntries(maleTags);

      tags.removeWhere(
          (tag, _) => tag.startsWith('female:') || tag.startsWith('male:'));
    }
  }

  static Future<void> loadCountMapIfRequired() async {
    if (tagCount == null) {
      await _loadCountMap();
    }
  }

  static int? getArticleCount(String classification, String name) {
    if (tagCount == null) {
      final subdir = Platform.isAndroid ? '/data' : '';
      final path =
          File('${Variables.applicationDocumentsDirectory}$subdir/index.json');
      final text = path.readAsStringSync();
      tagCount = jsonDecode(text);
    }

    return tagCount![classification][name];
  }

  static Future<List<(DisplayedTag, int)>> queryAutoComplete(String prefix,
      [bool useTranslated = false]) async {
    await loadCountMapIfRequired();

    prefix = prefix.toLowerCase().replaceAll('_', ' ');

    if (prefix.contains(':') && prefix.split(':')[0] != 'random') {
      return _queryAutoCompleteWithTagmap(prefix, useTranslated);
    }

    return _queryAutoCompleteFullSearch(prefix, useTranslated);
  }

  static List<(DisplayedTag, int)> _queryAutoCompleteWithTagmap(
      String prefix, bool useTranslated) {
    final groupOrig = prefix.split(':')[0];
    final group = _normalizeTagPrefix(groupOrig);
    final name = prefix.split(':').last;

    final results = <(DisplayedTag, int)>[];
    if (!tagCount!.containsKey(group)) return results;

    final nameCountsMap = tagCount![group] as Map<dynamic, dynamic>;
    if (!useTranslated) {
      results.addAll(nameCountsMap.entries
          .where((e) => e.key.toString().toLowerCase().contains(name))
          .map((e) => (DisplayedTag(group: group, name: e.key), e.value)));
    } else {
      results.addAll(TagTranslate.containsTotal(name)
          .where((e) => e.group! == group && nameCountsMap.containsKey(e.name))
          .map((e) => (e, nameCountsMap[e.name])));
    }
    results.sort((a, b) => b.$2.compareTo(a.$2));
    return results;
  }

  static List<(DisplayedTag, int)> _queryAutoCompleteFullSearch(
      String prefix, bool useTranslated) {
    if (useTranslated) {
      final results = TagTranslate.containsTotal(prefix)
          .where((e) => tagCount![e.group].containsKey(e.name))
          .map((e) => (e, tagCount![e.group][e.name] as int))
          .toList();
      results.sort((a, b) => b.$2.compareTo(a.$2));
      return results;
    }

    final results = <(DisplayedTag, int)>[];

    tagCount!['tag'].forEach((group, count) {
      if (group.contains(':')) {
        final subGroup = group.split(':');
        if (subGroup[1].contains(prefix)) {
          results.add((DisplayedTag(group: subGroup[0], name: group), count));
        }
      } else if (group.contains(prefix)) {
        results.add((DisplayedTag(group: 'tag', name: group), count));
      }
    });

    tagCount!.forEach((group, value) {
      if (group != 'tag') {
        value.forEach((name, count) {
          if (name.toLowerCase().contains(prefix)) {
            results.add((DisplayedTag(group: group, name: name), count));
          }
        });
      }
    });

    results.sort((a, b) => b.$2.compareTo(a.$2));
    return results;
  }

  static Future<List<(DisplayedTag, int)>> queryAutoCompleteFuzzy(String prefix,
      [bool useTranslated = false]) async {
    await loadCountMapIfRequired();

    prefix = prefix.toLowerCase().replaceAll('_', ' ');

    if (prefix.contains(':')) {
      final groupOrig = prefix.split(':')[0];
      final group = _normalizeTagPrefix(groupOrig);
      final name = prefix.split(':').last;

      // <Tag, Similarity, Count>
      final results = <(DisplayedTag, int, int)>[];
      if (!tagCount!.containsKey(group)) {
        return <(DisplayedTag, int)>[];
      }

      final nameCountsMap = tagCount![group];
      if (!useTranslated) {
        nameCountsMap.forEach((key, value) {
          results.add((
            DisplayedTag(group: group, name: key),
            Distance.levenshteinDistance(
                name.runes.toList(), key.runes.toList()),
            value
          ));
        });
      } else {
        results.addAll(TagTranslate.containsFuzzingTotal(name)
            .where((e) =>
                e.$1.group! == group && nameCountsMap.containsKey(e.$1.name))
            .map((e) => (e.$1, e.$2, nameCountsMap[e.$1.name])));
      }
      results.sort((a, b) => a.$2.compareTo(b.$2));
      return results.map((e) => (e.$1, e.$3)).toList();
    } else {
      if (!useTranslated) {
        final results = <(DisplayedTag, int, int)>[];
        tagCount!.forEach((group, value) {
          value.forEach((name, count) {
            results.add((
              DisplayedTag(group: group, name: name),
              Distance.levenshteinDistance(
                  prefix.runes.toList(), name.runes.toList()),
              count
            ));
          });
        });
        results.sort((a, b) => a.$2.compareTo(b.$2));
        return results.map((e) => (e.$1, e.$3)).toList();
      } else {
        final results = TagTranslate.containsFuzzingTotal(prefix)
            .where((e) => tagCount![e.$1.group].containsKey(e.$1.name))
            .map((e) => (e.$1, tagCount![e.$1.group][e.$1.name] as int, e.$2))
            .toList();
        results.sort((a, b) => a.$3.compareTo(b.$3));
        return results.map((e) => (e.$1, e.$2)).toList();
      }
    }
  }

  static List<(String, double)> _calculateSimilars(
      Map<String, dynamic> map, String artist) {
    var rr = map[artist];
    var result = <(String, double)>[];

    map.forEach((key, value) {
      if (artist == key) return;
      if (key.toLowerCase() == 'n/a') return;

      var dist = Distance.cosineDistance(rr, value);
      result.add((key, dist));
    });

    result.sort((x, y) => y.$2.compareTo(x.$2));

    return result;
  }

  static List<(String, double)> caclulateSimilarsManual(
      Map<String, dynamic> map, Map<String, dynamic> target) {
    final result = <(String, double)>[];

    map.forEach((key, value) {
      if (key.toLowerCase() == 'n/a') return;

      final dist = Distance.cosineDistance(target, value);
      result.add((key, dist));
    });

    result.sort((x, y) => y.$2.compareTo(x.$2));

    return result;
  }

  static List<(String, double)> calculateSimilarArtists(String artist) {
    return _calculateSimilars(tagArtist, artist);
  }

  static List<(String, double)> calculateSimilarGroups(String group) {
    return _calculateSimilars(tagGroup, group);
  }

  static List<(String, double)> calculateSimilarUploaders(String uploader) {
    return _calculateSimilars(tagUploader, uploader);
  }

  static List<(String, double)> calculateSimilarSeries(String series) {
    return _calculateSimilars(tagSeries, series);
  }

  static List<(String, double)> calculateSimilarCharacter(String character) {
    return _calculateSimilars(tagCharacter, character);
  }

  static List<(String, double)> calculateRelatedCharacterSeries(String series) {
    if (seriesSeries == null) {
      return _calculateSimilars(characterSeries!, series)
          .where((element) => element.$2 >= 0.000001)
          .toList();
    } else {
      var ll = (seriesSeries![series] as Map<String, dynamic>)
          .entries
          .map((e) => (e.key, (e.value as int).toDouble()))
          .toList();
      ll.sort((x, y) => y.$2.compareTo(x.$2));
      return ll;
    }
  }

  static List<(String, double)> calculateRelatedSeriesCharacter(
      String character) {
    if (characterCharacter == null) {
      return _calculateSimilars(seriesCharacter!, character)
          .where((element) => element.$2 >= 0.000001)
          .toList();
    } else {
      var ll = (characterCharacter![character] as Map<String, dynamic>)
          .entries
          .map((e) => (e.key, (e.value as num).toDouble()))
          .toList();
      ll.sort((x, y) => y.$2.compareTo(x.$2));
      return ll;
    }
  }

  static List<(String, double)> getRelatedCharacters(String series) {
    if (!characterSeries!.containsKey(series)) {
      return <(String, double)>[];
    }
    var ll = (characterSeries![series] as Map<String, dynamic>)
        .entries
        .map((e) => (e.key, (e.value as num).toDouble()))
        .toList();
    ll.sort((x, y) => y.$2.compareTo(x.$2));
    return ll;
  }

  static List<(String, double)> getRelatedSeries(String character) {
    if (!seriesCharacter!.containsKey(character)) {
      return <(String, double)>[];
    }
    var ll = (seriesCharacter![character] as Map<String, dynamic>)
        .entries
        .map((e) => (e.key, (e.value as num).toDouble()))
        .toList();
    ll.sort((x, y) => y.$2.compareTo(x.$2));
    return ll;
  }

  static List<(String, double)> getRelatedTag(String tag) {
    if (!relatedTag.containsKey(tag)) return <(String, double)>[];
    var ll = (relatedTag[tag] as List<dynamic>)
        .map((e) => (
              (e as Map<String, dynamic>).entries.first.key,
              (e.entries.first.value as num).toDouble()
            ))
        .toList();
    ll.sort((x, y) => y.$2.compareTo(x.$2));
    return ll;
  }
}

String _normalizeTagPrefix(String pp) {
  switch (pp) {
    case 'tags':
      return 'tag';

    case 'language':
    case 'languages':
      return 'lang';

    case 'artists':
      return 'artist';

    case 'groups':
      return 'group';

    case 'types':
      return 'type';

    case 'characters':
      return 'character';

    case 'classes':
      return 'class';
  }

  return pp;
}
