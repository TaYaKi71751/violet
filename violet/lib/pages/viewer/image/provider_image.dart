// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/network/cache.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/settings/settings_wrapper.dart';
import 'package:violet/pages/viewer/image/image_crop_bookmark.dart';

typedef VImageWidgetBuilder =
    Widget Function(BuildContext context, Widget child);

typedef VProgressIndicatorBuilder =
    Widget Function(
      BuildContext context,
      String url,
      DownloadProgress progress,
    );

typedef VLoadingErrorWidgetBuilder =
    Widget Function(BuildContext context, String url, dynamic error);

class ProviderImage extends StatefulWidget {
  final String getxId;
  final GlobalKey imgKey;
  final String imgUrl;
  final Map<String, String>? imgHeader;
  final VImageWidgetBuilder imageWidgetBuilder;
  final int index;

  const ProviderImage({
    super.key,
    required this.getxId,
    required this.imgKey,
    required this.imgUrl,
    required this.imgHeader,
    required this.imageWidgetBuilder,
    required this.index,
  });

  @override
  State<ProviderImage> createState() => _ProviderImageState();
}

class _ProviderImageState extends State<ProviderImage> {
  late final ViewerController c;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    c = Get.find(tag: widget.getxId);
  }

  @override
  void dispose() {
    CachedNetworkImage.evictFromCache(
      widget.imgUrl,
      cacheManager: WrapperCacheManager(),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      key: widget.imgKey,
      imageUrl: widget.imgUrl,
      httpHeaders: widget.imgHeader,
      cacheManager: WrapperCacheManager(),
      fit: BoxFit.cover,
      filterQuality: SettingsWrapper.imageQuality,
      memCacheHeight: Settings.useLowPerf.value
          ? (MediaQuery.of(context).size.width * 2.0).toInt()
          : null,
      imageBuilder: (context, imageProvider) {
        if (!_loaded) {
          _loaded = true;
          c.isImageLoaded[widget.index] = true;
        }
        return widget.imageWidgetBuilder(
          context,
          Image(
            key: widget.imgKey,
            image: imageProvider,
            fit: BoxFit.cover,
            filterQuality: SettingsWrapper.imageQuality,
          ),
        );
      },
      progressIndicatorBuilder: (context, url, progress) {
        return SizedBox(
          height: c.estimatedImgHeight[widget.index] != 0
              ? c.estimatedImgHeight[widget.index]
              : 300,
          child: Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                value: progress.totalSize == null
                    ? null
                    : progress.downloaded / progress.totalSize!,
              ),
            ),
          ),
        );
      },
      errorWidget: (context, url, error) {
        Logger.error('[viewer-provider_image] URL: $url\nE: $error');

        final iconButton = IconButton(
          icon: Icon(Icons.refresh, color: Settings.majorColor.value),
          onPressed: () => setState(() {
            CachedNetworkImage.evictFromCache(
              widget.imgUrl,
              cacheManager: WrapperCacheManager(),
            );
            c.imgKeys[widget.index] = GlobalKey();
          }),
        );

        return SizedBox(
          height: c.estimatedImgHeight[widget.index] != 0
              ? c.estimatedImgHeight[widget.index]
              : 300,
          child: Center(
            child: SizedBox(width: 50, height: 50, child: iconButton),
          ),
        );
      },
    );

    return GestureDetector(
      child: image,
      onLongPress: () {
        PlatformNavigator.navigateSlide(
          context,
          ImageCropBookmark(
            url: widget.imgUrl,
            headers: widget.imgHeader,
            articleId: c.articleId,
            page: widget.index,
            isNetworkImage: true,
          ),
        );
      },
    );
  }
}
