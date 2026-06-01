import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/acro_mode.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';
import 'searching_screen.dart';

class AgoraScreen extends StatefulWidget {
  const AgoraScreen({super.key});

  @override
  State<AgoraScreen> createState() => _AgoraScreenState();
}

class _AgoraScreenState extends State<AgoraScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  bool _nameSet = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // If name was already set (e.g. from a prior session), skip entry
    final profile = context.read<AppState>().profile;
    if (profile.name.isNotEmpty) {
      _nameSet = true;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _confirmName() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    context.read<AppState>().setProfile(name: name, mode: AcroMode.agora);
    setState(() => _nameSet = true);
  }

  void _enterSearching() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AcroColors.stoneLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '🏛  AGORA',
          style: GoogleFonts.dmSans(
            color: AcroColors.gold,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ),
      body: _nameSet ? _buildHome() : _buildNameEntry(),
    );
  }

  // ---------------------------------------------------------------------------
  // Name entry
  // ---------------------------------------------------------------------------

  Widget _buildNameEntry() {
    return Center(
      child: Container(
        width: 380,
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: AcroColors.gold.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ENTER ANONYMOUSLY',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AcroColors.stoneLight,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Just your name. No account needed.',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.4)),
            ),
            const SizedBox(height: 28),
            _pixelInput(_nameCtrl, 'Your name…', onSubmit: _confirmName),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _PixelButton(
                label: 'ENTER THE AGORA',
                onTap: _confirmName,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main Agora home (big button + live count)
  // ---------------------------------------------------------------------------

  Widget _buildHome() {
    final state = context.read<AppState>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'WELCOME, ${state.profile.name.toUpperCase()}',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AcroColors.stoneLight,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Every great idea started with a conversation.',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withOpacity(0.35)),
          ),
          const SizedBox(height: 60),

          // Live count badge
          StreamBuilder<int>(
            stream: state.agoraQueueCount(),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Text(
                count > 0
                    ? '$count ${count == 1 ? 'person' : 'people'} in the Agora'
                    : 'Be the first in the Agora',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: count > 0
                      ? AcroColors.gold.withOpacity(0.8)
                      : Colors.white24,
                  letterSpacing: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // The big pixel button
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => _buildBigButton(_pulse.value),
          ),

          const SizedBox(height: 60),
          TextButton(
            onPressed: () => setState(() {
              _nameSet = false;
              _nameCtrl.clear();
            }),
            child: Text(
              'Change name',
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigButton(double t) {
    final glow = AcroColors.gold.withOpacity(0.08 + 0.08 * t);
    return GestureDetector(
      onTap: _enterSearching,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: AcroColors.gold.withOpacity(0.08),
            border: Border.all(
              color: AcroColors.gold.withOpacity(0.5 + 0.3 * t),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: glow,
                blurRadius: 40,
                spreadRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🏛',
                style: TextStyle(fontSize: 48 + 4 * t),
              ),
              const SizedBox(height: 12),
              Text(
                'FIND A MATCH',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AcroColors.gold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _pixelInput(
    TextEditingController ctrl,
    String hint, {
    VoidCallback? onSubmit,
  }) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(
          color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
      onSubmitted: (_) => onSubmit?.call(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.25), fontFamily: 'monospace'),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AcroColors.gold),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _PixelButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PixelButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AcroColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AcroColors.stone,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
