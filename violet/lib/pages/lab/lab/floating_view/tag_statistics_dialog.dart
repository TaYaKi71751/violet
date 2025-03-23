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
