import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/badge_engine.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
