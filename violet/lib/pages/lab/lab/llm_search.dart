// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:violet/database/user/llm_search.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/common/toast.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/search.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/v_cached_network_image.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class LLMSearchPage extends StatefulWidget {
  const LLMSearchPage({super.key});

  @override
  State<LLMSearchPage> createState() => _LLMSearchPageState();
}

class _LLMSearchPageState extends State<LLMSearchPage> {
  final TextEditingController _searchQueryController = TextEditingController();
  final TextEditingController _kController = TextEditingController(text: '50');
  bool _strictRelevance = false;
  bool _showEvaluate = false;

  String _evaluate = '';
  bool _isLoading = false;

  LLMSearchService? _searchService;
  List<SearchResult> _searchResults = [];

  List<GlobalKey>? _keys;
  List<String>? _urls;

  @override
  void initState() {
    super.initState();
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

  Future<void> _saveSearchLog() async {
    final db = await LLMSearchLogDatabase.getInstance();
    final log = LLMSearchLog(
      query: _searchQueryController.text,
      k: int.tryParse(_kController.text) ?? 50,
      strictRelevance: _strictRelevance,
      timestamp: DateTime.now(),
    );
    await db.insert(log);
  }

  void _search() async {
    if (_searchQueryController.text.isEmpty) {
      showToast(
        level: ToastLevel.error,
        message: '검색어를 입력해주세요.',
      );
      return;
    }

    await _saveSearchLog();

    setState(() {
      _isLoading = true;
      _evaluate = '검색 중...';
      _searchResults = [];
    });

    try {
      _searchService ??= LLMSearchService();

      final int k = int.tryParse(_kController.text) ?? 50;

      final result = await _searchService!.searchJson(
        query: _searchQueryController.text,
        k: k,
        strictRelevance: _strictRelevance,
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTitle(),
                const SizedBox(height: 16),
                _buildSearchRow(),
                _buildSearchOptions(),
                _buildEvaluateArea(),
              ],
            ),
          ),
          if (_searchResults.isNotEmpty)
            Expanded(
              child: _buildResultsGrid(),
            ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return const LLMSearchInfoDialog();
          },
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: SvgPicture.asset(
              'assets/icons/llm-search.svg',
              width: 42,
              height: 42,
              colorFilter: ColorFilter.mode(
                Settings.themeWhat.value ? Colors.white : Colors.black87,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Violet LLM Search',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TypeAheadField<String>(
            textFieldConfiguration: TextFieldConfiguration(
              controller: _searchQueryController,
              decoration: const InputDecoration(
                labelText: '검색어',
                hintText: '검색할 키워드를 입력하세요',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            suggestionsCallback: (pattern) async {
              final db = await LLMSearchLogDatabase.getInstance();
              final queries = await db.getQueries();
              return queries
                  .where((query) =>
                      query.toLowerCase().contains(pattern.toLowerCase()))
                  .toSet()
                  .toList();
            },
            itemBuilder: (context, String suggestion) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0.0,
                  horizontal: 16.0,
                ),
                title: Text(suggestion),
                dense: true,
              );
            },
            onSuggestionSelected: (String suggestion) {
              _searchQueryController.text = suggestion;
            },
            hideOnEmpty: true,
            hideOnLoading: true,
            direction: AxisDirection.down,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: TextField(
            controller: _kController,
            decoration: const InputDecoration(
              labelText: '문서 수',
              hintText: '50',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _search,
            style: ElevatedButton.styleFrom(
              backgroundColor: Settings.majorColor.value,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              minimumSize: const Size(80, 48),
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
          ),
        ),
      ],
    );
  }

  Widget _buildSearchOptions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _strictRelevance = !_strictRelevance;
              });
            },
            child: Row(
              children: [
                Checkbox(
                    value: _strictRelevance,
                    onChanged: (value) {
                      setState(() {
                        _strictRelevance = value ?? false;
                      });
                    },
                    activeColor: Settings.majorColor.value),
                const Text(
                  '정확한 검색',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  '(관련성이 높은 결과만 표시)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Settings.themeWhat.value
                        ? Colors.grey
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_evaluate.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showEvaluate = !_showEvaluate;
                });
              },
              icon: Icon(
                _showEvaluate ? Icons.expand_less : Icons.expand_more,
                color: Settings.themeWhat.value ? Colors.white : Colors.black87,
              ),
              label: Text(
                '검색 결과 요약',
                style: TextStyle(
                  color:
                      Settings.themeWhat.value ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEvaluateArea() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      offset: Offset(0, _showEvaluate ? 0 : -0.1),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        scale: _showEvaluate ? 1.0 : 0.95,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(top: _showEvaluate ? 8 : 0),
          height: _showEvaluate ? null : 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              opacity: _showEvaluate ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Settings.themeWhat.value
                      ? Colors.black26
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Settings.themeWhat.value
                        ? Colors.grey.shade800
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  _evaluate,
                  style: TextStyle(
                    color: Settings.themeWhat.value
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = _calculateColumnCount(constraints.maxWidth);
        final height = MediaQuery.of(context).size.height;

        return MasonryGridView.count(
          physics: const BouncingScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 4.0,
          crossAxisSpacing: 4.0,
          itemCount: _searchResults.length,
          padding: const EdgeInsets.all(8),
          cacheExtent: height * 30.0,
          itemBuilder: (context, index) {
            return _buildResultCard(index);
          },
        );
      },
    );
  }

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
            child: InkWell(
              onTap: () async {
                FocusScope.of(context).unfocus();
                showArticleInfoById(context, result.id);
              },
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
                FutureBuilder<Size>(
                  future: _calculateImageDimension(
                      snapshot.data!.$1, snapshot.data!.$2),
                  builder: (context, sizeSnapshot) {
                    double aspectRatio = 1.0;
                    if (sizeSnapshot.hasData) {
                      aspectRatio =
                          sizeSnapshot.data!.width / sizeSnapshot.data!.height;
                      if (aspectRatio > 2.5) aspectRatio = 2.5;
                      if (aspectRatio < 0.4) aspectRatio = 0.4;
                    }

                    return AspectRatio(
                      aspectRatio: aspectRatio,
                      child: Container(
                        color: Settings.themeWhat.value
                            ? Colors.black12
                            : Colors.grey.shade100,
                        child: Hero(
                          tag: 'result_image_${result.id}',
                          child: VCachedNetworkImage(
                            key: _keys![index],
                            fit: BoxFit.contain,
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

class LLMSearchInfoDialog extends StatelessWidget {
  const LLMSearchInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 500,
        height: 250,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: SvgPicture.asset(
                'assets/icons/llm-search.svg',
                width: 96,
                height: 96,
                colorFilter: ColorFilter.mode(
                  Settings.themeWhat.value ? Colors.white : Colors.black87,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Violet LLM Search',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'A manga search engine powered by retrieval-augmented generation.\nDeveloped using various open-source tools and APIs, including Cursor, Claude, EasyOCR, DeepSeek, and Gemini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
