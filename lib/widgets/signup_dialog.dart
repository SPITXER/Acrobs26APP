import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';

class SignupPromptDialog extends StatefulWidget {
  const SignupPromptDialog({super.key});

  @override
  State<SignupPromptDialog> createState() => _SignupPromptDialogState();
}

class _SignupPromptDialogState extends State<SignupPromptDialog> {
  bool    _showEmail = false;
  bool    _loading   = false;
  String? _error;
  final   _emailCtrl = TextEditingController();
  final   _passCtrl  = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppState>().signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Google sign-in failed. Try again.'; });
    }
  }

  Future<void> _emailSignUp() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.length < 6) {
      setState(() => _error = 'Enter a valid email and password (6+ chars).');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppState>().signUpWithEmail(email, pass);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().contains('email-already-in-use')
            ? 'That email is already registered.'
            : 'Sign-up failed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0E1320),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: AcroColors.gold.withOpacity(0.30)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + title
              Row(children: [
                const Text('🏛', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Stay in the Agora',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                "You've been active for 5 minutes. Create an account to keep your profile, rooms, and debates across sessions and devices.",
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.45),
                    height: 1.5),
              ),
              const SizedBox(height: 28),

              // Google button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _googleSignIn,
                  icon: const Text('G',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87)),
                  label: const Text('CONTINUE WITH GOOGLE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3)),
                    textStyle: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Email toggle
              if (!_showEmail)
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _showEmail = true),
                    child: Text('Use email instead',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.38))),
                  ),
                ),

              // Email form
              if (_showEmail) ...[
                const SizedBox(height: 4),
                _field(_emailCtrl, 'Email address',
                    TextInputType.emailAddress),
                _field(_passCtrl, 'Password (6+ chars)',
                    TextInputType.visiblePassword,
                    obscure: true),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _emailSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AcroColors.gold,
                      foregroundColor: AcroColors.stone,
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3)),
                      textStyle: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1),
                    ),
                    child: Text(_loading ? 'CREATING…' : 'CREATE ACCOUNT'),
                  ),
                ),
              ],

              // Error
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12)),
              ],

              // Later
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () {
                    context.read<AppState>().dismissSignupPrompt();
                    Navigator.of(context).pop();
                  },
                  child: Text('Maybe later',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.25))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, TextInputType type,
      {bool obscure = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.white.withOpacity(0.25)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide:
                    BorderSide(color: AcroColors.gold.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide:
                    BorderSide(color: AcroColors.gold.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: AcroColors.gold)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      );
}
