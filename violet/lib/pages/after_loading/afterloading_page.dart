// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/act_log.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/other/named_color.dart';
import 'package:violet/pages/bookmark/bookmark_page.dart';
import 'package:violet/pages/common/toast.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/download/download_page.dart';
import 'package:violet/pages/hot/hot_page.dart';
import 'package:violet/pages/lock/lock_screen.dart';
import 'package:violet/pages/search/search_page.dart';
import 'package:violet/pages/segment/double_tap_to_top.dart';
import 'package:violet/pages/settings/settings_page.dart';
import 'package:violet/platform/misc.dart';
import 'package:violet/script/script_webview.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/update/update_manager.dart';
import 'package:violet/variables.dart';
import 'package:violet/version/update_sync.dart';
import 'package:violet/widgets/patch_note_prompt.dart';

class AfterLoadingPage extends StatefulWidget {
  const AfterLoadingPage({super.key});

  @override
  State<AfterLoadingPage> createState() => AfterLoadingPageState();
}

class AfterLoadingPageState extends State<AfterLoadingPage>
    with WidgetsBindingObserver {
  static int defaultInitialPage = 0;
  static const _shareMethodChannel = MethodChannel('xyz.project.violet/share');
  static const _shareEventChannel = EventChannel(
    'xyz.project.violet/shareEvent',
  );

  StreamSubscription? _deeplinkSubscription;
  StreamSubscription? _shareSubscription;
  String? _lastHandledArticleKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FToast().init(context);

    if (Platform.isAndroid || Platform.isIOS) {
      _listenDeeplink();
      _listenSharedText();
    }

    Future.delayed(const Duration(milliseconds: 200)).then((value) async {
      await UpdateManager.updateCheck(context);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showPatchNotePromptIfNeeded(context);
      });
    });
  }

  bool _alreadyLocked = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deeplinkSubscription?.cancel();
    _shareSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (Settings.useLockScreen.value &&
            Settings.useSecureMode.value &&
            !_alreadyLocked) {
          _alreadyLocked = true;
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => const LockScreen(isSecureMode: true),
                ),
              )
              .then((value) => _alreadyLocked = false);
        }
        ActLogger.log(ActLogEvent(type: ActLogType.appResume));
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        ActLogger.log(ActLogEvent(type: ActLogType.appSuspense));
        break;
      case AppLifecycleState.detached:
        ActLogger.log(ActLogEvent(type: ActLogType.appStop));
        break;
      default:
        // TODO: Implement properly
        break;
    }
  }

  void handleDeeplink(Uri? uri) {
    if (uri == null) {
      return;
    }

    unawaited(_handleArticleUri(uri));
  }

  Future<void> _listenDeeplink() async {
    final appLinks = AppLinks();
    _deeplinkSubscription = appLinks.uriLinkStream.listen(handleDeeplink);
    handleDeeplink(await appLinks.getInitialLink());
  }

  Future<void> _listenSharedText() async {
    if (!Platform.isAndroid) {
      return;
    }

    _shareSubscription = _shareEventChannel.receiveBroadcastStream().listen((
      event,
    ) {
      if (event is String) {
        _handleSharedText(event);
      }
    });

    final initialSharedText = await _shareMethodChannel.invokeMethod<String>(
      'getInitialSharedText',
    );
    if (initialSharedText != null) {
      _handleSharedText(initialSharedText);
    }
  }

  void _handleSharedText(String text) {
    final uri = _extractUri(text);
    if (uri == null) {
      return;
    }

    unawaited(_handleArticleUri(uri));
  }

  Uri? _extractUri(String text) {
    final match = RegExp(r'https?://[^\s]+').firstMatch(text.trim());
    final rawUrl = match?.group(0) ?? text.trim();
    return Uri.tryParse(rawUrl);
  }

  Future<void> _handleArticleUri(Uri uri) async {
    final articleId = await _articleIdFromUri(_unwrapSharedUri(uri));
    if (articleId == null) {
      return;
    }

    final articleKey = articleId.toString();
    if (_lastHandledArticleKey == articleKey) {
      return;
    }
    _lastHandledArticleKey = articleKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      showArticleInfoById(context, articleId);
    });
  }

  Uri _unwrapSharedUri(Uri uri) {
    final isVioletScheme =
        uri.scheme == 'violet' || uri.scheme == 'xyz.project.violet';
    if (!isVioletScheme || uri.host != 'share') {
      return uri;
    }

    final sharedUrl = uri.queryParameters['url'];
    if (sharedUrl == null) {
      return uri;
    }

    return _extractUri(sharedUrl) ?? uri;
  }

  Future<int?> _articleIdFromUri(Uri uri) async {
    final deeplinkId = int.tryParse(uri.host);
    if (deeplinkId != null) {
      return deeplinkId;
    }

    final host = uri.host.toLowerCase();

    if (host == 'hitomi.la') {
      final readerMatch = RegExp(r'^/reader/(\d+)\.html$').firstMatch(uri.path);
      if (readerMatch != null) {
        return int.tryParse(readerMatch.group(1)!);
      }

      final galleryMatch = RegExp(
        r'^/(?:cg|doujinshi|manga|imageset)/.+-(\d+)\.html$',
      ).firstMatch(uri.path);
      return galleryMatch == null ? null : int.tryParse(galleryMatch.group(1)!);
    }

    if (host == 'litomi.in') {
      final mangaMatch = RegExp(r'^/manga/(\d+)/?$').firstMatch(uri.path);
      return mangaMatch == null ? null : int.tryParse(mangaMatch.group(1)!);
    }

    if (host == 'e-hentai.org' || host == 'exhentai.org') {
      final galleryMatch = RegExp(r'^/g/(\d+)/[^/]+/?$').firstMatch(uri.path);
      if (galleryMatch != null) {
        return int.tryParse(galleryMatch.group(1)!);
      }

      final imageMatch = RegExp(r'^/s/[^/]+/(\d+)-\d+$').firstMatch(uri.path);
      return imageMatch == null ? null : int.tryParse(imageMatch.group(1)!);
    }

    if (host == 'nhentai.net' || host == 'nhentai.to') {
      final nHentaiId = uri.path.split('/')[2];
      final response = await http.get(
        'https://nhentai-media-id.vercel.app/api/media-id?id=$nHentaiId',
      );
      final mediaId = jsonDecode(response.body)['mediaId'];

      return int.tryParse(mediaId);
    }

    return null;
  }

  final PageController _pageController = PageController(
    initialPage: defaultInitialPage,
  );
  final FocusNode _focusNode = FocusNode();
  final FocusNode nestedFocusNode = FocusNode();

  int get _currentPage => _pageController.hasClients
      ? _pageController.page!.round()
      : defaultInitialPage;

  bool get _usesDrawer => Settings.useDrawer.value;

  bool get _usesBottomNavigationBar => !Settings.useDrawer.value;

  DateTime? _lastPopAt;

  bool _isDoubleTap = false;

  late final List<GlobalKey<State>> _widgetKeys = List.generate(
    5,
    (index) => GlobalKey(),
  );

  Widget _buildBottomNavigationBar(BuildContext context) {
    final translations = Translations.instance!;

    BottomNavigationBarItem buildItem(IconData iconData, String key) {
      return BottomNavigationBarItem(
        backgroundColor: Settings.themeWhat.value
            ? Settings.themeBlack.value
                  ? const Color(0xFF060606)
                  : Colors.grey.shade900.withOpacity(0.90)
            : Colors.grey.shade50,
        icon: Icon(iconData),
        label: translations.trans(key),
      );
    }

    Widget result = Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Settings.themeWhat.value && Settings.themeBlack.value
            ? const Color(0xFF060606)
            : null,
      ),
      child: BottomNavigationBar(
        showUnselectedLabels: false,
        type: BottomNavigationBarType.shifting,
        fixedColor: Settings.majorColor.value,
        unselectedItemColor: Settings.themeWhat.value
            ? Colors.white
            : Colors.black,
        backgroundColor: Settings.themeWhat.value && Settings.themeBlack.value
            ? const Color(0xFF060606)
            : null,
        currentIndex: _currentPage,
        onTap: (index) {
          if (_pageController.page != index) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          } else {
            if (_isDoubleTap) {
              // something to do for double tap
              (_widgetKeys[index].currentState as DoubleTapToTopMixin)
                  .animateToTop();

              _isDoubleTap = false;
              return;
            }

            _isDoubleTap = true;
            Timer(
              const Duration(milliseconds: 200),
              () => _isDoubleTap = false,
            );
          }
        },
        items: <BottomNavigationBarItem>[
          buildItem(Icons.search, 'search'),
          buildItem(MdiIcons.fire, 'hot'),
          buildItem(Icons.bookmark, 'bookmark'),
          buildItem(Icons.file_download, 'download'),
          buildItem(Icons.settings, 'settings'),
        ],
      ),
    );

    if (Platform.isAndroid) {
      final mediaQuery = MediaQuery.of(context);
      result = MediaQuery(
        data: mediaQuery.copyWith(
          padding:
              mediaQuery.padding +
              mediaQuery.viewInsets +
              const EdgeInsets.only(bottom: 6),
        ),
        child: result,
      );
    }

    return result;
  }

  Widget _buildDrawer(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final translations = Translations.instance!;

    Widget buildButton(IconData iconData, int page, String key) {
      final color = Settings.majorColor.value;

      return Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        height: 54,
        child: Container(
          decoration: BoxDecoration(
            color: page == _currentPage ? color.withOpacity(0.4) : null,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: InkWell(
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            hoverColor: color,
            highlightColor: color.withOpacity(0.2),
            focusColor: color,
            splashColor: color.withOpacity(0.3),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(iconData),
                const SizedBox(width: 12),
                Text(
                  translations.trans(key),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _pageController.jumpToPage(page);
              });
              Navigator.pop(context);
            },
          ),
        ),
      );
    }

    return Container(
      width: 220,
      padding: mediaQuery.padding + mediaQuery.viewInsets,
      child: Drawer(
        child: Column(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.all(40),
              child: Column(
                children: <Widget>[
                  InkWell(
                    child: Image.asset(
                      'assets/images/logo-${Settings.majorColor.value.name}.png',
                      width: 100,
                      height: 100,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'Project Violet',
                    style: TextStyle(
                      color: Settings.themeWhat.value
                          ? Colors.white
                          : Colors.black87,
                      fontSize: 18.0,
                      fontFamily: 'Calibre-Semibold',
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    UpdateSyncManager.currentVersion,
                    style: const TextStyle(
                      fontFamily: 'Calibre-Semibold',
                      fontSize: 17.0,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            buildButton(Icons.search, 0, 'search'),
            buildButton(MdiIcons.fire, 1, 'hot'),
            buildButton(MdiIcons.bookmark, 2, 'bookmark'),
            buildButton(MdiIcons.download, 3, 'download'),
            buildButton(Icons.settings, 4, 'settings'),
            const Spacer(),
            Text(
              'Copyright (C) 2020-2024\nby project-violet',
              style: TextStyle(
                color: Settings.themeWhat.value ? Colors.white : Colors.black87,
                fontSize: 12.0,
                fontFamily: 'Calibre-Semibold',
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    Variables.updatePadding(
      (mediaQuery.padding + mediaQuery.viewInsets).top,
      (mediaQuery.padding + mediaQuery.viewInsets).bottom,
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }

        final now = DateTime.now();

        if (_lastPopAt != null &&
            now.difference(_lastPopAt!) <= const Duration(seconds: 2)) {
          if (Platform.isAndroid) {
            await PlatformMiscMethods.instance.finishMainActivity();
          }

          Navigator.of(context).pop();
        } else {
          _lastPopAt = now;

          showToast(
            icon: Icons.logout,
            level: ToastLevel.warning,
            message: Translations.instance!.trans('closedoubletap'),
          );
        }
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            switch (event.logicalKey) {
              case LogicalKeyboardKey.keyA:
                _pageController.animateToPage(
                  _currentPage - 1,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
                break;
              case LogicalKeyboardKey.keyD:
                _pageController.animateToPage(
                  _currentPage + 1,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
                break;
            }
          }
          nestedFocusNode.requestFocus();
        },
        child: Scaffold(
          bottomNavigationBar: _usesBottomNavigationBar
              ? _buildBottomNavigationBar(context)
              : null,
          drawer: _usesDrawer ? _buildDrawer(context) : null,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: !Settings.themeWhat.value
                ? SystemUiOverlayStyle.dark
                : SystemUiOverlayStyle.light,
            child: Stack(
              children: [
                if (kReleaseMode &&
                    !(Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS))
                  const ScriptWebView(),
                PageView(
                  controller: _pageController,
                  physics: _usesDrawer
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (newPage) {
                    setState(() {});
                  },
                  children: <Widget>[
                    SearchPage(key: _widgetKeys[0], focusNode: nestedFocusNode),
                    HotPage(key: _widgetKeys[1]),
                    BookmarkPage(key: _widgetKeys[2]),
                    DownloadPage(key: _widgetKeys[3]),
                    SettingsPage(key: _widgetKeys[4]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
