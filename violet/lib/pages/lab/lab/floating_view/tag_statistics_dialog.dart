// 태그 통계 다이얼로그 위젯
import 'package:flutter/material.dart';

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

class _TagStatisticsDialogState extends State<TagStatisticsDialog> {
  String _searchQuery = '';
  int _minAppearance = 1;
  String _sortBy = 'count'; // 'count' 또는 'name'
  bool _sortAscending = false;

  // 태그 타입 필터 옵션
  final Map<String, bool> _tagTypeFilters = {
    'female': true,
    'male': true,
    'tags': true,
  };

  @override
  Widget build(BuildContext context) {
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

            // 태그 타입 필터 토글 섹션 추가
            _buildTagTypeFilterSection(),

            // 통합된 태그 목록
            Expanded(
              child: _buildAllTagsList(),
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

  // 태그 타입 필터 섹션 추가
  Widget _buildTagTypeFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '태그 타입:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(width: 12),
          // Female 태그 토글
          _buildTagTypeToggle(
            'female',
            Colors.pink,
            Icons.female,
          ),
          const SizedBox(width: 8),
          // Male 태그 토글
          _buildTagTypeToggle(
            'male',
            Colors.blue,
            Icons.male,
          ),
          const SizedBox(width: 8),
          // 일반 태그 토글
          _buildTagTypeToggle(
            'tags',
            Colors.grey,
            Icons.tag,
          ),
          const Spacer(),
          // 현재 표시 중인 태그 수
          Text(
            '표시 중인 태그: ${_getVisibleTagCount()}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // 태그 타입 토글 버튼
  Widget _buildTagTypeToggle(String tagType, Color color, IconData icon) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: _tagTypeFilters[tagType]! ? color : Colors.white54),
          const SizedBox(width: 4),
          Text(
            tagType,
            style: TextStyle(
              color: _tagTypeFilters[tagType]! ? Colors.white : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
      selected: _tagTypeFilters[tagType]!,
      onSelected: (bool selected) {
        setState(() {
          _tagTypeFilters[tagType] = selected;
        });
      },
      selectedColor: color.withOpacity(0.3),
      backgroundColor: Colors.white.withOpacity(0.05),
      checkmarkColor: color,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _tagTypeFilters[tagType]!
              ? color.withOpacity(0.7)
              : Colors.white12,
        ),
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

  // 현재 표시 중인 태그 수 계산
  int _getVisibleTagCount() {
    int count = 0;
    widget.tagStatistics.forEach((type, tags) {
      if (_tagTypeFilters[type] ?? false) {
        // 검색어와 최소 등장 횟수 필터 적용
        final filtered = tags.entries.where((entry) =>
            entry.key.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            entry.value >= _minAppearance);
        count += filtered.length;
      }
    });
    return count;
  }

  // 모든 태그 통합 목록
  Widget _buildAllTagsList() {
    // 모든 태그를 하나의 리스트로 통합
    List<MapEntry<String, Map<String, dynamic>>> allTags = [];

    // 각 태그 유형의 필터가 활성화된 경우에만 추가
    widget.tagStatistics.forEach((tagType, tagsMap) {
      if (_tagTypeFilters[tagType] ?? false) {
        tagsMap.forEach((tagName, count) {
          if (tagName.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              count >= _minAppearance) {
            allTags.add(
              MapEntry(
                tagName,
                {
                  'count': count,
                  'type': tagType,
                },
              ),
            );
          }
        });
      }
    });

    // 정렬 적용
    if (_sortBy == 'count') {
      allTags.sort((a, b) => _sortAscending
          ? a.value['count'].compareTo(b.value['count'])
          : b.value['count'].compareTo(a.value['count']));
    } else {
      // name
      allTags.sort((a, b) =>
          _sortAscending ? a.key.compareTo(b.key) : b.key.compareTo(a.key));
    }

    return allTags.isEmpty
        ? Center(
            child: Text(
              '검색 결과가 없습니다.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          )
        : ListView.builder(
            itemCount: allTags.length,
            itemBuilder: (context, index) {
              final entry = allTags[index];
              final tagName = entry.key;
              final tagData = entry.value;
              final tagCount = tagData['count'] as int;
              final tagType = tagData['type'] as String;
              final percentage = (tagCount / widget.totalArticleCount * 100)
                  .toStringAsFixed(1);

              // 태그 타입에 따른 색상 설정
              Color tagColor;
              IconData tagIcon;

              switch (tagType) {
                case 'female':
                  tagColor = Colors.pink;
                  tagIcon = Icons.female;
                  break;
                case 'male':
                  tagColor = Colors.blue;
                  tagIcon = Icons.male;
                  break;
                default:
                  tagColor = Colors.grey;
                  tagIcon = Icons.tag;
              }

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tagColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tagIcon,
                    color: tagColor,
                    size: 16,
                  ),
                ),
                title: Text(
                  tagName,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '타입: $tagType',
                  style: TextStyle(
                    color: tagColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
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
                  // 태그를 탭하면 관련 작품을 하이라이트하는 기능
                  _highlightNodesWithTag(tagType, tagName);
                },
              );
            },
          );
  }

  // 특정 태그를 가진 노드를 하이라이트하는 함수
  void _highlightNodesWithTag(String tagType, String tagValue) {
    // 다이얼로그 닫고 콜백으로 처리
    Navigator.of(context).pop({
      'action': 'highlight',
      'tagType': tagType,
      'tagValue': tagValue,
    });
  }
}
