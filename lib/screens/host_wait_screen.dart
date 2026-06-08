import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';
import '../widgets/cloud_corner_box.dart';
import 'room_screen.dart';

class HostWaitScreen extends StatefulWidget {
  final Map<String, dynamic> room;
  const HostWaitScreen({super.key, required this.room});
  @override
  State<HostWaitScreen> createState() => _HostWaitScreenState();
}

class _HostWaitScreenState extends State<HostWaitScreen> {
  bool _entered = false;
  VoidCallback? _savedCallback;
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _appState = context.read<AppState>();
      _savedCallback = _appState!.enterRoomCallback;
      _appState!.registerEnterRoomCallback(_handleEnter);
    });
  }

  @override
  void dispose() {
    _appState?.registerEnterRoomCallback(_savedCallback);
    super.dispose();
  }

  void _handleEnter() {
    if (!mounted || _entered) return;
    _entered = true;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RoomScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (ctx, state, _) {
      if (state.currentRoom != null && !_entered) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleEnter());
      }

      final title    = widget.room['title']    as String? ?? 'Untitled';
      final thesis   = widget.room['thesis']   as String? ?? '';
      final category = widget.room['category'] as String? ?? '';
      final matched  = state.currentRoom != null;

      String partnerName = '';
      if (matched) {
        final others = state.currentRoom!.members
            .where((m) => m.name != state.profile.name)
            .toList();
        partnerName = others.isNotEmpty ? others.first.name : 'Challenger';
      }

      return Scaffold(
        backgroundColor: const Color(0xFF0B0F1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0F1A),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AcroColors.stoneLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('⚖  THE STOA',
              style: GoogleFonts.dmSans(
                  color: AcroColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: CloudCornerBox(
              width: 320,
              padding: const EdgeInsets.all(28),
              borderColor: AcroColors.gold.withOpacity(0.22),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AcroColors.gold.withOpacity(0.28)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(category,
                          style: GoogleFonts.spaceMono(
                              fontSize: 9,
                              color: AcroColors.gold.withOpacity(0.70),
                              letterSpacing: 1.5)),
                    ),
                  const SizedBox(height: 18),
                  Text(title,
                      style: GoogleFonts.cormorant(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3)),
                  if (thesis.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('"$thesis"',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.42),
                            fontStyle: FontStyle.italic,
                            height: 1.4)),
                  ],
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  if (!matched)
                    Row(children: [
                      SizedBox(
                        width: 13, height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AcroColors.gold.withOpacity(0.45)),
                      ),
                      const SizedBox(width: 12),
                      Text('Awaiting a challenger…',
                          style: GoogleFonts.spaceMono(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.35))),
                    ])
                  else ...[
                    Text('$partnerName has arrived.',
                        style: GoogleFonts.spaceMono(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.60))),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleEnter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AcroColors.gold,
                          foregroundColor: AcroColors.stone,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2)),
                          textStyle: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2),
                        ),
                        child: const Text('ENTER DEBATE'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
