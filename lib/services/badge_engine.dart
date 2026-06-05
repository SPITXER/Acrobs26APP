import 'dart:math' show log;

// ─────────────────────────────────────────────────────────────────────────────
// ACRO Badge ranking system
//
// Composite score formula (weights as specified):
//   S = h·0.5  +  q·0.2  +  n·0.2  +  v·0.1
//
//   h = log-normalised hours active       (cap 500 h)
//   q = log-normalised quote count        (cap 200 quotes)
//   n = log-normalised nominations recv   (cap 50)
//   v = distinct debate topics / 8        (linear 0–1)
//
// Philosopher badge is then determined by:
//   1. composite score tier (minimum threshold)
//   2. dominant topic affinity within that tier
// ─────────────────────────────────────────────────────────────────────────────

enum AcroBadge {
  wanderer,
  sophist,
  zeno,
  epicurus,
  diogenes,
  pythagoras,
  heraclitus,
  aristotle,
  plato,
  socrates,
}

class BadgeInfo {
  final String name;
  final String epithet;
  final String emoji;
  final String domain;

  const BadgeInfo({
    required this.name,
    required this.epithet,
    required this.emoji,
    required this.domain,
  });
}

class BadgeEngine {
  BadgeEngine._();

  // ── Log-normalisation caps ────────────────────────────────────────────────
  static const _maxHours = 500.0;   // hours active
  static const _maxQuotes = 200.0;  // quotes posted
  static const _maxNom = 50.0;      // nominations received
  static const _numTopics = 8;      // total debate categories

  // ── Badge display metadata ────────────────────────────────────────────────
  static const Map<AcroBadge, BadgeInfo> labels = {
    AcroBadge.wanderer: BadgeInfo(
      name: 'The Wanderer',
      epithet: 'Yet to find your argument',
      emoji: '🌑',
      domain: 'Undeclared',
    ),
    AcroBadge.sophist: BadgeInfo(
      name: 'Sophist',
      epithet: 'The skilled rhetorician',
      emoji: '🗣️',
      domain: 'Rhetoric & Persuasion',
    ),
    AcroBadge.zeno: BadgeInfo(
      name: 'Zeno',
      epithet: 'Master of the stoic paradox',
      emoji: '⚖️',
      domain: 'Logic & Ethics',
    ),
    AcroBadge.epicurus: BadgeInfo(
      name: 'Epicurus',
      epithet: 'Seeker of the examined life',
      emoji: '🌿',
      domain: 'Ethics & History',
    ),
    AcroBadge.diogenes: BadgeInfo(
      name: 'Diogenes',
      epithet: 'The wandering provocateur',
      emoji: '🪔',
      domain: 'All Domains · Contrarian',
    ),
    AcroBadge.pythagoras: BadgeInfo(
      name: 'Pythagoras',
      epithet: 'All things are numbers',
      emoji: '📐',
      domain: 'Science & Mathematics',
    ),
    AcroBadge.heraclitus: BadgeInfo(
      name: 'Heraclitus',
      epithet: 'Everything flows',
      emoji: '🔥',
      domain: 'Philosophy & Theology',
    ),
    AcroBadge.aristotle: BadgeInfo(
      name: 'Aristotle',
      epithet: 'The rational animal',
      emoji: '🦉',
      domain: 'Science & Natural Philosophy',
    ),
    AcroBadge.plato: BadgeInfo(
      name: 'Plato',
      epithet: 'The philosopher king',
      emoji: '📜',
      domain: 'Politics & Ethics',
    ),
    AcroBadge.socrates: BadgeInfo(
      name: 'Socrates',
      epithet: 'I know that I know nothing',
      emoji: '🏛️',
      domain: 'Polymath · All Domains',
    ),
  };

  // ── Score computation ─────────────────────────────────────────────────────

  static double computeScore({
    required int totalMinutesActive,
    required int quoteCount,
    required int nominationsReceived,
    required int distinctTopics,
  }) {
    final h = _logNorm(totalMinutesActive / 60.0, _maxHours);
    final q = _logNorm(quoteCount.toDouble(), _maxQuotes);
    final n = _logNorm(nominationsReceived.toDouble(), _maxNom);
    final v = distinctTopics.clamp(0, _numTopics) / _numTopics;
    return (h * 0.5) + (q * 0.2) + (n * 0.2) + (v * 0.1);
  }

  static double _logNorm(double x, double max) {
    if (x <= 0 || max <= 0) return 0.0;
    return log(1 + x) / log(1 + max);
  }

  // ── Badge assignment ──────────────────────────────────────────────────────
  // top2Topics: up to 2 topic names sorted by engagement count (highest first)

  static AcroBadge assignBadge({
    required double score,
    required List<String> top2Topics,
    required int distinctTopics,
  }) {
    final variety = distinctTopics.clamp(0, _numTopics) / _numTopics;

    // Socrates — supreme polymath, highest score + widest variety
    if (score >= 0.70 && distinctTopics >= 6) {
      return AcroBadge.socrates;
    }

    // Plato — politics, ethics, philosophy (idealist high tier)
    if (score >= 0.50 &&
        _affinity(top2Topics, const ['Politics', 'Ethics', 'Philosophy'])) {
      return AcroBadge.plato;
    }

    // Aristotle — science, theology, economics (natural philosopher high tier)
    if (score >= 0.50 &&
        _affinity(
            top2Topics, const ['Science', 'Technology', 'Economics', 'Theology'])) {
      return AcroBadge.aristotle;
    }

    // Generic high-tier — default to Plato
    if (score >= 0.50) return AcroBadge.plato;

    // Pythagoras — science & tech, numbers above all
    if (score >= 0.35 &&
        _affinity(top2Topics, const ['Science', 'Technology'])) {
      return AcroBadge.pythagoras;
    }

    // Heraclitus — philosophy & theology with breadth (the obscure one)
    if (score >= 0.30 &&
        variety >= 0.50 &&
        _affinity(top2Topics, const ['Philosophy', 'Theology'])) {
      return AcroBadge.heraclitus;
    }

    // Diogenes — contrarian breadth (5+ topics, questions everything)
    if (score >= 0.25 && distinctTopics >= 5) return AcroBadge.diogenes;

    // Epicurus — ethics & history, the good life
    if (score >= 0.20 &&
        _affinity(top2Topics, const ['Ethics', 'History'])) {
      return AcroBadge.epicurus;
    }

    // Zeno — logic and stoic ethics
    if (score >= 0.15 &&
        _affinity(top2Topics, const ['Philosophy', 'Ethics'])) {
      return AcroBadge.zeno;
    }

    // Sophist — any meaningful participation
    if (score >= 0.05) return AcroBadge.sophist;

    return AcroBadge.wanderer;
  }

  static bool _affinity(List<String> topics, List<String> domains) =>
      topics.any(domains.contains);

  // ── Derive badge directly from a Firebase user stats map ─────────────────

  static AcroBadge fromStats(Map<String, dynamic> stats) {
    final minutes = (stats['totalMinutesActive'] as int?) ?? 0;
    final quotes  = (stats['quoteCount']          as int?) ?? 0;
    final nomRec  = (stats['nominationsReceived'] as int?) ?? 0;

    final rawTopics = stats['topicEngagement'];
    final topicMap = rawTopics is Map
        ? Map<String, int>.from(rawTopics
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};

    final distinctTopics = topicMap.length;
    final top2 = (topicMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(2)
        .map((e) => e.key)
        .toList();

    final score = computeScore(
      totalMinutesActive: minutes,
      quoteCount: quotes,
      nominationsReceived: nomRec,
      distinctTopics: distinctTopics,
    );

    return assignBadge(
        score: score, top2Topics: top2, distinctTopics: distinctTopics);
  }

  // ── Handy access ─────────────────────────────────────────────────────────

  static BadgeInfo infoFor(AcroBadge badge) => labels[badge]!;

  static AcroBadge fromId(String id) =>
      AcroBadge.values.firstWhere((b) => b.name == id,
          orElse: () => AcroBadge.wanderer);
}
