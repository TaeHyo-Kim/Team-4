import 'package:cloud_firestore/cloud_firestore.dart';

// 각 기능별 모델들을 import 합니다.
import '../features/auth/models.dart';
import '../features/pet/models.dart';
import '../features/walk/models.dart';
import '../features/social/models.dart';

// -----------------------------------------------------------------------------
// 1. 유저 (Auth) 리포지토리
// -----------------------------------------------------------------------------
class AuthRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 닉네임 중복 체크를 포함한 트랜잭션 저장 로직
  Future<void> saveUserWithNicknameCheck(UserModel user) async {
    final nicknameRef = _db.collection('usernames').doc(user.nickname);
    final userRef = _db.collection('users').doc(user.uid);

    return _db.runTransaction((transaction) async {
      // 1. 닉네임 존재 여부 확인
      final nicknameDoc = await transaction.get(nicknameRef);
      if (nicknameDoc.exists) {
        throw Exception("이미 사용 중인 닉네임입니다.");
      }

      // 2. 닉네임 선점 및 유저 프로필 동시 저장
      transaction.set(nicknameRef, {'uid': user.uid});
      transaction.set(userRef, user.toMap());
    });
  }

  // 유저 정보 가져오기
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDocument(doc);
  }

  // [오류 해결용 추가] 유저 프로필 정보(닉네임, 한줄소개, 위치공개 등) 업데이트
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }
}

// -----------------------------------------------------------------------------
// 2. 반려동물 (Pet) 리포지토리
// -----------------------------------------------------------------------------
class PetRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 내 반려동물 목록 가져오기
  Future<List<PetModel>> getPets(String userId) async {
    final snapshot = await _db
        .collection('pets')
        .where('ownerId', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) => PetModel.fromDocument(doc)).toList();
  }

  // 반려동물 등록
  Future<void> createPet({
    required String userId,
    required String name,
    required String breed,
    required double weight,
    DateTime? birthDate,
    String gender = 'M',
    bool isNeutered = false,
    String? imageUrl,
  }) async {
    final docRef = _db.collection('pets').doc();

    final newPet = PetModel(
      id: docRef.id,
      ownerId: userId,
      name: name,
      breed: breed,
      birthDate: Timestamp.fromDate(birthDate ?? DateTime.now()),
      gender: gender,
      imageUrl: imageUrl ?? '',
      weight: weight,
      isNeutered: isNeutered,
      isPrimary: false,
    );

    await docRef.set(newPet.toMap());
  }

  // 반려동물 정보 수정 (대표 펫 설정, 이미지 변경 등)
  Future<void> updatePet(String petId, Map<String, dynamic> data) async {
    await _db.collection('pets').doc(petId).update(data);
  }

  // 반려동물 삭제
  Future<void> deletePet(String petId) async {
    await _db.collection('pets').doc(petId).delete();
  }
}

// -----------------------------------------------------------------------------
// 3. 커뮤니티 (Social) 리포지토리
// -----------------------------------------------------------------------------
class SocialRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 전체 유저 목록 조회 (나 자신 제외)
  Future<List<UserModel>> getAllUsers(String myUid) async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs
        .map((doc) => UserModel.fromDocument(doc))
        .where((user) => user.uid != myUid)
        .toList();
  }

  // 내가 팔로우한 UID 목록 조회
  Future<Set<String>> getMyFollowingIds(String myUid) async {
    final snapshot = await _db
        .collection('users')
        .doc(myUid)
        .collection('following')
        .get();

    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  // 팔로우 실행 (트랜잭션으로 팔로잉/팔로워 수 동시 업데이트)
  Future<void> followUser({required String myUid, required String targetUid}) async {
    final myRef = _db.collection('users').doc(myUid);
    final targetRef = _db.collection('users').doc(targetUid);

    final followRef = myRef.collection('following').doc(targetUid);
    final followerRef = targetRef.collection('followers').doc(myUid);

    return _db.runTransaction((transaction) async {
      final check = await transaction.get(followRef);
      if (check.exists) return;

      transaction.set(followRef, {'createdAt': FieldValue.serverTimestamp()});
      transaction.set(followerRef, {'createdAt': FieldValue.serverTimestamp()});

      transaction.update(myRef, {'stats.followingCount': FieldValue.increment(1)});
      transaction.update(targetRef, {'stats.followerCount': FieldValue.increment(1)});
    });
  }

  // 언팔로우 실행
  Future<void> unfollowUser({required String myUid, required String targetUid}) async {
    final myRef = _db.collection('users').doc(myUid);
    final targetRef = _db.collection('users').doc(targetUid);

    final followRef = myRef.collection('following').doc(targetUid);
    final followerRef = targetRef.collection('followers').doc(myUid);

    return _db.runTransaction((transaction) async {
      final check = await transaction.get(followRef);
      if (!check.exists) return;

      transaction.delete(followRef);
      transaction.delete(followerRef);

      transaction.update(myRef, {'stats.followingCount': FieldValue.increment(-1)});
      transaction.update(targetRef, {'stats.followerCount': FieldValue.increment(-1)});
    });
  }
}

// -----------------------------------------------------------------------------
// 4. 산책 (Walk) 리포지토리
// -----------------------------------------------------------------------------
class WalkRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 산책 기록 저장
  Future<void> saveWalk(WalkRecordModel walk) async {
    final docRef = walk.id == null
        ? _db.collection('walks').doc()
        : _db.collection('walks').doc(walk.id);

    await docRef.set(walk.toMap());
  }

  // 내 산책 기록 불러오기 (최신순 정렬)
  Future<List<WalkRecordModel>> getMyWalks(String userId) async {
    final snapshot = await _db
        .collection('walks')
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs.map((doc) => WalkRecordModel.fromDocument(doc)).toList();
  }
}