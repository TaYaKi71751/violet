// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:violet/locale/locale.dart' as locale;
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';

class ViewerSettingPanel extends StatefulWidget {
  final String getxId;
  final VoidCallback viewerStyleChangeEvent;
  final VoidCallback thumbSizeChangeEvent;

  const ViewerSettingPanel({
    super.key,
    required this.viewerStyleChangeEvent,
    required this.thumbSizeChangeEvent,
    required this.getxId,
  });

  @override
  State<ViewerSettingPanel> createState() => _ViewerSettingPanelState();
}

class _ViewerSettingPanelState extends State<ViewerSettingPanel> {
  late final ViewerController c;
  int imgqualityOption = Settings.imageQuality.value;

  @override
  void initState() {
    super.initState();
    c = Get.find(tag: widget.getxId);
  }

  @override
  Widget build(BuildContext context) {
    var listview = ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        ListTile(
          dense: true,
          title: Row(
            children: [
              Text(
                  '${locale.Translations.instance!.trans('timersetting')} '
                  '(${Settings.timerTick.value.toStringAsFixed(1)}${locale.Translations.instance!.trans('second')})',
                  style: const TextStyle(color: Colors.white)),
              Expanded(
                child: Align(
                  child: SliderTheme(
                    data: const SliderThemeData(
                      activeTrackColor: Colors.blue,
                      inactiveTrackColor: Color(0xffd0d2d3),
                      trackHeight: 3,
                      thumbShape:
                          RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    ),
                    child: Slider(
                      value: Settings.timerTick.value,
                      max: 20,
                      min: 1,
                      divisions: (20 - 1) * 2,
                      inactiveColor: Settings.majorColor.value.withOpacity(0.7),
                      activeColor: Settings.majorColor.value,
                      onChangeEnd: (value) async {
                        await Settings.timerTick.setValue(value);
                      },
                      onChanged: (value) {
                        setState(() {
                          Settings.timerTick.setValue(value);
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _checkBox(
          value: Settings.isHorizontal.value,
          title: locale.Translations.instance!.trans('toggleviewerstyle'),
          onChanged: (value) async {
            await Settings.isHorizontal.setValue(!Settings.isHorizontal.value);

            widget.viewerStyleChangeEvent.call();

            c.viewType.value = Settings.isHorizontal.value
                ? ViewType.horizontal
                : ViewType.vertical;
            setState(() {});
          },
        ),
        _checkBox(
          title: locale.Translations.instance!.trans('togglescrollvertical'),
          value: Settings.scrollVertical.value,
          enabled: Settings.isHorizontal.value,
          onChanged: (value) async {
            await Settings.scrollVertical
                .setValue(!Settings.scrollVertical.value);

            c.viewScrollType.value = Settings.scrollVertical.value
                ? ViewType.vertical
                : ViewType.horizontal;

            setState(() {});
          },
        ),
        _checkBox(
          title: locale.Translations.instance!.trans('togglerighttoleft'),
          value: Settings.rightToLeft.value,
          onChanged: (value) async {
            await Settings.rightToLeft.setValue(!Settings.rightToLeft.value);

            c.rightToLeft.value = Settings.rightToLeft.value;

            setState(() {});
          },
        ),
        _checkBox(
          title: locale.Translations.instance!.trans('toggleanimatin'),
          value: Settings.animation.value,
          onChanged: (value) async {
            await Settings.animation.setValue(!Settings.animation.value);

            c.animation.value = Settings.animation.value;

            setState(() {});
          },
        ),
        _checkBox(
          title: locale.Translations.instance!.trans('togglepadding'),
          value: Settings.padding.value,
          onChanged: (value) async {
            await Settings.padding.setValue(!Settings.padding.value);

            c.padding.value = Settings.padding.value;

            setState(() {});
          },
        ),
        _checkBox(
          title: locale.Translations.instance!.trans('disableoverlaybuttons'),
          value: !Settings.disableOverlayButton.value,
          onChanged: (value) async {
            await Settings.disableOverlayButton
                .setValue(!Settings.disableOverlayButton.value);

            c.overlayButton.value = !Settings.disableOverlayButton.value;

            setState(() {});
          },
        ),
        if (!Platform.isIOS)
          _checkBox(
            value: Settings.moveToAppBarToBottom.value,
            title: locale.Translations.instance!.trans('movetoappbartobottom'),
            onChanged: (value) async {
              await Settings.moveToAppBarToBottom
                  .setValue(!Settings.moveToAppBarToBottom.value);

              c.appBarToBottom.value = Settings.moveToAppBarToBottom.value;

              setState(() {});
            },
          ),
        _checkBox(
          value: Settings.showSlider.value,
          title: locale.Translations.instance!.trans('showslider'),
          enabled: Settings.moveToAppBarToBottom.value,
          onChanged: (value) async {
            await Settings.showSlider.setValue(!Settings.showSlider.value);

            c.showSlider.value = Settings.showSlider.value;

            setState(() {});
          },
        ),
        _checkBox(
          value: Settings.showPageNumberIndicator.value,
          title: locale.Translations.instance!.trans('showpagenumberindicator'),
          onChanged: (value) async {
            await Settings.showPageNumberIndicator
                .setValue(!Settings.showPageNumberIndicator.value);

            c.indicator.value = Settings.showPageNumberIndicator.value;

            setState(() {});
          },
        ),
        if (!Platform.isIOS)
          _checkBox(
            title: locale.Translations.instance!.trans('disablefullscreen'),
            value: !Settings.disableFullScreen.value,
            onChanged: (value) async {
              await Settings.disableFullScreen
                  .setValue(!Settings.disableFullScreen.value);

              c.fullscreen.value = Settings.disableFullScreen.value;

              if (Settings.disableFullScreen.value) {
                SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.manual,
                  overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
                );
              }
              setState(() {});
            },
          ),
        PopupMenuButton<int>(
          onSelected: (int value) async {
            await Settings.imageQuality.setValue(value);

            c.imgQuality.value = value;

            setState(() {
              imgqualityOption = value;
            });
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            const PopupMenuItem<int>(
              value: 0,
              child: Text('None'),
            ),
            PopupMenuItem<int>(
              value: 1,
              child: Text(locale.Translations.instance!.trans('high')),
            ),
            PopupMenuItem<int>(
              value: 2,
              child: Text(locale.Translations.instance!.trans('middle')),
            ),
            PopupMenuItem<int>(
              value: 3,
              child: Text(locale.Translations.instance!.trans('low')),
            ),
          ],
          child: ListTile(
            dense: true,
            title: Text(
              locale.Translations.instance!.trans('imgquality'),
              style: const TextStyle(color: Colors.white),
            ),
            trailing: Text(
              [
                'None',
                locale.Translations.instance!.trans('high'),
                locale.Translations.instance!.trans('middle'),
                locale.Translations.instance!.trans('low')
              ][imgqualityOption],
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        PopupMenuButton<int>(
          onSelected: (int value) async {
            await Settings.thumbSize.setValue(value);

            c.thumbSize.value = value;

            widget.thumbSizeChangeEvent.call();
            setState(() {});
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: 0,
              child: Text(locale.Translations.instance!.trans('large')),
            ),
            PopupMenuItem<int>(
              value: 1,
              child: Text(locale.Translations.instance!.trans('middle')),
            ),
            PopupMenuItem<int>(
              value: 2,
              child: Text(locale.Translations.instance!.trans('small')),
            ),
          ],
          child: ListTile(
            dense: true,
            title: Text(
              locale.Translations.instance!.trans('thumbnailslidersize'),
              style: const TextStyle(color: Colors.white),
            ),
            trailing: Text(
              [
                locale.Translations.instance!.trans('verylarge'),
                locale.Translations.instance!.trans('large'),
                locale.Translations.instance!.trans('middle'),
                locale.Translations.instance!.trans('small')
              ][Settings.thumbSize.value],
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        _checkBox(
          value: Settings.showRecordJumpMessage.value,
          title: locale.Translations.instance!.trans('showrecordjumpmessage'),
          onChanged: (value) async {
            await Settings.showRecordJumpMessage
                .setValue(!Settings.showRecordJumpMessage.value);
            setState(() {});
          },
        ),
        if (Platform.isIOS) Container(height: 24),
      ],
    );

    if (Settings.enableViewerFunctionBackdropFilter.value) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6)),
            padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
            child: listview,
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.black.withOpacity(0.8),
        padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
        child: listview,
      );
    }
  }

  _checkBox({
    required bool value,
    required String title,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return ListTile(
      dense: true,
      enabled: enabled,
      trailing: Switch(
        onChanged: enabled ? onChanged : null,
        value: value,
        activeColor: Settings.majorColor.value,
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () => onChanged(value),
    );
  }
}
