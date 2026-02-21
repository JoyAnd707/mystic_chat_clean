// lib/firebase/firestore_chat_service.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreChatService {
  FirestoreChatService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static DocumentReference<Map<String, dynamic>> _roomDoc(String roomId) {
    return _db.collection('rooms').doc(roomId);
  }

  static CollectionReference<Map<String, dynamic>> _messagesCol(String roomId) {
    return _roomDoc(roomId).collection('messages');
  }

  static bool _isDmRoomId(String roomId) => roomId.startsWith('dm_');

  /// Expects: dm_<idA>_<idB> (IDs are already sorted in your app)
  static List<String> _dmMemberIdsFromRoomId(String roomId) {
    final parts = roomId.split('_');
    if (parts.length < 3) return const [];
    final a = parts[1].trim();
    final b = parts[2].trim();
    if (a.isEmpty || b.isEmpty) return const [];
    return [a, b];
  }

  /// ✅ Critical for push notifications:
  /// Cloud Function needs rooms/{roomId}.memberIds to exist.
  static Future<void> _ensureDmRoomDocExists(String roomId) async {
    if (!_isDmRoomId(roomId)) return;

    final members = _dmMemberIdsFromRoomId(roomId);
    if (members.length != 2) return;

    final ref = _roomDoc(roomId);

    // Use merge so we never overwrite existing fields if you add more later.
    await ref.set({
      'kind': 'dm',
      'memberIds': members,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream of messages ordered by ts ascending.
  /// Injects:
  /// - id (docId)
  static Stream<List<Map<String, dynamic>>> messagesStreamMaps(String roomId) {
    return _messagesCol(roomId)
        .orderBy('ts', descending: false)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  /// docId = ts.toString()
  static Future<void> sendTextMessage({
    required String roomId,
    required String senderId,
    required String text,
    required int ts,
    required String bubbleTemplate,
    required String decor,
    String? fontFamily,

    // ✅ must match ChatScreenState named params
    String? replyToMessageId,
    String? replyToSenderId,
    String? replyToText,
  }) async {
    // ✅ DM rooms must have a parent room doc so push can resolve recipients
    await _ensureDmRoomDocExists(roomId);

    final docId = ts.toString();

    await _messagesCol(roomId).doc(docId).set({
      'type': 'text',
      'senderId': senderId,
      'text': text,
      'ts': ts,
      'bubbleTemplate': bubbleTemplate,
      'decor': decor,
      'fontFamily': fontFamily,
      'heartReactorIds': <String>[],

      // ✅ reply fields
      'replyToMessageId': replyToMessageId,
      'replyToSenderId': replyToSenderId,
      'replyToText': replyToText,
    });

    // optional: keep room "fresh"
    await _roomDoc(roomId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ must match ChatScreenState: sendSystemLine(text: ..., ts: ...)
  static Future<void> sendSystemLine({
    required String roomId,
    required String text,
    required int ts,
  }) async {
    // not strictly needed for push (system lines don't push),
    // but keeps DM room docs consistent.
    await _ensureDmRoomDocExists(roomId);

    final docId = ts.toString();

    await _messagesCol(roomId).doc(docId).set({
      'type': 'system',
      'senderId': '',
      'text': text,
      'ts': ts,
      'bubbleTemplate': 'normal',
      'decor': 'none',
      'fontFamily': null,
      'heartReactorIds': <String>[],
    });

    await _roomDoc(roomId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Voice message: uploads file to Storage and writes Firestore doc
  static Future<void> sendVoiceMessage({
    required String roomId,
    required String senderId,
    required String localFilePath,
    required int durationMs,
    required int ts,
    required String bubbleTemplate,
    required String decor,
  }) async {
    await _ensureDmRoomDocExists(roomId);

    final docId = ts.toString();

    // We assume m4a (as per your voice format notes)
    final storagePath = 'rooms/$roomId/voice/$docId.m4a';
    final ref = _storage.ref(storagePath);

    final file = File(localFilePath);
    final snap = await ref.putFile(
      file,
      SettableMetadata(contentType: 'audio/mp4'),
    );

    final voiceUrl = await snap.ref.getDownloadURL();

    await _messagesCol(roomId).doc(docId).set({
      'type': 'voice',
      'senderId': senderId,
      'ts': ts,
      'durationMs': durationMs,

      // important for playback
      'voiceUrl': voiceUrl,
      'storagePath': storagePath, // helps delete

      // keep same style fields as text
      'bubbleTemplate': bubbleTemplate,
      'decor': decor,
      'fontFamily': null,
      'heartReactorIds': <String>[],
    });

    await _roomDoc(roomId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Delete voice message: deletes storage file (if exists) + deletes Firestore doc
  static Future<void> deleteVoiceMessage({
    required String roomId,
    required String messageId,
  }) async {
    final msgRef = _messagesCol(roomId).doc(messageId);
    final snap = await msgRef.get();

    if (snap.exists) {
      final data = snap.data() ?? {};
      final storagePath = (data['storagePath'] ?? '').toString();
      final voiceUrl = (data['voiceUrl'] ?? '').toString();

      try {
        if (storagePath.isNotEmpty) {
          await _storage.ref(storagePath).delete();
        } else if (voiceUrl.isNotEmpty) {
          // fallback (if older docs saved only URL)
          await _storage.refFromURL(voiceUrl).delete();
        }
      } catch (_) {
        // ignore: file might already be gone
      }
    }

    await msgRef.delete();
  }

  static Future<void> toggleHeart({
    required String roomId,
    required String messageId,
    required String reactorId,
    required bool isAdding,
  }) async {
    final ref = _messagesCol(roomId).doc(messageId);

    await ref.update({
      'heartReactorIds': isAdding
          ? FieldValue.arrayUnion([reactorId])
          : FieldValue.arrayRemove([reactorId]),
    });
  }

  /// ✅ delete doc
  static Future<void> deleteMessage({
    required String roomId,
    required String messageId,
  }) async {
    await _messagesCol(roomId).doc(messageId).delete();
  }
}
