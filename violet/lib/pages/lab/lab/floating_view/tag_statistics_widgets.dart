import 'package:flutter/material.dart';
import 'package:violet/pages/lab/lab/floating_view/tag_statistics_models.dart';

class TagStatisticsPanel extends StatelessWidget {
  final Map<String, Map<String, int>> tagStatistics;
  final String selectedTagType;
  final Set<String> selectedTags;
  final String searchQuery;
  final int minAppearance;
  final Function(String) onTagTypeChanged;
  final Function(String, bool) onTagSelected;
  final Function(String) onSearchChanged;
  final Function(int) onMinAppearanceChanged;

  const TagStatisticsPanel({
    Key? key,
    required this.tagStatistics,
    required this.selectedTagType,
    required this.selectedTags,
    required this.searchQuery,
    required this.minAppearance,
    required this.onTagTypeChanged,
    required this.onTagSelected,
    required this.onSearchChanged,
    required this.onMinAppearanceChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Column(
        children: [
          _buildTagTypeSelector(),
          _buildTagFilterControls(),
          Expanded(
            child: _buildTagStatisticsList(selectedTagType),
          ),
        ],
      ),
    );
  }

  // 태그 타입 선택기
  Widget _buildTagTypeSelector() {
    return Container(
        // ... 태그 타입 선택기 UI 코드 ...
        );
  }

  // 태그 필터 컨트롤
  Widget _buildTagFilterControls() {
    return Container(
      // ... 검색 및 최소 등장 횟수 필터 컨트롤 ...
      child: Row(
        children: [
          // 검색창
          Expanded(
            flex: 3,
            child: TextField(
              // ... 검색창 속성 ...
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 8),
          // 최소 등장 횟수 입력
          Container(
            // ... 최소 등장 횟수 입력 필드 ...
            child: TextField(
              // ... 텍스트 필드 속성 ...
              controller: TextEditingController(text: minAppearance.toString()),
              onChanged: (value) {
                int? parsedValue = int.tryParse(value);
                if (parsedValue != null) {
                  onMinAppearanceChanged(parsedValue);
                }
              },
            ),
          ),
          const Spacer(),

          // 모든 태그 합계
          Text(
            '총 태그 종류: ${getTotalUniqueTagCount(tagStatistics)}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // 태그 통계 목록
  Widget _buildTagStatisticsList(String tagType) {
    // 태그 맵 가져오기
    final tagsMap = tagStatistics[tagType] ?? {};

    // 검색 및 최소 등장 횟수 필터 적용
    final filteredTags = filterTags(tagsMap, searchQuery, minAppearance);

    return ListView.builder(
      // ... ListView 속성 ...
      itemCount: filteredTags.length,
      itemBuilder: (context, index) {
        final tag = filteredTags.keys.elementAt(index);
        final count = filteredTags[tag]!;
        final isSelected = selectedTags.contains(tag);

        return TagListItem(
          tag: tag,
          count: count,
          isSelected: isSelected,
          onTagSelected: onTagSelected,
        );
      },
    );
  }
}

class TagListItem extends StatelessWidget {
  final String tag;
  final int count;
  final bool isSelected;
  final Function(String, bool) onTagSelected;

  const TagListItem({
    Key? key,
    required this.tag,
    required this.count,
    required this.isSelected,
    required this.onTagSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // ... 태그 리스트 아이템 UI 코드 ...
      title: Text(tag),
      subtitle: Text('$count회 등장'),
      selected: isSelected,
      onTap: () => onTagSelected(tag, !isSelected),
    );
  }
}
