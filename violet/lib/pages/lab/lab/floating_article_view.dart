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

    // 노드 생성
    for (int i = 0; i < articlesToUse; i++) {
      // 원점을 중심으로 랜덤한 위치에 배치
      final randomX =
          centerX + (math.Random().nextDouble() * 2 - 1) * spreadRadius;
      final randomY =
          centerY + (math.Random().nextDouble() * 2 - 1) * spreadRadius;

      _nodes.add(ArticleNode(
        queryResult: _queryResults[i],
        x: randomX,
        y: randomY,
        maxWidth: _virtualSize.width,
        maxHeight: _virtualSize.height,
      ));
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
      _dragPosition = localPosition;
      print('드래그 시작: ${node.x}, ${node.y}');
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
    return Positioned(
      left: node.x - 150, // 아티클 위젯의 절반 너비
      top: node.y - 100, // 아티클 위젯의 절반 높이
      child: Transform.scale(
        scale: 0.75, // 크기 조정
        child: _buildArticleCard(node),
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
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) => _handleDragStart(details, node),
        onPanUpdate: (details) => _handleDragUpdate(details, node),
        onPanEnd: (details) => _handleDragEnd(details, node),
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
        constrained: true,
        onInteractionUpdate: (details) {
          setState(() {
            _scale = getScaleFromTransform();
            _offset = getOffsetFromTransform();
          });
        },
        onInteractionEnd: _handleTransformation,
        child: SizedBox.fromSize(
          size: _virtualSize,
          child: AnimatedBuilder(
            animation: _controller,
            builder: _buildAnimatedContent,
          ),
        ),
      ),
    );
  }

  // 애니메이션 콘텐츠 빌더
  Widget _buildAnimatedContent(BuildContext context, Widget? child) {
    // 노드 움직임 업데이트
    for (var node in _nodes) {
      if (_draggedNode != node) {
        node.update(_controller.value);
      }
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 격자 그리기
        _buildGrid(),

        // 노드와 엣지 그리기
        _buildEdges(),

        // 각 아티클 노드 배치
        ..._nodes.map(_buildArticleNode).toList(),
      ],
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
    // 노드 사이에 엣지 그리기
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final distance = math.sqrt(math.pow(nodes[i].x - nodes[j].x, 2) +
            math.pow(nodes[i].y - nodes[j].y, 2));

        if (distance < maxDistance) {
          final opacity = 1.0 - (distance / maxDistance);

          // 아티클의 유사도나 관계성에 따라 색상을 결정할 수 있음
          // 예시로 기본 색상 사용
          final color = Colors.lightBlueAccent.withOpacity(opacity * 0.7);

          final paint = Paint()
            ..color = color
            ..strokeWidth = 2.0 * opacity
            ..style = PaintingStyle.stroke;

          canvas.drawLine(
            Offset(nodes[i].x, nodes[i].y),
            Offset(nodes[j].x, nodes[j].y),
            paint,
          );
        }
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
  final double maxVelocity = 0.5; // 속도 제한 (느리게)
  bool isDraggable = true; // 드래그 가능 여부 플래그 추가

  ArticleNode({
    required this.queryResult,
    required this.x,
    required this.y,
    required this.maxWidth,
    required this.maxHeight,
  }) {
    final random = math.Random();

    // 랜덤한 속도와 방향 (느리게)
    velocityX = (random.nextDouble() - 0.5) * maxVelocity;
    velocityY = (random.nextDouble() - 0.5) * maxVelocity;
  }

  void update(double delta) {
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
  }
}
