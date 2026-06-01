import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/debate_room.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/room_card.dart';
import 'room_screen.dart';
import 'app_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Philosophy';
  int _capacity = 2;
  String _duration = '1 min';
  bool _pMute = true, _pHand = false, _pKick = true, _pRec = false;

  final _durations = ['1 min', '5 min', '15 min', '30 min', '1 hour', 'Open'];
  final _categories = ['Philosophy', 'Science', 'Politics', 'Ethics', 'Economics', 'History'];
  final _durationMap = {
    '1 min': 60, '5 min': 300, '15 min': 900,
    '30 min': 1800, '1 hour': 3600, 'Open': 0
  };
  final _filters = ['all', '1v1', 'small', 'group', 'live', 'open', 'short'];
  final _filterLabels = {
    'all': 'All', '1v1': '1-on-1', 'small': 'Small (≤4)',
    'group': 'Group (5+)', 'live': '🔴 Live', 'open': '⏾ Open', 'short': '⚡ Short'
  };

  String get _capLabel {
    if (_capacity == 2) return 'One-on-One Debate';
    if (_capacity <= 4) return 'Small Group';
    if (_capacity <= 8) return 'Open Forum';
    return 'Large Auditorium';
  }

  void _createRoom() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a debate topic.')));
      return;
    }
    final state = context.read<AppState>();
    final room = DebateRoom(
      id: 'r${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      desc: _descCtrl.text.trim(),
      host: state.profile.name,
      hostInitials: state.profile.initials,
      category: _category,
      capacity: _capacity,
      duration: _duration,
      durationSeconds: _durationMap[_duration] ?? 0,
      isLive: true,
      isHost: true,
      perms: RoomPerms(mute: _pMute, hand: _pHand, kick: _pKick, record: _pRec),
      members: [
        RoomMember(
            name: state.profile.name,
            initials: state.profile.initials,
            isHost: true)
      ],
    );
    state.enterRoom(room);
    state.createRoomFB(room);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    const isHost = true;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        title: Text('ACRO',
            style: GoogleFonts.playfairDisplay(
                color: AcroColors.gold, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 2)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppScreen())),
            icon: const Icon(Icons.dashboard, size: 16, color: AcroColors.gold),
            label: const Text('Feed', style: TextStyle(color: AcroColors.gold)),
          ),
          const SizedBox(width: 8),
          AcroAvatar(initials: state.profile.initials, size: 28),
          const SizedBox(width: 8),
          Text(state.profile.firstName,
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Host config panel (host only)
          if (isHost)
            Container(
              width: 320,
              decoration: BoxDecoration(
                border: Border(
                    right: BorderSide(color: AcroColors.gold.withOpacity(0.12))),
              ),
              child: _buildHostConfig(),
            ),

          // Rooms list
          Expanded(child: _buildRoomsList(state)),
        ],
      ),
    );
  }

  Widget _buildHostConfig() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Open a Debate Room',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 17, color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Configure your intellectual arena',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35))),
          const SizedBox(height: 20),

          _cfgLabel('Debate Topic / Thesis'),
          _cfgInput(_titleCtrl, "e.g. 'Free will is incompatible with determinism'"),
          _cfgLabel('Brief Description'),
          _cfgInput(_descCtrl, 'Context, opening position, or ground rules…', multiline: true),

          _cfgLabel('Category'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _categories.map((c) => _chip(c, _category == c, () => setState(() => _category = c))).toList(),
          ),
          const SizedBox(height: 14),

          _cfgLabel('Room Capacity'),
          Center(
            child: Text('$_capacity',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 34, color: AcroColors.gold, fontWeight: FontWeight.w700)),
          ),
          Center(
            child: Text(_capLabel,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35))),
          ),
          Slider(
            value: _capacity.toDouble(),
            min: 2, max: 12, divisions: 10,
            activeColor: AcroColors.gold,
            inactiveColor: AcroColors.gold.withOpacity(0.2),
            onChanged: (v) => setState(() => _capacity = v.toInt()),
          ),

          _cfgLabel('Debate Duration'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _durations.map((d) => _chip(d, _duration == d, () => setState(() => _duration = d))).toList(),
          ),
          const SizedBox(height: 14),

          _cfgLabel('Host Permissions'),
          _permRow('Mute guests', 'Host can silence any participant', _pMute, (v) => setState(() => _pMute = v)),
          _permRow('Approve to speak', 'Guests must raise hand first', _pHand, (v) => setState(() => _pHand = v)),
          _permRow('Remove participants', 'Host can kick disruptive guests', _pKick, (v) => setState(() => _pKick = v)),
          _permRow('Record session', 'Save debate transcript', _pRec, (v) => setState(() => _pRec = v)),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createRoom,
              icon: const Icon(Icons.meeting_room),
              label: const Text('Open Debate Room'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AcroColors.gold,
                foregroundColor: AcroColors.stone,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsList(AppState state) {
    final rooms = state.filteredRooms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open Rooms',
                style: GoogleFonts.playfairDisplay(fontSize: 15, color: Colors.white),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final active = state.roomFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(_filterLabels[f]!,
                            style: TextStyle(
                                fontSize: 11,
                                color: active ? AcroColors.gold : Colors.white38)),
                        selected: active,
                        onSelected: (_) => state.setRoomFilter(f),
                        backgroundColor: Colors.transparent,
                        selectedColor: AcroColors.gold.withOpacity(0.1),
                        side: BorderSide(
                            color: active ? AcroColors.gold : AcroColors.gold.withOpacity(0.18)),
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 44, color: AcroColors.gold.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Text('No rooms match this filter.\nBe the first to open one!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white24)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: rooms.length,
                  itemBuilder: (_, i) => RoomCard(
                    room: rooms[i],
                    onJoin: () {
                      final r = rooms[i];
                      final mems = [
                        RoomMember(name: r.host, initials: r.hostInitials, isHost: true),
                        RoomMember(name: state.profile.name, initials: state.profile.initials),
                      ];
                      state.enterRoom(DebateRoom(
                        id: r.id, title: r.title, desc: r.desc,
                        host: r.host, hostInitials: r.hostInitials,
                        category: r.category, capacity: r.capacity,
                        duration: r.duration, durationSeconds: r.durationSeconds,
                        isLive: r.isLive, guestCount: r.guestCount,
                        perms: r.perms, isHost: false, members: mems,
                      ));
                      state.joinRoomFB(r.id);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomScreen()));
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _cfgLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.45), letterSpacing: 1)),
      );

  Widget _cfgInput(TextEditingController ctrl, String hint, {bool multiline = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
          maxLines: multiline ? 3 : 1,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.22), fontSize: 12),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.18)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.18)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AcroColors.gold),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          ),
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AcroColors.gold.withOpacity(0.15) : Colors.transparent,
            border: Border.all(
                color: selected ? AcroColors.gold : AcroColors.gold.withOpacity(0.18)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: selected ? AcroColors.gold : Colors.white.withOpacity(0.45))),
        ),
      );

  Widget _permRow(String name, String desc, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                  Text(desc, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3))),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AcroColors.gold,
            ),
          ],
        ),
      );
}
