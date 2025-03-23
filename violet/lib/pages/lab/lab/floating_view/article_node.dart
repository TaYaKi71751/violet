import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:violet/database/query.dart';

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

  // 하이라이트 효과 강화를 위한 속성 추가
  double opacity = 1.0; // 투명도 조절
  double scale = 1.0; // 크기 조절
  double glowRadius = 0.0; // 글로우 효과 반경

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
