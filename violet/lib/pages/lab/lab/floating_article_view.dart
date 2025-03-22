import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/database/query.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class FloatingArticleView extends StatefulWidget {
  const FloatingArticleView({super.key});

  @override
  State<FloatingArticleView> createState() => _FloatingArticleViewState();
}

class _FloatingArticleViewState extends State<FloatingArticleView>
    with TickerProviderStateMixin {
  final List<ArticleNode> _nodes = [];
  late final AnimationController _controller;
  ArticleNode? _draggedNode;
  Offset? _dragPosition;
  final int nodeCount = 100; // 적정한 수의 아이템
  final double maxDistance = 200.0; // 엣지가 그려질 최대 거리

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // 검색 결과 가져오기
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 빈 검색으로 모든 아이템 가져오기
      final searchResult = await HentaiManager.search('');

      setState(() {
        // searchResult는 SearchResult 타입이므로 queryResult로 접근
        _queryResults = searchResult.results;
        _isLoading = false;

        // 검색 결과로 노드 생성
        _createNodes();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createNodes() {
    // 더 넓은 영역에 노드 배치
    final double spreadRadius = 2000.0;
    final centerX = _virtualSize.width / 2;
    final centerY = _virtualSize.height / 2;

    // 사용할 아티클 수 계산
    final articlesToUse =
        _queryResults.length < nodeCount ? _queryResults.length : nodeCount;

    // ID % 10 기준으로 그룹화
    Map<int, List<QueryResult>> groups = {};
    for (int i = 0; i < articlesToUse; i++) {
      final groupId = _queryResults[i].id() % 10;
      if (!groups.containsKey(groupId)) {
        groups[groupId] = [];
      }
      groups[groupId]!.add(_queryResults[i]);
    }

    // 각 그룹별로 위치 지정하여 노드 생성
    int groupIndex = 0;
    final random = math.Random();

    for (var entry in groups.entries) {
      final int groupId = entry.key;
      final List<QueryResult> groupItems = entry.value;

      // 각 그룹의 중심 위치 계산 (원형으로 배치)
      final double groupAngle = (groupIndex * (2 * math.pi / groups.length));
      final double groupRadius = spreadRadius * 0.6; // 그룹간 거리
      final double groupCenterX = centerX + math.cos(groupAngle) * groupRadius;
      final double groupCenterY = centerY + math.sin(groupAngle) * groupRadius;

      // 그룹별 랜덤 색상 지정 (시각적 구분을 위해)
      final groupColor = Color.fromRGBO(150 + random.nextInt(100),
          150 + random.nextInt(100), 150 + random.nextInt(100), 1.0);

      // 각 그룹에 대해 더 조밀한 초기 배치 영역 설정
      final double groupSpreadRadius = 350.0; // 그룹 내 노드들이 퍼지는 범위 (더 작게 설정)

      // 그룹 내 아이템들을 더 가깝게 배치
      for (int i = 0; i < groupItems.length; i++) {
        double itemX;
        double itemY;

        // 첫 번째 노드는 그룹 중심에 배치
        if (i == 0) {
          itemX = groupCenterX;
          itemY = groupCenterY;
        } else {
          // 나머지 노드들은 그룹 중심 주변에 클러스터링

          // 태양계 배치 스타일 - 중심에서부터 일정 거리와 각도로 배치
          final double angle =
              i * (2 * math.pi / groupItems.length) + random.nextDouble() * 0.5;

          // 노드 번호에 따라 중심에서 거리가 점점 증가 (나선형)
          // 아이템 수에 따라 적절히 조정
          final double distanceFromCenter =
              (i / groupItems.length) * groupSpreadRadius;

          itemX = groupCenterX + math.cos(angle) * distanceFromCenter;
          itemY = groupCenterY + math.sin(angle) * distanceFromCenter;

          // 약간의 랜덤성 추가 (매우 적은 범위로 제한)
          itemX += (random.nextDouble() * 30.0 - 15.0);
          itemY += (random.nextDouble() * 30.0 - 15.0);
        }

        // 노드 생성하고 그룹 ID 설정
        final node = ArticleNode(
          queryResult: groupItems[i],
          x: itemX,
          y: itemY,
          maxWidth: _virtualSize.width,
          maxHeight: _virtualSize.height,
          groupId: groupId,
        );

        // 그룹에 따라 관통 속성 설정
        // 같은 그룹 내에서는 일관된 관통 속성 부여 (그룹별 특성 부여)
        node.canPierceOtherGroups =
            groupId % 2 == 0; // 짝수 그룹은 관통 가능, 홀수 그룹은 불가능

        // 그룹별로 속도 특성 부여 (다양한 움직임 패턴)
        if (groupId % 3 == 0) {
          // 빠르게 움직이는 그룹
          node.maxVelocity = 4.5;
          node.velocityX = (random.nextDouble() - 0.5) * 4.0;
          node.velocityY = (random.nextDouble() - 0.5) * 4.0;
        } else if (groupId % 3 == 1) {
          // 중간 속도로 움직이는 그룹
          node.maxVelocity = 3.0;
          node.velocityX = (random.nextDouble() - 0.5) * 2.5;
          node.velocityY = (random.nextDouble() - 0.5) * 2.5;
        } else {
          // 천천히 움직이는 그룹
          node.maxVelocity = 2.0;
          node.velocityX = (random.nextDouble() - 0.5) * 1.5;
          node.velocityY = (random.nextDouble() - 0.5) * 1.5;
        }

        _nodes.add(node);
      }

      groupIndex++;
    }

    // 변환 컨트롤러 초기화 - 중앙에서 시작
    final matrix = Matrix4.identity();
    _transformationController.value = matrix;
  }

  @override
  void dispose() {
    _controller.dispose();
    _transformationController.dispose();
    super.dispose();
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
      // 원점으로 이동
      final matrix = Matrix4.identity();
      _transformationController.value = matrix;
    });
  }

  // 아티클 드래그 시작 핸들러
  void _handleDragStart(DragStartDetails details, ArticleNode node) {
    final invertedMatrix = Matrix4.inverted(_transformationController.value);
    final localPosition =
        MatrixUtils.transformPoint(invertedMatrix, details.globalPosition);

    setState(() {
      _draggedNode = node;
      node.isDraggable = false; // 드래그 중 자동 이동 비활성화
      _dragPosition = localPosition;
    });
  }

  // 아티클 드래그 업데이트 핸들러
  void _handleDragUpdate(DragUpdateDetails details, ArticleNode node) {
    if (_draggedNode == node) {
      final invertedMatrix = Matrix4.inverted(_transformationController.value);
      final localPosition =
          MatrixUtils.transformPoint(invertedMatrix, details.globalPosition);

      if (_dragPosition == null) {
        _dragPosition = localPosition;
        return;
      }

      final dx = localPosition.dx - _dragPosition!.dx;
      final dy = localPosition.dy - _dragPosition!.dy;

      setState(() {
        node.x += dx;
        node.y += dy;
        _dragPosition = localPosition;
      });
    }
  }

  // 아티클 드래그 종료 핸들러
  void _handleDragEnd(DragEndDetails details, ArticleNode node) {
    if (_draggedNode == node) {
      setState(() {
        _draggedNode = null;
        node.isDraggable = true; // 드래그 종료 후 자동 이동 다시 활성화
        _dragPosition = null;
      });
    }
  }

  // 크기 및 위치 변경 핸들러
  void _handleTransformation(ScaleEndDetails details) {
    setState(() {
      _scale = getScaleFromTransform();
      _offset = getOffsetFromTransform();
    });
  }

  // 앱바 위젯 생성
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('떠다니는 아티클'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _resetToCenter,
          tooltip: '초기 위치로 돌아가기',
        ),
      ],
    );
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
      painter: ArticleEdgePainter(_nodes, maxDistance),
    );
  }

  // 드래그 가능한 아티클 노드 위젯 생성
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

    return Positioned(
      left: node.x - 150, // 아티클 위젯의 절반 너비
      top: node.y - 200, // 아티클 위젯의 절반 높이
      child: Transform.scale(
        scale: 0.75, // 크기 조정
        child: Stack(
          children: [
            _buildArticleCard(node),
            // 그룹 표시 마커 추가
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: getGroupColor(node.groupId).withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
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

  // 아티클 카드 위젯 생성
  Widget _buildArticleCard(ArticleNode node) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 아티클 탭 시 동작 (예: 상세 페이지로 이동)
        },
        child: Stack(
          children: [
            // 아티클 위젯
            _buildArticleWidget(node),

            // 드래그 핸들 - 아티클 전체 영역을 드래그 가능하게 만듦
            _buildDragHandle(node),

            // 드래그 손잡이 표시
            _buildDragIndicator(),
          ],
        ),
      ),
    );
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

  // 사용 설명 패널 위젯 생성
  Widget _buildInstructionPanel() {
    return Positioned(
      bottom: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• 아티클을 드래그해서 움직이기',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              '• 핀치로 줌인/줌아웃',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              '• 배경을 드래그해서 이동',
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

  // 애니메이션 콘텐츠 빌더
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
    final dampingFactor = 0.95;

    // 노드 움직임 업데이트 및 노드 간 간격 유지
    for (var node in _nodes) {
      if (_draggedNode != node) {
        // 속도 감쇠 추가 - 진동 방지
        node.velocityX *= dampingFactor;
        node.velocityY *= dampingFactor;

        // 아주 작은 속도는 0으로 설정
        if (node.velocityX.abs() < 0.05) node.velocityX = 0;
        if (node.velocityY.abs() < 0.05) node.velocityY = 0;

        node.update(_controller.value);

        // 1. 자신의 그룹 중심으로 이동하는 힘 적용
        if (groupCenters.containsKey(node.groupId)) {
          final groupCenter = groupCenters[node.groupId]!;
          final dirX = groupCenter.dx - node.x;
          final dirY = groupCenter.dy - node.y;
          final distance = math.sqrt(dirX * dirX + dirY * dirY);

          if (distance > 0) {
            // 그룹 결집력 설정
            final factor = math.min(distance / 800, 0.02);
            node.velocityX += dirX * factor;
            node.velocityY += dirY * factor;
          }
        }

        // 2. 인접 그룹 중심으로의 약한 인력 적용
        int groupIndex = sortedGroupIds.indexOf(node.groupId);
        if (groupIndex >= 0) {
          // 인접 그룹 계산 (앞뒤로 하나씩)
          List<int> adjacentGroups = [];

          // 이전 그룹 (순환 구조 고려)
          int prevGroupIdx =
              (groupIndex - 1 < 0) ? sortedGroupIds.length - 1 : groupIndex - 1;
          adjacentGroups.add(sortedGroupIds[prevGroupIdx]);

          // 다음 그룹 (순환 구조 고려)
          int nextGroupIdx = (groupIndex + 1) % sortedGroupIds.length;
          adjacentGroups.add(sortedGroupIds[nextGroupIdx]);

          // 인접 그룹으로의 약한 인력 적용
          for (int adjacentGroupId in adjacentGroups) {
            if (groupCenters.containsKey(adjacentGroupId)) {
              final adjacentCenter = groupCenters[adjacentGroupId]!;
              final dirX = adjacentCenter.dx - node.x;
              final dirY = adjacentCenter.dy - node.y;
              final distance = math.sqrt(dirX * dirX + dirY * dirY);

              if (distance > 0 && distance < 1500) {
                // 일정 거리 내에서만 영향
                // 인접 그룹으로의 약한 인력 (자신의 그룹의 20% 정도)
                final factor = math.min(distance / 2000, 0.005);
                node.velocityX += dirX * factor;
                node.velocityY += dirY * factor;
              }
            }
          }
        }

        // 3. 같은 그룹 내 다른 노드와의 거리 유지
        for (var otherNode in _nodes) {
          if (node != otherNode && node.groupId == otherNode.groupId) {
            final dirX = node.x - otherNode.x;
            final dirY = node.y - otherNode.y;
            final distanceSq = dirX * dirX + dirY * dirY;

            // 최소 거리 설정 (이 거리보다 가까우면 서로 밀어냄)
            final minDistance = 300.0; // 적정 거리 설정
            final minDistanceSq = minDistance * minDistance;

            if (distanceSq > 0 && distanceSq < minDistanceSq) {
              final distance = math.sqrt(distanceSq);
              // 밀어내는 힘 설정
              final repulsionFactor = 0.05 * (1.0 - distance / minDistance);

              // 거리가 가까울수록 더 강하게 밀어냄
              node.velocityX += dirX / distance * repulsionFactor;
              node.velocityY += dirY / distance * repulsionFactor;
            }
          }
        }

        // 4. 다른 그룹 노드와의 반발력 적용 (인접 그룹은 약한 반발력)
        for (var otherNode in _nodes) {
          if (node != otherNode && node.groupId != otherNode.groupId) {
            final dirX = node.x - otherNode.x;
            final dirY = node.y - otherNode.y;
            final distanceSq = dirX * dirX + dirY * dirY;
            final distance = math.sqrt(distanceSq);

            // 최소 거리 설정
            final minDistance = 400.0;
            final minDistanceSq = minDistance * minDistance;

            if (distance > 0 && distanceSq < minDistanceSq) {
              // 인접 그룹인지 확인
              bool isAdjacent = false;
              int groupIndex = sortedGroupIds.indexOf(node.groupId);
              if (groupIndex >= 0) {
                int prevGroupIdx = (groupIndex - 1 < 0)
                    ? sortedGroupIds.length - 1
                    : groupIndex - 1;
                int nextGroupIdx = (groupIndex + 1) % sortedGroupIds.length;

                isAdjacent =
                    otherNode.groupId == sortedGroupIds[prevGroupIdx] ||
                        otherNode.groupId == sortedGroupIds[nextGroupIdx];
              }

              // 인접 그룹은 약한 반발력, 비인접 그룹은 강한 반발력
              double repulsionFactor;
              if (isAdjacent) {
                // 인접 그룹 - 약한 반발력
                repulsionFactor = 0.08 * (1.0 - distance / minDistance);
              } else {
                // 비인접 그룹 - 강한 반발력
                repulsionFactor = 0.15 * (1.0 - distance / minDistance);
              }

              node.velocityX += dirX / distance * repulsionFactor;
              node.velocityY += dirY / distance * repulsionFactor;
            }
          }
        }

        // 속도 제한
        node.maxVelocity = 3.0;
        node.limitVelocity();
      }
    }

    // 충돌 처리 개선 - 진동 방지
    for (int i = 0; i < _nodes.length; i++) {
      for (int j = i + 1; j < _nodes.length; j++) {
        // 그룹에 따라 다른 충돌 처리 적용
        _nodes[i].resolveCollision(_nodes[j]);
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

  // 탭으로 노드 찾기 - 선택 정보 업데이트
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
        setState(() {
          // 이전에 선택된 노드와 다른 경우에만 패널 위치 초기화
          if (_selectedNode != node) {
            _nodeInfoPanelPosition = const Offset(20, 80); // 패널 위치 초기화
          }
          _selectedNode = node; // 선택된 노드 저장
          _draggedNode = node;
          node.isDraggable = false;
          _dragPosition = virtualPosition;
        });
        return;
      }
    }

    // 빈 공간 탭 시 선택 해제
    setState(() {
      _selectedNode = null;
    });

    print('선택된 노드 없음');
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

  // 선택된 노드 정보 패널 위젯 생성 (드래그 가능하도록 수정)
  Widget _buildSelectedNodeInfo() {
    if (_selectedNode == null) return const SizedBox.shrink();

    final node = _selectedNode!;
    final queryResult = node.queryResult;

    return Positioned(
      top: _nodeInfoPanelPosition.dy,
      right: _nodeInfoPanelPosition.dx,
      child: GestureDetector(
        // 드래그 시작 처리
        onPanStart: (details) {
          // 드래그 시작 시점에 별도 처리가 필요하면 여기에 추가
        },
        // 드래그 이동 처리
        onPanUpdate: (details) {
          setState(() {
            // 패널 위치 업데이트 (dx는 오른쪽에서부터의 거리이므로 음수로 계산)
            _nodeInfoPanelPosition = Offset(
                _nodeInfoPanelPosition.dx - details.delta.dx,
                _nodeInfoPanelPosition.dy + details.delta.dy);
          });
        },
        // 드래그 종료 처리
        onPanEnd: (details) {
          // 드래그 종료 시점에 별도 처리가 필요하면 여기에 추가
        },
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.7), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 드래그 핸들 추가
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // 드래그 핸들 아이콘 추가
                      Icon(Icons.drag_handle, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        '선택된 아티클 정보',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 18),
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
              const Divider(color: Colors.white30),
              const SizedBox(height: 8),
              _buildInfoItem('ID', queryResult.id.toString()),
              _buildInfoItem('제목', queryResult.title()),
              _buildInfoItem('페이지 수', queryResult.files().toString()),
              const SizedBox(height: 8),
              _buildActionButtons(queryResult),
            ],
          ),
        ),
      ),
    );
  }

  // 정보 아이템 생성 헬퍼 함수
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 아티클 액션 버튼 생성
  Widget _buildActionButtons(QueryResult queryResult) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.open_in_new,
          label: '열기',
          onPressed: () {
            // 아티클 페이지로 이동
            // Navigator.push...
          },
        ),
        _buildActionButton(
          icon: Icons.download,
          label: '다운로드',
          onPressed: () {
            // 다운로드 기능
          },
        ),
        _buildActionButton(
          icon: Icons.bookmark,
          label: '북마크',
          onPressed: () {
            // 북마크 기능
          },
        ),
      ],
    );
  }

  // 액션 버튼 생성 헬퍼 함수
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
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

// 아티클 노드와 엣지를 그리는 CustomPainter
class ArticleEdgePainter extends CustomPainter {
  final List<ArticleNode> nodes;
  final double maxDistance;

  ArticleEdgePainter(this.nodes, this.maxDistance);

  @override
  void paint(Canvas canvas, Size size) {
    // 각 그룹별 노드 저장
    Map<int, List<ArticleNode>> groupedNodes = {};

    // 노드들을 그룹별로 정리
    for (var node in nodes) {
      if (!groupedNodes.containsKey(node.groupId)) {
        groupedNodes[node.groupId] = [];
      }
      groupedNodes[node.groupId]!.add(node);
    }

    // 모든 그룹 ID 정렬
    final List<int> sortedGroupIds = groupedNodes.keys.toList()..sort();
    final int totalGroups = sortedGroupIds.length;

    // 1. 같은 그룹 내 노드 간 연결 - 강한 연결
    groupedNodes.forEach((groupId, groupNodes) {
      if (groupNodes.length > 1) {
        // 같은 그룹 내 모든 노드끼리 연결
        for (int i = 0; i < groupNodes.length; i++) {
          for (int j = i + 1; j < groupNodes.length; j++) {
            final node1 = groupNodes[i];
            final node2 = groupNodes[j];

            final distance = math.sqrt(math.pow(node1.x - node2.x, 2) +
                math.pow(node1.y - node2.y, 2));

            // 거리에 따른 선 그리기
            final maxGroupDistance = maxDistance * 8.0;

            if (distance < maxGroupDistance) {
              // 같은 그룹 내 연결 - 강한 연결
              _drawConnection(
                canvas,
                node1,
                node2,
                distance,
                maxGroupDistance,
                groupId,
                1.0, // 강도 계수 (1.0 = 100% 강도)
              );
            }
          }
        }
      }
    });

    // 2. 인접 그룹 간 노드 연결 - 약한 연결
    for (int i = 0; i < sortedGroupIds.length; i++) {
      int currentGroupId = sortedGroupIds[i];

      // 인접 그룹 계산 (앞뒤로 하나씩)
      List<int> adjacentGroups = [];

      // 이전 그룹 (순환 구조 고려)
      int prevGroupIdx = (i - 1 < 0) ? sortedGroupIds.length - 1 : i - 1;
      adjacentGroups.add(sortedGroupIds[prevGroupIdx]);

      // 다음 그룹 (순환 구조 고려)
      int nextGroupIdx = (i + 1) % sortedGroupIds.length;
      adjacentGroups.add(sortedGroupIds[nextGroupIdx]);

      // 현재 그룹 노드들
      List<ArticleNode> currentGroupNodes = groupedNodes[currentGroupId]!;

      // 각 인접 그룹과의 연결
      for (int adjacentGroupId in adjacentGroups) {
        List<ArticleNode> adjacentGroupNodes = groupedNodes[adjacentGroupId]!;

        // 인접 그룹 노드와 연결
        for (var node1 in currentGroupNodes) {
          for (var node2 in adjacentGroupNodes) {
            final distance = math.sqrt(math.pow(node1.x - node2.x, 2) +
                math.pow(node1.y - node2.y, 2));

            // 인접 그룹 간 최대 거리는 더 짧게 설정 (더 가까운 노드만 연결)
            final maxAdjacentDistance = maxDistance * 4.0;

            if (distance < maxAdjacentDistance) {
              // 인접 그룹 간 연결 - 약한 연결 (강도 0.4 = 40%)
              _drawConnection(
                canvas,
                node1,
                node2,
                distance,
                maxAdjacentDistance,
                adjacentGroupId, // 인접 그룹의 색상 사용
                0.4, // 약한 연결 강도
              );
            }
          }
        }
      }
    }
  }

  // 노드 간 연결선 그리기 헬퍼 함수
  void _drawConnection(
    Canvas canvas,
    ArticleNode node1,
    ArticleNode node2,
    double distance,
    double maxDistance,
    int colorGroupId,
    double strengthFactor, // 연결 강도 (0.0 ~ 1.0)
  ) {
    // 투명도 계산 (거리가 가까울수록 더 선명하게)
    final baseOpacity = math.max(0.4, 1.0 - (distance / maxDistance));
    final opacity = baseOpacity * strengthFactor;

    // 그룹 ID에 따라 색상 다르게 설정
    final Color baseColor = _getGroupColor(colorGroupId);
    final color = baseColor.withOpacity(opacity);

    // 선 두께 계산 (거리가 가까울수록 더 두껍게, 강도에 따라 조정)
    final baseStrokeWidth = math.max(1.5, 4.0 * (1.0 - distance / maxDistance));
    final strokeWidth = baseStrokeWidth * strengthFactor;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // 엣지 그리기
    canvas.drawLine(
      Offset(node1.x, node1.y),
      Offset(node2.x, node2.y),
      paint,
    );

    // 가까운 노드들 사이에는 연결 표시 (강도에 따라 크기와 투명도 조정)
    if (distance < maxDistance * 0.5) {
      final midX = (node1.x + node2.x) / 2;
      final midY = (node1.y + node2.y) / 2;

      final glowOpacity = math.min(0.9, opacity * 1.5);
      final glowRadius = 3.0 * strengthFactor;

      final glowPaint = Paint()
        ..color = baseColor.withOpacity(glowOpacity)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * strengthFactor);

      canvas.drawCircle(Offset(midX, midY), glowRadius, glowPaint);
    }
  }

  // 그룹 ID에 따른 더 선명한 색상 반환
  Color _getGroupColor(int groupId) {
    final colors = [
      Colors.red.shade600,
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.amber.shade600,
      Colors.purple.shade600,
      Colors.orange.shade600,
      Colors.teal.shade600,
      Colors.pink.shade600,
      Colors.cyan.shade600,
      Colors.deepOrange.shade600,
    ];

    return colors[groupId % colors.length];
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
    return bounds.overlaps(other.bounds);
  }

  // 노드 업데이트 (움직임, 경계 확인) - 그룹 기반 움직임 조정
  void update(double delta) {
    if (!isDraggable) return; // 드래그 중이면 자동 이동 안함

    // 부드러운 움직임으로 업데이트
    x += velocityX;
    y += velocityY;

    // 가상 경계 영역 설정 (넓게)
    final virtualBoundary = 2000.0;
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

    // FloatingArticleView 클래스에서 다음과 같이 구현이 필요함:
    // 모든 노드에 대해 같은 그룹 노드들의 중심점 계산 및 이동 로직 적용
  }

  // 사각형 기반 충돌 처리 - 다른 그룹 관통 기능 추가
  void resolveCollision(ArticleNode other) {
    // 충돌 감지
    if (intersects(other)) {
      // 사각형 영역 계산
      final myRect = bounds;
      final otherRect = other.bounds;

      // 겹치는 영역 계산
      final overlap = myRect.intersect(otherRect);

      // 가장 작은 겹침 방향 찾기 (X 또는 Y 방향)
      final overlapWidth = overlap.width;
      final overlapHeight = overlap.height;

      double adjustX = 0;
      double adjustY = 0;

      // X축 또는 Y축 방향 중 더 작은 겹침을 선택하여 분리
      if (overlapWidth < overlapHeight) {
        // X축 방향으로 분리
        if (x < other.x) {
          adjustX = -overlapWidth;
        } else {
          adjustX = overlapWidth;
        }
      } else {
        // Y축 방향으로 분리
        if (y < other.y) {
          adjustY = -overlapHeight;
        } else {
          adjustY = overlapHeight;
        }
      }

      // 같은 그룹인지 다른 그룹인지에 따라 처리 방법 차별화
      bool sameGroup = groupId == other.groupId;

      // 충돌 반응 계수 - 같은 그룹일 때와 다른 그룹일 때 다르게 설정
      double positionFactor = sameGroup ? 0.5 : 0.3; // 위치 조정 계수
      double velocityRestitution =
          sameGroup ? restitution : restitution * 1.2; // 속도 반발 계수

      // 드래그 상태에 따라 위치 조정
      if (!isDragging() && !other.isDragging()) {
        // 두 노드 모두 자유롭게 움직이는 경우

        // 서로 다른 그룹인 경우, canPierceOtherGroups 속성에 따라 처리
        if (!sameGroup && canPierceOtherGroups && other.canPierceOtherGroups) {
          // 다른 그룹이면서 둘 다 관통 설정이 켜져있을 때

          // 약한 충돌 효과 (위치 조정은 적게, 속도는 약간만 영향)
          x += adjustX * positionFactor * 0.3;
          y += adjustY * positionFactor * 0.3;
          other.x -= adjustX * positionFactor * 0.3;
          other.y -= adjustY * positionFactor * 0.3;

          // 속도에 약간의 영향만 (완전히 관통하지 않고 약간의 상호작용)
          double tempVelocityX = velocityX;
          double tempVelocityY = velocityY;

          if (overlapWidth < overlapHeight) {
            velocityX = velocityX * 0.95 + other.velocityX * 0.05;
            other.velocityX = other.velocityX * 0.95 + tempVelocityX * 0.05;
          } else {
            velocityY = velocityY * 0.95 + other.velocityY * 0.05;
            other.velocityY = other.velocityY * 0.95 + tempVelocityY * 0.05;
          }
        } else {
          // 같은 그룹이거나 관통 설정이 꺼진 경우 - 일반 충돌 처리

          // 위치 조정
          x += adjustX * positionFactor;
          y += adjustY * positionFactor;
          other.x -= adjustX * positionFactor;
          other.y -= adjustY * positionFactor;

          // 속도 교환 (탄성 충돌)
          double tempVelocityX = velocityX;
          double tempVelocityY = velocityY;

          // X 방향 충돌인 경우 X 방향 속도 교환
          if (overlapWidth < overlapHeight) {
            velocityX = other.velocityX * velocityRestitution;
            other.velocityX = tempVelocityX * velocityRestitution;
          } else {
            // Y 방향 충돌인 경우 Y 방향 속도 교환
            velocityY = other.velocityY * velocityRestitution;
            other.velocityY = tempVelocityY * velocityRestitution;
          }

          // 다른 그룹일 경우 추가 속도 부스트 (더 역동적인 움직임)
          if (!sameGroup) {
            final random = math.Random();
            final boostFactor =
                0.5 + random.nextDouble() * 0.5; // 0.5-1.0 랜덤 부스트

            velocityX *= boostFactor;
            velocityY *= boostFactor;
            other.velocityX *= boostFactor;
            other.velocityY *= boostFactor;
          }
        }
      } else if (!isDragging()) {
        // 내 노드만 자유롭게 움직이는 경우
        // 다른 그룹이면서 관통 설정이 켜져있으면 약한 충돌
        if (!sameGroup && canPierceOtherGroups && other.canPierceOtherGroups) {
          x += adjustX * 0.3;
          // 속도는 적게 영향받음
          if (overlapWidth < overlapHeight) {
            velocityX *= -0.3;
          } else {
            velocityY *= -0.3;
          }
        } else {
          // 일반 충돌
          x += adjustX;
          y += adjustY;

          // 속도 반전
          if (overlapWidth < overlapHeight) {
            velocityX *= -velocityRestitution;
          } else {
            velocityY *= -velocityRestitution;
          }
        }
      } else if (!other.isDragging()) {
        // 상대 노드만 자유롭게 움직이는 경우
        // 다른 그룹이면서 관통 설정이 켜져있으면 약한 충돌
        if (!sameGroup && canPierceOtherGroups && other.canPierceOtherGroups) {
          other.x -= adjustX * 0.3;
          other.y -= adjustY * 0.3;
          // 속도는 적게 영향받음
          if (overlapWidth < overlapHeight) {
            other.velocityX *= -0.3;
          } else {
            other.velocityY *= -0.3;
          }
        } else {
          // 일반 충돌
          other.x -= adjustX;
          other.y -= adjustY;

          // 상대 속도 반전
          if (overlapWidth < overlapHeight) {
            other.velocityX *= -velocityRestitution;
          } else {
            other.velocityY *= -velocityRestitution;
          }
        }
      }

      // 속도 제한
      limitVelocity();
      other.limitVelocity();
    }
  }

  // 드래그 중인지 확인
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
