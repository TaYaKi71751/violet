import 'package:json_annotation/json_annotation.dart';
import 'package:collection/collection.dart';

enum UserRole {
  @JsonValue(null)
  swaggerGeneratedUnknown(null),

  @JsonValue('admin')
  admin('admin'),
  @JsonValue('user')
  user('user');

  final String? value;

  const UserRole(this.value);
}
