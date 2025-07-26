// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter_test/flutter_test.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/component/index.dart';
import 'package:violet/component/query_translate.dart';
import 'package:violet/settings/settings.dart';

void main() {
  group('Query Test', () {
    setUp(() async {
      await HentaiIndex.loadCountMapIfRequired();
      await TagTranslate.init();
    });

    test('Hitomi Query Auto Complete', () async {
      final result0 = await HentaiIndex.queryAutoComplete('fema');
      final result1 = await HentaiIndex.queryAutoComplete('random:');

      expect(result0[0].$1.toString(), 'female:sole female');
      expect(result1.length, 0);
    });

    test('Hitomi Query Auto Complete Korean', () async {
      final result0 = await HentaiIndex.queryAutoComplete('단독여', true);
      final result1 = await HentaiIndex.queryAutoComplete('male:단독', true);

      expect(result0[0].$1.toString(), 'female:sole female');
      expect(result1[0].$1.toString(), 'male:sole male');
    });

    test('Hitomi Query Auto Complete Fuzzy', () async {
      final result0 = await HentaiIndex.queryAutoCompleteFuzzy('michoking');
      final result1 =
          await HentaiIndex.queryAutoCompleteFuzzy('artist:michoking');
      final result2 =
          await HentaiIndex.queryAutoCompleteFuzzy('female:bigbreakfast');

      expect(result0[0].$1.toString(), 'artist:michiking');
      expect(result1[0].$1.toString(), 'artist:michiking');
      expect(result2[0].$1.toString(), 'female:big breasts');
    });

    test('Hitomi Query To Sql', () {
      Settings.searchPure.value = false;
      final result0 =
          translate2query('female:sole_female (lang:korean or lang:n/a)');
      final result1 =
          translate2query('female:sole_female -(female:mother female:milf)');
      final result2 =
          translate2query('(lang:korean or lang:n/a) -female:sole_female');

      expect(result0,
          'SELECT * FROM HitomiColumnModel WHERE Tags LIKE \'%|female:sole female|%\' AND (Language LIKE \'%korean%\' OR Language LIKE \'%n/a%\')  AND ExistOnHitomi=1');
      expect(result1,
          'SELECT * FROM HitomiColumnModel WHERE Tags LIKE \'%|female:sole female|%\' AND NOT (Tags LIKE \'%|female:mother|%\' AND Tags LIKE \'%|female:milf|%\')  AND ExistOnHitomi=1');
      expect(result2,
          'SELECT * FROM HitomiColumnModel WHERE (Language LIKE \'%korean%\' OR Language LIKE \'%n/a%\') AND (Tags LIKE \'%|female:sole female|%\') IS NOT 1  AND ExistOnHitomi=1');
    });
  });
}
