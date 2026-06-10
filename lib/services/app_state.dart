import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show GlobalKey, NavigatorState, ScaffoldMessengerState;
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

  // Last page the user was on — restored after a browser refresh
  String restoredPage = '';

  // HostWaitScreen room saved for refresh restore
  Map<String, dynamic>? restoredHostWaitRoom;

  // Debate room cache — survives leaveRoom() so users can re-enter
  final Map<String, DebateRoom> _roomCache = {};
  // stoaRoomId → debateRoomId — lets side menu re-enter from stoa tile
  final Map<String, String> _stoaToDebateRoom = {};

  // Stoa argument rooms (up to 10 active at once)
  final List<String> _myStoaRoomIds = [];
  // Per-room join watchers — one per active stoa room, watches stoa_room_joins/$id
  final Map<String, StreamSubscription> _stoaJoinWatchers = {};

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
    ready = _init();
  }

  // Completes when _init() finishes — used by AcropolisMapScreen to know
  // when the persisted room (if any) has been restored to currentRoom.
  late final Future<void> ready;

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
    // Restore in-memory stoa state from Firebase so re-entry and
    // match notifications work correctly after a page refresh.
    if (profile.name.isNotEmpty) {
      _restoreStoaState();
    }
  }

  Future<void> _restoreStoaState() async {
    try {
      final snap = await _db.ref('stoa_rooms').get();
      if (!snap.exists || snap.value == null) return;
      final raw = snap.value;
      if (raw is! Map) return;

      for (final entry in raw.entries) {
        final data = entry.value;
        if (data is! Map) continue;
        final hostUid = data['hostUid'] as String?;
        if (hostUid != profile.uid) continue;

        final roomId   = data['roomId'] as String? ?? entry.key.toString();
        // debateRoomId is deterministic; fall back to stored value for old rooms
        final debateId = data['debateRoomId'] as String? ?? 'dr_$roomId';

        if (!_myStoaRoomIds.contains(roomId)) {
          _myStoaRoomIds.add(roomId);
        }
        _stoaToDebateRoom[roomId] = debateId;
      }

      if (_myStoaRoomIds.isNotEmpty) {
        for (final id in List.of(_myStoaRoomIds)) {
          _startStoaRoomWatch(id);
        }
        notifyListeners();
      }
    } catch (_) {
      // Non-fatal — stoa state will rebuild naturally on user interaction
    }
  }

  // ── Local storage ────────────────────────────────────────────────────────

  static const _kUid        = 'acro_uid';
  static const _kName       = 'acro_name';
  static const _kField      = 'acro_field';
  static const _kInterests  = 'acro_interests';
  static const _kQuote      = 'acro_quote';
  // Persisted active room — survives a page refresh
  static const _kRoomId     = 'acro_room_id';
  static const _kRoomTitle  = 'acro_room_title';
  static const _kRoomPrtNm  = 'acro_room_prt_nm';
  static const _kRoomPrtIni = 'acro_room_prt_ini';
  // Persisted active page (stoa / agora / acropolis)
  static const _kPage          = 'acro_page';
  // Persisted HostWaitScreen room — survives a page refresh
  static const _kHostWaitId    = 'acro_hwait_id';
  static const _kHostWaitTitle = 'acro_hwait_title';
  static const _kHostWaitThesis = 'acro_hwait_thesis';
  static const _kHostWaitCat   = 'acro_hwait_cat';

  Future<void> _loadLocalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName) ?? '';
    if (name.isEmpty) return;
    profile.uid       = prefs.getString(_kUid) ?? profile.uid;
    profile.name      = name;
    profile.field     = prefs.getString(_kField) ?? '';
    profile.interests = prefs.getStringList(_kInterests) ?? [];
    profile.quote     = prefs.getString(_kQuote) ?? '';

    // Restore room the user was in before the page refresh
    final roomId = prefs.getString(_kRoomId) ?? '';
    if (roomId.isNotEmpty) {
      reenterRoom(
        roomId,
        title:       prefs.getString(_kRoomTitle)  ?? 'Debate',
        partnerName: prefs.getString(_kRoomPrtNm)  ?? '',
        partnerIni:  prefs.getString(_kRoomPrtIni) ?? '?',
      );
    }

    // Restore last-visited page (stoa / agora / acropolis)
    restoredPage = prefs.getString(_kPage) ?? '';

    // Restore HostWaitScreen if the user was there before the refresh
    final hwaitId = prefs.getString(_kHostWaitId) ?? '';
    if (hwaitId.isNotEmpty) {
      restoredHostWaitRoom = {
        'roomId':   hwaitId,
        'title':    prefs.getString(_kHostWaitTitle)   ?? '',
        'thesis':   prefs.getString(_kHostWaitThesis)  ?? '',
        'category': prefs.getString(_kHostWaitCat)     ?? '',
      };
    }

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

  void _saveCurrentRoom(DebateRoom room) {
    SharedPreferences.getInstance().then((prefs) {
      final partner = room.members.where((m) => m.name != profile.name).toList();
      prefs.setString(_kRoomId,     room.id);
      prefs.setString(_kRoomTitle,  room.title);
      prefs.setString(_kRoomPrtNm,  partner.isNotEmpty ? partner.first.name     : '');
      prefs.setString(_kRoomPrtIni, partner.isNotEmpty ? partner.first.initials : '?');
    });
  }

  void _clearSavedRoom() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_kRoomId);
      prefs.remove(_kRoomTitle);
      prefs.remove(_kRoomPrtNm);
      prefs.remove(_kRoomPrtIni);
    });
  }

  void saveLastPage(String page) {
    SharedPreferences.getInstance().then((p) => p.setString(_kPage, page));
  }

  void clearLastPage() {
    restoredPage = '';
    SharedPreferences.getInstance().then((p) => p.remove(_kPage));
  }

  void saveHostWaitRoom(Map<String, dynamic> room) {
    SharedPreferences.getInstance().then((p) {
      p.setString(_kHostWaitId,    room['roomId']   as String? ?? '');
      p.setString(_kHostWaitTitle, room['title']    as String? ?? '');
      p.setString(_kHostWaitThesis, room['thesis']  as String? ?? '');
      p.setString(_kHostWaitCat,   room['category'] as String? ?? '');
    });
  }

  void clearHostWaitRoom() {
    restoredHostWaitRoom = null;
    SharedPreferences.getInstance().then((p) {
      p.remove(_kHostWaitId);
      p.remove(_kHostWaitTitle);
      p.remove(_kHostWaitThesis);
      p.remove(_kHostWaitCat);
    });
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
    // Migrate any stoa rooms created under the temp uid to the Firebase uid
    final tempRooms = List<String>.of(_myStoaRoomIds);
    profile.uid = user.uid;
    await _saveLocalProfile();
    for (final roomId in tempRooms) {
      _db.ref('stoa_rooms/$roomId/hostUid').set(user.uid);
    }
    // Reset and re-subscribe stoa watchers under the new uid
    for (final sub in _stoaJoinWatchers.values) sub.cancel();
    _stoaJoinWatchers.clear();
    _myStoaRoomIds..clear()..addAll(tempRooms);
    for (final id in tempRooms) _startStoaRoomWatch(id);
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
    if (!room.isSpectator) _saveCurrentRoom(room);
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
      // _stoaToDebateRoom only contains rooms where this user is the host,
      // so a membership check gives us the correct role without a Firebase round-trip.
      final isKnownHost = _stoaToDebateRoom.values.contains(roomId);
      currentRoom = DebateRoom(
        id: roomId,
        title: title,
        host:         isKnownHost ? profile.name     : (partnerName.isNotEmpty ? partnerName : profile.name),
        hostInitials: isKnownHost ? profile.initials : (partnerName.isNotEmpty ? partnerIni  : profile.initials),
        isHost: isKnownHost,
        members: [
          RoomMember(name: profile.name, initials: profile.initials, isHost: isKnownHost),
          if (partnerName.isNotEmpty)
            RoomMember(name: partnerName, initials: partnerIni, isHost: !isKnownHost),
        ],
      );
    }

    // Always verify host identity — the cached path skips the else block
    // but endRoomFB may have set live=false when the host left.
    // Writing live=true must happen every re-entry, not just on cache miss.
    _db.ref('rooms/$roomId/hostUid').get().then((snap) {
      if (snap.value != profile.uid || currentRoom?.id != roomId) return;
      // Restore room for guests — without this they are immediately ejected.
      _db.ref('rooms/$roomId/live').set(true);
      if (currentRoom?.isHost != true) {
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

    _roomEnterTime = DateTime.now();
    // Persist so the room is restored on the NEXT refresh even if the user
    // got here via the side menu (which doesn't go through enterRoom).
    if (currentRoom != null && !currentRoom!.isSpectator) {
      _saveCurrentRoom(currentRoom!);
    }
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
    _clearSavedRoom();
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
          ..sort((a, b) {
            final aTs = ((a.value as Map)['ts'] as num?)?.toInt() ?? 0;
            final bTs = ((b.value as Map)['ts'] as num?)?.toInt() ?? 0;
            return aTs.compareTo(bTs);
          });
        for (final e in entries) {
          final m = Map<String, dynamic>.from(e.value as Map);
          m['_fbKey'] = e.key.toString();
          msgs.add(m);
        }
      }
      onMessages(msgs);
    });
  }

  Future<void> sendRoomSystemEventFB(String roomId, String name, String ini, String msg) async {
    if (roomId.isEmpty) return;
    try {
      await _db.ref('rchats/$roomId').push().set({
        'name': name,
        'ini':  ini,
        'msg':  msg,
        'type': 'system',
        'ts':   DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<void> sendHandRaiseEventFB(String roomId, String name, String ini) async {
    if (roomId.isEmpty) return;
    try {
      await _db.ref('rchats/$roomId').push().set({
        'name': name,
        'ini':  ini,
        'msg':  'raised their hand',
        'type': 'hand_raise',
        'ts':   DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
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

  Future<void> pinRoomMessageFB(String roomId, String fbKey, bool pinned) async {
    try {
      await _db.ref('rchats/$roomId/$fbKey').update({'pinned': pinned});
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
    final idx = posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    posts[idx].arguments = [...posts[idx].arguments, arg];
    posts[idx].replyCount++;
    notifyListeners();
  }

  void addChatMessage(String postId, ChatMessage msg) {
    final idx = posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    posts[idx].chats = [...posts[idx].chats, msg];
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Match streams (shared by Agora + Stoa)
  // ---------------------------------------------------------------------------

  Stream<Map<String, dynamic>?> matchStream() {
    return _db.ref('matches/${profile.uid}').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      if (data['handled'] == true) return null;
      return data;
    });
  }

  // Marks the match notification as handled without deleting it, so the
  // room remains visible on the floor for spectators.
  Future<void> markMatchHandled() async {
    await _db.ref('matches/${profile.uid}/handled').set(true);
  }

  Future<void> joinAsSpectator(String roomId, String title) async {
    final room = DebateRoom(
      id: roomId,
      title: title,
      host: '',
      hostInitials: '?',
      isHost: false,
      isSpectator: true,
      members: [RoomMember(name: profile.name, initials: profile.initials)],
    );
    enterRoom(room);
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
        'cap': 4,
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
    final roomId      = matchData['roomId']      as String? ?? '';
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
    final roomId      = 'stoa_${_uuid.v4()}';
    final debateRoomId = 'dr_$roomId'; // deterministic — no race on first challenger
    _myStoaRoomIds.add(roomId);
    // Create the stoa card and the debate room together so the debateRoomId
    // is always present before any challenger joins.
    await _db.ref().update({
      'stoa_rooms/$roomId': {
        'roomId':      roomId,
        'debateRoomId': debateRoomId,
        'hostUid':     profile.uid,
        'hostName':    profile.name,
        'hostIni':     profile.initials,
        'title':       title,
        'thesis':      thesis,
        'category':    category,
        'ts':          ServerValue.timestamp,
      },
      'rooms/$debateRoomId': {
        'title':     title,
        'desc':      thesis,
        'host':      profile.name,
        'hIni':      profile.initials,
        'hostUid':   profile.uid,
        'cat':       category,
        'cap':       4,
        'dur':       'Open',
        'durS':      0,
        'live':      true,
        'guests':    0,
        'perms':     const RoomPerms().toMap(),
        'createdAt': ServerValue.timestamp,
      },
    });
    if (isPermanentAccount && category.isNotEmpty) {
      _db.ref('users/${profile.uid}/topicEngagement/$category')
          .set(ServerValue.increment(1));
    }
    _startStoaRoomWatch(roomId);
    notifyListeners();
  }

  Future<void> terminateStoaRoom(String roomId) async {
    // debateRoomId is always 'dr_$roomId' since createStoaRoom now pre-creates it.
    // Fall back to a Firebase read only if the room predates this change.
    final debateId = 'dr_$roomId';
    await _db.ref().update({
      'stoa_rooms/$roomId':      null,
      'stoa_room_joins/$roomId': null,
      'rooms/$debateId/live':    false,
    });

    _stoaJoinWatchers[roomId]?.cancel();
    _stoaJoinWatchers.remove(roomId);
    _myStoaRoomIds.remove(roomId);
    _stoaToDebateRoom.removeWhere((_, v) => v == debateId);
    stoaNotifications.remove(roomId);
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
    final stoaRoomId = room['roomId']   as String? ?? '';
    final hostUid    = room['hostUid']  as String? ?? '';
    if (stoaRoomId.isEmpty || hostUid.isEmpty) return;
    final hostName   = room['hostName'] as String? ?? 'Anonymous';
    final hostIni    = room['hostIni']  as String? ?? '?';
    final category   = room['category'] as String? ?? '';

    if (isPermanentAccount && category.isNotEmpty) {
      _db.ref('users/${profile.uid}/topicEngagement/$category')
          .set(ServerValue.increment(1));
    }

    // debateRoomId is always set by createStoaRoom — deterministic, no race.
    final debateRoomId = room['debateRoomId'] as String? ?? 'dr_$stoaRoomId';
    final roomName     = room['title'] as String? ?? _greekRoomName();

    // Use server-side increment so simultaneous challengers don't corrupt the count.
    // isFull is best-effort from the local snapshot — worst case one extra person
    // slips in, which the host's watcher will correct by setting matched:true.
    final prevCount = room['challengerCount'] as int? ?? 0;
    final isFull    = prevCount + 1 >= 3;

    await _db.ref().update({
      'stoa_rooms/$stoaRoomId/challengers/${profile.uid}': {
        'name': profile.name, 'ini': profile.initials,
      },
      'stoa_rooms/$stoaRoomId/challengerCount': ServerValue.increment(1),
      if (isFull) 'stoa_rooms/$stoaRoomId/matched': true,

      // Notify this challenger
      'matches/${profile.uid}': {
        'roomId':      debateRoomId,
        'partnerId':   hostUid,
        'partnerName': hostName,
        'partnerIni':  hostIni,
        'isHost':      false,
        'roomName':    roomName,
      },

      // Notify the host via per-room join queue
      'stoa_room_joins/$stoaRoomId/${profile.uid}': {
        'uid':          profile.uid,
        'name':         profile.name,
        'ini':          profile.initials,
        'debateRoomId': debateRoomId,
        'ts':           ServerValue.timestamp,
      },

      // Increment guest count on the debate room that the host pre-created
      'rooms/$debateRoomId/guests': ServerValue.increment(1),
    });

    // Write presence immediately so the host's roomPresenceStream fires in real-time
    // and their grid tile appears without waiting for the challenger to enter RoomScreen.
    await writeRoomPresence(debateRoomId, isHost: false);
  }

  // Per-room watcher: subscribes to stoa_room_joins/$stoaRoomId.onChildAdded.
  // Pre-loads existing join keys so it only fires for NEW challengers.
  void _startStoaRoomWatch(String stoaRoomId) {
    if (_stoaJoinWatchers.containsKey(stoaRoomId)) return;

    // Pre-load existing joins to suppress replay on subscribe
    _db.ref('stoa_room_joins/$stoaRoomId').get().then((snap) {
      if (_stoaJoinWatchers.containsKey(stoaRoomId)) return;

      final Set<String> knownJoins = {};
      if (snap.exists && snap.value is Map) {
        knownJoins.addAll(
            (snap.value as Map).keys.map((k) => k.toString()));
      }

      _stoaJoinWatchers[stoaRoomId] = _db
          .ref('stoa_room_joins/$stoaRoomId')
          .onChildAdded
          .listen((event) {
        final uid = event.snapshot.key?.toString() ?? '';
        if (knownJoins.contains(uid)) return; // already existed before subscribe
        knownJoins.add(uid);

        final raw = event.snapshot.value;
        if (raw is! Map) return;
        final partnerName  = raw['name']         as String? ?? 'Someone';
        final partnerIni   = raw['ini']          as String? ?? '?';
        final debateRoomId = raw['debateRoomId'] as String?;
        if (debateRoomId == null) return;

        _stoaToDebateRoom[stoaRoomId] = debateRoomId;
        stoaNotifications[stoaRoomId] = partnerName;

        if (currentRoom != null && currentRoom!.id == debateRoomId) {
          // Already inside this debate — add the new member without re-navigating
          final alreadyListed =
              currentRoom!.members.any((m) => m.name == partnerName);
          if (!alreadyListed) {
            currentRoom = DebateRoom(
              id:            currentRoom!.id,
              title:         currentRoom!.title,
              host:          currentRoom!.host,
              hostInitials:  currentRoom!.hostInitials,
              isHost:        currentRoom!.isHost,
              members:       [...currentRoom!.members,
                               RoomMember(name: partnerName, initials: partnerIni)],
            );
          }
        } else if (currentRoom == null) {
          enterRoom(DebateRoom(
            id:           debateRoomId,
            title:        debateRoomId,
            host:         profile.name,
            hostInitials: profile.initials,
            isHost:       true,
            members: [
              RoomMember(name: profile.name, initials: profile.initials, isHost: true),
              RoomMember(name: partnerName,  initials: partnerIni),
            ],
          ));
        }
        notifyListeners();
        // Auto-enter immediately — no host permission step required.
        _enterRoomCallback?.call();
      });
    }).catchError((_) {});
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
  // Room presence — drives live member list in RoomScreen
  // ---------------------------------------------------------------------------

  Future<void> writeRoomPresence(String roomId, {required bool isHost}) async {
    if (roomId.isEmpty) return;
    final ref = _db.ref('rooms/$roomId/presence/${profile.uid}');
    final data = {'name': profile.name, 'ini': profile.initials, 'isHost': isHost, 'camOn': true};
    await ref.set(data);
    await ref.onDisconnect().remove();
    // The previous browser tab registers an onDisconnect that removes presence.
    // If it fires after we've written new presence it silently deletes our entry.
    // Re-write after 2 s if presence is gone and we're still in this room.
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        if (currentRoom?.id != roomId) return;
        final snap = await ref.get();
        if (!snap.exists) {
          await ref.set(data);
          await ref.onDisconnect().remove();
        }
      } catch (_) {}
    });
  }

  Future<void> updateCameraPresenceFB(String roomId, bool camOn) async {
    if (roomId.isEmpty) return;
    try {
      await _db.ref('rooms/$roomId/presence/${profile.uid}/camOn').set(camOn);
    } catch (_) {}
  }

  Future<void> leaveRoomFB(String roomId) async {
    if (roomId.isEmpty) return;
    await _db.ref('rooms/$roomId/presence/${profile.uid}').remove();
  }

  Future<void> endRoomFB(String roomId) async {
    if (roomId.isEmpty) return;
    await _db.ref('rooms/$roomId/live').set(false);
  }

  Stream<bool> roomLiveStream(String roomId) {
    return _db.ref('rooms/$roomId/live').onValue.map((event) {
      // If the field hasn't arrived yet, assume the room is still live.
      // Only eject when Firebase explicitly delivers live = false.
      if (!event.snapshot.exists) return true;
      return event.snapshot.value == true;
    });
  }

  Stream<int> roomPresenceCountStream(String roomId) {
    return _db.ref('rooms/$roomId/presence').onValue.map((event) {
      if (!event.snapshot.exists) return 0;
      final raw = event.snapshot.value;
      return raw is Map ? raw.length : 0;
    });
  }

  Stream<List<RoomMember>> roomPresenceStream(String roomId) {
    return _db.ref('rooms/$roomId/presence').onValue.map((event) {
      if (!event.snapshot.exists) return <RoomMember>[];
      final raw = event.snapshot.value;
      if (raw is! Map) return <RoomMember>[];
      return Map<String, dynamic>.from(raw).values.map((v) {
        final m = Map<String, dynamic>.from(v as Map);
        return RoomMember(
          name:     m['name']   as String? ?? 'Unknown',
          initials: m['ini']    as String? ?? '?',
          isHost:   m['isHost'] as bool?   ?? false,
          camOn:    m['camOn']  as bool?   ?? true,
        );
      }).toList();
    });
  }

  void updateRoomMembers(String roomId, List<RoomMember> members) {
    if (currentRoom?.id != roomId || members.isEmpty) return;
    currentRoom = DebateRoom(
      id:              currentRoom!.id,
      title:           currentRoom!.title,
      desc:            currentRoom!.desc,
      host:            currentRoom!.host,
      hostInitials:    currentRoom!.hostInitials,
      category:        currentRoom!.category,
      capacity:        currentRoom!.capacity,
      duration:        currentRoom!.duration,
      durationSeconds: currentRoom!.durationSeconds,
      isLive:          currentRoom!.isLive,
      guestCount:      currentRoom!.guestCount,
      perms:           currentRoom!.perms,
      isHost:          currentRoom!.isHost,
      isSpectator:     currentRoom!.isSpectator,
      members:         members,
    );
    // Keep cache current so re-entry via reenterRoom() starts with the live member list
    _roomCache[roomId] = currentRoom!;
    notifyListeners();
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
}
