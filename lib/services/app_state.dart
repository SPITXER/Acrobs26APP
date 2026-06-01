import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/acro_mode.dart';
import '../models/user_profile.dart';
import '../models/debate_room.dart';
import '../models/post.dart';

class AppState extends ChangeNotifier {
  final _db = FirebaseDatabase.instance;
  final _uuid = const Uuid();

  final UserProfile profile = UserProfile();
  DebateRoom? currentRoom;
  List<Post> posts = List.from(samplePosts);

  AppState() {
    profile.uid = _uuid.v4();
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  void setProfile({
    required String name,
    String field = '',
    AcroMode? mode,
    List<String> interests = const [],
  }) {
    profile.name = name;
    profile.field = field.isEmpty ? 'Intellectual' : field;
    if (mode != null) profile.mode = mode;
    if (interests.isNotEmpty) profile.interests = interests;
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

  // ---------------------------------------------------------------------------
  // Room
  // ---------------------------------------------------------------------------

  void enterRoom(DebateRoom room) {
    currentRoom = room;
    notifyListeners();
  }

  void leaveRoom() {
    currentRoom = null;
    notifyListeners();
  }

  StreamSubscription listenToRoomChat(
      String roomId, void Function(List<Map>) onMessages) {
    return _db.ref('rchats/$roomId').onValue.listen((event) {
      final msgs = <Map>[];
      if (event.snapshot.exists) {
        final data =
            Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final entries = data.entries.toList()
          ..sort((a, b) => ((a.value as Map)['ts'] ?? 0)
              .compareTo((b.value as Map)['ts'] ?? 0));
        for (final e in entries) {
          msgs.add(Map<dynamic, dynamic>.from(e.value as Map));
        }
      }
      onMessages(msgs);
    });
  }

  Future<void> sendRoomChatFB(
      String roomId, String name, String ini, String text) async {
    try {
      await _db.ref('rchats/$roomId').push().set({
        'name': name,
        'ini': ini,
        'msg': text,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Posts / Feed (AppScreen)
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Match streams (shared by Agora + Stoa)
  // ---------------------------------------------------------------------------

  Stream<Map<String, dynamic>?> matchStream() {
    return _db.ref('matches/${profile.uid}').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  Future<void> clearMatch() async {
    await _db.ref('matches/${profile.uid}').remove();
  }

  // ---------------------------------------------------------------------------
  // Agora matchmaking
  // ---------------------------------------------------------------------------

  Future<void> joinAgoraQueue() async {
    await _db.ref('spark_queue/${profile.uid}').set({
      'name': profile.name,
      'uid': profile.uid,
      'ts': ServerValue.timestamp,
    });
  }

  Future<void> leaveAgoraQueue() async {
    await _db.ref('spark_queue/${profile.uid}').remove();
  }

  Stream<int> agoraQueueCount() {
    return _db.ref('spark_queue').onValue.map((event) {
      if (!event.snapshot.exists) return 0;
      final raw = event.snapshot.value;
      if (raw is! Map) return 0;
      return raw.length;
    });
  }

  // Returns a subscription. The screen must cancel it on dispose.
  // When two users are in the queue, the one with the lexicographically
  // greater uid initiates the match (prevents both trying simultaneously).
  StreamSubscription watchAgoraQueue() {
    final uid = profile.uid;
    return _db.ref('spark_queue').onValue.listen((event) async {
      if (!event.snapshot.exists) return;
      final raw = event.snapshot.value;
      if (raw is! Map) return;
      final data = Map<String, dynamic>.from(raw);
      data.remove(uid);
      if (data.isEmpty) return;

      final others = data.entries.toList()
        ..sort((a, b) {
          final ta =
              (Map<String, dynamic>.from(a.value as Map)['ts'] ?? 0) as int;
          final tb =
              (Map<String, dynamic>.from(b.value as Map)['ts'] ?? 0) as int;
          return ta.compareTo(tb);
        });

      final partnerId = others.first.key;
      final partnerData =
          Map<String, dynamic>.from(others.first.value as Map);

      if (uid.compareTo(partnerId) <= 0) return;

      final roomId = 'r${DateTime.now().millisecondsSinceEpoch}';
      final partnerName = partnerData['name'] as String? ?? 'Anonymous';
      final partnerIni = _initials(partnerName);

      try {
        await _db.ref().update({
          'spark_queue/$uid': null,
          'spark_queue/$partnerId': null,
          'matches/$uid': {
            'roomId': roomId,
            'partnerId': partnerId,
            'partnerName': partnerName,
            'partnerIni': partnerIni,
            'isHost': true,
          },
          'matches/$partnerId': {
            'roomId': roomId,
            'partnerId': uid,
            'partnerName': profile.name,
            'partnerIni': profile.initials,
            'isHost': false,
          },
          'rooms/$roomId': _buildRoomMap(roomId, 'Agora Conversation'),
        });
      } catch (_) {
        // Another client may have claimed the slot first — keep waiting
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Stoa matchmaking
  // ---------------------------------------------------------------------------

  Future<void> publishToStoaPool() async {
    await _db.ref('browse_pool/${profile.uid}').set({
      'uid': profile.uid,
      'name': profile.name,
      'field': profile.field,
      'interests': profile.interests,
      'ts': ServerValue.timestamp,
    });
  }

  Future<void> removeFromStoaPool() async {
    await _db.ref('browse_pool/${profile.uid}').remove();
  }

  Stream<List<Map<String, dynamic>>> browsePoolStream() {
    return _db.ref('browse_pool').onValue.map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];
      final raw = event.snapshot.value;
      if (raw is! Map) return <Map<String, dynamic>>[];
      final data = Map<String, dynamic>.from(raw);
      data.remove(profile.uid);
      return data.values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList()
        ..sort((a, b) =>
            ((a['ts'] ?? 0) as int).compareTo((b['ts'] ?? 0) as int));
    });
  }

  // Returns roomId if it was a mutual match, null if like was just sent.
  Future<String?> sendStoaLike(
      String toUid, String toName, String toIni) async {
    await _db
        .ref('browse_likes/${profile.uid}/$toUid')
        .set(ServerValue.timestamp);
    final theirLike =
        await _db.ref('browse_likes/$toUid/${profile.uid}').get();

    if (theirLike.exists) {
      final roomId = 'r${DateTime.now().millisecondsSinceEpoch}';
      await _db.ref().update({
        'browse_pool/${profile.uid}': null,
        'browse_pool/$toUid': null,
        'matches/${profile.uid}': {
          'roomId': roomId,
          'partnerId': toUid,
          'partnerName': toName,
          'partnerIni': toIni,
          'isHost': true,
        },
        'matches/$toUid': {
          'roomId': roomId,
          'partnerId': profile.uid,
          'partnerName': profile.name,
          'partnerIni': profile.initials,
          'isHost': false,
        },
        'rooms/$roomId': _buildRoomMap(roomId, 'Stoa Conversation'),
      });
      return roomId;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildRoomMap(String roomId, String title) => {
        'title': title,
        'desc': '',
        'host': profile.name,
        'hIni': profile.initials,
        'cat': 'Conversation',
        'cap': 2,
        'dur': 'Open',
        'durS': 0,
        'live': true,
        'guests': 0,
        'perms': const RoomPerms().toMap(),
        'createdAt': ServerValue.timestamp,
      };

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  DebateRoom buildRoomFromMatch(Map<String, dynamic> matchData) {
    final roomId = matchData['roomId'] as String;
    final isHost = matchData['isHost'] as bool? ?? false;
    final partnerName = matchData['partnerName'] as String? ?? 'Anonymous';
    final partnerIni = matchData['partnerIni'] as String? ?? '?';
    final myName = profile.name;
    final myIni = profile.initials;

    return DebateRoom(
      id: roomId,
      title: isHost ? 'Conversation' : 'Conversation',
      host: isHost ? myName : partnerName,
      hostInitials: isHost ? myIni : partnerIni,
      isHost: isHost,
      members: [
        RoomMember(
            name: isHost ? myName : partnerName,
            initials: isHost ? myIni : partnerIni,
            isHost: true),
        RoomMember(
            name: isHost ? partnerName : myName,
            initials: isHost ? partnerIni : myIni),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Legacy stubs — kept so LobbyScreen (used by AppScreen feed) compiles.
  // LobbyScreen is mothballed; these are no-ops.
  // ---------------------------------------------------------------------------

  String roomFilter = 'all';
  Map<String, DebateRoom> roomsDB = {};

  void setRoomFilter(String filter) {
    roomFilter = filter;
    notifyListeners();
  }

  List<DebateRoom> get filteredRooms =>
      roomsDB.isEmpty ? List<DebateRoom>.from(demoRooms) : roomsDB.values.toList();

  Future<void> createRoomFB(DebateRoom room) async {}
  Future<void> joinRoomFB(String roomId) async {}
  Future<void> leaveRoomFB(String roomId) async {}
}
