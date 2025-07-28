// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/log/log.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/common/toast.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/segment/filter_page.dart';
import 'package:violet/pages/segment/filter_page_controller.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/util/evict_image_urls.dart';
import 'package:violet/widgets/cupertino_switch_list_tile.dart';

class CropBookmarkPage extends StatefulWidget {
  const CropBookmarkPage({super.key, this.bookmarks});

  final List<BookmarkCropImage>? bookmarks;

  @override
  State<CropBookmarkPage> createState() => _CropBookmarkPageState();
}

class _CropBookmarkPageState extends State<CropBookmarkPage> {
  final ValueNotifier<int> columnCount =
      ValueNotifier(Settings.cropBookmarkAlign.value);
  final ValueNotifier<bool> showOverlay =
      ValueNotifier(Settings.cropBookmarkShowOverlay.value);
  bool sortDesc = Settings.cropBookmarkSortDesc.value;
  final FilterController _filterController =
      FilterController(heroKey: 'cropbookmark');
  List<int> _filterIds = [];

  List<String>? imagesUrlForEvict;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      FirebaseAnalytics.instance.logEvent(name: 'open_crop');
    }
  }

  @override
  void dispose() {
    super.dispose();
    evictImageUrls(imagesUrlForEvict);
  }

  bool _isCapturing = false;
  final GlobalKey _captureKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    final listView = FutureBuilder(
      future: widget.bookmarks != null
          ? Future.value(widget.bookmarks)
          : Bookmark.getInstance().then((value) => value.getCropImages()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();
        var imgs = snapshot.data!;
        if (_filterIds.isNotEmpty) {
          imgs = imgs.where((e) => _filterIds.contains(e.article())).toList();
        }
        if (sortDesc) imgs = imgs.reversed.toList();
        imagesUrlForEvict = List<String>.filled(imgs.length, '');

        final masonryGrid = MasonryGridView.count(
          key: _isCapturing ? null : PageStorageKey('lazyGrid'), // 스크롤 위치 유지
          physics: _isCapturing
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          shrinkWrap: _isCapturing, // 전체 렌더링 여부
          crossAxisCount: columnCount.value,
          mainAxisSpacing: 6.0 / columnCount.value,
          crossAxisSpacing: 6.0 / columnCount.value,
          itemCount: imgs.length,
          cacheExtent: height * 3.0,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final e = imgs[index];
            final area =
                e.area().split(',').map((e) => double.parse(e)).toList();
            return buildItem(
              e,
              index,
              e.article(),
              e.page(),
              Rect.fromLTRB(area[0], area[1], area[2], area[3]),
              e.aspectRatio(),
            );
          },
        );

        if (_isCapturing) {
          return SingleChildScrollView(
            child: RepaintBoundary(
              key: _captureKey,
              child: masonryGrid,
            ),
          );
        } else {
          return masonryGrid;
        }
      },
    );

    return CupertinoPageScaffold(
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Crop Bookmark'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _filter(context),
                  child: const Icon(MdiIcons.filter),
                ),
                if (_isCapturing)
                  const CupertinoActivityIndicator()
                else
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _startCapture,
                    child: const Icon(CupertinoIcons.camera),
                  ),
                settingMenu(),
              ],
            ),
          ),
        ],
        body: listView,
      ),
    );
  }

  Widget buildItem(
    BookmarkCropImage crop,
    int index,
    int articleId,
    int page,
    Rect rect,
    double aspectRatio,
  ) {
    return FutureBuilder(
      future:
          Future.delayed(const Duration(milliseconds: 100)).then((value) async {
        final provider = await getImageProviderFromId(articleId);
        final image = await provider.getImageUrl(page);
        final header = await provider.getHeader(page);
        imagesUrlForEvict![index] = image;
        return (image, header);
      }),
      builder:
          (context, AsyncSnapshot<(String, Map<String, String>)> snapshot) {
        final width = (MediaQuery.of(context).size.width -
                (6.0 / columnCount.value) * (columnCount.value - 1)) /
            columnCount.value;
        final cropRawAspectRatio =
            calculateCropRawAspectRatio(width, aspectRatio, rect);

        if (!snapshot.hasData) {
          return AspectRatio(
            aspectRatio: cropRawAspectRatio,
            child: const Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return Material(
          child: AspectRatio(
            aspectRatio: cropRawAspectRatio,
            child: Stack(
              children: [
                CropImageWidget(
                  articleId: articleId,
                  page: page,
                  url: snapshot.data!.$1,
                  headers: snapshot.data!.$2,
                  rect: rect,
                  aspectRatio: aspectRatio,
                  columnCount: columnCount.value,
                  showOverlay: showOverlay,
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        showArticleInfoById(context, articleId);
                      },
                      onDoubleTap: () async {
                        showViewer(context, articleId, page);
                      },
                      onLongPress: () async {
                        if (await showYesNoDialog(context, '북마크를 삭제할까요?')) {
                          await (await Bookmark.getInstance())
                              .deleteCropBookmark(crop);
                          setState(() {});
                        }
                      },
                      highlightColor:
                          Theme.of(context).highlightColor.withOpacity(0.15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget settingMenu() {
    return PullDownButton(
      itemBuilder: (context) => [
        PullDownMenuActionsRow.medium(
          items: [
            PullDownMenuItem(
              title: 'Export',
              icon: CupertinoIcons.arrowshape_turn_up_left,
              onTap: () async {
                final crops =
                    await (await Bookmark.getInstance()).getCropImages();
                if (!context.mounted) return;
                await showOkDialog(
                    context, jsonEncode(crops), 'Export Crop Bookmarks');
              },
            ),
            PullDownMenuItem(
              title: 'Import',
              icon: CupertinoIcons.square_arrow_down,
              onTap: () async {
                final text = TextEditingController();
                if (await showOkCancelDialog(
                  titleText: 'Import Crop Bookmarks',
                  context: context,
                  contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  contentBuilder: (_) => TextField(
                    controller: text,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 999,
                  ),
                )) {
                  try {
                    var arr = jsonDecode(text.text);
                    if (arr is Map<String, dynamic>) {
                      arr = <dynamic>[arr];
                    }

                    final bookmark = await Bookmark.getInstance();

                    for (var e in arr as List<dynamic>) {
                      final elem = e as Map<String, dynamic>;
                      await bookmark.insertCropImage(elem['article'],
                          elem['page'], elem['area'], elem['aspectRatio'],
                          logging: false);
                    }

                    showToast(
                      level: ToastLevel.check,
                      message: 'Successful Importing!',
                    );
                    setState(() {});
                  } catch (e) {
                    showToast(
                      level: ToastLevel.error,
                      message: 'Import Error! Check Log!',
                    );
                    Logger.error('[Import Crop] $e');
                  }
                }
              },
            ),
          ],
        ),
        const PullDownMenuTitle(title: Text('Column Align')),
        SliderMenuItem(
          initialValue: columnCount.value,
          onChanged: (int value) async {
            await Settings.cropBookmarkAlign.setValue(value);
            setState(() {
              columnCount.value = value;
            });
          },
        ),
        const PullDownMenuTitle(title: Text('Show Options')),
        SwitchMenuItem(
          title: 'Show Overlay',
          initialValue: showOverlay.value,
          onChanged: (bool value) async {
            await Settings.cropBookmarkShowOverlay.setValue(value);
            showOverlay.value = value;
          },
        ),
        SwitchMenuItem(
          title: 'Sort Descending',
          initialValue: sortDesc,
          onChanged: (bool value) async {
            await Settings.cropBookmarkSortDesc.setValue(value);
            sortDesc = value;
            setState(() {});
          },
        ),
        const PullDownMenuTitle(title: Text('Others')),
        PullDownMenuItem(
          title: 'User Bookmarks',
          icon: CupertinoIcons.bookmark,
          onTap: () async {
            final dir = await getApplicationDocumentsDirectory();
            final dio = Dio();
            await dio.download(
                'https://github.com/project-violet/violet/raw/dev/violet/assets/daily.zip',
                '${dir.path}/daily.zip');

            final inputStream = InputFileStream('${dir.path}/daily.zip');
            final archive = ZipDecoder().decodeBytes(inputStream.toUint8List());
            for (final file in archive.files) {
              if (file.name == 'violet/assets/daily/crop-bookmarks.json') {
                final outputStream = OutputMemoryStream();
                file.writeContent(outputStream);

                final json = jsonDecode(utf8.decode(outputStream.getBytes()));
                List<BookmarkCropImage> bookmarks = [];
                for (final e in json as List<dynamic>) {
                  final bookmark = BookmarkCropImage(result: {
                    'Article': e['article'],
                    'Page': e['page'],
                    'Area': e['area'],
                    'AspectRatio': e['aspectRatio'],
                    'DateTime': e['datetime'],
                  });
                  bookmarks.add(bookmark);
                }

                if (!context.mounted) return;
                PlatformNavigator.navigateSlide(
                  context,
                  CropBookmarkPage(
                      bookmarks: bookmarks
                          .sortedBy((e) => DateTime.parse(e.datetime()))
                          .toList()),
                  opaque: false,
                );
              }
            }
          },
        ),
        // TODO: enable select mode
        // const PullDownMenuDivider.large(),
        // PullDownMenuItem(
        //   title: 'Select',
        //   onTap: () {},
        //   icon: CupertinoIcons.checkmark_circle,
        // ),
      ],
      animationBuilder: null,
      position: PullDownMenuPosition.automatic,
      buttonBuilder: (_, showMenu) => CupertinoButton(
        onPressed: showMenu,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.zero,
        alignment: Alignment.centerRight,
        child: const Icon(CupertinoIcons.ellipsis_circle),
      ),
    );
  }

  Future<void> _filter(BuildContext context) async {
    final bookmarks = widget.bookmarks ??
        await (await Bookmark.getInstance()).getCropImages();
    final ids = bookmarks.map((e) => e.article()).toList();
    final queryResults = await QueryManager.queryIds(ids);

    if (!context.mounted) return;
    await PlatformNavigator.navigateSlide(
      context,
      Provider<FilterController>.value(
        value: _filterController,
        child: FilterPage(
          queryResult: queryResults,
        ),
      ),
    );

    final filtered = _filterController.applyFilter(queryResults);
    setState(() {
      _filterIds = filtered.map((e) => e.id()).toList();
    });
  }

  void _startCapture() async {
    setState(() => _isCapturing = true);

    // 한 프레임 기다렸다가 렌더링 완료 후 캡처
    await Future.delayed(Duration(milliseconds: 10000));
    await Future.delayed(Duration.zero); // flutter 프레임 캐치

    RenderRepaintBoundary boundary =
        _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    final image = await boundary.toImage(pixelRatio: 10.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) return;

    setState(() => _isCapturing = false);

    final pngBytes = byteData.buffer.asUint8List();

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/masonry_capture.png');
    await file.writeAsBytes(pngBytes);
  }
}

double calculateCropRawAspectRatio(
    double width, double aspectRatio, Rect cropRect) {
  final height = width / aspectRatio;

  final cropSize = Size(cropRect.width * width, cropRect.height * height);
  return cropSize.width / cropSize.height;
}

class CropImageWidget extends StatefulWidget {
  final String url;
  final Map<String, String> headers;
  final int articleId;
  final int page;
  final Rect rect;
  final double aspectRatio;
  final int columnCount;
  final ValueNotifier<bool> showOverlay;

  const CropImageWidget({
    super.key,
    required this.url,
    required this.headers,
    required this.articleId,
    required this.page,
    required this.rect,
    required this.aspectRatio,
    required this.columnCount,
    required this.showOverlay,
  });

  @override
  State<CropImageWidget> createState() => _CropImageWidgetState();
}

class _CropImageWidgetState extends State<CropImageWidget> {
  double? height;
  double? originalAspectRatio;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width -
            (6.0 / widget.columnCount) * (widget.columnCount - 1)) /
        widget.columnCount;
    final height = width / widget.aspectRatio;

    // 참고: https://github.com/project-violet/violet/pull/363#issuecomment-1908442196
    final cropSize =
        Size(widget.rect.width * width, widget.rect.height * height);
    final cropRawAspectRatio = cropSize.width / cropSize.height;
    final cropRawRect = Rect.fromLTRB(
      widget.rect.left * width,
      widget.rect.top * height,
      widget.rect.right * width,
      widget.rect.bottom * height,
    );

    late final Size viewRawSize;
    late final double translateRatio;

    final rawAspectRatio = width / height;
    if (cropRawAspectRatio / rawAspectRatio <= 1.0) {
      final viewHeight = width / cropRawAspectRatio;
      viewRawSize = Size(width, viewHeight);
      translateRatio = 1.0;
    } else {
      // 실제 viewWidth는 width와 같지만 cropRect, scale의 계산 편의를 위해 height에 상대적으로 설정
      // translateRatio로 후 보정함
      final viewWidth = height * cropRawAspectRatio;
      viewRawSize = Size(viewWidth, height);
      translateRatio = viewWidth / width;
    }

    final cropRect = Rect.fromLTRB(
      cropRawRect.left / viewRawSize.width,
      cropRawRect.top / viewRawSize.height,
      cropRawRect.right / viewRawSize.width,
      cropRawRect.bottom / viewRawSize.height,
    );

    final image = ExtendedImage.network(
      widget.url,
      fit: BoxFit.contain,
      alignment: Alignment.topLeft,
      headers: widget.headers,
      retries: 100,
      timeRetry: const Duration(milliseconds: 300),
      clearMemoryCacheWhenDispose: true,
      handleLoadingProgress: true,
      loadStateChanged: (ExtendedImageState state) {
        if (state.extendedImageLoadState == LoadState.failed) {
          state.reLoadImage();
          return const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state.extendedImageInfo == null) {
          return Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                value: state.loadingProgress == null
                    ? null
                    : state.loadingProgress!.cumulativeBytesLoaded /
                        state.loadingProgress!.expectedTotalBytes!,
              ),
            ),
          );
        }

        return state.completedWidget;
      },
    );

    // TODO: remove me
    // final image = VCachedNetworkImage(
    //   fit: BoxFit.contain,
    //   alignment: Alignment.topLeft,
    //   fadeInDuration: const Duration(microseconds: 500),
    //   fadeInCurve: Curves.easeIn,
    //   imageUrl: widget.url,
    //   httpHeaders: widget.headers,
    //   progressIndicatorBuilder: (context, string, progress) {
    //     return Center(
    //       child: SizedBox(
    //         width: 30,
    //         height: 30,
    //         child: CircularProgressIndicator(value: progress.progress),
    //       ),
    //     );
    //   },
    // );

    final imageArea = AspectRatio(
      aspectRatio: cropRawAspectRatio,
      child: Transform.scale(
        scaleX: viewRawSize.width / cropRawRect.width,
        scaleY: viewRawSize.height / cropRawRect.height,
        alignment: Alignment.topLeft,
        child: Transform.translate(
          offset: Offset(-cropRawRect.left / translateRatio,
              -cropRawRect.top / translateRatio),
          child: ClipRect(
            clipper: RectClipper(cropRect),
            child: image,
          ),
        ),
      ),
    );

    final pageOverlay = Align(
      alignment: FractionalOffset.bottomRight,
      child: Transform(
        transform: Matrix4.identity()..scale(0.9),
        child: Theme(
          data: ThemeData(
            useMaterial3: false,
            canvasColor: Colors.transparent,
          ),
          child: RawChip(
            labelPadding: const EdgeInsets.all(0.0),
            label: Text(
              '${widget.articleId} (${widget.page + 1} Page)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.0,
              ),
            ),
            elevation: 6.0,
            shadowColor: Colors.grey[60],
            padding: const EdgeInsets.symmetric(
              vertical: 6.0,
              horizontal: 10.0,
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        imageArea,
        ValueListenableBuilder(
          valueListenable: widget.showOverlay,
          builder: (context, value, child) {
            return Visibility(
              visible: value,
              child: pageOverlay,
            );
          },
        ),
      ],
    );
  }
}

class RectClipper extends CustomClipper<Rect> {
  final Rect rect;

  RectClipper(this.rect);

  @override
  Rect getClip(Size size) {
    final x1 = size.width * rect.left;
    final y1 = size.height * rect.top;
    final x2 = size.width * rect.right;
    final y2 = size.height * rect.bottom;
    return Rect.fromPoints(Offset(x1, y1), Offset(x2, y2));
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}

@immutable
class SliderMenuItem extends StatefulWidget implements PullDownMenuEntry {
  const SliderMenuItem({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final int initialValue;
  final ValueChanged<int> onChanged;

  @override
  State<SliderMenuItem> createState() => _SliderMenuItemState();
}

class _SliderMenuItemState extends State<SliderMenuItem> {
  late int value = widget.initialValue;

  void onChanged(double v) {
    setState(() => value = v.toInt());

    widget.onChanged(v.toInt());
  }

  @override
  Widget build(BuildContext context) => CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.light),
        child: CupertinoSlider(
          value: value.toDouble(),
          min: 1,
          max: 8,
          onChanged: onChanged,
        ),
      );
}

@immutable
class SwitchMenuItem extends StatefulWidget implements PullDownMenuEntry {
  const SwitchMenuItem({
    super.key,
    required this.title,
    required this.initialValue,
    required this.onChanged,
  });

  final String title;
  final bool initialValue;
  final ValueChanged<bool> onChanged;

  @override
  State<SwitchMenuItem> createState() => _SwitchMenuItemState();
}

class _SwitchMenuItemState extends State<SwitchMenuItem> {
  late bool value = widget.initialValue;

  void onChanged(bool v) {
    setState(() => value = v);

    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Theme.of(context).textTheme.titleMedium!.fontSize!;

    return Material(
      color: Colors.transparent,
      child: CupertinoSwitchListTile(
        title: Text(
          widget.title,
          style: TextStyle(fontSize: fontSize),
        ),
        activeColor: CupertinoColors.activeGreen,
        value: value,
        onChanged: onChanged,
        dense: true,
      ),
    );
  }
}
