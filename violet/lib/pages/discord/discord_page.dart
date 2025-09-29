// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:uni_links/uni_links.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:violet/server/violet_v2.dart';

// class DiscordLinkPage extends StatefulWidget {
//   const DiscordLinkPage({super.key});

//   @override
//   State<DiscordLinkPage> createState() => _DiscordLinkPageState();
// }

// class _DiscordLinkPageState extends State<DiscordLinkPage> {
//   StreamSubscription<String?>? _sub;
//   bool _linked = false;
//   String? _lastLink;
//   bool _listening = false;

//   @override
//   void initState() {
//     super.initState();
//     _initLinks();
//   }

//   Future<void> _initLinks() async {
//     if (_listening) return;
//     _listening = true;

//     try {
//       final initial = await getInitialLink();
//       if (initial != null) _handleLink(initial);
//     } catch (_) {}

//     _sub = linkStream.listen((link) {
//       if (link != null) _handleLink(link);
//     }, onError: (_) {});
//   }

//   void _handleLink(String link) {
//     setState(() {
//       _lastLink = link;
//       if (link.startsWith('violet://discord-login')) {
//         _linked = true;
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _sub?.cancel();
//     super.dispose();
//   }

//   Future<void> _startDiscordLink() async {
//     final url = Uri.parse('${VioletServerV2.api}/api/v2/auth/discord');
//     await launchUrl(url, mode: LaunchMode.externalApplication);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Discord 연동')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               '계정을 Discord와 연동합니다.\n\n1) 버튼을 눌러 브라우저에서 로그인합니다.\n2) 완료되면 앱으로 자동으로 돌아옵니다.',
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.link),
//               label: const Text('디스코드 연동 시작'),
//               onPressed: _startDiscordLink,
//             ),
//             const SizedBox(height: 24),
//             Row(
//               children: [
//                 Icon(
//                   _linked ? Icons.check_circle : Icons.radio_button_unchecked,
//                   color: _linked ? Colors.green : Colors.grey,
//                 ),
//                 const SizedBox(width: 8),
//                 Text(_linked ? '연동 완료' : '연동 대기 중'),
//               ],
//             ),
//             const SizedBox(height: 8),
//             if (_lastLink != null) ...[
//               const Text('최근 딥링크:'),
//               Text(_lastLink!,
//                   style: const TextStyle(fontSize: 12, color: Colors.grey)),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
