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
  /// [baseUrl] 서버 URL (기본값: 'http://localhost:8080')
  LLMSearchService({this.baseUrl = 'http://localhost:8080'});

  /// 기본 검색 API 호출 (내부 메서드)
  ///
  /// [payload] 검색 요청 페이로드
  /// [timeout] 요청 타임아웃 시간
  ///
  /// 성공 시 응답 본문을 반환, 실패 시 예외 발생
  Future<String> _searchRequest({
    required Map<String, dynamic> payload,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final url = Uri.parse('$baseUrl/search');

    Logger.info('[LLMSearchService] 검색 요청: $payload');

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      return decodeResponseBody(response.bodyBytes);
    } else {
      final errorMsg =
          '서버 오류: ${response.statusCode} - ${decodeResponseBody(response.bodyBytes)}';
      Logger.error('[LLMSearchService] $errorMsg');
      throw Exception(errorMsg);
    }
  }

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
      final payload = {
        'query': query,
        if (searchQuery != null) 'search_query': searchQuery,
        'k': k,
      };

      final decodedBody = await _searchRequest(payload: payload);

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

  /// JSON 형식의 검색 API 호출
  ///
  /// [query] 검색할 질문
  /// [query] 벡터 검색에 사용할 키워드 (선택사항)
  /// [k] 검색할 문서 수 (기본값: 50)
  ///
  /// 성공 시 JSON 객체를 반환, 실패 시 에러 정보가 포함된 JSON 객체 반환
  Future<Map<String, dynamic>> searchJson({
    required String query,
    int k = 50,
    bool strictRelevance = false,
  }) async {
    try {
      // 검색 쿼리 템플릿 생성
      String formattedQuery = _createJsonQueryTemplate(query, strictRelevance);

      final payload = {
        'query': formattedQuery,
        'search_query': query,
        'k': k,
      };

      final decodedBody = await _searchRequest(
        payload: payload,
        timeout: const Duration(seconds: 60), // JSON 응답은 더 오래 걸릴 수 있음
      );

      return _processJsonResponse(decodedBody);
    } catch (e, stackTrace) {
      Logger.error('[LLMSearchService] 검색 중 오류 발생: $e\n$stackTrace');

      // 네트워크 오류 발생 시 자동 재시도
      if (e.toString().contains('Failed to load')) {
        Logger.warning('[LLMSearchService] 네트워크 오류로 인한 재시도...');
        await Future.delayed(const Duration(milliseconds: 500));
        return searchJson(query: query, k: k);
      }

      return {'error': '검색 실패', 'message': e.toString()};
    }
  }

  /// JSON 검색을 위한 쿼리 템플릿 생성
  String _createJsonQueryTemplate(String searchQuery, bool strictRelevance) {
    return '''
당신은 다양한 작품들을 분석하는 전문가다.
모든 응답 문장은 반드시 문어체 평서문으로 작성되어야 하며, 어떠한 경우에도 반말이나 존댓말이 포함되어서는 안 된다.

작품이 검색내용과 관련된 정보를 포함하는지에 대한 여부를 판단하여 간단한 설명(reason)을 작성한다.
${strictRelevance ? "반드시 검색내용과 명확하게 관련된 작품만 포함하며, 검색 내용에 적힌 모든 내용을 만족해야하며, 관련성이 미약하거나 동떨어진 작품은 제외한다." : "관련된 정보를 포함하지 않거나 동떨어진 경우에는 해당 작품을 제외하되 가능한 많은 결과를 출력하도록 노력한다."}
출력 결과는 관련성 순서로 나열한다.
응답은 반드시 아래의 JSON 형식만을 따르고, JSON 구조를 절대 깨뜨리지 말아야 한다(예: 문자열 내 쌍따옴표 " 사용 금지, 중괄호나 대괄호 누락 금지).
다른 텍스트나 추가 설명은 절대 포함시키지 않으며, reason에는 "가 포함되지 않아야 한다.

또한 전체 검색 결과물로 출력될 내용물들을 간단하게 요약하여 evaluate에 작성한다.
evaluate에는 검색 판단 결과를 요약하는데, 어떤 방식으로 요약했는지는 절대 설명하지 말고, 도덕적 판단 기준은 배제하고, 각 reason과 검색내용을 연관지어 강조해서 설명한다.

검색내용: $searchQuery

예시 형식(엄격 준수):
{
  "evaluate": "전체 검색 판단 결과를 요약한다.",
  "results": [
    {"id": 12345, "reason": "각 작품이 입력 정보와 어떤 관련이 있는지, 작품 자체의 특징은 어떠한지 설명한다."},
    {"id": 12345, "reason": "각 작품이 입력 정보와 어떤 관련이 있는지, 작품 자체의 특징은 어떠한지 설명한다."},
    ...
  ]
}
JSON 형식의 무결성을 최우선으로 유지하며, 오류(예: " 사용, 구문 누락)를 절대 발생시키지 않는다.
''';
  }

  /// JSON 응답 처리
  Map<String, dynamic> _processJsonResponse(String decodedBody) {
    try {
      // 결과 추출
      final result = jsonDecode(decodedBody);
      String resultText = result['result'] as String;

      // JSON 블록이 있는 경우 처리
      if (resultText.trim().startsWith('```') &&
          resultText.trim().endsWith('```')) {
        final parsedResult = parseJsonFromMarkdown(resultText);

        // 파싱된 결과가 Map이면 그대로 반환
        if (parsedResult is Map<String, dynamic>) {
          return parsedResult;
        }

        // 파싱된 결과가 문자열이면 다시 JSON으로 파싱 시도
        if (parsedResult is String) {
          try {
            return jsonDecode(parsedResult);
          } catch (e) {
            Logger.error('[LLMSearchService] JSON 파싱 실패: $e');
            return {'error': '응답을 JSON으로 파싱할 수 없습니다.', 'raw': parsedResult};
          }
        }

        // 다른 타입의 결과는 문자열로 변환하여 반환
        return {'result': parsedResult.toString()};
      }

      // JSON 블록이 없는 경우 직접 파싱 시도
      try {
        return jsonDecode(resultText);
      } catch (e) {
        Logger.error('[LLMSearchService] JSON 파싱 실패: $e');
        return {'error': '응답을 JSON으로 파싱할 수 없습니다.', 'raw': resultText};
      }
    } catch (e) {
      Logger.error('[LLMSearchService] 응답 파싱 실패: $e\n원본: $decodedBody');
      return {'error': '응답 파싱 실패', 'message': e.toString(), 'raw': decodedBody};
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

  /// 비동기 JSON 검색 API 호출 (백그라운드에서 실행)
  ///
  /// [query] 검색할 질문
  /// [searchQuery] 벡터 검색에 사용할 키워드 (선택사항)
  /// [k] 검색할 문서 수 (기본값: 50)
  /// [onResult] 검색 결과 콜백
  /// [onError] 에러 발생 시 콜백
  void searchJsonAsync({
    required String query,
    int k = 50,
    required Function(Map<String, dynamic>) onResult,
    required Function(Map<String, dynamic>) onError,
  }) {
    searchJson(query: query, k: k)
        .then(onResult)
        .catchError((e) => onError({'error': e.toString()}));
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
