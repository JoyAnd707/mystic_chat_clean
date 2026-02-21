import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dms/dms_screens.dart';
import 'screens/chat_screen.dart';
import '../fx/heart_reaction_fly_layer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase/auth_service.dart';
import '../fx/tap_sparkle_layer.dart';
import 'audio/sfx.dart';
import 'audio/bgm.dart';
import 'bots/daily_fact_bot.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase/push_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notifications_service.dart';




class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
  
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child; // no animation, no fade, no white flash
  }
}




/// =======================================
/// Mystic Chat — App Entry
/// =======================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();



  final messaging = FirebaseMessaging.instance;

// בקשת הרשאה (iOS יציג את הדיאלוג רק על מכשיר אמיתי)
NotificationSettings settings =
    await messaging.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);

print('🔔 Notification permission: ${settings.authorizationStatus}');

// קבלת FCM token
String? token = await messaging.getToken();
print('📱 FCM Token: $token');


  // חובה כדי ש-local notifications יעבדו באיזולייט של BG
  await NotificationsService.instance.initForBackground();

  debugPrint(
    'BG FCM | hasNotification=${message.notification != null} | data=${message.data}',
  );

  // ✅ אם זו הודעה עם notification payload, אנדרואיד כבר מציג התראה לבד.
  // אחרת תקבלי כפילות (מערכת + local).
  if (message.notification != null) {
    return;
  }

  // ✅ data-only: פה כן מציגים local
  await NotificationsService.instance.showFromRemoteMessage(message);
}


Future<void> _enableImmersiveSticky() async {
  // Hide Android navigation bar + status bar until user swipes.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Optional: make bars transparent when they do appear (Android).
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must be registered before runApp (and before messages arrive)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ✅ Firebase (required before any Firestore usage)
  await Firebase.initializeApp();
  

  // ✅ Init notifications (creates channel for Android 8–12 + requests permission for 13+)
  await NotificationsService.instance.init();


  try {
    await FirebaseFirestore.instance.collection('debug').doc('ping').set({
      'ok': true,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (e) {
    debugPrint('Firestore ping failed: $e');
  }

  await Hive.initFlutter();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // ✅ Hide Android system bars until swipe
  await _enableImmersiveSticky();

  // ✅ ONE global audio session for the whole app
  try {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ));
  } catch (e) {
    debugPrint('AudioSession configure failed: $e');
  }

  // ✅ Init audio managers (just_audio)
  try {
    await Bgm.I.init();
  } catch (e) {
    debugPrint('Bgm.init failed: $e');
  }

  try {
    await Sfx.I.init();
  } catch (e) {
    debugPrint('Sfx.init failed: $e');
  }

  runApp(const MysticChatApp());
}








/// Key used to store the chosen user id (first launch).
const String kPrefsCurrentUserId = 'currentUserId';

/// Names allowed on first launch.
/// Tip: we accept both "Adi" and "Adi★" etc.
const Map<String, String> allowedNameToId = {
  'Joy': 'joy',
  'Adi': 'adi',
  'Lian': 'lian',
  'Danielle': 'danielle',
  'Lera': 'lera',
  'Lihi': 'lihi',
  'Tal': 'tal',
};



class MysticChatApp extends StatefulWidget {
  const MysticChatApp({super.key});

  @override
  State<MysticChatApp> createState() => _MysticChatAppState();
}

class _MysticChatAppState extends State<MysticChatApp>
    with WidgetsBindingObserver {
  Future<String?> _loadSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(kPrefsCurrentUserId);
    if (id == null || id.trim().isEmpty) return null;
    return id;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // App is no longer in the foreground → stop audio
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      await Bgm.I.pause();
      await Sfx.I.stopAll();
      return;
    }

if (state == AppLifecycleState.resumed) {
  await _enableImmersiveSticky();
  await Bgm.I.resumeIfPossible();
}

  }

  @override
  Widget build(BuildContext context) {
return MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: const {
        TargetPlatform.android: _NoTransitionsBuilder(),
        TargetPlatform.iOS: _NoTransitionsBuilder(),
      },
    ),
  ),
builder: (context, child) {
  return HeartReactionFlyLayer(
    child: TapSparkleLayer(
      debugScale: 0.7,
      child: child ?? const SizedBox.shrink(),
    ),
  );
},

  home: FutureBuilder<String?>(
    future: _loadSavedUserId(),
    builder: (context, snapshot) {
      final savedId = snapshot.data;
      if (savedId == null) {
        return const UsernameScreen();
      }
      return ChatModePicker(currentUserId: savedId);
    },
  ),
);


  }
}



Future<void> devReset(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();

  // ✅ Remove current user (forces onboarding again)
  await prefs.remove(kPrefsCurrentUserId);

  // OPTIONAL: uncomment only if you want to wipe all chats too
  // await Hive.deleteFromDisk();

  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const MysticChatApp()),
    (route) => false,
  );
}


/// =======================================
/// First-launch: Username → User ID
/// =======================================

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  String? _resolveUserId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Case-insensitive match against allowed names
    for (final entry in allowedNameToId.entries) {
      if (entry.key.toLowerCase() == trimmed.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

Future<void> _submit() async {
  final userId = _resolveUserId(_controller.text);
  if (userId == null) {
    setState(() => _error = 'שם לא נמצא ברשימה. נסי שוב בדיוק כמו שמופיע.');
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kPrefsCurrentUserId, userId);

  // 1) ✅ Sign in anonymously + save mapping users/<uid>
  await AuthService.ensureSignedIn(currentUserId: userId);

  // 2) ✅ Ask permission + get FCM token + save it into users/<uid>.fcmTokens
  await PushService.initAndSaveToken(appUserId: userId);

  if (!mounted) return;

  // 3) ✅ Now navigate
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => ChatModePicker(currentUserId: userId),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final allowedNames = allowedNameToId.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Mystic Chat',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'כתבי את השם שלך (חד-פעמי)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 22),

              TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  hintText: 'לדוגמה: Joy',
                  hintStyle: const TextStyle(color: Colors.white38),
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('המשך'),
              ),

              const SizedBox(height: 18),
              const Text(
                'שמות אפשריים:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in allowedNames)
                        Chip(
                          label: Text(name),
                          labelStyle: const TextStyle(color: Colors.white),
                          backgroundColor: const Color(0xFF2A2A2A),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class ChatModePicker extends StatefulWidget {
  final String currentUserId;

  const ChatModePicker({super.key, required this.currentUserId});

  @override
  State<ChatModePicker> createState() => _ChatModePickerState();
}

class _ChatModePickerState extends State<ChatModePicker> {
  bool _botStarted = false;

@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (_botStarted) return;
    _botStarted = true;

    await DailyFactBotScheduler.I.start();

    // ✅ Home BGM (also used for DMs)
    await Bgm.I.playHomeDm();

    // ✅ PUSH: ask permission + save token
    await PushService.initAndSaveToken(appUserId: widget.currentUserId);
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    'Mystic Chat',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'בחרי מצב:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 26),

ElevatedButton(
  onPressed: () {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: widget.currentUserId,
          roomId: 'group_main',
          title: 'Group Chat',
          enableBgm: true,
        ),
      ),
    )
        .then((_) async {
      // ✅ leaving group: resume Home/DMs BGM so it doesn't "leak"
      await Bgm.I.leaveGroupAndResumeHomeDm();
    });
  },
  child: const Text('Group Chat'),
),



                  const SizedBox(height: 12),

       ElevatedButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DmsListScreen(currentUserId: widget.currentUserId),
      ),
    );
  },
  child: const Text('DMs'),
),

                ],
              ),
            ),

            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => devReset(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'DEV RESET',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



