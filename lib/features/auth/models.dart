import 'package:cloud_firestore/cloud_firestore.dart';

// 유저 통계
class UserStats {
  final double totalWalkDistance;
  final int followerCount;
  final int followingCount;

  UserStats({
    this.totalWalkDistance = 0.0,
    this.followerCount = 0,
    this.followingCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalWalkDistance': totalWalkDistance,
      'followerCount': followerCount,
      'followingCount': followingCount,
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      totalWalkDistance: (map['totalWalkDistance'] ?? 0).toDouble(),
      followerCount: map['followerCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
    );
  }
}

// 유저 모델 (필드 보완 완료)
class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String? bio;                // [추가] 자기소개
  final String? profileImageUrl;    // [추가] 프로필 이미지
  final bool isLocationPublic;      // [추가] 위치 공개 여부
  final Map<String, dynamic>? position; // [추가] GeoFlutterFire 위치 데이터
  final UserStats stats;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.bio,
    this.profileImageUrl,
    this.isLocationPublic = false, // 기본값은 비공개 권장
    this.position,
    required this.stats,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'isLocationPublic': isLocationPublic,
      'position': position, // 위치 정보 업데이트 시 사용
      'stats': stats.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      nickname: data['nickname'] ?? '알 수 없음',
      bio: data['bio'],
      profileImageUrl: data['profileImageUrl'],
      isLocationPublic: data['isLocationPublic'] ?? false,
      position: data['position'], // GeoPoint와 geohash가 포함된 Map
      stats: UserStats.fromMap(data['stats'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}