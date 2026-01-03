import 'package:cloud_firestore/cloud_firestore.dart';

// [중요] 각 기능별 모델들을 import 합니다.
// 경로가 다르다면 본인 프로젝트 구조에 맞춰 수정해주세요.
import '../features/auth/models.dart';
import '../features/pet/models.dart';
import '../features/walk/models.dart';
import '../features/social/models.dart'; // (만약 별도 파일이 없다면 생략 가능)

// -----------------------------------------------------------------------------
// 1. 유저 (Auth) 리포지토리
// -----------------------------------------------------------------------------
class AuthRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 유저 정보 저장 (회원가입 시)
  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  // 유저 정보 가져오기 (로그인 시)
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDocument(doc);
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
    DateTime? birthDate, // 선택값 처리를 위해 nullable
    String gender = 'M',
    bool isNeutered = false,
  }) async {
    final docRef = _db.collection('pets').doc(); // 자동 ID 생성

    final newPet = PetModel(
      id: docRef.id,
      ownerId: userId,
      name: name,
      breed: breed,
      birthDate: Timestamp.fromDate(birthDate ?? DateTime.now()),
      gender: gender,
      imageUrl: '', // 이미지는 추후 Storage 구현 시 추가
      weight: weight,
      isNeutered: isNeutered,
      isPrimary: false, // 첫 등록 로직에 따라 true/false 분기 가능
    );

    await docRef.set(newPet.toMap());
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

  // 팔로우 (Transaction: 안전한 동시 업데이트)
  Future<void> followUser({required String myUid, required String targetUid}) async {
    final myRef = _db.collection('users').doc(myUid);
    final targetRef = _db.collection('users').doc(targetUid);

    final followRef = myRef.collection('following').doc(targetUid);
    final followerRef = targetRef.collection('followers').doc(myUid);

    return _db.runTransaction((transaction) async {
      final check = await transaction.get(followRef);
      if (check.exists) return; // 이미 팔로우 중

      // 1. 서브 컬렉션 추가
      transaction.set(followRef, {'createdAt': FieldValue.serverTimestamp()});
      transaction.set(followerRef, {'createdAt': FieldValue.serverTimestamp()});

      // 2. 카운트 증가
      transaction.update(myRef, {'stats.followingCount': FieldValue.increment(1)});
      transaction.update(targetRef, {'stats.followerCount': FieldValue.increment(1)});
    });
  }

  // 언팔로우 (Transaction)
  Future<void> unfollowUser({required String myUid, required String targetUid}) async {
    final myRef = _db.collection('users').doc(myUid);
    final targetRef = _db.collection('users').doc(targetUid);

    final followRef = myRef.collection('following').doc(targetUid);
    final followerRef = targetRef.collection('followers').doc(myUid);

    return _db.runTransaction((transaction) async {
      final check = await transaction.get(followRef);
      if (!check.exists) return;

      // 1. 서브 컬렉션 삭제
      transaction.delete(followRef);
      transaction.delete(followerRef);

      // 2. 카운트 감소
      transaction.update(myRef, {'stats.followingCount': FieldValue.increment(-1)});
      transaction.update(targetRef, {'stats.followerCount': FieldValue.increment(-1)});
    });
  }
}

// -----------------------------------------------------------------------------
// 4. 산책 (Walk) 리포지토리 - (다음 단계 준비용)
// -----------------------------------------------------------------------------
class WalkRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 산책 기록 저장
  Future<void> saveWalk(WalkRecordModel walk) async {
    // ID가 없으면 자동 생성
    final docRef = walk.id == null
        ? _db.collection('walks').doc()
        : _db.collection('walks').doc(walk.id);

    await docRef.set(walk.toMap());
  }

  // 내 산책 기록 불러오기
  Future<List<WalkRecordModel>> getMyWalks(String userId) async {
    final snapshot = await _db
        .collection('walks')
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true) // 최신순
        .get();

    return snapshot.docs.map((doc) => WalkRecordModel.fromDocument(doc)).toList();
  }
}