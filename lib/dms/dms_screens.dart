import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/bgm.dart';
import '../audio/sfx.dart';

part 'dms_core.dart';
part 'dms_widgets.dart';
part 'dms_painters.dart';



class DmsListScreen extends StatefulWidget {
  final String currentUserId;

  const DmsListScreen({super.key, required this.currentUserId});

  @override
  State<DmsListScreen> createState() => _DmsListScreenState();
}

class _DmsListScreenState extends State<DmsListScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkleController;

// ✅ prevents double back sound when we pop manually (top bar back)
bool _suppressNextPopSound = false;


  static const String _boxName = 'mystic_chat_storage';
  String _roomKey(String roomId) => 'room_messages__$roomId';
  String _metaKey(String roomId) => 'room_meta__$roomId';
  String _lastReadKeyFor(String roomId) =>
      'lastReadMs__${widget.currentUserId}__$roomId';

@override
void initState() {
  super.initState();

  // ✅ DMs use same Home BGM
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Bgm.I.playHomeDm();
  });

  _twinkleController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
}


  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  String _dmRoomId(String a, String b) {
    final pair = [a, b]..sort();
    return 'dm_${pair[0]}_${pair[1]}';
  }

  static const String _roomsCol = 'dm_rooms';

  Future<void> _ensureDmRoomExists({
    required String roomId,
    required String me,
    required String other,
  }) async {
    final ref = FirebaseFirestore.instance.collection(_roomsCol).doc(roomId);
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'participants': [me, other]..sort(),
      'lastUpdatedMs': 0,
      'lastSenderId': '',
      'lastText': '',
      'createdMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  Future<List<_DmEntry>> _loadDmEntries() async {
    final prefs = await SharedPreferences.getInstance();

    final others = dmUsers.values
        .where((u) => u.id != widget.currentUserId)
        .toList();

    final entries = <_DmEntry>[];

    for (final u in others) {
      final roomId = _dmRoomId(widget.currentUserId, u.id);

      // ✅ create room doc once (so list always has something to open)
      await _ensureDmRoomExists(
        roomId: roomId,
        me: widget.currentUserId,
        other: u.id,
      );

      final doc = await FirebaseFirestore.instance
          .collection(_roomsCol)
          .doc(roomId)
          .get();

      final data = (doc.data() ?? <String, dynamic>{});

      final int lastUpdatedMs =
          (data['lastUpdatedMs'] is int) ? data['lastUpdatedMs'] as int : 0;

      final String lastSenderId =
          (data['lastSenderId'] ?? '').toString();

      final String previewRaw =
          (data['lastText'] ?? '').toString().trim();

      final String preview =
          previewRaw.isEmpty ? 'Tap to open chat' : previewRaw;

      final lastReadMs = prefs.getInt(_lastReadKeyFor(roomId)) ?? 0;

      final bool unread =
          (lastUpdatedMs > lastReadMs) && (lastSenderId != widget.currentUserId);

      entries.add(
        _DmEntry(
          user: u,
          roomId: roomId,
          lastUpdatedMs: lastUpdatedMs,
          unread: unread,
          preview: preview,
        ),
      );
    }

    entries.sort((a, b) {
      final byTime = b.lastUpdatedMs.compareTo(a.lastUpdatedMs);
      if (byTime != 0) return byTime;
      return a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase());
    });

    return entries;
  }


@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: true,
    onPopInvoked: (didPop) {
      // ✅ if we already played back sound manually (top bar back), skip once
      if (_suppressNextPopSound) {
        _suppressNextPopSound = false;
        return;
      }

      // ✅ system back (Android back / iOS swipe)
      try {
        Sfx.I.playBack();
      } catch (_) {}
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ✅ Static background image
          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/StarsBG.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // ✅ Animated glints on top
          Positioned.fill(
            child: MysticStarTwinkleOverlay(
              animation: _twinkleController,
              starCount: 58,
              sizeMultiplier: 1.25,

            ),
          ),

          SafeArea(
            child: Column(
              children: [
_DmTopBar(
  onBack: () async {
    // 🔊 Back SFX (do NOT await — navigate immediately)
    try {
      Sfx.I.playBack();
    } catch (_) {}

    // ✅ tell PopScope to NOT play sound again
    _suppressNextPopSound = true;

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  },
),

                Expanded(
                  child: Builder(
                    builder: (context) {
                      final double uiScale = mysticUiScale(context);
                      double s(double v) => v * uiScale;

                      return FutureBuilder<List<_DmEntry>>(
                        future: _loadDmEntries(),
                        builder: (context, snap) {
                          final items = snap.data ?? const <_DmEntry>[];

                          return ListView.separated(
                    padding: EdgeInsets.symmetric(
  horizontal: s(10), // ⬅️ פחות שוליים = מלבן רחב יותר
  vertical: s(10),
),

                            itemCount: items.length,
                            separatorBuilder: (_, __) => SizedBox(height: s(9)),

                            itemBuilder: (context, index) {
                              final e = items[index];
                              final double uiScale = mysticUiScale(context);

                              return _DmRowTile(
                                user: e.user,
                                previewText: e.preview,
                                unread: e.unread,
                                lastUpdatedMs: e.lastUpdatedMs,
                                uiScale: uiScale,
          onTap: () async {
  // 🔊 SFX — DM room selected (do NOT await)
  try {
    Sfx.I.playSelectDm();
  } catch (_) {}

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DmChatScreen(
        currentUserId: widget.currentUserId,
        otherUserId: e.user.id,
        otherName: e.user.name,
        roomId: e.roomId,
      ),
    ),
  );

  if (mounted) setState(() {});
},

                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}


}










/// =======================================
/// DM CHAT SCREEN (separate from group ChatScreen)
/// =======================================
class DmChatScreen extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final String otherName;
  final String roomId;

  const DmChatScreen({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherName,
    required this.roomId,
  });

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen>
    with SingleTickerProviderStateMixin {

  static const String _roomsCol = 'dm_rooms';
  static const String _msgsSub = 'messages';

  final ScrollController _scroll = ScrollController();
  final TextEditingController _c = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final AnimationController _twinkleController;

  bool _isTyping = false;

  String _lastReadKey() =>
      'lastReadMs__${widget.currentUserId}__${widget.roomId}';

  DocumentReference<Map<String, dynamic>> get _roomRef =>
      FirebaseFirestore.instance.collection(_roomsCol).doc(widget.roomId);

  CollectionReference<Map<String, dynamic>> get _msgsRef =>
      _roomRef.collection(_msgsSub);

  Stream<QuerySnapshot<Map<String, dynamic>>> get _msgsStream =>
      _msgsRef.orderBy('tsMs', descending: false).snapshots();

  Future<void> _markReadNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReadKey(), DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _ensureRoomExists() async {
    final snap = await _roomRef.get();
    if (snap.exists) return;

    final pair = [widget.currentUserId, widget.otherUserId]..sort();

    await _roomRef.set({
      'participants': pair,
      'lastUpdatedMs': 0,
      'lastSenderId': '',
      'lastText': '',
      'createdMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  void _scrollToBottom({bool keepFocus = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (keepFocus) _focus.requestFocus();
    });
  }

  void _onTapType() {
    if (_isTyping) {
      _focus.requestFocus();
      return;
    }
    setState(() => _isTyping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (text.isEmpty) return;

    // 🔊 SFX — do NOT await
    try {
      Sfx.I.playSend();
    } catch (_) {}

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    _c.clear();
    setState(() => _isTyping = true);

    // ✅ write message
    await _msgsRef.add({
      'type': 'text',
      'senderId': widget.currentUserId,
      'text': text,
      'tsMs': nowMs,
    });

    // ✅ update room meta for list + unread
    await _roomRef.set({
      'lastUpdatedMs': nowMs,
      'lastSenderId': widget.currentUserId,
      'lastText': text,
    }, SetOptions(merge: true));

    _scrollToBottom(keepFocus: true);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Bgm.I.playHomeDm();
    });

    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _focus.addListener(() {
      if (!_focus.hasFocus) {
        if (mounted) {
          setState(() {
            _isTyping = false;
          });
        }
      }
    });

    _c.addListener(() {
      if (_focus.hasFocus && !_isTyping) {
        if (mounted) {
          setState(() {
            _isTyping = true;
          });
        }
      }
    });

    // ✅ ensure room exists + mark read
    _ensureRoomExists().then((_) async {
      await _markReadNow();
    });
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _scroll.dispose();
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double uiScale = mysticUiScale(context);
    double s(double v) => v * uiScale;

    final mq = MediaQuery.of(context);

    return MediaQuery(
      data: mq.copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // ✅ TOP BAR שלך נשאר בדיוק כמו שיש לך
            SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 34, width: double.infinity),
                  LayoutBuilder(
                    builder: (context, c) {
                      const double barAspect = 2048 / 212;
                      final w = c.maxWidth;
                      final barH = w / barAspect;

                      return SizedBox(
                        width: w,
                        height: barH,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/ui/DMSroomNameBar.png',
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.center,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  try {
                                    Sfx.I.playBack();
                                  } catch (_) {}
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: const SizedBox(
                                  width: 72,
                                  height: double.infinity,
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 80),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: const Offset(-2, 1),
                                      child: Image.asset(
                                        'assets/ui/DMSlittleLetterIcon.png',
                                        width: 25,
                                        height: 25,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        widget.otherName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w200,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/backgrounds/StarsBG.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    Positioned.fill(
                      child: MysticStarTwinkleOverlay(
                        animation: _twinkleController,
                        starCount: 58,
                        sizeMultiplier: 1.25,
                      ),
                    ),

                    // ✅ במקום ListView על _messages — StreamBuilder
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _msgsStream,
                      builder: (context, snap) {
                        final docs = snap.data?.docs ?? const [];

                        // ✅ mark read when we receive new snapshot (lightweight)
                        if (snap.hasData) {
                          WidgetsBinding.instance.addPostFrameCallback((_) async {
                            await _markReadNow();
                          });
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (snap.hasData) _scrollToBottom();
                        });

                        return ListView.builder(
                          controller: _scroll,
                          padding: EdgeInsets.only(
                            left: s(14),
                            right: s(14),
                            top: s(10),
                            bottom: s(90),
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final m = docs[i].data();

                            if ((m['type'] ?? 'text') != 'text') {
                              return const SizedBox.shrink();
                            }

                            final sender = (m['senderId'] ?? '').toString();
                            final isMe = sender == widget.currentUserId;
                            final text = (m['text'] ?? '').toString();
                            final int ts =
                                (m['tsMs'] is int) ? m['tsMs'] as int : 0;
                            final String timeLabel = mysticTimeOnlyFromMs(ts);

                            int prevTs = 0;
                            if (i > 0) {
                              final prev = docs[i - 1].data();
                              if ((prev['type'] ?? 'text') == 'text') {
                                prevTs = (prev['tsMs'] is int)
                                    ? prev['tsMs'] as int
                                    : 0;
                              }
                            }

                            final bool showDateDivider =
                                (i == 0 && ts > 0) ||
                                    (i > 0 &&
                                        ts > 0 &&
                                        !mysticIsSameDayMs(prevTs, ts));

                            final String dateHeader =
                                mysticDmDateHeaderFromMs(ts);

                            String prevSender = '';
                            if (i > 0) {
                              final prev = docs[i - 1].data();
                              if ((prev['type'] ?? 'text') == 'text') {
                                prevSender = (prev['senderId'] ?? '').toString();
                              }
                            }

                            final bool switchedSender =
                                (prevSender.isNotEmpty && prevSender != sender);

                            final double sameSenderGap = s(22);
                            final double switchedSenderGap = s(34);
                            final double bottomGap =
                                switchedSender ? switchedSenderGap : sameSenderGap;

                            return Padding(
                              padding: EdgeInsets.only(bottom: bottomGap),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showDateDivider)
                                    _DmDateDivider(
                                      text: dateHeader,
                                      uiScale: uiScale,
                                    ),
                                  _DmMessageRow(
                                    isMe: isMe,
                                    text: text,
                                    time: timeLabel,
                                    uiScale: uiScale,
                                    meLetter: (dmUsers[widget.currentUserId]
                                                ?.name
                                                .characters
                                                .first ??
                                            ' ')
                                        .toUpperCase(),
                                    otherLetter: (dmUsers[widget.otherUserId]
                                                ?.name
                                                .characters
                                                .first ??
                                            ' ')
                                        .toUpperCase(),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.only(bottom: s(0)),
              child: _DmBottomCornerLine(uiScale: uiScale),
            ),

            _DmBottomBar(
              height: s(80),
              isTyping: _isTyping,
              onTapTypeMessage: _onTapType,
              controller: _c,
              focusNode: _focus,
              onSend: _send,
              uiScale: uiScale,
            ),
          ],
        ),
      ),
    );
  }
}














