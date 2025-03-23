import 'package:flutter/material.dart';

class TagFilterControl extends StatelessWidget {
  final String searchQuery;
  final int minAppearance;
  final Function(String) onSearchChanged;
  final Function(int) onMinAppearanceChanged;

  const TagFilterControl({
    Key? key,
    required this.searchQuery,
    required this.minAppearance,
    required this.onSearchChanged,
    required this.onMinAppearanceChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 검색창
        Expanded(
          flex: 3,
          child: TextField(
            // ... 검색창 속성 ...
            decoration: InputDecoration(
                // ... 검색창 장식 ...
                ),
            controller: TextEditingController(text: searchQuery),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: 8),

        // 최소 등장 횟수 입력
        Container(
          // ... 최소 등장 횟수 입력 필드 ...
          child: TextField(
            // ... 최소 등장 필드 속성 ...
            controller: TextEditingController(text: minAppearance.toString()),
            onChanged: (value) {
              int? parsedValue = int.tryParse(value);
              if (parsedValue != null) {
                onMinAppearanceChanged(parsedValue);
              }
            },
          ),
        ),
      ],
    );
  }
}

class TagTypeSelector extends StatelessWidget {
  final Map<String, Map<String, int>> tagStatistics;
  final String selectedTagType;
  final Function(String) onTagTypeChanged;

  const TagTypeSelector({
    Key? key,
    required this.tagStatistics,
    required this.selectedTagType,
    required this.onTagTypeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tagTypes = tagStatistics.keys.toList();

    return Container(
      // ... 태그 타입 선택기 UI 코드 ...
      child: SegmentedButton<String>(
        // ... 세그먼트 버튼 속성 ...
        segments: tagTypes
            .map((type) => ButtonSegment<String>(
                  value: type,
                  label: Text(type),
                ))
            .toList(),
        selected: {selectedTagType},
        onSelectionChanged: (Set<String> newSelection) {
          onTagTypeChanged(newSelection.first);
        },
      ),
    );
  }
}
