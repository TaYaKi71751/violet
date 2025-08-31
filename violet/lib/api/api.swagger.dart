// ignore_for_file: type=lint

import 'package:json_annotation/json_annotation.dart';
import 'package:json_annotation/json_annotation.dart' as json;
import 'package:collection/collection.dart';
import 'dart:convert';

import 'package:chopper/chopper.dart';

import 'client_mapping.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show MultipartFile;
import 'package:chopper/chopper.dart' as chopper;
import 'api.enums.swagger.dart' as enums;
export 'api.enums.swagger.dart';

part 'api.swagger.chopper.dart';
part 'api.swagger.g.dart';

// **************************************************************************
// SwaggerChopperGenerator
// **************************************************************************

@ChopperApi()
abstract class Api extends ChopperService {
  static Api create({
    ChopperClient? client,
    http.Client? httpClient,
    Authenticator? authenticator,
    ErrorConverter? errorConverter,
    Converter? converter,
    Uri? baseUrl,
    List<Interceptor>? interceptors,
  }) {
    if (client != null) {
      return _$Api(client);
    }

    final newClient = ChopperClient(
        services: [_$Api()],
        converter: converter ?? $JsonSerializableConverter(),
        interceptors: interceptors ?? [],
        client: httpClient,
        authenticator: authenticator,
        errorConverter: errorConverter,
        baseUrl: baseUrl ?? Uri.parse('http://'));
    return _$Api(newClient);
  }

  ///
  Future<chopper.Response> apiV2Get() {
    return _apiV2Get();
  }

  ///
  @Get(path: '/api/v2')
  Future<chopper.Response> _apiV2Get();

  ///
  Future<chopper.Response> apiV2HmacGet() {
    return _apiV2HmacGet();
  }

  ///
  @Get(path: '/api/v2/hmac')
  Future<chopper.Response> _apiV2HmacGet();

  ///Get Comment
  ///@param where Where to get
  Future<chopper.Response<CommentGetResponseDto>> apiV2CommentGet(
      {required String? where}) {
    generatedMapping.putIfAbsent(
        CommentGetResponseDto, () => CommentGetResponseDto.fromJsonFactory);

    return _apiV2CommentGet(where: where);
  }

  ///Get Comment
  ///@param where Where to get
  @Get(path: '/api/v2/comment')
  Future<chopper.Response<CommentGetResponseDto>> _apiV2CommentGet(
      {@Query('where') required String? where});

  ///Post Comment
  Future<chopper.Response> apiV2CommentPost({required CommentPostDto? body}) {
    return _apiV2CommentPost(body: body);
  }

  ///Post Comment
  @Post(
    path: '/api/v2/comment',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV2CommentPost(
      {@Body() required CommentPostDto? body});

  ///Toggle comment hidden status
  ///@param id
  Future<chopper.Response> apiV2CommentIdHiddenPatch({required num? id}) {
    return _apiV2CommentIdHiddenPatch(id: id);
  }

  ///Toggle comment hidden status
  ///@param id
  @Patch(
    path: '/api/v2/comment/{id}/hidden',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV2CommentIdHiddenPatch(
      {@Path('id') required num? id});

  ///Get current user information
  Future<chopper.Response<User>> apiV2UserGet() {
    generatedMapping.putIfAbsent(User, () => User.fromJsonFactory);

    return _apiV2UserGet();
  }

  ///Get current user information
  @Get(path: '/api/v2/user')
  Future<chopper.Response<User>> _apiV2UserGet();

  ///Register User
  Future<chopper.Response> apiV2UserPost({required UserRegisterDTO? body}) {
    return _apiV2UserPost(body: body);
  }

  ///Register User
  @Post(
    path: '/api/v2/user',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV2UserPost(
      {@Body() required UserRegisterDTO? body});

  ///Get all users
  Future<chopper.Response<List<User>>> apiV2UserListGet() {
    generatedMapping.putIfAbsent(User, () => User.fromJsonFactory);

    return _apiV2UserListGet();
  }

  ///Get all users
  @Get(path: '/api/v2/user/list')
  Future<chopper.Response<List<User>>> _apiV2UserListGet();

  ///Get userAppIds registered by discord id
  Future<chopper.Response<ListDiscordUserAppIdsResponseDto>>
      apiV2UserDiscordGet() {
    generatedMapping.putIfAbsent(ListDiscordUserAppIdsResponseDto,
        () => ListDiscordUserAppIdsResponseDto.fromJsonFactory);

    return _apiV2UserDiscordGet();
  }

  ///Get userAppIds registered by discord id
  @Get(path: '/api/v2/user/discord')
  Future<chopper.Response<ListDiscordUserAppIdsResponseDto>>
      _apiV2UserDiscordGet();

  ///Login
  Future<chopper.Response<Tokens>> apiV2AuthPost(
      {required UserRegisterDTO? body}) {
    generatedMapping.putIfAbsent(Tokens, () => Tokens.fromJsonFactory);

    return _apiV2AuthPost(body: body);
  }

  ///Login
  @Post(
    path: '/api/v2/auth',
    optionalBody: true,
  )
  Future<chopper.Response<Tokens>> _apiV2AuthPost(
      {@Body() required UserRegisterDTO? body});

  ///Logout
  Future<chopper.Response> apiV2AuthDelete() {
    return _apiV2AuthDelete();
  }

  ///Logout
  @Delete(path: '/api/v2/auth')
  Future<chopper.Response> _apiV2AuthDelete();

  ///Get refresh token
  Future<chopper.Response<ResLoginUser>> apiV2AuthRefreshGet() {
    generatedMapping.putIfAbsent(
        ResLoginUser, () => ResLoginUser.fromJsonFactory);

    return _apiV2AuthRefreshGet();
  }

  ///Get refresh token
  @Get(path: '/api/v2/auth/refresh')
  Future<chopper.Response<ResLoginUser>> _apiV2AuthRefreshGet();

  ///Login From Discord
  Future<chopper.Response> apiV2AuthDiscordGet() {
    return _apiV2AuthDiscordGet();
  }

  ///Login From Discord
  @Get(path: '/api/v2/auth/discord')
  Future<chopper.Response> _apiV2AuthDiscordGet();

  ///Redirect discord oauth2
  Future<chopper.Response> apiV2AuthDiscordRedirectGet() {
    return _apiV2AuthDiscordRedirectGet();
  }

  ///Redirect discord oauth2
  @Get(path: '/api/v2/auth/discord/redirect')
  Future<chopper.Response> _apiV2AuthDiscordRedirectGet();

  ///Get article read view
  ///@param offset Offset
  ///@param count Count
  ///@param type Type
  Future<chopper.Response<ViewGetResponseDto>> apiV2ViewGet({
    required int? offset,
    required int? count,
    String? type,
  }) {
    generatedMapping.putIfAbsent(
        ViewGetResponseDto, () => ViewGetResponseDto.fromJsonFactory);

    return _apiV2ViewGet(offset: offset, count: count, type: type);
  }

  ///Get article read view
  ///@param offset Offset
  ///@param count Count
  ///@param type Type
  @Get(path: '/api/v2/view')
  Future<chopper.Response<ViewGetResponseDto>> _apiV2ViewGet({
    @Query('offset') required int? offset,
    @Query('count') required int? count,
    @Query('type') String? type,
  });

  ///Post article read data
  ///@param articleId ArticleId
  ///@param viewSeconds Count
  ///@param userAppId User App Id
  Future<chopper.Response> apiV2ViewPost({
    required int? articleId,
    required int? viewSeconds,
    required String? userAppId,
  }) {
    return _apiV2ViewPost(
        articleId: articleId, viewSeconds: viewSeconds, userAppId: userAppId);
  }

  ///Post article read data
  ///@param articleId ArticleId
  ///@param viewSeconds Count
  ///@param userAppId User App Id
  @Post(
    path: '/api/v2/view',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV2ViewPost({
    @Query('articleId') required int? articleId,
    @Query('viewSeconds') required int? viewSeconds,
    @Query('userAppId') required String? userAppId,
  });

  ///Post article read data
  ///@param articleId ArticleId
  ///@param viewSeconds Count
  ///@param userAppId User App Id
  Future<chopper.Response> apiV2ViewLoginedPost({
    required int? articleId,
    required int? viewSeconds,
    required String? userAppId,
  }) {
    return _apiV2ViewLoginedPost(
        articleId: articleId, viewSeconds: viewSeconds, userAppId: userAppId);
  }

  ///Post article read data
  ///@param articleId ArticleId
  ///@param viewSeconds Count
  ///@param userAppId User App Id
  @Post(
    path: '/api/v2/view/logined',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV2ViewLoginedPost({
    @Query('articleId') required int? articleId,
    @Query('viewSeconds') required int? viewSeconds,
    @Query('userAppId') required String? userAppId,
  });

  ///통계 데이터 조회
  Future<chopper.Response<StatsResponseDto>> apiV2StatsGet() {
    generatedMapping.putIfAbsent(
        StatsResponseDto, () => StatsResponseDto.fromJsonFactory);

    return _apiV2StatsGet();
  }

  ///통계 데이터 조회
  @Get(path: '/api/v2/stats')
  Future<chopper.Response<StatsResponseDto>> _apiV2StatsGet();

  ///Create Bookmark Backup
  Future<chopper.Response> apiV2BookmarkBackupPost() {
    return _apiV2BookmarkBackupPost();
  }

  ///Create Bookmark Backup
  @Post(
    path: '/api/v2/bookmark/backup',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV2BookmarkBackupPost();

  ///Get User Bookmarks
  Future<chopper.Response> apiV2BookmarkGet() {
    return _apiV2BookmarkGet();
  }

  ///Get User Bookmarks
  @Get(path: '/api/v2/bookmark')
  Future<chopper.Response> _apiV2BookmarkGet();
}

@JsonSerializable(explicitToJson: true)
class CommentGetResponseDtoElement {
  const CommentGetResponseDtoElement({
    required this.id,
    required this.userAppId,
    required this.body,
    required this.dateTime,
    this.parent,
  });

  factory CommentGetResponseDtoElement.fromJson(Map<String, dynamic> json) =>
      _$CommentGetResponseDtoElementFromJson(json);

  static const toJsonFactory = _$CommentGetResponseDtoElementToJson;
  Map<String, dynamic> toJson() => _$CommentGetResponseDtoElementToJson(this);

  @JsonKey(name: 'id')
  final int id;
  @JsonKey(name: 'userAppId')
  final String userAppId;
  @JsonKey(name: 'body')
  final String body;
  @JsonKey(name: 'dateTime')
  final DateTime dateTime;
  @JsonKey(name: 'parent')
  final int? parent;
  static const fromJsonFactory = _$CommentGetResponseDtoElementFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CommentGetResponseDtoElement &&
            (identical(other.id, id) ||
                const DeepCollectionEquality().equals(other.id, id)) &&
            (identical(other.userAppId, userAppId) ||
                const DeepCollectionEquality()
                    .equals(other.userAppId, userAppId)) &&
            (identical(other.body, body) ||
                const DeepCollectionEquality().equals(other.body, body)) &&
            (identical(other.dateTime, dateTime) ||
                const DeepCollectionEquality()
                    .equals(other.dateTime, dateTime)) &&
            (identical(other.parent, parent) ||
                const DeepCollectionEquality().equals(other.parent, parent)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(id) ^
      const DeepCollectionEquality().hash(userAppId) ^
      const DeepCollectionEquality().hash(body) ^
      const DeepCollectionEquality().hash(dateTime) ^
      const DeepCollectionEquality().hash(parent) ^
      runtimeType.hashCode;
}

extension $CommentGetResponseDtoElementExtension
    on CommentGetResponseDtoElement {
  CommentGetResponseDtoElement copyWith(
      {int? id,
      String? userAppId,
      String? body,
      DateTime? dateTime,
      int? parent}) {
    return CommentGetResponseDtoElement(
        id: id ?? this.id,
        userAppId: userAppId ?? this.userAppId,
        body: body ?? this.body,
        dateTime: dateTime ?? this.dateTime,
        parent: parent ?? this.parent);
  }

  CommentGetResponseDtoElement copyWithWrapped(
      {Wrapped<int>? id,
      Wrapped<String>? userAppId,
      Wrapped<String>? body,
      Wrapped<DateTime>? dateTime,
      Wrapped<int?>? parent}) {
    return CommentGetResponseDtoElement(
        id: (id != null ? id.value : this.id),
        userAppId: (userAppId != null ? userAppId.value : this.userAppId),
        body: (body != null ? body.value : this.body),
        dateTime: (dateTime != null ? dateTime.value : this.dateTime),
        parent: (parent != null ? parent.value : this.parent));
  }
}

@JsonSerializable(explicitToJson: true)
class CommentGetResponseDto {
  const CommentGetResponseDto({
    required this.elements,
  });

  factory CommentGetResponseDto.fromJson(Map<String, dynamic> json) =>
      _$CommentGetResponseDtoFromJson(json);

  static const toJsonFactory = _$CommentGetResponseDtoToJson;
  Map<String, dynamic> toJson() => _$CommentGetResponseDtoToJson(this);

  @JsonKey(name: 'elements', defaultValue: <CommentGetResponseDtoElement>[])
  final List<CommentGetResponseDtoElement> elements;
  static const fromJsonFactory = _$CommentGetResponseDtoFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CommentGetResponseDto &&
            (identical(other.elements, elements) ||
                const DeepCollectionEquality()
                    .equals(other.elements, elements)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(elements) ^ runtimeType.hashCode;
}

extension $CommentGetResponseDtoExtension on CommentGetResponseDto {
  CommentGetResponseDto copyWith(
      {List<CommentGetResponseDtoElement>? elements}) {
    return CommentGetResponseDto(elements: elements ?? this.elements);
  }

  CommentGetResponseDto copyWithWrapped(
      {Wrapped<List<CommentGetResponseDtoElement>>? elements}) {
    return CommentGetResponseDto(
        elements: (elements != null ? elements.value : this.elements));
  }
}

@JsonSerializable(explicitToJson: true)
class CommentPostDto {
  const CommentPostDto({
    required this.where,
    required this.body,
    this.parent,
  });

  factory CommentPostDto.fromJson(Map<String, dynamic> json) =>
      _$CommentPostDtoFromJson(json);

  static const toJsonFactory = _$CommentPostDtoToJson;
  Map<String, dynamic> toJson() => _$CommentPostDtoToJson(this);

  @JsonKey(name: 'where')
  final String where;
  @JsonKey(name: 'body')
  final String body;
  @JsonKey(name: 'parent')
  final int? parent;
  static const fromJsonFactory = _$CommentPostDtoFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CommentPostDto &&
            (identical(other.where, where) ||
                const DeepCollectionEquality().equals(other.where, where)) &&
            (identical(other.body, body) ||
                const DeepCollectionEquality().equals(other.body, body)) &&
            (identical(other.parent, parent) ||
                const DeepCollectionEquality().equals(other.parent, parent)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(where) ^
      const DeepCollectionEquality().hash(body) ^
      const DeepCollectionEquality().hash(parent) ^
      runtimeType.hashCode;
}

extension $CommentPostDtoExtension on CommentPostDto {
  CommentPostDto copyWith({String? where, String? body, int? parent}) {
    return CommentPostDto(
        where: where ?? this.where,
        body: body ?? this.body,
        parent: parent ?? this.parent);
  }

  CommentPostDto copyWithWrapped(
      {Wrapped<String>? where, Wrapped<String>? body, Wrapped<int?>? parent}) {
    return CommentPostDto(
        where: (where != null ? where.value : this.where),
        body: (body != null ? body.value : this.body),
        parent: (parent != null ? parent.value : this.parent));
  }
}

@JsonSerializable(explicitToJson: true)
class User {
  const User({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.userAppId,
    required this.role,
    required this.discordId,
    required this.avatar,
    required this.nickname,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  static const toJsonFactory = _$UserToJson;
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @JsonKey(name: 'id')
  final double id;
  @JsonKey(name: 'createdAt')
  final DateTime createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime updatedAt;
  @JsonKey(name: 'userAppId')
  final String userAppId;
  @JsonKey(
    name: 'role',
    toJson: userRoleToJson,
    fromJson: userRoleRoleFromJson,
  )
  final enums.UserRole role;
  static enums.UserRole userRoleRoleFromJson(Object? value) =>
      userRoleFromJson(value, enums.UserRole.user);

  @JsonKey(name: 'discordId')
  final String discordId;
  @JsonKey(name: 'avatar')
  final String avatar;
  @JsonKey(name: 'nickname')
  final String nickname;
  static const fromJsonFactory = _$UserFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is User &&
            (identical(other.id, id) ||
                const DeepCollectionEquality().equals(other.id, id)) &&
            (identical(other.createdAt, createdAt) ||
                const DeepCollectionEquality()
                    .equals(other.createdAt, createdAt)) &&
            (identical(other.updatedAt, updatedAt) ||
                const DeepCollectionEquality()
                    .equals(other.updatedAt, updatedAt)) &&
            (identical(other.userAppId, userAppId) ||
                const DeepCollectionEquality()
                    .equals(other.userAppId, userAppId)) &&
            (identical(other.role, role) ||
                const DeepCollectionEquality().equals(other.role, role)) &&
            (identical(other.discordId, discordId) ||
                const DeepCollectionEquality()
                    .equals(other.discordId, discordId)) &&
            (identical(other.avatar, avatar) ||
                const DeepCollectionEquality().equals(other.avatar, avatar)) &&
            (identical(other.nickname, nickname) ||
                const DeepCollectionEquality()
                    .equals(other.nickname, nickname)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(id) ^
      const DeepCollectionEquality().hash(createdAt) ^
      const DeepCollectionEquality().hash(updatedAt) ^
      const DeepCollectionEquality().hash(userAppId) ^
      const DeepCollectionEquality().hash(role) ^
      const DeepCollectionEquality().hash(discordId) ^
      const DeepCollectionEquality().hash(avatar) ^
      const DeepCollectionEquality().hash(nickname) ^
      runtimeType.hashCode;
}

extension $UserExtension on User {
  User copyWith(
      {double? id,
      DateTime? createdAt,
      DateTime? updatedAt,
      String? userAppId,
      enums.UserRole? role,
      String? discordId,
      String? avatar,
      String? nickname}) {
    return User(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        userAppId: userAppId ?? this.userAppId,
        role: role ?? this.role,
        discordId: discordId ?? this.discordId,
        avatar: avatar ?? this.avatar,
        nickname: nickname ?? this.nickname);
  }

  User copyWithWrapped(
      {Wrapped<double>? id,
      Wrapped<DateTime>? createdAt,
      Wrapped<DateTime>? updatedAt,
      Wrapped<String>? userAppId,
      Wrapped<enums.UserRole>? role,
      Wrapped<String>? discordId,
      Wrapped<String>? avatar,
      Wrapped<String>? nickname}) {
    return User(
        id: (id != null ? id.value : this.id),
        createdAt: (createdAt != null ? createdAt.value : this.createdAt),
        updatedAt: (updatedAt != null ? updatedAt.value : this.updatedAt),
        userAppId: (userAppId != null ? userAppId.value : this.userAppId),
        role: (role != null ? role.value : this.role),
        discordId: (discordId != null ? discordId.value : this.discordId),
        avatar: (avatar != null ? avatar.value : this.avatar),
        nickname: (nickname != null ? nickname.value : this.nickname));
  }
}

@JsonSerializable(explicitToJson: true)
class UserRegisterDTO {
  const UserRegisterDTO({
    required this.userAppId,
  });

  factory UserRegisterDTO.fromJson(Map<String, dynamic> json) =>
      _$UserRegisterDTOFromJson(json);

  static const toJsonFactory = _$UserRegisterDTOToJson;
  Map<String, dynamic> toJson() => _$UserRegisterDTOToJson(this);

  @JsonKey(name: 'userAppId')
  final String userAppId;
  static const fromJsonFactory = _$UserRegisterDTOFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UserRegisterDTO &&
            (identical(other.userAppId, userAppId) ||
                const DeepCollectionEquality()
                    .equals(other.userAppId, userAppId)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(userAppId) ^ runtimeType.hashCode;
}

extension $UserRegisterDTOExtension on UserRegisterDTO {
  UserRegisterDTO copyWith({String? userAppId}) {
    return UserRegisterDTO(userAppId: userAppId ?? this.userAppId);
  }

  UserRegisterDTO copyWithWrapped({Wrapped<String>? userAppId}) {
    return UserRegisterDTO(
        userAppId: (userAppId != null ? userAppId.value : this.userAppId));
  }
}

@JsonSerializable(explicitToJson: true)
class ListDiscordUserAppIdsResponseDto {
  const ListDiscordUserAppIdsResponseDto({
    required this.userAppIds,
  });

  factory ListDiscordUserAppIdsResponseDto.fromJson(
          Map<String, dynamic> json) =>
      _$ListDiscordUserAppIdsResponseDtoFromJson(json);

  static const toJsonFactory = _$ListDiscordUserAppIdsResponseDtoToJson;
  Map<String, dynamic> toJson() =>
      _$ListDiscordUserAppIdsResponseDtoToJson(this);

  @JsonKey(name: 'userAppIds', defaultValue: <String>[])
  final List<String> userAppIds;
  static const fromJsonFactory = _$ListDiscordUserAppIdsResponseDtoFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ListDiscordUserAppIdsResponseDto &&
            (identical(other.userAppIds, userAppIds) ||
                const DeepCollectionEquality()
                    .equals(other.userAppIds, userAppIds)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(userAppIds) ^ runtimeType.hashCode;
}

extension $ListDiscordUserAppIdsResponseDtoExtension
    on ListDiscordUserAppIdsResponseDto {
  ListDiscordUserAppIdsResponseDto copyWith({List<String>? userAppIds}) {
    return ListDiscordUserAppIdsResponseDto(
        userAppIds: userAppIds ?? this.userAppIds);
  }

  ListDiscordUserAppIdsResponseDto copyWithWrapped(
      {Wrapped<List<String>>? userAppIds}) {
    return ListDiscordUserAppIdsResponseDto(
        userAppIds: (userAppIds != null ? userAppIds.value : this.userAppIds));
  }
}

@JsonSerializable(explicitToJson: true)
class Tokens {
  const Tokens({
    required this.accessToken,
    required this.refreshToken,
  });

  factory Tokens.fromJson(Map<String, dynamic> json) => _$TokensFromJson(json);

  static const toJsonFactory = _$TokensToJson;
  Map<String, dynamic> toJson() => _$TokensToJson(this);

  @JsonKey(name: 'accessToken')
  final String accessToken;
  @JsonKey(name: 'refreshToken')
  final String refreshToken;
  static const fromJsonFactory = _$TokensFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Tokens &&
            (identical(other.accessToken, accessToken) ||
                const DeepCollectionEquality()
                    .equals(other.accessToken, accessToken)) &&
            (identical(other.refreshToken, refreshToken) ||
                const DeepCollectionEquality()
                    .equals(other.refreshToken, refreshToken)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(accessToken) ^
      const DeepCollectionEquality().hash(refreshToken) ^
      runtimeType.hashCode;
}

extension $TokensExtension on Tokens {
  Tokens copyWith({String? accessToken, String? refreshToken}) {
    return Tokens(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken);
  }

  Tokens copyWithWrapped(
      {Wrapped<String>? accessToken, Wrapped<String>? refreshToken}) {
    return Tokens(
        accessToken:
            (accessToken != null ? accessToken.value : this.accessToken),
        refreshToken:
            (refreshToken != null ? refreshToken.value : this.refreshToken));
  }
}

@JsonSerializable(explicitToJson: true)
class ResLoginUser {
  const ResLoginUser();

  factory ResLoginUser.fromJson(Map<String, dynamic> json) =>
      _$ResLoginUserFromJson(json);

  static const toJsonFactory = _$ResLoginUserToJson;
  Map<String, dynamic> toJson() => _$ResLoginUserToJson(this);

  static const fromJsonFactory = _$ResLoginUserFromJson;

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode => runtimeType.hashCode;
}

@JsonSerializable(explicitToJson: true)
class ViewGetResponseDtoElement {
  const ViewGetResponseDtoElement({
    required this.articleId,
    required this.count,
  });

  factory ViewGetResponseDtoElement.fromJson(Map<String, dynamic> json) =>
      _$ViewGetResponseDtoElementFromJson(json);

  static const toJsonFactory = _$ViewGetResponseDtoElementToJson;
  Map<String, dynamic> toJson() => _$ViewGetResponseDtoElementToJson(this);

  @JsonKey(name: 'articleId')
  final int articleId;
  @JsonKey(name: 'count')
  final int count;
  static const fromJsonFactory = _$ViewGetResponseDtoElementFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ViewGetResponseDtoElement &&
            (identical(other.articleId, articleId) ||
                const DeepCollectionEquality()
                    .equals(other.articleId, articleId)) &&
            (identical(other.count, count) ||
                const DeepCollectionEquality().equals(other.count, count)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(articleId) ^
      const DeepCollectionEquality().hash(count) ^
      runtimeType.hashCode;
}

extension $ViewGetResponseDtoElementExtension on ViewGetResponseDtoElement {
  ViewGetResponseDtoElement copyWith({int? articleId, int? count}) {
    return ViewGetResponseDtoElement(
        articleId: articleId ?? this.articleId, count: count ?? this.count);
  }

  ViewGetResponseDtoElement copyWithWrapped(
      {Wrapped<int>? articleId, Wrapped<int>? count}) {
    return ViewGetResponseDtoElement(
        articleId: (articleId != null ? articleId.value : this.articleId),
        count: (count != null ? count.value : this.count));
  }
}

@JsonSerializable(explicitToJson: true)
class ViewGetResponseDto {
  const ViewGetResponseDto({
    required this.elements,
  });

  factory ViewGetResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ViewGetResponseDtoFromJson(json);

  static const toJsonFactory = _$ViewGetResponseDtoToJson;
  Map<String, dynamic> toJson() => _$ViewGetResponseDtoToJson(this);

  @JsonKey(name: 'elements', defaultValue: <ViewGetResponseDtoElement>[])
  final List<ViewGetResponseDtoElement> elements;
  static const fromJsonFactory = _$ViewGetResponseDtoFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ViewGetResponseDto &&
            (identical(other.elements, elements) ||
                const DeepCollectionEquality()
                    .equals(other.elements, elements)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(elements) ^ runtimeType.hashCode;
}

extension $ViewGetResponseDtoExtension on ViewGetResponseDto {
  ViewGetResponseDto copyWith({List<ViewGetResponseDtoElement>? elements}) {
    return ViewGetResponseDto(elements: elements ?? this.elements);
  }

  ViewGetResponseDto copyWithWrapped(
      {Wrapped<List<ViewGetResponseDtoElement>>? elements}) {
    return ViewGetResponseDto(
        elements: (elements != null ? elements.value : this.elements));
  }
}

@JsonSerializable(explicitToJson: true)
class StatsResponseDto {
  const StatsResponseDto({
    required this.totalUsers,
    required this.totalComments,
    required this.userGrowth,
    required this.commentGrowth,
  });

  factory StatsResponseDto.fromJson(Map<String, dynamic> json) =>
      _$StatsResponseDtoFromJson(json);

  static const toJsonFactory = _$StatsResponseDtoToJson;
  Map<String, dynamic> toJson() => _$StatsResponseDtoToJson(this);

  @JsonKey(name: 'totalUsers')
  final int totalUsers;
  @JsonKey(name: 'totalComments')
  final int totalComments;
  @JsonKey(name: 'userGrowth')
  final Object userGrowth;
  @JsonKey(name: 'commentGrowth')
  final Object commentGrowth;
  static const fromJsonFactory = _$StatsResponseDtoFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is StatsResponseDto &&
            (identical(other.totalUsers, totalUsers) ||
                const DeepCollectionEquality()
                    .equals(other.totalUsers, totalUsers)) &&
            (identical(other.totalComments, totalComments) ||
                const DeepCollectionEquality()
                    .equals(other.totalComments, totalComments)) &&
            (identical(other.userGrowth, userGrowth) ||
                const DeepCollectionEquality()
                    .equals(other.userGrowth, userGrowth)) &&
            (identical(other.commentGrowth, commentGrowth) ||
                const DeepCollectionEquality()
                    .equals(other.commentGrowth, commentGrowth)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(totalUsers) ^
      const DeepCollectionEquality().hash(totalComments) ^
      const DeepCollectionEquality().hash(userGrowth) ^
      const DeepCollectionEquality().hash(commentGrowth) ^
      runtimeType.hashCode;
}

extension $StatsResponseDtoExtension on StatsResponseDto {
  StatsResponseDto copyWith(
      {int? totalUsers,
      int? totalComments,
      Object? userGrowth,
      Object? commentGrowth}) {
    return StatsResponseDto(
        totalUsers: totalUsers ?? this.totalUsers,
        totalComments: totalComments ?? this.totalComments,
        userGrowth: userGrowth ?? this.userGrowth,
        commentGrowth: commentGrowth ?? this.commentGrowth);
  }

  StatsResponseDto copyWithWrapped(
      {Wrapped<int>? totalUsers,
      Wrapped<int>? totalComments,
      Wrapped<Object>? userGrowth,
      Wrapped<Object>? commentGrowth}) {
    return StatsResponseDto(
        totalUsers: (totalUsers != null ? totalUsers.value : this.totalUsers),
        totalComments:
            (totalComments != null ? totalComments.value : this.totalComments),
        userGrowth: (userGrowth != null ? userGrowth.value : this.userGrowth),
        commentGrowth:
            (commentGrowth != null ? commentGrowth.value : this.commentGrowth));
  }
}

String? userRoleNullableToJson(enums.UserRole? userRole) {
  return userRole?.value;
}

String? userRoleToJson(enums.UserRole userRole) {
  return userRole.value;
}

enums.UserRole userRoleFromJson(
  Object? userRole, [
  enums.UserRole? defaultValue,
]) {
  return enums.UserRole.values.firstWhereOrNull((e) => e.value == userRole) ??
      defaultValue ??
      enums.UserRole.swaggerGeneratedUnknown;
}

enums.UserRole? userRoleNullableFromJson(
  Object? userRole, [
  enums.UserRole? defaultValue,
]) {
  if (userRole == null) {
    return null;
  }
  return enums.UserRole.values.firstWhereOrNull((e) => e.value == userRole) ??
      defaultValue;
}

String userRoleExplodedListToJson(List<enums.UserRole>? userRole) {
  return userRole?.map((e) => e.value!).join(',') ?? '';
}

List<String> userRoleListToJson(List<enums.UserRole>? userRole) {
  if (userRole == null) {
    return [];
  }

  return userRole.map((e) => e.value!).toList();
}

List<enums.UserRole> userRoleListFromJson(
  List? userRole, [
  List<enums.UserRole>? defaultValue,
]) {
  if (userRole == null) {
    return defaultValue ?? [];
  }

  return userRole.map((e) => userRoleFromJson(e.toString())).toList();
}

List<enums.UserRole>? userRoleNullableListFromJson(
  List? userRole, [
  List<enums.UserRole>? defaultValue,
]) {
  if (userRole == null) {
    return defaultValue;
  }

  return userRole.map((e) => userRoleFromJson(e.toString())).toList();
}

typedef $JsonFactory<T> = T Function(Map<String, dynamic> json);

class $CustomJsonDecoder {
  $CustomJsonDecoder(this.factories);

  final Map<Type, $JsonFactory> factories;

  dynamic decode<T>(dynamic entity) {
    if (entity is Iterable) {
      return _decodeList<T>(entity);
    }

    if (entity is T) {
      return entity;
    }

    if (isTypeOf<T, Map>()) {
      return entity;
    }

    if (isTypeOf<T, Iterable>()) {
      return entity;
    }

    if (entity is Map<String, dynamic>) {
      return _decodeMap<T>(entity);
    }

    return entity;
  }

  T _decodeMap<T>(Map<String, dynamic> values) {
    final jsonFactory = factories[T];
    if (jsonFactory == null || jsonFactory is! $JsonFactory<T>) {
      return throw "Could not find factory for type $T. Is '$T: $T.fromJsonFactory' included in the CustomJsonDecoder instance creation in bootstrapper.dart?";
    }

    return jsonFactory(values);
  }

  List<T> _decodeList<T>(Iterable values) =>
      values.where((v) => v != null).map<T>((v) => decode<T>(v) as T).toList();
}

class $JsonSerializableConverter extends chopper.JsonConverter {
  @override
  FutureOr<chopper.Response<ResultType>> convertResponse<ResultType, Item>(
      chopper.Response response) async {
    if (response.bodyString.isEmpty) {
      // In rare cases, when let's say 204 (no content) is returned -
      // we cannot decode the missing json with the result type specified
      return chopper.Response(response.base, null, error: response.error);
    }

    if (ResultType == String) {
      return response.copyWith();
    }

    if (ResultType == DateTime) {
      return response.copyWith(
          body: DateTime.parse((response.body as String).replaceAll('"', ''))
              as ResultType);
    }

    final jsonRes = await super.convertResponse(response);
    return jsonRes.copyWith<ResultType>(
        body: $jsonDecoder.decode<Item>(jsonRes.body) as ResultType);
  }
}

final $jsonDecoder = $CustomJsonDecoder(generatedMapping);

// ignore: unused_element
String? _dateToJson(DateTime? date) {
  if (date == null) {
    return null;
  }

  final year = date.year.toString();
  final month = date.month < 10 ? '0${date.month}' : date.month.toString();
  final day = date.day < 10 ? '0${date.day}' : date.day.toString();

  return '$year-$month-$day';
}

class Wrapped<T> {
  final T value;
  const Wrapped.value(this.value);
}
