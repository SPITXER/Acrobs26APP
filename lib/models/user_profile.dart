class UserProfile {
  String name;
  String field;
  String location;
  String quote;
  List<String> interests;
  String role; // 'host' or 'guest'

  UserProfile({
    this.name = '',
    this.field = '',
    this.location = '',
    this.quote = '',
    this.interests = const [],
    this.role = 'host',
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}
