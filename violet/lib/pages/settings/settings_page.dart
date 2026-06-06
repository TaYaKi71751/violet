// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mdi/mdi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/component/eh/eh_bookmark.dart';
import 'package:violet/component/index.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/downloader/isolate_downloader.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/other/ex_country.dart';
import 'package:violet/pages/after_loading/afterloading_page.dart';
import 'package:violet/pages/common/toast.dart';
import 'package:violet/pages/community/user_status_card.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/pages/settings/artist_collection/artist_collection_page.dart';
import 'package:violet/pages/settings/faq_page.dart';
import 'package:violet/pages/lab/lab/global_comments.dart';
import 'package:violet/pages/lab/lab/recent_record_u.dart';
import 'package:violet/pages/lab/lab_page.dart';
import 'package:violet/pages/settings/user_manual_page.dart';
import 'package:violet/pages/settings/patchnote_page.dart';
import 'package:violet/pages/segment/double_tap_to_top.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/settings/bookmark_version_select.dart';
import 'package:violet/pages/settings/db_rebuild_page.dart';
import 'package:violet/pages/settings/import_from_eh.dart';
import 'package:violet/pages/settings/license_page.dart';
import 'package:violet/pages/settings/lock_setting_page.dart';
import 'package:violet/pages/settings/log_page.dart';
import 'package:violet/pages/settings/login/ehentai_login.dart';
import 'package:violet/pages/settings/restore_bookmark.dart';
import 'package:violet/pages/settings/route.dart';
import 'package:violet/pages/settings/tag_rebuild_page.dart';
import 'package:violet/pages/settings/tag_selector.dart';
import 'package:violet/pages/settings/version_page.dart';
import 'package:violet/pages/splash/splash_page.dart';
import 'package:violet/platform/misc.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/util/helper.dart';
import 'package:violet/version/sync.dart';
import 'package:violet/version/update_sync.dart';
import 'package:violet/widgets/theme_switchable_state.dart';
import 'package:violet/network/wrapper.dart' as http;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ThemeSwitchableState<SettingsPage>
    with AutomaticKeepAliveClientMixin<SettingsPage>, DoubleTapToTopMixin {
  final FlareControls _flareController = FlareControls();

  @override
  VoidCallback? get shouldReloadCallback =>
      () => _shouldReload = true;

  List<Widget>? _cachedGroups;
  bool _shouldReload = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    if (_cachedGroups == null || _shouldReload) {
      _shouldReload = false;
      _cachedGroups = _themeGroup()
        ..addAll([const UserStatusCard()])
        ..addAll(_communityGroup())
        ..addAll(_searchGroup())
        ..addAll(_systemGroup())
        ..addAll(_securityGroup())
        ..addAll(_databaseGroup())
        ..addAll(_networkingGroup())
        ..addAll(_downloadGroup())
        ..addAll(_bookmarkGroup())
        ..addAll(_componetGroup())
        ..addAll(_viewGroup())
        ..addAll(_updateGroup())
        ..addAll(_etcGroup())
        ..add(_bottomInfo());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: statusBarHeight),
      physics: const BouncingScrollPhysics(),
      controller: doubleTapToTopScrollController = ScrollController(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _cachedGroups!,
      ),
    );
  }

  Container _buildItems(List<Widget> items) {
    final itemsWithDividers = items
        .map((e) => [e, SettingGroupDivider(key: GlobalKey())])
        .expand((e) => e)
        .take(items.length * 2 - 1)
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      width: double.infinity,
      decoration: !Settings.themeFlat.value
          ? BoxDecoration(
              color: Settings.themeWhat.value ? Colors.black26 : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Settings.themeWhat.value
                      ? Colors.black26
                      : Colors.grey.withOpacity(0.1),
                  spreadRadius: Settings.themeWhat.value ? 0 : 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3), // changes position of shadow
                ),
              ],
            )
          : null,
      color: !Settings.themeFlat.value
          ? null
          : Settings.themeWhat.value
          ? Colors.black26
          : Colors.white,
      child: !Settings.themeFlat.value
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Material(
                color: Settings.themeWhat.value
                    ? Settings.themeBlack.value
                          ? Palette.blackThemeBackground
                          : Colors.black38
                    : Colors.white,
                child: Column(children: itemsWithDividers),
              ),
            )
          : Column(children: itemsWithDividers),
    );
  }

  @override
  bool get wantKeepAlive => true;

  List<Widget> _themeGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('theme')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: ShaderMask(
              shaderCallback: (bounds) => const RadialGradient(
                center: Alignment.topLeft,
                radius: 1.0,
                colors: [Colors.black, Colors.white],
                tileMode: TileMode.clamp,
              ).createShader(bounds),
              child: const Icon(MdiIcons.themeLightDark, color: Colors.white),
            ),
            title: Text(Translations.instance!.trans('darkmode')),
            trailing: SizedBox(
              width: 50,
              height: 50,
              child: FlareActor(
                'assets/flare/switch_daytime.flr',
                animation: Settings.themeWhat.value ? 'night_idle' : 'day_idle',
                controller: _flareController,
                snapToEnd: true,
              ),
            ),
          ),
          onTap: () async {
            if (Settings.themeWhat.value) {
              _flareController.play('switch_night');
            } else {
              _flareController.play('switch_day');
            }
            await Settings.themeWhat.setValue(!Settings.themeWhat.value);
            DynamicTheme.of(context)!.setBrightness(
              Settings.themeWhat.value ? Brightness.dark : Brightness.light,
            );
            ThemeSwitchableStateTargetStore.doChange();
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(MdiIcons.monitor, color: Settings.majorColor.value),
            title: Text(Translations.instance!.trans('usesystemtheme')),
            trailing: Switch(
              value: Settings.useSystemTheme.value,
              onChanged: (newValue) async {
                await Settings.useSystemTheme.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.useSystemTheme.setValue(
              !Settings.useSystemTheme.value,
            );
            if (Settings.useSystemTheme.value) {
              final systemBrightness = MediaQuery.platformBrightnessOf(context);
              final themeChanged =
                  Settings.themeWhat.value !=
                  (systemBrightness == Brightness.dark);
              if (themeChanged) {
                if (Settings.themeWhat.value) {
                  _flareController.play('switch_night');
                } else {
                  _flareController.play('switch_day');
                }
                await Settings.themeWhat.setValue(!Settings.themeWhat.value);
                DynamicTheme.of(context)!.setBrightness(systemBrightness);
                ThemeSwitchableStateTargetStore.doChange();
              }
            }
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        ListTile(
          leading: ShaderMask(
            shaderCallback: (bounds) => const RadialGradient(
              center: Alignment.bottomLeft,
              radius: 1.2,
              colors: [Colors.orange, Colors.pink],
              tileMode: TileMode.clamp,
            ).createShader(bounds),
            child: const Icon(MdiIcons.formatColorFill, color: Colors.white),
          ),
          title: Text(Translations.instance!.trans('colorsetting')),
          trailing: const Icon(
            // Icons.message,
            Icons.keyboard_arrow_right,
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(Translations.instance!.trans('selectcolor')),
                  content: SingleChildScrollView(
                    child: BlockPicker(
                      pickerColor: Settings.majorColor.value,
                      onColorChanged: (color) async {
                        await Settings.setMajorColor(color);
                        setState(() {
                          _shouldReload = true;
                        });
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
        InkWell(
          onTap: Settings.themeWhat.value
              ? () async {
                  await Settings.themeBlack.setValue(
                    !Settings.themeBlack.value,
                  );
                  DynamicTheme.of(context)!.setThemeData(
                    ThemeData(
                      appBarTheme: AppBarTheme(
                        systemOverlayStyle: !Settings.themeWhat.value
                            ? SystemUiOverlayStyle.dark
                            : SystemUiOverlayStyle.light,
                      ),
                      useMaterial3: false,
                      brightness: Theme.of(context).brightness,
                      bottomSheetTheme: BottomSheetThemeData(
                        backgroundColor: Colors.black.withOpacity(0),
                      ),
                      scaffoldBackgroundColor:
                          Settings.themeBlack.value && Settings.themeWhat.value
                          ? Colors.black
                          : null,
                      dialogBackgroundColor:
                          Settings.themeBlack.value && Settings.themeWhat.value
                          ? Palette.blackThemeBackground
                          : null,
                      cardColor:
                          Settings.themeBlack.value && Settings.themeWhat.value
                          ? Palette.blackThemeBackground
                          : null,
                      colorScheme: ColorScheme.fromSwatch().copyWith(
                        secondary: Settings.majorColor.value,
                        brightness: Theme.of(context).brightness,
                      ),
                      cupertinoOverrideTheme: CupertinoThemeData(
                        brightness: Theme.of(context).brightness,
                        primaryColor: Settings.majorColor.value,
                        textTheme: const CupertinoTextThemeData(),
                        barBackgroundColor: Settings.themeWhat.value
                            ? Settings.themeBlack.value
                                  ? const Color(0xFF181818)
                                  : Colors.grey.shade800
                            : null,
                      ),
                    ),
                  );
                  ThemeSwitchableStateTargetStore.doChange();
                  setState(() {
                    _shouldReload = true;
                  });
                }
              : null,
          child: ListTile(
            leading: Icon(
              MdiIcons.brightness3,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('blackmode')),
            trailing: Switch(
              value: Settings.themeBlack.value,
              onChanged: Settings.themeWhat.value
                  ? (newValue) async {
                      await Settings.themeFlat.setValue(newValue);
                      DynamicTheme.of(context)!.setThemeData(
                        ThemeData(
                          appBarTheme: AppBarTheme(
                            systemOverlayStyle: !Settings.themeWhat.value
                                ? SystemUiOverlayStyle.dark
                                : SystemUiOverlayStyle.light,
                          ),
                          useMaterial3: false,
                          brightness: Theme.of(context).brightness,
                          bottomSheetTheme: BottomSheetThemeData(
                            backgroundColor: Colors.black.withOpacity(0),
                          ),
                          scaffoldBackgroundColor:
                              Settings.themeBlack.value &&
                                  Settings.themeWhat.value
                              ? Colors.black
                              : null,
                          dialogBackgroundColor:
                              Settings.themeBlack.value &&
                                  Settings.themeWhat.value
                              ? Palette.blackThemeBackground
                              : null,
                          cardColor:
                              Settings.themeBlack.value &&
                                  Settings.themeWhat.value
                              ? Palette.blackThemeBackground
                              : null,
                          colorScheme: ColorScheme.fromSwatch().copyWith(
                            secondary: Settings.majorColor.value,
                          ),
                          cupertinoOverrideTheme: CupertinoThemeData(
                            brightness: Theme.of(context).brightness,
                            primaryColor: Settings.majorColor.value,
                            textTheme: const CupertinoTextThemeData(),
                            barBackgroundColor: Settings.themeWhat.value
                                ? Settings.themeBlack.value
                                      ? const Color(0xFF181818)
                                      : Colors.grey.shade800
                                : null,
                          ),
                        ),
                      );
                      setState(() {
                        _shouldReload = true;
                      });
                    }
                  : null,
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
        ),
        InkWell(
          child: ListTile(
            leading: Icon(Mdi.buffer, color: Settings.majorColor.value),
            title: Text(Translations.instance!.trans('useflattheme')),
            trailing: Switch(
              value: Settings.themeFlat.value,
              onChanged: (newValue) async {
                await Settings.themeFlat.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.themeFlat.setValue(!Settings.themeFlat.value);
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        InkWell(
          child: ListTile(
            leading: Icon(
              MdiIcons.tabletDashboard,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('usetabletmode')),
            trailing: Switch(
              value: Settings.useTabletMode.value,
              onChanged: (newValue) async {
                await Settings.useTabletMode.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.useTabletMode.setValue(
              !Settings.useTabletMode.value,
            );
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(
              MdiIcons.cellphoneText,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('userdrawer')),
            trailing: Switch(
              value: Settings.useDrawer.value,
              onChanged: (newValue) async {
                await Settings.useDrawer.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });

                final afterLoadingPageState = context
                    .findAncestorStateOfType<AfterLoadingPageState>();
                afterLoadingPageState!.setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.useDrawer.setValue(!Settings.useDrawer.value);
            setState(() {
              _shouldReload = true;
            });

            final afterLoadingPageState = context
                .findAncestorStateOfType<AfterLoadingPageState>();
            afterLoadingPageState!.setState(() {
              _shouldReload = true;
            });
          },
        ),
      ]),
    ];
  }

  List<Widget> _communityGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('community')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: const Icon(MdiIcons.discord, color: Color(0xFF7189da)),
            title: Text(Translations.instance!.trans('discord')),
            trailing: const Icon(Icons.open_in_new),
          ),
          onTap: () async {
            final url = Uri.parse('https://discord.gg/K8qny6E');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
        ),
        ListTile(
          leading: const Icon(MdiIcons.gmail, color: Colors.redAccent),
          title: Text(Translations.instance!.trans('contact')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            final url = Uri(
              scheme: 'mailto',
              path: 'violet.dev.master@gmail.com',
              queryParameters: {'subject': '[App Issue] '},
            );
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
        ),
        ListTile(
          leading: Icon(
            MdiIcons.accessPointNetwork,
            color: Settings.majorColor.value,
          ),
          title: Text(Translations.instance!.trans('realtimeuserrecord')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            PlatformNavigator.navigateSlide(context, const LabRecentRecordsU());
          },
        ),
        ListTile(
          leading: Icon(
            MdiIcons.commentTextMultiple,
            color: Settings.majorColor.value,
          ),
          title: Text(Translations.instance!.trans('comment')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            PlatformNavigator.navigateSlide(context, const LabGlobalComments());
          },
        ),
        ListTile(
          leading: Icon(
            MdiIcons.star,
            color: Settings.themeWhat.value
                ? Colors.yellowAccent
                : Colors.yellow.shade900,
          ),
          title: Text(Translations.instance!.trans('artistcollection')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            PlatformNavigator.navigateSlide(
              context,
              const ArtistCollectionPage(),
            );
          },
        ),
        ListTile(
          leading: const Icon(
            MdiIcons.bookOpenPageVariant,
            color: Colors.brown,
          ),
          title: Text(Translations.instance!.trans('usermanual')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            PlatformNavigator.navigateSlide(context, const UserManualPage());
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: const Icon(
              MdiIcons.frequentlyAskedQuestions,
              color: Colors.orange,
            ),
            title: Text(Translations.instance!.trans('faq')),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () {
            PlatformNavigator.navigateSlide(context, const FAQPageKorean());
          },
        ),
      ]),
    ];
  }

  List<Widget> _searchGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('search')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(
              MdiIcons.tagHeartOutline,
              color: Settings.majorColor.value,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Translations.instance!.trans('defaulttag')),
                Text(
                  Translations.instance!.trans('currenttag') +
                      Settings.includeTags.value,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () async {
            final vv = await showDialog(
              context: context,
              builder: (BuildContext context) =>
                  const TagSelectorDialog(what: 'include'),
            );

            if (vv != null && vv.$1 == 1) {
              Settings.includeTags.setValue(vv.$2);
              setState(() {
                _shouldReload = true;
              });
            }
          },
        ),
        ListTile(
          leading: Icon(MdiIcons.tagOff, color: Settings.majorColor.value),
          title: Text(Translations.instance!.trans('excludetag')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            final vv = await showDialog<(int, String)?>(
              context: context,
              builder: (BuildContext context) =>
                  const TagSelectorDialog(what: 'exclude'),
            );

            if (vv?.$1 == 1) {
              Settings.excludeTags.setValue(vv!.$2.split(' ').toList());
              setState(() {
                _shouldReload = true;
              });
            }
          },
        ),
        ListTile(
          leading: Icon(MdiIcons.tooltipEdit, color: Settings.majorColor.value),
          title: Text(Translations.instance!.trans('tagrebuild')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            if (await showYesNoDialog(
              context,
              Translations.instance!.trans('tagrebuildmsg'),
              Translations.instance!.trans('tagrebuild'),
            )) {
              await showDialog(
                context: context,
                builder: (BuildContext context) => const TagRebuildPage(),
              );

              await HentaiIndex.init();

              showToast(
                level: ToastLevel.check,
                message:
                    '${Translations.instance!.trans('tagrebuild')} ${Translations.instance!.trans('complete')}',
              );
            }
          },
        ),
        InkWell(
          child: ListTile(
            leading: Icon(Mdi.compassOutline, color: Settings.majorColor.value),
            title: const Text('Pure Search'),
            trailing: Switch(
              value: Settings.searchPure.value,
              onChanged: (newValue) async {
                await Settings.searchPure.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.searchPure.setValue(!Settings.searchPure.value);
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        InkWell(
          child: ListTile(
            leading: Icon(
              MdiIcons.databaseSearch,
              color: Settings.majorColor.value,
            ),
            title: Text(
              Translations.instance!.trans('recordsearchdatabaseonly'),
            ),
            trailing: Switch(
              value: Settings.recordSearchDatabaseOnly.value,
              onChanged: (newValue) async {
                await Settings.recordSearchDatabaseOnly.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeThumbColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.recordSearchDatabaseOnly.setValue(
              !Settings.recordSearchDatabaseOnly.value,
            );
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(MdiIcons.searchWeb, color: Settings.majorColor.value),
            title: Text(Translations.instance!.trans('usewebsearch')),
            trailing: Switch(
              value: Settings.searchNetwork.value,
              onChanged: (newValue) async {
                await Settings.searchNetwork.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.searchNetwork.setValue(
              !Settings.searchNetwork.value,
            );
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        if (Settings.searchNetwork.value)
          InkWell(
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8.0),
                bottomRight: Radius.circular(8.0),
              ),
            ),
            child: ListTile(
              leading: Icon(
                MdiIcons.searchWeb,
                color: Settings.majorColor.value,
              ),
              title: Text(Translations.instance!.trans('usesearchexpunged')),
              trailing: Switch(
                value: Settings.searchExpunged.value,
                onChanged: (newValue) async {
                  await Settings.searchExpunged.setValue(newValue);
                  setState(() {
                    _shouldReload = true;
                  });
                },
                activeTrackColor: Settings.majorColor.value,
                activeColor: Settings.majorAccentColor.value,
              ),
            ),
            onTap: () async {
              await Settings.searchExpunged.setValue(
                !Settings.searchExpunged.value,
              );
              setState(() {
                _shouldReload = true;
              });
            },
          ),
        if (Settings.searchNetwork.value)
          InkWell(
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8.0),
                bottomRight: Radius.circular(8.0),
              ),
            ),
            child: ListTile(
              leading: Icon(
                MdiIcons.searchWeb,
                color: Settings.majorColor.value,
              ),
              title: Text(Translations.instance!.trans('includetagnetwork')),
              trailing: Switch(
                value: Settings.includeTagNetwork.value,
                onChanged: (newValue) async {
                  await Settings.includeTagNetwork.setValue(newValue);
                  setState(() {
                    _shouldReload = true;
                  });
                },
                activeTrackColor: Settings.majorColor.value,
                activeColor: Settings.majorAccentColor.value,
              ),
            ),
            onTap: () async {
              await Settings.includeTagNetwork.setValue(
                !Settings.includeTagNetwork.value,
              );
              setState(() {
                _shouldReload = true;
              });
            },
          ),
        if (Settings.searchNetwork.value)
          InkWell(
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8.0),
                bottomRight: Radius.circular(8.0),
              ),
            ),
            child: ListTile(
              leading: Icon(
                MdiIcons.searchWeb,
                color: Settings.majorColor.value,
              ),
              title: Text(Translations.instance!.trans('excludetagnetwork')),
              trailing: Switch(
                value: Settings.excludeTagNetwork.value,
                onChanged: (newValue) async {
                  await Settings.excludeTagNetwork.setValue(newValue);
                  setState(() {
                    _shouldReload = true;
                  });
                },
                activeTrackColor: Settings.majorColor.value,
                activeColor: Settings.majorAccentColor.value,
              ),
            ),
            onTap: () async {
              await Settings.excludeTagNetwork.setValue(
                !Settings.excludeTagNetwork.value,
              );
              setState(() {
                _shouldReload = true;
              });
            },
          ),
        if (Settings.searchNetwork.value)
          InkWell(
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
            ),
            child: ListTile(
              leading: CachedNetworkImage(
                imageUrl: 'https://e-hentai.org/favicon.ico',
                width: 25,
              ),
              title: const Text('Search Categories'),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: () async {
              var cats = Settings.searchCategory.value;

              var catsController = TextEditingController(text: '$cats');

              getButton(String name, int cat) {
                return CategoryButton(
                  name: name,
                  controller: catsController,
                  cat: cat,
                );
              }

              final doujinshiButton = getButton('Doujinshi', 1);
              final mangaButton = getButton('Manga', 2);
              final artistcgButton = getButton('Artist CG', 3);
              final gamecgButton = getButton('Game CG', 4);
              final westernButton = getButton('Western', 9);
              final nonhButton = getButton('Non-H', 8);
              final imagesetButton = getButton('Image Set', 5);
              final cosplayButton = getButton('Cosplay', 6);
              final asianpornButton = getButton('Asian Porn', 7);
              final miscButton = getButton('Misc', 0);

              Widget okButton = TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Settings.majorColor.value,
                ),
                child: Text(Translations.instance!.trans('ok')),
                onPressed: () {
                  try {
                    cats = int.parse(catsController.text);
                    Settings.searchCategory.setValue(cats);
                  } catch (e, st) {
                    Logger.error(
                      '[Search Categories] $e\n'
                      '$st',
                    );
                  }
                  Navigator.pop(context);
                },
              );
              Widget cancelButton = TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Settings.majorColor.value,
                ),
                child: Text(Translations.instance!.trans('cancel')),
                onPressed: () {
                  Navigator.pop(context);
                },
              );
              await showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  actions: [okButton, cancelButton],
                  title: const Text('E-Hentai Categories'),
                  contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text('f_cats: '),
                        ...[
                          TextField(controller: catsController, readOnly: true),
                          doujinshiButton,
                          mangaButton,
                          artistcgButton,
                          gamecgButton,
                          westernButton,
                          nonhButton,
                          imagesetButton,
                          cosplayButton,
                          asianpornButton,
                          miscButton,
                        ].map((e) => Row(children: [Expanded(child: e)])),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ]),
    ];
  }

  List<Widget> _systemGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('system')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(Icons.receipt, color: Settings.majorColor.value),
            title: Text(Translations.instance!.trans('logrecord')),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () {
            PlatformNavigator.navigateSlide(context, const LogPage());
          },
        ),
        ListTile(
          leading: Icon(Icons.language, color: Settings.majorColor.value),
          title: Text(Translations.instance!.trans('language')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => Theme(
                data: Theme.of(context).copyWith(primaryColor: Colors.pink),
                child: CountryPickerDialog(
                  titlePadding: const EdgeInsets.symmetric(vertical: 16),
                  // searchCursorColor: Colors.pinkAccent,
                  // searchInputDecoration:
                  //     InputDecoration(hintText: 'Search...'),
                  // isSearchable: true,
                  title: const Text('Select Language'),
                  onValuePicked: (Country country) async {
                    var exc = country as ExCountry;
                    await Translations.instance!.load(exc.toString());
                    await Settings.language.setValue(exc.toString());
                    setState(() {
                      _shouldReload = true;
                    });
                  },
                  itemFilter: (c) => [].contains(c.isoCode),
                  priorityList: [
                    ExCountry.create('US'),
                    ExCountry.create('KR'),
                    ExCountry.create('JP'),
                    ExCountry.create('CN', script: 'Hant'),
                    ExCountry.create('CN', script: 'Hans'),
                    ExCountry.create('IT'),
                    ExCountry.create('ES'),
                    ExCountry.create('BR'),
                    // CountryPickerUtils.getCountryByIsoCode('RU'),
                  ],
                  itemBuilder: (Country country) {
                    return Row(
                      children: <Widget>[
                        CountryPickerUtils.getDefaultFlagImage(country),
                        const SizedBox(width: 8.0, height: 30),
                        Text((country as ExCountry).getDisplayLanguage()),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
        if (Settings.language.value == 'ko')
          ListTile(
            leading: Icon(Icons.translate, color: Settings.majorColor.value),
            title: Text(Translations.instance!.trans('translatetagtokorean')),
            trailing: Switch(
              value: Settings.translateTags.value,
              onChanged: (newValue) async {
                await Settings.translateTags.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
            onTap: () async {
              await Settings.translateTags.setValue(
                !Settings.translateTags.value,
              );
              setState(() {
                _shouldReload = true;
              });
            },
          ),
        ListTile(
          leading: Icon(
            MdiIcons.imageSizeSelectLarge,
            color: Settings.majorColor.value,
          ),
          title: Text(Translations.instance!.trans('lowresmode')),
          trailing: Switch(
            value: Settings.useLowPerf.value,
            onChanged: (newValue) async {
              await Settings.useLowPerf.setValue(newValue);
              setState(() {
                _shouldReload = true;
              });
            },
            activeTrackColor: Settings.majorColor.value,
            activeColor: Settings.majorAccentColor.value,
          ),
          onTap: () async {
            await Settings.useLowPerf.setValue(!Settings.useLowPerf.value);
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        ListTile(
          leading: Icon(Mdi.tableArrowRight, color: Settings.majorColor.value),
          title: Text(Translations.instance!.trans('exportlog')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            final ext = Platform.isIOS
                ? await getApplicationSupportDirectory()
                : await getExternalStorageDirectory();
            final logfile = File('${ext!.path}/log.txt');

            if (Platform.isAndroid) {
              await PlatformMiscMethods.instance.exportFile(
                logfile.path,
                mimeType: 'application/txt',
                fileNameToSaveAs: 'log.txt',
              );
            } else {
              final selectedPath = await FilePicker.platform.getDirectoryPath();

              if (selectedPath == null) {
                return;
              }

              final extpath = '$selectedPath/bookmark.db';

              await logfile.copy(extpath);
            }

            showToast(
              level: ToastLevel.check,
              message: Translations.instance!.trans('complete'),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.info_outline, color: Settings.majorColor.value),
          title: Text(Translations.instance!.trans('info')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            await showDialog(
              context: context,
              builder: (BuildContext context) {
                return const VersionViewPage();
              },
            );
          },
        ),
        ListTile(
          leading: const Icon(MdiIcons.fileSign, color: Colors.cyan),
          title: Text(Translations.instance!.trans('patchnote')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            PlatformNavigator.navigateSlide(context, const PatchNotePage());
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: const Icon(MdiIcons.flask, color: Color(0xFF73BE1E)),
            title: Text(Translations.instance!.trans('lab')),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () async {
            PlatformNavigator.navigateSlide(context, const LaboratoryPage());
          },
        ),
      ]),
    ];
  }

  List<Widget> _securityGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('security')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            // borderRadius: BorderRadius.circular(8.0),
            leading: Icon(Icons.lock_outline, color: Settings.majorColor.value),
            title: Text(Translations.instance!.trans('lockapp')),
            trailing: const Icon(
              // Icons.message,
              Icons.keyboard_arrow_right,
            ),
          ),
          onTap: () async {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => const LockSettingPage()),
            );
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(
              MdiIcons.shieldLockOutline,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('securemode')),
            trailing: Switch(
              value: Settings.useSecureMode.value,
              onChanged: (newValue) async {
                await Settings.useSecureMode.setValue(newValue);
                await Settings.setSecureMode();
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.useSecureMode.setValue(
              !Settings.useSecureMode.value,
            );
            await Settings.setSecureMode();
            setState(() {
              _shouldReload = true;
            });
          },
        ),
      ]),
    ];
  }

  List<Widget> _databaseGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('database')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          onTap: () async {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const SplashPage(switching: true),
              ),
            );
          },
          child: ListTile(
            leading: Icon(
              MdiIcons.swapHorizontal,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('switching')),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
        ),
        InkWell(
          child: ListTile(
            leading: Icon(
              MdiIcons.databaseEdit,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('dbrebuild')),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () async {
            if (await showYesNoDialog(
              context,
              Translations.instance!.trans('dbrebuildmsg'),
              Translations.instance!.trans('dbrebuild'),
            )) {
              await showDialog(
                context: context,
                builder: (BuildContext context) => const DBRebuildPage(),
              );

              showToast(
                level: ToastLevel.check,
                message:
                    '${Translations.instance!.trans('dbrebuild')} ${Translations.instance!.trans('complete')}',
              );
            }
          },
        ),
        InkWell(
          child: ListTile(
            leading: Icon(
              MdiIcons.vectorIntersection,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('dbopt')),
            trailing: Switch(
              value: Settings.useOptimizeDatabase.value,
              onChanged: (newValue) async {
                await Settings.useOptimizeDatabase.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.useOptimizeDatabase.setValue(
              !Settings.useOptimizeDatabase.value,
            );
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            var latestDB = SyncManager.getLatestDB().getDateTime();
            var lastDB = prefs.getString('databasesync');

            if (lastDB != null &&
                latestDB.difference(DateTime.parse(lastDB)).inHours < 1) {
              showToast(
                level: ToastLevel.check,
                message: Translations.instance!.trans('thisislatestbookmark'),
              );
              return;
            }

            var dir = await getApplicationDocumentsDirectory();
            try {
              await ((await openDatabase('${dir.path}/data/data.db')).close());
              await deleteDatabase('${dir.path}/data/data.db');
              if (Platform.isAndroid || Platform.isIOS) {
                if (await Directory('${dir.path}/data').exists()) {
                  await Directory('${dir.path}/data').delete(recursive: true);
                }
              }
            } catch (_) {}

            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (context) => DataBaseDownloadPage(
                      dbType: Settings.databaseType.value,
                      isSync: true,
                    ),
                  ),
                )
                .then((value) async {
                  HentaiIndex.init();
                  final directory = await getApplicationDocumentsDirectory();
                  final path = File('${directory.path}/data/index.json');
                  final text = path.readAsStringSync();
                  HentaiIndex.tagCount = jsonDecode(text);
                  await DataBaseManager.reloadInstance();

                  showToast(
                    level: ToastLevel.check,
                    message: Translations.instance!.trans('synccomplete'),
                  );
                });
          },
          child: ListTile(
            leading: Icon(
              MdiIcons.databaseSync,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('syncmanual')),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
        ),
      ]),
    ];
  }

  List<Widget> _networkingGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('network')),
      _buildItems([
        // InkWell(
        //   customBorder: const RoundedRectangleBorder(
        //       borderRadius: BorderRadius.only(
        //           topLeft: Radius.circular(8.0),
        //           topRight: Radius.circular(8.0))),
        //   child: ListTile(
        //     leading: Icon(MdiIcons.vpn, color: Settings.majorColor.value),
        //     title: const Text('VPN'),
        //     trailing: const Icon(Icons.keyboard_arrow_right),
        //   ),
        //   onTap: () {},
        // ),
        //
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(Icons.router, color: Settings.majorColor.value),
            title: Text(Translations.instance!.trans('routing_rule')),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (BuildContext context) => const RouteDialog(),
              );
            },
          ),
          onTap: () async {
            await showDialog(
              context: context,
              builder: (BuildContext context) => const RouteDialog(),
            );
          },
        ),

        ListTile(
          leading: Icon(Icons.router, color: Settings.majorColor.value),
          title: Text('Image ${Translations.instance!.trans('routing_rule')}'),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            await showDialog(
              context: context,
              builder: (BuildContext context) => const ImageRouteDialog(),
            );
          },
        ),

        ListTile(
          leading: Icon(
            MdiIcons.commentSearch,
            color: Settings.majorColor.value,
          ),
          title: Text(Translations.instance!.trans('messagesearchapi')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            TextEditingController text = TextEditingController(
              text: Settings.searchMessageAPI.value,
            );
            Widget okButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              child: Text(Translations.instance!.trans('ok')),
              onPressed: () {
                Navigator.pop(context, true);
              },
            );
            Widget cancelButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              child: Text(Translations.instance!.trans('cancel')),
              onPressed: () {
                Navigator.pop(context, false);
              },
            );
            Widget defaultButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              child: Text(Translations.instance!.trans('default')),
              onPressed: () {
                _shouldReload = true;
                setState(() => text.text = 'https://koromo.cc/api/search/msg');
              },
            );
            var dialog = await showDialog(
              useRootNavigator: false,
              context: context,
              builder: (BuildContext context) => AlertDialog(
                contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                title: const Text('대사 검색기 API'),
                content: TextField(
                  controller: text,
                  autofocus: true,
                  maxLines: 3,
                ),
                actions: [defaultButton, okButton, cancelButton],
              ),
            );
            if (dialog != null && dialog == true) {
              await Settings.searchMessageAPI.setValue(text.text);
            }
          },
        ),
        ListTile(
          leading: Icon(MdiIcons.timerOff, color: Settings.majorColor.value),
          title: Text(Translations.instance!.trans('ignoretimeout')),
          trailing: Switch(
            value: Settings.ignoreTimeout.value,
            onChanged: (newValue) async {
              await Settings.ignoreTimeout.setValue(newValue);
              setState(() {
                _shouldReload = true;
              });
            },
            activeTrackColor: Settings.majorColor.value,
            activeColor: Settings.majorAccentColor.value,
          ),
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Image.asset(
              'assets/images/logo.png',
              width: 25,
              height: 25,
            ),
            title: Text(Translations.instance!.trans('usevioletserver')),
            trailing: Switch(
              value: Settings.useVioletServer.value,
              onChanged: (newValue) async {
                await Settings.useVioletServer.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.useVioletServer.setValue(
              !Settings.useVioletServer.value,
            );
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(MdiIcons.server, color: Settings.majorColor.value),
            title: Text(Translations.instance!.trans('usechunksync')),
            trailing: Switch(
              value: Settings.useChunkSync.value,
              onChanged: (newValue) async {
                await Settings.useChunkSync.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.useChunkSync.setValue(!Settings.useChunkSync.value);
            setState(() {
              _shouldReload = true;
            });
          },
        ),
      ]),
    ];
  }

  List<Widget> _downloadGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('download')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          onTap: Platform.isIOS
              ? null
              : () async {
                  await Settings.useInnerStorage.setValue(
                    !Settings.useInnerStorage.value,
                  );
                  setState(() {
                    _shouldReload = true;
                  });
                },
          child: ListTile(
            leading: Icon(
              MdiIcons.downloadLock,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('useinnerstorage')),
            trailing: Switch(
              value: Settings.useInnerStorage.value,
              onChanged: Platform.isIOS
                  ? null
                  : (newValue) async {
                      await Settings.useInnerStorage.setValue(newValue);
                      setState(() {
                        _shouldReload = true;
                      });
                    },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
        ),
        ListTile(
          leading: Icon(MdiIcons.lan, color: Settings.majorColor.value),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Translations.instance!.trans('threadcount')),
              FutureBuilder(
                builder: (context, AsyncSnapshot<SharedPreferences> snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      '${Translations.instance!.trans('curthread')}: ',
                      overflow: TextOverflow.ellipsis,
                    );
                  }
                  return Text(
                    '${Translations.instance!.trans('curthread')}: ${snapshot.data!.getInt('thread_count')}',
                    overflow: TextOverflow.ellipsis,
                  );
                },
                future: SharedPreferences.getInstance(),
              ),
            ],
          ),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            // 32개 => 50mb/s
            var tc = prefs.getInt('thread_count');

            TextEditingController text = TextEditingController(
              text: tc.toString(),
            );
            Widget yesButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              onPressed: () async {
                if (int.tryParse(text.text) == null) {
                  await showOkDialog(
                    context,
                    Translations.instance!.trans('putonlynum'),
                  );
                  return;
                }
                if (int.parse(text.text) > 128) {
                  await showOkDialog(
                    context,
                    Translations.instance!.trans('toomuch'),
                  );
                  return;
                }
                if (int.parse(text.text) == 0) {
                  await showOkDialog(
                    context,
                    Translations.instance!.trans('threadzero'),
                  );
                  return;
                }

                Navigator.pop(context, true);
              },
              child: Text(
                Translations.instance!.trans('change'),
                style: TextStyle(color: Settings.majorColor.value),
              ),
            );
            Widget noButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text(
                Translations.instance!.trans('cancel'),
                style: TextStyle(color: Settings.majorColor.value),
              ),
            );
            var dialog = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                title: Text(Translations.instance!.trans('setthread')),
                content: TextField(
                  controller: text,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                actions: [yesButton, noButton],
              ),
            );
            if (dialog == true) {
              (await IsolateDownloader.getInstance()).changeThreadCount(
                int.parse(text.text),
              );

              await prefs.setInt('thread_count', int.parse(text.text));

              showToast(
                level: ToastLevel.check,
                message: Translations.instance!.trans('changedthread'),
              );

              setState(() {});
            }
          },
        ),
        InkWell(
          // customBorder: RoundedRectangleBorder(
          //   borderRadius: BorderRadius.all(
          //     Radius.circular(8.0),
          //   ),
          onTap: Settings.useInnerStorage.value
              ? null
              : () async {
                  TextEditingController text = TextEditingController(
                    text: Settings.downloadBasePath.value,
                  );
                  Widget yesButton = TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Settings.majorColor.value,
                    ),
                    child: Text(Translations.instance!.trans('ok')),
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                  );
                  Widget noButton = TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Settings.majorColor.value,
                    ),
                    child: Text(Translations.instance!.trans('cancel')),
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                  );
                  Widget defaultButton = TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Settings.majorColor.value,
                    ),
                    child: Text(Translations.instance!.trans('default')),
                    onPressed: () {
                      _shouldReload = true;
                      Settings.getDefaultDownloadPath().then(
                        (value) => setState(() => text.text = value),
                      );
                    },
                  );
                  var dialog = await showDialog(
                    useRootNavigator: false,
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      title: Text(Translations.instance!.trans('downloadpath')),
                      content: TextField(
                        controller: text,
                        autofocus: true,
                        maxLines: 3,
                      ),
                      actions: [defaultButton, yesButton, noButton],
                    ),
                  );
                  if (dialog != null && dialog == true) {
                    try {
                      if (Platform.isAndroid &&
                          await Permission.manageExternalStorage.isGranted) {
                        var prevDir = Directory(
                          Settings.downloadBasePath.value,
                        );
                        if (await prevDir.exists()) {
                          await prevDir.rename(text.text);
                        }
                      }
                    } catch (_) {}

                    await Settings.downloadBasePath.setValue(text.text);
                  }
                },
          child: ListTile(
            leading: Icon(
              MdiIcons.folderDownload,
              color: Settings.majorColor.value,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Translations.instance!.trans('downloadpath')),
                Text(
                  '${Translations.instance!.trans('curdownloadpath')}: ${Settings.downloadBasePath.value}',
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          //   customBorder: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.all(
          //       Radius.circular(8.0),
          //     ),
          //   ),
          child: ListTile(
            leading: Icon(
              MdiIcons.folderTable,
              color: Settings.majorColor.value,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Translations.instance!.trans('downloadrule')),
                Text(
                  '${Translations.instance!.trans('curdownloadrule')}: ${Settings.downloadRule.value}',
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () async {
            TextEditingController text = TextEditingController(
              text: Settings.downloadRule.value,
            );
            Widget okButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              child: Text(Translations.instance!.trans('ok')),
              onPressed: () {
                Navigator.pop(context, true);
              },
            );
            Widget cancelButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              child: Text(Translations.instance!.trans('cancel')),
              onPressed: () {
                Navigator.pop(context, false);
              },
            );
            Widget defaultButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              child: Text(Translations.instance!.trans('default')),
              onPressed: () {
                _shouldReload = true;
                setState(
                  () => text.text = '%(extractor)s/%(id)s/%(file)s.%(ext)s',
                );
              },
            );
            // Widget manual = TextButton(onPressed: onPressed, child: child)
            // TODO: Check download rule is accurately
            var dialog = await showDialog(
              useRootNavigator: false,
              context: context,
              builder: (BuildContext context) => AlertDialog(
                contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                title: Text(Translations.instance!.trans('downloadrule')),
                content: TextField(
                  controller: text,
                  autofocus: true,
                  maxLines: 3,
                ),
                actions: [defaultButton, okButton, cancelButton],
              ),
            );
            if (dialog != null && dialog == true) {
              await Settings.downloadRule.setValue(text.text);
            }
          },
        ),
      ]),
    ];
  }

  List<Widget> _bookmarkGroup() {
    /*
    Future<void> toggleAutoBackupBookmark() async {
      await Settings.setAutoBackupBookmark(!Settings.autobackupBookmark.value);
      setState(() {
        _shouldReload = true;
      });
    }

    Future<void> setAutoBackupBookmark(bool newValue) async {
      await Settings.setAutoBackupBookmark(newValue);
      setState(() {
        _shouldReload = true;
      });
    }
     */

    return [
      SettingGroupName(name: Translations.instance!.trans('bookmark')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          // onTap: toggleAutoBackupBookmark,
          onTap: null,
          child: ListTile(
            leading: Icon(
              MdiIcons.bookArrowUpOutline,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('autobackupbookmark')),
            trailing: Switch(
              value: Settings.autobackupBookmark.value,
              // onChanged: setAutoBackupBookmark,
              onChanged: null,
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
        ),
        ListTile(
          leading: Icon(
            MdiIcons.bookArrowDownOutline,
            color: Settings.majorColor.value,
          ),
          title: Text(Translations.instance!.trans('restoringbookmark')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            await showOkDialog(
              context,
              Translations.instance!.trans('restorebookmarkmsg'),
              Translations.instance!.trans('warning'),
            );

            final prefs = await SharedPreferences.getInstance();
            var myappid = prefs.getString('fa_userid');

            // 1. 북마크 유저 아이디 선택
            TextEditingController text = TextEditingController(text: myappid);
            Widget okButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              child: Text(Translations.instance!.trans('ok')),
              onPressed: () {
                Navigator.pop(context, true);
              },
            );
            Widget cancelButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              child: Text(Translations.instance!.trans('cancel')),
              onPressed: () {
                Navigator.pop(context, false);
              },
            );
            var dialog = await showDialog(
              useRootNavigator: false,
              context: context,
              builder: (BuildContext context) => AlertDialog(
                contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                title: const Text('Enter User App Id'),
                content: TextField(
                  controller: text,
                  autofocus: true,
                  maxLines: 3,
                ),
                actions: [okButton, cancelButton],
              ),
            );
            if (dialog == null || dialog == false) {
              // await Settings.setDownloadRule(text.text);
              return;
            }

            try {
              // 2. 유효한 유저 아이디 인지 확인(서버 요청 및 다운로드)
              var result = await VioletServer.restoreBookmark(text.text);
              if (result == null) {
                await showOkDialog(
                  context,
                  "Invalid User-App-Id! If you're still getting this error, contact the developer.",
                  Translations.instance!.trans('restoringbookmark'),
                );
                return;
              }

              // 3. 북마크 버전 가져오기
              var versions = await VioletServer.versionsBookmark(text.text);
              if (versions == null) {
                await showOkDialog(
                  context,
                  '북마크 버전 정보를 가져오는데 오류가 발생했습니다. UserAppId와 함께 개발자에게 문의하시기 바랍니다.',
                  Translations.instance!.trans('restoringbookmark'),
                );
                return;
              }

              // 4. 버전 선택 및 북마크 확인 (이 북마크를 복원할까요?)
              var version = await PlatformNavigator.navigateSlide(
                context,
                BookmarkVersionSelectPage(
                  userAppId: text.text,
                  versions: versions,
                ),
              );

              if (version == null) {
                return;
              }

              // 5. 열람기록도 같이 복원할까요?
              var restoreWithRecord = await showYesNoDialog(
                context,
                '열람기록도 같이 복원할까요?',
              );

              // 6. 북마크 다운로드
              var bookmark = await VioletServer.resotreBookmarkWithVersion(
                text.text,
                version,
              );

              // 7. 덮어쓰기 한다.
              var rr = await showDialog(
                context: context,
                builder: (BuildContext context) => RestoreBookmarkPage(
                  source: bookmark,
                  restoreWithRecord: restoreWithRecord,
                ),
              );

              if (rr != null && rr == false) {
                return;
              }
            } catch (e, st) {
              Logger.error(
                '[Restore Bookmark] $e\n'
                '$st',
              );
              showToast(
                level: ToastLevel.error,
                message: 'Bookmark Restoring Error!',
              );
              return;
            }

            await Bookmark.getInstance();

            showToast(
              level: ToastLevel.check,
              message: Translations.instance!.trans('importbookmark'),
            );
          },
        ),
        ListTile(
          leading: Icon(MdiIcons.import, color: Settings.majorColor.value),
          title: Text(Translations.instance!.trans('importingbookmark')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            try {
              await FilePicker.platform.clearTemporaryFiles();
              final filePickerResult = await FilePicker.platform.pickFiles();
              final pickedFilePath = filePickerResult?.files.singleOrNull?.path;

              if (pickedFilePath == null) {
                showToast(
                  level: ToastLevel.error,
                  message: Translations.instance!.trans('noselectedb'),
                );

                return;
              }

              final pickedFile = File(pickedFilePath);
              final db = (await getApplicationDocumentsDirectory());

              await pickedFile.copy('${db.path}/user.db');

              await Bookmark.getInstance();

              showToast(
                level: ToastLevel.check,
                message: Translations.instance!.trans('importbookmark'),
              );
            } catch (e, st) {
              Logger.error(
                '[Import Bookmark] $e\n'
                '$st',
              );
              showToast(
                level: ToastLevel.error,
                message: Translations.instance!.trans('failimportbookmark'),
              );
            }
          },
        ),
        ListTile(
          leading: Icon(MdiIcons.export, color: Settings.majorColor.value),
          title: Text(Translations.instance!.trans('exportingbookmark')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            try {
              final dir = (await getApplicationDocumentsDirectory());
              final bookmarkDatabaseFile = File('${dir.path}/user.db');

              if (Platform.isAndroid) {
                await PlatformMiscMethods.instance.exportFile(
                  bookmarkDatabaseFile.path,
                  mimeType: 'application/vnd.sqlite3',
                  fileNameToSaveAs: 'violet-bookmarks.db',
                );
              } else if (Platform.isIOS) {
                final bytes = await bookmarkDatabaseFile.readAsBytes();

                await FlutterFileDialog.saveFile(
                  params: SaveFileDialogParams(
                    data: bytes,
                    fileName: 'bookmark.db',
                  ),
                );
              } else {
                final selectedPath = await FilePicker.platform
                    .getDirectoryPath();

                if (selectedPath == null) {
                  return;
                }

                final extpath = '$selectedPath/bookmark.db';

                await bookmarkDatabaseFile.copy(extpath);
              }

              showToast(
                level: ToastLevel.check,
                message: Translations.instance!.trans('exportbookmark'),
              );
            } catch (e, st) {
              Logger.error(
                '[Export Bookmark] $e\n'
                '$st',
              );
              showToast(
                level: ToastLevel.error,
                message: Translations.instance!.trans('failexportbookmark'),
              );
            }
          },
        ),
        InkWell(
          child: ListTile(
            leading: Icon(
              MdiIcons.cloudSearchOutline,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('importfromeh')),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            var ehc = prefs.getString('eh_cookies');

            if (ehc == null || ehc == '') {
              showToast(
                level: ToastLevel.error,
                message: Translations.instance!.trans('setcookiefirst'),
              );
              return;
            }

            await showDialog(
              context: context,
              builder: (BuildContext context) => const ImportFromEHPage(),
            );

            if (EHBookmark.bookmarkInfo == null) {
              showToast(
                level: ToastLevel.warning,
                message: Translations.instance!.trans('bookmarkisempty'),
              );
              return;
            }

            int count = 0;
            for (var element in EHBookmark.bookmarkInfo!) {
              count += element.length;
            }

            var qqq = await showYesNoDialog(
              context,
              Translations.instance!
                  .trans('ensurecreatebookmark')
                  .replaceAll('\$1', count.toString()),
            );
            if (qqq) {
              var bookmark = await Bookmark.getInstance();
              for (int i = 0; i < EHBookmark.bookmarkInfo!.length; i++) {
                if (EHBookmark.bookmarkInfo![i].isEmpty) continue;
                await bookmark.createGroup('Favorite $i', '', Colors.black);
                var group = (await bookmark.getGroup())
                    .where((element) => element.name() == 'Favorite $i')
                    .last
                    .id();
                for (int j = 0; j < EHBookmark.bookmarkInfo![i].length; j++) {
                  await bookmark.insertArticle(
                    EHBookmark.bookmarkInfo![i].elementAt(j).toString(),
                    DateTime.now(),
                    group,
                  );
                }
              }

              showToast(
                level: ToastLevel.check,
                message: Translations.instance!.trans('completeimportbookmark'),
              );
            }
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(
              MdiIcons.cloudSearchOutline,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('importfromjson')),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () async {
            TextEditingController textController = TextEditingController();

            Widget importButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              child: const Text('Import'),
              onPressed: () async {
                Navigator.pop(context, textController.text);
              },
            );
            Widget cancelButton = TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Settings.majorColor.value,
              ),
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context, null);
              },
            );

            final text = await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(Translations.instance!.trans('importfromjson')),
                  contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  actions: [importButton, cancelButton],
                  content: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    reverse: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          Translations.instance!.trans('pasteyourbookmarktext'),
                        ),
                        Row(
                          children: [
                            const Text('JSON: '),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText:
                                      'ex: ["1207894", "artist:michiking", ...]',
                                ),
                                controller: textController,
                                keyboardType: TextInputType.multiline,
                                minLines: null,
                                maxLines: null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

            if (text == null) return;

            try {
              var json = jsonDecode(text) as List<dynamic>;
              var groupName = 'Imported at ${DateTime.now().toLocal()}';
              var bookmark = await Bookmark.getInstance();
              await bookmark.createGroup(groupName, '', Colors.black);
              var group = (await bookmark.getGroup())
                  .where((element) => element.name() == groupName)
                  .first
                  .id();
              for (int j = 0; j < json.length; j++) {
                var tar = json.elementAt(j).toString();
                if (int.tryParse(tar) != null) {
                  await bookmark.insertArticle(tar, DateTime.now(), group);
                } else if (tar.contains(':') &&
                    ['artist', 'group'].contains(tar.split(':')[0])) {
                  await bookmark.bookmarkArtist(
                    tar.split(':')[1],
                    tar.split(':')[0] == 'artist'
                        ? ArtistType.artist
                        : ArtistType.group,
                    group,
                  );
                }
              }

              await showOkDialog(context, 'Success!');
            } catch (e, st) {
              Logger.error(
                '[Import from hiyobi] $e\n'
                '$st',
              );

              await showOkDialog(
                context,
                'Bookmark format is not correct. Please refer to Log Record for details.',
              );
            }
          },
        ),
      ]),
    ];
  }

  List<Widget> _componetGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('component')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
          child: ListTile(
            leading: CachedNetworkImage(
              imageUrl: 'https://e-hentai.org/favicon.ico',
              width: 25,
            ),
            title: const Text('E-Hentai/ExHentai'),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () async {
            var useExHentai = true;
            var dialog = await showDialog(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('E-Hentai Login'),
                contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Settings.majorColor.value,
                      ),
                      child: const Text('Login From WebPage'),
                      onPressed: () => Navigator.pop(context, 1),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Settings.majorColor.value,
                      ),
                      child: const Text('Enter Cookie Information'),
                      onPressed: () => Navigator.pop(context, 2),
                    ),
                  ],
                ),
              ),
            );

            if (dialog == null) return;

            final prefs = await SharedPreferences.getInstance();
            if (dialog == 1) {
              var cookie = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );

              if (cookie != null) {
                await catchUnwind(() async {
                  final res = await http.get(
                    'https://exhentai.org',
                    headers: {'Cookie': cookie},
                  );

                  // sk=...; expires=Sun, 29-Dec-2024 07:02:58 GMT; Max-Age=31536000; path=/; domain=.exhentai.org
                  final setCookie = res.headers['set-cookie'];
                  if (setCookie != null && setCookie.startsWith('sk=')) {
                    cookie += ';${setCookie.split(';')[0]}';
                  }
                });

                await prefs.setString('eh_cookies', cookie);
              }

              if (cookie != null) {
                showToast(level: ToastLevel.check, message: 'Login Success!');
              }
            } else if (dialog == 2) {
              var cookie = prefs.getString('eh_cookies');

              var sController = TextEditingController(
                text: cookie != null ? parseCookies(cookie)['sk'] : '',
              );
              var imiController = TextEditingController(
                text: cookie != null
                    ? parseCookies(cookie)['ipb_member_id']
                    : '',
              );
              var iphController = TextEditingController(
                text: cookie != null
                    ? parseCookies(cookie)['ipb_pass_hash']
                    : '',
              );
              var iController = TextEditingController(
                text: cookie != null ? parseCookies(cookie)['igneous'] : '',
              );
              Widget okButton = TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Settings.majorColor.value,
                ),
                child: Text(Translations.instance!.trans('ok')),
                onPressed: () {
                  Navigator.pop(context, true);
                },
              );
              Widget cancelButton = TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Settings.majorColor.value,
                ),
                child: Text(Translations.instance!.trans('cancel')),
                onPressed: () {
                  Navigator.pop(context, false);
                },
              );
              var dialog = await showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  actions: [okButton, cancelButton],
                  title: const Text('E-Hentai Login'),
                  contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: [
                          const Text('sk: '),
                          Expanded(child: TextField(controller: sController)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('ipb_member_id: '),
                          Expanded(child: TextField(controller: imiController)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('ipb_pass_hash: '),
                          Expanded(child: TextField(controller: iphController)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('igneous: '),
                          Expanded(child: TextField(controller: iController)),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              if (dialog != null && dialog == true) {
                final cookie =
                    'sk=${sController.text};ipb_member_id=${imiController.text};ipb_pass_hash=${iphController.text};igneous=${iController.text}';
                await prefs.setString('eh_cookies', cookie);
              }
            }
            final cookie = prefs.getString('eh_cookies') ?? '';
            final res = await http.get(
              'https://exhentai.org',
              headers: {'Cookie': cookie},
            );

            res.body.trim().isEmpty || useExHentai == false
                ? useExHentai = false
                : useExHentai = true;
            (res.headers['set-cookie'] ?? '').split(';')[0] ==
                        'igneous=mystery' ||
                    useExHentai == false
                ? useExHentai = false
                : useExHentai = true;

            final parsedCookie = parseCookies(cookie);
            if (parsedCookie['igneous'] == null ||
                parsedCookie['igneous'] == 'mystery' ||
                useExHentai == false) {
              useExHentai = false;
            } else {
              useExHentai = true;
            }
            if (useExHentai) {
              Settings.searchRule = 'Hitomi|ExHentai|EHentai|NHentai'.split(
                '|',
              );
              await prefs.setString(
                'searchrule',
                'Hitomi|ExHentai|EHentai|NHentai',
              );
            } else {
              Settings.searchRule = 'Hitomi|EHentai|ExHentai|NHentai'.split(
                '|',
              );
              await prefs.setString(
                'searchrule',
                'Hitomi|EHentai|ExHentai|NHentai',
              );
            }
          },
        ),
      ]),
    ];
  }

  List<Widget> _viewGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('view')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
          child: ListTile(
            leading: Icon(
              MdiIcons.progressClock,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('showarticleprogress')),
            trailing: Switch(
              value: Settings.showArticleProgress.value,
              onChanged: (newValue) async {
                await Settings.showArticleProgress.setValue(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor.value,
              activeColor: Settings.majorAccentColor.value,
            ),
          ),
          onTap: () async {
            await Settings.showArticleProgress.setValue(
              !Settings.showArticleProgress.value,
            );
            setState(() {
              _shouldReload = true;
            });
          },
        ),
      ]),
    ];
  }

  List<Widget> _updateGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('update')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            // borderRadius: BorderRadius.circular(8.0),
            leading: Icon(Icons.update, color: Settings.majorColor.value),
            title: Text(Translations.instance!.trans('checkupdate')),
            trailing: const Icon(
              // Icons.message,
              Icons.keyboard_arrow_right,
            ),
          ),
          onTap: () async {
            await UpdateSyncManager.checkUpdateSync();

            if (UpdateSyncManager.updateRequire) {
              showToast(
                level: ToastLevel.check,
                message: Translations.instance!.trans('newupdate'),
              );
            } else {
              showToast(
                level: ToastLevel.check,
                message: Translations.instance!.trans('latestver'),
              );
            }
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(
              MdiIcons.cellphoneArrowDown,
              color: Settings.majorColor.value,
            ),
            title: Text(Translations.instance!.trans('manualupdate')),
            trailing: const Icon(
              // Icons.message,
              Icons.keyboard_arrow_right,
            ),
          ),
          onTap: () async {
            await UpdateSyncManager.checkUpdateSync();

            if (!UpdateSyncManager.updateRequire) {
              showToast(
                level: ToastLevel.check,
                message: Translations.instance!.trans('latestver'),
              );
              return;
            }

            if (Platform.isIOS) {
              showToast(
                level: ToastLevel.warning,
                message: Translations.instance!.trans('cannotuseios'),
              );
              return;
            }

            final url = Uri.parse(
              'https://github.com/TaYaKi71751/violet/releases/latest',
            );
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
        ),
      ]),
    ];
  }

  List<Widget> _etcGroup() {
    return [
      SettingGroupName(name: Translations.instance!.trans('etc')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8.0),
              topRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: const Icon(MdiIcons.discord, color: Color(0xFF7189da)),
            title: Text(Translations.instance!.trans('discord')),
            trailing: const Icon(Icons.open_in_new),
          ),
          onTap: () async {
            final url = Uri.parse('https://discord.gg/K8qny6E');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
        ),
        ListTile(
          leading: const Icon(MdiIcons.github, color: Colors.black),
          title: Text('GitHub ${Translations.instance!.trans('project')}'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () async {
            final url = Uri.parse('https://github.com/TaYaKi71751/violet');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
        ),
        ListTile(
          leading: const Icon(MdiIcons.gmail, color: Colors.redAccent),
          title: Text(Translations.instance!.trans('contact')),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            final url = Uri(
              scheme: 'mailto',
              path: 'violet.dev.master@gmail.com',
              queryParameters: {'subject': '[App Issue] '},
            );
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
        ),
        ListTile(
          leading: const Icon(MdiIcons.heart, color: Colors.orange),
          title: Text(Translations.instance!.trans('donate')),
          trailing: const Icon(
            // Icons.email,
            Icons.open_in_new,
          ),
          onTap: () async {
            final url = Uri.parse('https://www.patreon.com/projectviolet');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
        ),
        ListTile(
          leading: Icon(
            MdiIcons.humanHandsup,
            color: Settings.majorColor.value,
          ),
          title: const Text('Developers'),
          trailing: const Icon(
            // Icons.email,
            Icons.keyboard_arrow_right,
          ),
          onTap: () async {
            // final url = Uri.parse('https://www.patreon.com/projectviolet');
            // if (await canLaunchUrl(url)) {
            //   await launchUrl(url);
            // }
          },
        ),
        InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8.0),
              bottomRight: Radius.circular(8.0),
            ),
          ),
          child: ListTile(
            leading: Icon(MdiIcons.library, color: Settings.majorColor.value),
            title: Text(Translations.instance!.trans('license')),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => const VioletLicensePage(),
              ),
            );
          },
        ),
      ]),
    ];
  }

  _bottomInfo() {
    return Container(
      margin: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: <Widget>[
            // Card(
            //   elevation: 5,
            //   shape: RoundedRectangleBorder(
            //     borderRadius: BorderRadius.circular(8.0),
            //   ),
            //   child:
            InkWell(
              child: Image.asset(
                'assets/images/logo.png',
                width: 100,
                height: 100,
              ),
              //onTap: () {},
            ),
            // ),
            const Padding(padding: EdgeInsets.only(top: 12)),
            Text(
              'Project Violet',
              style: TextStyle(
                color: Settings.themeWhat.value ? Colors.white : Colors.black87,
                fontSize: 16.0,
                fontFamily: 'Calibre-Semibold',
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'Copyright (C) 2020-2024 by project-violet',
              style: TextStyle(
                color: Settings.themeWhat.value ? Colors.white : Colors.black87,
                fontSize: 12.0,
                fontFamily: 'Calibre-Semibold',
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingGroupDivider extends StatelessWidget {
  const SettingGroupDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      width: double.infinity,
      height: 1.0,
      color: Settings.themeWhat.value
          ? Colors.grey.shade600
          : Colors.grey.shade400,
    );
  }
}

class SettingGroupName extends StatelessWidget {
  final String name;

  const SettingGroupName({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            name,
            style: TextStyle(
              color: Settings.themeWhat.value ? Colors.white : Colors.black87,
              fontSize: 24.0,
              fontFamily: 'Calibre-Semibold',
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryButton extends StatefulWidget {
  final String name;
  final TextEditingController controller;
  final int cat;

  const CategoryButton({
    super.key,
    required this.name,
    required this.controller,
    required this.cat,
  });

  @override
  State<CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<CategoryButton> {
  bool stat = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: ListTile(
        leading: Icon(Mdi.compassOutline, color: Settings.majorColor.value),
        title: Text(widget.name),
        trailing: Switch(
          value: (stat =
              (int.parse(widget.controller.text) & (1 << widget.cat)) == 0),
          onChanged: (newValue) async {
            widget.controller.text =
                ((int.parse(widget.controller.text) ^ (1 << widget.cat))
                    .toString());
            final newStat =
                int.parse(widget.controller.text) & (1 << widget.cat) == 0;
            setState(() {
              stat = newStat;
            });
          },
          activeTrackColor: Settings.majorColor.value,
          activeColor: Settings.majorAccentColor.value,
        ),
      ),
      onTap: () async {
        widget.controller.text =
            ((int.parse(widget.controller.text) ^ (1 << widget.cat))
                .toString());
        final newStat =
            int.parse(widget.controller.text) & (1 << widget.cat) == 0;
        setState(() {
          stat = newStat;
        });
      },
    );
  }
}
