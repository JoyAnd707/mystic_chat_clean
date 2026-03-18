import 'dart:async';
import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyFactBotScheduler {
  DailyFactBotScheduler._();
  static final DailyFactBotScheduler I = DailyFactBotScheduler._();

  // ======================
  // Storage
  // ======================
  static const String _boxName = 'mystic_chat_storage';
  static const String _groupRoomId = 'group_main';

  static String _roomMessagesKey(String roomId) => 'room_messages__$roomId';
  static String _roomMetaKey(String roomId) => 'room_meta__$roomId';

  // ======================
  // SharedPreferences keys
  // ======================
  static const String _prefsNextSendMsKey = 'bot_nextSendMs__group_main';
  static const String _prefsLastSentDateKey = 'bot_lastSentDate__group_main';

  // ✅ NEW: presence tracking (for "someone is in chat")
  static const String _prefsLastPresenceMsKey = 'bot_lastPresenceMs__group_main';

  // ======================
  // Bot identity
  // ======================
  static const String botUserId = 'gackto_facto';

   Timer? _tick;
  bool _started = false;

  // ✅ Prevent concurrent check/send (fixes double-send in same run)
  bool _checkInFlight = false;


  // ✅ Tunables
  static const Duration _presenceWindow = Duration(minutes: 8); // "מישהי בצ'אט" לאחרונה
  static const Duration _sendCooldownAfterEnter = Duration(seconds: 60); // לא ישר בכניסה

  // ======================
  // FACT DATABASE 👇
  // ======================
  static const List<String> facts = <String>[
       'Honey never spoils. But if youd be my honey, id spoil you big time <3',
    'Octopuses have three hearts. My one heart is as big as three <3',
    'Bananas are berries, but strawberries are not. Try my banana. Its BERRY nutritious!',
    'A day on Venus is longer than a year on Venus. How quickly time goes by...',
    'The Eiffel Tower can grow taller in summer. you know what else grows bigger in the summer?',
    'A cloud weighs around a million tonnes. I wouldnt know the feeling, im a twink!' ,
    'Giraffes are 30 times more likely to get hit by lightning than people. Whos lighthing? is he still single?' ,
    'Identical twins dont have the same fingerprints. The police once took mine. ' ,
    'Earths rotation is changing speed. Well someone tell it to slow down!' ,
    'Earlobes have no biological purpose. Other than holding my cool earrings!' ,
    'Your brain is constantly eating itself. I wish i could eat myself!' ,
    'The largest piece of fossilised dinosaur shit discovered is over 30cm long and over two litres in volume. I experienced it first hand!' ,
    'Mars isnt actually round. know what else is round?' ,
    'Theres no such thing as zero-calorie foods. Bad news for the twink community...' ,
    'The Universes average colour is called Cosmic latte' ,
    'Animals can experience time differently from humans. Thats how i feel when im with you! ' ,
    'Water might not be wet. guess what i am right now.' ,
    'Most people stroke cats the wrong way. I usually diddle mine' ,
    'A chicken once lived for 18 months without a head. Me on the other hand, i cant go without head for more than 2 days!' ,
    'The raw ingredients of a human body would cost over £116,000. My raw ingredients are always free for you!' ,
    'Wearing a tie can reduce blood flow to the brain by 7.5 per cent. So tie me up next time!' ,
    'The fear of long words is called Hippopotomonstrosesquippedaliophobia. BOO!' ,
    'The worlds oldest dog lived to 29.5 years old. Did you know, On March 29,I performed the national anthem Kimigayo at the Major League Baseball season opening game in Tokyo Dome! ' ,
    'The worlds oldest cat lived to 38 years and three days old. When i was 38, i voiced the character Dante in the anime Sket Dance!' , 
    'The Sun makes a sound but we cant hear it. But you always listen to my songs :)' ,
    'Mount Everest isnt the tallest mountain on Earth. But it isnt short, its of average height!' ,
    'Our solar system has a wall. You can buy my awesome custom made wall decor at https://www.amazon.ca/Japanese-Aesthetic-Painting-Posters-16x24inch/dp/B09MJ86GD1' ,
    'Octopuses dont actually have tentacles. Here in japan with have plenty of tentacle experiences!' ,
    'Most maps of the world are wrong. Except the one that lead me to your heart <3' ,
    'NASA genuinely faked part of the Moon landing. Dont trust the goverment!(˶˃ ᵕ ˂˶) .ᐟ.ᐟ' ,
    'Comets smell like rotten eggs. Yuck!' ,
    'Earths poles are moving. I know of another moving pole ' ,
    'You can actually die laughing. So dont read too many of my hilarious facts!' ,
    'Chainsaws were first invented for childbirth. The thought alone sends chills down my spine!!' ,
    'The T.rex likely had feathers. Like me in Le Ciel!' ,
    'Football teams wearing red kits play better. Do you think red suits me? :)' ,
    'When you cut a worm in two, it regenerates. My broken heart didnt...' ,
    'Snails have teeth. Gave me srtaight teeth!' ,
    'Bananas are radioactive. Mine safe for the most part' ,
    'Theres no such thing as a straight line. What about a gay line?' ,
    'Finland is the happiest country on Earth. But im the happiest PERSON in the world. Check out this picture i took because im happy!',
    'You can be heavily pregnant and not realise. Is this what they call MPreg?!' ,
    'Most ginger cats are male. People thought i was a eoman so i dyed mine!' ,
    'In the deep sea, male anglerfish dont just mate. I wish i could find a man to try...' ,
    'Its possible for two lucid dreamers to communicate mid-dream. So lets sleep together and test it out!' ,
    'Being bored is actually a high arousal state physiologically... <3',
    'Platypuses sweat milk.... Call me perry.', 
    'LEGO bricks withstand compression better than concrete. I get bricked when you wont leggo!' ,
    'Its almost impossible to get too much sugar from fresh fruit. Youre much sweeter to me!',
    'You dont like the sound of your own voice because of the bones in your head. I personally think my voice is beautiful!Yasashii utagoe ni michibikareteNagare ochiru masshiro na namida ga kaze ni fukare toki wo kizamu, Boku wo miru kegare wo shiranai hitomi wa,Hateshinaku doko made mo tsuzuku daichi wo utsushi, Chiisana yubi de wasurete ita boku no namida no ato wo nazoru,Kimi wo hosoku sukitooru koe ga boku wo hanasanai,Boku ga koko ni itsuzukeru koto wa dekinai no ni,Ah, kobore ochiru namida wa o wakare no kotoba,Nani mo kikazu, tada boku no mune ni te wo ate hohoemi wo ukabe,Kimi no hoho ni kuchizuke wo... Boku wa kimi wo wasurenai, Motto tsuyoku dakishimete boku ga sora ni kaeru made,Kimi no hosoku sukitooru koe ga boku wo hanasanai,Motto tsuyoku dakishimete boku ga kienai you ni...,Boku ga kienai you ni... ',
    'Some animals display autistic-like traits. Woof!', 
    'The biggest butterfly in the world has a 31cm wingspan. The wings i wore were 10 times my width!',
    'You remember more dreams when you sleep badly. Ill make sure all your dreams are sweet <3',
    'A lightning bolt is five times hotter than the surface of the Sun. call me lightning bolt!' ,
    'Earth is 4.54 billion years old. Ill be 53 soon!' ,
    'eavers dont actually live in dams. Damn!!', 
    'Giraffes hum to communicate with each other. Just like me and The other Malice Mizer gang!',
    'Murder rates rise in summer. Too bad its so cold outside! BRR!!',
    'Laughing came before language. Did you laugh before reading my fun facto?',
    'Your brain burns 400-500 calories a day. So think about me a lot!'
    
  ];

  // ======================
  // PUBLIC API
  // ======================
  Future<void> start() async {
    print('[BOT] start() called');

    if (_started) return;
    _started = true;

    await _ensureNextSendScheduled();

    _tick = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _checkAndMaybeSend();
    });

    // ✅ IMPORTANT:
    // NO immediate send check on start.
    // We only send when presence is detected (or later ticks after presence).
  }

  Future<void> stop() async {
    _tick?.cancel();
    _tick = null;
    _started = false;
  }

  /// ✅ Call this when someone enters / becomes active in the group chat.
  Future<void> pingPresence({String roomId = _groupRoomId}) async {
    if (roomId != _groupRoomId) return; // facts only for group_main right now
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_prefsLastPresenceMsKey, nowMs);

    print('[BOT] presence ping at $nowMs');

    // we can check immediately, but cooldown prevents "send instantly on enter"
    await _checkAndMaybeSend();
  }

  /// 🔧 DEBUG: force a send window in ~10s (ONLY when you want to test)
  Future<void> debugSendIn10Seconds() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    await prefs.setInt(_prefsNextSendMsKey, now + 10 * 1000);
    await prefs.remove(_prefsLastSentDateKey);

    print('[BOT] debugSendIn10Seconds armed');
  }

  // ======================
  // INTERNAL LOGIC
  // ======================
  String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  int _randomMsInDay(DateTime dayStart) {
    final r = Random();
    final seconds = r.nextInt(24 * 60 * 60); // 0..86399
    return dayStart.add(Duration(seconds: seconds)).millisecondsSinceEpoch;
  }

Future<void> _ensureNextSendScheduled() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getInt(_prefsNextSendMsKey);
  final nowMs = DateTime.now().millisecondsSinceEpoch;

  // ✅ If already scheduled (even if it's in the past), do NOT reshuffle.
  // This guarantees "decide once per day".
  if (existing != null) {
    print('[BOT] nextSendMs already set (keeping) existing=$existing now=$nowMs');
    return;
  }

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  int candidate = _randomMsInDay(todayStart);

  // never schedule "too close" to now to avoid instant send on first presence
  if (candidate <= now.millisecondsSinceEpoch + 60 * 1000) {
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    candidate = _randomMsInDay(tomorrowStart);
  }

  await prefs.setInt(_prefsNextSendMsKey, candidate);
  print('[BOT] scheduled nextSendMs=$candidate');
}


  Future<void> _scheduleForTomorrow() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final next = _randomMsInDay(tomorrowStart);
    await prefs.setInt(_prefsNextSendMsKey, next);

    print('[BOT] scheduled tomorrow nextSendMs=$next');
  }

  Future<void> _checkAndMaybeSend() async {
    // ✅ Mutex: prevents 2 async callers from sending twice
    if (_checkInFlight) return;
    _checkInFlight = true;

    try {
      if (facts.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final nextSendMs = prefs.getInt(_prefsNextSendMsKey);
      if (nextSendMs == null) {
        await _ensureNextSendScheduled();
        return;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // ✅ Gate 1: must be after scheduled time
      if (nowMs < nextSendMs) return;

      // ✅ Gate 2: someone must be "present recently"
      final lastPresenceMs = prefs.getInt(_prefsLastPresenceMsKey) ?? 0;
      final isPresenceRecent =
          (nowMs - lastPresenceMs) <= _presenceWindow.inMilliseconds;
      if (!isPresenceRecent) return;

      // ✅ Gate 3: not instantly on enter
      final bool cooldownPassed =
          (nowMs - lastPresenceMs) >= _sendCooldownAfterEnter.inMilliseconds;
      if (!cooldownPassed) return;

      // ✅ Gate 4: once per day
      final todayKey = _yyyyMmDd(DateTime.now());
      final lastSent = prefs.getString(_prefsLastSentDateKey);
      if (lastSent == todayKey) {
        await _scheduleForTomorrow();
        return;
      }

      await _sendOneFactToGroup();

      await prefs.setString(_prefsLastSentDateKey, todayKey);
      await _scheduleForTomorrow();
    } finally {
      _checkInFlight = false;
    }
  }


  Future<void> _sendOneFactToGroup() async {
    final box = await Hive.openBox(_boxName);

    final key = _roomMessagesKey(_groupRoomId);
    final raw = box.get(key);

    final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
    }

    final fact = facts[Random().nextInt(facts.length)].trim();

final nowMs = DateTime.now().millisecondsSinceEpoch;

if (fact.isNotEmpty) {
  list.add({
    'type': 'text',
    'senderId': botUserId,
    'text': fact,
    'ts': nowMs,
    'bubbleTemplate': 'normal',
    'decor': 'none',
    'fontFamily': null,
    'heartReactorIds': <String>[],
  });
}

list.add({
  'type': 'text',
  'senderId': botUserId,
  'text': 'Gackto Facto Out',
  'ts': nowMs + 1,
  'bubbleTemplate': 'normal',
  'decor': 'none',
  'fontFamily': null,
  'heartReactorIds': <String>[],
});


    await box.put(key, list);

    await box.put(
      _roomMetaKey(_groupRoomId),
      <String, dynamic>{
        'lastUpdatedMs': DateTime.now().millisecondsSinceEpoch,
        'lastSenderId': botUserId,
      },
    );

    print('[BOT] wrote fact + sign-off (total=${list.length})');
  }
}
