// 태그 통계 관련 헬퍼 함수들

// 전체 고유 태그 수 계산
int getTotalUniqueTagCount(Map<String, Map<String, int>> tagStatistics) {
  int total = 0;
  tagStatistics.forEach((type, tags) {
    total += tags.length;
  });
  return total;
}

// 태그 필터링 (검색어와 최소 등장 횟수로)
Map<String, int> filterTags(
    Map<String, int> tags, String query, int minAppearance) {
  if (query.isEmpty && minAppearance <= 1) {
    return tags;
  }

  final queryLower = query.toLowerCase();
  return Map.fromEntries(tags.entries.where((entry) {
    final tagName = entry.key.toLowerCase();
    final count = entry.value;
    return count >= minAppearance &&
        (query.isEmpty || tagName.contains(queryLower));
  }));
}

// 태그 정렬 (등장 횟수 또는 알파벳순)
List<MapEntry<String, int>> sortTags(Map<String, int> tags, String sortType) {
  final entries = tags.entries.toList();

  if (sortType == 'count') {
    // 등장 횟수순으로 정렬 (내림차순)
    entries.sort((a, b) => b.value.compareTo(a.value));
  } else {
    // 알파벳순으로 정렬
    entries.sort((a, b) => a.key.compareTo(b.key));
  }

  return entries;
}

// ... 필요한 추가 헬퍼 함수 ...
