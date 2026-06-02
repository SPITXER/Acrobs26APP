import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';

/// End-drawer ledger — open debates, stoa rooms, notifications, terminate.
class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, state, _) {
      if (state.profile.name.isEmpty) return const SizedBox.shrink();
      return Drawer(
        backgroundColor: const Color(0xFF080C14),
        child: SafeArea(
          child: Column(children: [
            _Header(state: state),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                _Section(label: 'YOUR STOA ROOMS'),
                _StoaRooms(state: state),
                _Section(label: 'ACTIVE DEBATES'),
                _ActiveDebates(state: state),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}

// ── Drawer trigger button — shows badge when notifications pending ─────────

class SideMenuButton extends StatelessWidget {
  const SideMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, state, _) {
      if (state.profile.name.isEmpty) return const SizedBox.shrink();
      final count = state.stoaNotificationCount;
      return Stack(alignment: Alignment.topRight, children: [
        IconButton(
          icon: const Icon(Icons.menu_open_rounded, color: AcroColors.gold),
          tooltip: 'My Ledger',
          onPressed: () => Scaffold.of(context).openEndDrawer(),
        ),
        if (count > 0)
          Positioned(
            top: 8, right: 8,
            child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Colors.orangeAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AppState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AcroColors.gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AcroColors.gold.withOpacity(0.40)),
          ),
          child: Center(
            child: Text(state.profile.initials,
                style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AcroColors.gold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.profile.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            if (state.profile.field.isNotEmpty)
              Text(state.profile.field,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.38))),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white30, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              letterSpacing: 2.5,
              color: Colors.white.withOpacity(0.30))),
    );
  }
}

class _StoaRooms extends StatelessWidget {
  final AppState state;
  const _StoaRooms({required this.state});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: state.stoaRoomsStream(),
      builder: (ctx, snap) {
        final myRooms = (snap.data ?? [])
            .where((r) => r['hostUid'] == state.profile.uid)
            .toList();

        // Also show rooms that were recently joined (notification pending)
        final notifIds = state.stoaNotifications.keys.toSet();
        final notifRooms = notifIds
            .where((id) => !myRooms.any((r) => r['roomId'] == id))
            .toList();

        if (myRooms.isEmpty && notifRooms.isEmpty) {
          return _empty('No open rooms.');
        }

        return Column(children: [
          // Notification cards (rooms that were joined — already closed)
          ...notifRooms.map((roomId) {
            final joiner = state.stoaNotifications[roomId] ?? 'Someone';
            return _NotifTile(
              joiner: joiner,
              onClear: () => state.clearStoaNotification(roomId),
            );
          }),
          // Active open rooms
          ...myRooms.map((room) {
            final roomId = room['roomId'] as String;
            final title  = room['title']  as String? ?? 'Untitled';
            final hasNotif = state.stoaNotifications.containsKey(roomId);
            return _RoomTile(
              title: title,
              hasNotif: hasNotif,
              joinerName: state.stoaNotifications[roomId],
              onTerminate: () async {
                state.clearStoaNotification(roomId);
                await state.terminateStoaRoom(roomId);
              },
            );
          }),
        ]);
      },
    );
  }
}

class _RoomTile extends StatelessWidget {
  final String title;
  final bool hasNotif;
  final String? joinerName;
  final VoidCallback onTerminate;
  const _RoomTile({
    required this.title,
    required this.hasNotif,
    required this.joinerName,
    required this.onTerminate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasNotif
            ? Colors.orange.withOpacity(0.06)
            : Colors.white.withOpacity(0.03),
        border: Border.all(
            color: hasNotif
                ? Colors.orangeAccent.withOpacity(0.40)
                : Colors.white.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        if (hasNotif)
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
                color: Colors.orangeAccent, shape: BoxShape.circle),
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            Text(
              hasNotif
                  ? '${joinerName ?? 'Someone'} joined!'
                  : 'Waiting for challenger…',
              style: TextStyle(
                  fontSize: 11,
                  color: hasNotif
                      ? Colors.orangeAccent
                      : Colors.white.withOpacity(0.30)),
            ),
          ]),
        ),
        TextButton(
          onPressed: onTerminate,
          style: TextButton.styleFrom(
            foregroundColor: Colors.redAccent.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: GoogleFonts.dmSans(
                fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          ),
          child: const Text('END'),
        ),
      ]),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final String joiner;
  final VoidCallback onClear;
  const _NotifTile({required this.joiner, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.30)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        const Text('🔔 ', style: TextStyle(fontSize: 12)),
        Expanded(
          child: Text('$joiner joined your room',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 14, color: Colors.white38),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onClear,
        ),
      ]),
    );
  }
}

class _ActiveDebates extends StatelessWidget {
  final AppState state;
  const _ActiveDebates({required this.state});

  @override
  Widget build(BuildContext context) {
    final debates = state.activeDebates;
    if (debates.isEmpty) return _empty('No active debates.');
    return Column(
      children: debates.map((d) {
        return ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          leading: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AcroColors.gold.withOpacity(0.10),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: AcroColors.gold.withOpacity(0.25)),
            ),
            child: Center(
              child: Text(d['partnerIni'] ?? '?',
                  style: TextStyle(
                      color: AcroColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          title: Text(d['title'] ?? 'Debate',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          subtitle: Text('vs ${d['partnerName'] ?? ''}',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.35))),
        );
      }).toList(),
    );
  }
}

Widget _empty(String msg) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(msg,
          style: TextStyle(
              fontSize: 12, color: Colors.white.withOpacity(0.25))),
    );
