import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';

class ScrollThreadPage extends StatefulWidget {
  final Map<String, dynamic> scroll;
  const ScrollThreadPage({super.key, required this.scroll});

  @override
  State<ScrollThreadPage> createState() => _ScrollThreadPageState();
}

class _ScrollThreadPageState extends State<ScrollThreadPage>
    with SingleTickerProviderStateMixin {
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late AnimationController _pulseCtrl;

  final List<_ChatMsg> _messages = [
    _ChatMsg('Alexandros', 'This argument changed how I think about determinism entirely.', false),
    _ChatMsg('Miriam K.', 'The third premise is where it breaks down — Kant addressed this.', false),
    _ChatMsg('You', "Kant's noumenal self was his escape hatch, not a solution.", true),
  ];

  bool _liveActive = false;
  int _liveCount = 3;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg('You', text, true));
      _chatCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title     = widget.scroll['title']    as String? ?? 'Untitled Scroll';
    final thesis    = widget.scroll['thesis']   as String? ?? '';
    final category  = widget.scroll['category'] as String? ?? '';
    final hostName  = widget.scroll['hostName'] as String? ?? 'Anonymous';
    final byName    = widget.scroll['nominatedByName'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080C18),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AcroColors.stoneLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '📜  THE SCROLL',
          style: GoogleFonts.dmSans(
            color: AcroColors.gold,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _liveActive
                    ? Color.lerp(const Color(0xFF8B2E2E), const Color(0xFFC4504A), _pulseCtrl.value)!.withOpacity(0.85)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: _liveActive ? AcroColors.redLight : Colors.white.withOpacity(0.12)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_liveActive) ...[
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                ],
                Text(
                  _liveActive ? 'LIVE · $_liveCount' : 'JOIN LIVE',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    color: _liveActive ? Colors.white : AcroColors.stoneLight,
                    letterSpacing: 1.5,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // ── THE SCROLL CARD ──────────────────────────────────────────
                SliverToBoxAdapter(child: _buildScrollHeader(title, thesis, category, hostName, byName)),

                // ── LIVE DEBATE ──────────────────────────────────────────────
                SliverToBoxAdapter(child: _buildLiveDebate()),

                // ── LIVE CHAT ────────────────────────────────────────────────
                SliverToBoxAdapter(child: _buildChatSection()),

                // ── RESEARCH ─────────────────────────────────────────────────
                SliverToBoxAdapter(child: _buildResearchSection(title)),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),

          // ── Chat input bar ───────────────────────────────────────────────
          _buildChatInput(),
        ],
      ),
    );
  }

  // ── The Scroll header card ─────────────────────────────────────────────────

  Widget _buildScrollHeader(
      String title, String thesis, String category, String host, String byName) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF131826),
            const Color(0xFF0D1020),
          ],
        ),
        border: Border.all(color: AcroColors.gold.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (category.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AcroColors.gold.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: GoogleFonts.spaceMono(fontSize: 9, color: AcroColors.gold, letterSpacing: 2),
                ),
              ),
            const Spacer(),
            const Text('📜', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text('SCROLL', style: GoogleFonts.spaceMono(fontSize: 9, color: AcroColors.gold.withOpacity(0.5), letterSpacing: 2)),
          ]),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.cormorant(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          if (thesis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AcroColors.gold.withOpacity(0.05),
                border: Border(left: BorderSide(color: AcroColors.gold.withOpacity(0.5), width: 2)),
              ),
              child: Text(
                '"$thesis"',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.65),
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          Row(children: [
            AcroAvatar(initials: _initials(host), seed: host, size: 28),
            const SizedBox(width: 10),
            Text(host, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
            if (byName.isNotEmpty) ...[
              Text('  ·  ', style: TextStyle(color: Colors.white.withOpacity(0.2))),
              Text('nom. by $byName', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.28))),
            ],
          ]),
        ],
      ),
    );
  }

  // ── Live Debate section ────────────────────────────────────────────────────

  Widget _buildLiveDebate() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('LIVE DEBATE', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AcroColors.stoneLight, letterSpacing: 2.5)),
            const SizedBox(width: 10),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: _liveActive ? Colors.redAccent : Colors.white24, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(_liveActive ? '$_liveCount listening' : 'offline', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3))),
          ]),
          const SizedBox(height: 16),
          if (_liveActive) ...[
            // Active state: avatars + waveform placeholder
            Row(children: [
              ...List.generate(
                _liveCount.clamp(0, 5),
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AcroAvatar(initials: ['AM', 'TK', 'SE', 'RJ', 'PL'][i % 5], seed: 'debate$i', size: 32),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: AcroColors.gold.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Center(
                    child: Text('◆  ◆ ◆  ◆◆ ◆  ◆ ◆◆  ◆ ◆  ◆◆ ◆',
                        style: TextStyle(fontSize: 8, color: AcroColors.gold.withOpacity(0.5), letterSpacing: 2)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() { _liveActive = false; }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AcroColors.stoneLight,
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  ),
                  child: Text('LEAVE', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AcroColors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  ),
                  child: Text('SPEAK', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
              ),
            ]),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() { _liveActive = true; _liveCount++; }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AcroColors.gold.withOpacity(0.12),
                  foregroundColor: AcroColors.gold,
                  side: const BorderSide(color: AcroColors.gold, width: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  elevation: 0,
                ),
                child: Text('JOIN LIVE DEBATE', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '$_liveCount scholars currently debating',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Chat section ───────────────────────────────────────────────────────────

  Widget _buildChatSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FLOOR', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AcroColors.stoneLight, letterSpacing: 2.5)),
          const SizedBox(height: 14),
          ..._messages.map((m) => _chatBubble(m)),
        ],
      ),
    );
  }

  Widget _chatBubble(_ChatMsg msg) {
    final isSelf = msg.isSelf;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSelf) ...[
            AcroAvatar(initials: _initials(msg.name), seed: msg.name, size: 28),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  msg.name,
                  style: GoogleFonts.spaceMono(fontSize: 9, color: Colors.white.withOpacity(0.3), letterSpacing: 1),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelf
                        ? AcroColors.gold.withOpacity(0.12)
                        : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: isSelf
                          ? AcroColors.gold.withOpacity(0.25)
                          : Colors.white.withOpacity(0.08),
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(isSelf ? 0.85 : 0.65),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isSelf) ...[
            const SizedBox(width: 10),
            AcroAvatar(initials: 'YO', seed: 'self', size: 28),
          ],
        ],
      ),
    );
  }

  // ── Research section ───────────────────────────────────────────────────────

  Widget _buildResearchSection(String title) {
    final refs = [
      _ResearchRef('Primary Text', 'The original argument as delivered in the Stoa debate session.', '📖'),
      _ResearchRef('Counterpoint Archive', 'Opposing positions collected during the live debate.', '⚖️'),
      _ResearchRef('Related Scrolls', 'Other scrolls in The Hall touching on this thesis.', '🔗'),
      _ResearchRef('Suggested Reading', 'Canonical texts relevant to this argument.', '📚'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(children: [
              Expanded(child: Divider(color: AcroColors.gold.withOpacity(0.2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('RESEARCH', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AcroColors.stoneLight, letterSpacing: 2.5)),
              ),
              Expanded(child: Divider(color: AcroColors.gold.withOpacity(0.2))),
            ]),
          ),
          ...refs.map((r) => _researchCard(r)),
        ],
      ),
    );
  }

  Widget _researchCard(_ResearchRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: AcroColors.gold.withOpacity(0.12)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(children: [
        Text(ref.icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ref.title, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.75))),
              const SizedBox(height: 3),
              Text(ref.description, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3), height: 1.4)),
            ],
          ),
        ),
        Icon(Icons.chevron_right, size: 16, color: AcroColors.gold.withOpacity(0.4)),
      ]),
    );
  }

  // ── Chat input bar ─────────────────────────────────────────────────────────

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF080C18),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _chatCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Speak to the floor…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.22), fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            ),
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AcroColors.gold.withOpacity(0.15),
              border: Border.all(color: AcroColors.gold.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Icon(Icons.send, size: 16, color: AcroColors.gold),
          ),
        ),
      ]),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  }
}

class _ChatMsg {
  final String name;
  final String text;
  final bool isSelf;
  _ChatMsg(this.name, this.text, this.isSelf);
}

class _ResearchRef {
  final String title;
  final String description;
  final String icon;
  _ResearchRef(this.title, this.description, this.icon);
}
