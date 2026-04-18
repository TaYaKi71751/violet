// Source code from
// https://github.com/tommy351/eh-redux/blob/master/lib/screens/login/screen.dart
// https://github.com/tommy351/eh-redux/blob/master/lib/utils/cookie.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

Map<String, String> parseCookies(String cookies) {
  final result = HashMap<String, String>();

  for (final cookie in cookies.split(';')) {
    final index = cookie.indexOf('=');

    if (index > -1) {
      final key = cookie.substring(0, index).trim();
      final value = cookie.substring(index + 1).trim();
      result[key] = value;
    }
  }

  return result;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _loginUrl = 'https://e-hentai.org/bounce_login.php';
  final WebViewCookieManager cookieManager = WebViewCookieManager();

  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    cookieManager.clearCookies();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (url) => _checkCookie()),
      )
      ..loadRequest(Uri.parse(_loginUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: WebViewWidget(controller: _controller),
    );
  }

  Future<void> _checkCookie() async {
    var cookieString = await _controller.runJavaScriptReturningResult(
      'document.cookie',
    );
    try {
      cookieString = jsonDecode(cookieString as String) as String;
    } catch (e) {}

    final cookies = parseCookies(cookieString as String);
    developer.log('Get cookies: $cookies');

    if (cookies.containsKey('ipb_member_id') &&
        cookies.containsKey('ipb_pass_hash') &&
        (cookies.containsKey('sk') || cookies.containsKey('igneous'))) {
      if (!mounted) return;
      Navigator.pop(context, cookieString);
    } else if (cookies.containsKey('ipb_member_id')) {
      _controller.loadRequest(Uri.parse('https://exhentai.org'));
    }
  }
}
