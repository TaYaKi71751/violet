// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSavedServerUrl();
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
      child: Column(
        children: [
          Padding(
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
          if (_searchResults.isNotEmpty)
            Expanded(
              child: _buildResultsList(),
            ),
        ],
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
        hintText: '검색할 키워드를 입력하세요',
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
      padding: const EdgeInsets.all(16),
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
        children: [
          const Text(
            '검색 결과 요약',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
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

  Widget _buildResultsList() {
    final height = MediaQuery.of(context).size.height;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(8),
      cacheExtent: height * 3.0,
      itemCount: _searchResults.length,
      itemBuilder: (BuildContext ctxt, int index) {
        final result = _searchResults[index];
        return FutureBuilder(
          future: Future.delayed(const Duration(milliseconds: 100))
              .then((value) async {
            final provider = await getImageProviderFromId(result.id);
            final image = await provider.getThumbnailUrl();
            final header = await provider.getHeader(0);
            _urls![index] = image;

            return (image, header);
          }),
          builder:
              (context, AsyncSnapshot<(String, Map<String, String>)> snapshot) {
            if (!snapshot.hasData) {
              return Column(
                children: [
                  SizedBox(
                    height: _height![index] != 0 ? _height![index] : 200,
                    child: const Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text('ID: ${result.id}'),
                    subtitle: Text(result.reason),
                  ),
                ],
              );
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 2,
              child: InkWell(
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  showArticleInfoById(context, result.id);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                      child: VCachedNetworkImage(
                        key: _keys![index],
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(microseconds: 500),
                        fadeInCurve: Curves.easeIn,
                        imageUrl: snapshot.data!.$1,
                        httpHeaders: snapshot.data!.$2,
                        progressIndicatorBuilder: (context, string, progress) {
                          return SizedBox(
                            height: 200,
                            child: Center(
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  value: progress.progress,
                                ),
                              ),
                            ),
                          );
                        },
                        imageBuilder: (context, imageProvider, child) {
                          if (_height![index] == 0 || _height![index] == 200) {
                            Future.delayed(const Duration(milliseconds: 50))
                                .then((value) {
                              try {
                                final RenderBox renderBox = _keys![index]
                                    .currentContext!
                                    .findRenderObject()! as RenderBox;
                                final sizeRender = renderBox.size;
                                if (sizeRender.height != 200) {
                                  setState(() {
                                    _height![index] = sizeRender.height;
                                  });
                                }
                              } catch (_) {}
                            });
                          }
                          return child;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID: ${result.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            result.reason,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
