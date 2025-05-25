// This source code is a part of Project Violet.
// Copyright (C) 2020-2025. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_crop/image_crop.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/pages/common/toast.dart';

class ImageCropBookmark extends StatelessWidget {
  final GlobalKey<CropState> cropKey = GlobalKey<CropState>();
  final String url;
  final Map<String, String>? headers;
  final int articleId;
  final int page;
  late final double aspectRatio;
  final bool isNetworkImage;

  ImageCropBookmark({
    super.key,
    required this.url,
    this.headers,
    required this.articleId,
    required this.page,
    this.isNetworkImage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(20.0),
            child: Crop(
              key: cropKey,
              image: isNetworkImage
                  ? NetworkImage(url, headers: headers)
                  : FileImage(File(url)) as ImageProvider
                ..resolve(ImageConfiguration.empty)
                    .addListener(ImageStreamListener((imageInfo, _) {
                  aspectRatio = imageInfo.image.width / imageInfo.image.height;
                })),
            ),
          ),
        ),
        TextButton(
          child: const Text(
            'Bookmark Image',
            style: TextStyle(color: Colors.white),
          ),
          onPressed: () => bookmarkImage(context),
        ),
        SizedBox.fromSize(size: const Size.fromHeight(24.0))
      ],
    );
  }

  Future<void> bookmarkImage(BuildContext context) async {
    final area = cropKey.currentState!.area;
    if (area == null) {
      // cannot crop, widget is not setup
      return;
    }

    await (await Bookmark.getInstance()).insertCropImage(articleId, page,
        '${area.left},${area.top},${area.right},${area.bottom}', aspectRatio);

    showToast(
      level: ToastLevel.check,
      message:
          '$articleId(${page}p): [${area.toString().split('(')[1].split(')')[0]}] Saved!',
    );

    // ignore: use_build_context_synchronously
    Navigator.pop(context);
  }
}
