// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/settings/settings.dart';

/// Translate search query to sql query
String translate2query(String query, {bool filter = true}) {
  query = query.trim();
  final nn = int.tryParse(query.split(' ')[0]);
  if (nn != null) {
    return 'SELECT * FROM HitomiColumnModel WHERE Id=$nn';
  }

  final filterExistsOnHitomi = !Settings.searchPure.value && filter;

  if (query.isEmpty) {
    return 'SELECT * FROM HitomiColumnModel ${filterExistsOnHitomi ? 'WHERE ExistOnHitomi=1' : ''}';
  }

  final tokens =
      _splitTokens(query).map((x) => x.trim()).where((x) => x != '').toList();
  final where = _QueryTranslator(tokens).parseExpression();

  return 'SELECT * FROM HitomiColumnModel WHERE $where ${filterExistsOnHitomi ? ' AND ExistOnHitomi=1' : ''}';
}

List<String> _splitTokens(String tokens) {
  final result = <String>[];
  final builder = StringBuffer();
  for (int i = 0; i < tokens.length; i++) {
    if (tokens[i] == ' ') {
      result.add(builder.toString());
      builder.clear();
      continue;
    } else if (tokens[i] == '(' || tokens[i] == ')') {
      result.add(builder.toString());
      builder.clear();
      result.add(tokens[i]);
      continue;
    }

    builder.write(tokens[i]);
  }

  result.add(builder.toString());
  return result;
}

class _QueryTranslator {
  final List<String> tokens;
  int index = 0;

  _QueryTranslator(this.tokens);

  String parseExpression() {
    if (index >= tokens.length) return '';

    String token = nextToken();
    var where = '';
    bool negative = false;

    if (token.startsWith('-')) {
      negative = true;
      if (token == '-') {
        token = nextToken();
      } else {
        token = token.substring(1);
      }
    }

    if (token.contains(':')) {
      where += parseTag(token, negative);
    } else if (token.startsWith('page') &&
        (token.contains('>') || token.contains('=') || token.contains('<'))) {
      where += parsePageExpression(token, negative);
    } else if (token == '(') {
      where += parseParentheses(token, negative);
      where += parseExpression();
      where += nextToken();
      if (hasMoreTokens()) {
        where += parseLogicalExpression();
      }
    } else if (token == ')') {
      return token;
    } else {
      where += parseTitle(token, negative);
    }

    if (hasMoreTokens() && lookAhead() != ')') {
      where += parseLogicalExpression();
    }

    return where;
  }

  String parseTag(String token, bool negative) {
    var ss = token.split(':');
    var column = findColumnByTag(ss[0]);
    if (column == '') return '';

    var name = '';
    switch (ss[0]) {
      case 'male':
      case 'female':
        name = '|${token.replaceAll('_', ' ')}|';
        break;

      case 'tag':
      case 'series':
      case 'artist':
      case 'character':
      case 'group':
        name = '|${ss[1].replaceAll('_', ' ')}|';
        break;

      case 'uploader':
        name = ss[1];
        break;

      case 'lang':
      case 'type':
      case 'class':
        name = ss[1].replaceAll('_', ' ');
        break;
    }

    var compare = "$column LIKE '%$name%'";
    if (column == 'Uploader') compare += ' COLLATE NOCASE';

    return (negative ? '($compare) IS NOT 1' : compare);
  }

  String parsePageExpression(String token, bool negative) {
    final re = RegExp(r'page([\=\<\>]{1,2})(\d+)');
    if (re.hasMatch(token)) {
      final matches = re.allMatches(token).elementAt(0);
      return 'Files ${matches.group(1)} ${matches.group(2)}';
    }
    return '';
  }

  String parseParentheses(String token, bool negative) {
    return negative ? 'NOT $token' : token;
  }

  String parseTitle(String token, bool negative) {
    return negative ? "Title NOT LIKE '%$token%'" : "Title LIKE '%$token%'";
  }

  String parseLogicalExpression() {
    String next = lookAhead();
    late String op;
    if (next.toLowerCase() == 'or') {
      nextToken();
      op = 'OR';
    } else {
      op = 'AND';
    }
    return ' $op ${parseExpression()}';
  }

  String nextToken() => tokens[index++];
  String lookAhead() => index < tokens.length ? tokens[index] : '';
  bool hasMoreTokens() => index < tokens.length;

  static String findColumnByTag(String tag) {
    switch (tag) {
      case 'male':
      case 'female':
      case 'tag':
        return 'Tags';

      case 'lang':
        return 'Language';

      case 'series':
        return 'Series';

      case 'artist':
        return 'Artists';

      case 'group':
        return 'Groups';

      case 'uploader':
        return 'Uploader';

      case 'character':
        return 'Characters';

      case 'type':
        return 'Type';

      case 'class':
        return 'Class';
    }

    return tag;
  }
}
