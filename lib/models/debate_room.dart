class RoomPerms {
  final bool mute;
  final bool hand;
  final bool kick;
  final bool record;

  const RoomPerms({
    this.mute = true,
    this.hand = false,
    this.kick = true,
    this.record = false,
  });

  factory RoomPerms.fromMap(Map map) => RoomPerms(
        mute: map['mute'] ?? true,
        hand: map['hand'] ?? false,
        kick: map['kick'] ?? true,
        record: map['rec'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'mute': mute,
        'hand': hand,
        'kick': kick,
        'rec': record,
      };
}

class RoomMember {
  final String name;
  final String initials;
  final bool isHost;
  bool muted;
  bool handRaised;

  RoomMember({
    required this.name,
    required this.initials,
    this.isHost = false,
    this.muted = false,
    this.handRaised = false,
  });
}

class DebateRoom {
  final String id;
  final String title;
  final String desc;
  final String host;
  final String hostInitials;
  final String category;
  final int capacity;
  final String duration;
  final int durationSeconds;
  final bool isLive;
  int guestCount;
  final RoomPerms perms;
  bool isHost;
  bool isSpectator;
  List<RoomMember> members;

  DebateRoom({
    required this.id,
    required this.title,
    this.desc = '',
    required this.host,
    required this.hostInitials,
    this.category = 'Philosophy',
    this.capacity = 2,
    this.duration = 'Open',
    this.durationSeconds = 0,
    this.isLive = false,
    this.guestCount = 0,
    this.perms = const RoomPerms(),
    this.isHost = false,
    this.isSpectator = false,
    this.members = const [],
  });

  bool get isFull => guestCount >= capacity - 1;

  String get sizeLabel {
    if (capacity == 2) return '1-on-1';
    if (capacity <= 4) return 'Small Group';
    return 'Forum';
  }

  factory DebateRoom.fromMap(String id, Map map) => DebateRoom(
        id: id,
        title: map['title'] ?? '',
        desc: map['desc'] ?? '',
        host: map['host'] ?? '',
        hostInitials: map['hIni'] ?? '?',
        category: map['cat'] ?? 'Philosophy',
        capacity: map['cap'] ?? 2,
        duration: map['dur'] ?? 'Open',
        durationSeconds: map['durS'] ?? 0,
        isLive: map['live'] ?? false,
        guestCount: map['guests'] ?? 0,
        perms: map['perms'] != null
            ? RoomPerms.fromMap(map['perms'])
            : const RoomPerms(),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'desc': desc,
        'host': host,
        'hIni': hostInitials,
        'cat': category,
        'cap': capacity,
        'dur': duration,
        'durS': durationSeconds,
        'live': true,
        'guests': 0,
        'perms': perms.toMap(),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
}

// Demo rooms matching the HTML version
final demoRooms = [
  DebateRoom(
    id: 'dr1',
    title: 'Free Will is an Illusion',
    desc: 'Determinism leaves no room for genuine agency. Neuroscience confirms this.',
    host: 'Marcus A.',
    hostInitials: 'MA',
    category: 'Philosophy',
    capacity: 2,
    duration: '15 min',
    durationSeconds: 900,
    isLive: true,
    guestCount: 1,
    perms: RoomPerms(mute: true, hand: false, kick: true, record: false),
  ),
  DebateRoom(
    id: 'dr2',
    title: 'Democracy is Self-Defeating',
    desc: 'Uninformed mass voting undermines the outcomes democracy is meant to produce.',
    host: 'Dr. Yuki T.',
    hostInitials: 'YT',
    category: 'Politics',
    capacity: 6,
    duration: '30 min',
    durationSeconds: 1800,
    isLive: false,
    guestCount: 3,
    perms: RoomPerms(mute: true, hand: true, kick: true, record: true),
  ),
  DebateRoom(
    id: 'dr3',
    title: 'AGI surpasses human moral reasoning',
    desc: 'An open-ended exploration of machine ethics and emergent values.',
    host: 'Ravi S.',
    hostInitials: 'RS',
    category: 'Technology',
    capacity: 8,
    duration: 'Open',
    durationSeconds: 0,
    isLive: true,
    guestCount: 5,
    perms: RoomPerms(mute: false, hand: true, kick: false, record: true),
  ),
  DebateRoom(
    id: 'dr4',
    title: 'Stoicism is superior philosophy for modern life',
    desc: '1-on-1 structured argument. Host argues PRO, guest argues CON.',
    host: 'Elena R.',
    hostInitials: 'ER',
    category: 'Philosophy',
    capacity: 2,
    duration: '5 min',
    durationSeconds: 300,
    isLive: false,
    guestCount: 0,
    perms: RoomPerms(mute: true, hand: false, kick: true, record: false),
  ),
];
