// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/api/api.swagger.dart';
import 'package:violet/server/wsalt.dart';

class VioletServerV2 {
  static const protocol = 'https';
  static const host = 'koromo.cc';
  static const api = '$protocol://$host';

  static late final Api instance;

  static void init() {
    instance = Api.create(
      baseUrl: Uri.parse(api),
      interceptors: [HmacInterceptor()],
    );
  }

  static String? _userId;
  static Future<String> _getUserAppId() async {
    if (_userId == null) {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('fa_userid');
    }
    return _userId!;
  }

  static Future<void> view(int articleid) async {
    final userId = await _getUserAppId();
    await VioletServerV2.instance.apiV2ViewPost(
      articleId: articleid,
      viewSeconds: 0,
      userAppId: userId,
    );
  }

  static Future<CommentGetResponseDto> getComments(String where) async {
    return (await VioletServerV2.instance.apiV2CommentGet(where: where)).body!;
  }
}

class HmacInterceptor implements Interceptor {
  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(
    Chain<BodyType> chain,
  ) async {
    final request = applyHeaders(chain.request, hmacHeader());
    return chain.proceed(request);
  }

  static Map<String, String> hmacHeader() {
    final vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    final vValid = getValid(vToken.toString());

    return {
      'v-token': vToken.toString(),
      'v-valid': vValid,
      'Content-Type': 'application/json',
    };
  }
}
