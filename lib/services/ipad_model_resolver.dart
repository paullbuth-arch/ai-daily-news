class IpadModelResolver {
  IpadModelResolver._();

  static String match(String raw, List<String> models) {
    final value = raw.trim();
    if (!_usable(value)) return '';

    for (final model in models) {
      if (model == value) return model;
    }

    final numbered = _matchModelNumber(value, models);
    if (numbered.isNotEmpty) return numbered;

    final mini = _matchMiniGeneration(value, models);
    if (mini.isNotEmpty) return mini;
    if (_mentionsMiniWithoutGeneration(value)) return '';
    final pro = _matchProGeneration(value, models);
    if (pro.isNotEmpty) return pro;
    final air = _matchAirGeneration(value, models);
    if (air.isNotEmpty) return air;
    final base = _matchBaseIpadGeneration(value, models);
    if (base.isNotEmpty) return base;
    final part = _matchPartNumber(value, models);
    if (part.isNotEmpty) return part;
    if (_hasStructuredModelClue(value)) return '';

    final normalized = _modelKey(value);
    var best = '';
    var bestScore = 0;
    for (final model in models) {
      final key = _modelKey(model);
      var score = 0;
      for (final token in normalized.split(RegExp(r'[^a-z0-9]+'))) {
        if (token.length < 2) continue;
        if (key.contains(token)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = model;
      }
    }
    return bestScore >= 2 ? best : '';
  }

  static bool _usable(String value) =>
      value.isNotEmpty && value != '未知' && value.toLowerCase() != 'unknown';

  static String _matchModelNumber(String raw, List<String> models) {
    final compact = _compact(raw);
    final exact = <String, String>{
      // iPad Pro
      'A3360': 'iPad Pro 13 2025',
      'A3361': 'iPad Pro 13 2025',
      'A3362': 'iPad Pro 13 2025',
      'A3357': 'iPad Pro 11 2025',
      'A3358': 'iPad Pro 11 2025',
      'A3359': 'iPad Pro 11 2025',
      'A2925': 'iPad Pro 13 2024',
      'A2926': 'iPad Pro 13 2024',
      'A3007': 'iPad Pro 13 2024',
      'A2836': 'iPad Pro 11 2024',
      'A2837': 'iPad Pro 11 2024',
      'A3006': 'iPad Pro 11 2024',
      'A2436': 'iPad Pro 12.9 2022',
      'A2437': 'iPad Pro 12.9 2022',
      'A2764': 'iPad Pro 12.9 2022',
      'A2766': 'iPad Pro 12.9 2022',
      'A2759': 'iPad Pro 11 2022',
      'A2761': 'iPad Pro 11 2022',
      'A2435': 'iPad Pro 11 2022',
      'A2762': 'iPad Pro 11 2022',
      'A2378': 'iPad Pro 12.9 2021',
      'A2461': 'iPad Pro 12.9 2021',
      'A2379': 'iPad Pro 12.9 2021',
      'A2462': 'iPad Pro 12.9 2021',
      'A2377': 'iPad Pro 11 2021',
      'A2459': 'iPad Pro 11 2021',
      'A2301': 'iPad Pro 11 2021',
      'A2460': 'iPad Pro 11 2021',
      'A2229': 'iPad Pro 12.9 2020',
      'A2069': 'iPad Pro 12.9 2020',
      'A2232': 'iPad Pro 12.9 2020',
      'A2233': 'iPad Pro 12.9 2020',
      'A2228': 'iPad Pro 11 2020',
      'A2068': 'iPad Pro 11 2020',
      'A2230': 'iPad Pro 11 2020',
      'A2231': 'iPad Pro 11 2020',
      'A1876': 'iPad Pro 12.9 2018',
      'A2014': 'iPad Pro 12.9 2018',
      'A1895': 'iPad Pro 12.9 2018',
      'A1983': 'iPad Pro 12.9 2018',
      'A1980': 'iPad Pro 11 2018',
      'A2013': 'iPad Pro 11 2018',
      'A1934': 'iPad Pro 11 2018',
      'A1979': 'iPad Pro 11 2018',

      // iPad Air
      'A3461': 'iPad Air 13 2026',
      'A3462': 'iPad Air 13 2026',
      'A3464': 'iPad Air 13 2026',
      'A3459': 'iPad Air 11 2026',
      'A3460': 'iPad Air 11 2026',
      'A3463': 'iPad Air 11 2026',
      'A3268': 'iPad Air 13 2025',
      'A3269': 'iPad Air 13 2025',
      'A3271': 'iPad Air 13 2025',
      'A3266': 'iPad Air 11 2025',
      'A3267': 'iPad Air 11 2025',
      'A3270': 'iPad Air 11 2025',
      'A2898': 'iPad Air 13 2024',
      'A2899': 'iPad Air 13 2024',
      'A2900': 'iPad Air 13 2024',
      'A2902': 'iPad Air 11 2024',
      'A2903': 'iPad Air 11 2024',
      'A2904': 'iPad Air 11 2024',
      'A2588': 'iPad Air 5',
      'A2589': 'iPad Air 5',
      'A2591': 'iPad Air 5',
      'A2316': 'iPad Air 4',
      'A2324': 'iPad Air 4',
      'A2325': 'iPad Air 4',
      'A2072': 'iPad Air 4',
      'A2152': 'iPad Air 3',
      'A2123': 'iPad Air 3',
      'A2153': 'iPad Air 3',
      'A2154': 'iPad Air 3',

      // iPad mini
      'A2993': 'iPad mini 7',
      'A2995': 'iPad mini 7',
      'A2996': 'iPad mini 7',
      'A2567': 'iPad mini 6',
      'A2568': 'iPad mini 6',
      'A2569': 'iPad mini 6',
      'A2133': 'iPad mini 5',
      'A2124': 'iPad mini 5',
      'A2126': 'iPad mini 5',
      'A2125': 'iPad mini 5',

      // iPad
      'A3354': 'iPad A16',
      'A3355': 'iPad A16',
      'A3356': 'iPad A16',
      'A2696': 'iPad 10',
      'A2757': 'iPad 10',
      'A2777': 'iPad 10',
      'A3162': 'iPad 10',
      'A2602': 'iPad 9',
      'A2604': 'iPad 9',
      'A2603': 'iPad 9',
      'A2605': 'iPad 9',
      'A2270': 'iPad 8',
      'A2428': 'iPad 8',
      'A2429': 'iPad 8',
      'A2430': 'iPad 8',
      'A2197': 'iPad 7',
      'A2200': 'iPad 7',
      'A2198': 'iPad 7',
    };

    for (final entry in exact.entries) {
      if (compact.contains(entry.key)) {
        return _findModel(models, entry.value);
      }
    }

    return '';
  }

  static String _matchPartNumber(String raw, List<String> models) {
    final compact = _compact(raw);
    // Common order-number prefixes seen on About-device pages. These are
    // intentionally sparse: only use prefixes that map to a single model line.
    final partPrefixes = <String, String>{
      'MY252': 'iPad Pro 11 2020',
      'MY2H2': 'iPad Pro 12.9 2020',
      'MHNH3': 'iPad Pro 12.9 2021',
      'MLWL3': 'iPad mini 6',
    };
    for (final entry in partPrefixes.entries) {
      if (compact.contains(entry.key)) return _findModel(models, entry.value);
    }
    return '';
  }

  static String _matchMiniGeneration(String raw, List<String> models) {
    final normalized = _modelKey(raw);
    if (!normalized.contains('mini')) return '';
    if (_hasAny(normalized, const ['a17pro', 'a17 pro', 'mini7', 'mini 7'])) {
      return _findModel(models, 'iPad mini 7');
    }
    if (_hasAny(normalized, const ['a15', 'mini6', 'mini 6'])) {
      return _findModel(models, 'iPad mini 6');
    }
    if (_hasAny(normalized, const ['a12', 'mini5', 'mini 5'])) {
      return _findModel(models, 'iPad mini 5');
    }
    return '';
  }

  static bool _mentionsMiniWithoutGeneration(String raw) {
    final normalized = _modelKey(raw);
    return normalized.contains('ipad') && normalized.contains('mini');
  }

  static String _matchProGeneration(String raw, List<String> models) {
    final normalized = _modelKey(raw);
    if (!normalized.contains('pro')) return '';

    final size = _proSize(raw);
    if (size.isEmpty) return '';

    final chipMatch = _matchProChip(raw, size, models);
    if (chipMatch.isNotEmpty) return chipMatch;

    final generation = _generationNumber(raw);
    if (generation == null) return '';

    if (size == '11') {
      return switch (generation) {
        1 => _findModel(models, 'iPad Pro 11 2018'),
        2 => _findModel(models, 'iPad Pro 11 2020'),
        3 => _findModel(models, 'iPad Pro 11 2021'),
        4 => _findModel(models, 'iPad Pro 11 2022'),
        5 => _findModel(models, 'iPad Pro 11 2024'),
        _ => '',
      };
    }
    if (size == '12.9') {
      return switch (generation) {
        3 => _findModel(models, 'iPad Pro 12.9 2018'),
        4 => _findModel(models, 'iPad Pro 12.9 2020'),
        5 => _findModel(models, 'iPad Pro 12.9 2021'),
        6 => _findModel(models, 'iPad Pro 12.9 2022'),
        _ => '',
      };
    }
    return '';
  }

  static String _matchProChip(String raw, String size, List<String> models) {
    final normalized = _modelKey(raw).replaceAll(' ', '');
    if (normalized.contains('m5')) {
      return size == '13'
          ? _findModel(models, 'iPad Pro 13 2025')
          : _findModel(models, 'iPad Pro 11 2025');
    }
    if (normalized.contains('a12z')) {
      return _findModel(models, 'iPad Pro $size 2020');
    }
    if (normalized.contains('a12x')) {
      return _findModel(models, 'iPad Pro $size 2018');
    }
    if (normalized.contains('m1'))
      return _findModel(models, 'iPad Pro $size 2021');
    if (normalized.contains('m2'))
      return _findModel(models, 'iPad Pro $size 2022');
    if (normalized.contains('m4')) {
      return size == '13'
          ? _findModel(models, 'iPad Pro 13 2024')
          : _findModel(models, 'iPad Pro 11 2024');
    }
    return '';
  }

  static String _proSize(String raw) {
    final value = raw.toLowerCase();
    if (RegExp(r'13\s*(英寸|寸|inch|")?').hasMatch(value)) return '13';
    if (RegExp(r'11\s*(英寸|寸|inch|")?').hasMatch(value)) return '11';
    if (RegExp(r'12[\s\._,]*9\s*(英寸|寸|inch|")?').hasMatch(value)) {
      return '12.9';
    }
    return '';
  }

  static int? _generationNumber(String raw) {
    final chinese = RegExp(r'第\s*(\d+)\s*代').firstMatch(raw);
    if (chinese != null) return int.tryParse(chinese.group(1)!);
    final english = RegExp(
      r'(\d+)(st|nd|rd|th)\s+generation',
      caseSensitive: false,
    ).firstMatch(raw);
    if (english != null) return int.tryParse(english.group(1)!);
    return null;
  }

  static String _matchAirGeneration(String raw, List<String> models) {
    final normalized = _modelKey(raw);
    if (!normalized.contains('air')) return '';

    final size = _airSize(raw);
    if (size.isNotEmpty) {
      if (normalized.contains('m4')) {
        return _findModel(models, 'iPad Air $size 2026');
      }
      if (normalized.contains('m3')) {
        return _findModel(models, 'iPad Air $size 2025');
      }
      if (normalized.contains('m2')) {
        return _findModel(models, 'iPad Air $size 2024');
      }
    }

    if (normalized.contains('m1')) return _findModel(models, 'iPad Air 5');
    if (normalized.contains('a14')) return _findModel(models, 'iPad Air 4');
    if (normalized.contains('a12')) return _findModel(models, 'iPad Air 3');

    final generation = _generationNumber(raw);
    if (generation == null) return '';
    return switch (generation) {
      5 => _findModel(models, 'iPad Air 5'),
      4 => _findModel(models, 'iPad Air 4'),
      3 => _findModel(models, 'iPad Air 3'),
      _ => '',
    };
  }

  static String _airSize(String raw) {
    final value = raw.toLowerCase();
    if (RegExp(r'13\s*(英寸|寸|inch|")?').hasMatch(value)) return '13';
    if (RegExp(r'11\s*(英寸|寸|inch|")?').hasMatch(value)) return '11';
    return '';
  }

  static String _matchBaseIpadGeneration(String raw, List<String> models) {
    final normalized = _modelKey(raw);
    final mentionsBaseIpad =
        normalized.contains('ipad') &&
        !normalized.contains('pro') &&
        !normalized.contains('air') &&
        !normalized.contains('mini');
    if (!mentionsBaseIpad) return '';

    if (normalized.contains('a16')) return _findModel(models, 'iPad A16');
    if (normalized.contains('a14')) return _findModel(models, 'iPad 10');
    if (normalized.contains('a13')) return _findModel(models, 'iPad 9');
    if (normalized.contains('a12')) return _findModel(models, 'iPad 8');
    if (normalized.contains('a10')) return _findModel(models, 'iPad 7');

    final generation = _generationNumber(raw);
    if (generation == null) return '';
    return switch (generation) {
      11 => _findModel(models, 'iPad A16'),
      10 => _findModel(models, 'iPad 10'),
      9 => _findModel(models, 'iPad 9'),
      8 => _findModel(models, 'iPad 8'),
      7 => _findModel(models, 'iPad 7'),
      _ => '',
    };
  }

  static bool _hasStructuredModelClue(String raw) {
    final value = raw.toUpperCase();
    return RegExp(r'\bA\d{4}\b').hasMatch(value) ||
        RegExp(r'\b[A-Z]{1,4}\d{3,5}[A-Z0-9]{0,4}/A\b').hasMatch(value) ||
        RegExp(r'第\s*\d+\s*代').hasMatch(raw) ||
        RegExp(
          r'\d+(st|nd|rd|th)\s+generation',
          caseSensitive: false,
        ).hasMatch(raw);
  }

  static bool _hasAny(String value, List<String> needles) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final compact = normalized.replaceAll(' ', '');
    for (final needle in needles) {
      final n = needle.toLowerCase();
      if (normalized.contains(n) || compact.contains(n.replaceAll(' ', ''))) {
        return true;
      }
    }
    return false;
  }

  static String _findModel(List<String> models, String prefix) {
    for (final model in models) {
      if (model.startsWith(prefix)) return model;
    }
    return '';
  }

  static String _compact(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String _modelKey(String value) => value
      .toLowerCase()
      .replaceAll('第', '')
      .replaceAll('代', '')
      .replaceAll('英寸', '')
      .replaceAll('(', ' ')
      .replaceAll(')', ' ')
      .replaceAll('（', ' ')
      .replaceAll('）', ' ');
}
