// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/common/toast.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/search.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/v_cached_network_image.dart';

class LLMSearchPage extends StatefulWidget {
  const LLMSearchPage({super.key});

  @override
  State<LLMSearchPage> createState() => _LLMSearchPageState();
}

class _LLMSearchPageState extends State<LLMSearchPage> {
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _searchQueryController = TextEditingController();
  final TextEditingController _kController = TextEditingController(text: '50');

  String _evaluate = '';
  bool _isLoading = false;

  LLMSearchService? _searchService;
  List<SearchResult> _searchResults = [];

  List<double>? _height;
  List<GlobalKey>? _keys;
  List<String>? _urls;

  // 검색 폼의 높이를 측정하기 위한 GlobalKey 추가
  final GlobalKey _searchFormKey = GlobalKey();
  double _searchFormHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSavedServerUrl();

    // 위젯이 렌더링된 후 검색 폼의 높이를 측정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureSearchFormHeight();
    });
  }

  @override
  void dispose() {
    if (_urls != null) {
      PaintingBinding.instance.imageCache.clear();
      imageCache.clearLiveImages();
      imageCache.clear();
      _evictImageUrls(_urls!);
    }
    super.dispose();
  }

  void _evictImageUrls(List<String> urls) {
    for (var url in urls) {
      if (url.isNotEmpty) {
        CachedNetworkImageProvider(url).evict();
      }
    }
  }

  Future<void> _loadSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('llm_search_server_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _serverUrlController.text = savedUrl;
    } else {
      _serverUrlController.text = 'http://localhost:8080';
    }
  }

  Future<void> _saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_search_server_url', url);
    Logger.info('[LLMSearchPage] 서버 URL 저장: $url');
  }

  void _search() async {
    if (_serverUrlController.text.isEmpty) {
      showToast(
        level: ToastLevel.error,
        message: '서버 URL을 입력해주세요.',
      );
      return;
    }

    if (_searchQueryController.text.isEmpty) {
      showToast(
        level: ToastLevel.error,
        message: '검색어를 입력해주세요.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _evaluate = '검색 중...';
      _searchResults = [];
    });

    try {
      _searchService ??= LLMSearchService(baseUrl: _serverUrlController.text);

      // 서버 URL이 변경된 경우 서비스 재생성
      if (_searchService!.baseUrl != _serverUrlController.text) {
        _searchService = LLMSearchService(baseUrl: _serverUrlController.text);
        await _saveServerUrl(_serverUrlController.text);
      }

      final int k = int.tryParse(_kController.text) ?? 50;

      final result = await _searchService!.searchJson(
        query: _queryController.text,
        searchQuery: _searchQueryController.text,
        k: k,
      );

      if (result.containsKey('error')) {
        setState(() {
          _evaluate = '오류: ${result['message'] ?? result['error']}';
          _isLoading = false;
        });
        return;
      }

      if (result.containsKey('evaluate') && result.containsKey('results')) {
        final evaluate = result['evaluate'] as String;
        final results = result['results'] as List<dynamic>;

        final searchResults = <SearchResult>[];

        for (var item in results) {
          if (item is Map<String, dynamic> &&
              item.containsKey('id') &&
              item.containsKey('reason')) {
            searchResults.add(SearchResult(
              id: item['id'] is int
                  ? item['id']
                  : int.tryParse(item['id'].toString()) ?? 0,
              reason: item['reason'].toString(),
            ));
          }
        }

        // 이미지 표시를 위한 초기화
        _height = List<double>.filled(searchResults.length, 0);
        _keys = List<GlobalKey>.generate(
            searchResults.length, (index) => GlobalKey());
        _urls = List<String>.filled(searchResults.length, '');

        setState(() {
          _evaluate = evaluate;
          _searchResults = searchResults;
          _isLoading = false;
        });
      } else {
        setState(() {
          _evaluate = '응답 형식이 올바르지 않습니다: ${result.toString()}';
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('[LLMSearchPage] 검색 오류: $e');
      setState(() {
        _evaluate = '검색 오류: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageCache imageCache = PaintingBinding.instance.imageCache;
    if (imageCache.currentSizeBytes >= (1024 + 256) << 20) {
      imageCache.clear();
      imageCache.clearLiveImages();
    }

    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: _searchResults.isEmpty
          ? _buildSearchForm() // 검색 결과가 없을 때는 기존 레이아웃 사용
          : _buildSearchResultsView(), // 검색 결과가 있을 때는 새로운 레이아웃 사용
    );
  }

  // 검색 폼의 실제 높이를 측정하는 메서드
  void _measureSearchFormHeight() {
    if (_searchFormKey.currentContext != null) {
      final RenderBox renderBox =
          _searchFormKey.currentContext!.findRenderObject() as RenderBox;
      setState(() {
        _searchFormHeight = renderBox.size.height;
      });
    }
  }

  // 검색 폼 위젯 (기존 레이아웃)
  Widget _buildSearchForm() {
    return Column(
      children: [
        Padding(
          key: _searchFormKey, // GlobalKey 추가
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTitle(),
              const SizedBox(height: 16),
              _buildServerUrlField(),
              const SizedBox(height: 12),
              _buildSearchQueryField(),
              const SizedBox(height: 12),
              _buildKField(),
              const SizedBox(height: 16),
              _buildSearchButton(),
              const SizedBox(height: 16),
              if (_evaluate.isNotEmpty) _buildEvaluateArea(),
            ],
          ),
        ),
      ],
    );
  }

  // 검색 결과 화면 (두 가지 페이즈를 가진 레이아웃)
  Widget _buildSearchResultsView() {
    // 동적으로 측정된 높이 사용 (기본값 설정)
    final double formHeight = _searchFormHeight > 0 ? _searchFormHeight : 350;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          // 스크롤 이벤트 처리 (필요한 경우)
          return false;
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 첫 번째 페이즈: 스크롤을 올렸을 때 보이는 영역 (초기 검색 화면과 동일)
            SliverAppBar(
              pinned: false,
              floating: true,
              snap: true,
              expandedHeight: formHeight, // 동적으로 측정된 높이 사용
              backgroundColor:
                  Settings.themeWhat ? Colors.grey.shade900 : Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTitle(),
                      const SizedBox(height: 16),
                      _buildServerUrlField(),
                      const SizedBox(height: 12),
                      _buildSearchQueryField(),
                      const SizedBox(height: 12),
                      _buildKField(),
                      const SizedBox(height: 16),
                      _buildSearchButton(),
                    ],
                  ),
                ),
              ),
            ),

            // 두 번째 페이즈: 스크롤을 내렸을 때 보이는 영역 (검색 결과 요약만)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchResultsHeaderDelegate(
                child: Container(
                  color:
                      Settings.themeWhat ? Colors.grey.shade900 : Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildEvaluateArea(), // 검색 결과 요약만 표시
                    ],
                  ),
                ),
              ),
            ),

            // 검색 결과가 있을 때만 그리드 표시
            if (_searchResults.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == 0) {
                        return _buildResultsGrid();
                      }
                      return null;
                    },
                    childCount: 1,
                  ),
                ),
              )
            else
              // 검색 결과가 없을 때 메시지 표시
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      '검색 결과가 없습니다.',
                      style: TextStyle(
                        color: Settings.themeWhat
                            ? Colors.white70
                            : Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Center(
      child: Text(
        'LLM 검색',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildServerUrlField() {
    return TextField(
      controller: _serverUrlController,
      decoration: const InputDecoration(
        labelText: '서버 URL',
        hintText: 'http://localhost:8080',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSearchQueryField() {
    return TextField(
      controller: _searchQueryController,
      decoration: const InputDecoration(
        labelText: '검색어 (search_query)',
        hintText: '검색 내용을 입력하세요',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildKField() {
    return TextField(
      controller: _kController,
      decoration: const InputDecoration(
        labelText: '검색 문서 수 (k)',
        hintText: '50',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildSearchButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _search,
      style: ElevatedButton.styleFrom(
        backgroundColor: Settings.majorColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text(
              '검색',
              style: TextStyle(fontSize: 16),
            ),
    );
  }

  Widget _buildEvaluateArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Settings.themeWhat ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              Settings.themeWhat ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                '검색 결과 요약',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              // 검색어 표시 (간결하게)
              Text(
                '검색어: ${_searchQueryController.text}',
                style: TextStyle(
                  color: Settings.themeWhat ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _evaluate,
            style: TextStyle(
              color: Settings.themeWhat ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 화면 너비에 따라 컬럼 수 결정
        int crossAxisCount = _calculateColumnCount(constraints.maxWidth);

        // 결과가 없으면 빈 컨테이너 반환
        if (_searchResults.isEmpty) {
          return const SizedBox.shrink();
        }

        // 결과 개수에 따라 높이 계산 (최소 높이 설정)
        final double itemHeight = 300.0; // 각 아이템의 평균 높이
        final double totalHeight =
            _searchResults.length * itemHeight / crossAxisCount;
        final double minHeight =
            MediaQuery.of(context).size.height * 0.5; // 최소 높이
        final double gridHeight =
            totalHeight > minHeight ? totalHeight : minHeight;

        return SizedBox(
          height: gridHeight,
          child: MasonryGridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            itemCount: _searchResults.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              return _buildResultCard(index);
            },
          ),
        );
      },
    );
  }

  // 화면 너비에 따라 컬럼 수 계산
  int _calculateColumnCount(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    if (width < 1500) return 4;
    return 5;
  }

  Widget _buildResultCard(int index) {
    final result = _searchResults[index];

    return FutureBuilder(
      future:
          Future.delayed(const Duration(milliseconds: 100)).then((value) async {
        final provider = await getImageProviderFromId(result.id);
        final image = await provider.getThumbnailUrl();
        final header = await provider.getHeader(0);
        _urls![index] = image;

        return (image, header);
      }),
      builder:
          (context, AsyncSnapshot<(String, Map<String, String>)> snapshot) {
        if (!snapshot.hasData) {
          return Card(
            elevation: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 16),
                Text(
                  'ID: ${result.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    result.reason,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }

        return Card(
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              FocusScope.of(context).unfocus();
              showArticleInfoById(context, result.id);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지 영역
                FutureBuilder<Size>(
                  future: _calculateImageDimension(
                      snapshot.data!.$1, snapshot.data!.$2),
                  builder: (context, sizeSnapshot) {
                    // 이미지 크기 정보가 있으면 실제 비율 사용, 없으면 기본값 사용
                    double aspectRatio = 1.0; // 기본값
                    if (sizeSnapshot.hasData) {
                      aspectRatio =
                          sizeSnapshot.data!.width / sizeSnapshot.data!.height;
                      // 너무 극단적인 비율 방지
                      if (aspectRatio > 2.5) aspectRatio = 2.5;
                      if (aspectRatio < 0.4) aspectRatio = 0.4;
                    }

                    return AspectRatio(
                      aspectRatio: aspectRatio,
                      child: Container(
                        color: Settings.themeWhat
                            ? Colors.black12
                            : Colors.grey.shade100,
                        child: Hero(
                          tag: 'result_image_${result.id}',
                          child: VCachedNetworkImage(
                            key: _keys![index],
                            fit: BoxFit.contain, // 이미지가 짤리지 않고 전체가 보이도록 함
                            fadeInDuration: const Duration(microseconds: 500),
                            fadeInCurve: Curves.easeIn,
                            imageUrl: snapshot.data!.$1,
                            httpHeaders: snapshot.data!.$2,
                            progressIndicatorBuilder:
                                (context, string, progress) {
                              return Center(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    value: progress.progress,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // ID 표시 영역
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Text(
                    'ID: ${result.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                // 설명 텍스트 영역
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    result.reason,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Size> _calculateImageDimension(
      String url, Map<String, String> header) {
    Completer<Size> completer = Completer();
    Image image =
        Image(image: CachedNetworkImageProvider(url, headers: header));
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          completer.complete(size);
        },
      ),
    );
    return completer.future;
  }
}

class SearchResult {
  final int id;
  final String reason;

  SearchResult({required this.id, required this.reason});
}

// 검색 결과 헤더 델리게이트 클래스 (스크롤 시 고정되는 헤더)
class _SearchResultsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SearchResultsHeaderDelegate({
    required this.child,
  });

  @override
  double get minExtent => 120; // 검색 결과 요약만 표시하므로 높이 축소

  @override
  double get maxExtent => 120; // 검색 결과 요약만 표시하므로 높이 축소

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SearchResultsHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
