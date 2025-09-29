// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:flare_flutter/provider/asset_flare.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:get/get.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/firebase_options.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/after_loading/afterloading_page.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/pages/lock/lock_screen.dart';
import 'package:violet/pages/splash/splash_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/src/rust/frb_generated.dart';
import 'package:violet/style/palette.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    await RustLib.init();
    WidgetsFlutterBinding.ensureInitialized();
    await Logger.init();

    if (Platform.isAndroid || Platform.isIOS) {
      await FlutterDownloader.initialize();
    }
    FlareCache.doesPrune = false;
    FlutterError.onError = recordFlutterError;

    await initUserId();
    if (Platform.isAndroid || Platform.isIOS) {
      await initFirebase();
    }
    await Settings.initFirst();
    await warmupFlare();

    runApp(const MyApp());
  }, (exception, stack) async {
    Logger.error('[async-error] E: $exception\n$stack');

    if (Platform.isAndroid || Platform.isIOS) {
      await FirebaseCrashlytics.instance.recordError(exception, stack);
    }
  });
}

const _filesToWarmup = [
  'assets/flare/Loading2.flr',
  'assets/flare/likeUtsua.flr'
];

Future<void> warmupFlare() async {
  for (final filename in _filesToWarmup) {
    await cachedActor(
      AssetFlare(bundle: rootBundle, name: filename),
    );
  }
}

Future<void> recordFlutterError(FlutterErrorDetails flutterErrorDetails) async {
  Logger.error(
      '[unhandled-error] E: ${flutterErrorDetails.exceptionAsString()}\n'
      '${flutterErrorDetails.stack}');

  if (Platform.isAndroid || Platform.isIOS) {
    await FirebaseCrashlytics.instance.recordFlutterError(flutterErrorDetails);
  }
}

Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  var analytics = FirebaseAnalytics.instance;
  await analytics.setUserId(id: await initUserId());
}

Future<String> initUserId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('fa_userid');

  // check user-id is set
  if (id == null) {
    id = sha1.convert(utf8.encode(DateTime.now().toString())).toString();
    prefs.setString('fa_userid', id);
  }

  return id;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicTheme(
      defaultBrightness: Brightness.light,
      data: (brightness) => ThemeData(
        appBarTheme: AppBarTheme(
            systemOverlayStyle: !Settings.themeWhat.value
                ? SystemUiOverlayStyle.dark
                : SystemUiOverlayStyle.light),
        useMaterial3: false,
        brightness: brightness,
        bottomSheetTheme:
            BottomSheetThemeData(backgroundColor: Colors.black.withOpacity(0)),
        scaffoldBackgroundColor:
            Settings.themeBlack.value && Settings.themeWhat.value
                ? Colors.black
                : null,
        dialogBackgroundColor:
            Settings.themeBlack.value && Settings.themeWhat.value
                ? Palette.blackThemeBackground
                : null,
        cardColor: Settings.themeBlack.value && Settings.themeWhat.value
            ? Palette.blackThemeBackground
            : null,
        colorScheme: ColorScheme.fromSwatch().copyWith(
            secondary: Settings.majorColor.value, brightness: brightness),
        cupertinoOverrideTheme: CupertinoThemeData(
          brightness: brightness,
          primaryColor: Settings.majorColor.value,
          textTheme: const CupertinoTextThemeData(),
          barBackgroundColor: Settings.themeWhat.value
              ? Settings.themeBlack.value
                  ? const Color(0xFF181818)
                  : Colors.grey.shade800
              : null,
        ),
      ),
      themedWidgetBuilder: (context, theme) {
        return myApp(theme);
      },
    );
  }

  Widget myApp(ThemeData theme) {
    const supportedLocales = <Locale>[
      Locale('en', 'US'),
      Locale('ko', 'KR'),
      Locale('ja', 'JP'),
      Locale('zh', 'CH'),
      Locale('it', 'IT'),
      Locale('eo', 'ES'),
      Locale('pt', 'BR'),
    ];

    const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
      TranslationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ];

    final routes = <String, WidgetBuilder>{
      '/AfterLoading': (context) =>
          const CupertinoScaffold(body: AfterLoadingPage()),
      '/DatabaseDownload': (context) => const DataBaseDownloadPage(),
      '/SplashPage': (context) => const SplashPage(),
    };

    final home =
        Settings.useLockScreen.value ? const LockScreen() : const SplashPage();

    final navigatorObservers = Platform.isAndroid || Platform.isIOS
        ? [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ]
        : <NavigatorObserver>[];

    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    return GetMaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: navigatorObservers,
      theme: theme,
      home: home,
      supportedLocales: supportedLocales,
      routes: routes,
      localizationsDelegates: localizationsDelegates,
      localeResolutionCallback: localeResolution,
      scrollBehavior: CustomScrollBehavior(),
      builder: (context, child) {
        return EscapeKeyListener(
          navigatorKey: navigatorKey,
          child: child ?? Container(),
        );
      },
    );
  }

  Locale localeResolution(Locale? locale, Iterable<Locale> supportedLocales) {
    if (Settings.language.value.isNotEmpty) {
      if (Settings.language.value.contains('_')) {
        final ss = Settings.language.value.split('_');
        if (ss.length == 2) {
          return Locale.fromSubtags(languageCode: ss[0], scriptCode: ss[1]);
        } else {
          return Locale.fromSubtags(
              languageCode: ss[0], scriptCode: ss[1], countryCode: ss[2]);
        }
      } else {
        return Locale(Settings.language.value);
      }
    }

    if (locale == null) {
      if (Settings.language.value.isEmpty) {
        Settings.language.setValue(supportedLocales.first.languageCode);
      }
      return supportedLocales.first;
    }

    for (Locale supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode ||
          supportedLocale.countryCode == locale.countryCode) {
        if (Settings.language.value.isEmpty) {
          Settings.language.setValue(supportedLocale.languageCode);
        }
        return supportedLocale;
      }
    }

    if (Settings.language.value.isEmpty) {
      Settings.language.setValue(supportedLocales.first.languageCode);
    }

    return supportedLocales.first;
  }
}

// https://docs.flutter.dev/release/breaking-changes/default-scroll-behavior-drag
// for enable drag scrolling on desktop
class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

// A widget to listen for the Escape key, XButton1 and raise the WillPopScope event
// ignore: must_be_immutable
class EscapeKeyListener extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  bool toggleFullScreen = false;

  EscapeKeyListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      autofocus: true,
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          switch (event.logicalKey) {
            case LogicalKeyboardKey.escape:
              navigatorPop();
              break;
            case LogicalKeyboardKey.f11:
              toggleFullScreen = !toggleFullScreen;
              FullScreenWindow.setFullScreen(toggleFullScreen);
              break;
          }
        }
      },
      // https://github.com/flutter/flutter/issues/115641#issuecomment-2267579790
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          MouseBackRecognizer:
              GestureRecognizerFactoryWithHandlers<MouseBackRecognizer>(
            () => MouseBackRecognizer(),
            (instance) => instance.onTapDown = (details) => navigatorPop(),
          ),
        },
        child: child,
      ),
    );
  }

  void navigatorPop() {
    // Raise the WillPopScope event when Escape key is pressed
    if (Navigator.of(navigatorKey.currentContext!).canPop()) {
      Navigator.of(navigatorKey.currentContext!).maybePop();
    }
  }
}

class MouseBackRecognizer extends BaseTapGestureRecognizer {
  GestureTapDownCallback? onTapDown;

  MouseBackRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  @override
  void handleTapCancel({
    required PointerDownEvent down,
    PointerCancelEvent? cancel,
    required String reason,
  }) {}

  @override
  void handleTapDown({required PointerDownEvent down}) {
    final TapDownDetails details = TapDownDetails(
      globalPosition: down.position,
      localPosition: down.localPosition,
      kind: getKindForPointer(down.pointer),
    );

    if (down.buttons == kBackMouseButton && onTapDown != null) {
      invokeCallback<void>('onTapDown', () => onTapDown!(details));
    }
  }

  @override
  void handleTapUp({
    required PointerDownEvent down,
    required PointerUpEvent up,
  }) {}
}
