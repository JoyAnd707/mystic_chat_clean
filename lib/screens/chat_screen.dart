import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/chat_widgets.dart';
import '../audio/sfx.dart';
import '../audio/bgm.dart';
import '../bots/daily_fact_bot.dart';
import '../fx/heart_reaction_fly_layer.dart';
import 'dart:ui';
import '../firebase/firestore_chat_service.dart';
import '../firebase/auth_service.dart';
import '../services/presence_service.dart';
import '../services/notifications_service.dart'; // ✅ ADD THIS

// ✅ ADD THIS
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/image_message_service.dart';
part 'chat_screen_state.dart';
part 'chat_screen_widgets.dart';


double mysticUiScale(BuildContext context) {
  // ✅ UI scale tuned for your Mystic layout.
  // This is the "older" behavior (before the wide-phone cap):
  // - can scale DOWN on smaller screens
  // - can scale UP a bit on wider screens (keeps your original look)
  const double designWidth = 393.0; // iPhone 15 Pro baseline
  final double screenWidth = MediaQuery.of(context).size.width;

  // Allow a little upscaling (this is what makes the layout look like your
  // earlier "perfect" version on wider previews/devices).
  return (screenWidth / designWidth).clamp(0.85, 1.15);
}




class _TemplateMenuResult {
  final BubbleTemplate template;
  final BubbleDecor decor;

  const _TemplateMenuResult({
    required this.template,
    required this.decor,
  });
}

String backgroundForHour(int hour) {
  // 00:00–00:59
  if (hour == 0) return 'assets/backgrounds/MidnightBG.png';

  // Night split:
  // 21:00–23:59  AND  01:00–06:59
  if ((hour >= 21 && hour <= 23) || (hour >= 1 && hour <= 6)) {
    return 'assets/backgrounds/NightBG.png';
  }

  // 07:00–11:59
  if (hour >= 7 && hour <= 11) return 'assets/backgrounds/MorningBG.png';

  // 12:00–16:59
  if (hour >= 12 && hour <= 16) return 'assets/backgrounds/NoonBG.png';

  // 17:00–20:59
  return 'assets/backgrounds/EveningBG.png';
}

Color usernameColorForHour(int hour) {
  // Morning + Noon => BLACK
  if (hour >= 7 && hour <= 16) {
    return Colors.black;
  }

  // Evening + Night + Midnight => WHITE
  return Colors.white;
}

Color timeColorForHour(int hour) {
  // Morning + Noon => BLACK
  if (hour >= 7 && hour <= 16) {
    return Colors.black;
  }

  // Evening + Night + Midnight => WHITE (as before)
  return Colors.white;
}


/// =======================
/// USERS
/// =======================
const bool kEnableDebugIncomingPreview = false;

const ChatUser joy =
    ChatUser(id: 'joy', name: 'Joy', bubbleColor: Color(0xFFDACFFF));
const ChatUser adi =
    ChatUser(id: 'adi', name: 'Adi★', bubbleColor: Color(0xFFFFCFF7));
const ChatUser lian =
    ChatUser(id: 'lian', name: 'Lian', bubbleColor: Color(0xFFFAC0C4));
const ChatUser danielle =
    ChatUser(id: 'danielle', name: 'Danielle', bubbleColor: Color(0xFFCFECFF));
const ChatUser lera =
    ChatUser(id: 'lera', name: 'Lera', bubbleColor: Color(0xFFFFDDCF));
const ChatUser lihi =
    ChatUser(id: 'lihi', name: 'Lihi', bubbleColor: Color(0xFFFFFDCF));
const ChatUser tal =
    ChatUser(id: 'tal', name: 'Tal', bubbleColor: Color(0xFFD7FFCF));
const ChatUser gacktoFacto = ChatUser(
  
  id: 'gackto_facto',
  name: 'Gackto Facto of the Day',
  bubbleColor: Color(0xFFCFFFEE),
  avatarPath: 'assets/avatars/gackto_facto.png',
);


const Map<String, ChatUser> users = {
  'joy': joy,
  'adi': adi,
  'lian': lian,
  'danielle': danielle,
  'lera': lera,
  'lihi': lihi,
  'tal': tal,
    'gackto_facto': gacktoFacto,

};



/// =======================
/// MESSAGE MODEL
/// =======================

enum ChatMessageType { text, system, image, voice, video }

class ChatMessage {
  /// Firestore doc id (we use ts.toString())
  final String id;

  final ChatMessageType type;
  final String senderId;

  /// For text messages
  final String text;

  /// For image messages
  final String? imageUrl;

  /// For video messages
  final String? videoUrl;

  /// For voice messages (local path for now)
  final String? voicePath;
  final int? voiceDurationMs;

  final int ts;

  final BubbleTemplate bubbleTemplate;
  final BubbleDecor decor;
  final String? fontFamily;

  final Set<String> heartReactorIds;

  // ✅ REPLY META (for preview inside the bubble)
  final String? replyToMessageId;
  final String? replyToSenderId;
  final String? replyToText;

  ChatMessage({
    required this.id,
    required this.type,
    required this.senderId,
    required this.text,
    required this.ts,
    this.imageUrl,
    this.videoUrl,
    this.voicePath,
    this.voiceDurationMs,
    this.bubbleTemplate = BubbleTemplate.normal,
    this.decor = BubbleDecor.none,
    this.fontFamily,
    Set<String>? heartReactorIds,
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToText,
  }) : heartReactorIds = heartReactorIds ?? <String>{};

  ChatMessage copyWith({
    String? id,
    ChatMessageType? type,
    String? senderId,
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? voicePath,
    int? voiceDurationMs,
    int? ts,
    BubbleTemplate? bubbleTemplate,
    BubbleDecor? decor,
    String? fontFamily,
    Set<String>? heartReactorIds,
    String? replyToMessageId,
    String? replyToSenderId,
    String? replyToText,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      voicePath: voicePath ?? this.voicePath,
      voiceDurationMs: voiceDurationMs ?? this.voiceDurationMs,
      ts: ts ?? this.ts,
      bubbleTemplate: bubbleTemplate ?? this.bubbleTemplate,
      decor: decor ?? this.decor,
      fontFamily: fontFamily ?? this.fontFamily,
      heartReactorIds: heartReactorIds ?? this.heartReactorIds,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToText: replyToText ?? this.replyToText,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'senderId': senderId,
        'text': text,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'voicePath': voicePath,
        'voiceDurationMs': voiceDurationMs,
        'ts': ts,
        'bubbleTemplate': bubbleTemplate.name,
        'decor': decor.name,
        'fontFamily': fontFamily,
        'heartReactorIds': heartReactorIds.toList(),
        'replyToMessageId': replyToMessageId,
        'replyToSenderId': replyToSenderId,
        'replyToText': replyToText,
      };

  static ChatMessage fromMap(Map m) {
    final typeStr = (m['type'] ?? 'text').toString();
    final type = ChatMessageType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => ChatMessageType.text,
    );

    final btStr = (m['bubbleTemplate'] ?? 'normal').toString();
    final bt = BubbleTemplate.values.firstWhere(
      (b) => b.name == btStr,
      orElse: () => BubbleTemplate.normal,
    );

    final decorStr = (m['decor'] ?? 'none').toString();
    final decor = BubbleDecor.values.firstWhere(
      (d) => d.name == decorStr,
      orElse: () => BubbleDecor.none,
    );

    final ff = m['fontFamily'];
    final fontFamily =
        (ff == null || ff.toString().trim().isEmpty) ? null : ff.toString();

    final int ts = (m['ts'] is int) ? (m['ts'] as int) : 0;

    final rawReactors = (m['heartReactorIds'] as List?) ?? const [];
    final reactors = rawReactors.map((e) => e.toString()).toSet();

    final rawId = m['id'];
    final id = (rawId != null && rawId.toString().trim().isNotEmpty)
        ? rawId.toString()
        : '${ts}_${m['senderId'] ?? ''}_${(m['text'] ?? '').toString().hashCode}';

    final img =
        (m['imageUrl'] == null || m['imageUrl'].toString().trim().isEmpty)
            ? null
            : m['imageUrl'].toString();

    final vid =
        (m['videoUrl'] == null || m['videoUrl'].toString().trim().isEmpty)
            ? null
            : m['videoUrl'].toString();

    final vp =
        (m['voicePath'] == null || m['voicePath'].toString().trim().isEmpty)
            ? null
            : m['voicePath'].toString();

    final int? vDur = (m['voiceDurationMs'] is int)
        ? (m['voiceDurationMs'] as int)
        : int.tryParse((m['voiceDurationMs'] ?? '').toString());

    return ChatMessage(
      id: id,
      type: type,
      senderId: (m['senderId'] ?? '').toString(),
      text: (m['text'] ?? '').toString(),
      imageUrl: img,
      videoUrl: vid,
      voicePath: vp,
      voiceDurationMs: vDur,
      ts: ts,
      bubbleTemplate: bt,
      decor: decor,
      fontFamily: fontFamily,
      heartReactorIds: reactors,
      replyToMessageId: (m['replyToMessageId'] as String?)?.toString(),
      replyToSenderId: (m['replyToSenderId'] as String?)?.toString(),
      replyToText: (m['replyToText'] as String?)?.toString(),
    );
  }
}



class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String roomId;
  final String? title;

  /// ✅ If false -> NO background music in this room (DMs)
  final bool enableBgm;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.roomId,
    this.title,
    this.enableBgm = true, // default = group behavior
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}



