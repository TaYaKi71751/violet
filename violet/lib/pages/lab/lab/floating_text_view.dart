import 'package:flutter/material.dart';
import 'dart:math' as math;

class FloatingTextView extends StatefulWidget {
  const FloatingTextView({super.key});

  @override
  State<FloatingTextView> createState() => _FloatingTextViewState();
}

class _FloatingTextViewState extends State<FloatingTextView>
    with TickerProviderStateMixin {
  final List<NodeText> _nodes = [];
  late final AnimationController _controller;
  NodeText? _draggedNode;
  Offset? _dragPosition;
  final int nodeCount = 25;
  final double maxDistance = 150.0; // 엣지가 그려질 최대 거리

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

  // 가상 캔버스 크기 (무한 대신 매우 큰 값 사용)
  final Size _virtualSize = const Size(10000, 10000);

  // 노드 경계 없앰
  final bool useBoundary = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    // 더 넓은 영역에 노드 생성 (가시 영역 주변에)
    final double spreadRadius = 800.0;

    // 초기 노드 생성
    for (int i = 0; i < nodeCount; i++) {
      _nodes.add(
        NodeText(
          // 원점 주변 영역에 노드 배치 (-spreadRadius ~ +spreadRadius)
          x: (math.Random().nextDouble() * 2 - 1) * spreadRadius,
          y: (math.Random().nextDouble() * 2 - 1) * spreadRadius,
          maxWidth: _virtualSize.width,
          maxHeight: _virtualSize.height,
          useBoundary: useBoundary,
        ),
      );
    }

    // 변환 컨트롤러 초기화 - 화면 중앙을 기준점으로 설정
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('텍스트 클라우드'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToCenter,
            tooltip: '초기 위치로 돌아가기',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 무한 줌인/아웃 가능한 배경
          Container(
            color: Colors.black87,
            width: double.infinity,
            height: double.infinity,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: _minScale,
              maxScale: _maxScale,
              boundaryMargin: const EdgeInsets.all(double.infinity), // 무한 경계
              constrained: true, // 화면에 맞게 제약
              onInteractionUpdate: (details) {
                setState(() {
                  _scale = getScaleFromTransform();
                  _offset = getOffsetFromTransform();
                });
              },
              onInteractionEnd: (details) {
                setState(() {
                  _scale = getScaleFromTransform();
                  _offset = getOffsetFromTransform();
                });
              },
              child: SizedBox.fromSize(
                size: _virtualSize,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    // 노드 움직임 업데이트
                    for (var node in _nodes) {
                      if (_draggedNode != node) {
                        node.update(_controller.value);
                      }
                    }

                    return CustomPaint(
                      size: _virtualSize,
                      painter: InfiniteGridPainter(
                        _gridSize,
                        _gridColor,
                        getOffsetFromTransform(),
                        getScaleFromTransform(),
                      ),
                      foregroundPainter: NodeEdgePainter(_nodes, maxDistance),
                      child: Stack(
                        children: _nodes.map((node) {
                          return Positioned(
                            left: node.x - (node.size / 2),
                            top: node.y - (node.size / 2),
                            child: GestureDetector(
                              onPanStart: (details) {
                                setState(() {
                                  _draggedNode = node;
                                  // 현재 변환을 고려한 위치 계산
                                  final invertedMatrix = Matrix4.inverted(
                                    _transformationController.value,
                                  );
                                  _dragPosition = MatrixUtils.transformPoint(
                                    invertedMatrix,
                                    details.globalPosition,
                                  );
                                });
                              },
                              onPanUpdate: (details) {
                                if (_draggedNode == node) {
                                  final invertedMatrix = Matrix4.inverted(
                                    _transformationController.value,
                                  );
                                  final localPosition =
                                      MatrixUtils.transformPoint(
                                        invertedMatrix,
                                        details.globalPosition,
                                      );

                                  final dx =
                                      localPosition.dx - _dragPosition!.dx;
                                  final dy =
                                      localPosition.dy - _dragPosition!.dy;

                                  setState(() {
                                    node.x += dx;
                                    node.y += dy;
                                    _dragPosition = localPosition;
                                  });
                                }
                              },
                              onPanEnd: (details) {
                                if (_draggedNode == node) {
                                  setState(() {
                                    _draggedNode = null;
                                    _dragPosition = null;
                                  });
                                }
                              },
                              child: MouseRegion(
                                cursor: SystemMouseCursors.grab,
                                child: Text(
                                  node.content,
                                  style: TextStyle(
                                    fontSize: node.size,
                                    color: node.color.withOpacity(0.9),
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 5.0,
                                        color: node.color.withOpacity(0.5),
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 사용 설명
          Positioned(
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
                    '• 글자를 드래그해서 움직이기',
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
          ),

          // 실시간 정보 표시 패널
          Positioned(
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
                  ElevatedButton.icon(
                    onPressed: _resetToCenter,
                    icon: const Icon(Icons.center_focus_strong, size: 16),
                    label: const Text('원점으로'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 원점 버튼 (쉽게 접근 가능하도록 우측 하단에 추가)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _resetToCenter,
              backgroundColor: Colors.blue.withOpacity(0.8),
              mini: true,
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// 노드와 엣지를 그리는 CustomPainter
class NodeEdgePainter extends CustomPainter {
  final List<NodeText> nodes;
  final double maxDistance;

  NodeEdgePainter(this.nodes, this.maxDistance);

  @override
  void paint(Canvas canvas, Size size) {
    // 노드 사이에 엣지 그리기
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final distance = math.sqrt(
          math.pow(nodes[i].x - nodes[j].x, 2) +
              math.pow(nodes[i].y - nodes[j].y, 2),
        );

        if (distance < maxDistance) {
          final opacity = 1.0 - (distance / maxDistance);
          final blendedColor = Color.lerp(
            nodes[i].color,
            nodes[j].color,
            0.5,
          )!.withOpacity(opacity * 0.5);

          final paint = Paint()
            ..color = blendedColor
            ..strokeWidth = 1.5 * opacity
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
      canvas.drawLine(
        Offset(visibleLeft - 10000, y),
        Offset(visibleRight + 10000, y),
        paint,
      );
    }

    // 세로 격자선 - 보이는 부분만 그리기
    final startX = (visibleLeft ~/ scaledGridSize) * scaledGridSize;
    final endX = ((visibleRight ~/ scaledGridSize) + 1) * scaledGridSize;

    for (double x = startX; x <= endX; x += scaledGridSize) {
      canvas.drawLine(
        Offset(x, visibleTop - 10000),
        Offset(x, visibleBottom + 10000),
        paint,
      );
    }

    // 원점 표시
    final centerPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.4)
      ..strokeWidth = 2.0;

    // 가로선
    canvas.drawLine(
      Offset(visibleLeft - 10000, 0),
      Offset(visibleRight + 10000, 0),
      centerPaint,
    );

    // 세로선
    canvas.drawLine(
      Offset(0, visibleTop - 10000),
      Offset(0, visibleBottom + 10000),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant InfiniteGridPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.scale != scale;
  }
}

class NodeText {
  double x;
  double y;
  late double size;
  late Color color;
  late String content;
  late double velocityX;
  late double velocityY;
  final double maxWidth;
  final double maxHeight;
  final double maxVelocity = 0.8; // 속도 제한
  final bool useBoundary;

  final List<String> texts = [
    '안녕하세요',
    'Flutter',
    'Animation',
    '네트워크',
    '코딩',
    '반가워요',
    'Developer',
    '행복한',
    'Cloud',
    '연결',
    '상호작용',
    'Edge',
    '그래프',
    '노드',
    'AI',
    '미래',
    '기술',
    '창의성',
    'Data',
    '설계',
  ];

  NodeText({
    required this.x,
    required this.y,
    required this.maxWidth,
    required this.maxHeight,
    this.useBoundary = true,
  }) {
    final random = math.Random();
    size = random.nextDouble() * 18 + 14;
    color = Colors.primaries[random.nextInt(Colors.primaries.length)];
    content = texts[random.nextInt(texts.length)];

    // 랜덤한 속도와 방향 (느리게)
    velocityX = (random.nextDouble() - 0.5) * maxVelocity;
    velocityY = (random.nextDouble() - 0.5) * maxVelocity;
  }

  void update(double delta) {
    // 부드러운 움직임으로 업데이트
    x += velocityX;
    y += velocityY;

    if (useBoundary) {
      // 가상 경계 영역 설정 (넓게)
      final virtualBoundary = 1500.0;

      // 화면 경계에 닿으면 방향 반대로
      if (x < 0 || x > virtualBoundary) {
        velocityX *= -1;
        x = x < 0 ? 0 : virtualBoundary;
      }

      if (y < 0 || y > virtualBoundary) {
        velocityY *= -1;
        y = y < 0 ? 0 : virtualBoundary;
      }
    }
  }
}
