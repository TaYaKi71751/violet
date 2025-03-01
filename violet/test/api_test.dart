// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:violet/api/api.swagger.dart';
import 'package:violet/server/violet_v2.dart';
import 'package:violet/server/search.dart';

class MockApi {
  static late final Api instance;

  static void init() {
    instance = Api.create(
      baseUrl: Uri.parse('http://localhost:3000'),
      interceptors: [HmacInterceptor()],
    );
  }
}

void main() async {
  var disabled = true;
  if (Platform.environment.containsKey('ENABLE_API_TESTS')) {
    disabled = false;
  }

  MockApi.init();

  test('Test Hello', () async {
    final res = await MockApi.instance.apiV2Get();
    expect(res.body as String, 'Hello World!');
  }, skip: disabled);

  test('Test Hmac', () async {
    final res = await MockApi.instance.apiV2HmacGet();
    expect(res.statusCode, 200);
  }, skip: disabled);

  test('Test LLM Search', () async {
    final llmSearchService = LLMSearchService(baseUrl: 'http://localhost:8080');

    const searchQuery = '다채로운 문체';
    final result = await llmSearchService.search(
      query: '''
당신은 다양한 작품들을 분석하는 전문가다.
작품이 $searchQuery와 관련된 정보를 포함하는지에 대한 여부를 판단하여 간단한 설명(reason)을 작성한다.
관련된 정보를 포함하지 않거나 동떨어진 경우에는 해당 작품을 제외해야 하되 가능한 많은 결과를 출력하도록 노력한다.
응답은 반드시 아래의 JSON 배열 형식만을 따르고, 다른 텍스트나 추가 설명은 포함하지 말아야 하고, 각 reason에는 "가 포함되어 서는 안된다.
모든 응답 문장의 형식은 넷플릭스 작품 소개 형식으로 작성해야 한다.

예시 형식:
{
  "evaluate": "전체 검색 판단 결과를 요약한다.",
  "results": [
    {"id": 12345, "reason": "각 작품이 입력 정보와 어떤 관련이 있는지, 작품 자체의 특징은 어떠한지 설명한다."},
    {"id": 12345, "reason": "각 작품이 입력 정보와 어떤 관련이 있는지, 작품 자체의 특징은 어떠한지 설명한다."},
    ...
  ]
}
''',
      searchQuery: searchQuery,
      k: 30,
    );
    print(result);
    print(jsonDecode(result));
  }, skip: disabled);
}
