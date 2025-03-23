import 'package:flutter/material.dart';

class ArticleListPanel extends StatelessWidget {
  final Map<String, dynamic> similarArticles;
  final Set<String> selectedTags;
  final String displayMode;
  final Function(String) onDisplayModeChanged;

  const ArticleListPanel({
    Key? key,
    required this.similarArticles,
    required this.selectedTags,
    required this.displayMode,
    required this.onDisplayModeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Column(
        children: [
          _buildDisplayControls(),
          _buildArticleList(),
        ],
      ),
    );
  }

  Widget _buildDisplayControls() {
    return Container(
      // ... 디스플레이 컨트롤 UI 코드 ...
      child: Row(
        children: [
          // 보기 모드 선택
          SegmentedButton<String>(
            // ... 세그먼트 버튼 속성 ...
            segments: [
              ButtonSegment<String>(value: 'list', label: Text('리스트')),
              ButtonSegment<String>(value: 'card', label: Text('카드')),
            ],
            selected: {displayMode},
            onSelectionChanged: (Set<String> newSelection) {
              onDisplayModeChanged(newSelection.first);
            },
          ),

          // 선택된 태그 표시
          Expanded(
            child: _buildSelectedTagChips(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTagChips() {
    return Wrap(
      // ... 선택된 태그 칩 래퍼 속성 ...
      children: selectedTags.map((tag) {
        return Chip(
          label: Text(tag),
          // ... 칩 속성 ...
        );
      }).toList(),
    );
  }

  Widget _buildArticleList() {
    // 선택된 태그에 따라 기사 필터링
    final filteredArticles = _filterArticles(similarArticles, selectedTags);

    if (displayMode == 'list') {
      return _buildArticleListView(filteredArticles);
    } else {
      return _buildArticleCardView(filteredArticles);
    }
  }

  Widget _buildArticleListView(List<dynamic> articles) {
    return ListView.builder(
      // ... ListView 속성 ...
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return ArticleListViewItem(article: article);
      },
    );
  }

  Widget _buildArticleCardView(List<dynamic> articles) {
    return GridView.builder(
      // ... GridView 속성 ...
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
      ),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return ArticleCard(article: article);
      },
    );
  }

  List<dynamic> _filterArticles(
      Map<String, dynamic> articles, Set<String> tags) {
    // ... 태그를 기반으로 기사 필터링 로직 ...
    if (tags.isEmpty) {
      return articles['articles'] ?? [];
    }

    // 선택된 태그가 있는 경우, 해당 태그를 포함하는 기사만 필터링
    final List<dynamic> allArticles = articles['articles'] ?? [];
    return allArticles.where((article) {
      // ... 필터링 로직 구현 ...
      return true; // 실제 필터링 로직으로 교체
    }).toList();
  }
}

class ArticleListViewItem extends StatelessWidget {
  final dynamic article;

  const ArticleListViewItem({Key? key, required this.article})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // ... 기사 목록 아이템 UI 코드 ...
      title: Text(article['title'] ?? '제목 없음'),
      subtitle: Text(article['summary'] ?? '내용 없음'),
      // ... 기타 속성 ...
    );
  }
}

class ArticleCard extends StatelessWidget {
  final dynamic article;

  const ArticleCard({Key? key, required this.article}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      // ... 카드 UI 코드 ...
      child: Column(
        children: [
          Text(article['title'] ?? '제목 없음'),
          Text(article['summary'] ?? '내용 없음'),
          // ... 기타 UI 요소 ...
        ],
      ),
    );
  }
}
