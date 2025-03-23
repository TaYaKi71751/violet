import 'package:flutter/material.dart';

class TagStatisticsPanel extends StatefulWidget {
  final Map<String, Map<String, int>> tagStatistics;
  final int totalArticleCount;
  final Function(List<Map<String, String>>) onTagsSelected; // 콜백 함수 변경
  final Offset initialPosition;
  final VoidCallback onClose;

  const TagStatisticsPanel({
    Key? key,
    required this.tagStatistics,
    required this.totalArticleCount,
    required this.onTagsSelected,
    required this.initialPosition,
    required this.onClose,
  }) : super(key: key);

  @override
  State<TagStatisticsPanel> createState() => _TagStatisticsPanelState();
}

class _TagStatisticsPanelState extends State<TagStatisticsPanel>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  int _minAppearance = 1;
  String _sortBy = 'count'; // 'count' 또는 'name'
  bool _sortAscending = false;
  bool _isCollapsed = false; // 패널 축소 상태
  late Offset _position;

  // 선택된 태그 목록 (Map<태그 유형, Set<태그 값>>)
  final Map<String, Set<String>> _selectedTags = {
    'female': {},
    'male': {},
    'tags': {},
  };

  // 태그 타입 필터 옵션
  final Map<String, bool> _tagTypeFilters = {
    'female': true,
    'male': true,
    'tags': true,
  };

  // 애니메이션 컨트롤러를 담을 맵 추가
  final Map<String, AnimationController> _animationControllers = {};

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  @override
  void dispose() {
    // 모든 애니메이션 컨트롤러 해제
    _animationControllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 패널의 크기 계산
    final panelWidth = 400.0;
    final panelHeight = _isCollapsed ? 50.0 : 600.0;

    // 선택된 태그 개수 계산
    int totalSelectedTags = 0;
    _selectedTags.forEach((key, value) {
      totalSelectedTags += value.length;
    });

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position.dx + details.delta.dx,
              _position.dy + details.delta.dy,
            );
          });
        },
        child: Container(
          width: panelWidth,
          height: panelHeight,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              // 헤더 - 드래그 핸들 포함
              _buildPanelHeader(totalSelectedTags),

              // 축소된 상태가 아닐 때만 본문 표시
              if (!_isCollapsed) ...[
                // 검색 및 필터 섹션
                _buildSearchFilterSection(),

                // 태그 타입 필터 토글 섹션
                _buildTagTypeFilterSection(),

                // 통합된 태그 목록
                Expanded(
                  child: _buildAllTagsList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 패널 헤더 - 드래그 핸들 포함
  Widget _buildPanelHeader(int selectedCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          // 드래그 핸들 아이콘 추가
          const Icon(Icons.drag_handle, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          const Icon(Icons.analytics, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(
            selectedCount > 0 ? '태그 통계 (${selectedCount}개 선택됨)' : '태그 통계',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),

          // 선택 초기화 버튼 (선택된 태그가 있을 때만)
          if (selectedCount > 0)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
              onPressed: _clearAllSelections,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '선택 초기화',
            ),
          const SizedBox(width: 10),

          // 숨기기/보이기 전환 버튼
          IconButton(
            icon: Icon(
              _isCollapsed ? Icons.expand_more : Icons.expand_less,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _isCollapsed = !_isCollapsed;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: _isCollapsed ? '패널 확장' : '패널 축소',
          ),
          const SizedBox(width: 10),

          // 닫기 버튼
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '패널 닫기',
          ),
        ],
      ),
    );
  }

  // 검색 및 필터 섹션
  Widget _buildSearchFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54, size: 16),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),

          // 필터 옵션
          Row(
            children: [
              // 정렬 기준
              DropdownButton<String>(
                value: _sortBy,
                dropdownColor: Colors.black87,
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
                icon: const Icon(Icons.sort, color: Colors.white54, size: 16),
                hint: const Text('정렬'),
              ),
              const SizedBox(width: 8),

              // 오름차순/내림차순
              IconButton(
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white54,
                  size: 16,
                ),
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                  });
                },
                tooltip: _sortAscending ? '오름차순' : '내림차순',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),

              // 최소 등장 횟수 필터
              const Text(
                '최소:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 50,
                height: 30,
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
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                  controller:
                      TextEditingController(text: _minAppearance.toString()),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_list,
            color: Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 6),
          const Text(
            '필터:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          // 태그 타입 칩들을 나란히 배치
          _buildTagTypeChip('female', Colors.pink, Icons.female),
          const SizedBox(width: 4),
          _buildTagTypeChip('male', Colors.blue, Icons.male),
          const SizedBox(width: 4),
          _buildTagTypeChip('tags', Colors.grey, Icons.tag),
          const Spacer(),
          // 현재 표시 중인 태그 수
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.purple.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${_getVisibleTagCount()}개',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 간소화된 태그 타입 칩
  Widget _buildTagTypeChip(String tagType, Color color, IconData icon) {
    final isSelected = _tagTypeFilters[tagType] ?? false;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tagTypeFilters[tagType] = !isSelected;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.7)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.white54,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              tagType,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
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
                  'isSelected':
                      _selectedTags[tagType]?.contains(tagName) ?? false,
                },
              ),
            );
          }
        });
      }
    });

    if (_sortBy == 'count') {
      allTags.sort((a, b) => _sortAscending
          ? a.value['count'].compareTo(b.value['count'])
          : b.value['count'].compareTo(a.value['count']));
    } else {
      allTags.sort((a, b) =>
          _sortAscending ? a.key.compareTo(b.key) : b.key.compareTo(a.key));
    }

    return allTags.isEmpty
        ? Center(
            child: Text(
              '검색 결과가 없습니다.',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
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
              final isSelected = tagData['isSelected'] as bool;
              final percentage = (tagCount / widget.totalArticleCount * 100)
                  .toStringAsFixed(1);

              // 각 아이템에 대한 고유 키 생성
              final String animationKey = '$tagType:$tagName';

              // 아직 없는 경우 애니메이션 컨트롤러 생성
              if (!_animationControllers.containsKey(animationKey)) {
                _animationControllers[animationKey] = AnimationController(
                  vsync: this,
                  duration: const Duration(milliseconds: 300),
                );

                // 초기 상태 설정
                if (isSelected) {
                  _animationControllers[animationKey]!.value = 1.0;
                } else {
                  _animationControllers[animationKey]!.value = 0.0;
                }
              }

              // 선택 상태에 따라 애니메이션 실행
              if (isSelected &&
                  _animationControllers[animationKey]!.status !=
                      AnimationStatus.completed) {
                _animationControllers[animationKey]!.forward();
              } else if (!isSelected &&
                  _animationControllers[animationKey]!.status !=
                      AnimationStatus.dismissed) {
                _animationControllers[animationKey]!.reverse();
              }

              // 애니메이션 구성
              final Animation<double> scaleAnimation = CurvedAnimation(
                parent: _animationControllers[animationKey]!,
                curve: Curves.elasticOut,
              );

              final Animation<double> fadeAnimation = CurvedAnimation(
                parent: _animationControllers[animationKey]!,
                curve: Curves.easeInOut,
              );

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

              // 선택 상태에 따른 색상 및 스타일 조정
              final itemColor =
                  isSelected ? tagColor : Colors.white.withOpacity(0.9);
              final itemBgColor =
                  isSelected ? tagColor.withOpacity(0.2) : Colors.transparent;

              // 작은 크기의 리스트 아이템으로 변경 - 애니메이션 추가
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: itemBgColor,
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: InkWell(
                    onTap: () {
                      _toggleTagSelection(tagType, tagName);
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedBuilder(
                      animation: _animationControllers[animationKey]!,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              tagColor.withOpacity(0.1),
                              tagColor.withOpacity(0.3),
                              fadeAnimation.value,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color.lerp(
                                tagColor.withOpacity(0.3),
                                tagColor,
                                fadeAnimation.value,
                              )!,
                              width: 1.0 + fadeAnimation.value,
                            ),
                            boxShadow: [
                              if (fadeAnimation.value > 0)
                                BoxShadow(
                                  color: tagColor
                                      .withOpacity(0.3 * fadeAnimation.value),
                                  blurRadius: 8 * fadeAnimation.value,
                                  spreadRadius: 2 * fadeAnimation.value,
                                ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 원래 아이콘 (페이드 아웃)
                              Opacity(
                                opacity: 1.0 - fadeAnimation.value,
                                child: Icon(
                                  tagIcon,
                                  color: tagColor.withOpacity(0.7),
                                  size: 16,
                                ),
                              ),
                              // 체크 아이콘 (페이드 인 + 스케일)
                              ScaleTransition(
                                scale: scaleAnimation,
                                child: Opacity(
                                  opacity: fadeAnimation.value,
                                  child: Icon(
                                    Icons.check,
                                    color: tagColor,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  title: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: itemColor,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    child: Text(
                      tagName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: tagColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: tagColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '$tagCount',
                          style: TextStyle(
                            color: tagColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$percentage%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  onTap: () {
                    // 태그 탭 시 선택/해제 토글
                    _toggleTagSelection(tagType, tagName);
                  },
                ),
              );
            },
          );
  }

  // 태그 선택 토글 함수
  void _toggleTagSelection(String tagType, String tagValue) {
    setState(() {
      if (_selectedTags.containsKey(tagType)) {
        if (_selectedTags[tagType]!.contains(tagValue)) {
          // 이미 선택된 경우 제거
          _selectedTags[tagType]!.remove(tagValue);
        } else {
          // 선택되지 않은 경우 추가
          _selectedTags[tagType]!.add(tagValue);
        }
      } else {
        // 해당 타입이 없는 경우 새로 생성
        _selectedTags[tagType] = {tagValue};
      }
    });

    // 선택된 태그 즉시 적용
    _applyTagSelectionImmediately();
  }

  // 선택된 태그 즉시 적용 함수
  void _applyTagSelectionImmediately() {
    // 선택된 태그를 리스트 형태로 변환
    List<Map<String, String>> selectedTagsList = [];

    _selectedTags.forEach((tagType, tagValues) {
      for (var tagValue in tagValues) {
        selectedTagsList.add({
          'type': tagType,
          'value': tagValue,
        });
      }
    });

    // 콜백 호출하여 부모 위젯에 선택된 태그 전달
    widget.onTagsSelected(selectedTagsList);
  }

  // 모든 선택 초기화 함수 수정 - 초기화 후 즉시 적용
  void _clearAllSelections() {
    setState(() {
      _selectedTags.forEach((key, value) {
        value.clear();
      });
    });

    // 선택 초기화 후 즉시 적용 (빈 목록 전달)
    _applyTagSelectionImmediately();
  }
}
