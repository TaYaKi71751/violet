// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/article_item/thumbnail_view_page.dart';
import 'package:violet/pages/lab/lab/floating_view/floating_similar_article_view.dart';
import 'package:violet/component/hitomi/similar_articles.dart';

class SimpleInfoWidget extends StatelessWidget {
  final FlareControls _flareController = FlareControls();
  static final DateFormat _dateFormat = DateFormat(' yyyy/MM/dd HH:mm');

  SimpleInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final size = thumbnailSize();
    final data = Provider.of<ArticleInfo>(context);
    return Stack(
      children: <Widget>[
        Row(
          children: [
            Stack(
              children: <Widget>[
                thumbnail(context, data),
                bookmark(data),
              ],
            ),
            Expanded(
              child: SizedBox(
                height: size.height,
                width: size.width,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: simpleInfo(data),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          child: floatingSimilarView(context, data),
        ),
      ],
    );
  }

  Size thumbnailSize() {
    final baseSize = Platform.isWindows ? 100.0 : 50.0;
    final height = 4 * baseSize;
    final width = 3 * baseSize;
    return Size(width, height);
  }

  Widget thumbnail(BuildContext context, ArticleInfo data) {
    return Hero(
      tag: data.heroKey,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3.0),
          child: GestureDetector(
            onTap: () => thumbnailTapped(context, data),
            child: thumbnailImage(data),
          ),
        ),
      ),
    );
  }

  void thumbnailTapped(BuildContext context, ArticleInfo data) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget wi) {
        return FadeTransition(opacity: animation, child: wi);
      },
      pageBuilder: (_, __, ___) => ThumbnailViewPage(
        thumbnail: data.thumbnail,
        headers: data.headers,
        heroKey: data.heroKey,
        showUltra: false,
      ),
    ));
  }

  Widget thumbnailImage(ArticleInfo data) {
    final size = thumbnailSize();
    return data.thumbnail != null
        ? CachedNetworkImage(
            imageUrl: data.thumbnail ?? '',
            fit: BoxFit.cover,
            httpHeaders: data.headers,
            height: size.height,
            width: size.width,
          )
        : SizedBox(
            height: size.height,
            width: size.width,
            child: !Settings.simpleItemWidgetLoadingIcon
                ? const FlareActor(
                    'assets/flare/Loading2.flr',
                    alignment: Alignment.center,
                    fit: BoxFit.fitHeight,
                    animation: 'Alarm',
                  )
                : Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Settings.majorColor.withAlpha(150),
                      ),
                    ),
                  ),
          );
  }

  Widget bookmark(ArticleInfo data) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        child: Transform(
          transform: Matrix4.identity()..scale(1.0),
          child: SizedBox(
            width: 40,
            height: 40,
            child: FlareActor(
              'assets/flare/likeUtsua.flr',
              animation: data.isBookmarked ? 'Like' : 'IdleUnlike',
              controller: _flareController,
            ),
          ),
        ),
        onTap: () async {
          await data.setIsBookmarked(!data.isBookmarked);
          if (!data.isBookmarked) {
            _flareController.play('Unlike');
          } else {
            _flareController.play('Like');
          }
        },
      ),
    );
  }

  Widget simpleInfo(ArticleInfo data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        simpleInfoTextArtist(data),
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Theme(
            data: ThemeData(
                iconTheme: IconThemeData(
                    color: !Settings.themeWhat ? Colors.black : Colors.white)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                simpleInfoDateTime(data),
                simpleInfoPages(data),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget simpleInfoTextArtist(ArticleInfo data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Text(data.title,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(data.artist),
      ],
    );
  }

  Widget simpleInfoDateTime(ArticleInfo data) {
    return Row(
      children: <Widget>[
        const Icon(
          Icons.date_range,
          size: 20,
        ),
        Text(
            data.queryResult.getDateTime() != null
                ? _dateFormat.format(data.queryResult.getDateTime()!.toLocal())
                : '',
            style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  Widget simpleInfoPages(ArticleInfo data) {
    final id = data.queryResult.id();

    return Row(
      children: <Widget>[
        const Icon(
          Icons.photo,
          size: 20,
        ),
        Text(
            ' ${data.thumbnail != null ? '${ProviderManager.isExists(id) ? ProviderManager.getIgnoreDirty(id).length() : '?'} Page' : ''}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget floatingSimilarView(BuildContext context, ArticleInfo data) {
    final articleId = data.queryResult.id();

    return FutureBuilder<bool>(
      future: _checkSimilarArticlesExist(articleId),
      builder: (context, snapshot) {
        // 로딩 중일 때 로딩 인디케이터 표시
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
            ),
          );
        }

        // 유사 아티클 데이터가 없으면 빈 위젯 반환
        if (!snapshot.hasData || snapshot.data != true) {
          return const SizedBox.shrink();
        }

        // 유사 아티클 데이터가 있으면 버튼 표시
        return Material(
          elevation: 8,
          shadowColor: Colors.purple.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.purple, Colors.deepPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FloatingSimilarArticleView(
                      initialArticleId: articleId,
                      useRecursiveLoading: false,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bubble_chart, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkSimilarArticlesExist(int articleId) async {
    try {
      final similarArticles = SimilarArticles();

      await similarArticles.loadSimilarityData();

      if (!similarArticles.isLoaded) {
        return false;
      }

      final similarList = similarArticles.getSimilarArticles(articleId);

      return similarList.isNotEmpty;
    } catch (e) {
      print('유사 작품 확인 중 오류 발생: $e');
      return false;
    }
  }
}
