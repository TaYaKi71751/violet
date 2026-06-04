// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:synchronized/synchronized.dart';
import 'package:violet/database/user/user.dart';
import 'package:violet/log/log.dart';

class LLMSearchLog {
  final int? id;
  final String query;
  final int k;
  final bool strictRelevance;
  final DateTime timestamp;

  LLMSearchLog({
    this.id,
    required this.query,
    required this.k,
    required this.strictRelevance,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'query': query,
      'k': k,
      'strict_relevance': strictRelevance ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LLMSearchLog.fromMap(Map<String, dynamic> map) {
    return LLMSearchLog(
      id: map['id'],
      query: map['query'],
      k: map['k'],
      strictRelevance: map['strict_relevance'] == 1,
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class LLMSearchLogDatabase {
  static LLMSearchLogDatabase? _instance;
  static final _lock = Lock();

  LLMSearchLogDatabase._();

  static Future<LLMSearchLogDatabase> getInstance() async {
    await _lock.synchronized(() async {
      if (_instance == null) {
        final db = await CommonUserDatabase.getInstance();
        final rows = await db.query(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='LLMSearchLog';",
        );
        if (rows.isEmpty || rows[0].isEmpty) {
          try {
            await db.execute('''
              CREATE TABLE LLMSearchLog (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                query TEXT NOT NULL,
                k INTEGER NOT NULL,
                strict_relevance INTEGER NOT NULL,
                timestamp TEXT NOT NULL
              )
            ''');
          } catch (e, st) {
            Logger.error('[LLMSearchLog-Instance] E: $e\n$st');
          }
        }
        _instance = LLMSearchLogDatabase._();
      }
    });
    return _instance!;
  }

  static Future<void> reloadInstance() async {
    await _lock.synchronized(() async {
      _instance = null;
    });
  }

  Future<int> insert(LLMSearchLog log) async {
    final db = await CommonUserDatabase.getInstance();
    return await db.insert('LLMSearchLog', log.toMap());
  }

  Future<List<LLMSearchLog>> getLogs() async {
    final db = await CommonUserDatabase.getInstance();
    final List<Map<String, dynamic>> maps = await db.query(
      'SELECT * FROM LLMSearchLog',
    );
    return maps.map((x) => LLMSearchLog.fromMap(x)).toList().reversed.toList();
  }

  Future<List<String>> getQueries() async {
    final db = await CommonUserDatabase.getInstance();
    final List<Map<String, dynamic>> maps = await db.query(
      'SELECT query FROM LLMSearchLog',
    );
    return maps.map((x) => x['query'] as String).toList().reversed.toList();
  }
}
