// 유사도 기반 엣지 페인터 클래스 수정
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:violet/component/hitomi/similar_articles.dart';
import 'package:violet/pages/lab/lab/floating_view/article_node.dart';

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
