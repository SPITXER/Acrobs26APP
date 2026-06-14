import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/badge_engine.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openEditSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080C14),
        foregroundColor: Colors.white70,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('PROFILE',
            style: GoogleFonts.spaceMono(
                fontSize: 11,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 3.5)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit profile',
            onPressed: () => _openEditSheet(context, state),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: state.userStatsStream(),
        builder: (context, snap) {
          final stats = snap.data ?? {};
          final badge = BadgeEngine.fromStats(stats);
          final info = BadgeEngine.infoFor(badge);

          final minutes = (stats['totalMinutesActive'] as int?) ?? 0;
          final hours = minutes ~/ 60;
          final quoteCount = (stats['quoteCount'] as int?) ?? 0;
          final nomGiven = (stats['nominationsGiven'] as int?) ?? 0;
          final nomReceived = (stats['nominationsReceived'] as int?) ?? 0;
          final interests = (stats['interests'] as List?)?.cast<String>() ?? [];
          final savedQuote = (stats['quote'] as String?) ?? '';

          final rawTopics = stats['topicEngagement'];
          final topicMap = rawTopics is Map
              ? Map<String, int>.from(rawTopics
                  .map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
              : <String, int>{};
          final sortedTopics = topicMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final maxTopicCount =
              sortedTopics.isEmpty ? 1 : sortedTopics.first.value;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
            children: [
              // ── Profile header ─────────────────────────────────────────────
              _ProfileHeader(
                  state: state, info: info, savedQuote: savedQuote),
              const SizedBox(height: 28),

              // ── Contributions ──────────────────────────────────────────────
              _SectionLabel('CONTRIBUTIONS'),
              const SizedBox(height: 12),
              _StatsRow(
                  hours: hours,
                  quotes: quoteCount,
                  nomGiven: nomGiven,
                  nomReceived: nomReceived),
              const SizedBox(height: 28),

              // ── Badge ──────────────────────────────────────────────────────
              _SectionLabel('PHILOSOPHER BADGE'),
              const SizedBox(height: 12),
              _BadgeCard(badge: badge, info: info),
              const SizedBox(height: 28),

              // ── Topic engagement ───────────────────────────────────────────
              if (sortedTopics.isNotEmpty) ...[
                _SectionLabel('DEBATE TOPICS'),
                const SizedBox(height: 12),
                _TopicsBreakdown(
                    topics: sortedTopics, maxCount: maxTopicCount),
                const SizedBox(height: 28),
              ],

              // ── Interests ─────────────────────────────────────────────────
              if (interests.isNotEmpty) ...[
                _SectionLabel('INTERESTS'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: interests
                      .map((t) => _Chip(t))
                      .toList(),
                ),
                const SizedBox(height: 28),
              ],

              // ── Nominations ────────────────────────────────────────────────
              _SectionLabel('NOMINATIONS'),
              const SizedBox(height: 12),
              _NominationsCard(given: nomGiven, received: nomReceived),
              const SizedBox(height: 28),

              // ── Posts / Quotes ─────────────────────────────────────────────
              _SectionLabel('POSTS & QUOTES'),
              const SizedBox(height: 12),
              _LockedCard(
                icon: Icons.format_quote_rounded,
                text: quoteCount == 0
                    ? 'No quotes yet.'
                    : '$quoteCount quote${quoteCount == 1 ? '' : 's'} posted',
              ),
              const SizedBox(height: 28),

              // ── Friends ────────────────────────────────────────────────────
              _SectionLabel('FRIENDS'),
              const SizedBox(height: 12),
              _ComingSoonCard('Friend connections'),
              const SizedBox(height: 28),

              // ── Subscription ───────────────────────────────────────────────
              _SectionLabel('SUBSCRIPTION'),
              const SizedBox(height: 12),
              _ComingSoonCard('Subscription tiers'),
              const SizedBox(height: 36),

              // ── Sign out ───────────────────────────────────────────────────
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.logout, size: 14),
                label: Text('SIGN OUT',
                    style: GoogleFonts.spaceMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                style: TextButton.styleFrom(
                  foregroundColor:
                      Colors.redAccent.shade100.withOpacity(0.65),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 0, vertical: 12),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await context.read<AppState>().signOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final AppState state;
  final BadgeInfo info;
  final String savedQuote;
  const _ProfileHeader(
      {required this.state,
      required this.info,
      required this.savedQuote});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        AcroAvatar(
          initials: state.profile.initials,
          seed: state.profile.uid,
          size: 64,
          avatarOverride: state.profile.avatarIndex,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(state.profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cormorant(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            if (state.profile.field.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(state.profile.field,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.40),
                      letterSpacing: 0.3)),
            ],
            const SizedBox(height: 8),
            // Badge chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AcroColors.gold.withOpacity(0.08),
                border: Border.all(
                    color: AcroColors.gold.withOpacity(0.28)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(info.emoji,
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text(info.name,
                    style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AcroColors.gold,
                        letterSpacing: 0.6)),
              ]),
            ),
          ]),
        ),
      ]),
      if (savedQuote.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text('"$savedQuote"',
            style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.35),
                height: 1.5)),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contributions row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int hours;
  final int quotes;
  final int nomGiven;
  final int nomReceived;
  const _StatsRow(
      {required this.hours,
      required this.quotes,
      required this.nomGiven,
      required this.nomReceived});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCell('${hours}h', 'ACTIVE')),
      _divider(),
      Expanded(child: _StatCell('$quotes', 'QUOTES')),
      _divider(),
      Expanded(child: _StatCell('$nomGiven', 'NOM. GIVEN')),
      _divider(),
      Expanded(child: _StatCell('$nomReceived', 'NOM. RECV')),
    ]);
  }

  Widget _divider() => Container(
      width: 1, height: 36, color: Colors.white.withOpacity(0.07));
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.spaceMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.85))),
      const SizedBox(height: 3),
      Text(label,
          style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.8,
              color: Colors.white.withOpacity(0.25))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge card
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  final AcroBadge badge;
  final BadgeInfo info;
  const _BadgeCard({required this.badge, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AcroColors.gold.withOpacity(0.05),
        border: Border.all(color: AcroColors.gold.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(info.emoji,
            style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(info.name,
                style: GoogleFonts.cormorant(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AcroColors.gold)),
            const SizedBox(height: 3),
            Text(info.epithet,
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.45))),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.white.withOpacity(0.10)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(info.domain,
                  style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      color: Colors.white.withOpacity(0.30))),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic bars
// ─────────────────────────────────────────────────────────────────────────────

class _TopicsBreakdown extends StatelessWidget {
  final List<MapEntry<String, int>> topics;
  final int maxCount;
  const _TopicsBreakdown(
      {required this.topics, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: topics.take(6).map((entry) {
        final frac = maxCount > 0 ? entry.value / maxCount : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
              width: 88,
              child: Text(entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.50))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 4,
                  backgroundColor: Colors.white.withOpacity(0.07),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AcroColors.gold.withOpacity(0.60)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${entry.value}',
                style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.30))),
          ]),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nominations card
// ─────────────────────────────────────────────────────────────────────────────

class _NominationsCard extends StatelessWidget {
  final int given;
  final int received;
  const _NominationsCard({required this.given, required this.received});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Expanded(
          child: Column(children: [
            Text('$received',
                style: GoogleFonts.spaceMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AcroColors.gold)),
            const SizedBox(height: 3),
            Text('RECEIVED',
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.8,
                    color: Colors.white.withOpacity(0.25))),
          ]),
        ),
        Container(
            width: 1, height: 36, color: Colors.white.withOpacity(0.07)),
        Expanded(
          child: Column(children: [
            Text('$given',
                style: GoogleFonts.spaceMono(
                    fontSize: 22,
                    color: Colors.white.withOpacity(0.55))),
            const SizedBox(height: 3),
            Text('GIVEN',
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.8,
                    color: Colors.white.withOpacity(0.25))),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 2.5,
            color: Colors.white.withOpacity(0.28)));
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: Colors.white.withOpacity(0.50))),
    );
  }
}

class _LockedCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _LockedCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.20)),
        const SizedBox(width: 10),
        Text(text,
            style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.35))),
      ]),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  final String label;
  const _ComingSoonCard(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(
            color: Colors.white.withOpacity(0.05),
            style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline,
            size: 14, color: Colors.white.withOpacity(0.15)),
        const SizedBox(width: 10),
        Text('$label — coming soon',
            style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.20))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final AppState state;
  const _EditSheet({required this.state});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  static const _ghosts = [
    'assets/images/ghost_aristotle_copper.png',
    'assets/images/ghost_plato_silver.png',
    'assets/images/ghost_socrates_gold.png',
  ];
  static const _ghostNames = ['Aristotle', 'Plato', 'Socrates'];
  static const _allInterests = [
    'Philosophy', 'Science', 'Politics', 'Economics',
    'History', 'Ethics', 'Technology', 'Literature',
    'Psychology', 'Art', 'Mathematics', 'Theology',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _fieldCtrl;
  late int _selectedAvatar;
  late Set<String> _selectedInterests;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.state.profile;
    _nameCtrl  = TextEditingController(text: p.name);
    _fieldCtrl = TextEditingController(text: p.field);
    _selectedInterests = Set<String>.from(p.interests);
    final idx = p.avatarIndex;
    _selectedAvatar = idx >= 0
        ? idx
        : p.uid.hashCode.abs() % _ghosts.length;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fieldCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await widget.state.updateProfile(
      name:        _nameCtrl.text,
      avatarIndex: _selectedAvatar,
      field:       _fieldCtrl.text,
      interests:   _selectedInterests.toList(),
    );
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AcroColors.gold),
          borderRadius: BorderRadius.circular(6),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      // cap height so sheet scrolls when keyboard is up
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1120),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Handle + title (fixed) ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('EDIT PROFILE',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      letterSpacing: 2.5,
                      color: Colors.white.withOpacity(0.30))),
            ),
          ]),
        ),

        // ── Scrollable body ────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Avatar picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_ghosts.length, (i) {
                  final sel = _selectedAvatar == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatar = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel
                              ? AcroColors.gold
                              : Colors.white.withOpacity(0.10),
                          width: sel ? 2 : 1,
                        ),
                        color: sel
                            ? AcroColors.gold.withOpacity(0.08)
                            : Colors.transparent,
                      ),
                      child: Column(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(_ghosts[i],
                              width: 72, height: 72, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 6),
                        Text(_ghostNames[i],
                            style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 0.5,
                                color: sel
                                    ? AcroColors.gold
                                    : Colors.white.withOpacity(0.35))),
                      ]),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Name
              TextField(
                controller: _nameCtrl,
                maxLength: 32,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDeco('Display name').copyWith(
                  counterStyle: TextStyle(
                      color: Colors.white.withOpacity(0.20), fontSize: 10),
                ),
              ),
              const SizedBox(height: 16),

              // Field / expertise
              TextField(
                controller: _fieldCtrl,
                maxLength: 48,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDeco('Field / expertise').copyWith(
                  hintText: 'e.g. Classical Studies, Cognitive Science…',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.18), fontSize: 12),
                  counterStyle: TextStyle(
                      color: Colors.white.withOpacity(0.20), fontSize: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Interests label
              Text('INTERESTS',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      letterSpacing: 2.5,
                      color: Colors.white.withOpacity(0.28))),
              const SizedBox(height: 10),

              // Interest chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allInterests.map((t) {
                  final sel = _selectedInterests.contains(t);
                  return GestureDetector(
                    onTap: () => setState(() {
                      sel
                          ? _selectedInterests.remove(t)
                          : _selectedInterests.add(t);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? AcroColors.gold.withOpacity(0.12)
                            : Colors.white.withOpacity(0.04),
                        border: Border.all(
                          color: sel
                              ? AcroColors.gold.withOpacity(0.60)
                              : Colors.white.withOpacity(0.12),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(t,
                          style: TextStyle(
                              fontSize: 11,
                              color: sel
                                  ? AcroColors.gold
                                  : Colors.white.withOpacity(0.45))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
            ]),
          ),
        ),

        // ── Save button (fixed at bottom) ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AcroColors.gold,
                foregroundColor: AcroColors.stone,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                textStyle: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AcroColors.stone))
                  : const Text('SAVE'),
            ),
          ),
        ),
      ]),
    );
  }
}
