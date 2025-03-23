import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hentai.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'package:violet/component/hitomi/similar_articles.dart';
import 'package:violet/database/query.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

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
        // 태그 통계 버튼 추가
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: '태그 통계 보기',
            onPressed: () {
              _showTagStatistics();
            },
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

    // 초기 아티클인 경우 약간 크게 표시
    final scale = node.isSpecial ? 0.85 : (node.isHighSimilarity ? 0.8 : 0.75);

    return Positioned(
      left: node.x - 150, // 아티클 위젯의 절반 너비
      top: node.y - 200, // 아티클 위젯의 절반 높이
      child: Transform.scale(
        scale: scale, // 특별 노드는 좀 더 크게
        child: Stack(
          children: [
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
                    width:
                        node.isSpecial ? 3 : (node.isHighSimilarity ? 2.5 : 2),
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
          _buildActionButton(
            icon: Icons.open_in_new,
            label: '아티클 열기',
            onPressed: () {
              // 아티클 페이지로 이동
              showArticleInfoById(context, queryResult.id());
            },
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

  // 태그 통계 다이얼로그 표시 함수 수정
  void _showTagStatistics() {
    // 태그 통계 수집
    final tagStats = _collectTagStatistics();

    // 다이얼로그 표시 및 결과 처리
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TagStatisticsDialog(
        tagStatistics: tagStats,
        totalArticleCount: _nodes.length,
      ),
    ).then((result) {
      // 다이얼로그 결과 처리
      if (result != null && result['action'] == 'highlight') {
        final tagType = result['tagType'] as String;
        final tagValue = result['tagValue'] as String;

        // 태그를 가진 노드 하이라이트
        _highlightNodesWithSpecificTag(tagType, tagValue);
      }
    });
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

  // 특정 태그를 가진 노드를 하이라이트하는 함수
  void _highlightNodesWithSpecificTag(String tagType, String tagValue) {
    // 모든 노드 리셋
    for (var node in _nodes) {
      node.isAttracted = false;
      node.attractionFactor = 0;
      node.highlightColor = null;
      node.attractionTarget = null;
    }

    // 특정 태그를 가진 노드 찾기
    List<ArticleNode> matchingNodes = [];

    for (var node in _nodes) {
      final queryResult = node.queryResult;

      if (queryResult.tags() != null) {
        final tagsString = queryResult.tags() as String;
        final tagToFind = tagType == 'tags' ? tagValue : '$tagType:$tagValue';

        if (tagsString.contains(tagToFind)) {
          matchingNodes.add(node);
        }
      }
    }

    // 매칭된 노드가 없으면 스낵바 표시
    if (matchingNodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('태그 "$tagValue"를 가진 작품이 현재 뷰에 없습니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 매칭된 노드 하이라이트
    for (var node in matchingNodes) {
      node.highlightColor = Colors.green.withOpacity(0.3);
    }

    // 스낵바로 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('태그 "$tagValue"를 가진 ${matchingNodes.length}개 작품을 하이라이트했습니다.'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '취소',
          onPressed: () {
            // 하이라이트 취소
            for (var node in _nodes) {
              node.highlightColor = null;
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
                _buildSelectedNodeInfo(), // 선택된 노드 정보 패널 추가
              ],
            ),
    );
  }
}

// 유사도 기반 엣지 페인터 클래스 수정
class SimilarityEdgePainter extends CustomPainter {
  final List<ArticleNode> nodes;
  final double maxDistance;
  final SimilarArticles similarArticles;

  SimilarityEdgePainter(this.nodes, this.maxDistance, this.similarArticles);

  @override
  void paint(Canvas canvas, Size size) {
    // 초기 아티클 노드 찾기
    ArticleNode? initialNode;
    for (var node in nodes) {
      if (node.isSpecial) {
        initialNode = node;
        break;
      }
    }

    if (initialNode == null) return;

    // 초기 아티클과 다른 노드 간 연결 먼저 그리기
    for (var node in nodes) {
      if (node != initialNode) {
        // 두 노드 간 거리 계산
        final distance = math.sqrt(math.pow(initialNode.x - node.x, 2) +
            math.pow(initialNode.y - node.y, 2));

        // 두 노드 간 유사도 가져오기
        final similarity = similarArticles.getSimilarity(
            initialNode.queryResult.id(), node.queryResult.id());

        // 상위 유사도 노드는 항상 그리고, 나머지는 거리 제한 있음
        if (node.isHighSimilarity || distance < maxDistance * 5) {
          // 상위 유사도 노드는 항상 연결, 나머지는 일정 유사도 이상만
          if (node.isHighSimilarity || similarity > 0.1) {
            _drawSimilarityConnection(canvas, initialNode, node, distance,
                similarity, node.isHighSimilarity);
          }
        }
      }
    }

    // 그 외 노드 간 연결 (거리 제한 있음)
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final node1 = nodes[i];
        final node2 = nodes[j];

        // 둘 다 초기 아티클이 아닌 경우만 처리 (이미 위에서 처리됨)
        if (!node1.isSpecial && !node2.isSpecial) {
          // 두 노드 간 거리 계산
          final distance = math.sqrt(
              math.pow(node1.x - node2.x, 2) + math.pow(node1.y - node2.y, 2));

          // 일정 거리 이내인 경우만 연결선 그리기
          if (distance < maxDistance * 3) {
            // 두 노드 간 유사도 가져오기
            final similarity = similarArticles.getSimilarity(
                node1.queryResult.id(), node2.queryResult.id());

            // 유사도가 임계값 이상인 경우만 연결선 그리기
            if (similarity > 0.2) {
              _drawSimilarityConnection(
                  canvas, node1, node2, distance, similarity, false);
            }
          }
        }
      }
    }
  }

  // 유사도 기반 연결선 그리기 업데이트
  void _drawSimilarityConnection(
      Canvas canvas,
      ArticleNode node1,
      ArticleNode node2,
      double distance,
      double similarity,
      bool isHighSimilarity) {
    // 유사도에 따른 색상 가져오기
    final color = isHighSimilarity
        ? Colors.red // 상위 유사도는 항상 빨간색
        : similarArticles.getSimilarityColor(similarity);

    // 유사도에 따른 선 두께 계산 (상위 유사도는 더 두껍게)
    final strokeWidth = isHighSimilarity
        ? 2.0 + (similarity * 4.0) // 상위 유사도는 두꺼운 선
        : 0.5 + (similarity * 2.0); // 나머지는 얇은 선

    // 유사도에 따른 투명도 계산
    final opacity = isHighSimilarity
        ? (0.5 + (similarity * 0.5)).clamp(0.0, 1.0) // 상위 유사도는 더 선명하게
        : (0.1 + (similarity * 0.4)).clamp(0.0, 1.0); // 나머지는 더 투명하게

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // 상위 유사도는 대시 효과 없이 실선, 나머지는 점선
    if (!isHighSimilarity && similarity < 0.5) {
      // 낮은 유사도는 점선으로 표시
      paint.strokeCap = StrokeCap.round;

      // 점선 스타일 적용 (Flutter에서는 직접 대시 패턴 적용이 어려움)
      // 따라서 직접 점선을 그려줌
      final dashLength = 3.0;
      final gapLength = 5.0;

      final dx = node2.x - node1.x;
      final dy = node2.y - node1.y;
      final count = distance ~/ (dashLength + gapLength);

      if (count > 0) {
        final stepX = dx / count;
        final stepY = dy / count;

        for (int i = 0; i < count; i++) {
          final startX = node1.x + i * stepX;
          final startY = node1.y + i * stepY;
          canvas.drawLine(
              Offset(startX, startY),
              Offset(startX + stepX * dashLength / (dashLength + gapLength),
                  startY + stepY * dashLength / (dashLength + gapLength)),
              paint);
        }
        return;
      }
    }

    // 연결선 그리기 (점선이 아닌 경우)
    canvas.drawLine(Offset(node1.x, node1.y), Offset(node2.x, node2.y), paint);

    // 유사도가 높은 경우 중간에 유사도 표시
    if ((isHighSimilarity && similarity > 0.4) ||
        (!isHighSimilarity && similarity > 0.6)) {
      final midX = (node1.x + node2.x) / 2;
      final midY = (node1.y + node2.y) / 2;

      // 유사도에 따른 원 크기 조정
      final circleRadius = isHighSimilarity
          ? 4.0 + (similarity * 6.0) // 상위 유사도는 더 큰 원
          : 2.0 + (similarity * 3.0); // 나머지는 작은 원

      // 원 불투명도 값 클램핑
      final circleOpacity = (opacity * 1.2).clamp(0.0, 1.0);

      final circlePaint = Paint()
        ..color = color.withOpacity(circleOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(midX, midY), circleRadius, circlePaint);

      // 유사도 텍스트 표시 - 상위 유사도는 항상 표시, 나머지는 높은 유사도만
      if ((isHighSimilarity && similarity > 0.3) ||
          (!isHighSimilarity && similarity > 0.7 && distance > 100)) {
        final similarityText = '${(similarity * 100).toInt()}%';
        final textStyle = TextStyle(
          color: Colors.white,
          fontSize:
              isHighSimilarity ? 12 + (similarity * 6) : 8 + (similarity * 4),
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 3,
              color: Colors.black.withOpacity(0.7.clamp(0.0, 1.0)),
            ),
          ],
        );

        final textSpan = TextSpan(
          text: similarityText,
          style: textStyle,
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();

        // 텍스트 그리기
        textPainter.paint(
            canvas,
            Offset(
                midX - textPainter.width / 2, midY - textPainter.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 무한 격자를 그리는 CustomPainter
class InfiniteGridPainter extends CustomPainter {
  final double gridSize;
  final Color gridColor;
  final Offset offset;
  final double scale;

  InfiniteGridPainter(this.gridSize, this.gridColor, this.offset, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // 현재 보이는 영역 계산
    final visibleLeft = -offset.dx / scale;
    final visibleTop = -offset.dy / scale;
    final visibleRight = visibleLeft + size.width / scale;
    final visibleBottom = visibleTop + size.height / scale;

    // 보이는 영역의 격자만 그리기
    final scaledGridSize = gridSize;

    // 가로 격자선 - 보이는 부분만 그리기
    final startY = (visibleTop ~/ scaledGridSize) * scaledGridSize;
    final endY = ((visibleBottom ~/ scaledGridSize) + 1) * scaledGridSize;

    for (double y = startY; y <= endY; y += scaledGridSize) {
      canvas.drawLine(Offset(visibleLeft - 10000, y),
          Offset(visibleRight + 10000, y), paint);
    }

    // 세로 격자선 - 보이는 부분만 그리기
    final startX = (visibleLeft ~/ scaledGridSize) * scaledGridSize;
    final endX = ((visibleRight ~/ scaledGridSize) + 1) * scaledGridSize;

    for (double x = startX; x <= endX; x += scaledGridSize) {
      canvas.drawLine(Offset(x, visibleTop - 10000),
          Offset(x, visibleBottom + 10000), paint);
    }

    // 원점 표시
    final centerPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.4)
      ..strokeWidth = 2.0;

    // 가로선
    canvas.drawLine(Offset(visibleLeft - 10000, size.height / 2),
        Offset(visibleRight + 10000, size.height / 2), centerPaint);

    // 세로선
    canvas.drawLine(Offset(size.width / 2, visibleTop - 10000),
        Offset(size.width / 2, visibleBottom + 10000), centerPaint);
  }

  @override
  bool shouldRepaint(covariant InfiniteGridPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.scale != scale;
  }
}

class ArticleNode {
  double x;
  double y;
  final QueryResult queryResult;
  late double velocityX;
  late double velocityY;
  final double maxWidth;
  final double maxHeight;
  double maxVelocity = 3.5; // 최대 속도 증가 (2.0 -> 3.5)
  bool isDraggable = true; // 드래그 가능 여부 플래그
  final int groupId; // 그룹 ID
  bool canPierceOtherGroups = true; // 다른 그룹 관통 가능 여부 추가

  // 새로 추가된 속성
  bool isAttracted = false; // 인력 효과 적용 여부
  double attractionFactor = 0; // 인력 강도
  Color? highlightColor; // 하이라이트 색상
  ArticleNode? attractionTarget; // 인력의 대상이 되는 노드
  bool isSpecial = false; // 특별 노드 표시 (초기 아티클)
  bool isHighSimilarity = false; // 상위 유사도 표시
  double collisionRadius = 250.0; // 충돌 반경 (겹침 방지용)

  // 사각형 충돌 감지를 위한 크기 설정
  final double width = 300.0 * 3 / 4; // 아티클 카드의 너비
  final double height = 300.0; // 아티클 카드의 높이
  final double restitution = 0.8; // 반발 계수 (0~1, 값이 클수록 더 많이 튕김)

  ArticleNode({
    required this.queryResult,
    required this.x,
    required this.y,
    required this.maxWidth,
    required this.maxHeight,
    required this.groupId, // 생성자에 그룹 ID 파라미터 추가
  }) {
    final random = math.Random();

    // 랜덤한 속도와 방향 (더 빠르게)
    velocityX = (random.nextDouble() - 0.5) * maxVelocity * 0.9;
    velocityY = (random.nextDouble() - 0.5) * maxVelocity * 0.9;
  }

  // 사각형의 충돌 영역 정의 - UI 표시와 일치하도록 수정
  Rect get bounds => Rect.fromLTWH(x - width / 2, y - 100, width, height);

  // 사각형 충돌 감지
  bool intersects(ArticleNode other) {
    // 사각형 충돌 감지 (UI 표시용)
    bool rectCollision = bounds.overlaps(other.bounds);

    // 원형 충돌 감지 (배치 및 이동용)
    final dx = x - other.x;
    final dy = y - other.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    bool circleCollision =
        distance < (collisionRadius + other.collisionRadius) * 0.5;

    // 둘 중 하나라도 충돌이면 충돌로 간주
    return rectCollision || circleCollision;
  }

  // 노드 업데이트 (움직임, 경계 확인) - 그룹 기반 움직임 조정
  void update(double delta) {
    if (!isDraggable) return; // 드래그 중이면 자동 이동 안함

    // 부드러운 움직임으로 업데이트
    x += velocityX;
    y += velocityY;

    // 가상 경계 영역 설정 (넓게)
    final virtualBoundary = 5000.0;
    final centerX = maxWidth / 2;
    final centerY = maxHeight / 2;

    // 중앙으로부터 너무 멀어지면 방향 전환
    if (x < centerX - virtualBoundary || x > centerX + virtualBoundary) {
      velocityX *= -1;
      x = x < centerX - virtualBoundary
          ? centerX - virtualBoundary
          : centerX + virtualBoundary;
    }

    if (y < centerY - virtualBoundary || y > centerY + virtualBoundary) {
      velocityY *= -1;
      y = y < centerY - virtualBoundary
          ? centerY - virtualBoundary
          : centerY + virtualBoundary;
    }

    // 추가: 같은 그룹 노드들이 평균 위치를 향해 약하게 이동하는 힘 추가
    _moveTowardsGroupCenter();
  }

  // 같은 그룹의 평균 위치를 향해 이동하는 힘 추가
  void _moveTowardsGroupCenter() {
    // 외부에서 전달받은 _nodes 접근 방식이 없으므로
    // 이 메서드는 실제 구현에서 수정 필요합니다.

    // FloatingSimilarArticleView 클래스에서 다음과 같이 구현이 필요함:
    // 모든 노드에 대해 같은 그룹 노드들의 중심점 계산 및 이동 로직 적용
  }

  // 사각형 기반 충돌 처리 - 다른 그룹 관통 기능 추가
  void resolveCollision(ArticleNode other) {
    // 기존 충돌 감지
    if (intersects(other)) {
      // 원형 충돌에 기반한 해결
      final dx = x - other.x;
      final dy = y - other.y;
      final distanceSquared = dx * dx + dy * dy;

      // 두 노드가 정확히 같은 위치에 있는 경우 방지
      if (distanceSquared < 0.01) {
        x += (math.Random().nextDouble() - 0.5) * 10;
        y += (math.Random().nextDouble() - 0.5) * 10;
        return;
      }

      final distance = math.sqrt(distanceSquared);
      final minDistance = (collisionRadius + other.collisionRadius) * 0.5;

      // 충돌이 발생한 경우에만 처리
      if (distance < minDistance) {
        final overlap = minDistance - distance;

        // 방향 계산
        final dirX = dx / distance;
        final dirY = dy / distance;

        // 그룹 및 특성에 따른 처리
        bool sameGroup = groupId == other.groupId;

        // 충돌 해결 계수
        double myFactor = 0.5;
        double otherFactor = 0.5;

        // 초기 노드, 높은 유사도 노드 등에 따라 계수 조정
        // if (isSpecial) {
        //   myFactor = 0.0;
        //   otherFactor = 1.0;
        // } else if (other.isSpecial) {
        //   myFactor = 1.0;
        //   otherFactor = 0.0;
        // } else

        if (isHighSimilarity && !other.isHighSimilarity) {
          myFactor = 0.3;
          otherFactor = 0.7;
        } else if (!isHighSimilarity && other.isHighSimilarity) {
          myFactor = 0.7;
          otherFactor = 0.3;
        }

        // 드래그 중인 노드는 영향받지 않음
        if (isDragging()) myFactor = 0.0;
        if (other.isDragging()) otherFactor = 0.0;

        // 둘 다 드래그 중이면 아무 영향 없음
        if (isDragging() && other.isDragging()) return;

        // 조정 계수가 모두 0인 경우 처리 방지
        if (myFactor == 0.0 && otherFactor == 0.0) return;

        // 위치 조정
        final totalFactor = myFactor + otherFactor;
        if (totalFactor > 0) {
          myFactor /= totalFactor;
          otherFactor /= totalFactor;
        }

        if (!isDragging()) {
          x += dirX * overlap * myFactor;
          y += dirY * overlap * myFactor;
        }

        if (!other.isDragging()) {
          other.x -= dirX * overlap * otherFactor;
          other.y -= dirY * overlap * otherFactor;
        }

        // 속도 영향도 줌
        if (!isDragging() && !other.isDragging()) {
          // 탄성 계수 (같은 그룹일수록 더 탄력적)
          double elasticity = sameGroup ? 0.6 : 0.4;

          // 속도 교환 로직 (간단한 탄성 충돌)
          final vxTotal = velocityX - other.velocityX;
          final vyTotal = velocityY - other.velocityY;

          final dotProduct = dirX * vxTotal + dirY * vyTotal;

          // 충돌 방향으로의 속도 성분만 변경
          if (dotProduct > 0) {
            final impuls = dotProduct * elasticity;

            if (!isDragging()) {
              velocityX -= dirX * impuls * myFactor;
              velocityY -= dirY * impuls * myFactor;
            }

            if (!other.isDragging()) {
              other.velocityX += dirX * impuls * otherFactor;
              other.velocityY += dirY * impuls * otherFactor;
            }
          }
        }

        // 속도 제한
        limitVelocity();
        other.limitVelocity();
      }
    }
  }

  // 드래그 중인지 확인 (이름 변경하여 혼란 방지)
  bool isDragging() {
    return !isDraggable;
  }

  // 속도 제한 및 감쇠 메서드 (진동 방지)
  void limitVelocity() {
    // 매우 느린 속도는 0으로 설정 (미세 진동 방지)
    if (velocityX.abs() < 0.05) velocityX = 0;
    if (velocityY.abs() < 0.05) velocityY = 0;

    // 속도 제한
    final speed = math.sqrt(velocityX * velocityX + velocityY * velocityY);
    if (speed > maxVelocity) {
      velocityX = (velocityX / speed) * maxVelocity;
      velocityY = (velocityY / speed) * maxVelocity;
    }
  }
}

// 태그 통계 다이얼로그 위젯
class TagStatisticsDialog extends StatefulWidget {
  final Map<String, Map<String, int>> tagStatistics;
  final int totalArticleCount;

  const TagStatisticsDialog({
    Key? key,
    required this.tagStatistics,
    required this.totalArticleCount,
  }) : super(key: key);

  @override
  State<TagStatisticsDialog> createState() => _TagStatisticsDialogState();
}

class _TagStatisticsDialogState extends State<TagStatisticsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  int _minAppearance = 1;
  String _sortBy = 'count'; // 'count' 또는 'name'
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tagStatistics.keys.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 태그 유형 목록
    final tagTypes = widget.tagStatistics.keys.toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // 헤더
            _buildDialogHeader(),

            // 검색 및 필터 섹션
            _buildSearchFilterSection(),

            // 탭 바
            TabBar(
              controller: _tabController,
              tabs: tagTypes.map((type) {
                final tagCount = widget.tagStatistics[type]!.length;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 태그 유형에 따른 아이콘
                      Icon(
                        type == 'female'
                            ? Icons.female
                            : type == 'male'
                                ? Icons.male
                                : Icons.tag,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(type),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tagCount.toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              indicatorColor: Colors.purple,
            ),

            // 탭 내용
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: tagTypes
                    .map((type) => _buildTagStatisticsList(type))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 다이얼로그 헤더
  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.7),
            Colors.deepPurple.withOpacity(0.7)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics, color: Colors.white),
          const SizedBox(width: 12),
          const Text(
            '태그 통계',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '총 ${widget.totalArticleCount}개 작품 분석',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // 검색 및 필터 섹션
  Widget _buildSearchFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          // 검색창
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: '태그 검색...',
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),

          // 필터 옵션
          Row(
            children: [
              // 정렬 기준
              DropdownButton<String>(
                value: _sortBy,
                dropdownColor: Colors.black87,
                style: const TextStyle(color: Colors.white),
                underline: Container(
                  height: 1,
                  color: Colors.white30,
                ),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _sortBy = newValue;
                    });
                  }
                },
                items: <String>['count', 'name']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value == 'count' ? '등장 횟수' : '이름',
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                icon: const Icon(Icons.sort, color: Colors.white54),
                hint: const Text('정렬 기준'),
              ),
              const SizedBox(width: 12),

              // 오름차순/내림차순
              IconButton(
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white54,
                ),
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                  });
                },
                tooltip: _sortAscending ? '오름차순' : '내림차순',
              ),
              const SizedBox(width: 12),

              // 최소 등장 횟수 필터
              const Text(
                '최소 등장:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 60,
                child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _minAppearance = int.tryParse(value) ?? 1;
                    });
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                  controller:
                      TextEditingController(text: _minAppearance.toString()),
                ),
              ),
              const Spacer(),

              // 모든 태그 합계
              Text(
                '총 태그 종류: ${_getTotalUniqueTagCount()}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 전체 고유 태그 수 계산
  int _getTotalUniqueTagCount() {
    int total = 0;
    widget.tagStatistics.forEach((type, tags) {
      total += tags.length;
    });
    return total;
  }

  // 태그 통계 목록
  Widget _buildTagStatisticsList(String tagType) {
    // 태그 맵 가져오기
    final tagsMap = widget.tagStatistics[tagType] ?? {};

    // 검색 및 최소 등장 횟수 필터 적용
    List<MapEntry<String, int>> filteredTags = tagsMap.entries
        .where((entry) =>
            entry.key.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            entry.value >= _minAppearance)
        .toList();

    // 정렬 적용
    if (_sortBy == 'count') {
      filteredTags.sort((a, b) => _sortAscending
          ? a.value.compareTo(b.value)
          : b.value.compareTo(a.value));
    } else {
      // name
      filteredTags.sort((a, b) =>
          _sortAscending ? a.key.compareTo(b.key) : b.key.compareTo(a.key));
    }

    // 색상 설정
    Color tagColor;
    if (tagType == 'female') {
      tagColor = Colors.pink;
    } else if (tagType == 'male') {
      tagColor = Colors.blue;
    } else {
      // tags
      tagColor = Colors.grey;
    }

    return filteredTags.isEmpty
        ? Center(
            child: Text(
              '검색 결과가 없습니다.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          )
        : ListView.builder(
            itemCount: filteredTags.length,
            itemBuilder: (context, index) {
              final entry = filteredTags[index];
              final tagName = entry.key;
              final tagCount = entry.value;
              final percentage = (tagCount / widget.totalArticleCount * 100)
                  .toStringAsFixed(1);

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tagColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: tagColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  tagName,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tagColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$tagCount회',
                        style: TextStyle(
                          color: tagColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$percentage%',
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () {
                  // 태그를 탭하면 관련 작품을 하이라이트하는 기능 등을 추가할 수 있음
                  _highlightNodesWithTag(tagType, tagName);
                },
              );
            },
          );
  }

  // 특정 태그를 가진 노드를 하이라이트하는 함수
  void _highlightNodesWithTag(String tagType, String tagValue) {
    // 이 함수는 FloatingSimilarArticleViewState 클래스의 메서드이므로
    // 여기서는 Navigator.pop() 후 콜백으로 처리해야 함
    Navigator.of(context).pop({
      'action': 'highlight',
      'tagType': tagType,
      'tagValue': tagValue,
    });
  }
}
