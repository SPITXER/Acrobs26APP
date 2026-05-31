import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/post.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';
import 'lobby_screen.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  int _navIndex = 0;
  String _postFilter = 'all';
  Post? _selectedPost;

  final _catColors = {
    'ph': const Color(0xFFEDE9FE),
    'sc': const Color(0xFFDCFCE7),
    'po': const Color(0xFFFEE2E2),
    'ec': const Color(0xFFFEF3C7),
    'et': const Color(0xFFE0F2FE),
    'hi': const Color(0xFFFDF2F8),
  };
  final _catTextColors = {
    'ph': const Color(0xFF4C1D95),
    'sc': const Color(0xFF14532D),
    'po': const Color(0xFF7F1D1D),
    'ec': const Color(0xFF78350F),
    'et': const Color(0xFF0C4A6E),
    'hi': const Color(0xFF701A75),
  };

  final _replies = [
    'Interesting — can you elaborate on your second premise?',
    "I'd push back on that. The evidence suggests otherwise.",
    'Let me steelman your position before responding.',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AcroColors.parch,
      drawer: _buildDrawer(state),
      appBar: AppBar(
        backgroundColor: AcroColors.parch,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: AcroColors.stoneMid),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Text('ACRO',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: AcroColors.stone, letterSpacing: 1)),
            const SizedBox(width: 8),
            Text(_pageTitle, style: const TextStyle(fontSize: 14, color: AcroColors.stoneLight)),
          ],
        ),
        actions: [
          SizedBox(
            width: 180,
            child: TextField(
              style: const TextStyle(fontSize: 13, color: AcroColors.ink),
              decoration: InputDecoration(
                hintText: 'Search debates…',
                hintStyle: const TextStyle(fontSize: 12, color: AcroColors.stoneLight),
                prefixIcon: const Icon(Icons.search, size: 16, color: AcroColors.stoneLight),
                filled: true,
                fillColor: AcroColors.marble,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AcroColors.marbleDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AcroColors.marbleDark),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen())),
            child: const Text('Lobby', style: TextStyle(color: AcroColors.stoneMid, fontSize: 12)),
          ),
          if (_navIndex == 0)
            TextButton.icon(
              onPressed: () => _showCompose(state),
              icon: const Icon(Icons.add, size: 14, color: AcroColors.stone),
              label: const Text('New Argument', style: TextStyle(color: AcroColors.stone, fontSize: 12)),
              style: TextButton.styleFrom(
                backgroundColor: AcroColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          Expanded(child: _buildPage(state)),
          if (_navIndex == 0 && _selectedPost != null) _buildDetailPanel(state),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() { _navIndex = i; _selectedPost = null; }),
        selectedItemColor: AcroColors.gold,
        unselectedItemColor: AcroColors.stoneLight,
        backgroundColor: AcroColors.parch,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.forum, size: 20), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.event, size: 20), label: 'Meetups'),
          BottomNavigationBarItem(icon: Icon(Icons.people, size: 20), label: 'Network'),
          BottomNavigationBarItem(icon: Icon(Icons.person, size: 20), label: 'Profile'),
        ],
      ),
    );
  }

  String get _pageTitle {
    const titles = ['/ Debate Feed', '/ Meetups', '/ Connections', '/ My Profile'];
    return titles[_navIndex];
  }

  Widget _buildPage(AppState state) {
    switch (_navIndex) {
      case 0: return _buildFeed(state);
      case 1: return _buildMeetups();
      case 2: return _buildConnections();
      case 3: return _buildProfile(state);
      default: return const SizedBox();
    }
  }

  // ── FEED ──────────────────────────────────────────────────────
  Widget _buildFeed(AppState state) {
    final filters = [
      ('all', 'All'), ('live', '🔴 Live'), ('ph', 'Philosophy'),
      ('sc', 'Science'), ('po', 'Politics'), ('et', 'Ethics'),
      ('ec', 'Economics'), ('hi', 'History'),
    ];
    List<Post> posts = state.posts;
    if (_postFilter == 'live') posts = posts.where((p) => p.isLive).toList();
    else if (_postFilter != 'all') posts = posts.where((p) => p.category == _postFilter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compose prompt
          GestureDetector(
            onTap: () => _showCompose(state),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AcroColors.stone, Color(0xFF3C3428)],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AcroColors.gold.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  AcroAvatar(initials: state.profile.initials, size: 34),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                        "What's your thesis today, ${state.profile.firstName}?",
                        style: const TextStyle(color: AcroColors.stoneLight, fontSize: 13)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AcroColors.gold,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text('Write', style: TextStyle(color: AcroColors.stone, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),

          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final active = _postFilter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 14),
                  child: GestureDetector(
                    onTap: () => setState(() => _postFilter = f.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? AcroColors.stone : Colors.transparent,
                        border: Border.all(color: active ? AcroColors.stone : AcroColors.marbleDark),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(f.$2,
                          style: TextStyle(
                              fontSize: 12,
                              color: active ? AcroColors.gold : AcroColors.stoneMid)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Posts
          ...posts.map((p) => _buildPostCard(p, state)),
        ],
      ),
    );
  }

  Widget _buildPostCard(Post post, AppState state) {
    final selected = _selectedPost?.id == post.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPost = selected ? null : post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: selected ? AcroColors.gold : AcroColors.marbleDark),
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected ? [BoxShadow(color: AcroColors.gold.withOpacity(0.1), blurRadius: 20)] : [],
        ),
        child: Stack(
          children: [
            if (selected)
              Positioned(left: 0, top: 0, bottom: 0,
                child: Container(width: 3, decoration: BoxDecoration(color: AcroColors.gold, borderRadius: const BorderRadius.horizontal(left: Radius.circular(13))))),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AcroAvatar(initials: post.initials, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(post.author, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AcroColors.ink)),
                          Text(post.credentials, style: const TextStyle(fontSize: 11, color: AcroColors.stoneLight)),
                        ]),
                      ),
                      Text(post.timeAgo, style: const TextStyle(fontSize: 11, color: AcroColors.stoneLight)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _catColors[post.category] ?? AcroColors.marble,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(post.categoryLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: _catTextColors[post.category] ?? AcroColors.stoneMid)),
                  ),
                  const SizedBox(height: 8),
                  Text(post.title,
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AcroColors.ink, height: 1.35)),
                  const SizedBox(height: 6),
                  Text(
                    post.thesis.length > 120 ? '${post.thesis.substring(0, 120)}…' : post.thesis,
                    style: const TextStyle(fontSize: 13, color: AcroColors.stoneMid, height: 1.65),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 13, color: AcroColors.stoneLight),
                      const SizedBox(width: 4),
                      Text('${post.replyCount}', style: const TextStyle(fontSize: 12, color: AcroColors.stoneLight)),
                      const SizedBox(width: 16),
                      const Icon(Icons.visibility_outlined, size: 13, color: AcroColors.stoneLight),
                      const SizedBox(width: 4),
                      Text('${post.viewCount}', style: const TextStyle(fontSize: 12, color: AcroColors.stoneLight)),
                      const Spacer(),
                      if (post.isLive) ...[
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFE53E3E), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('LIVE', style: TextStyle(color: Color(0xFFE53E3E), fontSize: 11, fontWeight: FontWeight.w700)),
                      ] else
                        Text('${post.arguments.length} arguments',
                            style: const TextStyle(color: AcroColors.green, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            if (post.id == 'p1')
              Positioned(
                top: 13, right: 13,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AcroColors.red, borderRadius: BorderRadius.circular(10)),
                  child: const Text('🔥 HOT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel(AppState state) {
    final post = _selectedPost!;
    final chatCtrl = TextEditingController();

    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AcroColors.marbleDark)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(post.title,
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AcroColors.ink),
                      maxLines: 2),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedPost = null),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AcroColors.marble,
                      borderRadius: BorderRadius.circular(9),
                      border: const Border(left: BorderSide(color: AcroColors.gold, width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.thesis,
                            style: const TextStyle(fontSize: 13, color: AcroColors.stoneMid, height: 1.7)),
                        const SizedBox(height: 9),
                        Row(children: [
                          AcroAvatar(initials: post.initials, size: 22),
                          const SizedBox(width: 7),
                          Text('${post.author} · ${post.credentials}',
                              style: const TextStyle(fontSize: 11, color: AcroColors.stoneLight)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('ARGUMENTS (${post.arguments.length})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: AcroColors.stoneMid, letterSpacing: 1)),
                  const SizedBox(height: 9),
                  ...post.arguments.map((a) => _buildArgBlock(a)),
                  const SizedBox(height: 8),
                  _buildAddArg(post, state),
                ],
              ),
            ),
          ),
          // Live chat area
          Container(
            padding: const EdgeInsets.all(13),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AcroColors.marbleDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFE53E3E), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('Live Conference',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AcroColors.stoneMid, letterSpacing: 0.8)),
                  ],
                ),
                const SizedBox(height: 9),
                if (post.chats.isEmpty)
                  const Text('No messages yet. Start the conversation.',
                      style: TextStyle(fontSize: 12, color: AcroColors.stoneLight))
                else
                  ...post.chats.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: c.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxWidth: 220),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                              decoration: BoxDecoration(
                                color: c.isMe ? AcroColors.stone : AcroColors.marble,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Text(c.message,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: c.isMe ? AcroColors.goldLight : AcroColors.ink,
                                      height: 1.5)),
                            ),
                          ],
                        ),
                      )),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: StatefulBuilder(
                        builder: (ctx, setSt) => TextField(
                          controller: chatCtrl,
                          style: const TextStyle(fontSize: 12, color: AcroColors.ink),
                          onSubmitted: (_) {
                            final t = chatCtrl.text.trim();
                            if (t.isEmpty) return;
                            state.addChatMessage(post.id, ChatMessage(
                              from: state.profile.name, initials: state.profile.initials,
                              message: t, isMe: true,
                            ));
                            chatCtrl.clear();
                            Future.delayed(const Duration(milliseconds: 1000), () {
                              if (mounted) {
                                state.addChatMessage(post.id, ChatMessage(
                                  from: post.author, initials: post.initials,
                                  message: _replies[DateTime.now().millisecond % _replies.length],
                                  isMe: false,
                                ));
                              }
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Share your argument…',
                            hintStyle: const TextStyle(fontSize: 12, color: AcroColors.stoneLight),
                            filled: true, fillColor: AcroColors.marble,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AcroColors.marbleDark)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AcroColors.marbleDark)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection request sent!'))),
                      icon: const Icon(Icons.person_add_outlined, size: 14),
                      label: const Text('Connect', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen())),
                      icon: const Icon(Icons.video_call, size: 14),
                      label: const Text('Open Room', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AcroColors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArgBlock(Argument a) {
    final isCounter = a.stance == 'counter';
    final isSupport = a.stance == 'support';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCounter ? const Color(0xFFFFF5F5) : isSupport ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        border: Border(left: BorderSide(
          color: isCounter ? AcroColors.red : isSupport ? AcroColors.green : AcroColors.gold,
          width: 3,
        )),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCounter ? '↯ COUNTER' : isSupport ? '✓ IN SUPPORT' : '? CHALLENGING',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8,
              color: isCounter ? AcroColors.red : isSupport ? AcroColors.green : AcroColors.goldDark,
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            AcroAvatar(initials: a.initials, size: 22, style: AvatarStyle.stone),
            const SizedBox(width: 7),
            Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 7),
          Text(a.text, style: const TextStyle(fontSize: 13, color: AcroColors.stoneMid, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildAddArg(Post post, AppState state) {
    String stance = 'counter';
    final ctrl = TextEditingController();
    bool visible = false;
    return StatefulBuilder(
      builder: (ctx, setSt) => Column(
        children: [
          if (!visible)
            GestureDetector(
              onTap: () => setSt(() => visible = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AcroColors.marbleDark, width: 1.5, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Center(
                  child: Text('+ Add your argument',
                      style: TextStyle(fontSize: 12, color: AcroColors.stoneLight)),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: AcroColors.marble, borderRadius: BorderRadius.circular(9)),
              child: Column(
                children: [
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12, color: AcroColors.ink),
                    decoration: InputDecoration(
                      hintText: 'State your position clearly…',
                      hintStyle: const TextStyle(fontSize: 12, color: AcroColors.stoneLight),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AcroColors.marbleDark)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AcroColors.marbleDark)),
                      contentPadding: const EdgeInsets.all(9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _stanceBtn('counter', '↯ Counter', stance, (s) => setSt(() => stance = s)),
                      const SizedBox(width: 6),
                      _stanceBtn('support', '✓ Support', stance, (s) => setSt(() => stance = s)),
                      const SizedBox(width: 6),
                      _stanceBtn('question', '? Challenge', stance, (s) => setSt(() => stance = s)),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          final t = ctrl.text.trim();
                          if (t.isEmpty) return;
                          state.addArgument(post.id, Argument(
                            name: state.profile.name, initials: state.profile.initials,
                            stance: stance, text: t,
                          ));
                          ctrl.clear();
                          setSt(() => visible = false);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Argument added.')));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AcroColors.gold, foregroundColor: AcroColors.stone,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stanceBtn(String val, String label, String current, Function(String) onTap) {
    final active = current == val;
    return GestureDetector(
      onTap: () => onTap(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AcroColors.stone : Colors.transparent,
          border: Border.all(color: AcroColors.marbleDark),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, color: active ? AcroColors.gold : AcroColors.stoneMid)),
      ),
    );
  }

  // ── MEETUPS ───────────────────────────────────────────────────
  Widget _buildMeetups() {
    final meetups = [
      ('🏛️', 'Socratic Seminar: On Justice', "Structured dialogue on Plato's Republic.", 'Online', 'Jun 12 · 7pm UTC', 24),
      ('🤖', 'The Ethics of AI: Open Forum', 'Interdisciplinary gathering of philosophers.', 'In Person', 'Jun 15 · 6pm · Berlin', 38),
      ('⚡', 'Debate Night: Free Will vs Determinism', 'Oxford-style debate.', 'Online', 'Jun 18 · 8pm EST', 112),
      ('📚', 'The Vienna Circle Resurrected', 'Monthly reading group on logical positivism.', 'In Person', 'Jun 22 · 5pm · Vienna', 17),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Upcoming Gatherings', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700)),
              ElevatedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event created!'))),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Host Event', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: AcroColors.gold, foregroundColor: AcroColors.stone),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            children: meetups.map((m) => _meetupCard(m.$1, m.$2, m.$3, m.$4, m.$5, m.$6)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _meetupCard(String ico, String title, String desc, String type, String date, int att) {
    final online = type == 'Online';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AcroColors.marbleDark),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: online
                    ? [const Color(0xFF0F0E17), const Color(0xFF1A1A3E)]
                    : [const Color(0xFF1C0A00), const Color(0xFF3A1F00)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Stack(
              children: [
                Center(child: Text(ico, style: const TextStyle(fontSize: 36))),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: online ? const Color(0xFF2D7D4F) : const Color(0xFF8B2E2E),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 2),
                const SizedBox(height: 4),
                Text(desc.length > 60 ? '${desc.substring(0, 60)}…' : desc,
                    style: const TextStyle(fontSize: 12, color: AcroColors.stoneMid), maxLines: 2),
                const SizedBox(height: 9),
                Text('📅 $date', style: const TextStyle(fontSize: 11, color: AcroColors.stoneLight)),
                Text('👥 $att attending', style: const TextStyle(fontSize: 11, color: AcroColors.stoneLight)),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RSVP confirmed!'))),
                    style: ElevatedButton.styleFrom(backgroundColor: AcroColors.gold, foregroundColor: AcroColors.stone, padding: const EdgeInsets.symmetric(vertical: 8)),
                    child: const Text('RSVP', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── CONNECTIONS ───────────────────────────────────────────────
  Widget _buildConnections() {
    final conns = [
      ('MA', 'Marcus A.', 'Philosophy · Rome', ['Phenomenology', 'Stoicism'], true),
      ('YT', 'Dr. Yuki T.', 'Economics · Tokyo', ['Macroeconomics', 'Game Theory'], false),
      ('FA', 'Fatima Al-R.', 'Bioethics · Cairo', ['Bioethics', 'Consequentialism'], true),
    ];
    final sugg = [
      ('RS', 'Ravi S.', 'AI Research · Bangalore', ['AI Safety', 'Phil. of Mind'], true),
      ('ER', 'Elena R.', 'Neuroscience · Berlin', ['Consciousness', 'IIT'], true),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Network', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...conns.map((c) => _connCard(c.$1, c.$2, c.$3, c.$4, c.$5, false)),
          const Divider(height: 28),
          Text('Suggested Minds', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...sugg.map((c) => _connCard(c.$1, c.$2, c.$3, c.$4, c.$5, true)),
        ],
      ),
    );
  }

  Widget _connCard(String ini, String name, String field, List<String> tags, bool online, bool isSugg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AcroColors.marbleDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          AcroAvatar(initials: ini, size: 42),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AcroColors.ink)),
                Text(field, style: const TextStyle(fontSize: 12, color: AcroColors.stoneLight)),
                const SizedBox(height: 6),
                Wrap(spacing: 4, children: tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AcroColors.marble, border: Border.all(color: AcroColors.marbleDark), borderRadius: BorderRadius.circular(10)),
                  child: Text(t, style: const TextStyle(fontSize: 10, color: AcroColors.stoneMid)),
                )).toList()),
              ],
            ),
          ),
          if (online) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AcroColors.green, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isSugg ? 'Request sent to $name!' : 'Opening chat with $name'))),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSugg ? AcroColors.gold : Colors.transparent,
              foregroundColor: isSugg ? AcroColors.stone : AcroColors.stoneMid,
              elevation: 0,
              side: isSugg ? null : const BorderSide(color: AcroColors.marbleDark),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(isSugg ? 'Connect' : 'Message', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── PROFILE ───────────────────────────────────────────────────
  Widget _buildProfile(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AcroColors.marbleDark),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AcroAvatar(initials: state.profile.initials, size: 56),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.profile.name.isEmpty ? '—' : state.profile.name,
                              style: GoogleFonts.playfairDisplay(fontSize: 21, fontWeight: FontWeight.w700)),
                          if (state.profile.location.isNotEmpty)
                            Text('📍 ${state.profile.location} · ${state.profile.field}',
                                style: const TextStyle(fontSize: 13, color: AcroColors.stoneMid)),
                          if (state.profile.quote.isNotEmpty)
                            Text(state.profile.quote,
                                style: const TextStyle(fontSize: 12, color: AcroColors.stoneLight, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showEditProfile(state),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statBox('47', 'Arguments'),
                    _statBox('128', 'Connections'),
                    _statBox('12', 'Debates Won'),
                    _statBox('6', 'Clubs'),
                  ],
                ),
                if (state.profile.interests.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerLeft,
                    child: const Text('INTELLECTUAL INTERESTS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AcroColors.stoneMid, letterSpacing: 0.8))),
                  const SizedBox(height: 10),
                  Wrap(spacing: 7, runSpacing: 7,
                    children: state.profile.interests.map((i) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: AcroColors.stone, borderRadius: BorderRadius.circular(20)),
                      child: Text(i, style: const TextStyle(fontSize: 12, color: AcroColors.gold, fontWeight: FontWeight.w500)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String num, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AcroColors.marble, borderRadius: BorderRadius.circular(9)),
          child: Column(
            children: [
              Text(num, style: GoogleFonts.playfairDisplay(fontSize: 21, fontWeight: FontWeight.w700, color: AcroColors.ink)),
              Text(label, style: const TextStyle(fontSize: 11, color: AcroColors.stoneLight)),
            ],
          ),
        ),
      );

  // ── COMPOSE MODAL ─────────────────────────────────────────────
  void _showCompose(AppState state) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String cat = 'ph', catLabel = 'Philosophy';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Propose a Debate', style: GoogleFonts.playfairDisplay(fontSize: 21, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('YOUR THESIS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AcroColors.stoneMid, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: 'State your argument clearly…', border: OutlineInputBorder())),
                  const SizedBox(height: 14),
                  const Text('ELABORATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AcroColors.stoneMid, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(controller: bodyCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Expand on your position…', border: OutlineInputBorder())),
                  const SizedBox(height: 14),
                  const Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AcroColors.stoneMid, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      ('ph', 'Philosophy'), ('sc', 'Science'), ('po', 'Politics'),
                      ('et', 'Ethics'), ('ec', 'Economics'), ('hi', 'History'),
                    ].map((c) => GestureDetector(
                      onTap: () => setSt(() { cat = c.$1; catLabel = c.$2; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                        decoration: BoxDecoration(
                          color: cat == c.$1 ? AcroColors.stone : Colors.transparent,
                          border: Border.all(color: AcroColors.marbleDark),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(c.$2, style: TextStyle(fontSize: 12, color: cat == c.$1 ? AcroColors.gold : AcroColors.stoneMid)),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final t = titleCtrl.text.trim();
                if (t.isEmpty) return;
                state.addPost(Post(
                  id: 'p${DateTime.now().millisecondsSinceEpoch}',
                  author: state.profile.name.isEmpty ? 'You' : state.profile.name,
                  initials: state.profile.initials.isEmpty ? '?' : state.profile.initials,
                  credentials: state.profile.field.isEmpty ? 'Intellectual' : state.profile.field,
                  category: cat, categoryLabel: catLabel,
                  title: t, thesis: bodyCtrl.text.trim().isEmpty ? t : bodyCtrl.text.trim(),
                  timeAgo: 'just now', isLive: true,
                  arguments: [], chats: [],
                ));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Argument published!')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AcroColors.gold, foregroundColor: AcroColors.stone),
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
  }

  // ── EDIT PROFILE MODAL ────────────────────────────────────────
  void _showEditProfile(AppState state) {
    final nameCtrl = TextEditingController(text: state.profile.name);
    final fieldCtrl = TextEditingController(text: state.profile.field);
    final locCtrl = TextEditingController(text: state.profile.location);
    final quoteCtrl = TextEditingController(text: state.profile.quote);
    final intsCtrl = TextEditingController(text: state.profile.interests.join(', '));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Profile', style: GoogleFonts.playfairDisplay(fontSize: 19, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(children: [
              _modalField('Full Name', nameCtrl),
              _modalField('Field / Title', fieldCtrl),
              _modalField('Location', locCtrl),
              _modalField('Personal Quote', quoteCtrl),
              _modalField('Interests (comma-separated)', intsCtrl),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              state.updateProfileDetails(
                name: nameCtrl.text.trim(),
                field: fieldCtrl.text.trim(),
                location: locCtrl.text.trim(),
                quote: quoteCtrl.text.trim(),
                interests: intsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AcroColors.gold, foregroundColor: AcroColors.stone),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _modalField(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AcroColors.stoneMid, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          ],
        ),
      );

  Widget _buildDrawer(AppState state) {
    return Drawer(
      backgroundColor: AcroColors.stone,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: AcroColors.gold, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('Α', style: GoogleFonts.playfairDisplay(fontSize: 19, fontWeight: FontWeight.w700, color: AcroColors.stone)))),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ACRO', style: GoogleFonts.playfairDisplay(color: AcroColors.gold, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 2)),
                    const Text('The Agora of Ideas', style: TextStyle(fontSize: 10, color: AcroColors.stoneLight, letterSpacing: 0.6)),
                  ]),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.meeting_room, color: AcroColors.gold),
              title: const Text('Debate Lobby', style: TextStyle(color: AcroColors.gold, fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen())); },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('DISCOVER', style: TextStyle(fontSize: 10, letterSpacing: 2, color: AcroColors.stoneLight)),
            ),
            ...[
              (0, Icons.forum, 'Debate Feed'),
              (1, Icons.event, 'Meetups'),
            ].map((item) => ListTile(
              leading: Icon(item.$2, color: _navIndex == item.$1 ? AcroColors.gold : AcroColors.stoneLight),
              title: Text(item.$3, style: TextStyle(color: _navIndex == item.$1 ? AcroColors.gold : AcroColors.stoneLight, fontSize: 13)),
              selected: _navIndex == item.$1,
              selectedTileColor: AcroColors.gold.withOpacity(0.09),
              shape: const Border(left: BorderSide(color: Colors.transparent, width: 2)),
              onTap: () { Navigator.pop(context); setState(() { _navIndex = item.$1; }); },
            )),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('COMMUNITY', style: TextStyle(fontSize: 10, letterSpacing: 2, color: AcroColors.stoneLight)),
            ),
            ...[
              (2, Icons.people, 'Connections'),
              (3, Icons.person, 'My Profile'),
            ].map((item) => ListTile(
              leading: Icon(item.$2, color: _navIndex == item.$1 ? AcroColors.gold : AcroColors.stoneLight),
              title: Text(item.$3, style: TextStyle(color: _navIndex == item.$1 ? AcroColors.gold : AcroColors.stoneLight, fontSize: 13)),
              onTap: () { Navigator.pop(context); setState(() { _navIndex = item.$1; }); },
            )),
            const Spacer(),
            ListTile(
              leading: AcroAvatar(initials: state.profile.initials, size: 34),
              title: Text(state.profile.name.isEmpty ? '—' : state.profile.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text(state.profile.field.isEmpty ? '—' : state.profile.field,
                  style: const TextStyle(color: AcroColors.stoneLight, fontSize: 11)),
              trailing: const Icon(Icons.edit, size: 12, color: AcroColors.stoneLight),
              onTap: () { Navigator.pop(context); setState(() => _navIndex = 3); },
            ),
          ],
        ),
      ),
    );
  }
}
