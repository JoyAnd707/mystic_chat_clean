import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService {
  PresenceService._();
  static final PresenceService I = PresenceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===== Config =====
static const Duration heartbeatEvery = Duration(seconds: 10);
static const Duration onlineTimeout = Duration(seconds: 45);


  Timer? _heartbeatTimer;

  String? _roomId;
  String? _userId;

  /// rooms/{roomId}/presence/{userId}
  DocumentReference<Map<String, dynamic>> _presenceDoc(String roomId, String userId) {
    return _db.collection('rooms').doc(roomId).collection('presence').doc(userId);
  }

  /// Call when user enters a room (chat screen opened).
Future<void> enterRoom({
  required String roomId,
  required String userId,
  required String displayName,
}) async {
  _roomId = roomId;
  _userId = userId;

  // Write an "online" snapshot immediately
  await _presenceDoc(roomId, userId).set(
    <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      'state': 'online',

      // ✅ use client timestamp for presence stability
      'lastSeen': Timestamp.now(),
    },
    SetOptions(merge: true),
  );

  // Start/Restart heartbeat
  _heartbeatTimer?.cancel();
  _heartbeatTimer = Timer.periodic(heartbeatEvery, (_) async {
    final rid = _roomId;
    final uid = _userId;
    if (rid == null || uid == null) return;

    try {
      await _presenceDoc(rid, uid).set(
        <String, dynamic>{
          'state': 'online',

          // ✅ IMPORTANT: Timestamp.now() avoids serverTimestamp delays/null
          'lastSeen': Timestamp.now(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // ignore transient errors; next heartbeat will retry
    }
  });
}

  /// Call when user leaves a room (chat screen disposed / user navigates back).
  /// Not guaranteed on force-kill; that's why we also have timeout logic.
Future<void> leaveRoom({
  required String roomId,
  required String userId,
}) async {
  // Stop heartbeat first
  _heartbeatTimer?.cancel();
  _heartbeatTimer = null;

  // Best-effort "offline" write
  try {
    await _presenceDoc(roomId, userId).set(
      <String, dynamic>{
        'state': 'offline',

        // ✅ keep presence timestamps client-side for stability
        'lastSeen': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  } catch (_) {
    // If app is closing / offline network - ignore
  }

  if (_roomId == roomId && _userId == userId) {
    _roomId = null;
    _userId = null;
  }
}


  /// Stream ONLINE userIds in a room using timeout:
  /// online == lastSeen within [onlineTimeout] seconds.
  Stream<Set<String>> streamOnlineUserIds({required String roomId}) {
    // We compare timestamps using client-side cutoff.
    // Firestore query: lastSeen > cutoff
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      final cutoff = DateTime.now().subtract(onlineTimeout);

      final snap = await _db
          .collection('rooms')
          .doc(roomId)
          .collection('presence')
          .where('lastSeen', isGreaterThan: Timestamp.fromDate(cutoff))
          .get();

      final ids = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = (data['userId'] ?? doc.id).toString();
        ids.add(uid);
      }
      return ids;
    }).distinct((a, b) {
      if (a.length != b.length) return false;
      for (final x in a) {
        if (!b.contains(x)) return false;
      }
      return true;
    });
  }

  // =======================
// Typing Presence (Firestore)
// =======================

CollectionReference<Map<String, dynamic>> _typingCol(String roomId) {
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .collection('typing');
}

/// Writes "I'm typing" to Firestore.
/// We DELETE the doc when not typing (clean + no stale flags).
Future<void> setTyping({
  required String roomId,
  required String userId,
  required String displayName,
  required bool isTyping,
}) async {
  final doc = _typingCol(roomId).doc(userId);

  if (isTyping) {
    await doc.set(<String, dynamic>{
      'isTyping': true,
      'displayName': displayName,
      'ts': FieldValue.serverTimestamp(), // better than local time
    }, SetOptions(merge: true));
  } else {
    // delete => no typing
    await doc.delete();
  }
}

/// Streams all currently-typing userIds in a room.
/// Filters out stale entries by timestamp.
/// NOTE: We rely on serverTimestamp + client "now" to ignore old docs.
Stream<Set<String>> streamTypingUserIds({
  required String roomId,
  int staleAfterMs = 8000, // 8s feels right for typing indicator
}) {
  return _typingCol(roomId).snapshots().map((snap) {
    final now = DateTime.now();
    final out = <String>{};

    for (final d in snap.docs) {
      final data = d.data();

      final bool isTyping = (data['isTyping'] == true);
      if (!isTyping) continue;

      final tsRaw = data['ts'];
      if (tsRaw is! Timestamp) continue;

      final ts = tsRaw.toDate();
      final ageMs = now.difference(ts).inMilliseconds;

      if (ageMs <= staleAfterMs) {
        out.add(d.id); // docId == userId
      }
    }

    return out;
  });
}

}
