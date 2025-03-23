import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hentai.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'package:violet/component/hitomi/similar_articles.dart';
import 'package:violet/database/query.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/lab/lab/floating_view/article_node.dart';
import 'package:violet/pages/lab/lab/floating_view/painter.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/pages/lab/lab/floating_view/tag_statistics_panel.dart';

class FloatingSimilarArticleView extends StatefulWidget {
  final int initialArticleId;
  final bool useRecursiveLoading;

  const FloatingSimilarArticleView({
    Key? key,
    required this.initialArticleId,
    this.useRecursiveLoading = false,
  }) : super(key: key);

  @override
  _FloatingSimilarArticleViewState createState() =>
      _FloatingSimilarArticleViewState();
}

class _FloatingSimilarArticleViewState extends State<FloatingSimilarArticleView>
    with SingleTickerProviderStateMixin {
  final List<ArticleNode> _nodes = [];
  late final AnimationController _controller;
  ArticleNode? _draggedNode;
  Offset? _dragPosition;
  final int nodeCount = 100; // 최대 100개의 아이템 표시
  final double maxDistance = 200.0; // 엣지가 그려질 최대 거리

  // 유사도 관리 클래스 추가
  final SimilarArticles _similarArticles = SimilarArticles();

  // 유사도별 노드 그룹 관리
  final Map<int, List<ArticleNode>> _similarityGroups = {};

  // 탐색된 아티클 ID 목록
  final Set<int> _processedArticleIds = {};

  // 무한 배경을 위한 변수들
  final double _minScale = 0.2;
  final double _maxScale = 5.0;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  final TransformationController _transformationController =
      TransformationController();

  // 격자 설정
  final double _gridSize = 40.0;
  final Color _gridColor = Colors.white.withOpacity(0.1);

  // 가상 캔버스 크기
  final Size _virtualSize = const Size(5000, 5000);

  // 검색 결과 저장
  List<QueryResult> _queryResults = [];
  bool _isLoading = true;

  // 선택된 노드 정보 저장
  ArticleNode? _selectedNode;

  // 선택된 노드 정보 패널 위치 변수 추가
  Offset _nodeInfoPanelPosition = const Offset(20, 80); // 초기 위치

  // 더블 탭 감지를 위한 변수들 추가 (클래스 변수로)
  ArticleNode? _lastTappedNode;
  DateTime? _lastTapTime;
  final _doubleTapDuration = const Duration(milliseconds: 300); // 더블 탭 인식 시간

  // 아티클 ID 입력을 위한 컨트롤러 추가
  late TextEditingController _articleIdController;
  final FocusNode _articleIdFocusNode = FocusNode();
  bool _isSearching = false; // 검색 중인지 상태 추가

  // 태그 통계 패널 상태 변수 추가
  bool _showTagStatisticsPanel = true;
  Offset _tagStatisticsPanelPosition = const Offset(20, 120);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // 아티클 ID 컨트롤러 초기화
    _articleIdController =
        TextEditingController(text: widget.initialArticleId.toString());

    // 유사도 데이터 로드 후 아티클 불러오기
    _loadSimilarityDataAndArticles();
  }

  @override
  void dispose() {
    _controller.dispose();
    _transformationController.dispose();
    _articleIdController.dispose(); // 컨트롤러 해제
    _articleIdFocusNode.dispose(); // 포커스 노드 해제
    super.dispose();
  }

  // 유사도 데이터를 먼저 로드한 후 아티클을 불러오는 메소드 수정
  Future<void> _loadSimilarityDataAndArticles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 먼저 유사도 데이터 로드
      await _similarArticles.loadSimilarityData();

      if (_similarArticles.isLoaded) {
        // 재귀 모드에 따라 다른 로딩 방식 사용
        if (widget.useRecursiveLoading) {
          // 재귀적 방식으로 아티클 로드
          await _loadArticlesByIdRecursively(widget.initialArticleId);
        } else {
          // 비재귀적 방식으로 아티클 로드
          await _loadSimilarArticlesNonRecursive(widget.initialArticleId);
        }
      } else {
        // 유사도 데이터 로드 실패 시 에러 처리
        debugPrint('유사도 데이터 로드 실패');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('유사도 데이터 또는 아티클 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

// 재귀적으로 아티클을 불러오는 함수 구현
  // 재귀적으로 유사 아티클을 불러오는 함수
  Future<void> _loadArticlesByIdRecursively(int articleId,
      {double minSimilarity = 0.2, int depth = 0, int maxDepth = 3}) async {
    // 이미 처리한 아티클이거나 최대 깊이에 도달한 경우 중단
    if (_processedArticleIds.contains(articleId) ||
        depth > maxDepth ||
        _processedArticleIds.length >= nodeCount) {
      return;
    }

    // 현재 아티클 ID 처리 목록에 추가
    _processedArticleIds.add(articleId);

    try {
      // 현재 아티클 정보 가져오기
      final searchResult = await HentaiManager.idSearch(articleId.toString());
      _queryResults.add(searchResult.results.first);

      // 유사한 아티클 목록 가져오기
      final similarArticles = _similarArticles.getSimilarArticles(articleId);

      // 유사도별 재귀 호출 (유사도가 높은 것부터 처리)
      for (var similarArticle in similarArticles) {
        // 최소 유사도 이상인 경우만 처리
        if (similarArticle.similarity >= minSimilarity) {
          // 재귀적으로 유사 아티클 불러오기
          await _loadArticlesByIdRecursively(similarArticle.id,
              minSimilarity: minSimilarity,
              depth: depth + 1,
              maxDepth: maxDepth);
        }

        // 최대 노드 수 도달 시 중단
        if (_processedArticleIds.length >= nodeCount) {
          break;
        }
      }
    } catch (e) {
      debugPrint('아티클 $articleId 불러오기 실패: $e');
    }

    // 모든 작업이 완료되면 노드 생성 (최상위 함수에서만 호출)
    if (depth == 0) {
      setState(() {
        _createNodesWithSimilarity();
        _isLoading = false;
      });
    }
  }

  // 재귀 없이 유사 아티클을 불러오는 새로운 함수
  Future<void> _loadSimilarArticlesNonRecursive(int initialArticleId) async {
    try {
      // 초기 아티클 정보 가져오기
      final initialSearchResult =
          await HentaiManager.idSearch(initialArticleId.toString());

      if (initialSearchResult.results.isNotEmpty) {
        final initialArticle = initialSearchResult.results.first;

        debugPrint(
            '초기 아티클을 불러왔습니다: ${initialArticle.id()} - ${initialArticle.title()}');

        // 결과 목록에 초기 아티클 추가
        _queryResults.add(initialArticle);

        // ID 목록에도 추가
        _processedArticleIds.add(initialArticleId);

        // 초기 아티클과 유사한 아티클 목록 가져오기
        final similarArticles =
            _similarArticles.getSimilarArticles(initialArticleId);

        // 최대 nodeCount-1개만 가져옴 (초기 아티클 제외)
        final maxSimilarArticles =
            math.min(nodeCount - 1, similarArticles.length);

        // 유사도가 높은 아티클부터 처리
        for (int i = 0; i < maxSimilarArticles; i++) {
          final similarArticle = similarArticles[i];
          final articleId = similarArticle.id;

          // 이미 처리한 아티클인 경우 건너뜀
          if (_processedArticleIds.contains(articleId)) {
            continue;
          }

          try {
            // 아티클 정보 가져오기
            final searchResult =
                await HentaiManager.idSearch(articleId.toString());

            if (searchResult.results.isNotEmpty) {
              final article = searchResult.results.first;

              // 결과 목록에 추가
              _queryResults.add(article);

              // ID 목록에도 추가
              _processedArticleIds.add(articleId);

              debugPrint(
                  '유사 아티클 #${i + 1} 추가됨: ${article.id()} - ${article.title()} (유사도: ${similarArticle.similarity.toStringAsFixed(2)})');
            }
          } catch (e) {
            debugPrint('아티클 $articleId 불러오기 실패: $e');
          }

          // 최대 아티클 수에 도달하면 중단
          if (_processedArticleIds.length >= nodeCount) {
            break;
          }
        }

        // 모든 아티클 로드 후 노드 생성
        setState(() {
          debugPrint('총 ${_queryResults.length}개의 아티클을 불러왔습니다.');
          _createNodesWithSimilarity();
          _isLoading = false;
        });
      } else {
        debugPrint('⚠️ 초기 아티클($initialArticleId)을 찾을 수 없습니다.');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('초기 아티클 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 유사도 기반으로 노드를 생성하는 함수 수정
  void _createNodesWithSimilarity() {
    // 가상 캔버스 중심점
    final centerX = _virtualSize.width / 2;
    final centerY = _virtualSize.height / 2;

    // 초기 아티클 인덱스 찾기
    final initialArticleIndex = _queryResults
        .indexWhere((result) => result.id() == widget.initialArticleId);

    if (initialArticleIndex >= 0) {
      // 초기 아티클이 목록에 있는 경우
      debugPrint('초기 아티클 노드 생성: ${widget.initialArticleId}');
      final initialArticle = _queryResults[initialArticleIndex];

      // 중심에 초기 노드 생성
      final initialNode = ArticleNode(
        queryResult: initialArticle,
        x: centerX,
        y: centerY,
        maxWidth: _virtualSize.width,
        maxHeight: _virtualSize.height,
        groupId: 0, // 초기 아티클은 그룹 0
      );

      // 초기 노드에 특별한 스타일 적용
      initialNode.highlightColor = Colors.purple.withOpacity(0.3);
      initialNode.isSpecial = true; // 특별 속성 추가 (표시용)
      initialNode.canPierceOtherGroups = true; // 다른 그룹 관통 가능
      initialNode.collisionRadius = 350.0; // 충돌 반경 설정

      _nodes.add(initialNode);

      // 유사도 그룹 초기화
      _similarityGroups[0] = [initialNode];

      // 나머지 아티클 준비
      final List<QueryResult> remainingArticles = List.from(_queryResults);
      remainingArticles.removeAt(initialArticleIndex);

      // 각 아티클과 초기 아티클의 유사도 계산
      final Map<int, double> similarities = {};
      for (var article in remainingArticles) {
        final articleId = article.id();
        final similarity =
            _similarArticles.getSimilarity(widget.initialArticleId, articleId);
        similarities[articleId] = similarity;
      }

      // 유사도에 따라 정렬
      remainingArticles.sort((a, b) {
        final similarityA = similarities[a.id()] ?? 0.0;
        final similarityB = similarities[b.id()] ?? 0.0;
        return similarityB.compareTo(similarityA); // 내림차순 정렬
      });

      // 상위 5개와 나머지 아티클 구분
      final highSimilarityArticles = remainingArticles.take(5).toList();
      final lowSimilarityArticles = remainingArticles.length > 5
          ? remainingArticles.sublist(5)
          : <QueryResult>[];

      final random = math.Random();

      // 상위 5개 아티클 배치 (가깝게, 강하게 연결) - 겹침 방지
      for (int i = 0; i < highSimilarityArticles.length; i++) {
        final article = highSimilarityArticles[i];

        // 가까운 거리에 배치 (350-600 사이)
        // 더 넓게 분포시켜 겹침 방지
        final baseDistance = 350 + (250 * (i / highSimilarityArticles.length));

        // 원형으로 고르게 배치 - 각도 간격 넓게
        final angle = (i * (2 * math.pi / 5)) + (random.nextDouble() * 0.2);

        // 위치 계산
        final x = centerX + math.cos(angle) * baseDistance;
        final y = centerY + math.sin(angle) * baseDistance;

        // 강한 연결 그룹
        final groupId = 0; // 상위 5개는 모두 그룹 0 (강한 연결)

        // 노드 생성
        final node = ArticleNode(
          queryResult: article,
          x: x,
          y: y,
          maxWidth: _virtualSize.width,
          maxHeight: _virtualSize.height,
          groupId: groupId,
        );

        // 설정 - 느린 움직임, 강한 연결
        node.maxVelocity = 1.0;
        node.velocityX = (random.nextDouble() - 0.5) * 0.8;
        node.velocityY = (random.nextDouble() - 0.5) * 0.8;
        node.canPierceOtherGroups = true; // 다른 그룹 관통 가능
        node.isHighSimilarity = true; // 상위 유사도 표시
        node.collisionRadius = 300.0; // 충돌 반경 설정

        // 추가 스타일링
        node.highlightColor = Colors.red.withOpacity(0.2);

        _nodes.add(node);

        // 그룹에 추가
        if (!_similarityGroups.containsKey(groupId)) {
          _similarityGroups[groupId] = [];
        }
        _similarityGroups[groupId]!.add(node);
      }

      // 나머지 낮은 유사도 아티클 배치 (멀리, 약하게 연결)
      // 다중 동심원 구조로 배치하여 겹침 방지
      final int layers = 3; // 배치할 층 수
      final nodesPerLayer = (lowSimilarityArticles.length / layers).ceil();

      for (int i = 0; i < lowSimilarityArticles.length; i++) {
        final article = lowSimilarityArticles[i];
        final articleId = article.id();
        final similarity = similarities[articleId] ?? 0.0;

        // 층 결정 (0, 1, 2, ...)
        final layer = i ~/ nodesPerLayer;

        // 층 내 인덱스
        final indexInLayer = i % nodesPerLayer;

        // 같은 층 내에서의 총 각도
        final anglePerNode = 2 * math.pi / nodesPerLayer;

        // 각 층마다 시작 각도 오프셋 추가하여 겹치지 않게
        final angleOffset = (layer.isEven) ? 0 : anglePerNode / 2;

        // 기본 거리 계산 (층이 높을수록 더 멀리)
        final baseDistance = 900 + (layer * 300);

        // 각도 계산 (같은 층에서 고르게 분포)
        final angle = indexInLayer * anglePerNode +
            angleOffset +
            (random.nextDouble() * 0.2);

        // 유사도에 따라 약간의 거리 보정 (더 유사할수록 약간 더 가까이)
        final distanceAdjust = similarity * 100;

        // 위치 계산
        final x = centerX + math.cos(angle) * (baseDistance - distanceAdjust);
        final y = centerY + math.sin(angle) * (baseDistance - distanceAdjust);

        // 유사도에 따른 그룹 인덱스 계산 (1-4 그룹, 1이 더 높은 유사도)
        final groupId = 1 + (4 - (similarity / 0.25).ceil()).clamp(0, 3);

        // 노드 생성
        final node = ArticleNode(
          queryResult: article,
          x: x,
          y: y,
          maxWidth: _virtualSize.width,
          maxHeight: _virtualSize.height,
          groupId: groupId,
        );

        // 설정 - 빠른 움직임, 약한 연결
        node.maxVelocity = 1.5 + random.nextDouble() * 1.5; // 속도 약간 줄임
        node.velocityX = (random.nextDouble() - 0.5) * node.maxVelocity;
        node.velocityY = (random.nextDouble() - 0.5) * node.maxVelocity;
        node.canPierceOtherGroups = true; // 다른 그룹 관통 가능
        node.isHighSimilarity = false; // 낮은 유사도 표시
        node.collisionRadius = 250.0; // 충돌 반경 설정

        _nodes.add(node);

        // 그룹에 추가
        if (!_similarityGroups.containsKey(groupId)) {
          _similarityGroups[groupId] = [];
        }
        _similarityGroups[groupId]!.add(node);
      }

      // 초기 충돌 해결을 위한 시뮬레이션 반복
      _runInitialCollisionResolution();
    } else {
      // 초기 아티클이 목록에 없는 경우 처리 (기존 코드와 동일)
      // ...
    }

    // 변환 컨트롤러 초기화 - 초기 아티클이 있는 위치로 이동

    // 가상 캔버스 중심점 (이미 정의됨)
    // final centerX = _virtualSize.width / 2;
    // final centerY = _virtualSize.height / 2;

    // 스케일을 0.8로 설정하여 더 넓은 범위를 볼 수 있게 함
    final initialScale = 0.8;

    // 초기 위치 계산
    // 중요: vector_math.Vector3에서 setTranslation 값을 설정할 때
    // 화면 중앙에 초기 작품이 오도록 계산해야 함
    final matrix = Matrix4.identity();
    matrix.setEntry(0, 0, initialScale);
    matrix.setEntry(1, 1, initialScale);
    matrix.setEntry(2, 2, initialScale);
    matrix.setEntry(3, 3, 1.0);

    // 변환 계산 수정: 화면 중앙에 초기 노드가 오도록 계산
    // 핵심 포인트: centerX, centerY는 이미 초기 노드의 위치이기 때문에
    // 이 좌표가 화면 중앙에 위치하도록 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 화면 중앙에 노드가 오도록 변환
    matrix.setTranslation(vector_math.Vector3(
      screenWidth / 2 - centerX * initialScale,
      screenHeight / 2 - centerY * initialScale,
      0.0,
    ));

    _transformationController.value = matrix;

    // 현재 스케일과 오프셋 값 갱신
    _scale = getScaleFromTransform();
    _offset = getOffsetFromTransform();

    debugPrint('초기 화면 설정: 스케일=$initialScale, 위치=$centerX, $centerY');
  }

  // 초기 충돌 해결을 위한 시뮬레이션
  void _runInitialCollisionResolution() {
    // 초기에 100번의 시뮬레이션을 통해 노드들이 서로 밀어내도록 함
    for (int iteration = 0; iteration < 100; iteration++) {
      bool anyCollision = false;

      // 모든 노드 쌍에 대해 충돌 검사 및 해결
      for (int i = 0; i < _nodes.length; i++) {
        for (int j = i + 1; j < _nodes.length; j++) {
          final node1 = _nodes[i];
          final node2 = _nodes[j];

          // 두 노드 간 거리 계산
          final dx = node2.x - node1.x;
          final dy = node2.y - node1.y;
          final distanceSquared = dx * dx + dy * dy;

          // 충돌 반경의 합
          final minDistance = node1.collisionRadius + node2.collisionRadius;

          // 충돌이 발생한 경우
          if (distanceSquared < minDistance * minDistance) {
            anyCollision = true;

            // 거리 계산
            final distance = math.sqrt(distanceSquared);
            final overlap = minDistance - distance;

            // 밀어내는 방향 계산
            final dirX = dx / distance;
            final dirY = dy / distance;

            // 노드 유형에 따른 밀어내는 강도 조정
            double node1Factor = 0.5;
            double node2Factor = 0.5;

            // 초기 노드는 고정
            if (node1.isSpecial) {
              node1Factor = 0.0;
              node2Factor = 1.0;
            } else if (node2.isSpecial) {
              node1Factor = 1.0;
              node2Factor = 0.0;
            }
            // 높은 유사도 노드는 덜 밀림
            else if (node1.isHighSimilarity && !node2.isHighSimilarity) {
              node1Factor = 0.3;
              node2Factor = 0.7;
            } else if (!node1.isHighSimilarity && node2.isHighSimilarity) {
              node1Factor = 0.7;
              node2Factor = 0.3;
            }

            // 노드 위치 조정
            node1.x -= dirX * overlap * node1Factor;
            node1.y -= dirY * overlap * node1Factor;
            node2.x += dirX * overlap * node2Factor;
            node2.y += dirY * overlap * node2Factor;
          }
        }
      }

      // 더 이상 충돌이 없으면 종료
      if (!anyCollision) break;
    }

    // 시뮬레이션 후 초기 속도 부여
    final random = math.Random();
    for (var node in _nodes) {
      if (!node.isSpecial) {
        // 초기 노드는 제외
        // 높은 유사도 노드는 느리게
        if (node.isHighSimilarity) {
          node.velocityX = (random.nextDouble() - 0.5) * 0.8;
          node.velocityY = (random.nextDouble() - 0.5) * 0.8;
        } else {
          node.velocityX = (random.nextDouble() - 0.5) * node.maxVelocity;
          node.velocityY = (random.nextDouble() - 0.5) * node.maxVelocity;
        }
      }
    }
  }

  // TransformationController에서 현재 스케일 가져오기
  double getScaleFromTransform() {
    final matrix = _transformationController.value;
    return matrix.getMaxScaleOnAxis();
  }

  // TransformationController에서 현재 오프셋 가져오기
  Offset getOffsetFromTransform() {
    final matrix = _transformationController.value;
    return Offset(matrix.getTranslation().x, matrix.getTranslation().y);
  }

  void _resetToCenter() {
    setState(() {
      // 가상 캔버스 중심점 (초기 노드의 위치)
      final centerX = _virtualSize.width / 2;
      final centerY = _virtualSize.height / 2;

      // 중심으로 이동하되 적절한 스케일 설정
      final initialScale = 0.8;

      final matrix = Matrix4.identity();
      matrix.setEntry(0, 0, initialScale);
      matrix.setEntry(1, 1, initialScale);
      matrix.setEntry(2, 2, initialScale);
      matrix.setEntry(3, 3, 1.0);

      // 화면 중앙에 초기 작품이 오도록 계산
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;

      matrix.setTranslation(vector_math.Vector3(
        screenWidth / 2 - centerX * initialScale,
        screenHeight / 2 - centerY * initialScale,
        0.0,
      ));

      _transformationController.value = matrix;

      // 현재 스케일과 오프셋 값 갱신
      _scale = getScaleFromTransform();
      _offset = getOffsetFromTransform();

      // 스낵바로 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('초기 작품으로 화면을 이동했습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  // 크기 및 위치 변경 핸들러
  void _handleTransformation(ScaleEndDetails details) {
    setState(() {
      _scale = getScaleFromTransform();
      _offset = getOffsetFromTransform();
    });
  }

  // 앱바 위젯 생성 수정 - 텍스트필드 추가
  AppBar _buildAppBar() {
    return AppBar(
      leading: _isSearching
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  // 초기 아티클 ID로 컨트롤러 값 복원
                  _articleIdController.text =
                      widget.initialArticleId.toString();
                });
                // 포커스 해제
                FocusScope.of(context).unfocus();
              },
            )
          : null,
      title: _isSearching
          ? TextField(
              controller: _articleIdController,
              focusNode: _articleIdFocusNode,
              decoration: const InputDecoration(
                hintText: '아티클 ID 입력...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
              style: const TextStyle(fontSize: 16),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _processArticleIdInput(value);
                  // 포커스 해제
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _isSearching = false;
                  });
                }
              },
            )
          : Row(
              children: [
                const Text('Floating Article View'),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSearching = true;
                    });
                    // 약간의 지연 후 포커스 (애니메이션 완료 후)
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _articleIdFocusNode.requestFocus();
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tag, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'ID: ${widget.initialArticleId}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.useRecursiveLoading
                        ? Colors.purple
                        : Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.useRecursiveLoading ? '재귀 모드' : '일반 모드',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
      actions: [
        // 검색 아이콘으로 변경
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '아티클 ID로 검색',
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
              // 약간의 지연 후 포커스 (애니메이션 완료 후)
              Future.delayed(const Duration(milliseconds: 100), () {
                _articleIdFocusNode.requestFocus();
              });
            },
          ),
        // 검색 상태일 때는 확인 버튼
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '검색',
            onPressed: () {
              if (_articleIdController.text.isNotEmpty) {
                _processArticleIdInput(_articleIdController.text);
                // 포커스 해제
                FocusScope.of(context).unfocus();
                setState(() {
                  _isSearching = false;
                });
              }
            },
          ),
        // 로딩 모드 전환 버튼 (검색 상태가 아닐 때만)
        if (!_isSearching)
          IconButton(
            icon: Icon(
              widget.useRecursiveLoading ? Icons.account_tree : Icons.grid_view,
            ),
            tooltip: widget.useRecursiveLoading ? '일반 모드로 전환' : '재귀 모드로 전환',
            onPressed: () {
              // 반대 모드로 페이지 다시 로드
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => FloatingSimilarArticleView(
                    initialArticleId: widget.initialArticleId,
                    useRecursiveLoading: !widget.useRecursiveLoading,
                  ),
                ),
              );
            },
          ),
        // 초기 위치 버튼 (검색 상태가 아닐 때만)
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToCenter,
            tooltip: '초기 위치로 돌아가기',
          ),
        // "태그 통계 보기" 버튼 처리 수정
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: '태그 통계 보기',
            onPressed: _toggleTagStatisticsPanel,
          ),
      ],
    );
  }

  // 입력된 아티클 ID 처리 함수
  void _processArticleIdInput(String input) {
    try {
      // 입력값을 정수로 변환
      final int articleId = int.parse(input.trim());

      // 0보다 작거나 같은 ID는 무효
      if (articleId <= 0) {
        _showErrorSnackBar('유효하지 않은 아티클 ID입니다. 양수를 입력해주세요.');
        return;
      }

      // 현재 초기 아티클과 같은 ID인 경우
      if (articleId == widget.initialArticleId) {
        _showErrorSnackBar('현재 표시 중인 아티클과 동일한 ID입니다.');
        return;
      }

      // 아티클 ID 유효성 검사 후 초기 작품으로 설정 시작
      _loadAndSetNewInitialArticle(articleId);
    } catch (e) {
      _showErrorSnackBar('유효하지 않은 입력입니다. 숫자만 입력해주세요.');
    }
  }

  // 에러 스낵바 표시 함수
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 새 아티클 로드 및 초기 작품으로 설정 함수
  Future<void> _loadAndSetNewInitialArticle(int articleId) async {
    // 로딩 표시 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('아티클을 검색하는 중입니다...'),
            ],
          ),
        ),
      ),
    );

    try {
      // 해당 ID의 아티클이 존재하는지 먼저 확인
      final searchResult = await HentaiManager.idSearch(articleId.toString());

      // 다이얼로그 닫기
      Navigator.of(context).pop();

      if (searchResult.results.isEmpty) {
        _showErrorSnackBar('해당 ID의 아티클을 찾을 수 없습니다: $articleId');
        return;
      }

      final article = searchResult.results.first;

      // 아티클 정보를 표시하는 스낵바
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('아티클을 찾았습니다: ${article.title()}'),
          duration: const Duration(seconds: 2),
        ),
      );

      // 가상의 ArticleNode 생성 (임시적으로 사용, UI에는 나타나지 않음)
      final tempNode = ArticleNode(
        queryResult: article,
        x: 0, // 위치는 중요하지 않음
        y: 0, // 위치는 중요하지 않음
        maxWidth: _virtualSize.width,
        maxHeight: _virtualSize.height,
        groupId: 0,
      );

      // _setAsInitialArticle 함수 호출하여 새 초기 작품으로 설정
      _setAsInitialArticle(tempNode);
    } catch (e) {
      // 다이얼로그가 아직 열려있다면 닫기
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      _showErrorSnackBar('아티클 검색 중 오류가 발생했습니다: $e');
    }
  }

  // 격자 위젯 생성
  Widget _buildGrid() {
    return CustomPaint(
      size: _virtualSize,
      painter: InfiniteGridPainter(_gridSize, _gridColor,
          getOffsetFromTransform(), getScaleFromTransform()),
    );
  }

  // 엣지(노드 간 연결선) 위젯 생성
  Widget _buildEdges() {
    return CustomPaint(
      size: _virtualSize,
      painter: SimilarityEdgePainter(_nodes, maxDistance, _similarArticles),
    );
  }

  // 드래그 가능한 아티클 노드 위젯 생성 수정
  Widget _buildArticleNode(ArticleNode node) {
    // 그룹 ID에 따른 색상 반환
    Color getGroupColor(int groupId) {
      final colors = [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.purple,
        Colors.orange,
        Colors.teal,
        Colors.pink,
        Colors.cyan,
        Colors.amber,
      ];

      return colors[groupId % colors.length];
    }

    // 노드 스케일 계산 (기본 스케일에 다이나믹 스케일 적용)
    final baseScale =
        node.isSpecial ? 0.85 : (node.isHighSimilarity ? 0.8 : 0.75);
    final dynamicScale = baseScale * node.scale; // 동적 스케일 적용

    // 맥동 효과
    final pulsateEffect = 1.0;

    final effectiveScale = dynamicScale * pulsateEffect;

    return Positioned(
      left: node.x - 150, // 아티클 위젯의 절반 너비
      top: node.y - 200, // 아티클 위젯의 절반 높이
      child: Opacity(
        opacity: node.opacity, // 투명도 적용
        child: Transform.scale(
          scale: effectiveScale, // 동적 스케일 적용
          child: Stack(
            children: [
              // 글로우 효과 추가 (하이라이트 색상이 있고 글로우 반경이 설정된 경우)
              if (node.highlightColor != null && node.glowRadius > 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: node.highlightColor!.withOpacity(0.8),
                          blurRadius: node.glowRadius,
                          spreadRadius: node.glowRadius / 3,
                        ),
                      ],
                    ),
                  ),
                ),

              // 하이라이트 효과 추가
              if (node.highlightColor != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: node.highlightColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: node.highlightColor!.withOpacity(0.8),
                          blurRadius: node.isSpecial
                              ? 15
                              : (node.isHighSimilarity ? 12 : 10),
                          spreadRadius: node.isSpecial
                              ? 4
                              : (node.isHighSimilarity ? 3 : 2),
                        ),
                      ],
                    ),
                  ),
                ),

              _buildArticleCard(node),

              // 초기 아티클인 경우 특별 표시 추가
              if (node.isSpecial)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.9),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.star, color: Colors.yellow, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '초기 작품',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 상위 유사도 작품인 경우 표시 추가
              if (node.isHighSimilarity && !node.isSpecial)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.white, size: 14),
                        SizedBox(width: 2),
                        Text(
                          '높은 유사도',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 더블 탭 힌트 추가 (초기 작품이 아닌 경우만) - 더 눈에 띄게 수정
              if (!node.isSpecial)
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '더블탭하여 기준 작품으로',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 그룹 표시 마커 추가
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: getGroupColor(node.groupId).withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: node.isSpecial
                          ? Colors.yellow
                          : (node.isHighSimilarity ? Colors.red : Colors.white),
                      width: node.isSpecial
                          ? 3
                          : (node.isHighSimilarity ? 2.5 : 2),
                    ),
                  ),
                  child: Text(
                    '${node.groupId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 아티클 카드 위젯 생성 수정
  Widget _buildArticleCard(ArticleNode node) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // onTap과 onDoubleTap 제거 - _findNodeUnderTap에서 처리
        onLongPress: () {
          print('길게 누르기 감지됨: ${node.queryResult.id()}');
          _setAsInitialArticle(node);
        },
        child: Stack(
          children: [
            // 아티클 위젯
            _buildArticleWidget(node),

            // 드래그 핸들 - 아티클 전체 영역을 드래그 가능하게 만듦
            _buildDragHandle(node),

            // 드래그 손잡이 표시
            _buildDragIndicator(),

            // 더블 탭 힌트 아이콘 추가 - 더 명확하게 보이도록
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.touch_app,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 새로운 메서드: 작품을 초기 작품으로 설정 (수정)
  void _setAsInitialArticle(ArticleNode node) {
    print('초기 작품으로 설정 시작: ${node.queryResult.id()}');

    // 이미 초기 작품인 경우 아무 작업도 하지 않음
    if (node.isSpecial) {
      print('이미 초기 작품입니다.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 초기 작품입니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final newInitialArticleId = node.queryResult.id();
    print('새 초기 작품 ID: $newInitialArticleId');

    // 로딩 표시 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        // 뒤로 가기 버튼으로 다이얼로그 닫기 방지
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('새로운 초기 작품으로 페이지를 재구성 중입니다...'),
            ],
          ),
        ),
      ),
    );

    // 약간의 지연을 주어 로딩 다이얼로그가 표시되도록 함
    Future.delayed(const Duration(milliseconds: 300), () {
      print('초기화 작업 시작');

      if (!mounted) {
        print('위젯이 더 이상 마운트되지 않음');
        return;
      }

      // 상태 초기화
      setState(() {
        _nodes.clear();
        _similarityGroups.clear();
        _processedArticleIds.clear();
        _queryResults.clear();
        _selectedNode = null;
        _draggedNode = null;
        _isLoading = true;

        // 더블 탭 상태 초기화
        _lastTappedNode = null;
        _lastTapTime = null;
      });

      // 다이얼로그 닫기
      Navigator.of(context).pop();

      // 새로운 초기 작품으로 페이지 재구성
      _loadSimilarityDataAndArticlesWithNewInitial(newInitialArticleId);
    });
  }

  // 새로운 초기 작품으로 데이터를 로드하는 메서드
  Future<void> _loadSimilarityDataAndArticlesWithNewInitial(
      int newInitialArticleId) async {
    try {
      // 유사도 데이터가 이미 로드되어 있으므로 바로 아티클 로드
      if (_similarArticles.isLoaded) {
        // 재귀 모드에 따라 다른 로딩 방식 사용
        if (widget.useRecursiveLoading) {
          await _loadArticlesByIdRecursively(newInitialArticleId);
        } else {
          await _loadSimilarArticlesNonRecursive(newInitialArticleId);
        }

        // 여기서는 _createNodesWithSimilarity()가 호출되므로 추가 설정 불필요

        // 새로운 페이지로 이동
        _navigateToNewPage(newInitialArticleId);
      } else {
        // 유사도 데이터가 로드되지 않은 경우 (이 경우는 드물지만 안전을 위해 처리)
        await _similarArticles.loadSimilarityData();

        if (_similarArticles.isLoaded) {
          // 재귀 모드에 따라 다른 로딩 방식 사용
          if (widget.useRecursiveLoading) {
            await _loadArticlesByIdRecursively(newInitialArticleId);
          } else {
            await _loadSimilarArticlesNonRecursive(newInitialArticleId);
          }
          _navigateToNewPage(newInitialArticleId);
        } else {
          // 유사도 데이터 로드 실패 시 에러 처리
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('유사도 데이터 로드 실패, 다시 시도해주세요.'),
              duration: Duration(seconds: 3),
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('새 초기 작품 설정 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 새로운 페이지로 이동하는 메서드 수정 - 재귀 옵션 유지
  void _navigateToNewPage(int newInitialArticleId) {
    try {
      print('새 페이지로 이동 시작: $newInitialArticleId');
      // 현재 페이지는 닫고 새 페이지를 열어서 애니메이션 효과와 함께 전환
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => FloatingSimilarArticleView(
            initialArticleId: newInitialArticleId,
            useRecursiveLoading: widget.useRecursiveLoading, // 재귀 모드 옵션 유지
          ),
        ),
      );
      print('새 페이지로 이동 완료');
    } catch (e) {
      print('페이지 이동 오류: $e');
      // 오류 발생 시 로딩 상태 종료
      setState(() {
        _isLoading = false;
      });

      // 사용자에게 오류 알림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('페이지 이동 중 오류가 발생했습니다: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // 아티클 위젯 생성 (Provider 적용)
  Widget _buildArticleWidget(ArticleNode node) {
    return Provider<ArticleListItem>.value(
      value: ArticleListItem.fromArticleListItem(
        queryResult: node.queryResult,
        showDetail: false,
        width: 300, // 적당한 너비
        thumbnailTag: const Uuid().v4(),
        usableTabList: _queryResults,
        addBottomPadding: false,
      ),
      child: const ArticleListItemWidget(),
    );
  }

  // 드래그 핸들 위젯 생성
  Widget _buildDragHandle(ArticleNode node) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _draggedNode == node
                ? Colors.blue.withOpacity(0.8)
                : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // 드래그 표시자 위젯 생성
  Widget _buildDragIndicator() {
    return Positioned(
      top: 5,
      right: 5,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.drag_indicator,
          color: Colors.white70,
          size: 16,
        ),
      ),
    );
  }

  // 사용 설명 패널 위젯 수정 - 아티클 ID 입력 기능 설명 추가
  Widget _buildInstructionPanel() {
    return Positioned(
      bottom: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.useRecursiveLoading
                ? Colors.purple.withOpacity(0.5)
                : Colors.blue.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 모드 표시 추가
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: widget.useRecursiveLoading
                    ? Colors.purple.withOpacity(0.7)
                    : Colors.blue.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.useRecursiveLoading
                    ? '재귀 모드: 깊이 우선 탐색'
                    : '일반 모드: 유사도 기반 로딩',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const Text(
              '• 아티클을 탭하면 유사작품 모으기',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '• 아티클을 더블 탭하면 초기 작품으로 설정',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '• 아티클을 드래그해서 움직이기',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '• 핀치로 줌인/줌아웃',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '• 배경을 드래그해서 이동',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '• 앱바에서 모드 전환 가능',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '• 앱바의 검색 아이콘으로 아티클 ID 직접 입력 가능',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '• 상단의 ID를 탭하여 새 아티클로 변경 가능',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // 정보 패널 위젯 생성
  Widget _buildInfoPanel() {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 확대 배율 표시
            Text(
              '확대 배율: ${_scale.toStringAsFixed(2)}x',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            // 현재 위치 표시
            Text(
              '위치: (${(-_offset.dx / _scale).toStringAsFixed(0)}, ${(-_offset.dy / _scale).toStringAsFixed(0)})',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            // 정중앙 버튼
            _buildCenterButton(),
          ],
        ),
      ),
    );
  }

  // 중앙으로 이동 버튼 위젯 생성
  Widget _buildCenterButton() {
    return ElevatedButton.icon(
      onPressed: _resetToCenter,
      icon: const Icon(Icons.center_focus_strong, size: 16),
      label: const Text('원점으로'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.withOpacity(0.8),
        foregroundColor: Colors.white,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  // 원점 이동 플로팅 버튼 위젯 생성
  Widget _buildFloatingCenterButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        onPressed: _resetToCenter,
        backgroundColor: Colors.blue.withOpacity(0.8),
        mini: true,
        child: const Icon(Icons.my_location, size: 20),
      ),
    );
  }

  // 인터랙티브 캔버스 위젯 생성
  Widget _buildInteractiveCanvas() {
    return Container(
      color: Colors.black87,
      width: double.infinity,
      height: double.infinity,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: _minScale,
        maxScale: _maxScale,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        constrained: false,
        clipBehavior: Clip.none,
        onInteractionUpdate: (details) {
          setState(() {
            _scale = getScaleFromTransform();
            _offset = getOffsetFromTransform();
          });
        },
        onInteractionEnd: _handleTransformation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox.fromSize(
              size: _virtualSize,
              child: AnimatedBuilder(
                animation: _controller,
                builder: _buildAnimatedContent,
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: _findNodeUnderTap,
                onPanStart: _handleGlobalPanStart,
                onPanUpdate: _handleGlobalPanUpdate,
                onPanEnd: _handleGlobalPanEnd,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 애니메이션 콘텐츠 빌더 개선
  Widget _buildAnimatedContent(BuildContext context, Widget? child) {
    // 그룹별 중심점 계산
    Map<int, Offset> groupCenters = {};
    Map<int, int> groupCounts = {};
    List<int> sortedGroupIds = [];

    // 각 그룹의 평균 위치 계산 및 그룹 ID 수집
    for (var node in _nodes) {
      if (!groupCenters.containsKey(node.groupId)) {
        groupCenters[node.groupId] = Offset(node.x, node.y);
        groupCounts[node.groupId] = 1;
        sortedGroupIds.add(node.groupId);
      } else {
        final currentCenter = groupCenters[node.groupId]!;
        final currentCount = groupCounts[node.groupId]!;

        // 누적 합계 갱신
        groupCenters[node.groupId] =
            Offset(currentCenter.dx + node.x, currentCenter.dy + node.y);
        groupCounts[node.groupId] = currentCount + 1;
      }
    }

    // 그룹 ID 정렬
    sortedGroupIds.sort();

    // 평균 계산
    groupCenters.forEach((groupId, totalOffset) {
      final count = groupCounts[groupId]!;
      groupCenters[groupId] =
          Offset(totalOffset.dx / count, totalOffset.dy / count);
    });

    // 속도 감쇠 계수 설정 (진동 방지)
    final dampingFactor = 0.98; // 감쇠 조금 줄임

    // 노드 움직임 업데이트 및 노드 간 간격 유지
    for (var node in _nodes) {
      if (_draggedNode != node) {
        // 속도 감쇠 추가 - 진동 방지
        node.velocityX *= dampingFactor;
        node.velocityY *= dampingFactor;

        // 아주 작은 속도는 0으로 설정
        if (node.velocityX.abs() < 0.03) node.velocityX = 0;
        if (node.velocityY.abs() < 0.03) node.velocityY = 0;

        // 위치 업데이트
        node.update(_controller.value);

        // 유사도에 따른 인력 효과 적용
        if (node.isAttracted && node.attractionTarget != null) {
          final targetNode = node.attractionTarget!;
          final dirX = targetNode.x - node.x;
          final dirY = targetNode.y - node.y;
          final distance = math.sqrt(dirX * dirX + dirY * dirY);

          if (distance > 0) {
            // 거리가 가까울수록 인력 감소 (너무 가깝게 뭉치지 않도록)
            final distanceFactor = math.min(1.0, distance / 400);

            // 유사도에 비례하는 인력 적용
            node.velocityX +=
                dirX / distance * node.attractionFactor * distanceFactor * 0.08;
            node.velocityY +=
                dirY / distance * node.attractionFactor * distanceFactor * 0.08;
          }
        }
      }
    }

    // 충돌 처리 개선 - 다중 반복으로 안정성 향상
    // 여러 번 반복하여 복잡한 충돌도 안정적으로 해결
    for (int iteration = 0; iteration < 3; iteration++) {
      for (int i = 0; i < _nodes.length; i++) {
        for (int j = i + 1; j < _nodes.length; j++) {
          _nodes[i].resolveCollision(_nodes[j]);
        }
      }
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        _buildGrid(),
        _buildEdges(),
        ..._nodes.map(_buildArticleNode).toList(),
      ],
    );
  }

  // 탭으로 노드 찾기 - 선택 정보 업데이트 및 더블 탭 처리 추가
  void _findNodeUnderTap(TapDownDetails details) {
    // 화면 좌표를 가상 공간 좌표로 변환
    final invertedMatrix = Matrix4.inverted(_transformationController.value);
    final virtualPosition =
        MatrixUtils.transformPoint(invertedMatrix, details.globalPosition);

    print('Tap detected at: ${virtualPosition.dx}, ${virtualPosition.dy}');

    // 모든 노드 검사
    for (var node in _nodes) {
      // 노드의 충돌 영역 계산 (이미 UI 위치에 맞게 수정됨)
      final nodeBounds = node.bounds;

      // 탭 위치가 노드 내부에 있는지 확인
      if (nodeBounds.contains(virtualPosition)) {
        print('노드 선택됨: ${node.queryResult.id()}');

        // 더블 탭 감지 로직
        final now = DateTime.now();

        if (_lastTappedNode == node &&
            _lastTapTime != null &&
            now.difference(_lastTapTime!) <= _doubleTapDuration) {
          // 더블 탭으로 판단
          print('더블 탭 감지됨: ${node.queryResult.id()}');
          _setAsInitialArticle(node);

          // 더블 탭 감지 후 상태 초기화
          _lastTappedNode = null;
          _lastTapTime = null;
          return;
        }

        // 첫 번째 탭이거나 다른 노드를 탭한 경우
        _lastTappedNode = node;
        _lastTapTime = now;

        setState(() {
          // 이전에 선택된 노드와 다른 경우에만 패널 위치 초기화
          if (_selectedNode != node) {
            _nodeInfoPanelPosition = const Offset(20, 80); // 패널 위치 초기화
          }
          _selectedNode = node; // 선택된 노드 저장
          _draggedNode = node;
          node.isDraggable = false;
          _dragPosition = virtualPosition;

          // 유사한 작품들 모으기
          _attractSimilarNodes(node);
        });
        return;
      }
    }

    // 빈 공간 탭 시 선택 해제
    setState(() {
      _selectedNode = null;
      // 빈 공간 탭 시 모든 노드 원래 상태로 복원
      _resetNodeAttraction();
    });

    // 빈 공간 탭 시 더블 탭 감지 상태 초기화
    _lastTappedNode = null;
    _lastTapTime = null;

    print('선택된 노드 없음');
  }

  // 새로 추가: 유사한 작품들을 모으는 메서드
  void _attractSimilarNodes(ArticleNode centerNode) {
    final selectedId = centerNode.queryResult.id();

    // 모든 노드에 대해 선택된 노드와의 유사도 계산
    for (var node in _nodes) {
      if (node != centerNode) {
        final nodeId = node.queryResult.id();
        final similarity = _similarArticles.getSimilarity(selectedId, nodeId);

        // 유사도에 따라 특수 효과 적용 (임시 속성 추가)
        node.isAttracted = true;
        node.attractionFactor = similarity * 5.0; // 유사도가 높을수록 더 강한 인력

        // 유사도에 따라 색상 효과 적용
        if (similarity > 0.7) {
          // 매우 유사한 작품
          node.highlightColor = Colors.red.withOpacity(0.3);
          node.attractionTarget = centerNode;
        } else if (similarity > 0.4) {
          // 중간 정도 유사한 작품
          node.highlightColor = Colors.orange.withOpacity(0.3);
          node.attractionTarget = centerNode;
        } else if (similarity > 0.2) {
          // 약간 유사한 작품
          node.highlightColor = Colors.blue.withOpacity(0.2);
          node.attractionTarget = centerNode;
        } else {
          // 유사하지 않은 작품
          node.isAttracted = false;
          node.highlightColor = null;
          node.attractionTarget = null;
        }
      } else {
        // 선택된 노드 자신은 특별 효과
        centerNode.isAttracted = false;
        centerNode.highlightColor = Colors.purple.withOpacity(0.3);
      }
    }
  }

  // 새로 추가: 노드 인력 효과 초기화
  void _resetNodeAttraction() {
    for (var node in _nodes) {
      node.isAttracted = false;
      node.attractionFactor = 0;
      node.highlightColor = null;
      node.attractionTarget = null;
    }
  }

  // 글로벌 팬 시작 핸들러
  void _handleGlobalPanStart(DragStartDetails details) {
    // 화면 좌표를 가상 공간 좌표로 변환
    final invertedMatrix = Matrix4.inverted(_transformationController.value);
    final virtualPosition =
        MatrixUtils.transformPoint(invertedMatrix, details.globalPosition);

    print('Pan start at: ${virtualPosition.dx}, ${virtualPosition.dy}');

    // 모든 노드 검사하여 드래그할 노드 찾기
    for (var node in _nodes) {
      // 노드의 충돌 영역 계산
      final nodeBounds = node.bounds;

      // 확장된 히트 테스트 영역 (약간 더 큰 영역으로 체크)
      final expandedBounds = Rect.fromLTWH(nodeBounds.left - 20,
          nodeBounds.top - 20, nodeBounds.width + 40, nodeBounds.height + 40);

      // 터치 위치가 확장된 노드 영역 내부에 있는지 확인
      if (expandedBounds.contains(virtualPosition)) {
        print('드래그 시작: ${node.queryResult.id}');
        setState(() {
          _draggedNode = node;
          node.isDraggable = false;
          _dragPosition = virtualPosition;
        });
        return;
      }
    }
  }

  // 글로벌 팬 업데이트 핸들러
  void _handleGlobalPanUpdate(DragUpdateDetails details) {
    if (_draggedNode != null && _dragPosition != null) {
      // 화면 좌표를 가상 공간 좌표로 변환
      final invertedMatrix = Matrix4.inverted(_transformationController.value);
      final virtualPosition =
          MatrixUtils.transformPoint(invertedMatrix, details.globalPosition);

      final dx = virtualPosition.dx - _dragPosition!.dx;
      final dy = virtualPosition.dy - _dragPosition!.dy;

      print('드래그 업데이트: dx=$dx, dy=$dy');

      setState(() {
        _draggedNode!.x += dx;
        _draggedNode!.y += dy;
        _dragPosition = virtualPosition;
      });
    }
  }

  // 글로벌 팬 종료 핸들러
  void _handleGlobalPanEnd(DragEndDetails details) {
    if (_draggedNode != null) {
      print('드래그 종료');
      setState(() {
        _draggedNode!.isDraggable = true;
        _draggedNode = null;
        _dragPosition = null;
      });
    }
  }

  // 선택된 노드 정보 패널 위젯 생성 (유사도 및 태그 정보 추가)
  Widget _buildSelectedNodeInfo() {
    if (_selectedNode == null) return const SizedBox.shrink();

    final node = _selectedNode!;
    final queryResult = node.queryResult;

    // 초기 작품과의 유사도 계산
    double similarityValue = 0.0;
    ArticleNode? initialNode;

    // 초기 노드 찾기
    for (var n in _nodes) {
      if (n.isSpecial) {
        initialNode = n;
        break;
      }
    }

    // 초기 노드를 찾았고, 선택된 노드가 초기 노드가 아닌 경우
    if (initialNode != null && !node.isSpecial) {
      similarityValue = _similarArticles.getSimilarity(
          initialNode.queryResult.id(), queryResult.id());
    }

    return Positioned(
      top: _nodeInfoPanelPosition.dy,
      right: _nodeInfoPanelPosition.dx,
      child: GestureDetector(
        // 드래그 관련 코드 유지
        onPanStart: (details) {
          // 드래그 시작 시점에 별도 처리가 필요하면 여기에 추가
        },
        onPanUpdate: (details) {
          setState(() {
            _nodeInfoPanelPosition = Offset(
                _nodeInfoPanelPosition.dx - details.delta.dx,
                _nodeInfoPanelPosition.dy + details.delta.dy);
          });
        },
        onPanEnd: (details) {
          // 드래그 종료 시점에 별도 처리가 필요하면 여기에 추가
        },
        child: Container(
          width: 320, // 약간 더 넓게 조정
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: node.isSpecial
                  ? Colors.purpleAccent.withOpacity(0.7)
                  : (node.isHighSimilarity
                      ? Colors.redAccent.withOpacity(0.7)
                      : Colors.blue.withOpacity(0.5)),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: node.isSpecial
                    ? Colors.purple.withOpacity(0.4)
                    : (node.isHighSimilarity
                        ? Colors.red.withOpacity(0.3)
                        : Colors.blue.withOpacity(0.2)),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 섹션 - 제목 표시줄
              _buildInfoHeader(node),

              // 컨텐츠 섹션 - 작품 정보
              _buildInfoContent(queryResult),

              // 유사도 정보 (초기 노드가 아닌 경우만)
              if (!node.isSpecial && initialNode != null)
                _buildSimilarityInfo(similarityValue, initialNode.queryResult),

              // 태그 섹션
              _buildTagSection(queryResult),

              // 액션 섹션 - 버튼 및 기타 액션 제공
              _buildActionSection(queryResult),
            ],
          ),
        ),
      ),
    );
  }

  // 정보 패널 헤더 섹션
  Widget _buildInfoHeader(ArticleNode node) {
    final statusText =
        node.isSpecial ? '초기 작품' : (node.isHighSimilarity ? '높은 유사도' : '');
    final statusIcon = node.isSpecial
        ? Icons.star
        : (node.isHighSimilarity ? Icons.trending_up : null);
    final statusColor = node.isSpecial
        ? Colors.purpleAccent
        : (node.isHighSimilarity ? Colors.redAccent : Colors.transparent);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: node.isSpecial
              ? [
                  Colors.purple.withOpacity(0.7),
                  Colors.deepPurple.withOpacity(0.7)
                ]
              : (node.isHighSimilarity
                  ? [
                      Colors.red.withOpacity(0.6),
                      Colors.deepOrange.withOpacity(0.6)
                    ]
                  : [
                      Colors.blue.withOpacity(0.5),
                      Colors.blueAccent.withOpacity(0.5)
                    ]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 드래그 핸들 + 타이틀
          Row(
            children: [
              const Icon(Icons.drag_handle, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text(
                '선택된 아티클 정보',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              // 상태 아이콘 (있는 경우만)
              if (statusIcon != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // 닫기 버튼
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _selectedNode = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // 정보 패널 컨텐츠 섹션 (작품 정보)
  Widget _buildInfoContent(QueryResult queryResult) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기본 정보 섹션
          _buildInfoItem('ID', queryResult.id().toString(), Icons.tag),
          _buildInfoItem('제목', queryResult.title(), Icons.title),
          _buildInfoItem(
              '페이지 수', queryResult.files().toString(), Icons.photo_library),

          // 추가 정보가 있다면 여기에 더 추가
        ],
      ),
    );
  }

  // 세련된 정보 아이템 생성 헬퍼 함수
  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white70, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 액션 섹션 개선
  Widget _buildActionSection(QueryResult queryResult) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Row(
            children: [
              // 아티클 열기 버튼
              Expanded(
                child: _buildActionButton(
                  icon: Icons.article_outlined,
                  label: '아티클 열기',
                  onPressed: () {
                    // 아티클 페이지로 이동
                    showArticleInfoById(context, queryResult.id());
                  },
                ),
              ),
              const SizedBox(width: 10),
              // 뷰어 열기 버튼
              Expanded(
                child: _buildActionButton(
                  icon: Icons.visibility,
                  label: '뷰어 열기',
                  onPressed: () {
                    // 뷰어 페이지로 이동
                    showViewer(context, queryResult.id(), 0);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 액션 버튼 위젯 개선
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 3,
      ),
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 유사도 정보 위젯
  Widget _buildSimilarityInfo(
      double similarityValue, QueryResult initialArticle) {
    // 유사도에 따른 색상 설정
    Color similarityColor;
    String similarityText;

    if (similarityValue > 0.8) {
      similarityColor = Colors.red;
      similarityText = '매우 높음';
    } else if (similarityValue > 0.6) {
      similarityColor = Colors.orange;
      similarityText = '높음';
    } else if (similarityValue > 0.4) {
      similarityColor = Colors.yellow;
      similarityText = '중간';
    } else if (similarityValue > 0.2) {
      similarityColor = Colors.lightBlue;
      similarityText = '낮음';
    } else {
      similarityColor = Colors.grey;
      similarityText = '매우 낮음';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              const Text(
                '초기 작품과의 유사도',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 유사도 퍼센트 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: similarityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: similarityColor.withOpacity(0.5)),
                ),
                child: Text(
                  '${(similarityValue * 100).toInt()}%',
                  style: TextStyle(
                    color: similarityColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 유사도 텍스트 표시
              Text(
                similarityText,
                style: TextStyle(
                  color: similarityColor.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // 초기 작품 ID 표시
              Text(
                '초기 작품 ID: ${initialArticle.id()}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 유사도 프로그레스 바
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: similarityValue,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(similarityColor),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // 태그 섹션 위젯 수정 - queryResult의 다양한 태그 필드 활용
  Widget _buildTagSection(QueryResult queryResult) {
    // 태그 유형별 색상 매핑
    Map<String, Color> tagTypeColors = {
      'artist': Colors.pink,
      'character': Colors.purple,
      'group': Colors.orange,
      'female': Colors.red,
      'male': Colors.blue,
      'language': Colors.green,
      'series': Colors.teal,
      'tags': Colors.grey,
      'uploader': Colors.amber,
      // 필요에 따라 더 많은 유형 추가
    };

    // 모든 태그 컬렉션 생성
    Map<String, List<String>> allTags = {};

    // 일반 태그 (female, male, tags) 처리
    if (queryResult.tags() != null) {
      final tagsString = queryResult.tags() as String;

      // 파이프로 분리된 태그들 처리
      final basicTags =
          tagsString.split('|').where((element) => element.trim().isNotEmpty);

      // 각 태그 분석
      for (var tag in basicTags) {
        if (tag.contains(':')) {
          // 콜론이 있는 경우 (유형:값)
          final parts = tag.split(':');
          final tagType = parts[0].trim();
          final tagValue = parts[1].trim();

          if (!allTags.containsKey(tagType)) {
            allTags[tagType] = [];
          }

          allTags[tagType]!.add(tagValue);
        } else {
          // 콜론이 없는 경우 (기본 태그)
          if (!allTags.containsKey('tags')) {
            allTags['tags'] = [];
          }

          allTags['tags']!.add(tag.trim());
        }
      }
    }

    // artist 태그 처리
    if (queryResult.artists() != null &&
        queryResult.artists().toString().isNotEmpty) {
      allTags['artist'] = queryResult
          .artists()
          .toString()
          .split('|')
          .where((element) => element.trim().isNotEmpty)
          .toList();
    }

    // character 태그 처리
    if (queryResult.characters() != null &&
        queryResult.characters().toString().isNotEmpty) {
      allTags['character'] = queryResult
          .characters()
          .toString()
          .split('|')
          .where((element) => element.trim().isNotEmpty)
          .toList();
    }

    // group 태그 처리
    if (queryResult.groups() != null &&
        queryResult.groups().toString().isNotEmpty) {
      allTags['group'] = queryResult
          .groups()
          .toString()
          .split('|')
          .where((element) => element.trim().isNotEmpty)
          .toList();
    }

    // language 태그 처리
    if (queryResult.language() != null &&
        queryResult.language().toString().isNotEmpty) {
      allTags['language'] = [queryResult.language().toString()];
    }

    // series 태그 처리
    if (queryResult.series() != null &&
        queryResult.series().toString().isNotEmpty) {
      allTags['series'] = queryResult
          .series()
          .toString()
          .split('|')
          .where((element) => element.trim().isNotEmpty)
          .toList();
    }

    // uploader 태그 처리
    if (queryResult.uploader() != null &&
        queryResult.uploader().toString().isNotEmpty) {
      allTags['uploader'] = [queryResult.uploader().toString()];
    }

    // 태그가 없으면 위젯을 표시하지 않음
    if (allTags.isEmpty) return const SizedBox.shrink();

    // 총 태그 수 계산
    int totalTagCount = 0;
    allTags.forEach((key, value) {
      totalTagCount += value.length;
    });

    // 태그 표시 순서 정의 (중요한 태그 유형부터)
    final tagDisplayOrder = [
      'artist',
      'character',
      'series',
      'group',
      'female',
      'male',
      'language',
      'uploader',
      'tags'
    ];

    // 위 순서에 없는 태그 유형들은 사전순으로 정렬하여 마지막에 표시
    final remainingTagTypes = allTags.keys
        .where((type) => !tagDisplayOrder.contains(type))
        .toList()
      ..sort();

    // 최종 표시 순서
    final finalDisplayOrder = [...tagDisplayOrder, ...remainingTagTypes];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 태그 섹션 헤더
          Row(
            children: [
              const Icon(Icons.local_offer, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              const Text(
                '태그',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '총 $totalTagCount개',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 정해진 순서대로 태그 그룹 표시
          ...finalDisplayOrder.map((tagType) {
            // 해당 유형의 태그가 없으면 표시하지 않음
            if (!allTags.containsKey(tagType) || allTags[tagType]!.isEmpty) {
              return const SizedBox.shrink();
            }

            // 유형별 아이콘 선택
            IconData tagIcon;
            switch (tagType) {
              case 'artist':
                tagIcon = Icons.brush;
                break;
              case 'character':
                tagIcon = Icons.person;
                break;
              case 'group':
                tagIcon = Icons.group;
                break;
              case 'female':
                tagIcon = Icons.female;
                break;
              case 'male':
                tagIcon = Icons.male;
                break;
              case 'language':
                tagIcon = Icons.language;
                break;
              case 'series':
                tagIcon = Icons.book;
                break;
              case 'uploader':
                tagIcon = Icons.upload;
                break;
              case 'tags':
                tagIcon = Icons.tag;
                break;
              default:
                tagIcon = Icons.label;
            }

            final tagColor = tagTypeColors[tagType] ?? Colors.grey;
            final tagsList = allTags[tagType]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 태그 유형 헤더
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 6, top: 8),
                  decoration: BoxDecoration(
                    color: tagColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tagIcon, size: 12, color: tagColor),
                      const SizedBox(width: 4),
                      Text(
                        tagType,
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${tagsList.length})',
                        style: TextStyle(
                          color: tagColor.withOpacity(0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                // 태그 목록
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tagsList.map((tagValue) {
                    return InkWell(
                      onTap: () {
                        // 태그 탭 시 동작 (옵션)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('태그: $tagValue'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tagColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: tagColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          tagValue,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  // 태그 통계 수집 함수
  Map<String, Map<String, int>> _collectTagStatistics() {
    // 태그 유형별 통계 맵
    // 형식: {'태그 유형': {'태그 값': 등장 횟수}}
    Map<String, Map<String, int>> statistics = {
      'female': {},
      'male': {},
      'tags': {},
    };

    // 모든 작품을 순회하며 태그 데이터 수집
    for (var node in _nodes) {
      final queryResult = node.queryResult;

      // tags 필드에서 태그 추출
      if (queryResult.tags() != null) {
        final tagsString = queryResult.tags() as String;

        // 파이프로 분리된 태그들 처리
        final tagsList =
            tagsString.split('|').where((element) => element.trim().isNotEmpty);

        // 각 태그 분석
        for (var tag in tagsList) {
          if (tag.contains(':')) {
            // 콜론이 있는 경우 (유형:값)
            final parts = tag.split(':');
            final tagType = parts[0].trim();
            final tagValue = parts[1].trim();

            // 우리가 관심 있는 태그 유형인 경우만 처리
            if (statistics.containsKey(tagType)) {
              statistics[tagType]![tagValue] =
                  (statistics[tagType]![tagValue] ?? 0) + 1;
            }
          } else {
            // 콜론이 없는 경우 (기본 태그 - 'tags'로 분류)
            statistics['tags']![tag.trim()] =
                (statistics['tags']![tag.trim()] ?? 0) + 1;
          }
        }
      }
    }

    return statistics;
  }

  // 태그 통계 버튼 핸들러 수정
  void _toggleTagStatisticsPanel() {
    setState(() {
      _showTagStatisticsPanel = !_showTagStatisticsPanel;
    });
  }

  // 태그 선택 핸들러 수정 - 여러 태그 처리
  void _handleTagsSelected(List<Map<String, String>> selectedTags) {
    if (selectedTags.isEmpty) {
      // 선택된 태그가 없으면 모든 노드 원래 상태로 복원
      for (var node in _nodes) {
        node.highlightColor = null;
        node.opacity = 1.0;
        node.glowRadius = 0.0;
      }
      return;
    }

    // 모든 노드 리셋 (흐리게 처리)
    for (var node in _nodes) {
      node.isAttracted = false;
      node.attractionFactor = 0;
      node.highlightColor = null;
      node.attractionTarget = null;
      node.opacity = 0.25;
      node.glowRadius = 0.0;
    }

    // 모든 선택된 태그를 포함하는 노드 찾기
    List<ArticleNode> matchingNodes = [];

    for (var node in _nodes) {
      final queryResult = node.queryResult;

      if (queryResult.tags() != null) {
        final tagsString = queryResult.tags() as String;
        bool matchesAllTags = true;

        // 모든 선택된 태그가 이 아티클에 포함되어 있는지 확인
        for (var tagInfo in selectedTags) {
          final tagType = tagInfo['type']!;
          final tagValue = tagInfo['value']!;

          final tagToFind = tagType == 'tags' ? tagValue : '$tagType:$tagValue';

          if (!tagsString.contains(tagToFind)) {
            matchesAllTags = false;
            break;
          }
        }

        if (matchesAllTags) {
          matchingNodes.add(node);
        }
      }
    }

    // 매칭된 노드가 없으면 스낵바 표시
    if (matchingNodes.isEmpty) {
      // 모든 노드 원래 상태로 복원
      for (var node in _nodes) {
        node.opacity = 1.0;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('선택한 모든 태그를 포함하는 작품이 없습니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 매칭된 노드 강조 효과
    for (var node in matchingNodes) {
      // 강력한 하이라이트 효과 적용 (보라색 계열로 통일)
      node.highlightColor = Colors.deepPurple.withOpacity(0.6);
      // 완전 불투명하게
      node.opacity = 1.0;
      // 글로우 효과 추가 (더 강하게)
      node.glowRadius = 30.0;
    }

    // 스낵바로 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '선택한 모든 태그를 포함하는 ${matchingNodes.length}개 작품을 강조 표시했습니다.',
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: Colors.deepPurple.withOpacity(0.8),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '취소',
          textColor: Colors.white,
          onPressed: () {
            // 하이라이트 취소 - 모든 노드 원래 상태로 복원
            for (var node in _nodes) {
              node.highlightColor = null;
              node.opacity = 1.0;
              node.glowRadius = 0.0;
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildInteractiveCanvas(),
                _buildInstructionPanel(),
                _buildInfoPanel(),
                _buildFloatingCenterButton(),
                _buildSelectedNodeInfo(),

                // 태그 통계 패널 조건부 표시 - 콜백 함수 변경
                if (_showTagStatisticsPanel)
                  TagStatisticsPanel(
                    tagStatistics: _collectTagStatistics(),
                    totalArticleCount: _nodes.length,
                    onTagsSelected: _handleTagsSelected, // 변경된 콜백 함수
                    initialPosition: _tagStatisticsPanelPosition,
                    onClose: () {
                      setState(() {
                        _showTagStatisticsPanel = false;
                      });
                    },
                  ),
              ],
            ),
    );
  }
}
