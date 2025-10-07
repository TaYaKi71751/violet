// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/settings/patchnote_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/version/update_sync.dart';

class PatchNotePrompt extends StatefulWidget {
  const PatchNotePrompt({super.key});

  @override
  State<PatchNotePrompt> createState() => _PatchNotePromptState();
}

class _PatchNotePromptState extends State<PatchNotePrompt> {
  bool _doNotShowAgain = true; // 기본 체크됨

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = patches.isNotEmpty ? patches.first : null;
    final IconData headerIcon = latest == null
        ? Icons.new_releases
        : latest.isMajor
        ? MdiIcons.chevronTripleUp
        : latest.isMinor
        ? MdiIcons.chevronDoubleUp
        : MdiIcons.trendingUp;
    // PatchNotePage에서는 최신 항목(i == 0)을 녹색 계열로 강조합니다.
    final Color headerBaseColor = Settings.majorColor.value;
    final Color onHeaderColor =
        ThemeData.estimateBrightnessForColor(headerBaseColor) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final Color major = Settings.majorColor.value;
    final Color onMajor =
        ThemeData.estimateBrightnessForColor(major) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.dialogBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      headerBaseColor.withOpacity(0.95),
                      headerBaseColor.withOpacity(0.75),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(headerIcon, color: onHeaderColor),
                    const SizedBox(width: 8),
                    Text(
                      Translations.instance!.trans('patchnote'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onHeaderColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LatestPatchSummaryCard(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _doNotShowAgain,
                          onChanged: (v) {
                            setState(() {
                              _doNotShowAgain = v ?? true;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            Translations.instance!.trans('donotshowagain'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Footer buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: major),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PatchNotePage(),
                          ),
                        );
                      },
                      child: Text(Translations.instance!.trans('more')),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: major,
                        foregroundColor: onMajor,
                      ),
                      onPressed: () async {
                        // Save per-version shown mark only when checked
                        if (_doNotShowAgain) {
                          await Settings.lastPatchNoteShownVersion.setValue(
                            UpdateSyncManager.currentVersion,
                          );
                        }
                        // Per-version gating only: no global hide flag
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: Text(Translations.instance!.trans('ok')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestPatchSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 최신 항목만 간략 표시
    if (patches.isEmpty) {
      return const Text('표시할 패치 노트가 없습니다.');
    }
    final latest = patches.first;
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceVariant;
    final onSurface = theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: surface.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onSurface.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.new_releases, color: Settings.majorColor.value),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  latest.version,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${latest.dateTime.year}.${latest.dateTime.month}.${latest.dateTime.day}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...latest.contents
              .take(3)
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(e)),
                    ],
                  ),
                ),
              ),
          if (latest.contents.length > 3)
            Row(children: const [Expanded(child: Text('• ...'))]),
        ],
      ),
    );
  }
}

Future<void> showPatchNotePromptIfNeeded(BuildContext context) async {
  // Show only when app version changed
  final String current = UpdateSyncManager.currentVersion;
  final String lastShown = Settings.lastPatchNoteShownVersion.value;
  final bool versionChanged = lastShown != current;

  if (!versionChanged) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PatchNotePrompt(),
  );
}
