part of 'chat_screen.dart';

/// ✅ סוג בועה לשליחה (תפריט)
enum BubbleStyle { normal, glow }

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
String _titleTextForRoom(String roomId) {
  switch (roomId) {
    case 'group_main':
      return 'Mystic Messenger';

    default:
      return 'Chat';
  }
}

  static const double _topBarHeight = 0;
  static const double _bottomBarHeight = 80;
  static const double _redFrameTopGap = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _roomSub;

  VoidCallback? _onlineListener;

  // =======================
  // Creepy BG Easter Egg
  // =======================
  String? _bgOverride;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  final ImageMessageService _imageService = ImageMessageService();

  // ✅ IMPORTANT: cached "near bottom" state so UI rebuilds on scroll
  bool _nearBottomCached = true;
// ✅ VER103 — Delete mode (long-press my message)
String? _armedDeleteMessageId;

  late final AnimationController _bgFxCtrl;
late final AnimationController _wiggleCtrl;
late final Animation<double> _wiggleAnim;
Timer? _wiggleTimer;

static const List<String> _creepyTriggers = <String>[
  'glitch',
  'bug',
  'Bug',
  'Saeran',
  'saeran',
  'searan', // typo safety
  'Rika',
  'Savior',
  'Mint',
  'Mint eye',
  'paradise',
  "סארן",
  "סיירן",
  "גליץ'",
  "'גליץ",
  "באג",
  "מנטה",
  "מינט איי",
  "גן עדן",
  "ריקה",
  'struct', // דוגמה – תוסיפי/תמחקי מה שבא לך
];


  static const String _heartAsset = 'assets/reactions/HeartReaction.png';

Widget _buildImageHeartOverlay({
  required Set<String> reactorIds,
  required bool isMe,
  required double uiScale,
}) {
  if (reactorIds.isEmpty) return const SizedBox.shrink();

  final ids = reactorIds.toList()..sort();
  final shown = ids.take(3).toList();

  final double size = 26 * uiScale;
  final double gap = 2 * uiScale;

  return IgnorePointer(
    ignoring: true, // לא חוסם double-tap על התמונה
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < shown.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1,
                ),
              ),
              child: Center(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    _heartColorForUserId(shown[i]),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    _heartAsset,
                    width: size,
                    height: size,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}



// ✅ VER103 — helpers
bool _isMyDeletableMessage(ChatMessage msg) {
  if (msg.type == ChatMessageType.system) return false;
  return msg.senderId == widget.currentUserId;
  
}
// ✅ VER104 — custom text shown when reply target was deleted
static const String _deletedReplyLabel =
    'ERROR 404!!\n~This message is gone FOREVER~';


bool _isArmedDelete(ChatMessage msg) {
  return _armedDeleteMessageId != null && _armedDeleteMessageId == msg.id;
}

void _toggleArmDelete(ChatMessage msg) {
  if (!_isMyDeletableMessage(msg)) return;

  setState(() {
    if (_armedDeleteMessageId == msg.id) {
      _armedDeleteMessageId = null; // toggle off
    } else {
      _armedDeleteMessageId = msg.id; // arm this one
    }
  });
}

Future<void> _deleteArmedMessage(ChatMessage msg) async {
  if (!_isMyDeletableMessage(msg)) return;
  if (!_isArmedDelete(msg)) return;

  // close UI first (feels snappy)
  setState(() => _armedDeleteMessageId = null);

  try {
if (msg.type == ChatMessageType.voice) {
  await FirestoreChatService.deleteVoiceMessage(
    roomId: widget.roomId,
    messageId: msg.id,
  );
} else {
  await FirestoreChatService.deleteMessage(
    roomId: widget.roomId,
    messageId: msg.id,
  );
}

    // no setState needed: stream will remove it
  } catch (e) {
    // If rules block delete or network fails, show small feedback
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not delete message: $e'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}


  bool _isNearBottom({int thresholdItems = 1}) {
    // thresholdItems = כמה פריטים מהסוף עדיין נחשב “למטה”
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return true;

    final maxVisible = positions
        .where((p) => p.itemTrailingEdge > 0) // מופיע במסך
        .map((p) => p.index)
        .fold<int>(-1, (a, b) => a > b ? a : b);

    if (_messages.isEmpty) return true;

    final lastIndex = _messages.length - 1;
    return maxVisible >= (lastIndex - thresholdItems);
  }

  // =======================
  // Mentions (@) (WhatsApp-like picker)
  // =======================
  bool _mentionMenuOpen = false;
  int _mentionAtIndex = -1; // index of '@' in the text
  String _mentionQuery = ''; // text after '@' until caret
  List<ChatUser> _mentionResults = <ChatUser>[];

  String _normalizeMentionToken(String s) {
    // keep letters+digits+hebrew, drop symbols like ★
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0590-\u05FF]+'), '');
  }

  bool _isWordBoundaryBeforeAt(String text, int atIndex) {
    if (atIndex <= 0) return true;
    final ch = text[atIndex - 1];
    return ch.trim().isEmpty; // whitespace boundary
  }

  void _closeMentionMenu() {
    if (!mounted) return;
    if (!_mentionMenuOpen) return;
    setState(() {
      _mentionMenuOpen = false;
      _mentionAtIndex = -1;
      _mentionQuery = '';
      _mentionResults = <ChatUser>[];
    });
  }

  List<ChatUser> _allMentionCandidates() {
    // include everyone except me + optionally exclude bot
    final list = users.values.where((u) {
      if (u.id == widget.currentUserId) return false;
      if (u.id == 'gackto_facto') return false; // optional
      return true;
    }).toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  void _updateMentionMenuFromText() {
    if (!mounted) return;

    final text = _controller.text;
    final sel = _controller.selection;
    final caret = sel.baseOffset;

    if (caret < 0 || caret > text.length) {
      _closeMentionMenu();
      return;
    }

    // Find last '@' BEFORE caret
    final int at = text.lastIndexOf('@', caret - 1);
    if (at < 0) {
      _closeMentionMenu();
      return;
    }

    // Must be boundary before '@' (start or whitespace)
    if (!_isWordBoundaryBeforeAt(text, at)) {
      _closeMentionMenu();
      return;
    }

    // The substring between '@' and caret must not include whitespace/newline
    final between = text.substring(at + 1, caret);
    if (between.contains(RegExp(r'\s'))) {
      _closeMentionMenu();
      return;
    }

    final queryNorm = _normalizeMentionToken(between);

    // Filter candidates by name tokens
    final candidates = _allMentionCandidates();
    final results = candidates.where((u) {
      final nameNorm = _normalizeMentionToken(u.name);
      if (queryNorm.isEmpty) return true;
      return nameNorm.contains(queryNorm);
    }).toList();

    setState(() {
      _mentionMenuOpen = true;
      _mentionAtIndex = at;
      _mentionQuery = between;
      _mentionResults = results;
    });
  }

  void _insertMention(ChatUser u) {
    final text = _controller.text;
    final sel = _controller.selection;
    final caret = sel.baseOffset;

    if (_mentionAtIndex < 0 || caret < 0) return;
    if (_mentionAtIndex >= text.length) return;

    final before = text.substring(0, _mentionAtIndex);
    final after = text.substring(caret);

    final insertion = '@${u.name} ';

    final nextText = before + insertion + after;

    final newCaret = (before.length + insertion.length);

    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: newCaret),
    );

    // keep keyboard open
    _focusNode.requestFocus();

    _closeMentionMenu();
  }

  // =======================
  // Reply (WhatsApp-like preview)
  // =======================
  ChatMessage? _replyTarget;

  // highlight flash per message id
  final Map<String, bool> _highlightByMsgId = <String, bool>{};

  // drag accumulator
  double _dragDx = 0.0;

  String _replyPreviewText(String raw) {
    final s = raw.replaceAll('\n', ' ').trim();
    if (s.isEmpty) return '';
    if (s.length <= 70) return s;
    return '${s.substring(0, 70)}…';
  }

  void _setReplyTarget(ChatMessage msg) {
    if (!mounted) return;
    setState(() => _replyTarget = msg);
  }

  void _clearReplyTarget() {
    if (!mounted) return;
    setState(() => _replyTarget = null);
  }

  void _flashHighlight(String msgId) {
    if (!mounted) return;
    setState(() => _highlightByMsgId[msgId] = true);

    // ✅ exactly 1 second total, fade-out handled by AnimatedOpacity
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() => _highlightByMsgId[msgId] = false);
    });
  }

  Future<void> _jumpToMessageId(String messageId) async {
    final int index = _messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    if (!_itemScrollController.isAttached) return;

    await _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      alignment: 0.15, // קצת מתחת לראש, נראה טוב ל-reply jump
    );

    if (!mounted) return;
    _flashHighlight(messageId);
  }

  // =======================
  // Unread Divider (last read boundary)
  // =======================
  int _lastReadTsCache = 0;
  bool _lastReadLoaded = false;
  bool _hideUnreadDivider = false;

  // =======================
  // NEW "messages below" badge (overlay)
  // =======================
  int _newBelowCount = 0;

  // ✅ NEW: whether there is a mention below (so we can show @)
  bool _newBelowHasMention = false;

  // ✅ When I send a message, we wait for the Firestore snapshot that includes it.
  // When we see that exact ts in the list -> scroll to bottom (even if list length didn't grow).
  int _pendingScrollToBottomTs = 0;

  /// ✅ counts only "real unread-ish" messages:
  /// - text only
  /// - not me
  int _countAddedUnreadishMessages(
      List<ChatMessage> oldList, List<ChatMessage> newList) {
    if (newList.length <= oldList.length) return 0;

    final added = newList.sublist(oldList.length);
    int c = 0;

    for (final m in added) {
      if (m.type == ChatMessageType.text &&
          m.senderId != widget.currentUserId) {
        c++;
      }
    }

    return c;
  }

  /// ✅ NEW: detect if ANY added message is a "mention" of me
  bool _textMentionsUser(ChatMessage m, String userId) {
    final me = users[userId];
    if (me == null) return false;

    final raw = m.text;
    if (raw.isEmpty) return false;

    // direct contains (with the star etc)
    final directToken = '@${me.name}';
    if (raw.contains(directToken)) return true;

    // normalized compare (drop symbols like ★)
    final normRaw = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0590-\u05FF@ ]+'), '');
    final normMe = _normalizeMentionToken(me.name);
    if (normMe.isEmpty) return false;

    if (normRaw.contains('@$normMe')) return true;

    return false;
  }

  bool _hasAddedMentionsOfMe(List<ChatMessage> oldList, List<ChatMessage> newList) {
    if (newList.length <= oldList.length) return false;

    final added = newList.sublist(oldList.length);

    for (final m in added) {
      if (m.type != ChatMessageType.text) continue;
      if (m.senderId == widget.currentUserId) continue;

      // ✅ mention rule 1: reply to MY message
      if (m.replyToSenderId != null && m.replyToSenderId == widget.currentUserId) {
        return true;
      }

      // ✅ mention rule 2: "@Me" in text
      if (_textMentionsUser(m, widget.currentUserId)) {
        return true;
      }
    }

    return false;
  }

  bool _hasUnreadNow() {
    if (!_lastReadLoaded) return false;

    // ✅ UNREAD is only for OTHER people's messages
    return _messages.any((m) =>
        m.type == ChatMessageType.text &&
        m.ts > 0 &&
        m.ts > _lastReadTsCache &&
        m.senderId != widget.currentUserId);
  }

  int _firstUnreadTsOrNull() {
    if (!_lastReadLoaded) return 0;

    // ✅ First unread from OTHER users only
    for (final m in _messages) {
      if (m.type != ChatMessageType.text) continue;
      if (m.ts <= 0) continue;

      if (m.ts > _lastReadTsCache && m.senderId != widget.currentUserId) {
        return m.ts;
      }
    }
    return 0;
  }

  Future<void> _loadLastReadTsOnce() async {
    if (_lastReadLoaded) return;
    _lastReadTsCache = await _loadLastReadTs();
    _lastReadLoaded = true;
  }

  Future<void> _markReadIfAtBottom() async {
    if (!_lastReadLoaded) return;

    // ✅ Don't auto-mark read immediately on entry
    if (_nowMs() < _blockAutoMarkReadUntilMs) return;

    if (!_isNearBottom()) return;

    // ✅ when user reaches bottom: badge disappears
    if ((_newBelowCount != 0 || _newBelowHasMention) && mounted) {
      setState(() {
        _newBelowCount = 0;
        _newBelowHasMention = false;
      });
    }

    final int lastTs = _latestTextTs();
    if (lastTs <= 0) return;

    // nothing to do
    if (lastTs <= _lastReadTsCache) return;

    _lastReadTsCache = lastTs;
    await _saveLastReadTs(lastTs);

    if (mounted) {
      setState(() {
        _hideUnreadDivider = true;
      });
    }
  }

  // =======================
  // Scroll position restore
  // =======================
bool _didRestoreScroll = false;
double _savedScrollOffset = 0.0;
Timer? _scrollSaveDebounce;

// ✅ While opening the room: block any auto-scroll triggers from snapshots.
bool _openingLock = true;

// ✅ Used for hiding list until initial jump is applied (prevents "flash at top")
bool _initialOpenPositionApplied = false;


  // ✅ IMPORTANT: don't save offset until we've restored/jumped once
  bool _allowScrollOffsetSaves = false;
  int _blockAutoMarkReadUntilMs = 0;

  // =======================
  // Unread jump helpers (NO GlobalKeys inside a lazy list)
  // =======================

  // ✅ Stable key per message (safe for ScrollablePositionedList)
  Key _keyForMsg(ChatMessage m) => ValueKey<String>('msg_${m.id}');

  // ✅ Stable key for UNREAD divider (also NOT GlobalKey)
  final Key _unreadDividerKey = ValueKey<String>('unread_divider');

  String _scrollOffsetPrefsKey() =>
      'scrollOffset__${widget.currentUserId}__${widget.roomId}';

  Future<void> _loadSavedScrollOffset() async {
    final prefs = await SharedPreferences.getInstance();
    _savedScrollOffset = prefs.getDouble(_scrollOffsetPrefsKey()) ?? 0.0;
  }

  Future<void> _initScrollAndStream() async {
    await _loadSavedScrollOffset();
    if (!mounted) return;

    // start stream AFTER we know what to restore to
    _startFirestoreSubscription();
  }

  Future<void> _saveScrollOffsetNow() async {
    if (!_scrollController.hasClients) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_scrollOffsetPrefsKey(), _scrollController.offset);
  }

  void _onPositionsChanged() {
    if (!mounted) return;

    // ✅ Always compute and cache "near bottom"
    final bool nearBottom = _isNearBottom();

    // ✅ Force rebuild when near-bottom changes (this fixes the button "stuck" issue)
    if (nearBottom != _nearBottomCached) {
      setState(() {
        _nearBottomCached = nearBottom;
      });
    }

    // ✅ Reveal/hide UNREAD divider based on being near bottom
    if (_lastReadLoaded && _hasUnreadNow()) {
      if (nearBottom) {
        if (!_hideUnreadDivider) {
          setState(() => _hideUnreadDivider = true);
        }
      } else {
        if (_hideUnreadDivider) {
          setState(() => _hideUnreadDivider = false);
        }
      }
    } else {
      // no unread at all -> keep hidden
      if (!_hideUnreadDivider) {
        setState(() => _hideUnreadDivider = true);
      }
    }

    // ✅ Don't do side-effects during initial open
    if (!_allowScrollOffsetSaves) return;

    _scrollSaveDebounce?.cancel();
    _scrollSaveDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;

      // ✅ mark read when user is at bottom
      await _markReadIfAtBottom();

      // ✅ best-effort (note: ScrollablePositionedList doesn't use _scrollController)
      await _saveScrollOffsetNow();
    });
  }

  void _tryRestoreScrollOnce() {
    if (_didRestoreScroll) return;

    int triesLeft = 14;

    void attempt() {
      if (!mounted) return;

      if (!_scrollController.hasClients) {
        triesLeft--;
        if (triesLeft <= 0) return;
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }

      final max = _scrollController.position.maxScrollExtent;

      // Wait until layout stabilizes (avatars/images can change extents).
      if (max <= 0.0 && _messages.isNotEmpty) {
        triesLeft--;
        if (triesLeft <= 0) return;
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }

      final target = _savedScrollOffset.clamp(0.0, max);
      _scrollController.jumpTo(target);

      _didRestoreScroll = true;

      // ✅ now it's safe to save offsets
      _allowScrollOffsetSaves = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  // =======================
  // Heart animation gating
  // =======================
  bool _appIsResumed = true;
  bool _initialSnapshotDone = false;

  // block heart fly animations briefly after opening the chat
  int _enableHeartAnimsAtMs = 0;

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  bool _canPlayHeartFlyAnims() {
    return mounted &&
        _appIsResumed &&
        _initialSnapshotDone &&
        _nowMs() >= _enableHeartAnimsAtMs;
  }

  int _latestTextTs() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.type == ChatMessageType.text && m.ts > 0) return m.ts;
    }
    return 0;
  }

  /// ❤️ Heart colors per user (FINAL)
  static const Map<String, Color> _heartColorByUserId = <String, Color>{
    'lian': Color(0xFFFF2020), // #ff2020
    'lihi': Color(0xFFFF9020), // #ff9020
    'lera': Color(0xFFFFF420), // #fff420
    'tal': Color(0xFF33FF20), // #33ff20
    'danielle': Color(0xFF20D2FF), // #20d2ff
    'joy': Color(0xFFB120FF), // #b120ff
    'adi': Color(0xFFFF20AA), // #ff20aa
  };

  Color _heartColorForUserId(String userId) {
    return _heartColorByUserId[userId] ?? Colors.white;
  }

  List<Widget> _buildHeartIcons(Set<String> reactorIds, double uiScale) {
    if (reactorIds.isEmpty) return const <Widget>[];

    const double baseHeartSize = 40; // הגודל הוויזואלי של הלב
    const double baseHeartGap = 2.0;
Widget buildImageHeartOverlay({
  required Set<String> reactorIds,
  required bool isMe,
  required double uiScale,
}) {
  if (reactorIds.isEmpty) return const SizedBox.shrink();

  // show up to 3 hearts to keep it cute and not messy
  final ids = reactorIds.toList()..sort();
  final shown = ids.take(3).toList();

  final double size = 26 * uiScale;
  final double gap = 2 * uiScale;

  return IgnorePointer(
    ignoring: true, // ✅ overlay shouldn't block taps/double taps
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < shown.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1,
                ),
              ),
              child: Center(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    _heartColorForUserId(shown[i]),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    _heartAsset,
                    width: size,
                    height: size,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

    // גובה "שורת שם" בלבד (זה מה שמונע מהבועה לרדת)
    final double lineHeight = 16 * uiScale;

    final ids = reactorIds.toList()..sort();

    return ids.map((rid) {
      // ✅ each heart color == the user who reacted (liked)
      final tint = _heartColorForUserId(rid);

      return Padding(
        padding: EdgeInsets.only(left: baseHeartGap * uiScale),
        child: SizedBox(
          height: lineHeight,
          width: baseHeartSize * uiScale,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: baseHeartSize * uiScale,
            minWidth: 0,
            maxWidth: baseHeartSize * uiScale,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
              child: Transform.translate(
                offset: Offset(0, -16 * uiScale),
                child: Image.asset(
                  _heartAsset,
                  width: baseHeartSize * uiScale,
                  height: baseHeartSize * uiScale,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  bool _shouldTriggerCreepyEgg(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return false;

    for (final t in _creepyTriggers) {
      final tt = t.trim().toLowerCase();
      if (tt.isEmpty) continue;
      if (s.contains(tt)) return true;
    }
    return false;
  }

  Future<void> _playCreepyEggFx() async {
    if (!mounted) return;

    // 1) swap bg (AnimatedSwitcher will fade)
    setState(() {
      _bgOverride = 'assets/backgrounds/CreepyBackgroundEasterEgg.png';
    });

    // ✅ let the BG fade start, then start the egg
    await Future.delayed(const Duration(milliseconds: 120));

    // 2) creepy music
    if (widget.enableBgm) {
      await Bgm.I.playEasterEgg('bgm/CreepyMusic.mp3');
    }

    // 3) glitch pulses + SFX
    for (int i = 0; i < 3; i++) {
      Sfx.I.playGlitch();
      await _bgFxCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 120));
    }

    // 4) keep creepy bg a moment
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    // ✅ IMPORTANT: stop egg audio now (don’t wait for track to end)
    if (widget.enableBgm) {
      await Bgm.I.cancelEasterEggAndRestore(
        fadeOut: const Duration(milliseconds: 650),
      );
    }

    // 5) return background
    setState(() {
      _bgOverride = null;
    });
  }

  Future<void> _toggleHeartForMessage(ChatMessage msg) async {
    // ✅ Hearts allowed for text + image (but never system)
    if (msg.type == ChatMessageType.system) return;

    // ❌ Block hearts on my own messages (no add, no remove)
    if (msg.senderId == widget.currentUserId) return;

    final me = widget.currentUserId;
    final isAdding = !msg.heartReactorIds.contains(me);

    // Update in Firestore (ALL devices will update via stream)
    await FirestoreChatService.toggleHeart(
      roomId: widget.roomId,
      messageId: msg.id, // ✅ docId
      reactorId: me,
      isAdding: isAdding,
    );

    // ✅ No fly anim here (fly anim is for the RECEIVER / author via snapshot logic)
  }

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // ✅ Random font picker (3 paired fonts: EN + HE)
  final Random _rng = Random();

  // Pair 0: NanumGothic  <-> Heebo
  // Pair 1: NanumMyeongjo <-> FrankRuhlLibre
  // Pair 2: BMHanna      <-> Abraham
  static const List<String> _pairEn = <String>[
    'NanumGothic',
    'NanumMyeongjo',
    'BMHanna',
  ];

  static const List<String> _pairHe = <String>[
    'Heebo',
    'FrankRuhlLibre',
    'Abraham',
  ];

  bool _containsEnglishLetters(String s) => RegExp(r'[A-Za-z]').hasMatch(s);
  bool _containsHebrewLetters(String s) => RegExp(r'[\u0590-\u05FF]').hasMatch(s);


  String _lastReadPrefsKey() =>
      'lastReadMs__${widget.currentUserId}__${widget.roomId}';

  Future<void> _markRoomReadNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReadPrefsKey(), DateTime.now().millisecondsSinceEpoch);
  }

  String _lastReadTsPrefsKey() =>
      'lastReadTs__${widget.currentUserId}__${widget.roomId}';

  Future<int> _loadLastReadTs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastReadTsPrefsKey()) ?? 0;
  }

  Future<void> _saveLastReadTs(int ts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReadTsPrefsKey(), ts);
  }

  bool _shouldTrigger707Egg(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return false;

    // ✅ Full trigger list (from roadmap v28)
    const triggers = <String>[
      '7',
      '70',
      '707',
      'שבע',
      'שבעה',
      'שביעי',
      'שבעים',
      'seven',
      'luciel',
      'saeyoung',
      'saven', // optional typo safety
      'סבן',
      'hacker',
      'האקר',
      'hack',
      'לפרוץ',
      'פרוץ',
      'פריצה',
      'choi',
      'צוי', // NOTE: "צ'וי" becomes "צ וי" after normalization
      'ג\'ינג\'י',
      'גינגי',
      'שיער אדום',
      'אדום בשיער',
      'אדום',
      'לצבוע לאדום',
      'לתכנת',
      'תכנות',
      'קוד',
      'קודים',
    ];

    // ✅ Normalize the MESSAGE: keep only a-z / 0-9 / Hebrew, everything else → space
    String normalize(String x) {
      final cleaned = x
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\u0590-\u05FF]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return cleaned;
    }

    final normalizedMsg = normalize(s);
    if (normalizedMsg.isEmpty) return false;

    final paddedMsg = ' $normalizedMsg ';

    for (final t in triggers) {
      final tt = normalize(t);
      if (tt.isEmpty) continue;

      // ✅ Word-ish matching
      if (paddedMsg.contains(' $tt ')) return true;
    }

    return false;
  }

  // ✅ Live hour update (changes BG + username color even if nobody sends messages)
  Timer? _hourTimer;
  late int _uiHour;
  double _lastKeyboardInset = 0.0;

  void _scheduleNextHourTick() {
    _hourTimer?.cancel();

    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final delay = nextHour.difference(now);

    _hourTimer = Timer(delay, () {
      if (!mounted) return;

      final newHour = DateTime.now().hour;
      if (newHour != _uiHour) {
        setState(() {
          _uiHour = newHour;
        });

        // ✅ swap BGM track on hour change (only if allowed)
        if (widget.enableBgm) {
          Bgm.I.playForHour(newHour);
        }
      }

      // schedule again for the next hour
      _scheduleNextHourTick();
    });
  }

  bool _isTyping = false;
  late List<ChatMessage> _messages;

  // =======================
  // NEW badge (live in-room)
  // =======================
  final Map<int, bool> _newBadgeVisibleByTs = <int, bool>{};
  final Set<int> _seenMessageTs = <int>{};

  void _triggerNewBadgeForTs(int ts) {
    if (ts <= 0) return;

    // ✅ Show longer (so the user actually notices it)
    setState(() {
      _newBadgeVisibleByTs[ts] = true;
    });

    // stays visible longer
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      // ✅ turn OFF (MessageRow will fade it out)
      setState(() {
        _newBadgeVisibleByTs[ts] = false;
      });

      // ✅ keep it in the map a bit longer so fade-out can finish
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _newBadgeVisibleByTs.remove(ts);
      });
    });
  }

  // =======================
  // LIVE Heart reactions (receiver sees fly animation)
  // =======================
  final Map<int, Set<String>> _lastReactorSnapshotByTs = <int, Set<String>>{};
  bool _heartsSnapshotInitialized = false;

  Future<void> _spawnHeartsForReactors(List<String> reactorIds) async {
    for (final rid in reactorIds) {
      if (!mounted) return;
      HeartReactionFlyLayer.of(context)
          .spawnHeart(color: _heartColorForUserId(rid));
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  // ✅ Currently selected bubble template for the NEXT message
  BubbleTemplate _selectedTemplate = BubbleTemplate.normal;

  // ✅ Selected decor for NEXT message
  BubbleDecor _selectedDecor = BubbleDecor.none;

  void _openBubbleTemplateMenu() async {
    final result = await showModalBottomSheet<_TemplateMenuResult>(
      context: context,
      isScrollControlled: true, // ✅ allows large height + scrolling
      backgroundColor: Colors.black.withOpacity(0.92),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) {
        Widget templateTile({
          required BubbleTemplate template,
          required String label,
          required Widget preview,
        }) {
          final isSelected = _selectedTemplate == template;

          return GestureDetector(
            onTap: () => Navigator.pop(
              context,
              _TemplateMenuResult(template: template, decor: _selectedDecor),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.10)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withOpacity(0.35)
                      : Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 44, child: Center(child: preview)),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget decorTile({
          required BubbleDecor decor,
          required String label,
          required Widget preview,
        }) {
          final isSelected = _selectedDecor == decor;

          return GestureDetector(
            onTap: () => Navigator.pop(
              context,
              _TemplateMenuResult(template: _selectedTemplate, decor: decor),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.10)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withOpacity(0.35)
                      : Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 44, child: Center(child: preview)),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget grayBubblePreview() {
          return Container(
            width: 54,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }

        Widget decorPreviewHeartsGray() {
          return SizedBox(
            width: 54,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                grayBubblePreview(),
                Positioned(
                  top: -10,
                  left: -6,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubbleLeftHearts.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -6,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubbleRightHearts.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget decorPreviewPinkHeartsGray() {
          return SizedBox(
            width: 54,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                grayBubblePreview(),
                Positioned(
                  top: -10,
                  left: -6,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubblePinkHeartsLeft.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -6,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubblePinkHeartsRight.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget decorPreviewCornerStarsGlowGray() {
          return SizedBox(
            width: 54,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                grayBubblePreview(),
                Positioned(
                  top: -10,
                  left: -6,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubble4CornerStarsLeft.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -6,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubble4CornerStarsRightpng.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget decorPreviewFlowersRibbonGray() {
          return SizedBox(
            width: 54,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                grayBubblePreview(),
                Positioned(
                  bottom: -10,
                  left: -10,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubbleFlowersAndRibbon.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget decorPreviewStarsGray() {
          return SizedBox(
            width: 54,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                grayBubblePreview(),
                Positioned(
                  bottom: -10,
                  left: -10,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubbleStars.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget decorPreviewDripSadGray() {
          return SizedBox(
            width: 54,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                grayBubblePreview(),
                Positioned(
                  bottom: -16,
                  right: -12,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubbleDrip.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -12,
                  right: -8,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubbleSadFace.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget decorPreviewMusicNotesGray() {
          return SizedBox(
            width: 54,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                grayBubblePreview(),
                Positioned(
                  top: -10,
                  right: -10,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubbleMusicNotes.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget decorPreviewSurpriseGray() {
          return SizedBox(
            width: 54,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                grayBubblePreview(),
                Positioned(
                  top: -10,
                  right: -10,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubbleSurprise.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget decorPreviewKittyGray() {
          return SizedBox(
            width: 54,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                grayBubblePreview(),
                Positioned(
                  top: -10,
                  right: -10,
                  child: ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/decors/TextBubbleKitty.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bubble Style',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: [
                    templateTile(
                      template: BubbleTemplate.normal,
                      label: 'Normal',
                      preview: grayBubblePreview(),
                    ),
                    templateTile(
                      template: BubbleTemplate.glow,
                      label: 'Glow',
                      preview: Container(
                        width: 54,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200.withOpacity(0.35),
                              blurRadius: 16,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                const Text(
                  'Decor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: [
                    decorTile(
                      decor: BubbleDecor.none,
                      label: 'None',
                      preview: grayBubblePreview(),
                    ),
                    decorTile(
                      decor: BubbleDecor.hearts,
                      label: 'Red Hearts',
                      preview: decorPreviewHeartsGray(),
                    ),
                    decorTile(
                      decor: BubbleDecor.pinkHearts,
                      label: 'Pink Hearts',
                      preview: decorPreviewPinkHeartsGray(),
                    ),
                    decorTile(
                      decor: BubbleDecor.cornerStarsGlow,
                      label: 'Shiny Stars',
                      preview: decorPreviewCornerStarsGlowGray(),
                    ),
                    decorTile(
                      decor: BubbleDecor.flowersRibbon,
                      label: 'Flowers',
                      preview: decorPreviewFlowersRibbonGray(),
                    ),
                    decorTile(
                      decor: BubbleDecor.stars,
                      label: 'Stars',
                      preview: decorPreviewStarsGray(),
                    ),
                    decorTile(
                      decor: BubbleDecor.dripSad,
                      label: 'Gloomy',
                      preview: decorPreviewDripSadGray(),
                    ),
                    decorTile(
                      decor: BubbleDecor.musicNotes,
                      label: 'Music Notes',
                      preview: decorPreviewMusicNotesGray(),
                    ),
                    decorTile(
                      decor: BubbleDecor.surprise,
                      label: 'Surprise',
                      preview: decorPreviewSurpriseGray(),
                    ),
                    decorTile(
                      decor: BubbleDecor.kitty,
                      label: 'Kitty',
                      preview: decorPreviewKittyGray(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedTemplate = result.template;
      _selectedDecor = result.decor;
    });
  }

  /// ✅ Bubble style selection (saved per user)
  BubbleStyle _myBubbleStyle = BubbleStyle.normal;

  String _bubbleStylePrefsKey() => 'bubbleStyle__${widget.currentUserId}';

  Future<void> _loadBubbleStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bubbleStylePrefsKey());
    if (raw == BubbleStyle.glow.name) {
      if (mounted) setState(() => _myBubbleStyle = BubbleStyle.glow);
      return;
    }
    if (mounted) setState(() => _myBubbleStyle = BubbleStyle.normal);
  }

  Future<void> _saveBubbleStyle(BubbleStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bubbleStylePrefsKey(), style.name);
  }

  void _openBubbleStyleMenu() {
    // ✅ previews stay gray (templates), the real bubble uses user's color
    const Map<BubbleStyle, String> previewAsset = {
      BubbleStyle.normal: 'assets/bubble_templates/preview_normal.png',
      BubbleStyle.glow: 'assets/bubble_templates/preview_glow.png',
    };

    void select(BubbleStyle style) async {
      setState(() => _myBubbleStyle = style);
      await _saveBubbleStyle(style);
      if (mounted) Navigator.of(context).pop();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) {
        Widget tile(BubbleStyle style) {
          final bool selected = _myBubbleStyle == style;

          return GestureDetector(
            onTap: () => select(style),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? Colors.white : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Image.asset(
                      previewAsset[style]!,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    style == BubbleStyle.normal ? 'Normal' : 'Glow',
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bubble Templates',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.2,
                    children: [
                      tile(BubbleStyle.normal),
                      tile(BubbleStyle.glow),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ===== Hive =====
  static const String _boxName = 'mystic_chat_storage';
  String _roomKey(String roomId) => 'room_messages__$roomId';
  Future<Box> _box() async => Hive.openBox(_boxName);

  Future<void> _loadMessagesForRoom() async {
    final box = await _box();
    final raw = box.get(_roomKey(widget.roomId));

    if (raw is List) {
      _messages = raw.whereType<Map>().map((m) => ChatMessage.fromMap(m)).toList();
    } else {
      _messages = <ChatMessage>[];
      await _saveMessagesForRoom(updateMeta: false);
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveMessagesForRoom({
    bool updateMeta = false,
    String? lastSenderId,
  }) async {
    final box = await _box();

    await box.put(
      _roomKey(widget.roomId),
      _messages.map((m) => m.toMap()).toList(),
    );

    // ✅ Update DM meta with BOTH timestamp + who sent the last real message
    if (updateMeta) {
      await box.put(
        'room_meta__${widget.roomId}',
        <String, dynamic>{
          'lastUpdatedMs': DateTime.now().millisecondsSinceEpoch,
          'lastSenderId': (lastSenderId ?? '').toString(),
        },
      );
    }
  }

  /// =======================
  /// SYSTEM EVENTS (entered/left)
  /// =======================
  String _displayNameForId(String userId) {
    final u = users[userId];
    return u?.name ?? userId;
  }

Future<void> _emitSystemLine(
  String line, {
  bool showInUi = true,
  bool scroll = true,
}) async {
  final ts = DateTime.now().millisecondsSinceEpoch;

  // ✅ ONLY arm "pending scroll" if we actually want auto-scroll for this line.
  // This prevents "entered chatroom" from triggering a bottom scroll via snapshot.
  if (scroll) {
    _pendingScrollToBottomTs = ts;
  }

  await FirestoreChatService.sendSystemLine(
    roomId: widget.roomId,
    text: line,
    ts: ts,
  );

  if (scroll && mounted) {
    _scrollToBottom(animated: true, keepFocus: false);
  }
}


  Future<void> _emitEntered() async {
    final name = _displayNameForId(widget.currentUserId);
    await _emitSystemLine('$name has entered the chatroom.');
  }

  Future<void> _emitLeft({bool showInUi = true}) async {
    final name = _displayNameForId(widget.currentUserId);
    await _emitSystemLine(
      '$name has left the chatroom.',
      showInUi: showInUi,
      scroll: false,
    );
  }

  /// ===== REAL presence (Firestore) =====
  StreamSubscription<Set<String>>? _presenceSub;

  /// We still store a notifier per-room so the UI can rebuild easily.
  static final Map<String, ValueNotifier<Set<String>>> _roomOnline = {};
  late final ValueNotifier<Set<String>> _onlineNotifier;

  /// ===== Typing (Firestore, live) =====
  StreamSubscription<Set<String>>? _typingSub;
  late final ValueNotifier<Set<String>> _typingNotifier;

  // debounce so we don't write to Firestore on every keystroke
  Timer? _typingDebounce;

  // track my last sent typing state (prevents spam)
  bool _meTypingRemote = false;

  void _markMeOnline() {
    _onlineNotifier.value = {..._onlineNotifier.value, widget.currentUserId};
  }

  void _markMeOffline() {
    final next = {..._onlineNotifier.value}..remove(widget.currentUserId);
    _onlineNotifier.value = next;
  }

  void _sendTypingToFirestore(bool shouldType) {
    if (shouldType == _meTypingRemote) return;
    _meTypingRemote = shouldType;

    final name = _displayNameForId(widget.currentUserId);

    PresenceService.I.setTyping(
      roomId: widget.roomId,
      userId: widget.currentUserId,
      displayName: name,
      isTyping: shouldType,
    );
  }

  void _handleTypingChange() {
    final hasFocus = _focusNode.hasFocus;
    final hasText = _controller.text.trim().isNotEmpty;

    final shouldType = hasFocus && hasText;

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _sendTypingToFirestore(shouldType);
    });
  }

  @override
  void initState() {
    super.initState();

  // ✅ NEW: mark this room as currently open (so FG notifications are suppressed)
  NotificationsService.instance.setActiveRoomId(widget.roomId);

_wiggleCtrl = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 420),
);

_wiggleAnim = CurvedAnimation(
  parent: _wiggleCtrl,
  curve: Curves.easeInOut,
);

// 🎀 wiggle חמוד כל 2 שניות
_wiggleTimer = Timer.periodic(const Duration(seconds: 2), (_) {
  if (!mounted) return;
  if (_wiggleCtrl.isAnimating) return;
  if (_nearBottomCached) return; // ❗️לא לזוז כשכבר למטה
  _wiggleCtrl.forward(from: 0);
});

    // ✅ IMPORTANT: open at bottom; show UNREAD only when user scrolls UP.
    _hideUnreadDivider = true;

    _allowScrollOffsetSaves = false;
    _didRestoreScroll = false;

    _loadLastReadTsOnce().then((_) {
      if (!mounted) return;
      setState(() {});
    });

    AuthService.ensureSignedIn(currentUserId: widget.currentUserId);
    WidgetsBinding.instance.addObserver(this);

    _enableHeartAnimsAtMs = _nowMs() + 1600;
    _initialSnapshotDone = false;
    _appIsResumed = true;

    _messages = <ChatMessage>[];

    _bgFxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _uiHour = DateTime.now().hour;

    if (widget.enableBgm) {
      Bgm.I.playForHour(_uiHour);
    }

    _scheduleNextHourTick();

    _onlineNotifier = _roomOnline.putIfAbsent(
      widget.roomId,
      () => ValueNotifier<Set<String>>(<String>{}),
    );

    _typingNotifier = ValueNotifier<Set<String>>(<String>{});

    _typingSub?.cancel();
    _typingSub =
        PresenceService.I.streamTypingUserIds(roomId: widget.roomId).listen((ids) {
      if (!mounted) return;
      _typingNotifier.value = ids;
    });

    _markMeOnline();

    _controller.addListener(_handleTypingChange);
    _controller.addListener(_updateMentionMenuFromText);

    _focusNode.addListener(_handleTypingChange);

    final name = _displayNameForId(widget.currentUserId);
    PresenceService.I.enterRoom(
      roomId: widget.roomId,
      userId: widget.currentUserId,
      displayName: name,
    );

    _presenceSub?.cancel();
    _presenceSub =
        PresenceService.I.streamOnlineUserIds(roomId: widget.roomId).listen((ids) {
      if (!mounted) return;

      _onlineNotifier.value = ids;

      if (widget.roomId == 'group_main') {
        DailyFactBotScheduler.I.pingPresence(roomId: 'group_main');
      }
    });

    if (widget.roomId == 'group_main') {
      DailyFactBotScheduler.I.pingPresence(roomId: 'group_main');
    }

    _loadBubbleStyle();

    _initScrollAndStream();

    _blockAutoMarkReadUntilMs =
        DateTime.now().millisecondsSinceEpoch + 1200;
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _emitSystemLine(
        '${_displayNameForId(widget.currentUserId)} has entered the chatroom.',
        scroll: false,
      );
    });
  }

  @override
  void dispose() {


      // ✅ NEW: leaving chat -> allow notifications again (menu/background etc.)
  NotificationsService.instance.setActiveRoomId(null);
    _emitLeft(showInUi: false);

    PresenceService.I.leaveRoom(
      roomId: widget.roomId,
      userId: widget.currentUserId,
    );

    _roomSub?.cancel();
    _roomSub = null;

    _presenceSub?.cancel();
    _presenceSub = null;

    _typingSub?.cancel();
    _typingSub = null;

    _hourTimer?.cancel();

    _controller.removeListener(_handleTypingChange);
    _controller.removeListener(_updateMentionMenuFromText);

    _focusNode.removeListener(_handleTypingChange);

    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);

    _scrollSaveDebounce?.cancel();
    _scrollSaveDebounce = null;

    _saveScrollOffsetNow();

    _typingDebounce?.cancel();
    _typingDebounce = null;

    PresenceService.I.setTyping(
      roomId: widget.roomId,
      userId: widget.currentUserId,
      displayName: _displayNameForId(widget.currentUserId),
      isTyping: false,
    );

    _scrollController.dispose();
_wiggleTimer?.cancel();
_wiggleCtrl.dispose();

    WidgetsBinding.instance.removeObserver(this);

    _bgFxCtrl.dispose();
    _markMeOffline();

    super.dispose();
  }

  void _startFirestoreSubscription() {
    _roomSub?.cancel();

    _roomSub = FirestoreChatService.messagesStreamMaps(widget.roomId).listen(
      (rows) async {
        final List<ChatMessage> oldMessages = List<ChatMessage>.from(_messages);
        final int oldCount = oldMessages.length;
        final bool wasNearBottomBefore = _isNearBottom();

        final oldSeen = Set<int>.from(_seenMessageTs);

        final Map<int, Set<String>> oldReactorsByTs = <int, Set<String>>{};
        for (final m in oldMessages) {
          if (m.ts > 0) {
            oldReactorsByTs[m.ts] = Set<String>.from(m.heartReactorIds);
          }
        }

        final next = rows.map((m) => ChatMessage.fromMap(m)).toList();
        _messages = next;

        final bool hasNewMessages = next.length > oldCount;
        if (hasNewMessages && !wasNearBottomBefore) {
          final int added = _countAddedUnreadishMessages(oldMessages, next);
          final bool addedMention = _hasAddedMentionsOfMe(oldMessages, next);

          if ((added > 0 || addedMention) && mounted) {
            setState(() {
              if (added > 0) _newBelowCount += added;
              if (addedMention) _newBelowHasMention = true;
            });
          }
        }

final bool snapshotContainsMyPendingMessage =
    (_pendingScrollToBottomTs > 0) &&
        next.any((m) =>
            m.ts == _pendingScrollToBottomTs &&
            m.senderId == widget.currentUserId);

// ✅ During initial open, do NOT auto-scroll based on snapshot.
// We only allow ONE initial jump (to UNREAD or bottom) in firstLoad.
if (!_openingLock) {
  if (wasNearBottomBefore || snapshotContainsMyPendingMessage) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // ✅ one frame is enough; avoid double post-frame
      _scrollToBottom(animated: true, keepFocus: true);

      if (snapshotContainsMyPendingMessage) {
        _pendingScrollToBottomTs = 0;
      }
    });
  }
} else {
  // ✅ Still clear pending ts if we already saw it (prevents later surprise scroll)
  if (snapshotContainsMyPendingMessage) {
    _pendingScrollToBottomTs = 0;
  }
}


        await _loadLastReadTsOnce();

        if (!mounted) return;
        setState(() {});

        if (_seenMessageTs.isEmpty) {
          for (final m in _messages) {
            if (m.ts > 0) _seenMessageTs.add(m.ts);
          }
        } else {
          for (final m in _messages) {
            final int ts = m.ts;
            if (ts > 0 && !oldSeen.contains(ts)) {
              _seenMessageTs.add(ts);

              if (widget.roomId == 'group_main') {
                final bool isMe = m.senderId == widget.currentUserId;
                if (!isMe && m.type == ChatMessageType.text) {
                  _triggerNewBadgeForTs(ts);
                }
              }
            }
          }

          if (widget.roomId == 'group_main') {
            await DailyFactBotScheduler.I.pingPresence(roomId: 'group_main');
          }
        }

        if (!_heartsSnapshotInitialized) {
          _lastReactorSnapshotByTs.clear();
          for (final m in _messages) {
            if (m.ts > 0) {
              _lastReactorSnapshotByTs[m.ts] =
                  Set<String>.from(m.heartReactorIds);
            }
          }
          _heartsSnapshotInitialized = true;

          _initialSnapshotDone = true;
        } else {
          final List<String> reactorsToAnimate = <String>[];

          for (final m in _messages) {
            if (m.type != ChatMessageType.text) continue;
            if (m.ts <= 0) continue;

            if (m.senderId != widget.currentUserId) continue;

            final Set<String> prev =
                oldReactorsByTs[m.ts] ??
                    _lastReactorSnapshotByTs[m.ts] ??
                    <String>{};

            final Set<String> now = Set<String>.from(m.heartReactorIds);

            final added = now.difference(prev);

            added.remove(widget.currentUserId);

            if (added.isNotEmpty) {
              reactorsToAnimate.addAll(added.toList()..sort());
            }

            _lastReactorSnapshotByTs[m.ts] = now;
          }

          if (reactorsToAnimate.isNotEmpty && _canPlayHeartFlyAnims()) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await _spawnHeartsForReactors(reactorsToAnimate);
            });
          }
        }

final bool firstLoad = (oldCount == 0 && !_didRestoreScroll);

if (firstLoad && next.isNotEmpty) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;

    // ✅ One initial positioning, NO animation.
    await _jumpToFirstUnreadIfAny(animated: false);

    if (!mounted) return;

    setState(() {
      _initialOpenPositionApplied = true;
      _openingLock = false; // ✅ allow auto-scroll only AFTER initial positioning
    });

    _didRestoreScroll = true;

    // Do NOT force-hide unread divider here.
    // Let _onPositionsChanged decide based on near-bottom state.
  });
}


      },
    );
  }

  void _openKeyboard() {
    if (_isTyping) {
      _focusNode.requestFocus();
      return;
    }
    setState(() => _isTyping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _scrollToBottom({bool keepFocus = false, bool animated = true}) {
    if (!mounted) return;
    if (!_itemScrollController.isAttached) return;

    final int spacerIndex = _messages.length;

    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bool keyboardOpen = keyboardInset > 0.0;

    final double alignment = keyboardOpen ? 0.85 : 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!_itemScrollController.isAttached) return;

      if (animated) {
        await _itemScrollController.scrollTo(
          index: spacerIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: alignment,
        );
      } else {
        _itemScrollController.jumpTo(
          index: spacerIndex,
          alignment: alignment,
        );
      }

      _allowScrollOffsetSaves = true;

      if (keepFocus) {
        _focusNode.requestFocus();
      }
    });
  }

Future<void> _jumpToFirstUnreadIfAny({bool animated = false}) async {
  final int lastReadTs = await _loadLastReadTs();
if (mounted) {
  setState(() => _initialOpenPositionApplied = true);
}

  int targetIndex = -1;

  for (int i = 0; i < _messages.length; i++) {
    final m = _messages[i];
    if (m.type != ChatMessageType.text) continue;
    if (m.ts <= 0) continue;
    if (m.senderId == widget.currentUserId) continue;

    if (m.ts > lastReadTs) {
      targetIndex = i;
      break;
    }
  }

  if (!_itemScrollController.isAttached) return;

  if (targetIndex < 0) {
    _scrollToBottom(animated: false);
    return;
  }

  if (animated) {
    await _itemScrollController.scrollTo(
      index: targetIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.0,
    );
  } else {
    _itemScrollController.jumpTo(
      index: targetIndex,
      alignment: 0.0,
    );
  }

  _allowScrollOffsetSaves = true;
}


  Future<void> _debugSimulateIncomingMessage() async {
    final ts = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _messages.add(
        ChatMessage(
          id: ts.toString(),
          type: ChatMessageType.text,
          senderId: 'adi',
          text: 'Incoming test from Adi ✨',
          ts: ts,
        ),
      );
    });

    await _saveMessagesForRoom(
      updateMeta: true,
      lastSenderId: 'adi',
    );
  }

Future<void> _sendMessage() async {
  final text = _controller.text.trim();
  final bool triggerCreepy = _shouldTriggerCreepyEgg(text);

  if (text.isEmpty) return;

  // ✅ IMPORTANT: remember if keyboard was actually open
  final bool hadKeyboardFocus = _focusNode.hasFocus;

  final bool triggerEgg = _shouldTrigger707Egg(text);

  final BubbleTemplate templateForThisMessage = _selectedTemplate;
  final BubbleDecor decorForThisMessage = _selectedDecor;

  final bool hasEng = _containsEnglishLetters(text);
  final bool hasHeb = _containsHebrewLetters(text);

  // ✅ Choose one PAIR for the whole message
  final int pairIndex = _rng.nextInt(_pairEn.length);

  // ✅ For now we store a single fontFamily string (backwards-compatible):
  // - Hebrew-only => store HE pair font
  // - Otherwise  => store EN pair font (covers English-only + mixed)
  final String fontFamilyForThisMessage =
      (hasHeb && !hasEng) ? _pairHe[pairIndex] : _pairEn[pairIndex];

  final ts = DateTime.now().millisecondsSinceEpoch;
  _pendingScrollToBottomTs = ts;

  final ChatMessage? reply = _replyTarget;
  final String? replyToId = reply?.id;
  final String? replyToSenderId = reply?.senderId;
  final String? replyToText = reply?.text;

  setState(() {
    _controller.clear();

    // ✅ If user sent while keyboard is CLOSED (preview), keep it closed.
    _isTyping = hadKeyboardFocus;

    _selectedTemplate = BubbleTemplate.normal;
    _selectedDecor = BubbleDecor.none;

    _replyTarget = null;
  });

  _sendTypingToFirestore(false);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    if (hadKeyboardFocus) {
      _focusNode.requestFocus(); // keep open only if it was open
    } else {
      _focusNode.unfocus(); // make sure it stays closed
    }
  });

  await FirestoreChatService.sendTextMessage(
    roomId: widget.roomId,
    senderId: widget.currentUserId,
    text: text,
    ts: ts,
    bubbleTemplate: templateForThisMessage.name,
    decor: decorForThisMessage.name,
    fontFamily: fontFamilyForThisMessage,
    replyToMessageId: replyToId,
    replyToSenderId: replyToSenderId,
    replyToText: replyToText,
  );

  Sfx.I.playSend();

  if (triggerEgg) {
    Sfx.I.play707VoiceLine();
  }

  if (triggerCreepy) {
    _playCreepyEggFx();
  }
}


  void _onTapScrollToBottomButton() {
    if (mounted) {
      setState(() {
        _newBelowCount = 0;
        _newBelowHasMention = false;
      });
    }

    _scrollToBottom(animated: true, keepFocus: true);
    _markReadIfAtBottom();
  }
Future<void> _sendVoiceMessage({
  required String filePath,
  required int durationMs,
}) async {
  final ts = DateTime.now().millisecondsSinceEpoch;
  _pendingScrollToBottomTs = ts;

  // ✅ Send via Firebase: creates Firestore doc + uploads to Storage
  await FirestoreChatService.sendVoiceMessage(
    roomId: widget.roomId,
    senderId: widget.currentUserId,
    localFilePath: filePath,
    durationMs: durationMs,
    ts: ts,
    bubbleTemplate: BubbleTemplate.normal.name,
    decor: BubbleDecor.none.name,
  );

  Sfx.I.playSend();

  _scrollToBottom(animated: true, keepFocus: true);
}

  @override
  Widget build(BuildContext context) {
    final int hour = _uiHour;
    final bg = _bgOverride ?? backgroundForHour(hour);
    final Color usernameColor = usernameColorForHour(hour);
    final Color timeColor = timeColorForHour(hour);

    final double uiScale = mysticUiScale(context);

    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_lastKeyboardInset == keyboardInset) return;
      _lastKeyboardInset = keyboardInset;

      if (_isNearBottom()) {
        _scrollToBottom(animated: false);
      }
    });

    debugPrint('HOUR=$hour  usernameColor=$usernameColor  bg=$bg  uiScale=$uiScale');

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();

        if (mounted) {
          setState(() => _isTyping = false);
              // ✅ VER104 — tap outside cancels delete mode
    _armedDeleteMessageId = null;
        }
      },
child: Scaffold(
  backgroundColor: Colors.black,

  // ✅ IMPORTANT: we handle keyboard spacing ourselves via the list spacer
  resizeToAvoidBottomInset: false,

  floatingActionButton: kEnableDebugIncomingPreview
      ? FloatingActionButton(
          onPressed: _debugSimulateIncomingMessage,
          child: const Icon(Icons.bug_report),
        )
      : null,
  body: Column(
    children: [

            const TopBorderBar(height: _topBarHeight),
            SafeArea(
              bottom: false,
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: _onlineNotifier,
builder: (context, onlineIds, _) {
return ActiveUsersBar(
  usersById: users,
  onlineUserIds: onlineIds,
  currentUserId: widget.currentUserId,
  onBack: () async {
    if (widget.enableBgm) {
      await Bgm.I.leaveGroupAndResumeHomeDm();
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
  },
  onOpenBubbleMenu: _openBubbleTemplateMenu,
  onPickImage: () async {
    try {
      final roomId = widget.roomId;

      final ts = DateTime.now().millisecondsSinceEpoch;
      _pendingScrollToBottomTs = ts;
await _imageService.pickAndSendMedia(
  roomId: roomId,
  senderId: widget.currentUserId,
  ts: ts,
);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick/send image: $e')),
      );
    }
  },

  // ✅ NEW: voice
  onSendVoice: (filePath, durationMs) =>
      _sendVoiceMessage(filePath: filePath, durationMs: durationMs),

  // ✅ show friendly title instead of raw roomId
  titleText: _titleTextForRoom(widget.roomId),

  uiScale: uiScale,
);

},

              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _redFrameTopGap,
                    bottom: 0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 1200),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      layoutBuilder:
                          (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: AnimatedBuilder(
                        key: ValueKey(bg),
                        animation: _bgFxCtrl,
                        builder: (context, _) {
                          final t = _bgFxCtrl.value;

                          final bool glitchOn = _bgOverride != null;

                          final double pulse = (t * (1.0 - t)) * 4.0;
                          final double blur = glitchOn ? (pulse * 7.0) : 0.0;

                          final double dx = glitchOn ? (sin(t * 40) * 8.0) : 0.0;
                          final double dy = glitchOn ? (cos(t * 36) * 6.0) : 0.0;
                          final double rot = glitchOn ? (sin(t * 20) * 0.03) : 0.0;

                          Widget img = Image.asset(
                            bg,
                            fit: BoxFit.cover,
                          );

                          if (!glitchOn) return img;

                          return Transform.translate(
                            offset: Offset(dx, dy),
                            child: Transform.rotate(
                              angle: rot,
                              child: ImageFiltered(
                                imageFilter:
                                    ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.matrix(<double>[
                                    1, 0, 0, 0, 18 * pulse,
                                    0, 1, 0, 0, 6 * pulse,
                                    0, 0, 1, 0, 24 * pulse,
                                    0, 0, 0, 1, 0,
                                  ]),
                                  child: img,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _redFrameTopGap,
                    bottom: 0,
                    child: Column(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<Set<String>>(
                            valueListenable: _typingNotifier,
                            builder: (context, typingIds, _) {
                              final typingList = typingIds.toList();
                              typingList.sort((a, b) {
                                final an = users[a]?.name ?? a;
                                final bn = users[b]?.name ?? b;
                                return an.toLowerCase().compareTo(bn.toLowerCase());
                              });

                              final limitedTyping = typingList.take(3).toList();

                              return Opacity(
  opacity: (_initialOpenPositionApplied || _messages.isEmpty) ? 1.0 : 0.0,
  child: IgnorePointer(
    ignoring: !(_initialOpenPositionApplied || _messages.isEmpty),
    child: ScrollablePositionedList.builder(

                                itemScrollController: _itemScrollController,
                                itemPositionsListener: _itemPositionsListener,
                                padding: EdgeInsets.only(
                                  top: 8 * uiScale,
                                  bottom: 0,
                                ),
                                itemCount: _messages.length + 1,
                                itemBuilder: (context, index) {
                   if (index == _messages.length) {
  final bool keyboardOpen = keyboardInset > 0.0;
  final double safeBottom = MediaQuery.of(context).padding.bottom;

  // ✅ If Scaffold is resizing for keyboard, DON'T add keyboardInset again.
  final double extraBottomWhenKeyboardOpen = 70 * uiScale;
  final double bottomWhenClosed = (28 * uiScale) + safeBottom;

  final double spacerHeight = keyboardOpen
      ? extraBottomWhenKeyboardOpen
      : bottomWhenClosed;

  return SizedBox(height: spacerHeight);
}


                                  const double chatSidePadding = 16;

                                  final msg = _messages[index];
                                  final prev = index > 0 ? _messages[index - 1] : null;
final String? replyId = msg.replyToMessageId;
final bool replyTargetExists = (replyId == null)
    ? false
    : _messages.any((m) => m.id == replyId);


                                  bool showDateDivider = false;
                                  String dateLabel = '';

                                  if (widget.roomId == 'group_main' && msg.ts > 0) {
                                    final msgDay =
                                        DateTime.fromMillisecondsSinceEpoch(msg.ts);

                                    if (prev == null || prev.ts <= 0) {
                                      showDateDivider = true;
                                      dateLabel = _dayLabel(msgDay);
                                    } else {
                                      final prevDay =
                                          DateTime.fromMillisecondsSinceEpoch(prev.ts);
                                      if (!_isSameDay(msgDay, prevDay)) {
                                        showDateDivider = true;
                                        dateLabel = _dayLabel(msgDay);
                                      }
                                    }
                                  }

                                  double topSpacing;
                                  if (msg.type == ChatMessageType.system) {
                                    topSpacing = 14;
                                  } else if (prev == null) {
                                    topSpacing = 10;
                                  } else if (prev.type == ChatMessageType.system) {
                                    topSpacing = 12;
                                  } else if (prev.senderId == msg.senderId) {
                                    topSpacing = 18;
                                  } else {
                                    topSpacing = 12;
                                  }

                                  final List<Widget> pieces = <Widget>[];

                                  if (showDateDivider) {
                                    pieces.add(_GcDateDivider(
                                        label: dateLabel, uiScale: uiScale));
                                  }

                                  final int firstUnreadTs = _firstUnreadTsOrNull();
                                  final bool showUnreadDivider = !_hideUnreadDivider &&
                                      firstUnreadTs > 0 &&
                                      msg.type == ChatMessageType.text &&
                                      msg.ts == firstUnreadTs;

                                  if (showUnreadDivider) {
                                    pieces.add(
                                      KeyedSubtree(
                                        key: _unreadDividerKey,
                                        child: _UnreadDivider(
                                            uiScale: uiScale, text: 'UNREAD'),
                                      ),
                                    );
                                  }

                                  if (msg.type == ChatMessageType.system) {
                                    const double systemSideInset = 2.0;
                                    pieces.add(
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          systemSideInset * uiScale,
                                          topSpacing * uiScale,
                                          systemSideInset * uiScale,
                                          0,
                                        ),
                                        child: SystemMessageBar(
                                            text: msg.text, uiScale: uiScale),
                                      ),
                                    );

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: pieces,
                                    );
                                  }

                                  final user = users[msg.senderId];
                                  if (user == null) return const SizedBox.shrink();

                                  final isMe = user.id == widget.currentUserId;
                                  final bool isGroup = widget.roomId == 'group_main';
                                  final bool showNew =
                                      isGroup ? (_newBadgeVisibleByTs[msg.ts] ?? false) : false;

                                  pieces.add(
                                    KeyedSubtree(
                                      key: _keyForMsg(msg),
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          chatSidePadding * uiScale,
                                          topSpacing * uiScale,
                                          chatSidePadding * uiScale,
                                          0,
                                        ),
  child: GestureDetector(
  behavior: HitTestBehavior.translucent,

  // ✅ VER103 — long press arms delete ONLY for my own messages
  onLongPress: () {
    if (_isMyDeletableMessage(msg)) {
      _toggleArmDelete(msg);
    }
  },

  onDoubleTap: (msg.type == ChatMessageType.image)
      ? null
      : () => _toggleHeartForMessage(msg),

  onHorizontalDragStart: (_) {
    _dragDx = 0.0;
  },
  onHorizontalDragUpdate: (details) {
    _dragDx += details.delta.dx;

    final bool swipeOk = (_dragDx > 28);

    if (swipeOk) {
      _dragDx = 0.0;
      _setReplyTarget(msg);
      _flashHighlight(msg.id);
      _focusNode.requestFocus();
    }
  },
  onHorizontalDragEnd: (_) {
    _dragDx = 0.0;
  },

child: Stack(
  children: [
    // ✅ existing reply/highlight glow (unchanged)
    Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          opacity: (_highlightByMsgId[msg.id] ?? false) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22 * uiScale),
              color: user.bubbleColor.withOpacity(0.18),
              boxShadow: [
                BoxShadow(
                  color: user.bubbleColor.withOpacity(0.45),
                  blurRadius: 22 * uiScale,
                  spreadRadius: 1.5 * uiScale,
                ),
              ],
            ),
          ),
        ),
      ),
    ),

    // ✅ VER103 — armed-delete highlight (subtle tint in user's bubble color)
    Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          opacity: _isArmedDelete(msg) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22 * uiScale),
              color: user.bubbleColor.withOpacity(0.12),
              border: Border.all(
                color: user.bubbleColor.withOpacity(0.35),
                width: 1.2 * uiScale,
              ),
            ),
          ),
        ),
      ),
    ),

    MessageRow(
      user: user,
      text: msg.text,
      isMe: isMe,
      bubbleTemplate: msg.bubbleTemplate,
      decor: msg.decor,
      fontFamily: msg.fontFamily,
      showName: (widget.roomId == 'group_main'),
      // ✅ KEEP: hearts next to username
      nameHearts: (widget.roomId == 'group_main')
          ? _buildHeartIcons(msg.heartReactorIds, uiScale)
          : const <Widget>[],
      showTime: (widget.roomId == 'group_main'),
      timeMs: msg.ts,
      showNewBadge: showNew,
      usernameColor: usernameColor,
      timeColor: timeColor,
      uiScale: uiScale,
      replyToSenderName: (msg.replyToSenderId == null)
          ? null
          : (users[msg.replyToSenderId!]?.name ?? msg.replyToSenderId!),
      replyToText: (replyId == null)
          ? null
          : (replyTargetExists ? msg.replyToText : _deletedReplyLabel),
      onTapReplyPreview: () {
        if (replyId == null) return;

        if (!replyTargetExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_deletedReplyLabel),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }

        _jumpToMessageId(replyId);
      },
messageType: (msg.type == ChatMessageType.image)
    ? 'image'
    : (msg.type == ChatMessageType.voice)
        ? 'voice'
        : (msg.type == ChatMessageType.video)
            ? 'video'
            : 'text',
imageUrl: msg.imageUrl,
videoUrl: msg.videoUrl,


// ✅ voice
voicePath: msg.voicePath,
voiceDurationMs: msg.voiceDurationMs,

onDoubleTapImage: (msg.type == ChatMessageType.image)
    ? () => _toggleHeartForMessage(msg)
    : null,

    ),

    // ✅ existing outline highlight (unchanged)
    Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          opacity: (_highlightByMsgId[msg.id] ?? false) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18 * uiScale),
              border: Border.all(
                color: user.bubbleColor.withOpacity(0.55),
                width: 1.6 * uiScale,
              ),
            ),
          ),
        ),
      ),
    ),

    // ✅ VER103 — X button on the EMPTY LEFT SIDE (outside bubble)
    // ✅ VER104 — X centered vertically on the empty LEFT side
    if (_isArmedDelete(msg) && _isMyDeletableMessage(msg))
      Positioned.fill(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 2 * uiScale),
            child: GestureDetector(
              onTap: () => _deleteArmedMessage(msg),
              child: Container(
                width: 26 * uiScale,
                height: 26 * uiScale,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: user.bubbleColor.withOpacity(0.45),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.close,
                  size: 18 * uiScale,
                  color: user.bubbleColor.withOpacity(0.95),
                ),
              ),
            ),
          ),
        ),
      ),
  ],
),


),

                                      ),
                                    ),
                                  );

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: pieces,
                                  );
                                },
                                  ),
  ),
);

                              
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

// ✅ Typing overlay (always visible, even when user is scrolled up)
Positioned(
  left: 0,
  right: -2,

  // ✅ IMPORTANT:
  // The Column already shrinks the Expanded(Stack) when keyboard opens,
  // because BottomBorderBar is wrapped with AnimatedPadding(bottom: keyboardInset).
  // So adding keyboardInset here double-shifts and can push the overlay out of view.
  bottom: (8 * uiScale),

  child: IgnorePointer(
    ignoring: true,
    child: ValueListenableBuilder<Set<String>>(
      valueListenable: _typingNotifier,
      builder: (context, typingIds, _) {
        final ids = typingIds.toList()..remove(widget.currentUserId);
        if (ids.isEmpty) return const SizedBox.shrink();

        ids.sort((a, b) {
          final an = users[a]?.name ?? a;
          final bn = users[b]?.name ?? b;
          return an.toLowerCase().compareTo(bn.toLowerCase());
        });

        final limited = ids.take(3).toList();
        const double chatSidePadding = 16;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: chatSidePadding * uiScale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final uid in limited)
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * uiScale),
                  child: TypingBubbleRow(
                    user: users[uid]!,
                    isMe: false,
                    uiScale: uiScale,
                  ),
                ),
            ],
          ),
        );
      },
    ),
  ),
),




// ✅ NEW messages-below badge (wiggle cute)
if (_newBelowCount > 0 && !_nearBottomCached)
  Positioned(
    right: 16 * uiScale,
    bottom: 80 * uiScale, // ⬆️ הועלה למעלה (Mystic-like)
    child: AnimatedBuilder(
      animation: _wiggleAnim,
      builder: (context, child) {
        final t = _wiggleAnim.value;

        final dx = sin(t * pi * 2) * 3; // תזוזה קטנה
        final rot = sin(t * pi * 2) * 0.03; // סיבוב עדין
        final scale = 1.0 + (0.04 * sin(t * pi)); // bounce חמוד

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: NewMessagesBadge(
        count: _newBelowCount,
        badgeColor: const Color(0xFFEF797E),
        hasMention: _newBelowHasMention,
        onTap: _onTapScrollToBottomButton,
      ),
    ),
  ),



                  // ✅ Scroll-to-bottom button (WhatsApp-style)
                  if (!_nearBottomCached)
                    Positioned(
                      right: 16 * uiScale,
                      bottom: 16 * uiScale,
                      child: GestureDetector(
                        onTap: _onTapScrollToBottomButton,
                        child: Container(
                          width: 44 * uiScale,
                          height: 44 * uiScale,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.22),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 16 * uiScale,
                                spreadRadius: 1 * uiScale,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 30 * uiScale,
                          ),
                        ),
                      ),
                    ),

                  // ✅ Mystic red frame
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _redFrameTopGap,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: CustomPaint(
                        painter: _MysticRedFramePainter(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Mentions picker (WhatsApp-like) — sits above the input bar
            if (_mentionMenuOpen)
              _MentionPickerBar(
                uiScale: uiScale,
                results: _mentionResults,
                onPick: (u) => _insertMention(u),
                onClose: _closeMentionMenu,
                heartColorForUserId: _heartColorForUserId,
              ),

            // ✅ WhatsApp-like Reply Preview (only when replying)
            if (_replyTarget != null)
              ReplyPreviewBar(
                uiScale: uiScale,
                stripeColor: (users[_replyTarget!.senderId]?.bubbleColor ??
                    Colors.white),
                title: _displayNameForId(_replyTarget!.senderId),
                subtitle: _replyPreviewText(_replyTarget!.text),
                onTap: () {
                  final id = _replyTarget!.id;
                  _jumpToMessageId(id);
                },
                onClose: _clearReplyTarget,
              ),
AnimatedPadding(
  duration: const Duration(milliseconds: 120),
  curve: Curves.easeOut,
  padding: EdgeInsets.only(bottom: keyboardInset),
  child: BottomBorderBar(
    height: _bottomBarHeight * uiScale,
    isTyping: _isTyping,
    onTapTypeMessage: _openKeyboard,
    controller: _controller,
    focusNode: _focusNode,
    onSend: _sendMessage,
    uiScale: uiScale,
  ),
),

          ],
        ),
      ),
    );
  }
}
