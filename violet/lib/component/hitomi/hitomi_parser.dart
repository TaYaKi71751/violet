// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

class HitomiParser {
  // Extract metadata from galleryblock HTML.
  static Future<Map<String, dynamic>> parseGalleryBlock(String html) async {
    var doc = (await compute(parse, html)).querySelector('div');

    var title = doc!.querySelector('h1')!.text.trim();
    var magic = doc.querySelector('a')?.attributes['href'];
    var thumbnail = _parseThumbnail(doc);
    var artists = ['N/A'];
    List<String>? series;
    List<String>? tags;
    String? type;
    String? language;
    String? published;

    try {
      artists = doc
          .querySelector('div.artist-list')!
          .querySelectorAll('li')
          .map((e) => e.querySelector('a')!.text.trim())
          .toList();
    } catch (_) {
      try {
        artists = doc
            .querySelector('div.artists-list')!
            .querySelectorAll('li')
            .map((e) => e.querySelector('a')!.text.trim())
            .toList();
      } catch (__) {}
    }

    final metadata = _parseMetadataBlock(doc);
    final rows = metadata?.querySelectorAll('table tr') ?? [];
    series = _parseLinksFromLabel(rows, 'series');
    type = _parseFirstLinkFromLabel(rows, 'type');
    language = _legalizeLanguage(_parseFirstLinkFromLabel(rows, 'language'));
    tags = _parseLinksFromLabel(rows, 'tags').map(_legalizeTag).toList();
    published = metadata?.querySelector('p')?.text.trim();

    return {
      'Magic': magic,
      'Thumbnail': thumbnail,
      'Title': title,
      'Artists': artists,
      'Series': series,
      'Type': type,
      'Language': language,
      'Tags': tags,
      'Published': published,
    };
  }

  static Future<Map<String, dynamic>> parseGallery(String html) async {
    final doc = await compute(parse, html);
    final result = <String, dynamic>{};

    for (final tr in doc.querySelectorAll('div.gallery-info table tr')) {
      final key = tr.querySelector('td')?.text.toLowerCase().trim();
      final values = tr
          .querySelectorAll('a')
          .map((e) => e.text.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (key == 'group' || key == 'groups') {
        result['Groups'] = values;
      } else if (key == 'character' || key == 'characters') {
        result['Characters'] = values;
      }
    }

    return result;
  }

  static String? _parseThumbnail(Element doc) {
    final img = doc.querySelector('a img');
    final value = img?.attributes['data-src'] ?? img?.attributes['src'];
    if (value == null || value.isEmpty) return null;

    const prefix = '//tn.gold-usergeneratedcontent.net/';
    if (!value.startsWith(prefix)) return value;

    return value.substring(prefix.length).replaceFirst('smallbig', 'big');
  }

  static Element? _parseMetadataBlock(Element doc) {
    final divs = doc.children
        .where((element) => element.localName?.toLowerCase() == 'div')
        .toList();

    if (divs.length > 1) return divs[1];
    return doc.querySelector('table')?.parent;
  }

  static List<String> _parseLinksFromLabel(List<Element> rows, String label) {
    final row = rows.cast<Element?>().firstWhere(
      (row) => _rowLabel(row) == label,
      orElse: () => null,
    );
    if (row == null) return [];

    final cells = row.querySelectorAll('td');
    if (cells.length < 2) return [];

    return cells[1]
        .querySelectorAll('a')
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String? _parseFirstLinkFromLabel(List<Element> rows, String label) {
    final links = _parseLinksFromLabel(rows, label);
    if (links.isEmpty) return null;
    return links.first;
  }

  static String? _rowLabel(Element? row) {
    return row?.querySelector('td')?.text.trim().toLowerCase();
  }

  static String? _legalizeLanguage(String? language) {
    if (language == null || language.isEmpty) return null;
    final value = language.trim();

    return switch (value) {
      '모든 언어' => 'all',
      '한국어' => 'korean',
      'N/A' => 'n/a',
      '日本語' => 'japanese',
      'English' => 'english',
      'Español' => 'spanish',
      'ไทย' => 'thai',
      'Deutsch' => 'german',
      '中文' => 'chinese',
      'Português' => 'portuguese',
      'Français' => 'french',
      'Tagalog' => 'tagalog',
      'Русский' => 'russian',
      'Italiano' => 'italian',
      'polski' => 'polish',
      'tiếng việt' => 'vietnamese',
      'magyar' => 'hungarian',
      'Čeština' => 'czech',
      'Bahasa Indonesia' => 'indonesian',
      'العربية' => 'arabic',
      _ => value.toLowerCase(),
    };
  }

  static String _legalizeTag(String tag) {
    final value = tag.trim();
    if (value.endsWith('♀')) return 'female:${_normalizeTag(value, '♀')}';
    if (value.endsWith('♂')) return 'male:${_normalizeTag(value, '♂')}';
    return _normalizeTag(value);
  }

  static String _normalizeTag(String tag, [String suffix = '']) {
    final value = suffix.isEmpty
        ? tag
        : tag.substring(0, tag.length - suffix.length).trim();

    return value.toLowerCase().replaceAll(' ', '_');
  }
}
