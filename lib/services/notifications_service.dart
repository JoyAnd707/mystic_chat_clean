import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsService with WidgetsBindingObserver {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  // Channel ids (v2 so Android actually applies new sound settings)
  static const String channelDm = 'dm_messages_v2';
  static const String channelGroup = 'group_messages_v2';
  static const String channelHigh = 'chat_high_v2';



  

  // ✅ NEW: runtime state for gating
  final bool _isInForeground = true;

  // null => not currently inside a chat screen
  String? _activeRoomId;

  /// ✅ Call when entering/leaving a chat screen
  void setActiveRoomId(String? roomId) {
    final trimmed = roomId?.trim() ?? '';
    _activeRoomId = trimmed.isEmpty ? null : trimmed;
    debugPrint('NotificationsService | activeRoomId=$_activeRoomId');
  }


  Future<void> init() async {
    await _initLocalPlugin();
    await _createAndroidChannels();
    await _requestPermissionsIfNeeded();

    // ✅ NEW: track foreground/background
    WidgetsBinding.instance.addObserver(this);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint(
        'FG FCM | hasNotification=${message.notification != null} | data=${message.data}',
      );

      // ✅ NEW: foreground + inside the same room? -> NO notification
      final bool shouldShow = await _shouldShowNotificationFor(message);
      if (!shouldShow) {
        debugPrint('FG FCM | suppressed (user is viewing this room)');
        return;
      }

      final String kind = (message.data['kind']?.toString() ?? 'group').toLowerCase();
final bool isGroup = kind == 'group';
final String incomingRoomKey = _roomKeyFrom(message, isGroup: isGroup);

if (_activeRoomId != null && incomingRoomKey == _activeRoomId) {
  debugPrint('FG FCM | suppressed (user is viewing this room)');
  return;
}

await showFromRemoteMessage(message);

    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened: ${message.messageId}');
    });
  }

  /// Call this inside background handler isolate
  Future<void> initForBackground() async {
    await _initLocalPlugin();
    await _createAndroidChannels();
  }

  Future<void> _initLocalPlugin() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _local.initialize(initSettings);
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // file: android/app/src/main/res/raw/notification_sfx.ogg
    const sound = RawResourceAndroidNotificationSound('notification_sfx');

    const AndroidNotificationChannel dm = AndroidNotificationChannel(
      channelDm,
      'DM messages',
      description: 'Direct messages notifications',
      importance: Importance.high,
      playSound: true,
      sound: sound,
      enableVibration: true,
    );

    const AndroidNotificationChannel group = AndroidNotificationChannel(
      channelGroup,
      'Chatroom messages',
      description: 'Group chat notifications',
      importance: Importance.high,
      playSound: true,
      sound: sound,
      enableVibration: true,
    );

    const AndroidNotificationChannel high = AndroidNotificationChannel(
      channelHigh,
      'High priority chat',
      description: 'High priority notifications',
      importance: Importance.high,
      playSound: true,
      sound: sound,
      enableVibration: true,
    );

    await androidPlugin.createNotificationChannel(dm);
    await androidPlugin.createNotificationChannel(group);
    await androidPlugin.createNotificationChannel(high);
  }

  Future<void> _requestPermissionsIfNeeded() async {
    if (kIsWeb) return;

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // NOTE: On Android this API isn't really needed like iOS,
    // but keeping it doesn't hurt.
    if (Platform.isAndroid) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// ✅ NEW: single gate for "should notify?"
  Future<bool> _shouldShowNotificationFor(RemoteMessage message) async {
    // If not foreground -> always allow notification (this listener is FG,
    // but keeping logic future-proof)
    if (!_isInForeground) return true;

    // If not inside any chat screen -> allow (Main Menu / other screens)
    final String? active = _activeRoomId;
    if (active == null) return true;

    // Parse message kind + roomKey same way as showFromRemoteMessage
    final String kind = (message.data['kind']?.toString() ?? 'group').toLowerCase();
    final bool isGroup = kind == 'group';
    final String incomingRoomKey = _roomKeyFrom(message, isGroup: isGroup);

    // If backend didn’t send roomId/chatId/dmId, we cannot safely suppress.
    // (Otherwise we might suppress notifications for the wrong room.)
    if (incomingRoomKey.trim().isEmpty) return true;

    // If user is currently viewing THIS room -> suppress
    return incomingRoomKey != active;
  }

Future<void> showFromRemoteMessage(RemoteMessage message) async {
  // We prefer data fields for chat formatting
  final String rawSender =
      message.data['sender']?.toString() ??
      message.notification?.title ??
      'New message';

  final String msgText =
      message.data['body']?.toString() ??
      message.notification?.body ??
      '';

  // If truly empty, don’t show (prevents "NEW MESSAGE" / empty notifications)
  if (rawSender.trim().isEmpty && msgText.trim().isEmpty) return;

  // Optional: ignore "system" messages if your backend sends them
  final String msgType = (message.data['type']?.toString() ?? '').toLowerCase();
  if (msgType == 'system') return;

  // kind: "dm" | "group"
  final String kind = (message.data['kind']?.toString() ?? 'group').toLowerCase();
  final bool isGroup = kind == 'group';

  // Body without sender prefix (name already appears in title)
  final String cleanBody = msgText.trim().isEmpty ? '' : msgText.trim();

  // ✅ Capitalize sender for preview titles (joy -> Joy)
  final String sender = _capitalizeFirst(rawSender);

  // --- "Chatroom opened" logic (4h gap) ---
  final String roomKey = _roomKeyFrom(message, isGroup: isGroup);
  final int nowMs = DateTime.now().millisecondsSinceEpoch;

  final int? lastMs = await _getLastNotifyMs(roomKey);
  final bool isNewChatroom =
      lastMs == null ? true : (nowMs - lastMs) >= _chatroomGap.inMilliseconds;

  String title;
  String body;

  if (isGroup && isNewChatroom) {
    title = 'A new chatroom has opened!';
    body = cleanBody.isEmpty ? '' : '[new chatroom] $cleanBody';
  } else {
    title = isGroup ? '$sender (CHATROOM)' : sender;
    body = cleanBody;
  }

  // Channel selection
  final String channelId = isGroup ? channelGroup : channelDm;

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    isGroup ? 'Chatroom messages' : 'DM messages',
    channelDescription:
        isGroup ? 'Group chat notifications' : 'Direct messages notifications',
    importance: Importance.high,
    priority: Priority.high,
  );

  final NotificationDetails details =
      NotificationDetails(android: androidDetails);

  // Stable-ish id to reduce accidental duplicates
  final int notificationId =
      (message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString())
          .hashCode;

  await _local.show(
    notificationId,
    title,
    body,
    details,
  );

  // Update last notification time for this room scope
  await _setLastNotifyMs(roomKey, nowMs);
}

/// ✅ Capitalize only the first character (safe for already-capitalized)
String _capitalizeFirst(String s) {
  final t = s.trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}


  // "Chatroom opened" threshold
  static const Duration _chatroomGap = Duration(hours: 2);

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  /// Prefer per-room tracking if backend sends roomId/chatId.
  /// Falls back to kind-only tracking.
  String _roomKeyFrom(RemoteMessage message, {required bool isGroup}) {
    final String roomId =
        (message.data['roomId']?.toString() ??
                message.data['chatId']?.toString() ??
                message.data['dmId']?.toString() ??
                '')
            .trim();

    if (roomId.isNotEmpty) {
      return roomId;
    }

    // fallback: group/dm scope only
    return isGroup ? 'group' : 'dm';
  }

  Future<int?> _getLastNotifyMs(String roomKey) async {
    final p = await _prefs;
    return p.getInt('last_notify_ms_$roomKey');
  }

  Future<void> _setLastNotifyMs(String roomKey, int ms) async {
    final p = await _prefs;
    await p.setInt('last_notify_ms_$roomKey', ms);
  }
}
