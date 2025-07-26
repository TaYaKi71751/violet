// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/settings/settings.dart';

class LabSetting extends StatefulWidget {
  const LabSetting({super.key});

  @override
  State<LabSetting> createState() => _LabSettingState();
}

class _LabSettingState extends State<LabSetting> {
  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor.value),
              title: const Text('Simple item widget loading icon'),
              subtitle: const Text('using circular bar instead of flare'),
              trailing: Switch(
                value: Settings.simpleItemWidgetLoadingIcon.value,
                onChanged: (newValue) async {
                  await Settings.simpleItemWidgetLoadingIcon.setValue(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor.value,
                activeColor: Settings.majorAccentColor.value,
              ),
            ),
            onTap: () async {
              await Settings.simpleItemWidgetLoadingIcon
                  .setValue(!Settings.simpleItemWidgetLoadingIcon.value);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor.value),
              title: const Text('Artist article list tap option'),
              subtitle: const Text(
                  'show new viewer when artist article list item tapped'),
              trailing: Switch(
                value: Settings.showNewViewerWhenArtistArticleListItemTap.value,
                onChanged: (newValue) async {
                  await Settings.showNewViewerWhenArtistArticleListItemTap
                      .setValue(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor.value,
                activeColor: Settings.majorAccentColor.value,
              ),
            ),
            onTap: () async {
              await Settings.showNewViewerWhenArtistArticleListItemTap.setValue(
                  !Settings.showNewViewerWhenArtistArticleListItemTap.value);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor.value),
              title: const Text('Enable viewer function backdrop filter'),
              subtitle: const Text(
                  'apply ios style blur effect to viewer functions. this blur effect may decrease performance.'),
              trailing: Switch(
                value: Settings.enableViewerFunctionBackdropFilter.value,
                onChanged: (newValue) async {
                  await Settings.enableViewerFunctionBackdropFilter
                      .setValue(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor.value,
                activeColor: Settings.majorAccentColor.value,
              ),
            ),
            onTap: () async {
              await Settings.enableViewerFunctionBackdropFilter
                  .setValue(!Settings.enableViewerFunctionBackdropFilter.value);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor.value),
              title: const Text('Using PushReplacement On Article Read'),
              subtitle: const Text(
                  'when tap Read button in the article-info, the article-info closes.'),
              trailing: Switch(
                value: Settings.usingPushReplacementOnArticleRead.value,
                onChanged: (newValue) async {
                  await Settings.usingPushReplacementOnArticleRead
                      .setValue(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor.value,
                activeColor: Settings.majorAccentColor.value,
              ),
            ),
            onTap: () async {
              await Settings.usingPushReplacementOnArticleRead
                  .setValue(!Settings.usingPushReplacementOnArticleRead.value);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor.value),
              title: const Text('Download E(x)hentai Raw Image'),
              subtitle: const Text(
                  'download the original image. many network errors (connection reset ... etc) can occur during this operation.'),
              trailing: Switch(
                value: Settings.downloadEhRawImage.value,
                onChanged: (newValue) async {
                  await Settings.downloadEhRawImage.setValue(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor.value,
                activeColor: Settings.majorAccentColor.value,
              ),
            ),
            onTap: () async {
              await Settings.downloadEhRawImage
                  .setValue(!Settings.downloadEhRawImage.value);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor.value),
              title: const Text('Bookmark Scrollbar Position To Left'),
              subtitle: const Text('Reposition Bookmark Scrollber'),
              trailing: Switch(
                value: Settings.bookmarkScrollbarPositionToLeft.value,
                onChanged: (newValue) async {
                  await Settings.bookmarkScrollbarPositionToLeft
                      .setValue(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor.value,
                activeColor: Settings.majorAccentColor.value,
              ),
            ),
            onTap: () async {
              await Settings.bookmarkScrollbarPositionToLeft
                  .setValue(!Settings.bookmarkScrollbarPositionToLeft.value);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor.value),
              title: const Text('In Viewer Message Search'),
              subtitle: const Text('Support message search on viewer mode.'),
              trailing: Switch(
                value: Settings.inViewerMessageSearch.value,
                onChanged: (newValue) async {
                  await Settings.inViewerMessageSearch.setValue(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor.value,
                activeColor: Settings.majorAccentColor.value,
              ),
            ),
            onTap: () async {
              await Settings.inViewerMessageSearch
                  .setValue(!Settings.inViewerMessageSearch.value);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Container _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 8.0,
      ),
      width: double.infinity,
      height: 1.0,
      color: Settings.themeWhat.value
          ? Colors.grey.shade600
          : Colors.grey.shade400,
    );
  }
}
