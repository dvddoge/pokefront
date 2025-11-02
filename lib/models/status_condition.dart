enum StatusCondition {
  none,
  burn,
  paralysis,
  poison,
  toxic,
  sleep,
  freeze,
}

extension StatusConditionX on StatusCondition {
  static StatusCondition fromName(String? value) {
    if (value == null) return StatusCondition.none;
    switch (value.toLowerCase()) {
      case 'burn':
      case 'brn':
        return StatusCondition.burn;
      case 'paralysis':
      case 'par':
        return StatusCondition.paralysis;
      case 'poison':
      case 'psn':
        return StatusCondition.poison;
      case 'badly-poisoned':
      case 'badly_poisoned':
      case 'toxic':
      case 'tox':
        return StatusCondition.toxic;
      case 'sleep':
      case 'slp':
        return StatusCondition.sleep;
      case 'freeze':
      case 'frz':
        return StatusCondition.freeze;
      default:
        return StatusCondition.none;
    }
  }
}
