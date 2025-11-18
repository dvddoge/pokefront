class AbilityData {
  static const String intimidate = 'intimidate';
  static const String blaze = 'blaze';
  static const String torrent = 'torrent';
  static const String overgrow = 'overgrow';
  static const String levitate = 'levitate';
  static const String staticAbility = 'static';
  static const String sturdy = 'sturdy';

  static bool isSupported(String abilityName) {
    final name = abilityName.toLowerCase().replaceAll('-', ' ');
    return [
      intimidate,
      blaze,
      torrent,
      overgrow,
      levitate,
      staticAbility,
      sturdy
    ].contains(name);
  }

  static String normalize(String abilityName) {
    return abilityName.toLowerCase().replaceAll('-', ' ');
  }
}
