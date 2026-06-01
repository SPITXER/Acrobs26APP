import 'acro_mode.dart';

class UserProfile {
  String uid;
  String name;
  String field;
  String location;
  String quote;
  List<String> interests;
  AcroMode? mode;

  UserProfile({
    this.uid = '',
    this.name = '',
    this.field = '',
    this.location = '',
    this.quote = '',
    this.interests = const [],
    this.mode,
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
