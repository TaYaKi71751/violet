import 'package:flutter/material.dart';
import 'package:violet/database/query.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/lab/lab/floating_view/article_node.dart';

class SelectedNodeInfo extends StatelessWidget {
  final ArticleNode node;
  final QueryResult queryResult;
  final ArticleNode? initialNode;
  final double similarityValue;
  final VoidCallback onClose;

  const SelectedNodeInfo({
    super.key,
    required this.node,
    required this.queryResult,
    this.initialNode,
    this.similarityValue = 0,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            _buildSimilarityInfo(similarityValue, initialNode!.queryResult),

          // 태그 섹션
          _buildTagSection(context, queryResult),

          // 액션 섹션 - 버튼 및 기타 액션 제공
          _buildActionSection(context, queryResult),
        ],
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
              onClose();
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
  Widget _buildActionSection(BuildContext context, QueryResult queryResult) {
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
  Widget _buildTagSection(BuildContext context, QueryResult queryResult) {
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
}
