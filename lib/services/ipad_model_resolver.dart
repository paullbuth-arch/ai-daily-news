class IpadModelResolver {
  IpadModelResolver._();

  static String match(String raw, List<String> models) {
    final value = raw.trim();
    if (!_usable(value)) return '';

    for (final model in models) {
      if (model == value) return model;
    }

    final mini = _matchMiniGeneration(value, models);
    if (mini.isNotEmpty) return mini;
    if (_mentionsMiniWithoutGeneration(value)) return '';
    final pro = _matchProGeneration(value, models);
    if (pro.isNotEmpty) return pro;
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

    final partMatch = _matchProPartOrModelNumber(raw, models);
    if (partMatch.isNotEmpty) return partMatch;

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

  static String _matchProPartOrModelNumber(String raw, List<String> models) {
    final compact = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (_hasAny(compact, const ['A2228', 'A2068', 'A2230', 'MY252'])) {
      return _findModel(models, 'iPad Pro 11 2020');
    }
    if (_hasAny(compact, const ['A2069', 'A2232', 'A2233', 'MY2H2'])) {
      return _findModel(models, 'iPad Pro 12.9 2020');
    }
    if (_hasAny(compact, const ['A2377', 'A2459', 'A2301', 'A2460'])) {
      return _findModel(models, 'iPad Pro 11 2021');
    }
    if (_hasAny(compact, const ['A2378', 'A2461', 'A2379', 'A2462', 'MHNH3'])) {
      return _findModel(models, 'iPad Pro 12.9 2021');
    }
    if (_hasAny(compact, const ['A2759', 'A2435', 'A2761', 'A2762'])) {
      return _findModel(models, 'iPad Pro 11 2022');
    }
    if (_hasAny(compact, const ['A2436', 'A2764', 'A2437', 'A2766'])) {
      return _findModel(models, 'iPad Pro 12.9 2022');
    }
    return '';
  }

  static String _matchProChip(String raw, String size, List<String> models) {
    final normalized = _modelKey(raw).replaceAll(' ', '');
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
      return size == '12.9'
          ? _findModel(models, 'iPad Pro 13 2024')
          : _findModel(models, 'iPad Pro 11 2024');
    }
    return '';
  }

  static String _proSize(String raw) {
    final value = raw.toLowerCase();
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
