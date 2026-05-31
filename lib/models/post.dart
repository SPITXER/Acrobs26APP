class Argument {
  final String name;
  final String initials;
  final String stance; // 'counter', 'support', 'question'
  final String text;

  const Argument({
    required this.name,
    required this.initials,
    required this.stance,
    required this.text,
  });
}

class ChatMessage {
  final String from;
  final String initials;
  final String message;
  final bool isMe;

  const ChatMessage({
    required this.from,
    required this.initials,
    required this.message,
    this.isMe = false,
  });
}

class Post {
  final String id;
  final String author;
  final String initials;
  final String credentials;
  final String category; // 'ph', 'sc', 'po', etc.
  final String categoryLabel;
  final String title;
  final String thesis;
  final String timeAgo;
  int replyCount;
  int viewCount;
  final bool isLive;
  final bool isFeatured;
  List<Argument> arguments;
  List<ChatMessage> chats;

  Post({
    required this.id,
    required this.author,
    required this.initials,
    required this.credentials,
    required this.category,
    required this.categoryLabel,
    required this.title,
    required this.thesis,
    required this.timeAgo,
    this.replyCount = 0,
    this.viewCount = 0,
    this.isLive = false,
    this.isFeatured = false,
    this.arguments = const [],
    this.chats = const [],
  });
}

final samplePosts = [
  Post(
    id: 'p1',
    author: 'Marcus A.',
    initials: 'MA',
    credentials: 'Philosopher · Rome',
    category: 'ph',
    categoryLabel: 'Philosophy',
    title: 'Consciousness cannot be reduced to physical processes',
    thesis: "The hard problem of consciousness — why there is subjective experience at all — is fundamentally unsolvable by neuroscience alone. Qualia resist physicalist reduction.",
    timeAgo: '2m ago',
    replyCount: 24,
    viewCount: 336,
    isLive: true,
    isFeatured: true,
    arguments: [
      Argument(name: 'Elena R.', initials: 'ER', stance: 'counter', text: "Integrated Information Theory offers a rigorous mathematical framework. Tononi's phi values are physical and measurable."),
      Argument(name: 'James K.', initials: 'JK', stance: 'support', text: "Nagel's bat argument remains unanswered. No third-person account can capture first-person phenomenology."),
      Argument(name: 'Lena B.', initials: 'LB', stance: 'question', text: "Isn't this an argument from ignorance? Why assume unsolvable rather than merely unsolved?"),
    ],
    chats: [],
  ),
  Post(
    id: 'p2',
    author: 'Dr. Yuki T.',
    initials: 'YT',
    credentials: 'Economist · Tokyo',
    category: 'ec',
    categoryLabel: 'Economics',
    title: 'Universal Basic Income will accelerate inequality, not reduce it',
    thesis: "By removing means-testing, UBI paradoxically transfers welfare resources toward wealthier recipients who need them least.",
    timeAgo: '14m ago',
    replyCount: 41,
    viewCount: 574,
    isLive: true,
    isFeatured: false,
    arguments: [
      Argument(name: 'Priya M.', initials: 'PM', stance: 'counter', text: "Finland's pilot showed no disincentive to work and significant wellbeing gains."),
      Argument(name: 'Dr. Yuki T.', initials: 'YT', stance: 'support', text: "Finland's pilot was small-scale. Macroeconomic effects at national implementation are categorically different."),
    ],
    chats: [],
  ),
  Post(
    id: 'p3',
    author: 'Fatima Al-R.',
    initials: 'FA',
    credentials: 'Bioethicist · Cairo',
    category: 'et',
    categoryLabel: 'Ethics',
    title: 'Gene editing for enhancement is ethically obligatory',
    thesis: "A consequentialist framework demands we reduce preventable suffering where we can. Refusal is not neutrality — it is a choice to allow harm.",
    timeAgo: '1h ago',
    replyCount: 67,
    viewCount: 938,
    isLive: false,
    isFeatured: true,
    arguments: [
      Argument(name: 'Thomas B.', initials: 'TB', stance: 'counter', text: "Only those with resources can access enhancement, permanently stratifying humanity into genetic castes."),
      Argument(name: 'Fatima Al-R.', initials: 'FA', stance: 'support', text: "Which is an argument for equitable access, not prohibition. We don't ban medicine because it's unequally distributed."),
    ],
    chats: [],
  ),
];
