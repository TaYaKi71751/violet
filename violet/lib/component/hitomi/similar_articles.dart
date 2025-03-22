import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 아티클 간 유사도 정보를 관리하는 클래스
///
/// JSON 파일에서 유사도 데이터를 로드하고 활용하는 기능 제공
class SimilarArticles {
  // 싱글톤 인스턴스
  static final SimilarArticles _instance =
      SimilarArticles._internal();

  // 유사도 데이터 저장 맵 - { 아티클ID: { 관련아티클ID: 유사도점수 } }
  final Map<String, Map<String, double>> _similarityData = {};

  // 데이터 로드 여부
  bool _isLoaded = false;

  // 데이터 로드 여부 확인 getter
  bool get isLoaded => _isLoaded;

  // 싱글톤 접근 메서드
  factory SimilarArticles() => _instance;

  // 내부 생성자
  SimilarArticles._internal();

  /// 유사도 데이터 JSON 파일 로드
  ///
  /// assets/rank/similar_articles_with_scores.json 파일에서 데이터 로드
  Future<void> loadSimilarityData() async {
    if (_isLoaded) return;

    try {
      final jsonString = await rootBundle
          .loadString('assets/rank/similar_articles_with_scores.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      _similarityData.clear();

      // JSON 데이터 파싱
      jsonData.forEach((articleId, similarArticles) {
        final similarityMap = <String, double>{};

        (similarArticles as Map<String, dynamic>)
            .forEach((otherArticleId, similarityScore) {
          similarityMap[otherArticleId] =
              double.tryParse(similarityScore.toString()) ?? 0.0;
        });

        _similarityData[articleId] = similarityMap;
      });

      _isLoaded = true;
      debugPrint('유사도 데이터 로드 완료: ${_similarityData.length} 아티클');
    } catch (e) {
      debugPrint('유사도 데이터 로드 실패: $e');
      _isLoaded = false;
    }
  }

  /// 두 아티클 ID 간의 유사도 점수 반환
  ///
  /// [id1]과 [id2] 사이의 유사도 점수를 반환 (0.0 ~ 1.0)
  /// 같은 ID인 경우 1.0, 데이터가 없는 경우 0.0 반환
  double getSimilarity(int id1, int id2) {
    if (!_isLoaded) return 0.0;
    if (id1 == id2) return 1.0;

    final strId1 = id1.toString();
    final strId2 = id2.toString();

    // A->B 유사도 확인
    if (_similarityData.containsKey(strId1) &&
        _similarityData[strId1]!.containsKey(strId2)) {
      return _similarityData[strId1]![strId2]!;
    }

    // B->A 유사도 확인 (대칭적)
    if (_similarityData.containsKey(strId2) &&
        _similarityData[strId2]!.containsKey(strId1)) {
      return _similarityData[strId2]![strId1]!;
    }

    return 0.0;
  }

  /// 특정 아티클의 유사한 아티클 목록 반환
  ///
  /// [articleId]와 유사한 아티클 목록을 반환
  /// [limit]으로 결과 개수 제한 가능 (기본값: 10)
  List<SimilarArticle> getSimilarArticles(int articleId, {int limit = 10}) {
    if (!_isLoaded) return [];

    final strId = articleId.toString();
    if (!_similarityData.containsKey(strId)) return [];

    final similarArticles = <SimilarArticle>[];

    _similarityData[strId]!.forEach((otherIdStr, similarity) {
      similarArticles.add(SimilarArticle(
        id: int.parse(otherIdStr),
        similarity: similarity,
      ));
    });

    // 유사도 내림차순 정렬
    similarArticles.sort((a, b) => b.similarity.compareTo(a.similarity));

    // 개수 제한
    return similarArticles.length > limit
        ? similarArticles.sublist(0, limit)
        : similarArticles;
  }

  /// 유사도에 따른 Color 객체 반환
  ///
  /// [similarity] 값에 따라 적절한 색상 반환
  Color getSimilarityColor(double similarity) {
    if (similarity > 0.8) return Colors.red.shade400; // 매우 유사
    if (similarity > 0.6) return Colors.orange.shade400; // 상당히 유사
    if (similarity > 0.4) return Colors.green.shade400; // 중간 유사도
    if (similarity > 0.2) return Colors.blue.shade400; // 약간 유사
    return Colors.purple.shade400; // 거의 유사하지 않음
  }

  /// 유사도 범위에 따른 텍스트 설명 반환
  String getSimilarityDescription(double similarity) {
    if (similarity > 0.8) return '매우 유사';
    if (similarity > 0.6) return '상당히 유사';
    if (similarity > 0.4) return '중간 유사도';
    if (similarity > 0.2) return '약간 유사';
    return '유사하지 않음';
  }

  /// 아티클 목록을 유사도 기반으로 그룹화
  ///
  /// [articleIds] 목록의 아티클들을 유사도에 따라 그룹화
  /// [threshold] 값 이상의 유사도를 가진 아티클끼리 그룹화 (기본값: 0.5)
  List<List<int>> getArticleGroups(List<int> articleIds,
      {double threshold = 0.5}) {
    if (!_isLoaded || articleIds.isEmpty) return [];

    final groups = <List<int>>[];
    final processedIds = <int>{};

    for (final articleId in articleIds) {
      if (processedIds.contains(articleId)) continue;

      // 현재 ID와 유사한 아티클 찾기
      final currentGroup = [articleId];
      processedIds.add(articleId);

      for (final otherId in articleIds) {
        if (articleId == otherId || processedIds.contains(otherId)) continue;

        final similarity = getSimilarity(articleId, otherId);
        if (similarity >= threshold) {
          currentGroup.add(otherId);
          processedIds.add(otherId);
        }
      }

      groups.add(currentGroup);
    }

    return groups;
  }

  /// 아티클 ID와 관련된 모든 유사 아티클 ID 목록 반환
  ///
  /// [articleId]와 유사한 모든 아티클 ID 반환
  /// [threshold] 이상의 유사도를 가진 아티클만 포함 (기본값: 0.2)
  Set<int> getRelatedArticleIds(int articleId, {double threshold = 0.2}) {
    if (!_isLoaded) return {};

    final strId = articleId.toString();
    if (!_similarityData.containsKey(strId)) return {};

    final relatedIds = <int>{};

    _similarityData[strId]!.forEach((otherIdStr, similarity) {
      if (similarity >= threshold) {
        relatedIds.add(int.parse(otherIdStr));
      }
    });

    return relatedIds;
  }
}

/// 유사 아티클 정보를 담는 클래스
class SimilarArticle {
  /// 아티클 ID
  final int id;

  /// 유사도 점수 (0.0 ~ 1.0)
  final double similarity;

  /// 유사 아티클 생성자
  const SimilarArticle({
    required this.id,
    required this.similarity,
  });

  @override
  String toString() =>
      'SimilarArticle(id: $id, 유사도: ${(similarity * 100).toStringAsFixed(1)}%)';
}
