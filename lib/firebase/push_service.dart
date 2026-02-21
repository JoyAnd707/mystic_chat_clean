// lib/firebase/push_service.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushService {
  PushService._();

  static final FirebaseMessaging _msg = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> initAndSaveToken({required String appUserId}) async {
    // 1) Ask permission (iOS + Android 13+)
    final settings = await _msg.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 2) Get token
    final token = await _msg.getToken();
    if (token == null || token.isEmpty) return;

    await _saveToken(token: token, appUserId: appUserId);

    // 3) Token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      await _saveToken(token: newToken, appUserId: appUserId);
    });
  }

  static Future<void> _saveToken({
    required String token,
    required String appUserId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'appUserId': appUserId, // joy/adi/...
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'updatedAt': FieldValue.serverTimestamp(),

      // ✅ store as ARRAY (safe + mergeable)
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }
}
