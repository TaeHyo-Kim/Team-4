import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../features/auth/models.dart';
import '../features/pet/models.dart';
import '../features/walk/models.dart';
import '../features/social/models.dart'; // FollowModel import 경로 확인 필요

// ... (UserRepository, PetRepository, WalkRepository는 기존과 동일하므로 생략)

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeoFlutterFire _geo = GeoFlutterFire();

  Future<void> signUpWithTransaction({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final userRef = _firestore.collection('users');
    final usernameRef = _firestore.collection('usernames').doc(nickname);

    try {
      await _firestore.runTransaction((transaction) async {
        final usernameDoc = await transaction.get(usernameRef);
        if (usernameDoc.exists) {
          throw Exception("이미 존재하는 닉네임입니다.");
        }
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = cred.user!.uid;
        final newUser = UserModel(
          uid: uid,
          email: email,
          nickname: nickname,
          stats: UserStats(),
          createdAt: DateTime.now(),
        );
        transaction.set(userRef.doc(uid), newUser.toMap());
        transaction.set(usernameRef, {'uid': uid});
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMyLocation(double lat, double lng) async {
    final user = _auth.currentUser;
    if (user == null) return;
    GeoFirePoint myLocation = _geo.point(latitude: lat, longitude: lng);
    await _firestore.collection('users').doc(user.uid).update({
      'position': myLocation.data,
      'lastActiveAt': FieldValue.serverTimestamp(),
      'isLocationPublic': true,
    });
  }

  Stream<List<DocumentSnapshot>> getNearbyUsersStream(double lat, double lng, double radiusInKm) {
    GeoFirePoint center = _geo.point(latitude: lat, longitude: lng);
    var collectionRef = _firestore.collection('users').where('isLocationPublic', isEqualTo: true);
    return _geo.collection(collectionRef: collectionRef)
        .within(center: center, radius: radiusInKm, field: 'position');
  }

  Future<void> blockUser(String targetUid) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'blockedUserIds': FieldValue.arrayUnion([targetUid])
    });
  }
}

class PetRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<void> addPet(PetModel pet) async {
    await _firestore.collection('pets').add(pet.toMap());
  }
}

class WalkRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<void> createWalkRecord({
    required String userId,
    required List<String> petIds,
    required List<LatLng> path,
    required int duration,
    required double distance,
    required String memo,
    required String emoji,
    required String visibility,
  }) async {
    String encoded = "encoded_polyline_example";
    GeoPoint startPoint = GeoPoint(path.first.latitude, path.first.longitude);
    String startHash = "wydm9q";
    final record = WalkRecordModel(
      userId: userId,
      petIds: petIds,
      startTime: Timestamp.now(),
      endTime: Timestamp.now(),
      duration: duration,
      distance: distance,
      calories: distance * 50,
      encodedPath: encoded,
      startLocation: startPoint,
      startGeohash: startHash,
      memo: memo,
      emoji: emoji,
      visibility: visibility,
    );
    WriteBatch batch = _firestore.batch();
    DocumentReference recordRef = _firestore.collection('walk_records').doc();
    DocumentReference userRef = _firestore.collection('users').doc(userId);
    batch.set(recordRef, record.toMap());
    batch.update(userRef, {
      'stats.totalWalkDistance': FieldValue.increment(distance),
    });
    await batch.commit();
  }
}

class SocialRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> followUser({required String myUid, required String targetUid}) async {
    // DB 구조 유지: 'follows' 컬렉션의 문서 ID는 'followerId_followingId'
    final String docId = '${myUid}_$targetUid';
    final DocumentReference followRef = _firestore.collection('follows').doc(docId);
    final DocumentReference myUserRef = _firestore.collection('users').doc(myUid);
    final DocumentReference targetUserRef = _firestore.collection('users').doc(targetUid);

    // 이미 팔로우 중인지 체크 (선택 사항이지만 카운터 꼬임 방지용)
    final docSnapshot = await followRef.get();
    if (docSnapshot.exists) {
      // 이미 팔로우 중이면 아무것도 안함 (또는 예외 발생)
      return;
    }

    // FollowModel 인스턴스 생성
    final newFollow = FollowModel(
      followerId: myUid,
      followingId: targetUid,
      createdAt: DateTime.now(),
    );

    WriteBatch batch = _firestore.batch();

    // 1. 팔로우 관계 생성 (Model 사용)
    batch.set(followRef, newFollow.toMap());

    // 2. 내 팔로잉 숫자 증가 (+1)
    batch.update(myUserRef, {
      'stats.followingCount': FieldValue.increment(1),
    });

    // 3. 상대방 팔로워 숫자 증가 (+1)
    // 주의: 상대방 유저 문서가 없으면 여기서 에러가 발생하여 전체가 취소됨 (Test 코드에서 실존 유저를 넘겨야 함)
    batch.update(targetUserRef, {
      'stats.followerCount': FieldValue.increment(1),
    });

    await batch.commit();
  }
}