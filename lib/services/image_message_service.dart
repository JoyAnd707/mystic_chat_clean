import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImageMessageService {
  ImageMessageService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  /// Picks an image from gallery, uploads to Firebase Storage,
  /// and writes a Firestore message document:
  /// { type: "image", senderId, imageUrl, createdAt, fileName }
  ///
  /// Returns true if an image was sent, false if user canceled.
Future<bool> pickAndSendImage({
  required String roomId,
  required String senderId,
  required int ts,
  int imageQuality = 82,
  String? replyToMessageId,
  String? replyToSenderId,
  String? replyToText,
}) async {
  final XFile? picked = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: imageQuality,
  );

  if (picked == null) return false;

  final messagesRef = _firestore
      .collection('rooms')
      .doc(roomId)
      .collection('messages');

  final newDoc = messagesRef.doc(ts.toString());

  await newDoc.set({
    'id': newDoc.id,
    'type': 'image',
    'senderId': senderId,
    'text': '',
    'imageUrl': '',
    'fileName': picked.name,
    'ts': ts,
    'status': 'uploading',

    'replyToMessageId': replyToMessageId,
    'replyToSenderId': replyToSenderId,
    'replyToText': replyToText,
  });

  final String ext = _extFromName(picked.name);

  final storageRef = _storage
      .ref()
      .child('rooms')
      .child(roomId)
      .child('uploads')
      .child('${newDoc.id}.$ext');

  print('UPLOAD PATH: ${storageRef.fullPath}');

  try {
    final bytes = await picked.readAsBytes();

    final TaskSnapshot snap = await storageRef.putData(
      bytes,
      SettableMetadata(contentType: _guessImageContentType(ext)),
    );

    final String downloadUrl = await snap.ref.getDownloadURL();

    await newDoc.update({
      'imageUrl': downloadUrl,
      'status': 'sent',
    });

    return true;
  } catch (e) {
    await newDoc.update({'status': 'failed'});
    rethrow;
  }
}

  /// Picks a video from gallery, uploads to Firebase Storage,
  /// and writes a Firestore message document:
  /// { type: "video", senderId, videoUrl, ts, fileName, status }
  ///
  /// Returns true if a video was sent, false if user canceled.
Future<bool> pickAndSendVideo({
  required String roomId,
  required String senderId,
  required int ts,
  Duration? maxDuration,
  String? replyToMessageId,
  String? replyToSenderId,
  String? replyToText,
}) async {
  final XFile? picked = await _picker.pickVideo(
    source: ImageSource.gallery,
    maxDuration: maxDuration,
  );

  if (picked == null) return false;

  final messagesRef = _firestore
      .collection('rooms')
      .doc(roomId)
      .collection('messages');

  final newDoc = messagesRef.doc(ts.toString());

  await newDoc.set({
    'id': newDoc.id,
    'type': 'video',
    'senderId': senderId,
    'text': '',
    'videoUrl': '',
    'fileName': picked.name,
    'ts': ts,
    'status': 'uploading',

    'replyToMessageId': replyToMessageId,
    'replyToSenderId': replyToSenderId,
    'replyToText': replyToText,
  });

  final String ext = _extFromName(picked.name);

  final storageRef = _storage
      .ref()
      .child('rooms')
      .child(roomId)
      .child('uploads')
      .child('${newDoc.id}.$ext');

  print('UPLOAD PATH: ${storageRef.fullPath}');

  try {
    final TaskSnapshot snap = await storageRef.putFile(
      File(picked.path),
      SettableMetadata(contentType: _guessVideoContentType(ext)),
    );

    final String downloadUrl = await snap.ref.getDownloadURL();

    await newDoc.update({
      'videoUrl': downloadUrl,
      'status': 'sent',
    });

    return true;
  } catch (e) {
    await newDoc.update({'status': 'failed'});
    rethrow;
  }
}

  String _extFromName(String name) {
    final parts = name.split('.');
    if (parts.length < 2) return 'jpg';
    final ext = parts.last.toLowerCase().trim();
    if (ext.isEmpty) return 'jpg';
    return ext;
  }

  String _guessImageContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _guessVideoContentType(String ext) {
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'video/mp4';
    }
  }

  bool _isVideoExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'mp4':
    case 'mov':
    case 'webm':
    case 'mkv':
    case 'm4v':
      return true;
    default:
      return false;
  }
}

Future<void> _sendPickedImageFile({
  required XFile picked,
  required String roomId,
  required String senderId,
  required int ts,
  String? replyToMessageId,
  String? replyToSenderId,
  String? replyToText,
}) async {
  final messagesRef =
      _firestore.collection('rooms').doc(roomId).collection('messages');

  final newDoc = messagesRef.doc(ts.toString());

  await newDoc.set({
    'id': newDoc.id,
    'type': 'image',
    'senderId': senderId,
    'text': '',
    'imageUrl': '',
    'fileName': picked.name,
    'ts': ts,
    'status': 'uploading',

    'replyToMessageId': replyToMessageId,
    'replyToSenderId': replyToSenderId,
    'replyToText': replyToText,
  });

  final String ext = _extFromName(picked.name);

  final storageRef = _storage
      .ref()
      .child('rooms')
      .child(roomId)
      .child('uploads')
      .child('${newDoc.id}.$ext');

  try {
    final bytes = await picked.readAsBytes();

    final snap = await storageRef.putData(
      bytes,
      SettableMetadata(contentType: _guessImageContentType(ext)),
    );

    final url = await snap.ref.getDownloadURL();

    await newDoc.update({
      'imageUrl': url,
      'status': 'sent',
    });
  } catch (e) {
    await newDoc.update({'status': 'failed'});
    rethrow;
  }
}

Future<void> _sendPickedVideoFile({
  required XFile picked,
  required String roomId,
  required String senderId,
  required int ts,
  String? replyToMessageId,
  String? replyToSenderId,
  String? replyToText,
}) async {
  final messagesRef =
      _firestore.collection('rooms').doc(roomId).collection('messages');

  final newDoc = messagesRef.doc(ts.toString());

  await newDoc.set({
    'id': newDoc.id,
    'type': 'video',
    'senderId': senderId,
    'text': '',
    'videoUrl': '',
    'fileName': picked.name,
    'ts': ts,
    'status': 'uploading',

    'replyToMessageId': replyToMessageId,
    'replyToSenderId': replyToSenderId,
    'replyToText': replyToText,
  });

  final String ext = _extFromName(picked.name);

  final storageRef = _storage
      .ref()
      .child('rooms')
      .child(roomId)
      .child('uploads')
      .child('${newDoc.id}.$ext');

  try {
    final snap = await storageRef.putFile(
      File(picked.path),
      SettableMetadata(contentType: _guessVideoContentType(ext)),
    );

    final url = await snap.ref.getDownloadURL();

    await newDoc.update({
      'videoUrl': url,
      'status': 'sent',
    });
  } catch (e) {
    await newDoc.update({'status': 'failed'});
    rethrow;
  }
}

Future<bool> pickAndSendMedia({
  required String roomId,
  required String senderId,
  required int ts,
  String? replyToMessageId,
  String? replyToSenderId,
  String? replyToText,
}) async {
  final List<XFile> pickedList = await _picker.pickMultipleMedia();

  if (pickedList.isEmpty) return false;

  final XFile picked = pickedList.first;
  final String ext = _extFromName(picked.name);

  if (_isVideoExt(ext)) {
    await _sendPickedVideoFile(
      picked: picked,
      roomId: roomId,
      senderId: senderId,
      ts: ts,
      replyToMessageId: replyToMessageId,
      replyToSenderId: replyToSenderId,
      replyToText: replyToText,
    );
  } else {
    await _sendPickedImageFile(
      picked: picked,
      roomId: roomId,
      senderId: senderId,
      ts: ts,
      replyToMessageId: replyToMessageId,
      replyToSenderId: replyToSenderId,
      replyToText: replyToText,
    );
  }

  return true;
}

}
