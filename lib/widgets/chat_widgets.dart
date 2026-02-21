import 'dart:io';
import 'dart:ui' as ui;
import '../audio/bgm.dart';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/fullscreen_video_player.dart';
import '../widgets/video_preview_tile.dart';


import '../audio/sfx.dart';
import 'dart:math' as math;
import 'rotating_envelope.dart';



enum BubbleTemplate {
  normal,
  glow,
}

enum BubbleDecor {
  none,
  hearts,
  pinkHearts,

  /// ✅ NEW: same format as Hearts, but tinted + glow
  cornerStarsGlow,

  /// ✅ Single sticker: bottom-left corner
  flowersRibbon,

  /// ✅ Single sticker: bottom-left corner (same behavior as flowersRibbon)
  stars,

  /// ✅ Music note: top corner
  musicNotes,

  /// ✅ Surprise: top corner (same behavior as musicNotes)
  surprise,

  /// ✅ Kitty: top corner (same behavior as musicNotes + surprise)
  kitty,

  /// ✅ Drip tinted to bubble + sad face on top
  dripSad,
}


class TopBorderBar extends StatelessWidget {
  final double height;
  const TopBorderBar({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: height,
        width: double.infinity,
        color: Colors.black,
      ),
    );
  }
}

class BottomBorderBar extends StatefulWidget {
  final double height;
  final bool isTyping;
  final VoidCallback onTapTypeMessage;
  final VoidCallback onSend;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// ✅ NEW
  final double uiScale;

  const BottomBorderBar({
    super.key,
    required this.height,
    required this.isTyping,
    required this.onTapTypeMessage,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.uiScale,
  });

  static const double _typeButtonWidth = 260;
  static const double _sendBoxSize = 40;
  static const double _sendScale = 1.0;

  static const double _sendInset = 14;
  static const double _sendDown = 3;

  @override
  State<BottomBorderBar> createState() => _BottomBorderBarState();
}

class _BottomBorderBarState extends State<BottomBorderBar> {
  final ScrollController _typeFieldScrollController = ScrollController();

  TextDirection _inputDirection = TextDirection.ltr;

  bool _containsRtl(String s) {
    // עברית + ערבית (טווחים נפוצים)
    return RegExp(r'[\u0590-\u05FF\u0600-\u06FF]').hasMatch(s);
  }

  // ✅ NEW: whether there is at least 1 real char to send
  bool _canSend = false;

  void _syncCanSend() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next == _canSend) return;
    if (!mounted) return;
    setState(() => _canSend = next);
  }

  @override
  void initState() {
    super.initState();
    _canSend = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_syncCanSend);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncCanSend);
    _typeFieldScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.height <= 0) return const SizedBox.shrink();

    double s(double v) => v * widget.uiScale;

    // ✅ Draft mode:
    // אם יש טקסט שכבר הוקלד — נשארים ב-typing UI גם כשהמקלדת נסגרה (focus lost)
    final bool hasDraft = widget.controller.text.isNotEmpty;
    final bool showTypingUi = widget.isTyping || hasDraft;

    return Container(
      height: widget.height,
      width: double.infinity,
      color: Colors.black,
      padding: EdgeInsets.only(bottom: s(10)),
      child: showTypingUi ? _typingBar(s) : _typeMessageBar(s),
    );
  }


  // =====================
  // BEFORE TYPING
  // =====================
  Widget _typeMessageBar(double Function(double) s) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Type Message button
        GestureDetector(
          onTap: widget.onTapTypeMessage,
          child: SizedBox(
            width: s(BottomBorderBar._typeButtonWidth),
            child: Image.asset(
              'assets/ui/TypeMessageButton.png',
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
        _inactiveSendButton(left: true, s: s),
        _inactiveSendButton(left: false, s: s),
      ],
    );
  }

Widget _inactiveSendButton({
  required bool left,
  required double Function(double) s,
}) {
  return Positioned(
    left: left ? s(BottomBorderBar._sendInset) : null,
    right: left ? null : s(BottomBorderBar._sendInset),
    child: Transform.translate(
      offset: Offset(0, s(BottomBorderBar._sendDown)),
      child: IgnorePointer(
        ignoring: true,
        child: SizedBox(
          width: s(BottomBorderBar._sendBoxSize),
          height: s(BottomBorderBar._sendBoxSize),
          child: Transform.scale(
            scale: BottomBorderBar._sendScale,
            child: left
                ? Transform.flip(
                    flipX: true,
                    child: Image.asset(
                      'assets/ui/SendMessageButton.png',
                      fit: BoxFit.contain,
                    ),
                  )
                : Image.asset(
                    'assets/ui/SendMessageButton.png',
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    ),
  );
}


  // =====================
  // TYPING MODE
  // =====================
  Widget _typingBar(double Function(double) s) {
    void scrollTypeFieldToEndForDirection(TextDirection dir) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_typeFieldScrollController.hasClients) return;

        // ב-LTR "סוף" הוא max, ב-RTL "סוף" מבחינת מה שרוצים לראות הוא min
        final target = (dir == TextDirection.rtl)
            ? _typeFieldScrollController.position.minScrollExtent
            : _typeFieldScrollController.position.maxScrollExtent;

        _typeFieldScrollController.jumpTo(target);
      });
    }

    void handleChanged(String text) {
      final nextDir = _containsRtl(text) ? TextDirection.rtl : TextDirection.ltr;

      if (nextDir != _inputDirection) {
        setState(() {
          _inputDirection = nextDir;
        });
      }

      scrollTypeFieldToEndForDirection(nextDir);
      // ✅ canSend updates via controller listener (_syncCanSend)
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: s(BottomBorderBar._typeButtonWidth),
          child: Stack(
            children: [
              Image.asset(
                'assets/ui/TypeBar.png',
                fit: BoxFit.fitWidth,
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: s(18),
                    vertical: s(8),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: 1,
                    scrollController: _typeFieldScrollController,

                    // ✅ זה החלק שעושה את ההבדל בעברית
                    textDirection: _inputDirection,
                    textAlign: _inputDirection == TextDirection.rtl
                        ? TextAlign.right
                        : TextAlign.left,

                    textAlignVertical: TextAlignVertical.center,
                    onChanged: handleChanged,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: s(14),
                      height: 1.2,
                    ),
                    cursorColor: Colors.black,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Type...',
                      hintStyle: TextStyle(
                        color: Colors.black54,
                        fontSize: s(14),
                        height: 1.2,
                      ),
                      hintTextDirection: TextDirection.ltr, // ✅ תמיד LTR
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _activeSendButton(left: true, s: s),
        _activeSendButton(left: false, s: s),
      ],
    );
  }

Widget _activeSendButton({
  required bool left,
  required double Function(double) s,
}) {
  final String asset = _canSend
      ? 'assets/ui/SendMessageButtonActive.png'
      : 'assets/ui/SendMessageButton.png';

  return Positioned(
    left: left ? s(BottomBorderBar._sendInset) : null,
    right: left ? null : s(BottomBorderBar._sendInset),
    child: Transform.translate(
      offset: Offset(0, s(BottomBorderBar._sendDown)),
      child: GestureDetector(
        onTap: () {
          if (!_canSend) return; // ✅ block empty/whitespace-only
          widget.onSend();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: s(BottomBorderBar._sendBoxSize),
          height: s(BottomBorderBar._sendBoxSize),
          child: Transform.scale(
            scale: BottomBorderBar._sendScale,
            child: left
                ? Transform.flip(
                    flipX: true,
                    child: Image.asset(
                      asset,
                      fit: BoxFit.contain,
                    ),
                  )
                : Image.asset(
                    asset,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    ),
  );
}

}

const bool kDebugSevenNames = false;

class ActiveUsersBar extends StatelessWidget {
  final Map<String, ChatUser> usersById;
  final Set<String> onlineUserIds;
  final String currentUserId;
  final VoidCallback onBack;

  /// ✅ opens the bubble-style menu
  final VoidCallback onOpenBubbleMenu;

  /// ✅ pick image (camera button)
  final VoidCallback onPickImage;

  /// ✅ NEW: hold-to-record voice, release to send
  final Future<void> Function(String filePath, int durationMs) onSendVoice;

  /// ✅ title text to display in the center
  final String titleText;

  /// ✅ UI scale
  final double uiScale;

  const ActiveUsersBar({
    super.key,
    required this.usersById,
    required this.onlineUserIds,
    required this.currentUserId,
    required this.onBack,
    required this.onOpenBubbleMenu,
    required this.onPickImage,
    required this.onSendVoice,
    required this.titleText,
    required this.uiScale,
  });

  static const double barHeight = 76;

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * uiScale;

    final double tapSize = s(40);
    final double iconSize = s(26);

    return SizedBox(
      height: s(barHeight),
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/ui/ChatParticipantList.png',
              fit: BoxFit.cover,
            ),
          ),

          // ✅ Back triangle (left)
          Positioned(
            left: s(4),
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Sfx.I.playBack();
                  onBack();
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: tapSize,
                  height: tapSize,
                  child: Center(
                    child: Image.asset(
                      'assets/ui/ChatBackButton.png',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ✅ Max Speed (LEFT) — נשאר
          Positioned(
            left: s(44),
            top: 0,
            bottom: 0,
            child: Center(
              child: Image.asset(
                'assets/ui/MaxSpeedDecoy.png',
                width: s(57),
                height: s(42),
                fit: BoxFit.contain,
              ),
            ),
          ),

// ✅ Active users text (center) — SHOW ALL (2-line grid + auto scale-down)
Builder(
  builder: (context) {
    // left cluster: back + max speed
    final double leftInset = s(44) + s(57) + s(10);

    // right cluster: mic + camera + bubble menu
    final double rightInset = s(6) + (tapSize * 3) + (s(6) * 2) + s(10);

    final List<String> names = kDebugSevenNames
        ? <String>[
            'Joy',
            'Adi!',
            'Lian',
            'Danielle',
            'Tal',
            'Lihi',
            'Lera',
          ]
        : onlineUserIds
            .map((id) => usersById[id]?.name ?? id)
            .where((n) => n.trim().isNotEmpty)
            .toList();

    return Positioned(
      left: leftInset,
      right: rightInset,
      top: 0,
      bottom: 0,
      child: Center(
child: Padding(
  padding: EdgeInsets.fromLTRB(
    s(10), // 👈 הזזה עדינה ימינה (שני ל־4 / 6 / 8 לפי טעם)
    s(6),
    0,
    s(6),
  ),
  child: names.isEmpty
      ? Text(
          titleText,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: s(14),
            height: 1.05,
            fontWeight: FontWeight.w400,
          ),
        )
      : ActiveUsersCompactNames(
          names: names,
          baseFontSize: s(14),
          lineHeight: 1.05,
          maxLines: 3,
        ),
),

      ),
    );
  },
),



          // ✅ Right-side actions: [Mic] [Camera] [Bubble menu]
          Positioned(
            right: s(6),
            top: 0,
            bottom: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
         // 🎙️ Mic (tap to record, tap to send, double-tap to cancel)
TapToRecordMicButton(
  size: tapSize,
  iconSize: s(32),
  uiScale: uiScale,
  onSendVoice: onSendVoice,

  // 🔊 אפשר לשנות כאן למה שבא לך (כרגע safe, בלי לשבור קומפילציה)
  onStartRecordingSfx: () {
    // TODO: חברי פה סאונד "record start" אמיתי אם יש לך
    // לדוגמה אם קיים אצלך: Sfx.I.playRecordStart();
  },
  onCancelRecordingSfx: () {
    // TODO: חברי פה סאונד "record cancel" אמיתי אם יש לך
    // לדוגמה אם קיים אצלך: Sfx.I.playCancelRecord();
  },
),


                  SizedBox(width: s(6)),

                  // 📷 Camera button
                  GestureDetector(
                    onTap: onPickImage,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: tapSize,
                      height: tapSize,
                      child: Center(
                        child: Image.asset(
                          'assets/ui/CameraIcon.png',
                          width: s(32),
                          height: s(32),
                          fit: BoxFit.contain,
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: s(6)),

                  // ✨ Bubble menu button
                  GestureDetector(
                    onTap: onOpenBubbleMenu,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: tapSize,
                      height: tapSize,
                      child: Center(
                        child: Icon(
                          Icons.auto_awesome,
                          size: s(20),
                          color: Colors.white.withOpacity(0.9),
                        ),
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
  }
}




class ActiveUsersCompactNames extends StatelessWidget {
  const ActiveUsersCompactNames({
    super.key,
    required this.names,
    this.baseFontSize = 14,
    this.lineHeight = 1.05,
    this.maxLines = 3, // ✅ NEW: allow up to 3 lines
  });

  final List<String> names;
  final double baseFontSize;
  final double lineHeight;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cleaned = names
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList(growable: false);

    if (cleaned.isEmpty) return const SizedBox.shrink();

    // Decide how many lines we want (1..maxLines)
    // Mystic-like: 1 line for small, 2 lines for medium, 3 lines for 6+.
    int lines;
    if (cleaned.length <= 4) {
      lines = 1;
    } else if (cleaned.length <= 5) {
      lines = 2;
    } else {
      lines = 3;
    }
    lines = lines.clamp(1, maxLines);

    // Split names into N lines as evenly as possible (top line slightly longer)
    List<List<String>> splitIntoLines(List<String> xs, int lineCount) {
      if (lineCount <= 1) return [xs];

      final int n = xs.length;
      final int base = n ~/ lineCount;
      final int extra = n % lineCount;

      final List<List<String>> out = [];
      int index = 0;

      for (int i = 0; i < lineCount; i++) {
        final int take = base + (i < extra ? 1 : 0);
        if (take <= 0) {
          out.add(const []);
          continue;
        }
        out.add(xs.sublist(index, index + take));
        index += take;
      }

      // Remove any empty trailing lines (just in case)
      while (out.isNotEmpty && out.last.isEmpty) {
        out.removeLast();
      }
      return out.isEmpty ? [xs] : out;
    }

    String joinLine(List<String> xs) => xs.join(', ');

    final style = TextStyle(
      color: Colors.white,
      fontSize: baseFontSize,
      height: lineHeight,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.0,
    );

    final linesList = splitIntoLines(cleaned, lines);

    // ✅ scaleDown guarantees it always fits, while still showing ALL names
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < linesList.length; i++) ...[
                  if (i != 0) const SizedBox(height: 2),
                  Text(
                    joinLine(linesList[i]),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}




/// =======================
/// MODEL (UI)
/// =======================
class ChatUser {
  final String id;
  final String name;
  final Color bubbleColor;
  final String? avatarPath;

  const ChatUser({
    required this.id,
    required this.name,
    required this.bubbleColor,
    this.avatarPath,
  });
}

/// =======================
/// SYSTEM MESSAGE BAR (entered/left)
/// =======================
class SystemMessageBar extends StatelessWidget {
  final String text;

  /// ✅ NEW
  final double uiScale;

  const SystemMessageBar({
    super.key,
    required this.text,
    this.uiScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * uiScale;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: s(8)),
      padding: EdgeInsets.symmetric(vertical: s(6)),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(s(2)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: s(11),
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
      ),
    );
  }
}
double _minBubbleWidthForFirstWords({
  required BuildContext context,
  required String text,
  required TextStyle style,
  required double uiScale,
  int minWords = 3,
  required double maxBubbleWidth,
  required double horizontalPadding, // סה"כ padding אופקי (ימין+שמאל)
}) {
  final raw = text.trim();
  if (raw.isEmpty) return 0;

  // פיצול "מילים" בצורה פשוטה
  final parts = raw.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return 0;

  final takeN = parts.length < minWords ? parts.length : minWords;
  final sample = parts.take(takeN).join(' ');

  final painter = TextPainter(
    text: TextSpan(text: sample, style: style),
    textDirection: Directionality.of(context),
    maxLines: 1,
    ellipsis: '',
  )..layout(maxWidth: maxBubbleWidth);

  // רוחב הטקסט + padding של הבועה
  final w = painter.size.width + horizontalPadding;

  // לא לעבור את maxBubbleWidth
  return w.clamp(0.0, maxBubbleWidth);
}


/// =======================
/// MESSAGE ROW (bubble + tail + avatar)
/// =======================
class MessageRow extends StatelessWidget {
  final ChatUser user;
  final String text;
  final bool isMe;
  final String? replyToSenderName;
final String? replyToText;
final VoidCallback? onTapReplyPreview;
  /// ✅ NEW: message type + image url
  final String messageType; // 'text' / 'image' / 'voice'
  final String? imageUrl;
  /// ✅ NEW: video messages
  final String? videoUrl;

  /// ✅ NEW: voice messages
  final String? voicePath;
  final int? voiceDurationMs;


  /// ✅ NEW: allow heart reaction on images even when outer detector can't win
  final VoidCallback? onDoubleTapImage;


// ✅ NEW: builds TextSpans so @mentions are white (including the @)
List<InlineSpan> _buildMentionSpans(String s, {required double uiScale}) {
  final spans = <InlineSpan>[];

  final words = s.split(RegExp(r'(\s+)')); // keep spaces as tokens
  for (final token in words) {
    if (token.trim().isEmpty) {
      spans.add(TextSpan(text: token));
      continue;
    }

    final isMention = token.startsWith('@') && token.length > 1;

    spans.add(
      TextSpan(
        text: token,
        style: TextStyle(
          color: isMention ? Colors.white : Colors.black,
          fontWeight: isMention ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }

  return spans;
}
void _openImageViewer(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 12,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Sfx.I.playCloseImage(); // 🔊 סאונד סגירה
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              TextButton(
                onPressed: () {}, // אם תרצי בעתיד: כפתור "+" לפיצ׳רים
                child: const Text(
                  '[ + ]',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}


// ✅ NEW: extract plain display text without bidi isolates (for parsing)
String _plainForMentions(String s) => s; // keep it simple for now

  final List<Widget> nameHearts;

  /// ✅ איזה טמפלייט לצייר
  final BubbleTemplate bubbleTemplate;

  /// ✅ איזה קישוט להדביק על הבועה
  final BubbleDecor decor;

  /// ✅ Optional per-message font family (English random fonts)
  final String? fontFamily;

  final bool showName;
  final Color usernameColor;

  /// ✅ NEW: time color passed from ChatScreen (depends on hour)
  final Color timeColor;

  final double uiScale; // ✅ NEW
  final bool showNewBadge;

  /// ✅ NEW: time under message (like DMs)
  final bool showTime;
  final int timeMs;

const MessageRow({
  super.key,
  required this.user,
  required this.text,
  required this.isMe,
  required this.bubbleTemplate,
  this.decor = BubbleDecor.none,
  this.fontFamily,
  this.showName = true,
  required this.usernameColor,
  required this.timeColor,
  required this.showNewBadge,
  this.nameHearts = const <Widget>[],
  required this.uiScale,

  /// ✅ NEW
  this.messageType = 'text',
  this.imageUrl,
  this.videoUrl,

  // ✅ voice
  this.voicePath,
  this.voiceDurationMs,

  this.onDoubleTapImage,


  // ✅ reply preview
  this.replyToSenderName,
  this.replyToText,
  this.onTapReplyPreview,

  // ✅ time
  this.showTime = false,
  this.timeMs = 0,
});



  Color _decorBaseFromUser(Color c) {
    // Very light tint (reference: #fff8f8 on red)
    return _lighten(c, 0.88);
  }

  Color _decorGlowFromUser(Color c) {
    // Deeper glow (reference: #b47080 on red)
    final hsl = HSLColor.fromColor(c);
    final darker = hsl
        .withLightness((hsl.lightness * 0.62).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 0.95 + 0.05).clamp(0.0, 1.0))
        .toColor();
    // Slightly pull toward warm pink-ish glow like Mystic
    const warm = Color(0xFFB47080);
    return Color.lerp(darker, warm, 0.22) ?? darker;
  }

  Widget _decorWithGlow({
    required String asset,
    required double w,
    required double h,
    required Color baseTint,
    required Color glowTint,
  }) {
    return IgnorePointer(
      ignoring: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ✅ Glow layer (blurred + tinted)
          Opacity(
            opacity: 0.95,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(glowTint, BlendMode.srcIn),
                child: Image.asset(
                  asset,
                  width: w,
                  height: h,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // ✅ Base layer (light tinted)
          ColorFiltered(
            colorFilter: ColorFilter.mode(baseTint, BlendMode.srcIn),
            child: Image.asset(
              asset,
              width: w,
              height: h,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Color _lerp(Color a, Color b, double t) {
    return Color.lerp(a, b, t) ?? a;
  }

  Color _lighten(Color c, double amount) {
    return _lerp(c, Colors.white, amount.clamp(0.0, 1.0));
  }

  // “Mystic-ish” inner dark glow:
  Color _innerDarkGlowFromBase(Color base) {
    final hsl = HSLColor.fromColor(base);

    final muted = hsl
        .withLightness((hsl.lightness * 0.45).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 0.45).clamp(0.0, 1.0))
        .toColor();

    const warmHint = Color(0xFFAD927E);
    return Color.lerp(muted, warmHint, 0.12) ?? muted;
  }

  Color _outerBrightGlowFromBase(Color base) {
    final lifted = _lighten(base, 0.70);
    return _lerp(lifted, Colors.white, 0.10);
  }

  Color _darkenColor(Color color, [double amount = 0.25]) {
    final hsl = HSLColor.fromColor(color);
    final darker = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return darker.toColor();
  }

  /// ✅ Fixes "punctuation jumps to the wrong side" in mixed RTL/LTR chat.
  /// We isolate each message so surrounding Directionality doesn't reorder punctuation.
  String _bidiIsolate(String s) => '\u2068$s\u2069'; // FSI ... PDI

  bool _isProbablyRtl(String s) {
    // Hebrew + Arabic ranges (covers common RTL languages).
    return RegExp(r'[\u0590-\u08FF]').hasMatch(s);
  }

  Color _musicNoteTintFromBubble(Color bubble) {
    final hsl = HSLColor.fromColor(bubble);

    // ✅ computed from your reference:
    // base  #FFF5EB = HSL(30, 100%, 96%)
    // note  #F3B7A2 = HSL(16,  77%, 79%)
    const double hueShift = -14.44444444; // degrees (16 - 30)
    const double satFactor = 0.7714285714; // 77 / 100
    const double lightFactor = 0.8229166667; // 79 / 96

    // ✅ make it a bit darker (closer to your reference look on saturated bubbles)
    const double extraDarken = 0.92; // 1.0 = original ratio, <1.0 = darker

    final double hue = (hsl.hue + hueShift) % 360;
    final double sat = (hsl.saturation * satFactor).clamp(0.0, 1.0);
    final double light =
        (hsl.lightness * lightFactor * extraDarken).clamp(0.0, 1.0);

    return HSLColor.fromAHSL(1.0, hue, sat, light).toColor();
  }

  // ✅ NEW: simple HH:mm formatter (no intl)
  String _timeLabel(int ms) {
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }
// ✅ Allows clean wrapping for long URLs / long tokens (AliExpress etc.)
String _softWrapLongTokens(String s) {
  const zwsp = '\u200B'; // zero-width space (invisible)

  final hasVeryLongToken = RegExp(r'\S{22,}').hasMatch(s);
  final looksLikeUrl =
      s.contains('http://') || s.contains('https://') || s.contains('www.');

  if (!hasVeryLongToken && !looksLikeUrl) return s;

  // Add break opportunities after common URL/token separators
  return s.replaceAllMapped(
    RegExp(r'([\/\.\?\&\=\-\_\:\#])'),
    (m) => '${m.group(1)}$zwsp',
  );
}
String _maybeAvoidOrphanLastLine({
  required BuildContext context,
  required String text,
  required TextStyle style,
  required double maxTextWidth,
  double orphanWidthFactor = 0.42, // כמה "קצר" נחשב יתום (0.35–0.50 זה טווח טוב)
}) {
  final raw = text.trim();
  if (raw.isEmpty) return text;

  // חייבים לפחות 2 מילים כדי להדביק "2 מילים אחרונות"
  final parts = raw.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (parts.length < 2) return text;

  // מודדים כמה שורות יוצאות בפועל ברוחב הנתון
  final tp = TextPainter(
    text: TextSpan(text: raw, style: style),
    textDirection: Directionality.of(context),
    maxLines: null,
  )..layout(maxWidth: maxTextWidth);

  final lines = tp.computeLineMetrics();
  if (lines.length <= 1) return text; // אין wrap בכלל

  // ✅ NEW: אל תנסה "לתקן יתום" כשיש רק 2 שורות.
  // זה המקרה שמייצר שורה ראשונה קצרה כמו אצל Adi.
  if (lines.length == 2) return text;

  final last = lines.last;
  final bool lastLineIsOrphan = last.width < (maxTextWidth * orphanWidthFactor);

  if (!lastLineIsOrphan) return text;

  // ✅ כן יתום -> נדביק רק את שתי המילים האחרונות
  final lastSpace = raw.lastIndexOf(' ');
  if (lastSpace <= 0) return text;

  final before = raw.substring(0, lastSpace);
  final after = raw.substring(lastSpace + 1);
  return '$before\u00A0$after';
}



// ✅ NEW: force wrap by WORD COUNT (max N words per line)
String _wrapByWordCount(String s, {int maxWordsPerLine = 5}) {
  if (maxWordsPerLine <= 0) return s;

  // Keep existing manual newlines
  final originalLines = s.split('\n');
  final outLines = <String>[];

  for (final line in originalLines) {
    final words = line.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      outLines.add('');
      continue;
    }

    final buf = <String>[];
    for (int i = 0; i < words.length; i++) {
      buf.add(words[i]);
      final isEndOfLine = (i == words.length - 1);
      final hitLimit = ((i + 1) % maxWordsPerLine == 0);

      if (!isEndOfLine && hitLimit) {
        outLines.add(buf.join(' '));
        buf.clear();
      }
    }

    if (buf.isNotEmpty) outLines.add(buf.join(' '));
  }

  return outLines.join('\n');
}

  @override
  Widget build(BuildContext context) {
    final double avatarSize = 56 * uiScale; // ✅ scale with device
    final double gap = 10 * uiScale;
    double s(double v) => v * uiScale;
final double screenW = MediaQuery.of(context).size.width;
final double sidePadding = 16;

final double availableForBubble =
    screenW - (sidePadding * 2) - (avatarSize + gap);

final double mysticMax = availableForBubble * 0.86;
final double hardCap = 360 * uiScale;

final double maxBubbleWidth = math.min(hardCap, mysticMax);

    final avatar = SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: SquareAvatar(
        size: avatarSize,
        letter: user.name[0],
        imagePath: user.avatarPath,
      ),
    );

    final BubbleTemplate effectiveTemplate = bubbleTemplate;

    // צבע בסיס: כמו הבועה הרגילה, ובמצבי אפקט אפשר קצת להרים אותו
    final Color bubbleBase = user.bubbleColor;
    final Color bubbleFill = (effectiveTemplate == BubbleTemplate.glow)
        ? _lighten(bubbleBase, 0.18)
        : bubbleBase;

    // ✅ NORMAL / GLOW
    final Color innerDarkGlow = _innerDarkGlowFromBase(bubbleFill);
    final Color outerBrightGlow = _outerBrightGlowFromBase(bubbleFill);

    // ✅ Corner Stars (Glow)
    final Color cornerStarsBaseTint = _decorBaseFromUser(user.bubbleColor);
    final Color cornerStarsGlowTint = _decorGlowFromUser(user.bubbleColor);

    const String cornerStarsLeftAsset =
        'assets/decors/TextBubble4CornerStarsLeft.png';
    const String cornerStarsRightAsset =
        'assets/decors/TextBubble4CornerStarsRightpng.png';

// קודם כל: soft wrap ל-URL/טוקנים ארוכים
final String softText = _softWrapLongTokens(text);

// טקסט-סטייל למדידה (חייב להיות תואם למה שה-Text משתמש)
const double msgFontMeasure = 15.0;
final TextStyle measureStyleForWrap = TextStyle(
  fontFamily: fontFamily,
  fontFamilyFallback: [
    _hebrewFallbackFor(fontFamily),
    'NotoSans',
  ],
  fontSize: msgFontMeasure * uiScale,
  height: 1.2,
  fontWeight: FontWeight.w400,
  letterSpacing: -0.15 * uiScale,
);

// רוחב הטקסט נטו בתוך הבועה (בלי padding פנימי של bubbleInner)
final double bubbleInnerHPadMeasure = 20 * uiScale; // 10+10 (כמו אצלך)
final double maxTextWidth =
    (maxBubbleWidth - bubbleInnerHPadMeasure).clamp(0.0, maxBubbleWidth);


final String displayText = _maybeAvoidOrphanLastLine(
  context: context,
  text: softText,
  style: measureStyleForWrap,
  maxTextWidth: maxTextWidth,
  orphanWidthFactor: 0.42,
);





// ✅ Decide what the row shows: image OR text
late final Widget messageBody;

final String msgType = messageType; // 'text' / 'image' / 'voice'
final String? imgUrl = imageUrl;

// ✅ voice data
final String? vPath = voicePath;
final bool hasVoicePath = (vPath != null && vPath.trim().isNotEmpty);
final int vDurMs = voiceDurationMs ?? 0;

final bool isImageMessage = (msgType == 'image');
final bool isVoiceMessage = (msgType == 'voice');
final bool isVideoMessage = (msgType == 'video'); // ✅ NEW

final bool hasImageUrl = (imgUrl != null && imgUrl.trim().isNotEmpty);

// ✅ NEW: video url data
final String? vidUrl = videoUrl;
final bool hasVideoUrl = (vidUrl != null && vidUrl.trim().isNotEmpty);


// ✅ Fixed SMALL rectangular preview (same size for all images)
final double imagePreviewWidth  = math.min(maxBubbleWidth, 140 * uiScale);
final double imagePreviewHeight = 210 * uiScale;

// ✅ Envelope asset (your icon)
const String envelopeAsset = 'assets/ui/DMSmessageUnread.png';

if (isImageMessage) {
  if (hasImageUrl) {
    messageBody = GestureDetector(
      onTap: () => _openImageViewer(context, imgUrl),
      onDoubleTap: onDoubleTapImage,
      behavior: HitTestBehavior.opaque,
      child: ClipRect(
        child: SizedBox(
          width: imagePreviewWidth,
          height: imagePreviewHeight,
          child: Image.network(
            imgUrl,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  } else {
    final double envelopeSize = 50.0;

    messageBody = SizedBox(
      width: imagePreviewWidth,
      height: imagePreviewHeight,
      child: Center(
        child: RotatingEnvelope(
          assetPath: envelopeAsset,
          size: envelopeSize,
          duration: const Duration(milliseconds: 1800),
          opacity: 1.0,
        ),
      ),
    );
  }
} else if (isVideoMessage) {
  if (hasVideoUrl) {
    messageBody = GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => FullscreenVideoPlayer(videoUrl: vidUrl),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: ClipRect(
        child: VideoPreviewTile(
          videoUrl: vidUrl,
          width: imagePreviewWidth,
          height: imagePreviewHeight,
          uiScale: uiScale,
        ),
      ),
    );
  } else {
    // placeholder בזמן upload
    messageBody = SizedBox(
      width: imagePreviewWidth,
      height: imagePreviewHeight,
      child: Center(
        child: RotatingEnvelope(
          assetPath: envelopeAsset,
          size: 50.0,
          duration: const Duration(milliseconds: 1800),
          opacity: 1.0,
        ),
      ),
    );
  }

} else if (isVoiceMessage) {
  if (hasVoicePath) {
    messageBody = VoiceMessageTile(
      filePath: vPath,
      durationMs: vDurMs,
      uiScale: uiScale,
      bubbleColor: bubbleFill,
    );
  } else {
    messageBody = RotatingEnvelope(
      assetPath: envelopeAsset,
      size: 34 * uiScale,
      duration: const Duration(milliseconds: 1800),
      opacity: 1.0,
    );
  }
} else {
  const double msgFont = 15.0;

  messageBody = Directionality(
    textDirection:
        _isProbablyRtl(displayText) ? TextDirection.rtl : TextDirection.ltr,
    child: Text(
      _bidiIsolate(displayText),
      textAlign: _isProbablyRtl(displayText) ? TextAlign.right : TextAlign.left,
      softWrap: true,
      maxLines: null,
      overflow: TextOverflow.visible,
      strutStyle: StrutStyle(
        fontSize: msgFont * uiScale,
        height: 1.2,
        forceStrutHeight: true,
      ),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
      style: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: [
          _hebrewFallbackFor(fontFamily),
          'NotoSans',
        ],
        fontSize: msgFont * uiScale,
        height: 1.2,
        color: Colors.black,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.15 * uiScale,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    ),
  );
}




// ✅ Reply preview builder (shared)
Widget replyPreview() {
  if (!((replyToText != null && replyToText!.trim().isNotEmpty) ||
      (replyToSenderName != null && replyToSenderName!.trim().isNotEmpty))) {
    return const SizedBox.shrink();
  }

  return GestureDetector(
    onTap: onTapReplyPreview,
    behavior: HitTestBehavior.opaque,
    child: Container(
      margin: EdgeInsets.only(bottom: 6 * uiScale),
      padding: EdgeInsets.symmetric(
        horizontal: 8 * uiScale,
        vertical: 6 * uiScale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.10),
        borderRadius: BorderRadius.circular(4 * uiScale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyToSenderName != null && replyToSenderName!.trim().isNotEmpty)
            Text(
              replyToSenderName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12 * uiScale,
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.70),
                height: 1.0,
              ),
            ),
          if (replyToText != null && replyToText!.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 3 * uiScale),
              child: Text(
                replyToText!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12 * uiScale,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.65),
                  height: 1.1,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

// ✅ IMAGE: no bubble at all (only the image)
final Widget imageOnlyWidget = Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    replyPreview(),
    messageBody,
  ],
);

// ✅ TEXT: keep the bubble exactly as before
final bubbleInner = Padding(
  padding: EdgeInsets.symmetric(
    horizontal: 10 * uiScale,
    vertical: 6 * uiScale,
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      replyPreview(),
      messageBody,
    ],
  ),
);

// ✅ Mystic-like minimum width so short messages don't shrink too much
final double floorMinBubbleWidth = 18 * uiScale;

// Horizontal padding inside bubbleInner: 10 left + 10 right
final double bubbleInnerHPadMin = 20 * uiScale;

// Use SAME style as the actual Text (so measurement matches reality)
final TextStyle measureStyleForMin = TextStyle(
  fontFamily: fontFamily,
  fontFamilyFallback: [
    _hebrewFallbackFor(fontFamily),
    'NotoSans',
  ],
  fontSize: msgFontMeasure * uiScale,
  height: 1.2,
  fontWeight: FontWeight.w400,
  letterSpacing: -0.15 * uiScale,
);

// Count words (based on the original text, not displayText)
final String rawForWords = text.trim();
final int wordCount = rawForWords.isEmpty
    ? 0
    : rawForWords.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

// Measure a “minimum” width based on the first 3 words
final double minBy3Words = _minBubbleWidthForFirstWords(
  context: context,
  text: text,
  style: measureStyleForMin,
  uiScale: uiScale,
  minWords: 3,
  maxBubbleWidth: maxBubbleWidth,
  horizontalPadding: bubbleInnerHPadMin,
);

// ✅ NEW: for longer messages, force a wider minimum (prevents “Not even worth” width)
// tweak 0.72–0.82 to taste (0.76 is a good Mystic-ish default)
final double minByPercent =
    (wordCount >= 6) ? (maxBubbleWidth * 0.76) : 0.0;

// Final min width = max(floor, 3-words width, percent floor) and never above maxBubbleWidth
final double minBubbleWidth = math.min(
  maxBubbleWidth,
  math.max(
    floorMinBubbleWidth,
    math.max(minBy3Words, minByPercent),
  ),
);



final Widget bubbleWidget = isImageMessage
    ? imageOnlyWidget
    : ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minBubbleWidth,
          maxWidth: maxBubbleWidth,
        ),
        child: BubbleWithTail(
          color: bubbleFill,
          isMe: isMe,
          radius: 6 * uiScale,
          tailWidth: 10 * uiScale,
          tailHeight: 6 * uiScale,
          tailTop: 12 * uiScale,
          glowEnabled: (effectiveTemplate == BubbleTemplate.glow),
          glowInnerColor: innerDarkGlow,
          glowOuterColor: outerBrightGlow,
          child: bubbleInner,
        ),
      );



// ✅ If image: return just the widget (no decors). If text: keep decors stack.
final Widget bubbleStack = isImageMessage

    ? bubbleWidget
    : Stack(
        clipBehavior: Clip.none,
        children: [
          bubbleWidget,


    // ✅ DECOR: Hearts
    if (decor == BubbleDecor.hearts) ...[
      if (isMe) ...[
        Positioned(
          top: s(-22),
          left: s(-28),
          child: IgnorePointer(
            ignoring: true,
            child: Image.asset(
              'assets/decors/TextBubbleLeftHearts.png',
              width: s(46),
              height: s(46),
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          bottom: s(-8),
          right: s(-20),
          child: IgnorePointer(
            ignoring: true,
            child: Image.asset(
              'assets/decors/TextBubbleRightHearts.png',
              width: s(48),
              height: s(48),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ] else ...[
        Positioned(
          top: s(-22),
          right: s(-28),
          child: IgnorePointer(
            ignoring: true,
            child: Transform.flip(
              flipX: true,
              child: Image.asset(
                'assets/decors/TextBubbleLeftHearts.png',
                width: s(46),
                height: s(46),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: s(-8),
          left: s(-20),
          child: IgnorePointer(
            ignoring: true,
            child: Transform.flip(
              flipX: true,
              child: Image.asset(
                'assets/decors/TextBubbleRightHearts.png',
                width: s(48),
                height: s(48),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    ],

    // ✅ DECOR: Pink Hearts
    if (decor == BubbleDecor.pinkHearts) ...[
      if (isMe) ...[
        Positioned(
          top: s(-22),
          left: s(-28),
          child: IgnorePointer(
            ignoring: true,
            child: Image.asset(
              'assets/decors/TextBubblePinkHeartsLeft.png',
              width: s(46),
              height: s(46),
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          bottom: s(-8),
          right: s(-20),
          child: IgnorePointer(
            ignoring: true,
            child: Image.asset(
              'assets/decors/TextBubblePinkHeartsRight.png',
              width: s(48),
              height: s(48),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ] else ...[
        Positioned(
          top: s(-22),
          right: s(-28),
          child: IgnorePointer(
            ignoring: true,
            child: Transform.flip(
              flipX: true,
              child: Image.asset(
                'assets/decors/TextBubblePinkHeartsLeft.png',
                width: s(46),
                height: s(46),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: s(-8),
          left: s(-20),
          child: IgnorePointer(
            ignoring: true,
            child: Transform.flip(
              flipX: true,
              child: Image.asset(
                'assets/decors/TextBubblePinkHeartsRight.png',
                width: s(48),
                height: s(48),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    ],

    // ✅ DECOR: Stars
    if (decor == BubbleDecor.stars) ...[
      if (isMe)
        Positioned(
          bottom: s(-20),
          left: s(-25),
          child: IgnorePointer(
            ignoring: true,
            child: Image.asset(
              'assets/decors/TextBubbleStars.png',
              width: s(44),
              height: s(44),
              fit: BoxFit.contain,
            ),
          ),
        )
      else
        Positioned(
          bottom: s(-20),
          right: s(-25),
          child: IgnorePointer(
            ignoring: true,
            child: Transform.flip(
              flipX: true,
              child: Image.asset(
                'assets/decors/TextBubbleStars.png',
                width: s(44),
                height: s(44),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
    ],
// ✅ DECOR: Flowers + Ribbon (bottom corner sticker)
if (decor == BubbleDecor.flowersRibbon) ...[
  if (isMe)
    Positioned(
      bottom: s(-20),
      left: s(-40),
      child: IgnorePointer(
        ignoring: true,
        child: Image.asset(
          'assets/decors/TextBubbleFlowersAndRibbon.png',
          width: s(70),
          height: s(70),
          fit: BoxFit.contain,
        ),
      ),
    )
  else
    Positioned(
      bottom: s(-20),
      right: s(-40),
      child: IgnorePointer(
        ignoring: true,
        child: Transform.flip(
          flipX: true,
          child: Image.asset(
            'assets/decors/TextBubbleFlowersAndRibbon.png',
            width: s(70),
            height: s(70),
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
],

    // ✅ DECOR: DripSad
    if (decor == BubbleDecor.dripSad) ...[
      Positioned(
        bottom: s(-31),
        right: isMe ? s(6) : null,
        left: isMe ? null : s(6),
        child: IgnorePointer(
          ignoring: true,
          child: Transform.flip(
            flipX: isMe,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                bubbleFill,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                'assets/decors/TextBubbleDrip.png',
                width: s(40),
                height: s(40),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: s(-7),
        right: isMe ? s(12) : null,
        left: isMe ? null : s(18),
        child: IgnorePointer(
          ignoring: true,
          child: Transform.flip(
            flipX: isMe,
            child: Image.asset(
              'assets/decors/TextBubbleSadFace.png',
              width: s(22),
              height: s(22),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ],

    // ✅ DECOR: Music Notes
    if (decor == BubbleDecor.musicNotes) ...[
      Positioned(
        top: s(-18),
        left: isMe ? s(-18) : null,
        right: isMe ? null : s(-18),
        child: IgnorePointer(
          ignoring: true,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              _musicNoteTintFromBubble(bubbleFill),
              BlendMode.srcIn,
            ),
            child: Image.asset(
              'assets/decors/TextBubbleMusicNotes.png',
              width: s(34),
              height: s(34),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ],

    // ✅ DECOR: Surprise
    if (decor == BubbleDecor.surprise) ...[
      Positioned(
        top: s(-18),
        left: isMe ? s(-18) : null,
        right: isMe ? null : s(-18),
        child: IgnorePointer(
          ignoring: true,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              _musicNoteTintFromBubble(bubbleFill),
              BlendMode.srcIn,
            ),
            child: Image.asset(
              'assets/decors/TextBubbleSurprise.png',
              width: s(34),
              height: s(34),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ],

    // ✅ DECOR: Corner Stars Glow
    if (decor == BubbleDecor.cornerStarsGlow) ...[
      if (isMe) ...[
        Positioned(
          top: s(-18),
          left: s(-22),
          child: _decorWithGlow(
            asset: cornerStarsLeftAsset,
            w: s(46),
            h: s(46),
            baseTint: cornerStarsBaseTint,
            glowTint: cornerStarsGlowTint,
          ),
        ),
        Positioned(
          bottom: s(-8),
          right: s(-20),
          child: _decorWithGlow(
            asset: cornerStarsRightAsset,
            w: s(48),
            h: s(48),
            baseTint: cornerStarsBaseTint,
            glowTint: cornerStarsGlowTint,
          ),
        ),
      ] else ...[
        Positioned(
          top: s(-18),
          right: s(-22),
          child: Transform.flip(
            flipX: true,
            child: _decorWithGlow(
              asset: cornerStarsLeftAsset,
              w: s(46),
              h: s(46),
              baseTint: cornerStarsBaseTint,
              glowTint: cornerStarsGlowTint,
            ),
          ),
        ),
        Positioned(
          bottom: s(-8),
          left: s(-20),
          child: Transform.flip(
            flipX: true,
            child: _decorWithGlow(
              asset: cornerStarsRightAsset,
              w: s(48),
              h: s(48),
              baseTint: cornerStarsBaseTint,
              glowTint: cornerStarsGlowTint,
            ),
          ),
        ),
      ],
    ],

    // ✅ DECOR: Kitty
    if (decor == BubbleDecor.kitty) ...[
      Positioned(
        top: s(-18),
        left: isMe ? s(-18) : null,
        right: isMe ? null : s(-18),
        child: IgnorePointer(
          ignoring: true,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  _musicNoteTintFromBubble(bubbleFill),
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/decors/TextBubbleKitty.png',
                  width: s(34),
                  height: s(34),
                  fit: BoxFit.contain,
                ),
              ),
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  _darkenColor(_musicNoteTintFromBubble(bubbleFill), 0.25),
                  BlendMode.srcIn,
                ),
                child: Transform.scale(
                  scale: 0.78,
                  child: Image.asset(
                    'assets/decors/TextBubbleKittyFace.png',
                    width: s(34),
                    height: s(34),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],

    // ✅ NEW badge (ALWAYS, independent of decor)
    Positioned(
      top: s(-10),
      left: isMe ? s(-14) : null,
      right: isMe ? null : s(-14),
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          opacity: showNewBadge ? 1.0 : 0.0,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            scale: showNewBadge ? 1.08 : 0.92,
            child: MysticNewBadge(
              uiScale: uiScale,
            ),
          ),
        ),
      ),
    ),
  ],
);


    final String tLabel = showTime ? _timeLabel(timeMs) : '';
    // ✅ Reserve vertical space so the list spacing stays like the old "time-under-bubble" layout.
// This compensates for the fact that Positioned() does NOT affect Stack height.
final double reservedTimeHeight =
    (showTime && tLabel.isNotEmpty) ? (5 * uiScale) : 0.0;

final bubbleWithName = Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
  children: [
if (showName)
  Padding(
    padding: EdgeInsets.only(bottom: 2 * uiScale),
    child: Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ✅ isMe: hearts BEFORE name (left of name)
          if (isMe) ...nameHearts,
          if (isMe && nameHearts.isNotEmpty) SizedBox(width: 4 * uiScale),

Text(
  user.name,
  style: TextStyle(
    color: usernameColor,
    fontSize: 16 * uiScale, // ✅ היה 13.5
    fontWeight: FontWeight.w300, // ✅ אופציונלי: קצת יותר “שם”
    height: 1.0,
    letterSpacing: 0.2 * uiScale,
  ),
),


          // ✅ not isMe: hearts AFTER name (right of name)
          if (!isMe && nameHearts.isNotEmpty) SizedBox(width: 4 * uiScale),
          if (!isMe) ...nameHearts,
        ],
      ),
    ),
  ),


    // ✅ Bubble only (time moved under avatar)
    ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: bubbleStack,
      ),
    ),
  ],
);




// ✅ Time label once (used under avatar)


// ✅ Avatar + Time block (locked position, never depends on bubble size)
Widget avatarWithTime({required bool rightSide}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: rightSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      avatar,
      if (showTime && tLabel.isNotEmpty) ...[
        SizedBox(height: 6 * uiScale),
Text(
  tLabel,
  textHeightBehavior: const TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  ),
  style: TextStyle(
    color: timeColor.withOpacity(0.70),
    fontSize: 12 * uiScale,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: 0.2 * uiScale,
  ),
),

      ],
    ],
  );
}
// ✅ TUNING: baseline gap between messages (Group Chat density)
final double rowBottomGap = 2 * uiScale; // was 6 * uiScale (try 2.5–4)

// ✅ אחרים (isMe=false): avatar + time on the LEFT, bubble on the RIGHT
if (!isMe) {
  return Padding(
    padding: EdgeInsets.only(bottom: reservedTimeHeight + rowBottomGap),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(left: avatarSize + gap),
          child: bubbleWithName,
        ),
        Positioned(
          left: 0,
          top: 0,
          child: avatarWithTime(rightSide: false),
        ),
      ],
    ),
  );
}

// ✅ אני (isMe=true): avatar + time on the RIGHT, bubble on the LEFT
return Padding(
  padding: EdgeInsets.only(bottom: reservedTimeHeight + rowBottomGap),
  child: Stack(
    clipBehavior: Clip.none,
    children: [
      Padding(
        padding: EdgeInsets.only(right: avatarSize + gap),
        child: Align(
          alignment: Alignment.centerRight,
          child: bubbleWithName,
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        child: avatarWithTime(rightSide: true),
      ),
    ],
  ),
);


// ✅ אני (isMe=true): avatar + time on the RIGHT, bubble on the LEFT
return Padding(
  padding: EdgeInsets.only(bottom: reservedTimeHeight + 6 * uiScale),

  child: Stack(
    clipBehavior: Clip.none,
    children: [
      Padding(
        padding: EdgeInsets.only(right: avatarSize + gap),
        child: Align(
          alignment: Alignment.centerRight,
          child: bubbleWithName,
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        child: avatarWithTime(rightSide: true), // ✅ USE IT
      ),
    ],
  ),
);


  }
}




class TypingBubbleRow extends StatelessWidget {
  final ChatUser user;
  final bool isMe;
  final double uiScale;

  const TypingBubbleRow({
    super.key,
    required this.user,
    required this.isMe,
    required this.uiScale,
  });

  Color _darken(Color c, [double amount = 0.25]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {


    final double avatarSlot = 56 * uiScale;

    final bubbleFill = user.bubbleColor;
    final dotsColor = _darken(bubbleFill, 0.55).withOpacity(0.85);

    final typingBubble = Container(
      width: avatarSlot,
      height: 34 * uiScale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bubbleFill,
        borderRadius: BorderRadius.circular(8 * uiScale),
      ),
      child: TypingDots(
        color: dotsColor,
        dotSize: 6.0 * uiScale,
        gap: 4.0 * uiScale,
      ),
    );

    return SizedBox(
      height: avatarSlot,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: isMe ? null : 0,
            right: isMe ? 0 : null,
            child: typingBubble,
          ),
        ],
      ),
    );
  }
}


class SquareAvatar extends StatelessWidget {
  final double size;
  final String letter;
  final String? imagePath;

  const SquareAvatar({
    super.key,
    required this.size,
    required this.letter,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.zero, // ✅ פינות חדות לגמרי
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: (imagePath != null && imagePath!.trim().isNotEmpty)
          ? ClipRect(
              child: Image.asset(
                imagePath!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(
                  letter.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            )
          : Text(
              letter.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
    );
  }
}



/// =======================
/// BUBBLE + TAIL (single painted shape = no seam)
/// =======================
class _BubbleWithTailPainter extends CustomPainter {
  final Color color;
  final bool isMe;
  final double radius;
  final double tailWidth;
  final double tailHeight;

  /// ✅ locked from TOP (Mystic behavior)
  final double tailTop;

  final bool glowEnabled;
  final Color? glowInnerColor;
  final Color? glowOuterColor;

  _BubbleWithTailPainter({
    required this.color,
    required this.isMe,
    required this.radius,
    required this.tailWidth,
    required this.tailHeight,
    required this.tailTop,
    required this.glowEnabled,
    required this.glowInnerColor,
    required this.glowOuterColor,
  });

  double _sigma(double blurRadius) {
    return blurRadius * 0.57735 + 0.5;
  }

  Path _buildBubblePath(Size size) {
    final Rect bubbleRect = isMe
        ? Rect.fromLTWH(0, 0, size.width - tailWidth, size.height)
        : Rect.fromLTWH(tailWidth, 0, size.width - tailWidth, size.height);

    final RRect bubbleRRect = RRect.fromRectAndRadius(
      bubbleRect,
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(bubbleRRect);

    // ✅ tail center is anchored from TOP, so it never moves with message height
    final double cy = bubbleRect.top + tailTop + (tailHeight / 2);

    final double minCy = bubbleRect.top + radius + tailHeight / 2 + 1;
    final double maxCy = bubbleRect.bottom - radius - tailHeight / 2 - 1;
    final double tailCy = cy.clamp(minCy, maxCy);

    // ✅ SHARP TRIANGLE TAIL
    if (isMe) {
      final double xBase = bubbleRect.right;
      final double xTip = bubbleRect.right + tailWidth;

      path.moveTo(xBase, tailCy - tailHeight / 2);
      path.lineTo(xTip, tailCy);
      path.lineTo(xBase, tailCy + tailHeight / 2);
      path.close();
    } else {
      final double xBase = bubbleRect.left;
      final double xTip = bubbleRect.left - tailWidth;

      path.moveTo(xBase, tailCy - tailHeight / 2);
      path.lineTo(xTip, tailCy);
      path.lineTo(xBase, tailCy + tailHeight / 2);
      path.close();
    }

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _buildBubblePath(size);

    // ✅ Glow must wrap the SAME path (bubble + tail)
    // ✅ Stroke-based glow: thickness stays constant no matter message length
    if (glowEnabled) {
      final Color inner = glowInnerColor ?? Colors.black;
      final Color outer = glowOuterColor ?? Colors.white;

      final Paint outerHaze = Paint()
        ..color = outer.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 32.0
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, _sigma(22));

      final Paint innerSpread = Paint()
        ..color = inner.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, _sigma(8));

      final Paint tightRing = Paint()
        ..color = inner.withOpacity(0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, _sigma(2.2));

      canvas.drawPath(path, outerHaze);
      canvas.drawPath(path, innerSpread);
      canvas.drawPath(path, tightRing);
    }

    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant _BubbleWithTailPainter old) {
    return old.color != color ||
        old.isMe != isMe ||
        old.radius != radius ||
        old.tailWidth != tailWidth ||
        old.tailHeight != tailHeight ||
        old.tailTop != tailTop ||
        old.glowEnabled != glowEnabled ||
        old.glowInnerColor != glowInnerColor ||
        old.glowOuterColor != glowOuterColor;
  }
}


class BubbleWithTail extends StatelessWidget {
  final Widget child;
  final Color color;
  final bool isMe;

  /// bubble shape tuning
  final double radius;
  final double tailWidth;
  final double tailHeight;

  /// ✅ from TOP of bubble-rect (not counting tail gutter)
  final double tailTop;

  /// ✅ glow (must wrap bubble + tail)
  final bool glowEnabled;
  final Color? glowInnerColor;
  final Color? glowOuterColor;

  const BubbleWithTail({
    super.key,
    required this.child,
    required this.color,
    required this.isMe,
    this.radius = 6,
    this.tailWidth = 10,
    this.tailHeight = 6,
    this.tailTop = 12,
    this.glowEnabled = false,
    this.glowInnerColor,
    this.glowOuterColor,
  });

  @override
  Widget build(BuildContext context) {
    final EdgeInsets gutter = EdgeInsets.only(
      left: isMe ? 0 : tailWidth,
      right: isMe ? tailWidth : 0,
    );

    return CustomPaint(
      painter: _BubbleWithTailPainter(
        color: color,
        isMe: isMe,
        radius: radius,
        tailWidth: tailWidth,
        tailHeight: tailHeight,
        tailTop: tailTop,
        glowEnabled: glowEnabled,
        glowInnerColor: glowInnerColor,
        glowOuterColor: glowOuterColor,
      ),
      child: Padding(
        padding: gutter,
        child: child,
      ),
    );
  }
}



class BubbleTail extends StatelessWidget {
  final Color color;
  final bool isMe;

  const BubbleTail({
    super.key,
    required this.color,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(7, 8),
      painter: _TailPainter(color: color, isMe: isMe),
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  final bool isMe;

  _TailPainter({required this.color, required this.isMe});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    if (isMe) {
      path.moveTo(0, 0);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height / 2);
      path.lineTo(size.width, size.height);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// =======================
/// RTL/LTR detector (per message)
/// =======================
bool _isRtl(String text) {
  for (final rune in text.runes) {
    if (rune == 0x20) continue; // space

    final ch = String.fromCharCode(rune);

    final isWeak = ch.trim().isEmpty ||
        '0123456789.,!?;:-()[]{}\'"'.contains(ch) ||
        ch == '\u200E' || // LRM
        ch == '\u200F'; // RLM

    if (isWeak) continue;

    if ((rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      return true;
    }

    return false;
  }

  return false;
}
String _hebrewFallbackFor(String? latinFamily) {
  switch (latinFamily) {
    case 'NanumGothic':
      return 'Heebo';
    case 'NanumMyeongjo':
      return 'FrankRuhlLibre';
    case 'BMHanna':
      return 'Abraham';
    default:
      return 'Heebo';
  }
}

// =====================
// Typing line (Option 2)
// =====================

class TypingDots extends StatefulWidget {
  final Color color;
  final double dotSize;
  final double gap;

  const TypingDots({
    super.key,
    required this.color,
    this.dotSize = 4.5,
    this.gap = 3.0,
  });

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _yForDot(int i, double t) {
    final phase = (t + i * 0.16) % 1.0;

    final v = (phase < 0.5)
        ? Curves.easeOut.transform(phase / 0.5)
        : Curves.easeIn.transform((1.0 - phase) / 0.5);

    return -6.0 * v;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : widget.gap),
              child: Transform.translate(
                offset: Offset(0, _yForDot(i, t)),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class TypingNamesLine extends StatelessWidget {
  final Map<String, ChatUser> usersById;
  final List<String> typingUserIds;
  final String currentUserId;

  /// אם יש יותר מ-2 מקלידות, נציג 2 ראשונות ואז "+N".
  final int maxNames;

  /// ✅ NEW
  final double uiScale;

  const TypingNamesLine({
    super.key,
    required this.usersById,
    required this.typingUserIds,
    required this.currentUserId,
    this.maxNames = 2,
    this.uiScale = 1.0,
  });

  String _nameFor(String id) {
    final u = usersById[id];
    final name = (u == null) ? id : u.name;
    return id == currentUserId ? 'You' : name;
  }

  Color _colorFor(String id) {
    final u = usersById[id];
    return (u == null) ? Colors.white : u.bubbleColor;
  }

  @override
  Widget build(BuildContext context) {
    if (typingUserIds.isEmpty) return const SizedBox.shrink();

    double s(double v) => v * uiScale;

    final shown = typingUserIds.take(maxNames).toList();
    final remaining = typingUserIds.length - shown.length;

    return Padding(
      padding: EdgeInsets.only(left: s(14), right: s(14), bottom: s(6)),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: s(8),
        runSpacing: s(4),
        children: [
          for (final id in shown) ...[
            Text(
              _nameFor(id),
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: s(12),
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
            TypingDots(color: _colorFor(id), dotSize: s(4.5), gap: s(3.0)),
          ],
          if (remaining > 0) ...[
            Text(
              '+$remaining',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: s(12),
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
            TypingDots(color: Colors.white.withOpacity(0.65), dotSize: s(4.5), gap: s(3.0)),
          ],
        ],
      ),
    );
  }
}
class MysticNewBadge extends StatelessWidget {
  final double uiScale;

  const MysticNewBadge({
    super.key,
    this.uiScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * uiScale;

    return ClipRRect(
      borderRadius: BorderRadius.circular(s(1.8)), // היה 1.1
      child: Container(
        color: const Color(0xFFFF6769),
        padding: EdgeInsets.symmetric(
          horizontal: s(2.4), // היה 0.7
          vertical: s(0.9),   // היה 0.15
        ),
        child: Text(
          'NEW',
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            color: Colors.white,
            fontSize: s(9.2),          // היה 6.0
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: s(0.35),     // היה 0.12
          ),
        ),
      ),
    );
  }
}

class TapToRecordMicButton extends StatefulWidget {
  final double size;
  final double iconSize;
  final double uiScale;
  final Future<void> Function(String filePath, int durationMs) onSendVoice;

  /// 🔊 optional: user-defined sounds (so we don't break compilation)
  final VoidCallback? onStartRecordingSfx;
  final VoidCallback? onCancelRecordingSfx;

  const TapToRecordMicButton({
    super.key,
    required this.size,
    required this.iconSize,
    required this.uiScale,
    required this.onSendVoice,
    this.onStartRecordingSfx,
    this.onCancelRecordingSfx,
  });

  @override
  State<TapToRecordMicButton> createState() => _TapToRecordMicButtonState();
}

class _TapToRecordMicButtonState extends State<TapToRecordMicButton> {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _busy = false; // ✅ prevents rapid double taps during start/stop
  int _startedAtMs = 0;
  String? _currentPath;

  bool _didPauseBgm = false;

  static const String _micAsset = 'assets/ui/MicReacordIcon.png';
  static const Color _recordingTint = Color(0xFF59EEC6);

  Future<String> _makeTempPath() async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/voice_$ts.m4a';
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _pauseBgmOnce() async {
    try {
      await Bgm.I.pause();
      _didPauseBgm = true;
    } catch (_) {
      _didPauseBgm = false;
    }
  }

  Future<void> _resumeBgmIfPausedByMe() async {
    if (!_didPauseBgm) return;
    try {
      await Bgm.I.resumeIfPossible();
    } catch (_) {}
    _didPauseBgm = false;
  }

  Future<void> _start() async {
    if (_isRecording) return;

    final ok = await _ensureMicPermission();
    if (!ok) return;

    await _pauseBgmOnce();

    final path = await _makeTempPath();

    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    _currentPath = path;

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
    } catch (_) {
      _startedAtMs = 0;
      _currentPath = null;
      await _resumeBgmIfPausedByMe();
      return;
    }

    try {
      widget.onStartRecordingSfx?.call();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isRecording = true);
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording) return;

    final stoppedPath = await _recorder.stop();
    final endMs = DateTime.now().millisecondsSinceEpoch;

    final path = stoppedPath ?? _currentPath;
    final durationMs = (_startedAtMs > 0) ? (endMs - _startedAtMs) : 0;

    _startedAtMs = 0;
    _currentPath = null;

    if (mounted) setState(() => _isRecording = false);

    await _resumeBgmIfPausedByMe();

    if (path == null) return;

    // ✅ if we somehow got 0ms, treat as cancel (don’t send silent)
    if (durationMs < 250) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      return;
    }

    await widget.onSendVoice(path, durationMs);
  }

  Future<void> _cancel() async {
    if (!_isRecording) return;

    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _currentPath;

    _startedAtMs = 0;
    _currentPath = null;

    if (mounted) setState(() => _isRecording = false);

    try {
      widget.onCancelRecordingSfx?.call();
    } catch (_) {}

    await _resumeBgmIfPausedByMe();

    if (path == null) return;

    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _toggleTap() async {
    if (_busy) return;
    _busy = true;

    try {
      if (_isRecording) {
        await _stopAndSend();
      } else {
        await _start();
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = _isRecording;

    return GestureDetector(
      onTap: _toggleTap,
      onDoubleTap: () async {
        if (_busy) return;
        if (!_isRecording) return;
        _busy = true;
        try {
          await _cancel();
        } finally {
          _busy = false;
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 90),
            scale: recording ? 1.12 : 1.0,
            child: Image.asset(
              _micAsset,
              width: widget.iconSize,
              height: widget.iconSize,
              fit: BoxFit.contain,
              color: recording ? _recordingTint : Colors.white.withOpacity(0.92),
            ),
          ),
        ),
      ),
    );
  }
}

class VoiceMessageTile extends StatefulWidget {
  final String filePath;
  final int durationMs;
  final double uiScale;

  // ✅ color of the sender bubble
  final Color bubbleColor;

  const VoiceMessageTile({
    super.key,
    required this.filePath,
    required this.durationMs,
    required this.uiScale,
    required this.bubbleColor,
  });

  @override
  State<VoiceMessageTile> createState() => _VoiceMessageTileState();
}

class _VoiceMessageTileState extends State<VoiceMessageTile> {
  final AudioPlayer _player = AudioPlayer();

  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _ready = false;

  // ✅ show spinner while loading remote URL / first decode
  bool _loading = false;

  // ✅ pause/resume BGM only on THIS phone
  bool _didPauseBgm = false;

  // ✅ NEW: prevent "completed" firing twice => play finish SFX only once
  bool _finishSfxPlayed = false;


  Color _darken(Color c, [double amount = 0.25]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _pauseBgmOnce() async {
    if (_didPauseBgm) return;
    try {
      await Bgm.I.pause();
      _didPauseBgm = true;
    } catch (_) {
      _didPauseBgm = false;
    }
  }

  Future<void> _resumeBgmIfPausedByMe() async {
    if (!_didPauseBgm) return;
    try {
      await Bgm.I.resumeIfPossible();
    } catch (_) {}
    _didPauseBgm = false;
  }

  Future<void> _ensureLoaded() async {
    if (_ready) return;

    final String path = widget.filePath.trim();
    if (path.isEmpty) return;

    final bool isRemote = path.startsWith('http://') || path.startsWith('https://');

    try {
      if (isRemote) {
        await _player.setUrl(path);
      } else {
        final f = File(path);
        if (!await f.exists()) return;
        await _player.setFilePath(path);
      }

      _dur = _player.duration ?? Duration(milliseconds: widget.durationMs);
      _ready = true;

      _player.positionStream.listen((p) {
        if (!mounted) return;
        setState(() => _pos = p);
      });

      // ✅ when completed: play SFX + resume BGM
      _player.playerStateStream.listen((st) async {
        if (!mounted) return;
        setState(() {});

        if (st.processingState == ProcessingState.completed) {
          // ✅ guard: prevent double fire
          if (_finishSfxPlayed) return;
          _finishSfxPlayed = true;

          // reset UI position to the end (just in case)
          if (mounted) setState(() => _pos = _player.duration ?? _dur);

          // 🔊 play "finished listening" sound (ONCE)
          try {
            await Sfx.I.playStopListeningToVoiceMessage();
          } catch (_) {}

          // 🎵 resume BGM (only on this phone)
          await _resumeBgmIfPausedByMe();

          // optional: jump back to start so next tap plays from beginning
          try {
            await _player.seek(Duration.zero);
            await _player.pause();
          } catch (_) {}
        }
      });


      // update duration later if it arrives (esp. for URL)
      _player.durationStream.listen((d) {
        if (!mounted) return;
        if (d == null) return;
        setState(() => _dur = d);
      });
    } catch (_) {
      _ready = false;
      return;
    }

    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    // ✅ if user leaves while playing: restore BGM
    _resumeBgmIfPausedByMe();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.uiScale;
    final bool playing = _player.playing;

    final Duration total = (_ready ? (_player.duration ?? _dur) : Duration(milliseconds: widget.durationMs));

    final double maxMs = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final double curMs = _pos.inMilliseconds.toDouble().clamp(0.0, maxMs);

    final Color base = widget.bubbleColor;
    final Color sliderActive = _darken(base, 0.28);
    final Color sliderInactive = sliderActive.withOpacity(0.25);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool bounded = constraints.maxWidth.isFinite;

        final double playW = 34 * s;
        final double gap1 = 10 * s;
        final double gap2 = 8 * s;
        final double timeW = 44 * s;

        final double sliderW = bounded
            ? (constraints.maxWidth - playW - gap1 - gap2 - timeW).clamp(60 * s, 240 * s)
            : (140 * s);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _loading
                  ? null
                  : () async {
                      if (!_ready) {
                        if (!mounted) return;
                        setState(() => _loading = true);

                        await _ensureLoaded();

                        if (!mounted) return;
                        setState(() => _loading = false);

                        if (!_ready) return;
                      }

                             if (_player.playing) {
                        await _player.pause();
                        await _resumeBgmIfPausedByMe();
                      } else {
                        // ✅ NEW: new play session => allow finish SFX once
                        _finishSfxPlayed = false;

                        // ✅ pause BGM while voice plays (this phone only)
                        await _pauseBgmOnce();
                        await _player.play();
                      }


                      if (!mounted) return;
                      setState(() {});
                    },
              child: Container(
                width: playW,
                height: playW,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10 * s),
                ),
                child: _loading
                    ? SizedBox(
                        width: 16 * s,
                        height: 16 * s,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2 * s,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black.withOpacity(0.55),
                          ),
                        ),
                      )
                    : Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 22 * s,
                        color: Colors.black.withOpacity(0.75),
                      ),
              ),
            ),
            SizedBox(width: gap1),

            SizedBox(
              width: sliderW,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: sliderActive,
                  inactiveTrackColor: sliderInactive,
                  thumbColor: sliderActive,
                  overlayColor: sliderActive.withOpacity(0.12),
                  trackHeight: 3.2 * s,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: 6.5 * s,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: 12 * s,
                  ),
                ),
                child: Slider(
                  value: curMs,
                  min: 0.0,
                  max: maxMs,
                  onChangeStart: (_) async {
                    if (_loading) return;

                    if (!_ready) {
                      if (!mounted) return;
                      setState(() => _loading = true);

                      await _ensureLoaded();

                      if (!mounted) return;
                      setState(() => _loading = false);
                    }
                  },
                  onChanged: (v) async {
                    if (!_ready) return;
                    await _player.seek(Duration(milliseconds: v.round()));
                  },
                ),
              ),
            ),

            SizedBox(width: gap2),

            SizedBox(
              width: timeW,
              child: Text(
                _fmt(total),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12 * s,
                  color: Colors.black.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
