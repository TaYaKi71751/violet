// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';

import 'package:apple_pencil_double_tap/apple_pencil_double_tap.dart';
import 'package:apple_pencil_double_tap/entities/preferred_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/context/viewer_context.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart' as locale;
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/viewer/horizontal_viewer_page.dart';
import 'package:violet/pages/viewer/others/lifecycle_event_handler.dart';
import 'package:violet/pages/viewer/overlay/viewer_overlay.dart';
import 'package:violet/pages/viewer/vertical_viewer_page.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/util/call_once.dart';
import 'package:violet/util/evict_image_urls.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late CallOnce _initProvider;
  late ViewerPageProvider _pageInfo;
  late ViewerController c;
  late String getxId;
  late DateTime _startsTime, _inactivateTime;
  late LifecycleEventHandler _lifecycleEventHandler;
  Timer? _nextPageTimer;
  int _inactivateSeconds = 0;

  @override
  Widget build(BuildContext context) {
    _tidyImageCache();

    final mediaQuery = MediaQuery.of(context);

    final view = Obx(
      () => Stack(
        children: [
          if (c.viewType.value == ViewType.horizontal)
            HorizontalViewerPage(getxId: getxId)
          else
            VerticalViewerPage(getxId: getxId),
          ViewerOverlay(getxId: getxId),
        ],
      ),
    );

    late Widget body;

    if (c.fullscreen.value) {
      body = AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
        sized: false,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: view,
        ),
      );
    } else {
      body = Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Padding(
          padding: mediaQuery.padding + mediaQuery.viewInsets,
          child: view,
        ),
      );
    }

    final pageKeyListener = KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          switch (event.logicalKey) {
            case LogicalKeyboardKey.keyW:
            case LogicalKeyboardKey.arrowUp:
              c.prev();
              break;
            case LogicalKeyboardKey.keyS:
            case LogicalKeyboardKey.arrowDown:
              c.next();
              break;

            case LogicalKeyboardKey.keyA:
            case LogicalKeyboardKey.arrowLeft:
              c.rightButton();
              break;
            case LogicalKeyboardKey.keyD:
            case LogicalKeyboardKey.arrowRight:
              c.leftButton();
              break;
          }
        }
      },
      child: body,
    );

    return PopScope(
      canPop: true,
      onPopInvoked: _handlePopInvoked,
      child: pageKeyListener,
    );
  }

  @override
  void initState() {
    super.initState();

    _initProvider = CallOnce(_initAfterProvider);
    _startsTime = DateTime.now();

    _enterFullScreen();

    _jumpPage();

    _allocDeviceEventHandler();
    _allocLifetimeEventHandler();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initProvider.call();
  }

  @override
  void dispose() {
    _clearImageCache();
    WidgetsBinding.instance.removeObserver(_lifecycleEventHandler);
    _exitFullScreen();

    ViewerContext.pop();
    Get.delete<ViewerController>(tag: getxId);

    if (_nextPageTimer != null) _nextPageTimer!.cancel();
    super.dispose();
  }

  _enterFullScreen() {
    if (!Settings.disableFullScreen.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    }
  }

  _exitFullScreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }

  _jumpPage() {
    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      if (_pageInfo.jumpPage != null) {
        c.jump(_pageInfo.jumpPage!);
      } else {
        c.bookmark.value = await (await Bookmark.getInstance()).isBookmark(
          _pageInfo.id,
        );

        if (Settings.showRecordJumpMessage.value) {
          await Future.delayed(
            const Duration(milliseconds: 100),
          ).then((value) => _checkLatestRead());
        }
      }

      c.startTimer();
    });
  }

  _allocDeviceEventHandler() {
    ApplePencilDoubleTap().listen(
      v1Callback: (PreferredAction preferedAction) {
        if (ModalRoute.of(context)!.isCurrent) {
          c.next();
        }
      },
    );

    if (Platform.isAndroid) {
      const EventChannel(
        'xyz.project.violet/volume',
      ).receiveBroadcastStream().listen((event) {
        if (event is String) {
          if (event == 'up') {
            c.prev();
          } else if (event == 'down') {
            c.next();
          }
        }
      });
    }
  }

  _allocLifetimeEventHandler() {
    _lifecycleEventHandler = LifecycleEventHandler(
      inactiveCallBack: () async {
        _inactivateTime = DateTime.now();
        await (await User.getInstance()).updateUserLog(
          _pageInfo.id,
          c.page.value,
        );
      },
      resumeCallBack: () async {
        _inactivateSeconds += DateTime.now()
            .difference(_inactivateTime)
            .inSeconds;
        await ScriptManager.refresh();
      },
    );

    WidgetsBinding.instance.addObserver(_lifecycleEventHandler);
  }

  _tidyImageCache() {
    ImageCache imageCache = PaintingBinding.instance.imageCache;
    if (imageCache.currentSizeBytes >= (1024 + 256) << 20) {
      imageCache.clear();
      imageCache.clearLiveImages();
    }
  }

  void _clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    if (_pageInfo.useWeb) {
      evictImageUrls(_pageInfo.uris);
    }
    imageCache.clear();
    imageCache.clearLiveImages();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  void startTimer() {
    if (_nextPageTimer != null) {
      _nextPageTimer!.cancel();
      _nextPageTimer = null;
    }
    if (Settings.enableTimer.value) {
      _nextPageTimer = Timer.periodic(
        Duration(milliseconds: (Settings.timerTick.value * 1000).toInt()),
        nextPageTimerCallback,
      );
    }
  }

  void stopTimer() {
    if (_nextPageTimer != null) {
      _nextPageTimer!.cancel();
      _nextPageTimer = null;
    }
  }

  Future<void> nextPageTimerCallback(timer) async {
    c.next();
  }

  _initAfterProvider() {
    _pageInfo = Provider.of<ViewerPageProvider>(context);
    getxId = const Uuid().v4();
    c = Get.put(
      ViewerController(
        context,
        _pageInfo,
        close: _close,
        replace: _replace,
        startTimer: startTimer,
        stopTimer: stopTimer,
      ),
      tag: getxId,
    );
    ViewerContext.push(c);
  }

  Future<void> _close() async {
    c.onSession.value = false;
    await _savePageRead();
  }

  Future<void> _handlePopInvoked(bool didPop) async {
    await _close();
  }

  _checkLatestRead() async {
    final user = await User.getInstance();
    final log = await user.getUserLog();

    final x = log.where((e) => e.articleId() == _pageInfo.id.toString());
    if (x.length < 2) return;

    // 최근 읽은 기록 조회
    final e = x.elementAt(1);
    if (e.lastPage() == null) return;
    if (e.lastPage()! <= 1 ||
        DateTime.now().difference(DateTime.parse(e.datetimeStart())).inDays >
            7) {
      return;
    }

    // Jump 실행
    if (!mounted) return;
    final doJump = await showYesNoDialog(
      context,
      locale.Translations.instance!
          .trans('recordmessage')
          .replaceAll('%s', e.lastPage().toString()),
      locale.Translations.instance!.trans('record'),
    );
    if (!doJump) return;

    c.jump(e.lastPage()! - 1);
  }

  _savePageRead() async {
    await (await User.getInstance()).updateUserLog(
      _pageInfo.id,
      c.page.value + 1,
    );
    if (!_pageInfo.useFileSystem && Settings.useVioletServer.value) {
      VioletServer.viewClose(
        _pageInfo.id,
        DateTime.now().difference(_startsTime).inSeconds - _inactivateSeconds,
      );
    }
  }

  _replace(QueryResult article) async {
    await _savePageRead();

    await (await User.getInstance()).insertUserLog(article.id(), 0);

    var prov = await ProviderManager.get(article.id());
    var headers = await prov.getHeader(0);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation1, animation2) =>
            Provider<ViewerPageProvider>.value(
              value: ViewerPageProvider(
                uris: List<String>.filled(prov.length(), ''),
                useProvider: true,
                provider: prov,
                headers: headers,
                id: article.id(),
                title: article.title(),
                usableTabList: _pageInfo.usableTabList,
              ),
              child: const ViewerPage(),
            ),
      ),
    );
  }
}
