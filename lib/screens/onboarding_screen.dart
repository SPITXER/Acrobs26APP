import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';
import 'lobby_screen.dart';
import 'acropolis_map_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _fieldCtrl = TextEditingController();
  String _role = 'host';

  void _enter() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name first.')),
      );
      return;
    }
    context.read<AppState>().setProfile(
          name: name,
          field: _fieldCtrl.text.trim(),
          role: _role,
        );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AcropolisMapScreen(
          onZoneTap: (zone) {
            // TODO: navigate to each mode screen
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${zone.name.toUpperCase()} — coming soon')),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1510), Color(0xFF2C2820), Color(0xFF1A1510)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: AcroColors.gold.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AcroColors.gold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('Α',
                                  style: GoogleFonts.playfairDisplay(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: AcroColors.stone)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('ACRO',
                              style: GoogleFonts.playfairDisplay(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: AcroColors.gold,
                                  letterSpacing: 3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text('THE AGORA OF IDEAS',
                          style: TextStyle(
                              fontSize: 11,
                              color: AcroColors.stoneLight,
                              letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 28),

                    // Name
                    _label('Your Name'),
                    _input(_nameCtrl, 'Enter your full name…'),

                    // Field
                    _label('Your Field / Expertise'),
                    _input(_fieldCtrl, 'e.g. Political Philosophy, Economics…'),

                    const SizedBox(height: 6),
                    Center(
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: AcroColors.gold.withOpacity(0.15))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('Choose your role',
                                style: TextStyle(fontSize: 12, color: AcroColors.stoneLight)),
                          ),
                          Expanded(child: Divider(color: AcroColors.gold.withOpacity(0.15))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Role selection
                    Row(
                      children: [
                        Expanded(child: _roleBtn('host', '🏛️', 'Host', 'Open a debate room')),
                        const SizedBox(width: 10),
                        Expanded(child: _roleBtn('guest', '🎓', 'Guest', 'Join a debate room')),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Enter button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _enter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AcroColors.gold,
                          foregroundColor: AcroColors.stone,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Enter the Agora →',
                            style: GoogleFonts.dmSans(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AcroColors.stoneLight,
                letterSpacing: 0.8)),
      );

  Widget _input(TextEditingController ctrl, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onSubmitted: (_) => _enter(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AcroColors.stoneLight, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: AcroColors.gold),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          ),
        ),
      );

  Widget _roleBtn(String role, String emoji, String label, String hint) {
    final selected = _role == role;
    return GestureDetector(
      onTap: () => setState(() => _role = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AcroColors.gold.withOpacity(0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? AcroColors.gold : AcroColors.gold.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AcroColors.gold : AcroColors.stoneLight)),
            Text(hint,
                style: TextStyle(
                    fontSize: 10,
                    color: (selected ? AcroColors.gold : AcroColors.stoneLight)
                        .withOpacity(0.65))),
          ],
        ),
      ),
    );
  }
}
