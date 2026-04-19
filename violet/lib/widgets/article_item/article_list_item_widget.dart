// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:extended_wrap/extended_wrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart' as locale;
import 'package:violet/model/article_list_item.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/server/violet_v2.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/util/call_once.dart';
import 'package:violet/widgets/article_item/article_list_item_widget_controller.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/article_item/thumbnail.dart';
import 'package:violet/widgets/article_item/thumbnail_view_page.dart';
import 'package:violet/widgets/toast.dart';

class ArticleListItemWidget extends StatefulWidget {
  final bool isChecked;
  final bool isCheckMode;

  const ArticleListItemWidget({
    super.key,
    this.isChecked = false,
    this.isCheckMode = false,
  });

  @override
  State<ArticleListItemWidget> createState() => _ArticleListItemWidgetState();
}

class _ArticleListItemWidgetState extends State<ArticleListItemWidget>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<ArticleListItemWidget> {
  late CallOnce initProvider;
  late ArticleListItem data;
  late ArticleListItemWidgetController c;
  late String getxId;

  @override
  bool get wantKeepAlive => true;

  bool animating = false;

  RxBool isChecked = false.obs;

  @override
  void initState() {
    super.initState();
    initProvider = CallOnce(initAfterProvider);

    isChecked.value = widget.isChecked;
  }

  initAfterProvider() {
    data = Provider.of<ArticleListItem>(context);
    getxId = const Uuid().v4();
    c = Get.put(ArticleListItemWidgetController(data), tag: getxId);
    updateIdOnlyArticle();
  }

  // This checks QueryResult then do idQueryWeb
  // when QueryResult keys was only exists 'Id'
  updateIdOnlyArticle() async {
    // When queryResult is only id
    if (c.articleListItem.queryResult.result.keys.length == 1 &&
        c.articleListItem.queryResult.result.keys.lastOrNull == 'Id') {
      final query = await HentaiManager.idQueryWeb(
        '${c.articleListItem.queryResult.id()}',
      );

      // Update ArticleListItem to new
      data = ArticleListItem.fromJson({
        ...c.articleListItem.toJson(),
        'queryResult': query,
      });

      // Swap data of new
      c.dispose();
      c = ArticleListItemWidgetController(data);

      // Swap local ArticleListItemWidgetController
      // https://stackoverflow.com/questions/67250736/flutter-getx-how-to-remove-initialized-controller-every-time-we-navigate-to-oth
      Get.delete<ArticleListItemWidgetController>(tag: getxId, force: true);
      Get.put(c, tag: getxId);

      setState(() {
        _shouldReload = true;
      });
    }
  }

  @override
  void dispose() {
    c.disposed = true;
    super.dispose();
    Get.delete<ArticleListItemWidgetController>(tag: getxId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initProvider.call();
  }

  bool firstChecked = false;

  BodyWidget? _body;
  bool _shouldReload = false;

  Widget? _cachedBuildWidget;
  bool _shouldReloadCachedBuildWidget = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (c.disposed) return Container();

    _doBookmarkScaling();

    if (_cachedBuildWidget == null ||
        _shouldReloadCachedBuildWidget ||
        _shouldReload) {
      if (_body == null || _shouldReload) {
        _shouldReload = false;

        // https://stackoverflow.com/a/52249579
        final body = BodyWidget(key: c.bodyKey, getxId: getxId);

        _body = body;
      }

      _cachedBuildWidget = Obx(
        () => Container(
          color: isChecked.value ? Colors.amber : Colors.transparent,
          child: PimpedButton(
            particle: Rectangle2DemoParticle(),
            pimpedWidgetBuilder: (context, controller) {
              return GestureDetector(
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onLongPress: () async {
                  await _onLongPress(controller);
                },
                onLongPressEnd: _onPressEnd,
                onTapCancel: _onTapCancle,
                onDoubleTap: _onDoubleTap,
                child: Obx(
                  () => SizedBox(
                    width: c.thisWidth,
                    height: c.thisHeight.isNaN ? null : c.thisHeight.value,
                    child: AnimatedContainer(
                      curve: Curves.easeInOut,
                      duration: const Duration(milliseconds: 300),
                      transform: c.thisHeight.value.isNaN
                          ? null
                          : (Matrix4.identity()
                              ..translate(c.thisWidth / 2, c.thisHeight / 2)
                              ..scale(c.scale.value)
                              ..translate(-c.thisWidth / 2, -c.thisHeight / 2)),
                      child: _body!,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return _cachedBuildWidget!;
  }

  _doBookmarkScaling() {
    if (data.bookmarkMode) {
      if (!widget.isCheckMode && !c.onScaling && c.scale.value != 1.0) {
        _animateScale(1.0);
      } else if (widget.isCheckMode &&
          isChecked.value &&
          c.scale.value != 0.95) {
        _animateScale(0.95);
      }
    }
  }

  _animateScale(double scale) {
    c.scale.value = scale;
  }

  _onTapDown(detail) {
    if (c.onScaling) return;
    c.onScaling = true;
    _animateScale(0.95);
  }

  _onTapUp(detail) async {
    if (data.selectMode) {
      data.selectCallback!();
      return;
    }

    c.onScaling = false;

    if (widget.isCheckMode) {
      isChecked.value = !isChecked.value;
      data.bookmarkCheckCallback!(data.queryResult.id(), isChecked.value);
      _animateScale(isChecked.value ? 0.95 : 1.0);
      return;
    }

    if (firstChecked) return;

    _animateScale(1.0);

    showArticleInfoRaw(
      context: context,
      queryResult: data.queryResult,
      usableTabList: data.usableTabList,
    );
  }

  // ignore: unused_element
  _viewArticle() async {
    if (Settings.useVioletServer.value) {
      Future.delayed(const Duration(milliseconds: 100)).then((value) async {
        await VioletServerV2.view(data.queryResult.id());
      });
    }
    await (await User.getInstance()).insertUserLog(data.queryResult.id(), 0);

    if (!ProviderManager.isExists(data.queryResult.id())) {
      return;
    }

    var prov = await ProviderManager.get(data.queryResult.id());

    await prov.init();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return Provider<ViewerPageProvider>.value(
            value: ViewerPageProvider(
              // useWeb: true,
              uris: List<String>.filled(prov.length(), ''),
              useProvider: true,
              provider: prov,
              headers: c.headers,
              id: data.queryResult.id(),
              title: data.queryResult.title(),
              usableTabList: data.usableTabList,
            ),
            child: const ViewerPage(),
          );
        },
      ),
    ).then((value) async {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    });
  }

  Future<void> _onLongPress(controller) async {
    c.onScaling = false;

    if (data.bookmarkMode) {
      if (widget.isCheckMode) {
        isChecked.value = !isChecked.value;
        _animateScale(1.0);
        return;
      }
      isChecked.value = true;
      firstChecked = true;
      _animateScale(0.95);
      data.bookmarkCallback!(data.queryResult.id());
      return;
    }

    if (c.isBookmarked.value) {
      if (!await showYesNoDialog(context, '북마크를 삭제할까요?', '북마크')) return;
    }

    if (!c.disposed) {
      FToast().showToast(
        child: ToastWrapper(
          icon: c.isBookmarked.value ? Icons.delete_forever : Icons.check,
          color: c.isBookmarked.value
              ? Colors.redAccent.withOpacity(0.8)
              : Colors.greenAccent.withOpacity(0.8),
          msg:
              '${data.queryResult.id()}${locale.Translations.instance!.trans(c.isBookmarked.value ? 'removetobookmark' : 'addtobookmark')}',
        ),
        ignorePointer: true,
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 4),
      );
    }

    if (!c.isBookmarked.value) {
      await (await Bookmark.getInstance()).bookmark(data.queryResult.id());
    } else {
      await (await Bookmark.getInstance()).unbookmark(data.queryResult.id());
    }

    c.isBookmarked.value = !c.isBookmarked.value;

    if (!c.isBookmarked.value) {
      if (!Settings.simpleItemWidgetLoadingIcon.value) {
        c.flareController!.play('Unlike');
      }
    } else {
      controller.forward(from: 0.0);
      if (!Settings.simpleItemWidgetLoadingIcon.value) {
        c.flareController!.play('Like');
      }
    }

    await HapticFeedback.lightImpact();

    c.pad.value = 0;
    _animateScale(1.0);
  }

  _onPressEnd(detail) {
    c.onScaling = false;
    if (firstChecked) {
      firstChecked = false;
      return;
    }

    c.pad.value = 0;
    _animateScale(1.0);
  }

  _onTapCancle() {
    c.onScaling = false;

    c.pad.value = 0;
    _animateScale(1.0);
  }

  Future<void> _onDoubleTap() async {
    _showThumbnailView();
  }

  _showThumbnailView() async {
    c.onScaling = false;

    if (data.doubleTapCallback == null) {
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder:
              (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
                Widget wi,
              ) {
                return FadeTransition(opacity: animation, child: wi);
              },
          pageBuilder: (_, __, ___) => ThumbnailViewPage(
            thumbnail: c.thumbnail.value,
            headers: c.headers,
            heroKey: data.thumbnailTag,
            showUltra: data.showUltra,
          ),
        ),
      );
    } else {
      data.doubleTapCallback!();
    }

    _shouldReloadCachedBuildWidget = true;
    Future.delayed(
      const Duration(milliseconds: 500),
    ).then((value) => _shouldReloadCachedBuildWidget = false);
    setState(() {
      c.pad.value = 0;
    });
  }
}

class BodyWidget extends StatelessWidget {
  late final ArticleListItemWidgetController c;

  final String getxId;

  BodyWidget({super.key, required this.getxId}) {
    c = Get.find(tag: getxId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: c.articleListItem.addBottomPadding
          ? c.articleListItem.showDetail
                ? const EdgeInsets.only(bottom: 6)
                : const EdgeInsets.only(bottom: 50)
          : EdgeInsets.zero,
      decoration: !Settings.themeFlat.value
          ? BoxDecoration(
              color: c.articleListItem.showDetail
                  ? Settings.themeWhat.value
                        ? Settings.themeBlack.value
                              ? Palette.blackThemeBackground
                              : Colors.grey.shade800
                        : Colors.white70
                  : Colors.grey.withOpacity(0.3),
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              boxShadow: [
                BoxShadow(
                  color: Settings.themeWhat.value
                      ? Colors.grey.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.4),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3), // changes position of shadow
                ),
              ],
            )
          : null,
      color: !Settings.themeFlat.value || !c.articleListItem.showDetail
          ? null
          : Settings.themeWhat.value
          ? Colors.black26
          : Colors.white,
      child: c.articleListItem.showDetail
          ? IntrinsicHeight(
              child: Row(
                children: <Widget>[
                  ThumbnailWidget(getxId: getxId),
                  Expanded(child: _DetailWidget(getxId: getxId)),
                ],
              ),
            )
          : ThumbnailWidget(getxId: getxId),
    );
  }
}

// Artist List Item Details
class _DetailWidget extends StatelessWidget {
  late final ArticleListItemWidgetController c;

  _DetailWidget({required String getxId}) {
    c = Get.find(tag: getxId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Theme(
        data: ThemeData(
          useMaterial3: false,
          iconTheme: IconThemeData(
            color: !Settings.themeWhat.value ? Colors.black : Colors.white,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              c.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(c.artist, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (c.articleListItem.showUltra) tagArea(),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.date_range, size: 18),
                Text(
                  ' ${c.dateTime}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2.0),
            Row(
              children: [
                const Icon(Icons.photo, size: 18),
                Obx(
                  () => Text(
                    ' ${c.imageCount.value} Page',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4.0),
                if (c.articleListItem.viewed != null)
                  const Icon(MdiIcons.eyeOutline, size: 18),
                if (c.articleListItem.viewed != null)
                  Text(
                    ' ${c.articleListItem.viewed} Viewed',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (c.articleListItem.seconds != null)
                  const Icon(MdiIcons.clockOutline, size: 18),
                if (c.articleListItem.seconds != null)
                  Text(
                    ' ${c.articleListItem.seconds} Seconds',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget tagArea() {
    if (c.articleListItem.queryResult.tags() == null) {
      return Container(height: 30);
    }

    final tags = c.articleListItem.queryResult.tagList();
    if (Settings.useTabletMode.value) {
      return ExtendedWrap(
        spacing: 3.0,
        maxLines: 3,
        runSpacing: -10.0,
        children: tags.map((x) => TagChip(group: x.$1, name: x.$2)).toList(),
      );
    } else {
      return Wrap(
        spacing: 3.0,
        runSpacing: -10.0,
        children: tags.map((x) => TagChip(group: x.$1, name: x.$2)).toList(),
      );
    }
  }
}

class ModalInsideModal extends StatelessWidget {
  final bool reverse;

  const ModalInsideModal({super.key, this.reverse = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Material(
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              reverse: reverse,
              shrinkWrap: true,
              controller: ModalScrollController.of(context),
              physics: const ClampingScrollPhysics(),
              children: ListTile.divideTiles(
                context: context,
                tiles: List.generate(
                  100,
                  (index) => ListTile(
                    title: Text('Item $index'),
                    onTap: () => showCupertinoModalBottomSheet(
                      expand: true,
                      isDismissible: false,
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ModalInsideModal(reverse: reverse),
                    ),
                  ),
                ),
              ).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
