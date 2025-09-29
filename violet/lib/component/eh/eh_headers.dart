// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/network/wrapper.dart' as http;

class EHSession {
  static EHSession? tryLogin(String id, String pass) {
    return null;
  }

  static Future<String?> cookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('eh_cookies');
  }

  static Future<String> requestString(String url) async {
    final cookie = await EHSession.cookie();
    return (await http.get(url, headers: {'Cookie': cookie ?? ''})).body;
  }

  static Future<String?> requestRedirect(String url) async {
    final cookie = await EHSession.cookie();
    Request req = Request('Get', Uri.parse(url))..followRedirects = false;
    req.headers['Cookie'] = cookie ?? '';
    Client baseClient = Client();
    StreamedResponse response = await baseClient.send(req);
    return response.headers['location'];
  }

  static Future<String> postComment(String url, String content) async {
    final cookie = await EHSession.cookie();
    return (await http.post(
      url,
      headers: {'Cookie': cookie ?? ''},
      body: 'commenttext_new=${Uri.encodeFull(content)}',
    )).body;
  }

  static Future<EHArticle?> fetchArticle(int id, String ehash) async {
    final cookie = await EHSession.cookie();

    // 1. 설정된 쿠키가 있다면 exhentai에서 먼저 시도
    if (cookie != null) {
      try {
        final html = await EHSession.requestString(
          'https://exhentai.org/g/$id/$ehash/?p=0&inline_set=ts_l',
        );
        return EHParser.parseArticleData(html);
      } catch (_) {}
    }

    // 2. 설정된 쿠키가 없거나 exh 요청이 실패하면 eh에서 시도
    try {
      final html = (await http.get(
        'https://e-hentai.org/g/$id/$ehash/?p=0&inline_set=ts_l',
      )).body;
      if (!EHParser.validHtml(html)) {
        return null;
      }
      return EHParser.parseArticleData(html);
    } catch (_) {}

    return null;
  }
}
