class IpadModelResolver {
  IpadModelResolver._();

  static String match(String raw, List<String> models) {
    final value = raw.trim();
    if (!_usable(value)) return '';

    final direct = _matchHardwareCode(value, models);
    if (direct.isNotEmpty) return direct;

    final pro = _matchProGeneration(value, models);
    if (pro.isNotEmpty) return pro;

    for (final model in models) {
      if (model == value) return model;
    }

    final mini = _matchMiniGeneration(value, models);
    if (mini.isNotEmpty) return mini;
    if (_mentionsMiniWithoutGeneration(value)) return '';

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

  static String _matchHardwareCode(String raw, List<String> models) {
    final value = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9/]'), ' ');
    if (_hasAny(value, const ['MLWL3', 'A2567', 'A2568', 'A2569'])) {
      return _findModel(models, 'iPad mini 6');
    }
    if (_hasAny(value, const ['MHNH3', 'A2378', 'A2379', 'A2461', 'A2462'])) {
      return _findModel(models, 'iPad Pro 12.9 2021');
    }
    if (_hasAny(value, const ['A2436', 'A2437', 'A2764', 'A2766'])) {
      return _findModel(models, 'iPad Pro 12.9 2022');
    }
    if (_hasAny(value, const ['A2377', 'A2301', 'A2459', 'A2460'])) {
      return _findModel(models, 'iPad Pro 11 2021');
    }
    if (_hasAny(value, const ['A2435', 'A2759', 'A2761', 'A2762'])) {
      return _findModel(models, 'iPad Pro 11 2022');
    }
    return '';
  }

  static String _matchProGeneration(String raw, List<String> models) {
    final compact = raw
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('．', '.');
    if (!compact.contains('ipad') || !compact.contains('pro')) return '';

    final is129 =
        compact.contains('12.9') ||
        compact.contains('129英寸') ||
        compact.contains('129inch');
    final is11 =
        !is129 &&
        (compact.contains('11英寸') ||
            compact.contains('11inch') ||
            RegExp(r'(^|[^0-9])11($|[^0-9])').hasMatch(compact));

    if (is129 && _hasAny(compact, const ['第5代', '5thgeneration', '5thgen'])) {
      return _findModel(models, 'iPad Pro 12.9 2021');
    }
    if (is129 && _hasAny(compact, const ['第6代', '6thgeneration', '6thgen'])) {
      return _findModel(models, 'iPad Pro 12.9 2022');
    }
    if (is11 && _hasAny(compact, const ['第3代', '3rdgeneration', '3rdgen'])) {
      return _findModel(models, 'iPad Pro 11 2021');
    }
    if (is11 && _hasAny(compact, const ['第4代', '4thgeneration', '4thgen'])) {
      return _findModel(models, 'iPad Pro 11 2022');
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
