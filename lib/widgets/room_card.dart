import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/debate_room.dart';
import '../theme/acro_theme.dart';

class RoomCard extends StatelessWidget {
  final DebateRoom room;
  final VoidCallback onJoin;

  const RoomCard({super.key, required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: room.isFull ? null : onJoin,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: AcroColors.gold.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(13),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Host row
            Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: const BoxDecoration(
                      color: AcroColors.gold, shape: BoxShape.circle),
                  child: Center(
                    child: Text(room.hostInitials,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: AcroColors.stone)),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.host, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
                    const Text('Host', style: TextStyle(fontSize: 10, color: Colors.white54)),
                  ],
                ),
                const Spacer(),
                if (room.isLive)
                  Row(
                    children: [
                      Container(
                        width: 5, height: 5,
                        decoration: const BoxDecoration(color: Color(0xFFE53E3E), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      const Text('LIVE',
                          style: TextStyle(fontSize: 9, color: Color(0xFFE53E3E), fontWeight: FontWeight.w700)),
                    ],
                  )
                else
                  const Text('Waiting', style: TextStyle(fontSize: 10, color: Colors.white30)),
              ],
            ),
            const SizedBox(height: 11),

            // Title
            Text(room.title,
                style: GoogleFonts.playfairDisplay(
                    fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (room.desc.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                room.desc.length > 80 ? '${room.desc.substring(0, 80)}…' : room.desc,
                style: const TextStyle(fontSize: 11, color: Colors.white38, height: 1.45),
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 10),

            // Tags
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _tag(room.category),
                _tag(room.sizeLabel),
                _tag('⏱ ${room.duration}'),
                if (room.perms.hand) _tag('✋ Hand req.'),
                if (room.perms.record) _tag('⏺ Recorded'),
              ],
            ),
            const Spacer(),

            // Footer
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.people, size: 12, color: Colors.white54),
                  const SizedBox(width: 3),
                  Text('${room.guestCount}/${room.capacity}',
                      style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  const SizedBox(width: 9),
                  Icon(Icons.access_time, size: 12, color: Colors.white54),
                  const SizedBox(width: 3),
                  Text(room.duration,
                      style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  const Spacer(),
                  TextButton(
                    onPressed: room.isFull ? null : onJoin,
                    style: TextButton.styleFrom(
                      backgroundColor: room.isFull
                          ? Colors.transparent
                          : AcroColors.gold,
                      foregroundColor: room.isFull
                          ? Colors.white38
                          : AcroColors.stone,
                      side: room.isFull
                          ? const BorderSide(color: Colors.white24)
                          : BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    child: Text(room.isFull ? 'Full' : 'Join'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AcroColors.gold.withOpacity(0.1),
          border: Border.all(color: AcroColors.gold.withOpacity(0.18)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 9, color: AcroColors.goldLight)),
      );
}
