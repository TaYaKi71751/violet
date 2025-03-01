// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:violet/log/log.dart';
import 'package:charset/charset.dart';

/// 서버 검색 API와 통신하기 위한 클래스
class LLMSearchService {
  /// 서버 기본 URL
  final String baseUrl;

  /// 생성자
  /// [baseUrl] 서버 URL (예: 'http://localhost:8000')
  LLMSearchService({required this.baseUrl});

  /// 검색 API 호출
  ///
  /// [query] 검색할 질문
  /// [searchQuery] 벡터 검색에 사용할 키워드 (선택사항)
  /// [k] 검색할 문서 수 (기본값: 50)
  ///
  /// 성공 시 검색 결과 텍스트를 반환, 실패 시 에러 메시지 반환
  Future<String> search({
    required String query,
    String? searchQuery,
    int k = 50,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/search');

      final payload = {
        'query': query,
        if (searchQuery != null) 'search_query': searchQuery,
        'k': k,
      };

      Logger.info('[LLMSearchService] 검색 요청: $payload');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // 인코딩 문제 처리
        String decodedBody = decodeResponseBody(response.bodyBytes);

        try {
          // 결과 추출
          final result = jsonDecode(decodedBody);
          String resultText = result['result'] as String;

          // JSON 블록이 있는 경우 처리
          if (resultText.trim().startsWith('```') &&
              resultText.trim().endsWith('```')) {
            final parsedResult = parseJsonFromMarkdown(resultText);
            // 파싱 결과가 문자열이 아닌 경우 JSON 문자열로 변환
            if (parsedResult is! String) {
              return jsonEncode(parsedResult);
            }
            return parsedResult.toString();
          }

          return resultText;
        } catch (e) {
          Logger.error('[LLMSearchService] 응답 파싱 실패: $e\n원본: $decodedBody');
          // 원본 응답 반환
          return decodedBody;
        }
      } else {
        final errorMsg =
            '서버 오류: ${response.statusCode} - ${decodeResponseBody(response.bodyBytes)}';
        Logger.error('[LLMSearchService] $errorMsg');
        return '검색 실패: $errorMsg';
      }
    } catch (e, stackTrace) {
      Logger.error('[LLMSearchService] 검색 중 오류 발생: $e\n$stackTrace');

      // 네트워크 오류 발생 시 자동 재시도
      if (e.toString().contains('Failed to load')) {
        Logger.warning('[LLMSearchService] 네트워크 오류로 인한 재시도...');
        await Future.delayed(const Duration(milliseconds: 500));
        return search(query: query, searchQuery: searchQuery, k: k);
      }

      return '검색 실패: $e';
    }
  }

  /// 비동기 검색 API 호출 (백그라운드에서 실행)
  ///
  /// [query] 검색할 질문
  /// [searchQuery] 벡터 검색에 사용할 키워드 (선택사항)
  /// [k] 검색할 문서 수 (기본값: 50)
  /// [onResult] 검색 결과 콜백
  /// [onError] 에러 발생 시 콜백
  void searchAsync({
    required String query,
    String? searchQuery,
    int k = 50,
    required Function(String) onResult,
    required Function(String) onError,
  }) {
    search(query: query, searchQuery: searchQuery, k: k)
        .then(onResult)
        .catchError((e) => onError(e.toString()));
  }
}

/// 다양한 인코딩을 처리하는 응답 디코딩 함수
///
/// [bodyBytes] HTTP 응답의 바이트 데이터
///
/// UTF-8, EUC-KR, Latin1 순으로 디코딩을 시도하고 성공한 결과를 반환
String decodeResponseBody(List<int> bodyBytes) {
  // UTF-8로 디코딩 시도
  try {
    return utf8.decode(bodyBytes);
  } catch (e) {
    Logger.warning('[LLMSearchService] UTF-8 디코딩 실패: $e');

    // EUC-KR로 디코딩 시도
    try {
      final eucKrDecoder = Charset.getByName('euc-kr');
      if (eucKrDecoder != null) {
        final result = eucKrDecoder.decode(bodyBytes);
        Logger.warning('[LLMSearchService] EUC-KR로 디코딩 성공');
        return result;
      }
    } catch (e) {
      Logger.warning('[LLMSearchService] EUC-KR 디코딩 실패: $e');
    }

    // 모든 디코딩 실패 시 latin1 사용
    Logger.warning('[LLMSearchService] Latin1으로 대체 처리');
    return latin1.decode(bodyBytes);
  }
}

/// JSON 블록 마커를 제거하고 JSON을 파싱하는 함수
///
/// [text] JSON 블록 마커(```json과 ```)로 감싸진 텍스트
///
/// 마커를 제거하고 JSON을 파싱한 결과를 반환
dynamic parseJsonFromMarkdown(String text) {
  // JSON 블록 마커 제거
  String jsonText = text.trim();

  // ```json으로 시작하고 ```로 끝나는 패턴 확인
  if (jsonText.startsWith('```json') && jsonText.endsWith('```')) {
    // ```json과 마지막 ```를 제거
    jsonText = jsonText.substring('```json'.length, jsonText.length - 3).trim();
  }
  // ```으로 시작하고 ```로 끝나는 패턴 확인
  else if (jsonText.startsWith('```') && jsonText.endsWith('```')) {
    // 처음과 마지막 ```를 제거
    jsonText = jsonText.substring(3, jsonText.length - 3).trim();
  }

  // JSON 파싱
  try {
    // 응답이 JSON 배열 또는 객체 형식인지 확인
    if ((jsonText.startsWith('{') && jsonText.endsWith('}')) ||
        (jsonText.startsWith('[') && jsonText.endsWith(']'))) {
      return jsonDecode(jsonText);
    } else {
      // 유효한 JSON 형식이 아닌 경우 원본 텍스트 반환
      Logger.warning('[LLMSearchService] 유효한 JSON 형식이 아님: $jsonText');
      return text;
    }
  } catch (e) {
    Logger.error('[LLMSearchService] JSON 파싱 실패: $e\n원본 텍스트: $text');
    // 파싱 실패 시 원본 텍스트 반환
    return text;
  }
}
