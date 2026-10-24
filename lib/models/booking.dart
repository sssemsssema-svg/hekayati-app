class Booking {
  final String childName;
  final String gender;      // boy | girl
  final String ageGroup;    // 3-5 | 6-10 | 11-16 | adult
  final String artStyle;    // manga | comic | webtoon | mandala | sketch | popart | fantasy | pixel | classic | random
  final String imagination; // exact | ai

  const Booking({
    required this.childName,
    required this.gender,
    required this.ageGroup,
    this.artStyle = 'manga',
    this.imagination = 'ai',
  });

  static const List<String> allStyles = [
    'manga',
    'comic',
    'webtoon',
    'mandala',
    'sketch',
    'popart',
    'fantasy',
    'pixel',
    'classic',
    'random',
  ];

  static String styleLabel(String s) {
    switch (s.toLowerCase()) {
      case 'manga':
        return 'أنمي ومانجا ⚔️';
      case 'comic':
        return 'كوميك بوك 🦸';
      case 'webtoon':
        return 'ويب تون 📱';
      case 'mandala':
        return 'ماندالا وفنون 🧘';
      case 'sketch':
        return 'اسكتشات ✏️';
      case 'popart':
        return 'بوب آرت ⚡';
      case 'fantasy':
        return 'فانتازيا 🐉';
      case 'pixel':
        return 'رترو بكسل 👾';
      case 'classic':
        return 'كلاسيكي 🏰';
      case 'random':
        return 'إبداع تلقائي 🎲';
      default:
        return s;
    }
  }
}
