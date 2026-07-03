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
