import 'package:flutter/material.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/settings/login/ehentai_login.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ReaderScreen extends StatefulWidget {
  final String readerUrl;
  const ReaderScreen({required this.readerUrl, super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState(readerUrl);
}

class _ReaderScreenState extends State<ReaderScreen> {
  final String readerUrl;

  late WebViewController _controller;
  final WebViewCookieManager cookieManager = WebViewCookieManager();

  _ReaderScreenState(this.readerUrl);
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _controller = _controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) async {
            Logger.info('[Reader-WebView-onUrlChange] ${change.url!}');
            if (Uri.parse(change.url!).host != Uri.parse(readerUrl).host &&
                (await _controller.canGoBack())) {
              _controller.goBack();
            }
          },
          onPageFinished: (url) async {
            try {
              if (Uri.parse(url).host != Uri.parse(readerUrl).host &&
                  (await _controller.canGoBack())) {
              } else if (Uri.parse(url).host == 'hitomi.la' &&
                  Uri.parse(url).path == '/-1') {
                Navigator.pop(context);
              } else if (Uri.parse(url).host == 'hitomi.la' &&
                  Uri.parse(url).path.startsWith('/reader/')) {
                _controller.runJavaScript('''
                  document.body.setAttribute('style', 'margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #303030; background: #303030 !important;');
                  document.querySelectorAll('[class*="navbar"]').forEach(el => el.setAttribute(
                    'style', 'display: none !important;'
                  ));
                  document.querySelector('img.lillie').setAttribute('style', 'overflow: hidden; max-width: 100%; max-height: 100%; object-fit: contain;');
                  ''');
              } else if ((Uri.parse(url).host == 'exhentai.org' ||
                      Uri.parse(url).host == 'e-hentai.org') &&
                  Uri.parse(url).path.startsWith('/g/')) {
                String? firstPageUrl;
                try {
                  final result = await _controller.runJavaScriptReturningResult(
                    'document.querySelector("a[href\$=\\"-1\\"]")?.href || null',
                  );
                  if (result != 'null') {
                    firstPageUrl = result.toString().replaceAll('"', '');
                  }
                } catch (e) {
                  Logger.warning(
                    '[Reader-WebView-onPageFinished] Error getting firstPageUrl: $e',
                  );
                }
                if (firstPageUrl == null || !firstPageUrl.endsWith('-1')) {
                  _controller.reload();
                } else {
                  _controller.loadRequest(Uri.parse(firstPageUrl));
                }
              } else if ((Uri.parse(url).host == 'exhentai.org' ||
                      Uri.parse(url).host == 'e-hentai.org') &&
                  Uri.parse(url).path.startsWith('/s/')) {
                String? nextLink;
                String? prevLink;
                try {
                  final result = await _controller.runJavaScriptReturningResult(
                    'document.querySelector("a#next")?.href || null',
                  );
                  if (result != 'null') {
                    nextLink = result.toString().replaceAll('"', '');
                  }
                } catch (e) {
                  Logger.warning(
                    '[Reader-WebView-onPageFinished] Error getting nextLink: $e',
                  );
                }
                try {
                  final result = await _controller.runJavaScriptReturningResult(
                    'document.querySelector("a#prev")?.href || null',
                  );
                  if (result != 'null') {
                    prevLink = result.toString().replaceAll('"', '');
                  }
                } catch (e) {
                  Logger.warning(
                    '[Reader-WebView-onPageFinished] Error getting nextLink: $e',
                  );
                }
                if (nextLink != null &&
                    prevLink != null &&
                    nextLink.isNotEmpty &&
                    prevLink.isNotEmpty) {
                  await _controller.runJavaScript('''
                  document.body.outerHTML = `<body>\${document.querySelector('img#img').outerHTML}</body>`;
                  document.body.setAttribute('style', 'margin: 0; padding: 0; display: flex; flex-direction: column; justify-content: center; align-items: center; height: 100vh; background-color: #303030; background: #303030 !important;');
                    document.querySelector('img#img').setAttribute('onload', '');
                  document.querySelector('img#img').setAttribute('onerror', '');
                  document.querySelector('img#img').setAttribute('style', 'overflow: hidden; max-width: 100%; max-height: 100%; object-fit: contain;');
                    (() => {
                      const nextPage = document.querySelectorAll('div.nextPage').length > 0 ? document.querySelectorAll('div.nextPage')[0] : document.createElement('div');
                      nextPage.className = 'nextPage';
                      nextPage.setAttribute('style', 'position: fixed; left: 0; height: 100vh; width: 50vw; border: none; z-index: 1000;');
                      nextPage.setAttribute('onClick',`document.location='$nextLink';`);
                      document.querySelectorAll('div.nextPage').length === 0 && document.body.appendChild(nextPage);

                      const prevPage = document.querySelectorAll('div.prevPage').length > 0 ? document.querySelectorAll('div.prevPage')[0] : document.createElement('div');
                      prevPage.className = 'prevPage';
                      prevPage.setAttribute('style', 'position: fixed; right: 0; height: 100vh; width: 50vw; border: none; z-index: 1000;');
                      prevPage.setAttribute('onClick',`document.location='$prevLink';`);
                      document.querySelectorAll('div.prevPage').length === 0 && document.body.appendChild(prevPage);
                    })();
                  ''');
                }
              } else if ((Uri.parse(url).host == 'exhentai.org' ||
                      Uri.parse(url).host == 'e-hentai.org') &&
                  Uri.parse(url).path.startsWith('/-1')) {
                Navigator.pop(context);
              } else if ((Uri.parse(url).host == 'exhentai.org' ||
                      Uri.parse(url).host == 'e-hentai.org') &&
                  Uri.parse(url).path.startsWith('/gallerypopups.php')) {
                final closeWindow = await _controller
                    .runJavaScriptReturningResult('''
                        Boolean(document.querySelector('[style="text-align:center; margin-top:50px"]'))
                      ''');
                if (closeWindow == true ||
                    closeWindow.toString() == 'true' ||
                    closeWindow.toString().contains('true')) {
                  Navigator.pop(context);
                }
              }
            } catch (e) {
              Logger.error('[Reader-WebView-onPageFinished] Error: $e');
              _controller.reload();
            }
          },
        ),
      );
    if (readerUrl.contains('e-hentai.org') ||
        readerUrl.contains('exhentai.org')) {
      EHSession.cookie().then((cookies) async {
        final parsedCookies = parseCookies(cookies!);
        for (final entry in parsedCookies.entries) {
          await cookieManager.setCookie(
            WebViewCookie(
              name: entry.key,
              value: entry.value,
              domain: Uri.parse(readerUrl).host,
            ),
          );
        }
        _controller = _controller..loadRequest(Uri.parse(readerUrl));
      });
    } else {
      _controller.loadRequest(Uri.parse(readerUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null,
        backgroundColor: Colors.transparent,
        elevation: 0.0,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
