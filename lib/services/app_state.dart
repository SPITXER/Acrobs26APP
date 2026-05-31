import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_profile.dart';
import '../models/debate_room.dart';
import '../models/post.dart';

class AppState extends ChangeNotifier {
  final UserProfile profile = UserProfile();
  DebateRoom? currentRoom;
  List<Post> posts = List.from(samplePosts);
  Map<String, DebateRoom> roomsDB = {};
  String roomFilter = 'all';
  StreamSubscription? _roomsSub;

  AppState() {
    _listenToRooms();
  }

  void _listenToRooms() {
    _roomsSub = FirebaseDatabase.instance.ref('rooms').onValue.listen(
      (event) {
        roomsDB = {};
        if (event.snapshot.exists) {
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          data.forEach((key, value) {
            roomsDB[key.toString()] =
                DebateRoom.fromMap(key.toString(), Map<dynamic, dynamic>.from(value as Map));
          });
        }
        notifyListeners();
      },
      onError: (_) => notifyListeners(),
    );
  }

  Future<void> createRoomFB(DebateRoom room) async {
    try {
      await FirebaseDatabase.instance.ref('rooms/${room.id}').set(room.toMap());
    } catch (_) {}
  }

  Future<void> joinRoomFB(String roomId) async {
    try {
      final r = roomsDB[roomId];
      if (r != null) {
        await FirebaseDatabase.instance
            .ref('rooms/$roomId/guests')
            .set(r.guestCount + 1);
      }
    } catch (_) {}
  }

  Future<void> leaveRoomFB(String roomId) async {
    try {
      final r = roomsDB[roomId];
      if (r != null) {
        await FirebaseDatabase.instance
            .ref('rooms/$roomId/guests')
            .set((r.guestCount - 1).clamp(0, 999));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    super.dispose();
  }

  void setProfile({
    required String name,
    required String field,
    required String role,
  }) {
    profile.name = name;
    profile.field = field.isEmpty ? 'Intellectual' : field;
    profile.role = role;
    notifyListeners();
  }

  void updateProfileDetails({
    String? name,
    String? field,
    String? location,
    String? quote,
    List<String>? interests,
  }) {
    if (name != null) profile.name = name;
    if (field != null) profile.field = field;
    if (location != null) profile.location = location;
    if (quote != null) profile.quote = quote;
    if (interests != null) profile.interests = interests;
    notifyListeners();
  }

  void setRoomFilter(String filter) {
    roomFilter = filter;
    notifyListeners();
  }

  List<DebateRoom> get filteredRooms {
    final all = roomsDB.isEmpty
        ? List<DebateRoom>.from(demoRooms)
        : roomsDB.values.toList();
    switch (roomFilter) {
      case '1v1':
        return all.where((r) => r.capacity == 2).toList();
      case 'small':
        return all.where((r) => r.capacity <= 4).toList();
      case 'group':
        return all.where((r) => r.capacity >= 5).toList();
      case 'live':
        return all.where((r) => r.isLive).toList();
      case 'open':
        return all.where((r) => r.durationSeconds == 0).toList();
      case 'short':
        return all.where((r) => r.durationSeconds > 0 && r.durationSeconds <= 300).toList();
      default:
        return all;
    }
  }

  void enterRoom(DebateRoom room) {
    currentRoom = room;
    notifyListeners();
  }

  void leaveRoom() {
    currentRoom = null;
    notifyListeners();
  }

  void addPost(Post post) {
    posts.insert(0, post);
    notifyListeners();
  }

  void addArgument(String postId, Argument arg) {
    final post = posts.firstWhere((p) => p.id == postId);
    post.arguments = [...post.arguments, arg];
    post.replyCount++;
    notifyListeners();
  }

  void addChatMessage(String postId, ChatMessage msg) {
    final post = posts.firstWhere((p) => p.id == postId);
    post.chats = [...post.chats, msg];
    notifyListeners();
  }
}
