import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, Colors, GlobalKey, NavigatorState, ScaffoldMessengerState, SnackBar, SnackBarAction, Text, TextStyle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/acro_mode.dart';
import '../models/user_profile.dart';
import '../models/debate_room.dart';
import '../models/post.dart';
import 'badge_engine.dart';

class AppState extends ChangeNotifier {
  final _db = FirebaseDatabase.instance;
  final _uuid = const Uuid();

  final GlobalKey<NavigatorState>        _navigatorKey;
  final GlobalKey<ScaffoldMessengerState> _messengerKey;

  final UserProfile profile = UserProfile();
  DebateRoom? currentRoom;
  List<Post> posts = List.from(samplePosts);

  // Firebase Auth
  User? firebaseUser;

  // 5-minute signup prompt
  bool _promptShown = false;
  Timer? _activityTimer;
  VoidCallback? _signupDialogCallback; // registered by map screen

  // Room navigation — registered by StoaScreen / any active screen
  VoidCallback? _enterRoomCallback;
  VoidCallback? get enterRoomCallback => _enterRoomCallback;
  void registerEnterRoomCallback(VoidCallback? cb) => _enterRoomCallback = cb;

  // Room session timing — for hours-active stat
  DateTime? _roomEnterTime;

  // Debate room cache — survives leaveRoom() so users can re-enter
  final Map<String, DebateRoom> _roomCache = {};
  // stoaRoomId → debateRoomId — lets side menu re-enter from stoa tile
  final Map<String, String> _stoaToDebateRoom = {};

  // Stoa argument rooms (up to 10 active at once)
  final List<String> _myStoaRoomIds = [];
  StreamSubscription? _globalStoaWatcher;

  // roomId → joiner name, persists until cleared
  final Map<String, String> stoaNotifications = {};

  // Rooms this user is currently debating in
  final List<Map<String, String>> activeDebates = [];

  List<String> get myStoaRoomIds => List.unmodifiable(_myStoaRoomIds);
  bool get canCreateStoaRoom => _myStoaRoomIds.length < 10;
  int  get stoaNotificationCount => stoaNotifications.length;

  AppState({
    required GlobalKey<NavigatorState>        navigatorKey,
    required GlobalKey<ScaffoldMessengerState> messengerKey,
  })  : _navigatorKey = navigatorKey,
        _messengerKey = messengerKey {
    profile.uid = _uuid.v4();
    _init();
  }

  Future<void> _init() async {
    await _loadLocalProfile();
    firebaseUser = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((user) {
      firebaseUser = user;
      if (user != null) _activityTimer?.cancel();
      notifyListeners();
    });
    // Start timer if user already has a name (returning user)
    if (profile.name.isNotEmpty && firebaseUser == null) {
      _startActivityTimer();
    }
  }

  // ── Local storage ────────────────────────────────────────────────────────

  static const _kUid       = 'acro_uid';
  static const _kName      = 'acro_name';
  static const _kField     = 'acro_field';
  static const _kInterests = 'acro_interests';
  static const _kQuote     = 'acro_quote';

  Future<void> _loadLocalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName) ?? '';
    if (name.isEmpty) return;
    profile.uid       = prefs.getString(_kUid) ?? profile.uid;
    profile.name      = name;
    profile.field     = prefs.getString(_kField) ?? '';
    profile.interests = prefs.getStringList(_kInterests) ?? [];
    profile.quote     = prefs.getString(_kQuote) ?? '';
    notifyListeners();
  }

  Future<void> _saveLocalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_kUid,  profile.uid),
      prefs.setString(_kName, profile.name),
      prefs.setString(_kField, profile.field),
      prefs.setStringList(_kInterests, profile.interests),
      prefs.setString(_kQuote, profile.quote),
    ]);
  }

  // ── 5-minute signup prompt ───────────────────────────────────────────────

  void registerSignupDialogCallback(VoidCallback cb) {
    _signupDialogCallback = cb;
  }

  void _startActivityTimer() {
    if (_promptShown || firebaseUser != null) return;
    _activityTimer?.cancel();
    _activityTimer = Timer(const Duration(minutes: 5), () {
      if (firebaseUser != null || _promptShown) return;
      _promptShown = true;
      _signupDialogCallback?.call();
    });
  }

  void dismissSignupPrompt() { /* no-op — dialog closed by caller */ }

  // ── Firebase Auth ────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    final cred = await FirebaseAuth.instance
        .signInWithPopup(GoogleAuthProvider());
    final user = cred.user;
    if (user == null) return;
    if (profile.name.isEmpty && user.displayName != null) {
      profile.name = user.displayName!;
    }
    profile.uid = user.uid;
    await _saveLocalProfile();
    await _db.ref('users/${user.uid}').set({
      'uid':       user.uid,
      'name':      profile.name,
      'field':     profile.field,
      'interests': profile.interests,
      'ts':        ServerValue.timestamp,
    });
    notifyListeners();
  }

  Future<void> signUpWithEmail(String email, String password) async {
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    final user = cred.user;
    if (user == null) return;
    profile.uid = user.uid;
    await _saveLocalProfile();
    await _db.ref('users/${user.uid}').set({
      'uid':       user.uid,
      'name':      profile.name,
      'field':     profile.field,
      'interests': profile.interests,
      'email':     email,
      'ts':        ServerValue.timestamp,
    });
    notifyListeners();
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
    _saveLocalProfile();
    _startActivityTimer();
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
    _saveLocalProfile();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Room
  // ---------------------------------------------------------------------------

  void enterRoom(DebateRoom room) {
    currentRoom = room;
    _roomEnterTime = DateTime.now();
    _roomCache[room.id] = room; // cache so user can re-enter after leaving
    activeDebates.removeWhere((d) => d['roomId'] == room.id);
    final partner = room.members.where((m) => m.name != profile.name).toList();
    activeDebates.add({
      'roomId':      room.id,
      'title':       room.title,
      'partnerName': partner.isNotEmpty ? partner.first.name     : '',
      'partnerIni':  partner.isNotEmpty ? partner.first.initials : '?',
    });
    notifyListeners();
  }

  // Re-enter a previously joined room from the side menu.
  // Falls back to reconstructing a minimal DebateRoom when cache is cold
  // (e.g. after a page refresh) so RoomScreen can still connect via Firebase.
  void reenterRoom(String roomId, {
    String title = 'Debate',
    String partnerName = '',
    String partnerIni = '?',
  }) {
    final cached = _roomCache[roomId];
    if (cached != null) {
      currentRoom = cached;
    } else {
      // Reconstruct from the data we have. Read hostUid from Firebase so
      // isHost is correct even after a page refresh (avoids both sides
      // waiting for an offer that nobody creates).
      currentRoom = DebateRoom(
        id: roomId,
        title: title,
        host: partnerName.isNotEmpty ? partnerName : profile.name,
        hostInitials: partnerName.isNotEmpty ? partnerIni : profile.initials,
        isHost: false,
        members: [
          RoomMember(name: profile.name, initials: profile.initials),
          if (partnerName.isNotEmpty)
            RoomMember(name: partnerName, initials: partnerIni, isHost: true),
        ],
      );
      // Async-correct isHost from the rooms node then re-notify
      _db.ref('rooms/$roomId/hostUid').get().then((snap) {
        if (snap.value == profile.uid && currentRoom?.id == roomId) {
          currentRoom = DebateRoom(
            id: roomId,
            title: currentRoom?.title ?? title,
            host: profile.name,
            hostInitials: profile.initials,
            isHost: true,
            members: [
              RoomMember(name: profile.name, initials: profile.initials, isHost: true),
              if (partnerName.isNotEmpty)
                RoomMember(name: partnerName, initials: partnerIni),
            ],
          );
          notifyListeners();
        }
      });
    }
    _roomEnterTime = DateTime.now();
    notifyListeners();
  }

  // Returns the debate room ID for a given stoa argument room ID (host use).
  String? debateRoomForStoaRoom(String stoaRoomId) =>
      _stoaToDebateRoom[stoaRoomId];

  void leaveRoom() {
    if (currentRoom != null) {
      // Flush session minutes — keep room in activeDebates and cache
      // so the user can re-enter from the side menu.
      if (_roomEnterTime != null && isPermanentAccount) {
        final minutes =
            DateTime.now().difference(_roomEnterTime!).inMinutes;
        if (minutes > 0) {
          _db
              .ref('users/${profile.uid}/totalMinutesActive')
              .set(ServerValue.increment(minutes));
        }
      }
      _roomEnterTime = null;
    }
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
        'hostUid': profile.uid,
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
    final roomId      = matchData['roomId']      as String;
    final isHost      = matchData['isHost']      as bool?   ?? false;
    final partnerName = matchData['partnerName'] as String? ?? 'Anonymous';
    final partnerIni  = matchData['partnerIni']  as String? ?? '?';
    final roomName    = matchData['roomName']    as String? ?? _greekRoomName();
    final myName = profile.name;
    final myIni  = profile.initials;

    return DebateRoom(
      id: roomId,
      title: roomName,
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
  // Symposium matchmaking
  // ---------------------------------------------------------------------------

  Future<void> publishToSymposiumPool() async {
    // Compute current badge to include in pool entry (visible to other users)
    String badgeId = AcroBadge.wanderer.name;
    if (isPermanentAccount) {
      final snap = await _db.ref('users/${profile.uid}').get();
      if (snap.exists) {
        final stats = Map<String, dynamic>.from(snap.value as Map);
        badgeId = BadgeEngine.fromStats(stats).name;
      }
    }
    await _db.ref('symposium_pool/${profile.uid}').set({
      'uid':     profile.uid,
      'name':    profile.name,
      'field':   profile.field,
      'interests': profile.interests,
      'quote':   profile.quote,
      'badgeId': badgeId,
      'ts':      ServerValue.timestamp,
    });
  }

  Future<void> removeFromSymposiumPool() async {
    await _db.ref('symposium_pool/${profile.uid}').remove();
  }

  Stream<List<Map<String, dynamic>>> symposiumPoolStream() {
    return _db.ref('symposium_pool').onValue.map((event) {
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

  Future<void> sendSymposiumRequest(String toUid) async {
    final reqId = _uuid.v4();
    await _db.ref('requests/$toUid/$reqId').set({
      'reqId': reqId,
      'fromUid': profile.uid,
      'fromName': profile.name,
      'fromField': profile.field,
      'fromInterests': profile.interests,
      'fromQuote': profile.quote,
      'ts': ServerValue.timestamp,
    });
  }

  Stream<List<Map<String, dynamic>>> requestsStream() {
    return _db.ref('requests/${profile.uid}').onValue.map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];
      final raw = event.snapshot.value;
      if (raw is! Map) return <Map<String, dynamic>>[];
      final data = Map<String, dynamic>.from(raw);
      return data.entries
          .map((e) => Map<String, dynamic>.from(e.value as Map))
          .toList()
        ..sort((a, b) =>
            ((a['ts'] ?? 0) as int).compareTo((b['ts'] ?? 0) as int));
    });
  }

  Future<void> acceptSymposiumRequest(Map<String, dynamic> req) async {
    final fromUid = req['fromUid'] as String;
    final fromName = req['fromName'] as String? ?? 'Anonymous';
    final fromIni = _initials(fromName);
    final reqId = req['reqId'] as String;
    final roomId = 'r${DateTime.now().millisecondsSinceEpoch}';

    await _db.ref().update({
      'requests/${profile.uid}/$reqId': null,
      'symposium_pool/${profile.uid}': null,
      'symposium_pool/$fromUid': null,
      'matches/${profile.uid}': {
        'roomId': roomId,
        'partnerId': fromUid,
        'partnerName': fromName,
        'partnerIni': fromIni,
        'isHost': true,
      },
      'matches/$fromUid': {
        'roomId': roomId,
        'partnerId': profile.uid,
        'partnerName': profile.name,
        'partnerIni': profile.initials,
        'isHost': false,
      },
      'rooms/$roomId': _buildRoomMap(roomId, 'Symposium'),
    });
  }

  Future<void> declineSymposiumRequest(String reqId) async {
    await _db.ref('requests/${profile.uid}/$reqId').remove();
  }

  // ---------------------------------------------------------------------------
  // Stoa argument rooms  (up to 10 per user)
  // ---------------------------------------------------------------------------

  Stream<List<Map<String, dynamic>>> stoaRoomsStream() {
    return _db.ref('stoa_rooms').onValue.map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];
      final raw = event.snapshot.value;
      if (raw is! Map) return <Map<String, dynamic>>[];
      return Map<String, dynamic>.from(raw)
          .values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList()
        ..sort((a, b) =>
            ((b['ts'] ?? 0) as int).compareTo((a['ts'] ?? 0) as int));
    });
  }

  Future<void> createStoaRoom({
    required String title,
    required String thesis,
    required String category,
  }) async {
    if (_myStoaRoomIds.length >= 10) return; // hard cap
    final roomId = 'stoa_${_uuid.v4()}';
    _myStoaRoomIds.add(roomId);
    await _db.ref('stoa_rooms/$roomId').set({
      'roomId':   roomId,
      'hostUid':  profile.uid,
      'hostName': profile.name,
      'hostIni':  profile.initials,
      'title':    title,
      'thesis':   thesis,
      'category': category,
      'ts':       ServerValue.timestamp,
    });
    // Track topic engagement for badge system
    if (isPermanentAccount && category.isNotEmpty) {
      _db.ref('users/${profile.uid}/topicEngagement/$category')
          .set(ServerValue.increment(1));
    }
    _ensureGlobalStoaWatch();
    notifyListeners();
  }

  Future<void> terminateStoaRoom(String roomId) async {
    // If this stoa room was matched, also mark the debate room as ended
    final debateSnap = await _db.ref('stoa_rooms/$roomId/debateRoomId').get();
    final debateId = debateSnap.value as String?;
    final updates = <String, dynamic>{'stoa_rooms/$roomId': null};
    if (debateId != null) updates['rooms/$debateId/live'] = false;
    await _db.ref().update(updates);

    _myStoaRoomIds.remove(roomId);
    _stoaToDebateRoom.removeWhere((_, v) => v == debateId);
    stoaNotifications.remove(roomId);
    if (_myStoaRoomIds.isEmpty) {
      _globalStoaWatcher?.cancel();
      _globalStoaWatcher = null;
    }
    notifyListeners();
  }

  void clearStoaNotification(String roomId) {
    stoaNotifications.remove(roomId);
    notifyListeners();
  }

  static const _greekTerms = [
    'Λόγος',    'Νόμος',    'Δίκη',     'Σοφία',    'Ἀρετή',
    'Πόλις',    'Δόξα',     'Ψυχή',     'Κόσμος',   'Κρίσις',
    'Εἰρήνη',  'Δύναμις',  'Φρόνησις', 'Θέσις',    'Μοῖρα',
    'Χάρις',    'Ἀγών',     'Ἔρως',     'Τύχη',     'Ἀρχή',
  ];

  String _greekRoomName() {
    final rng = math.Random();
    final a = _greekTerms[rng.nextInt(_greekTerms.length)];
    String b;
    do { b = _greekTerms[rng.nextInt(_greekTerms.length)]; } while (b == a);
    return '$a · $b';
  }

  Future<void> joinStoaRoom(Map<String, dynamic> room) async {
    final stoaRoomId = room['roomId']   as String;
    final hostUid    = room['hostUid']  as String;
    final hostName   = room['hostName'] as String? ?? 'Anonymous';
    final hostIni    = room['hostIni']  as String? ?? '?';
    final title      = room['title']    as String? ?? 'Argument';
    final category   = room['category'] as String? ?? '';

    // Track topic engagement for badge system
    if (isPermanentAccount && category.isNotEmpty) {
      _db.ref('users/${profile.uid}/topicEngagement/$category')
          .set(ServerValue.increment(1));
    }

    final debateRoomId = 'r${DateTime.now().millisecondsSinceEpoch}';
    final roomName     = _greekRoomName();
    await _db.ref().update({
      // Mark stoa card as matched + link debate room — card stays on the floor
      'stoa_rooms/$stoaRoomId/matched':       true,
      'stoa_rooms/$stoaRoomId/debateRoomId':  debateRoomId,
      'stoa_rooms/$stoaRoomId/challengerName': profile.name,
      'stoa_rooms/$stoaRoomId/challengerUid':  profile.uid,
      'matches/${profile.uid}': {
        'roomId':      debateRoomId,
        'partnerId':   hostUid,
        'partnerName': hostName,
        'partnerIni':  hostIni,
        'isHost':      false,
        'roomName':    roomName,
      },
      'matches/$hostUid': {
        'roomId':      debateRoomId,
        'partnerId':   profile.uid,
        'partnerName': profile.name,
        'partnerIni':  profile.initials,
        'isHost':      true,
        'stoaRoomId':  stoaRoomId,
        'roomName':    roomName,
      },
      'rooms/$debateRoomId': _buildRoomMap(debateRoomId, roomName),
    });
  }

  // Single watcher for all of this user's stoa rooms
  void _ensureGlobalStoaWatch() {
    if (_globalStoaWatcher != null) return;
    _globalStoaWatcher = _db.ref('matches/${profile.uid}').onValue.listen((event) {
      if (!event.snapshot.exists) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final stoaRoomId = data['stoaRoomId'] as String?;
      if (stoaRoomId == null) return;            // not a stoa-triggered match
      if (!_myStoaRoomIds.contains(stoaRoomId)) return; // not our room

      final partnerName = data['partnerName'] as String? ?? 'Someone';
      final room = buildRoomFromMatch(data);
      enterRoom(room);
      _stoaToDebateRoom[stoaRoomId] = room.id; // so host can re-enter later
      clearMatch();
      _myStoaRoomIds.remove(stoaRoomId);
      stoaNotifications[stoaRoomId] = partnerName;
      if (_myStoaRoomIds.isEmpty) {
        _globalStoaWatcher?.cancel();
        _globalStoaWatcher = null;
      }
      notifyListeners();

      _messengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(
          '⚖  $partnerName challenged your argument!',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
        action: SnackBarAction(
          label: 'ENTER DEBATE',
          onPressed: () => _enterRoomCallback?.call(),
        ),
        duration: const Duration(seconds: 20),
        backgroundColor: const Color(0xFF1A1200),
      ));
    });
  }

  // ---------------------------------------------------------------------------
  // Nominations — Stoa → Symposium Canon
  // ---------------------------------------------------------------------------

  bool get isPermanentAccount => firebaseUser != null;

  Future<void> nominateStoaRoom(Map<String, dynamic> room) async {
    final roomId = room['roomId'] as String? ?? '';
    if (roomId.isEmpty || !isPermanentAccount) return;

    final nomId = 'nom_${_uuid.v4()}';
    final hostUid = room['hostUid'] as String? ?? '';

    final updates = <String, dynamic>{
      'nominations/$nomId': {
        'nomId':            nomId,
        'roomId':           roomId,
        'title':            room['title']    ?? '',
        'thesis':           room['thesis']   ?? '',
        'category':         room['category'] ?? '',
        'hostUid':          hostUid,
        'hostName':         room['hostName'] ?? 'Anonymous',
        'nominatedBy':      profile.uid,
        'nominatedByName':  profile.name,
        'ts':               ServerValue.timestamp,
        'originalTs':       room['ts'] ?? 0,
      },
      'nomination_index/${profile.uid}/$roomId': nomId,
      'users/${profile.uid}/nominationsGiven': ServerValue.increment(1),
    };

    if (hostUid.isNotEmpty && hostUid != profile.uid) {
      updates['users/$hostUid/nominationsReceived'] = ServerValue.increment(1);
    }

    await _db.ref().update(updates);
  }

  // Live stream of this user's stat node (used by badge system + side menu)
  Stream<Map<String, dynamic>> userStatsStream() {
    if (!isPermanentAccount) return Stream.value({});
    return _db.ref('users/${profile.uid}').onValue.map((event) {
      if (!event.snapshot.exists) return <String, dynamic>{};
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  Future<bool> hasNominated(String roomId) async {
    if (!isPermanentAccount) return false;
    final snap =
        await _db.ref('nomination_index/${profile.uid}/$roomId').get();
    return snap.exists;
  }

  Stream<List<Map<String, dynamic>>> nominationsStream() {
    return _db.ref('nominations').onValue.map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];
      final raw = event.snapshot.value;
      if (raw is! Map) return <Map<String, dynamic>>[];
      return Map<String, dynamic>.from(raw)
          .values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList()
        ..sort((a, b) =>
            ((b['ts'] ?? 0) as int).compareTo((a['ts'] ?? 0) as int));
    });
  }

  Stream<Map<String, int>> nominationStatsStream() {
    if (!isPermanentAccount) {
      return Stream.value({'given': 0, 'received': 0});
    }
    return _db.ref('users/${profile.uid}').onValue.map((event) {
      if (!event.snapshot.exists) return {'given': 0, 'received': 0};
      final data =
          Map<String, dynamic>.from(event.snapshot.value as Map);
      return {
        'given':    (data['nominationsGiven']    as int?) ?? 0,
        'received': (data['nominationsReceived'] as int?) ?? 0,
      };
    });
  }

  // ---------------------------------------------------------------------------
  // Stoa viewer presence
  // ---------------------------------------------------------------------------

  Future<void> joinStoaViewer(String roomId) async {
    if (roomId.isEmpty) return;
    final ref = _db.ref('stoa_viewers/$roomId/${profile.uid}');
    await ref.set(true);
    await ref.onDisconnect().remove();
  }

  Future<void> leaveStoaViewer(String roomId) async {
    if (roomId.isEmpty) return;
    await _db.ref('stoa_viewers/$roomId/${profile.uid}').remove();
  }

  Stream<int> stoaViewerCountStream(String roomId, {String hostUid = ''}) {
    return _db.ref('stoa_viewers/$roomId').onValue.map((event) {
      if (!event.snapshot.exists) return 0;
      final raw = event.snapshot.value;
      if (raw is! Map) return 0;
      final count = raw.length;
      return hostUid.isNotEmpty && raw.containsKey(hostUid) ? count - 1 : count;
    });
  }

  // ---------------------------------------------------------------------------
  // Stoa quotes
  // ---------------------------------------------------------------------------

  Stream<List<Map<String, dynamic>>> stoaQuotesStream(String roomId) {
    return _db.ref('stoa_quotes/$roomId').onValue.map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];
      final raw = event.snapshot.value;
      if (raw is! Map) return <Map<String, dynamic>>[];
      return Map<String, dynamic>.from(raw)
          .values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList()
        ..sort((a, b) =>
            ((b['bumps'] ?? 0) as int).compareTo((a['bumps'] ?? 0) as int));
    });
  }

  Future<void> addStoaQuote(String roomId, String text) async {
    final qId = 'q_${_uuid.v4()}';
    await _db.ref('stoa_quotes/$roomId/$qId').set({
      'quoteId':    qId,
      'text':       text,
      'authorUid':  profile.uid,
      'authorName': profile.name.isNotEmpty ? profile.name : 'Anonymous',
      'bumps':      0,
      'ts':         ServerValue.timestamp,
    });
    // Track quote count for badge system
    if (isPermanentAccount) {
      _db.ref('users/${profile.uid}/quoteCount').set(ServerValue.increment(1));
    }
  }

  Future<void> bumpStoaQuote(
      String roomId, String quoteId, bool currentlyBumped) async {
    final bumpRef =
        _db.ref('stoa_quote_bumps/$roomId/${profile.uid}/$quoteId');
    final quoteRef = _db.ref('stoa_quotes/$roomId/$quoteId/bumps');
    if (currentlyBumped) {
      await Future.wait([bumpRef.remove(),
          quoteRef.set(ServerValue.increment(-1))]);
    } else {
      await Future.wait([bumpRef.set(true),
          quoteRef.set(ServerValue.increment(1))]);
    }
  }

  Future<Set<String>> getUserBumps(String roomId) async {
    final snap =
        await _db.ref('stoa_quote_bumps/$roomId/${profile.uid}').get();
    if (!snap.exists) return {};
    final raw = snap.value;
    if (raw is! Map) return {};
    return Map<String, dynamic>.from(raw).keys.toSet();
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
