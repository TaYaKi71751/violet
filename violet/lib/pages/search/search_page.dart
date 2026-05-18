// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:math';

import 'package:auto_animated/auto_animated.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/population.dart';
import 'package:violet/context/modal_bottom_sheet_context.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/search.dart';
import 'package:violet/locale/locale.dart' as trans;
import 'package:violet/log/log.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/lab/lab/search_message.dart';
import 'package:violet/pages/search/search_bar_page.dart';
import 'package:violet/pages/search/search_page_controller.dart';
import 'package:violet/pages/search/search_page_modify.dart';
import 'package:violet/pages/search/search_type.dart';
import 'package:violet/pages/segment/double_tap_to_top.dart';
import 'package:violet/pages/segment/filter_page.dart';
import 'package:violet/pages/segment/filter_page_controller.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/debounce_widget.dart';
import 'package:violet/widgets/search_bar.dart';
import 'package:violet/widgets/theme_switchable_state.dart';

bool blurred = false;

class SearchPage extends StatefulWidget {
  final String? searchKeyWord;
  final FocusNode? focusNode;

  const SearchPage({super.key, this.searchKeyWord, this.focusNode});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ThemeSwitchableState<SearchPage>
    with AutomaticKeepAliveClientMixin<SearchPage>, DoubleTapToTopMixin {
  @override
  bool get wantKeepAlive => widget.searchKeyWord == null;

  @override
  VoidCallback? get shouldReloadCallback =>
      () => _shouldReload = true;

  late final String getxId;
  late final SearchPageController c;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();

    getxId = const Uuid().v4();
    c = Get.put(SearchPageController(reloadForce: reloadForce), tag: getxId);

    c.init(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doInitialSearch();
    });
  }

  doInitialSearch() async {
    final generation = _searchGeneration;

    try {
      final search = HentaiManager.search(widget.searchKeyWord ?? '');
      if (!Settings.ignoreTimeout.value) {
        search.timeout(const Duration(seconds: 5));
      }
      final result = await search;

      if (generation != _searchGeneration) {
        return;
      }

      c.latestQuery = (result, widget.searchKeyWord ?? '');
      c.queryResult = c.latestQuery!.$1!.results;
      if (c.filterController.isPopulationSort) {
        Population.sortByPopulation(c.queryResult);
      }
      reloadForce();

      if (c.searchTotalResultCount.value == 0) {
        Future.delayed(const Duration(milliseconds: 100)).then((value) async {
          if (generation != _searchGeneration) {
            return;
          }
          c.searchTotalResultCount.value = await HentaiManager.countSearch(
            widget.searchKeyWord ?? '',
          );
        });
      }
    } catch (e, st) {
      Logger.error(
        '[Initial-Search] E: $e\n'
        '$st',
      );
      c.showErrorToast('Failed to search all: $e');
    }
  }

  Future<void> searchFromDeeplink(String query) async {
    if (widget.searchKeyWord != null || query.trim().isEmpty) return;

    _searchGeneration++;

    try {
      final db = await SearchLogDatabase.getInstance();
      await db.insertSearchLog(query);
    } catch (e, st) {
      await Logger.error(
        '[searchFromDeeplink-log] E: ${e.toString()}\n${st.toString()}',
      );
    }

    c.latestQuery = (null, query);
    c.doSearch();
    if (c.scrollController?.hasClients ?? false) {
      c.scrollController?.jumpTo(0);
    }
    reloadForce();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    c.initScroll(context);
    doubleTapToTopScrollController = c.scrollController;
  }

  bool _shouldReload = false;
  ResultPanelWidget? _cachedPannel;
  ObjectKey sliverKey = ObjectKey(const Uuid().v4());
  Timer? _holdTimer;

  reloadForce() {
    setState(() {
      _cachedPannel = null;
      _shouldReload = true;
      sliverKey = ObjectKey(const Uuid().v4());
    });
  }

  // https://stackoverflow.com/questions/60643355/is-it-possible-to-have-both-expand-and-contract-effects-with-the-slivers-in
  @override
  Widget build(BuildContext context) {
    super.build(context);

    print('build!');

    if (_cachedPannel == null || _shouldReload) {
      _shouldReload = false;

      c.itemKeys.clear();

      print('searchResultType: ${Settings.searchResultType.value}');

      final panel = ResultPanelWidget(
        searchResultType: Settings.searchResultType.value,
        resultList: c.getSearchList(),
        itemKeys: c.itemKeys,
        sliverKey: sliverKey,
        keyPrefix: 'search',
      );

      _cachedPannel = panel;
    }

    final slivers = [
      if (widget.searchKeyWord == null)
        SliverPersistentHeader(
          floating: true,
          delegate: AnimatedOpacitySliver(
            searchBar: Stack(
              children: <Widget>[searchBar(), msgsearch(), align()],
            ),
          ),
        )
      else
        SliverToBoxAdapter(child: Container(height: 16)),
      _cachedPannel!,
    ];

    late Widget scrollView;

    if (widget.searchKeyWord == null) {
      scrollView = CustomScrollView(
        controller: c.scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: slivers,
      );
    } else {
      scrollView = CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          border: const Border(bottom: BorderSide(color: Colors.transparent)),
          leading: CupertinoButton(
            padding: const EdgeInsets.all(10),
            onPressed: alignOnTap,
            child: const Icon(
              MdiIcons.formatListText,
              size: 21.0,
              color: Colors.grey,
            ),
          ),
          middle: Text(widget.searchKeyWord!),
          trailing: CupertinoButton(
            padding: const EdgeInsets.all(10),
            onPressed: alignLongPress,
            child: const Icon(MdiIcons.filter, size: 21.0, color: Colors.grey),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: NestedScrollView(
            controller: c.scrollController,
            physics: const ScrollPhysics(parent: PageScrollPhysics()),
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
                  return [];
                },
            body: CustomScrollView(
              controller: ModalScrollController.of(context),
              physics: const BouncingScrollPhysics(),
              slivers: slivers,
            ),
          ),
        ),
      );
    }

    final pageKeyListener = KeyboardListener(
      focusNode: widget.focusNode ?? FocusNode(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          _holdTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
            switch (event.logicalKey) {
              case LogicalKeyboardKey.keyW:
                c.scrollController!.animateTo(
                  c.scrollController!.offset - 300,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
                break;
              case LogicalKeyboardKey.keyS:
                c.scrollController!.animateTo(
                  c.scrollController!.offset + 300,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
                break;
            }
          });
        } else if (event is KeyUpEvent) {
          _holdTimer?.cancel();
          _holdTimer = null;
        }
      },
      child: scrollView,
    );

    return Scaffold(
      body: SafeArea(bottom: false, child: pageKeyListener),
      floatingActionButton: _floatingActionButton(),
    );
  }

  Widget _floatingActionButton() {
    return FloatingActionButton.extended(
      backgroundColor: Settings.majorColor.value,
      label: Obx(
        () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.horizontal,
                  child: child,
                ),
              ),
          child: !c.isExtended.value
              ? const Icon(MdiIcons.bookOpenPageVariantOutline)
              : Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 4.0),
                      child: Icon(MdiIcons.bookOpenPageVariantOutline),
                    ),
                    Obx(
                      () => Text(
                        '${c.searchPageNum.value + c.baseCount}/${c.queryResult.length}/${c.searchTotalResultCount}',
                      ),
                    ),
                  ],
                ),
        ),
      ),
      onPressed: () async {
        var rr = await showDialog(
          context: context,
          builder: (BuildContext context) => SearchPageModifyPage(
            curPage: c.searchPageNum.value + c.baseCount,
            maxPage: c.searchTotalResultCount.value,
          ),
        );
        if (rr == null) return;

        if (rr[0] == 1) {
          final setPage = rr[1] as int;

          c.latestQuery = (
            SearchResult(results: [], offset: setPage),
            c.latestQuery!.$2,
          );

          c.doSearch(setPage);
        }
      },
    );
  }

  searchBar() {
    final searchHintText =
        c.latestQuery != null && c.latestQuery!.$2.trim() != ''
        ? c.latestQuery!.$2
        : widget.searchKeyWord ?? trans.Translations.instance!.trans('search');

    final textFormField = TextFormField(
      cursorColor: Colors.black,
      decoration: InputDecoration(
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.only(
          left: 15,
          bottom: 11,
          top: 11,
          right: 15,
        ),
        hintText: searchHintText,
      ),
    );

    final searchBar = Column(
      children: <Widget>[
        Material(
          color: Settings.themeWhat.value
              ? Settings.themeBlack.value
                    ? Palette.blackThemeBackground
                    : Colors.grey.shade900.withOpacity(0.4)
              : Colors.grey.shade200.withOpacity(0.4),
          child: ListTile(
            title: textFormField,
            leading: SizedBox(
              width: 25,
              height: 25,
              child: FlareActor.asset(c.asset, controller: c.heroFlareControls),
            ),
          ),
        ),
      ],
    );

    final searchBarOverlay = Positioned(
      left: 0.0,
      top: 0.0,
      bottom: 0.0,
      right: 0.0,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: showSearchBar,
          onDoubleTap: () async {
            if (widget.searchKeyWord != null) return;
            c.latestQuery = (null, 'random:${Random().nextDouble() + 1}');
            c.doSearch();
          },
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 72 * 2, 0),
      child: SizedBox(
        height: 64,
        child: Card(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4.0)),
          ),
          elevation: !Settings.themeFlat.value ? 100 : 0,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Stack(children: <Widget>[searchBar, searchBarOverlay]),
        ),
      ),
    );
  }

  showSearchBar() async {
    if (widget.searchKeyWord != null) return;

    await Future.delayed(const Duration(milliseconds: 200));

    c.heroFlareControls.play('search2close');

    if (!mounted) return;
    final query = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return SearchBarPage(
            assetProvider: c.asset,
            initText: c.latestQuery != null ? c.latestQuery!.$2 : '',
            heroController: c.heroFlareControls,
          );
        },
        fullscreenDialog: true,
      ),
    );

    try {
      final db = await SearchLogDatabase.getInstance();
      await db.insertSearchLog(query);
      setState(() {
        c.heroFlareControls.play('close2search');
      });
      if (query == null) return;

      c.latestQuery = (null, query);
      c.doSearch();
    } catch (e, st) {
      await Logger.error(
        '[showSearchBar] E: ${e.toString()}\n${st.toString()}',
      );
    }
  }

  msgsearch() {
    final width = MediaQuery.of(context).size.width;

    final msgsearchOverlay = InkWell(
      onTap: () {
        PlatformNavigator.navigateSlide(context, const LabSearchMessage());
      },
      child: const SizedBox(
        height: 64,
        width: 64,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[Icon(MdiIcons.commentSearch, color: Colors.grey)],
        ),
      ),
    );

    final msgsearchBody = Card(
      color: Palette.themeColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4.0)),
      ),
      elevation: !Settings.themeFlat.value ? 100 : 0,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: msgsearchOverlay,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(width - 8 - 64 - 8 - 64, 8, 8, 0),
      child: SizedBox(
        height: 64,
        child: Hero(
          tag: 'msgsearch${ModalBottomSheetContext.getCount()}',
          child: msgsearchBody,
        ),
      ),
    );
  }

  align() {
    final width = MediaQuery.of(context).size.width;

    final alignOverlay = InkWell(
      onTap: alignOnTap,
      onLongPress: alignLongPress,
      child: const SizedBox(
        height: 64,
        width: 64,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[Icon(MdiIcons.formatListText, color: Colors.grey)],
        ),
      ),
    );

    final alignBody = Card(
      color: Palette.themeColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4.0)),
      ),
      elevation: !Settings.themeFlat.value ? 100 : 0,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: alignOverlay,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(width - 8 - 64, 8, 8, 0),
      child: SizedBox(
        height: 64,
        child: Hero(
          tag: 'searchtype${ModalBottomSheetContext.getCount()}',
          child: alignBody,
        ),
      ),
    );
  }

  alignOnTap() async {
    final previousAlignType = Settings.searchResultType.value;
    final newAlignType = await Navigator.of(context).push(
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
        pageBuilder: (_, __, ___) => SearchType(
          heroTag: 'searchtype${ModalBottomSheetContext.getCount()}',
          previousType: previousAlignType,
        ),
        barrierColor: Colors.black12,
        barrierDismissible: true,
      ),
    );

    if (newAlignType == null || previousAlignType == newAlignType) return;

    await Settings.searchResultType.setValue(newAlignType);
    await Future.delayed(const Duration(milliseconds: 50), () {
      _shouldReload = true;
      c.resetItemHeight();
      setState(() {});
    });
  }

  alignLongPress() async {
    final navigator = widget.searchKeyWord == null
        ? PlatformNavigator.navigateFade
        : PlatformNavigator.navigateSlide;
    navigator(
      context,
      Provider<FilterController>.value(
        value: c.filterController,
        child: FilterPage(queryResult: c.queryResult),
      ),
    ).then((value) {
      c.applyFilter();
      _shouldReload = true;
      c.searchPageNum.value = 0;
      reloadForce();
    });
  }
}

class ResultPanelWidget extends StatelessWidget {
  final SearchResultType searchResultType;
  final List<QueryResult> resultList;
  final ObjectKey sliverKey;
  final Map<String, GlobalKey> itemKeys;
  final bool bookmarkMode;
  final String keyPrefix;
  final BookmarkCallback? bookmarkCallback;
  final BookmarkCheckCallback? bookmarkCheckCallback;
  final bool isCheckMode;
  final List<int>? checkedArticle;

  const ResultPanelWidget({
    super.key,
    required this.searchResultType,
    required this.resultList,
    required this.sliverKey,
    required this.itemKeys,
    required this.keyPrefix,
    this.bookmarkMode = false,
    this.bookmarkCallback,
    this.bookmarkCheckCallback,
    this.isCheckMode = false,
    this.checkedArticle,
  });

  @override
  Widget build(BuildContext context) {
    final windowWidth = MediaQuery.of(context).size.width;
    final padding = bookmarkMode
        ? const EdgeInsets.fromLTRB(12, 0, 12, 16)
        : const EdgeInsets.fromLTRB(8, 0, 8, 16);

    switch (searchResultType) {
      case SearchResultType.threeGrid:
      case SearchResultType.twoGrid:
        final columnCount = searchResultType == SearchResultType.threeGrid
            ? 3
            : 2;
        final simpleModeColumnCount = Settings.useTabletMode.value
            ? columnCount * 2
            : columnCount;
        return SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            key: sliverKey,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: simpleModeColumnCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              return articleItem(
                index,
                windowWidth,
                (windowWidth - 4.0) / simpleModeColumnCount,
                alignment: Alignment.bottomCenter,
                debouncing: bookmarkMode,
              );
            }, childCount: resultList.length),
          ),
        );

      case SearchResultType.bigLine:
      case SearchResultType.detail:
      case SearchResultType.ultra:
        if (Settings.useTabletMode.value ||
            MediaQuery.of(context).orientation == Orientation.landscape) {
          const kDetailModeColumnCount = 2;
          final aspectRatioHeight =
              Settings.useTabletMode.value && searchResultType.isUltra
              ? 220
              : 130;

          return SliverPadding(
            padding: padding,
            sliver: LiveSliverGrid(
              key: sliverKey,
              controller: ScrollController(),
              showItemInterval: const Duration(milliseconds: 50),
              showItemDuration: const Duration(milliseconds: 150),
              visibleFraction: 0.001,
              itemCount: resultList.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: kDetailModeColumnCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio:
                    (windowWidth / kDetailModeColumnCount) / aspectRatioHeight,
              ),
              itemBuilder: (context, index, animation) {
                return articleItem(
                  index,
                  windowWidth,
                  (windowWidth - 4.0) / kDetailModeColumnCount,
                  showDetail: searchResultType.isDetailLike,
                  showUltra: searchResultType.isUltra,
                  addBottomPadding: true,
                );
              },
            ),
          );
        } else {
          return SliverList(
            key: key,
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              return articleItem(
                index,
                windowWidth,
                windowWidth - 4.0,
                showDetail: searchResultType.isDetailLike,
                showUltra: searchResultType.isUltra,
                addBottomPadding: true,
              );
            }, childCount: resultList.length),
          );
        }
    }
  }

  articleItem(
    int index,
    double windowWidth,
    double width, {
    bool showDetail = false,
    bool showUltra = false,
    bool addBottomPadding = false,
    Alignment alignment = Alignment.center,
    bool debouncing = false,
  }) {
    final keyStr = '$keyPrefix/${resultList[index].id()}/$index';

    if (!itemKeys.containsKey(keyStr)) {
      itemKeys[keyStr] = GlobalKey();
    }

    final article = Provider<ArticleListItem>.value(
      value: ArticleListItem.fromArticleListItem(
        queryResult: resultList[index],
        showDetail: showDetail,
        showUltra: showUltra,
        addBottomPadding: addBottomPadding,
        width: width,
        thumbnailTag: const Uuid().v4(),
        bookmarkMode: bookmarkMode,
        bookmarkCallback: bookmarkCallback,
        bookmarkCheckCallback: bookmarkCheckCallback,
        usableTabList: resultList,
      ),
      child: !isCheckMode
          ? const ArticleListItemWidget()
          : ArticleListItemWidget(
              isCheckMode: true,
              isChecked: checkedArticle!.contains(resultList[index].id()),
            ),
    );

    final aligned = Padding(
      key: itemKeys[keyStr],
      padding: EdgeInsets.zero,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(child: article),
      ),
    );

    if (debouncing) {
      return DebounceWidget(child: aligned);
    } else {
      return aligned;
    }
  }
}
