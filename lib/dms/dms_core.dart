part of 'dms_screens.dart';






double mysticUiScale(BuildContext context) {
  // ✅ never upscale above design (prevents overflow on wide devices)
  const double designWidth = 393.0;       // baseline you already tuned
  const double maxWidthForScale = 430.0;  // cap wide phones

  final double screenWidth = MediaQuery.of(context).size.width;
  final double effectiveWidth = min(screenWidth, maxWidthForScale);

  return (effectiveWidth / designWidth).clamp(0.85, 1.0);
}

class DmUser {
  final String id;
  final String name;
  final String? avatarPath;

  const DmUser({
    required this.id,
    required this.name,
    this.avatarPath,
  });
}

// ✅ Keep DM users INSIDE DM module (no import from group files)
const Map<String, DmUser> dmUsers = {
  'joy': DmUser(id: 'joy', name: 'Joy'),
  'adi': DmUser(id: 'adi', name: 'Adi★'),
  'lian': DmUser(id: 'lian', name: 'Lian'),
  'danielle': DmUser(id: 'danielle', name: 'Danielle'),
  'lera': DmUser(id: 'lera', name: 'Lera'),
  'lihi': DmUser(id: 'lihi', name: 'Lihi'),
  'tal': DmUser(id: 'tal', name: 'Tal'),
};

String mysticTimestampFromMs(int ms) {
  if (ms <= 0) return '';

  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final yy = (dt.year % 100).toString().padLeft(2, '0');

  final isPm = dt.hour >= 12;
  final ampm = isPm ? 'PM' : 'AM';

  int hh = dt.hour % 12;
  if (hh == 0) hh = 12;

  final hhStr = hh.toString().padLeft(2, '0');
  final minStr = dt.minute.toString().padLeft(2, '0');

  return '$dd/$mm/$yy $ampm $hhStr:$minStr';
}

String mysticTimeOnlyFromMs(int ms) {
  if (ms <= 0) return '';

  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final isPm = dt.hour >= 12;
  final ampm = isPm ? 'PM' : 'AM';

  int hh = dt.hour % 12;
  if (hh == 0) hh = 12;

  final hhStr = hh.toString().padLeft(2, '0');
  final minStr = dt.minute.toString().padLeft(2, '0');

  return '$ampm $hhStr:$minStr';
}

// ✅ NEW: yyyy.MM.dd EEE like Mystic
String mysticDmDateHeaderFromMs(int ms) {
  if (ms <= 0) return '';

  final dt = DateTime.fromMillisecondsSinceEpoch(ms);

  const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final week = w[(dt.weekday - 1).clamp(0, 6)];

  final yyyy = dt.year.toString().padLeft(4, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');

  return '$yyyy.$mm.$dd $week';
}

bool mysticIsSameDayMs(int aMs, int bMs) {
  if (aMs <= 0 || bMs <= 0) return false;
  final a = DateTime.fromMillisecondsSinceEpoch(aMs);
  final b = DateTime.fromMillisecondsSinceEpoch(bMs);
  return a.year == b.year && a.month == b.month && a.day == b.day;
}




class _DmEntry {
  final DmUser user;
  final String roomId;
  final int lastUpdatedMs;
  final bool unread;
  final String preview;

  const _DmEntry({
    required this.user,
    required this.roomId,
    required this.lastUpdatedMs,
    required this.unread,
    required this.preview,
  });
}
