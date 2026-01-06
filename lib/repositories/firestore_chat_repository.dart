import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreChatRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Gelen Kutusu (Benim sohbetlerim)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyChats(String myUid) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  // Sohbet İçindeki Mesajlar
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Mesaj Gönder
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final msgsRef = chatRef.collection('messages');
    final now = FieldValue.serverTimestamp();

    await _db.runTransaction((tx) async {
      tx.set(msgsRef.doc(), {
        'senderId': senderId,
        'text': text,
        'createdAt': now,
      });

      tx.update(chatRef, {
        'lastMessage': text,
        'lastMessageAt': now,
        'lastSenderId': senderId,
      });
    });
  }

  // Sohbet Başlat (Varsa getir, yoksa oluştur)
  Future<String> startChat(String myUid, String otherUid, String otherName) async {
    final ids = [myUid, otherUid]..sort();
    final chatId = ids.join('_'); // Benzersiz ID (uid1_uid2)
    final chatRef = _db.collection('chats').doc(chatId);
    final snap = await chatRef.get();

    if (!snap.exists) {
      await chatRef.set({
        'participants': ids,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'userNames': {otherUid: otherName},
      });
    }
    return chatId;
  }
}