import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ReaderScreen extends StatefulWidget {
  final String readerUrl;
  const ReaderScreen({required this.readerUrl, super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState(readerUrl);
}

class _ReaderScreenState extends State<ReaderScreen> {
  final String readerUrl;

  late final WebViewController _controller;
  _ReaderScreenState(this.readerUrl);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (url) => {}))
      ..loadRequest(Uri.parse(readerUrl));
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
