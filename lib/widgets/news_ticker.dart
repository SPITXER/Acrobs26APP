import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Reads live headlines from Firebase Realtime Database node:
//   announcements/{key}/text  — string value
// If the node is empty or absent, falls back to the Greek pool below.
class NewsTicker extends StatefulWidget {
  const NewsTicker({super.key});

  @override
  State<NewsTicker> createState() => _NewsTickerState();
}

class _NewsTickerState extends State<NewsTicker> {
  static const _greekPool = [
    'The gods look favorably upon today\'s debates',
    'Citizens! Logos, ethos, pathos — choose your weapon',
    'By Athena — a worthy argument has been posted',
    'The Ekklesia convenes — all voices shall be heard',
    'Socrates asks: what is the good life?',
    'The Stoa fills with discourse at the ninth hour',
    'A new champion emerges from the Agora',
    'Hear ye! A debate of great consequence begins',
    'The Oracle has spoken — enter the Agora',
    'New challenger approaches the Stoa floor',
  ];

  List<String> _pool = [];
  int _idx = 0;
  String _displayed = '';
  bool _cursorOn = true;
  Timer? _charTimer;
  Timer? _pauseTimer;
  Timer? _cursorTimer;
  StreamSubscription<DatabaseEvent>? _dbSub;

  @override
  void initState() {
    super.initState();
    _pool = List.of(_greekPool)..shuffle(Random());

    _cursorTimer = Timer.periodic(
      const Duration(milliseconds: 530),
      (_) { if (mounted) setState(() => _cursorOn = !_cursorOn); },
    );

    _dbSub = FirebaseDatabase.instance
        .ref('announcements')
        .onValue
        .listen(_onDbUpdate);

    _typeHeadline();
  }

  void _onDbUpdate(DatabaseEvent event) {
    if (!mounted) return;
    final data = event.snapshot.value;
    if (data == null) return;

    final live = <String>[];
    if (data is Map) {
      for (final v in data.values) {
        final text = v is Map ? v['text'] : (v is String ? v : null);
        if (text is String && text.isNotEmpty) live.add(text);
      }
    }

    if (live.isEmpty) return;
    live.shuffle(Random());
    _charTimer?.cancel();
    _pauseTimer?.cancel();
    setState(() { _pool = live; _idx = 0; });
    _typeHeadline();
  }

  void _typeHeadline() {
    if (_pool.isEmpty) return;
    _displayed = '';
    int i = 0;
    final text = _pool[_idx];
    _charTimer?.cancel();
    _charTimer = Timer.periodic(const Duration(milliseconds: 48), (t) {
      if (!mounted) { t.cancel(); return; }
      if (i >= text.length) {
        t.cancel();
        _pauseTimer = Timer(const Duration(seconds: 4), () {
          if (!mounted) return;
          setState(() => _idx = (_idx + 1) % _pool.length);
          _typeHeadline();
        });
        return;
      }
      setState(() => _displayed = text.substring(0, ++i));
    });
  }

  @override
  void dispose() {
    _charTimer?.cancel();
    _pauseTimer?.cancel();
    _cursorTimer?.cancel();
    _dbSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF1C0F00).withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF5E462C), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            '◈  ',
            style: GoogleFonts.pixelifySans(
              fontSize: 10,
              color: const Color(0xFFCC9C54).withValues(alpha: 0.9),
            ),
          ),
          Expanded(
            child: Text(
              '$_displayed${_cursorOn ? '▌' : ' '}',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.pixelifySans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE9D6AC).withValues(alpha: 0.92),
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
